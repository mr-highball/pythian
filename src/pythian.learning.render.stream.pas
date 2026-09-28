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
unit pythian.learning.render.stream;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.learning,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.wave.stream;

const
  MaximumJournalStreamGrains = 32768;
  MaximumJournalStreamVisits: Int64 = 128000000;

type
  { Borrows its pool, callback and PCM16 writer. The writer must declare the
    exact total frame count returned by JournalStreamFrames. Each selection
    chunk is only an input block; Hann normalization continues across blocks.
    A callback or writer failure poisons this stream; discard its staged WAV. }
  TJournalWaveRenderStream = class
  private
    FPool: TJournalCandidatePool;
    FReadWindow: TJournalWindowRead;
    FWriter: TWavePcm16Writer;
    FChannels: Integer;
    FWindowFrames: Integer;
    FHopFrames: Integer;
    FExpectedGrains: Integer;
    FGrainCount: Integer;
    FFlushedFrames: Int64;
    FOutputFrames: Int64;
    FMix: array of Double;
    FWeights: array of Double;
    FBlock: TAudioSamples;
    FBlockFrames: Integer;
    FBufferedFrames: Integer;
    FPeak: Double;
    FFailed: Boolean;
    FFinished: Boolean;
    procedure FlushTo(const AFrame: Int64);
    procedure WriteBuffered;
    procedure AppendOne(const ASlot: Integer);
  public
    constructor Create(const APool: TJournalCandidatePool;
      const AReadWindow: TJournalWindowRead; const AWriter: TWavePcm16Writer;
      const AWindowFrames, AHopFrames, AExpectedGrains, ABlockFrames: Integer);
    procedure AppendSelection(const ASelection: TAcousticIndices);
    procedure Finish;
    property GrainCount: Integer read FGrainCount;
    property FlushedFrames: Int64 read FFlushedFrames;
    property Peak: Double read FPeak;
    property Failed: Boolean read FFailed;
    property Finished: Boolean read FFinished;
  end;

function JournalStreamFrames(const AWindowFrames, AHopFrames,
  AGrainCount: Integer): Int64;

implementation

uses
  Math;

function JournalStreamFrames(const AWindowFrames, AHopFrames,
  AGrainCount: Integer): Int64;
begin
  if (AWindowFrames < 1) or (AWindowFrames > 65536) or
    (AHopFrames < 1) or (AHopFrames > AWindowFrames) or
    (AGrainCount < 1) or (AGrainCount > MaximumJournalStreamGrains) then
  begin
    raise EAudio.Create('Journal stream geometry or grain count invalid');
  end;
  Result := Int64(AGrainCount - 1) * AHopFrames + AWindowFrames;
end;

constructor TJournalWaveRenderStream.Create(const APool: TJournalCandidatePool;
  const AReadWindow: TJournalWindowRead; const AWriter: TWavePcm16Writer;
  const AWindowFrames, AHopFrames, AExpectedGrains, ABlockFrames: Integer);
begin
  inherited Create;
  if (APool = nil) or not Assigned(AReadWindow) or (AWriter = nil) or
    (ABlockFrames < 1) or (ABlockFrames > 65536) then
  begin
    raise EAudio.Create('Journal stream requires pool, reader, writer and bounded block');
  end;
  FOutputFrames := JournalStreamFrames(AWindowFrames, AHopFrames, AExpectedGrains);
  if (Int64(AExpectedGrains) * AWindowFrames * AWriter.Channels >
      MaximumJournalStreamVisits) or
    (AWriter.ExpectedFrames <> FOutputFrames) or AWriter.Finished or AWriter.Failed or
    (AWriter.FrameCount <> 0) then
  begin
    raise EAudio.Create('Journal stream work or writer geometry invalid');
  end;
  FPool := APool;
  FReadWindow := AReadWindow;
  FWriter := AWriter;
  FChannels := AWriter.Channels;
  FWindowFrames := AWindowFrames;
  FHopFrames := AHopFrames;
  FExpectedGrains := AExpectedGrains;
  FBlockFrames := ABlockFrames;
  SetLength(FMix, AWindowFrames * FChannels);
  SetLength(FWeights, AWindowFrames);
  SetLength(FBlock, ABlockFrames * FChannels);
end;

procedure TJournalWaveRenderStream.WriteBuffered;
var
  LSamples: TAudioSamples;
begin
  if FBufferedFrames = 0 then
  begin
    Exit;
  end;
  if FBufferedFrames = FBlockFrames then
  begin
    FWriter.AppendSamples(FBlock);
  end
  else
  begin
    SetLength(LSamples, FBufferedFrames * FChannels);
    Move(FBlock[0], LSamples[0], Length(LSamples) * SizeOf(Single));
    FWriter.AppendSamples(LSamples);
  end;
  FBufferedFrames := 0;
