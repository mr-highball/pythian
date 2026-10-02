(*
MIT License

Copyright (c) 2026 mr-highball

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*)
unit pythian.tests.audio.session;

{$mode delphi}
{$H+}

interface

uses
  pythian.wfc.learning.profile;

procedure CheckAudioSession(const AProfile: TJournalModelProfile);
procedure SoakAudioSession(const AProfile: TJournalModelProfile; const ASeconds: Integer);

implementation

uses
  SysUtils, Math, fpjson, jsonparser, pythian.audio, pythian.learning.journal,
  pythian.learning.binding,
  pythian.learning.selection, pythian.learning.render.stream,
  pythian.wfc.audio.stream;

type
  TSessionProbe = class
    Reads: Int64;
    Channels: Integer;
    FailRead: Boolean;
    Reenter: Boolean;
    Session: TJournalAudioSession;
    GrainCount: Int64;
    GrainHash: QWord;
    function ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
    procedure Grain(const AOrdinal: Int64; const AToken: Integer;
      const ACandidate: TJournalRepresentative);
  end;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EAudio.Create(AMessage);
end;

function TSessionProbe.ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
var
  LIndex: Integer;
begin
  Inc(Reads);
  if FailRead then raise EAudio.Create('Authored source read failed');
  if Reenter then Session.Pause;
  SetLength(Result, ACandidate.ValidFrames * Max(1, Channels));
  for LIndex := 0 to High(Result) do
    Result[LIndex] := (1 + ACandidate.SegmentIndex) * (LIndex mod 7 - 3) / 32;
end;

procedure TSessionProbe.Grain(const AOrdinal: Int64; const AToken: Integer;
  const ACandidate: TJournalRepresentative);
begin
  Require(AOrdinal = GrainCount, 'Grain receipt sequence differs');
  Inc(GrainCount);
  GrainHash := (GrainHash * 33 + QWord(AToken * 7 + ACandidate.SegmentIndex * 3 +
    ACandidate.FeatureIndex + 1)) and $FFFFFFFF;
end;

function Render(const AProfile: TJournalModelProfile; const AFrames: Int64;
  const APull: Integer; out AGrainHash: QWord): TAudioSamples;
var
  LProbe: TSessionProbe;
  LSession: TJournalAudioSession;
  LBlock: TAudioSamples;
  LOffset: Integer;
  LBefore: Int64;
begin
  LProbe := TSessionProbe.Create;
  LSession := nil;
  try
    LSession := TJournalAudioSession.Create(AProfile, LProbe.ReadWindow,
      TJournalSelectionWeights.Create(3, 1), 731, AFrames, LProbe.Grain);
    SetLength(Result, AFrames);
    LOffset := 0;
    while LSession.State <> assCompleted do
    begin
      LBefore := LProbe.Reads;
      LBlock := LSession.ReadFrames(APull);
      Require((Length(LBlock) > 0) and (Length(LBlock) <= APull) and
        (LProbe.Reads - LBefore <= SessionChunkGrains), 'Unbounded or stalled pull');
      Move(LBlock[0], Result[LOffset], Length(LBlock) * SizeOf(Single));
      Inc(LOffset, Length(LBlock));
    end;
    Require((LOffset = AFrames) and (LSession.Position = AFrames) and
      (LProbe.GrainCount = LSession.TotalGrains), 'Exact ending or receipt differs');
    Require(Length(LSession.ReadFrames(APull)) = 0, 'Exhausted session continued');
    AGrainHash := LProbe.GrainHash;
  finally
    LSession.Free;
    LProbe.Free;
  end;
end;

procedure CheckAudioSession(const AProfile: TJournalModelProfile);
const
  CDurations: array[0..2] of Integer = (120, 7200, 86400);
var
  LProbe: TSessionProbe;
  LSession: TJournalAudioSession;
  LFirst, LSecond: TAudioSamples;
  LHashA, LHashB: QWord;
  LIndex: Integer;
  LReads, LPosition: Int64;
  LRejected: Boolean;
  LWide: TJournalModelProfile;
  LDocument: TJSONObject;
  LVocabulary: String;
  LSeconds: Integer;
