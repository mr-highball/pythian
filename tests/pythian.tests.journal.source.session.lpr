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
program pythian_tests_journal_source_session;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.learning,
  pythian.analysis.journal,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.binding,
  pythian.wfc.learning.profile,
  pythian.wfc.audio.stream;

type
  TProbe = class
    Channels: Integer;
    Reads: Integer;
    FailRead: Boolean;
    Tokens: TAcousticIndices;
    Windows: TJournalRepresentatives;
    function ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
    procedure Grain(const AOrdinal: Int64; const AToken: Integer;
      const ACandidate: TJournalRepresentative);
    procedure RejectWrite;
  end;

procedure Require(const ACondition: Boolean; const AWhy: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AWhy);
  end;
end;

function TProbe.ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
var
  LFrame: Integer;
  LChannel: Integer;
begin
  Inc(Reads);
  if FailRead then
  begin
    raise EAudio.Create('Authored source read failure');
  end;
  Result := nil;
  SetLength(Result, ACandidate.ValidFrames * Channels);
  for LFrame := 0 to ACandidate.ValidFrames - 1 do
  begin
    for LChannel := 0 to Channels - 1 do
    begin
      Result[LFrame * Channels + LChannel] :=
        0.25 * Sin((ACandidate.SourceFrame + LFrame) * 0.017 + LChannel * 0.3);
    end;
  end;
end;

procedure TProbe.Grain(const AOrdinal: Int64; const AToken: Integer;
  const ACandidate: TJournalRepresentative);
begin
  Require(AOrdinal = Length(Tokens), 'Session grain receipt order');
  SetLength(Tokens, Length(Tokens) + 1);
  SetLength(Windows, Length(Windows) + 1);
  Tokens[AOrdinal] := AToken;
  Windows[AOrdinal] := ACandidate;
end;

procedure TProbe.RejectWrite;
begin
  raise EAudio.Create('Session fixture journal is read-only');
end;

function TextFile(const APath: String): UTF8String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require(LStream.Size <= MaximumJournalProfileBytes, 'Fixture text exceeds metadata bound');
    SetLength(Result, Integer(LStream.Size));
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

function Render(const AProfile: TJournalModelProfile;
  const AIndex: TJournalSourceSuccessors; const APull: Integer;
  out ATokens: TAcousticIndices; out AWindows: TJournalRepresentatives): TAudioSamples;
var
  LSession: TJournalAudioSession;
  LProbe: TProbe;
  LBlock: TAudioSamples;
  LWeights: TJournalSelectionWeights;
  LFrames: Int64;
  LOffset: Integer;
begin
  Result := nil;
  LProbe := TProbe.Create;
  LSession := nil;
  try
    LProbe.Channels := AProfile.Channels;
    LWeights := TJournalSelectionWeights.Create(1);
    LFrames := AProfile.Options.WindowFrames +
      Int64(SessionChunkGrains + 10) * AProfile.Options.HopFrames;
    LSession := TJournalAudioSession.Create(AProfile, LProbe.ReadWindow,
      LWeights, 731, LFrames, LProbe.Grain, AIndex);
    while LSession.State <> assCompleted do
    begin
      LBlock := LSession.ReadFrames(APull);
      Require(Length(LBlock) > 0, 'Actual session made progress');
      LOffset := Length(Result);
      SetLength(Result, LOffset + Length(LBlock));
      Move(LBlock[0], Result[LOffset], Length(LBlock) * SizeOf(Single));
    end;
    Require((LSession.Position = LFrames) and (Length(LProbe.Tokens) = 139),
      'Actual session continues across fixed 128-grain WFC boundary');
    ATokens := Copy(LProbe.Tokens);
    AWindows := Copy(LProbe.Windows);
  finally
    LSession.Free;
    LProbe.Free;
  end;
end;

procedure Same(const ALeft, ARight: TAudioSamples;
  const ATokens, AOtherTokens: TAcousticIndices;
  const AWindows, AOtherWindows: TJournalRepresentatives);