end;

procedure TJournalWaveRenderStream.FlushTo(const AFrame: Int64);
var
  LRing: Integer;
  LChannel: Integer;
  LWeight: Double;
  LValue: Double;
begin
  if (AFrame < FFlushedFrames) or (AFrame > FOutputFrames) then
  begin
    raise EAudio.Create('Journal stream flush extent invalid');
  end;
  while FFlushedFrames < AFrame do
  begin
    LRing := FFlushedFrames mod FWindowFrames;
    LWeight := Max(1.0, FWeights[LRing]);
    for LChannel := 0 to FChannels - 1 do
    begin
      LValue := FMix[LRing * FChannels + LChannel] / LWeight;
      RequireFinite(LValue, 'Journal stream sample');
      if Abs(LValue) > 1 then
      begin
        raise EAudio.Create('Journal stream exceeds PCM16 headroom');
      end;
      FPeak := Max(FPeak, Abs(LValue));
      FBlock[FBufferedFrames * FChannels + LChannel] := LValue;
      FMix[LRing * FChannels + LChannel] := 0;
    end;
    FWeights[LRing] := 0;
    Inc(FBufferedFrames);
    Inc(FFlushedFrames);
    if FBufferedFrames = FBlockFrames then
    begin
      WriteBuffered;
    end;
  end;
end;

procedure TJournalWaveRenderStream.AppendOne(const ASlot: Integer);
var
  LCandidate: TJournalRepresentative;
  LSamples: TAudioSamples;
  LStart: Int64;
  LFrame: Integer;
  LChannel: Integer;
  LRing: Integer;
  LWeight: Double;
  LValue: Double;
begin
  LCandidate := FPool.CandidateAt(ASlot);
  LSamples := FReadWindow(LCandidate);
  if Length(LSamples) <> LCandidate.ValidFrames * FChannels then
  begin
    raise EAudio.Create('Journal stream callback returned a mismatched window');
  end;
  LStart := Int64(FGrainCount) * FHopFrames;
  for LFrame := 0 to FWindowFrames - 1 do
  begin
    LRing := (LStart + LFrame) mod FWindowFrames;
    LWeight := Sqr(Sin(Pi * (LFrame + 0.5) / FWindowFrames));
    FWeights[LRing] := FWeights[LRing] + LWeight;
    for LChannel := 0 to FChannels - 1 do
    begin
      LValue := 0;
      if LFrame < LCandidate.ValidFrames then
      begin
        LValue := LSamples[LFrame * FChannels + LChannel];
        RequireFinite(LValue, 'Journal stream source sample');
        if Abs(LValue) > 1 then
        begin
          raise EAudio.Create('Journal stream source exceeds PCM16 headroom');
        end;
      end;
      FMix[LRing * FChannels + LChannel] :=
        FMix[LRing * FChannels + LChannel] + LValue * LWeight;
    end;
  end;
  Inc(FGrainCount);
  FlushTo(Int64(FGrainCount) * FHopFrames);
end;

procedure TJournalWaveRenderStream.AppendSelection(const ASelection: TAcousticIndices);
var
  LSlot: Integer;
  LCandidate: TJournalRepresentative;
begin
  if FFailed or FFinished then
  begin
    raise EAudio.Create('Journal stream cannot continue after failure or finish');
  end;
  if (Length(ASelection) < 1) or
    (Length(ASelection) > FExpectedGrains - FGrainCount) then
  begin
    raise EAudio.Create('Journal stream selection count invalid');
  end;
  for LSlot in ASelection do
  begin
    LCandidate := FPool.CandidateAt(LSlot);
    if not LCandidate.Found or (LCandidate.ValidFrames < 1) or
      (LCandidate.ValidFrames > FWindowFrames) then
    begin
      raise EAudio.Create('Journal stream selection needs admitted source windows');
    end;
  end;
  try
    for LSlot in ASelection do
    begin
      AppendOne(LSlot);
    end;
  except
    FFailed := True;
    raise;
  end;
end;

procedure TJournalWaveRenderStream.Finish;
begin
  if FFailed or FFinished or (FGrainCount <> FExpectedGrains) then
  begin
    raise EAudio.Create('Journal stream is failed, finished or incomplete');
  end;
  try
    FlushTo(FOutputFrames);
    WriteBuffered;
    FWriter.Finish;
    FFinished := True;
  except
    FFailed := True;
    raise;
  end;
end;

end.