begin
  LProbe := TSessionProbe.Create;
  LSession := nil;
  LWide := nil;
  LDocument := nil;
  try
    if AProfile.Model.Order = 4 then
    begin
      LSession := TJournalAudioSession.Create(AProfile, LProbe.ReadWindow,
        TJournalSelectionWeights.Create(1, 1), 731, 8000);
      LRejected := False;
      try LSession.ReadFrames(4096) except on EAudio do LRejected := True end;
      Require(LRejected and (LSession.State = assFailed) and
        (LSession.Position = 0) and (Pos('seed', LSession.Failure) > 0),
        'Impossible declared continuation did not fail with seed identity');
      WriteLn('PASS impossible continuation rejects without seed substitution');
      Exit;
    end;
    if AProfile.Model.Order <> 2 then Exit;
    LFirst := Render(AProfile, 264213, 173, LHashA);
    LSecond := Render(AProfile, 264213, 65536, LHashB);
    Require((Length(LFirst) = Length(LSecond)) and (LHashA = LHashB),
      'Consumer partition changed length or grain provenance');
    Require(CompareByte(LFirst[0], LSecond[0], Length(LFirst) * SizeOf(Single)) = 0,
      'Consumer partition changed exact PCM');
    for LIndex := 1 to 33 do
    begin
      LFirst := Render(AProfile, LIndex, 7, LHashA);
      Require(Length(LFirst) = LIndex, 'Sub-window ending differs');
    end;
    LSession := TJournalAudioSession.Create(AProfile, LProbe.ReadWindow,
      TJournalSelectionWeights.Create(1, 1), High(Integer), Int64(High(Integer)) + 64000);
    Require((LSession.TotalFrames > High(Integer)) and (LProbe.Reads = 0),
      'Large declared duration read ahead or truncated clock');
    LRejected := False;
    try LSession.ReadFrames(65537) except on EAudio do LRejected := True end;
    Require(LRejected and (LProbe.Reads = 0) and (LSession.State = assReady),
      'Invalid pull mutated session');
    LFirst := LSession.ReadFrames(4096);
    Require(Length(LFirst) > 0, 'Large-clock request failed first pull');
    LReads := LProbe.Reads;
    LPosition := LSession.Position;
    LSession.Pause;
    Require((Length(LSession.ReadFrames(4096)) = 0) and (LProbe.Reads = LReads) and
      (LSession.Position = LPosition), 'Pause failed backpressure');
    LSession.Resume;
    Require(Length(LSession.ReadFrames(4096)) > 0, 'Resume failed');
    LSession.Stop;
    LReads := LProbe.Reads;
    LSession.Resume;
    Require((LSession.State = assStopped) and
      (Length(LSession.ReadFrames(4096)) = 0) and (LProbe.Reads = LReads),
      'Stopped session restarted or read source');
    FreeAndNil(LSession);
    LSession := TJournalAudioSession.Create(AProfile, LProbe.ReadWindow,
      TJournalSelectionWeights.Create(1, 1), 731, 80000);
    LSession.ReadFrames(4096);
    LPosition := LSession.Position;
    LProbe.FailRead := True;
    LRejected := False;
    try LSession.ReadFrames(65536) except on EAudio do LRejected := True end;
    Require(LRejected and (LSession.State = assFailed) and
      (LSession.Position = LPosition), 'Read failure published partial pull');
    LReads := LProbe.Reads;
    LRejected := False;
    try LSession.ReadFrames(1) except on EAudio do LRejected := True end;
    Require(LRejected and (LReads = LProbe.Reads), 'Failed session retried source');
    FreeAndNil(LSession);
    LProbe.FailRead := False;
    LProbe.Reenter := True;
    LSession := TJournalAudioSession.Create(AProfile, LProbe.ReadWindow,
      TJournalSelectionWeights.Create(1, 1), 731, 80000);
    LProbe.Session := LSession;
    LRejected := False;
    try LSession.ReadFrames(4096) except on EAudio do LRejected := True end;
    Require(LRejected and (LSession.State = assFailed), 'Reentrant callback accepted');
    Require(JournalStreamFrames(65536, 32768, 300000) > High(Integer),
      'Primary renderer clock remains 32-bit');
    LRejected := False;
    try JournalStreamFrames(65536, 32768, High(Int64))
    except on EAudio do LRejected := True end;
    Require(LRejected, 'Overflowing geometry accepted');
    FreeAndNil(LSession);
    LProbe.Reenter := False;
    LProbe.Channels := 2;
    LDocument := TJSONObject(GetJSON(AProfile.EncodeReport));
    LDocument.Integers['sample_rate'] := MaximumSampleRate;
    LDocument.Integers['channels'] := 2;
    LVocabulary := AcousticVocabularySha256(AProfile.Palette, AProfile.Options,
      MaximumSampleRate, 2);
    LDocument.Strings['vocabulary_sha256'] := LVocabulary;
    LDocument.Strings['model_binding_sha256'] :=
      AcousticModelBindingSha256(LVocabulary, AProfile.ModelSha256);
    LWide := TJournalModelProfile.Create(LDocument.AsJSON, AProfile.EncodeModel);
    for LSeconds in CDurations do
    begin
      LSession := TJournalAudioSession.Create(LWide, LProbe.ReadWindow,
        TJournalSelectionWeights.Create(1, 1), 731, Int64(LSeconds) * MaximumSampleRate);
      Require(LSession.TotalFrames = Int64(LSeconds) * MaximumSampleRate,
        'Requested duration or maximum-rate stereo clock truncated');
      LFirst := LSession.ReadFrames(4096);
      Require((Length(LFirst) > 0) and (Length(LFirst) mod 2 = 0),
        'Large duration failed bounded stereo startup');
      FreeAndNil(LSession);
    end;
    WriteLn('PASS exact PCM/provenance partitions, clipping, large clocks, lifecycle and failures');
  finally
    LSession.Free;
    LWide.Free;
    LDocument.Free;
    LProbe.Free;
  end;