var
  LIndex: Integer;
begin
  Require((Length(ALeft) = Length(ARight)) and
    CompareMem(@ALeft[0], @ARight[0], Length(ALeft) * SizeOf(Single)),
    'Session PCM byte replay across pull sizes');
  Require(Length(ATokens) = Length(AOtherTokens), 'Session token receipt count');
  for LIndex := 0 to High(ATokens) do
  begin
    Require((ATokens[LIndex] = AOtherTokens[LIndex]) and
      (AWindows[LIndex].SegmentIndex = AOtherWindows[LIndex].SegmentIndex) and
      (AWindows[LIndex].SourceFrame = AOtherWindows[LIndex].SourceFrame) and
      (AWindows[LIndex].ValidFrames = AOtherWindows[LIndex].ValidFrames),
      'Session actual-window receipt replay');
  end;
end;

procedure RejectProfile(const AProfile: TJournalModelProfile;
  const AIndex: TJournalSourceSuccessors; const AMode: Integer);
var
  LRoot: TJSONObject;
  LChanged: TJournalModelProfile;
  LProbe: TProbe;
  LSession: TJournalAudioSession;
  LVocabulary: String;
  LRejected: Boolean;
begin
  LRoot := TJSONObject(GetJSON(AProfile.EncodeReport));
  LChanged := nil;
  LSession := nil;
  LProbe := TProbe.Create;
  try
    if AMode = 0 then
    begin
      LRoot.Integers['sample_rate'] := AProfile.SampleRate + 1000;
      LVocabulary := AcousticVocabularySha256(AProfile.Palette, AProfile.Options,
        LRoot.Integers['sample_rate'], AProfile.Channels);
      LRoot.Strings['vocabulary_sha256'] := LVocabulary;
      LRoot.Strings['model_binding_sha256'] :=
        AcousticModelBindingSha256(LVocabulary, AProfile.ModelSha256);
    end
    else if AMode = 1 then
    begin
      LRoot.Arrays['sources'].Objects[0].Strings['source_sha256'] := StringOfChar('f', 64);
    end
    else
    begin
      LRoot.Arrays['sources'].Objects[0].Int64s['source_frames'] :=
        LRoot.Arrays['sources'].Objects[0].Int64s['source_frames'] - 1;
    end;
    LChanged := TJournalModelProfile.Create(LRoot.AsJSON, AProfile.EncodeModel);
    LRejected := False;
    try
      LSession := TJournalAudioSession.Create(LChanged, LProbe.ReadWindow,
        TJournalSelectionWeights.Create(1), 731, 10000, nil, AIndex);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Require(LRejected and (LProbe.Reads = 0),
      'Incompatible successor vocabulary/source/range rejects before source reads');
  finally
    LSession.Free;
    LProbe.Free;
    LChanged.Free;
    LRoot.Free;
  end;
end;

procedure CheckSession(const AProfile: TJournalModelProfile;
  const AIndex: TJournalSourceSuccessors);
var
  LBase: TAudioSamples;
  LReplay: TAudioSamples;
  LTokens: TAcousticIndices;
  LOtherTokens: TAcousticIndices;
  LBaseTokens: TAcousticIndices;
  LWindows: TJournalRepresentatives;
  LOtherWindows: TJournalRepresentatives;
  LBaseWindows: TJournalRepresentatives;
  LSlots: TAcousticIndices;
  LSelector: TJournalSelectionStream;
  LProbe: TProbe;
  LSession: TJournalAudioSession;
  LPosition: Integer;
  LRejected: Boolean;
  LReads: Integer;
begin
  LBase := Render(AProfile, nil, 113, LBaseTokens, LBaseWindows);
  LReplay := Render(AProfile, nil, 65536, LOtherTokens, LOtherWindows);
  Same(LBase, LReplay, LBaseTokens, LOtherTokens, LBaseWindows, LOtherWindows);
  LSelector := TJournalSelectionStream.Create(AProfile.Pool,
    TJournalSelectionWeights.Create(1), 731);
  try
    LSlots := LSelector.SelectChunk(LBaseTokens);
    for LPosition := 0 to High(LSlots) do
    begin
      Require(AProfile.Pool.CandidateAt(LSlots[LPosition]).SourceFrame =
        LBaseWindows[LPosition].SourceFrame, 'Nil session preserves sparse fallback');
    end;
  finally
    LSelector.Free;
  end;
  LBase := Render(AProfile, AIndex, 113, LTokens, LWindows);
  LReplay := Render(AProfile, AIndex, 65536, LOtherTokens, LOtherWindows);
  Same(LBase, LReplay, LTokens, LOtherTokens, LWindows, LOtherWindows);
  for LPosition := 0 to High(LTokens) do
  begin
    Require((LTokens[LPosition] = LBaseTokens[LPosition]) and
      (LWindows[LPosition].SegmentIndex = LBaseWindows[LPosition].SegmentIndex),
      'Successor session preserves generated WFC path and source share');
  end;
  for LPosition := 0 to 2 do
  begin
    RejectProfile(AProfile, AIndex, LPosition);
  end;
  LProbe := TProbe.Create;
  LSession := nil;
  try
    LProbe.Channels := AProfile.Channels;
    LProbe.FailRead := True;
    LSession := TJournalAudioSession.Create(AProfile, LProbe.ReadWindow,
      TJournalSelectionWeights.Create(1), 731, 10000, nil, AIndex);
    LRejected := False;
    try
      LSession.ReadFrames(113);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Require(LRejected and (LSession.State = assFailed),
      'Successor source callback failure poisons session');
    LReads := LProbe.Reads;
    LRejected := False;
    try
      LSession.ReadFrames(113);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Require(LRejected and (LProbe.Reads = LReads), 'Failed successor session never retries source');
  finally
    LSession.Free;
    LProbe.Free;
  end;
  WriteLn('PASS actual WFC session nil/successor block replay, 128-grain continuation, binding rejection and callback failure');
end;

procedure Run;
var
  LOuter: TJSONObject;
  LProfile: TJournalModelProfile;
  LStream: TFileStream;
  LJournal: TFeatureJournal;
  LReader: TJournalTrainingReader;
  LIndex: TJournalSourceSuccessors;
  LProbe: TProbe;
  LSegments: TJournalTrainingSegments;
begin
  Require(ParamCount = 3, 'Usage: PROFILE.json MODEL.wfcs READONLY.pyaf');
  LOuter := TJSONObject(GetJSON(TextFile(ParamStr(1))));
  LProfile := nil;
  LStream := nil;
  LJournal := nil;
  LReader := nil;
  LIndex := nil;
  LProbe := TProbe.Create;
  try
    LProfile := TJournalModelProfile.Create(LOuter.Objects['journal_profile'].AsJSON,
      TextFile(ParamStr(2)));
    Require(LProfile.SourceCount = 1, 'Fixture expects one frozen source range');
    LStream := TFileStream.Create(ParamStr(3), fmOpenRead or fmShareDenyWrite);
    LJournal := TFeatureJournal.Create(LStream, LProfile.SourceAt(0).Binding,
      LProbe.RejectWrite, False);
    SetLength(LSegments, 1);
    LSegments[0] := WholeJournalSegment(LJournal);
    LReader := TJournalTrainingReader.Create(LSegments);
    LIndex := TJournalSourceSuccessors.Create(LReader, LProfile.Palette);
    CheckSession(LProfile, LIndex);
  finally
    LIndex.Free;
    LReader.Free;
    LJournal.Free;
    LStream.Free;
    LProfile.Free;
    LProbe.Free;
    LOuter.Free;
  end;
end;

begin
  Run;
end.