end;

procedure SoakAudioSession(const AProfile: TJournalModelProfile; const ASeconds: Integer);
var
  LProbe: TSessionProbe;
  LSession: TJournalAudioSession;
  LBlock: TAudioSamples;
  LStart: QWord;
  LWarmHeap, LMaximumHeap, LUsed: PtrUInt;
  LPulls: Int64;
begin
  Require((ASeconds >= 120) and (ASeconds <= 86400), 'Soak supports 120..86400 seconds');
  LProbe := TSessionProbe.Create;
  LSession := nil;
  try
    LSession := TJournalAudioSession.Create(AProfile, LProbe.ReadWindow,
      TJournalSelectionWeights.Create(1, 1), 731, Int64(ASeconds) * AProfile.SampleRate);
    LStart := GetTickCount64;
    LMaximumHeap := 0;
    LWarmHeap := 0;
    LPulls := 0;
    while LSession.State <> assCompleted do
    begin
      LBlock := LSession.ReadFrames(65536);
      Require(Length(LBlock) > 0, 'Soak stalled');
      Inc(LPulls);
      LUsed := GetFPCHeapStatus.CurrHeapUsed;
      if LPulls = 8 then LWarmHeap := LUsed;
      LMaximumHeap := Max(LMaximumHeap, LUsed);
    end;
    Require(LSession.Position = Int64(ASeconds) * AProfile.SampleRate,
      'Soak did not render complete requested duration');
    Require(LMaximumHeap <= LWarmHeap + 2 * 1024 * 1024,
      'Session live heap grew beyond two MiB after warmup');
    WriteLn('PASS actual rendered_seconds=', ASeconds, ' frames=', LSession.Position,
      ' elapsed_ms=', GetTickCount64 - LStart, ' pulls=', LPulls,
      ' source_reads=', LProbe.Reads, ' warm_heap=', LWarmHeap,
      ' max_live_heap=', LMaximumHeap, ' retained_output_frames=', Length(LBlock));
  finally
    LSession.Free;
    LProbe.Free;
  end;
end;

end.
