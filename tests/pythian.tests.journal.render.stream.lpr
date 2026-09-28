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
program pythian_tests_journal_render_stream;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils,
  pythian.audio, pythian.wave, pythian.wave.stream,
  pythian.learning, pythian.learning.journal,
  pythian.learning.selection, pythian.learning.context,
  pythian.learning.render.stream;

type
  TProbe = class
    FailFeature: Integer;
    Gain: Single;
    function ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
  end;

function TProbe.ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
var
  LIndex: Integer;
begin
  if ACandidate.FeatureIndex = FailFeature then
  begin
    raise EAudio.Create('Deliberate source-read failure');
  end;
  Result := nil;
  SetLength(Result, ACandidate.ValidFrames);
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex] := Gain * (ACandidate.FeatureIndex + 1) * (LIndex - 3) / 32;
  end;
end;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function RenderStream(const APool: TJournalCandidatePool;
  const AProbe: TProbe; const ASelection: TAcousticIndices;
  const ABlockFrames, AChunkFrames: Integer;
  const AExplicit: Boolean = False): TAudioBytes;
var
  LMemory: TMemoryStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LRender: TJournalWaveRenderStream;
  LChunk: TAcousticIndices;
  LWindows: TJournalContextWindows;
  LOffset: Integer;
  LIndex: Integer;
  LCount: Integer;
begin
  Result := nil;
  LMemory := TMemoryStream.Create;
  LSink := nil;
  LWriter := nil;
  LRender := nil;
  try
    LSink := TStreamAudioSink.Create(LMemory);
    LWriter := TWavePcm16Writer.Create(LSink, 16000, 1,
      JournalStreamFrames(8, 4, Length(ASelection)));
    LRender := TJournalWaveRenderStream.Create(APool, AProbe.ReadWindow,
      LWriter, 8, 4, Length(ASelection), ABlockFrames);
    LOffset := 0;
    while LOffset < Length(ASelection) do
    begin
      LCount := AChunkFrames;
      if LCount > Length(ASelection) - LOffset then
      begin
        LCount := Length(ASelection) - LOffset;
      end;
      SetLength(LChunk, LCount);
      for LIndex := 0 to LCount - 1 do
      begin
        LChunk[LIndex] := ASelection[LOffset + LIndex];
      end;
      if AExplicit then
      begin
        SetLength(LWindows, LCount);
        for LIndex := 0 to LCount - 1 do
        begin
          LWindows[LIndex].Token := APool.TokenAt(LChunk[LIndex]);
          LWindows[LIndex].Candidate := APool.CandidateAt(LChunk[LIndex]);
        end;
        LRender.AppendWindows(LWindows);
      end
      else LRender.AppendSelection(LChunk);
      Inc(LOffset, LCount);
    end;
    LRender.Finish;
    Require(LRender.Finished and not LRender.Failed and
      (LWriter.FrameCount = JournalStreamFrames(8, 4, Length(ASelection))),
      'Stream did not finish exact frame count');
    SetLength(Result, LMemory.Size);
    if Length(Result) > 0 then
    begin
      LMemory.Position := 0;
      LMemory.ReadBuffer(Result[0], Length(Result));
    end;
  finally
    LRender.Free;
    LWriter.Free;
    LSink.Free;
    LMemory.Free;
  end;
end;

procedure CheckFailurePaths(const APool: TJournalCandidatePool; const AProbe: TProbe);
var
  LMemory: TMemoryStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LRender: TJournalWaveRenderStream;
  LSelection: TAcousticIndices;
  LWindows: TJournalContextWindows;
  LFailed: Boolean;
begin
  LFailed := False;
  try
    JournalStreamFrames(8, 9, 2);
  except
    on EAudio do LFailed := True;
  end;
  Require(LFailed, 'Invalid stream geometry was accepted');
  LMemory := TMemoryStream.Create;
  LSink := nil;
  LWriter := nil;
  LRender := nil;
  try
    LSink := TStreamAudioSink.Create(LMemory);
    LWriter := TWavePcm16Writer.Create(LSink, 16000, 1,
      JournalStreamFrames(8, 4, 2));
    LRender := TJournalWaveRenderStream.Create(APool, AProbe.ReadWindow,
      LWriter, 8, 4, 2, 3);
    SetLength(LSelection, 1);
    LSelection[0] := -1;
    LFailed := False;
    try
      LRender.AppendSelection(LSelection);
    except
      on EAudio do LFailed := True;
    end;
    Require(LFailed and (LRender.GrainCount = 0) and not LRender.Failed,
      'Invalid preflight mutated stream');
    SetLength(LWindows, 2);
    LWindows[0].Token := 0;
    LWindows[0].Candidate := APool.CandidateAt(3);
    LWindows[1] := LWindows[0];
    LWindows[1].Candidate.SourceFrame := -1;
    LFailed := False;
    try LRender.AppendWindows(LWindows)
    except on EAudio do LFailed := True end;
    Require(LFailed and (LRender.GrainCount = 0) and not LRender.Failed,
      'Malformed explicit window reached source reader');
    AProbe.FailFeature := 1;
    SetLength(LSelection, 2);
    LSelection[0] := 3;
    LSelection[1] := 1;
    LFailed := False;
    try
      LRender.AppendSelection(LSelection);
    except
      on EAudio do LFailed := True;
    end;
    Require(LFailed and LRender.Failed and (LRender.GrainCount = 1),
      'Source-read failure did not poison partial stream');
    LFailed := False;
    try
      LRender.Finish;
    except
      on EAudio do LFailed := True;
    end;
    Require(LFailed, 'Poisoned stream finished');
  finally
    AProbe.FailFeature := -1;
    LRender.Free;
    LWriter.Free;
    LSink.Free;
    LMemory.Free;
  end;
  LMemory := TMemoryStream.Create;
  LSink := nil;
  LWriter := nil;
  LRender := nil;
  try
    LSink := TStreamAudioSink.Create(LMemory);
    LWriter := TWavePcm16Writer.Create(LSink, 16000, 1,
      JournalStreamFrames(8, 4, 1));
    LRender := TJournalWaveRenderStream.Create(APool, AProbe.ReadWindow,
      LWriter, 8, 4, 1, 3);
    AProbe.Gain := 16;
    SetLength(LSelection, 1);
    LSelection[0] := 3;
    LFailed := False;
    try
      LRender.AppendSelection(LSelection);
    except
      on EAudio do LFailed := True;
    end;
    Require(LFailed and LRender.Failed, 'Excess source sample did not reject PCM16 headroom');
  finally
    AProbe.Gain := 1;
    LRender.Free;
    LWriter.Free;
    LSink.Free;
    LMemory.Free;
  end;
  LMemory := TMemoryStream.Create;
  LSink := nil;
  LWriter := nil;
  LRender := nil;
  try
    LSink := TStreamAudioSink.Create(LMemory);
    LWriter := TWavePcm16Writer.Create(LSink, 16000, 1,
      JournalStreamFrames(8, 4, 2));
    LRender := TJournalWaveRenderStream.Create(APool, AProbe.ReadWindow,
      LWriter, 8, 4, 2, 3);
    SetLength(LWindows, 2);
    LWindows[0].Token := APool.TokenAt(3);
    LWindows[0].Candidate := APool.CandidateAt(3);
    LWindows[1].Token := APool.TokenAt(1);
    LWindows[1].Candidate := APool.CandidateAt(1);
    AProbe.FailFeature := 1;
    LFailed := False;
    try LRender.AppendWindows(LWindows)
    except on EAudio do LFailed := True end;
    Require(LFailed and LRender.Failed and (LRender.GrainCount = 1),
      'Explicit callback failure did not poison partial stream');
  finally
    AProbe.FailFeature := -1;
    LRender.Free;
    LWriter.Free;
    LSink.Free;
    LMemory.Free;
  end;
end;

procedure CheckEqual(const ALeft, ARight: TAudioBytes; const AMessage: String);
var
  LIndex: Integer;
begin
  Require(Length(ALeft) = Length(ARight), AMessage + ': length');
  for LIndex := 0 to High(ALeft) do
  begin
    Require(ALeft[LIndex] = ARight[LIndex], AMessage + ': byte ' + IntToStr(LIndex));
  end;
end;

var
  LProbe: TProbe;
  LPool: TJournalCandidatePool;
  LCandidates: TJournalRepresentatives;
  LSelection: TAcousticIndices;
  LWhole: TAudioClip;
  LExpected: TAudioBytes;
  LActualA: TAudioBytes;
  LActualB: TAudioBytes;
  LExplicit: TAudioBytes;
  LIndex: Integer;
begin
  LProbe := TProbe.Create;
  LProbe.FailFeature := -1;
  LProbe.Gain := 1;
  LPool := nil;
  LWhole := nil;
  try
    SetLength(LCandidates, 4);
    for LIndex := 0 to High(LCandidates) do
    begin
      LCandidates[LIndex].Found := True;
      LCandidates[LIndex].SegmentIndex := LIndex div 2;
      LCandidates[LIndex].FeatureIndex := LIndex;
      LCandidates[LIndex].SourceFrame := LIndex * 8;
      LCandidates[LIndex].ValidFrames := 8;
    end;
    LPool := TJournalCandidatePool.CreateFromCandidates(1, 2, 2, LCandidates);
    SetLength(LSelection, 13);
    for LIndex := 0 to High(LSelection) do
    begin
      LSelection[LIndex] := LIndex mod 4;
    end;
    LWhole := RenderJournalSelection(LPool, LSelection, LProbe.ReadWindow,
      16000, 1, 8, 4);
    LExpected := EncodeWavePcm16(LWhole);
    LActualA := RenderStream(LPool, LProbe, LSelection, 3, 2);
    LActualB := RenderStream(LPool, LProbe, LSelection, 7, 5);
    LExplicit := RenderStream(LPool, LProbe, LSelection, 7, 5, True);
    CheckEqual(LExpected, LActualA, 'Whole versus streamed PCM');
    CheckEqual(LActualA, LActualB, 'Block and chunk invariance');
    CheckEqual(LActualA, LExplicit, 'Slot versus explicit window parity');
    LWhole.Free;
    LWhole := nil;
    SetLength(LSelection, 4103);
    for LIndex := 0 to High(LSelection) do
    begin
      LSelection[LIndex] := LIndex mod 4;
    end;
    LActualA := RenderStream(LPool, LProbe, LSelection, 13, 1031);
    LActualB := RenderStream(LPool, LProbe, LSelection, 97, 257);
    CheckEqual(LActualA, LActualB, 'Beyond-4096 block invariance');
    CheckFailurePaths(LPool, LProbe);
    WriteLn('PASS journal continuous PCM stream');
  finally
    LWhole.Free;
    LPool.Free;
    LProbe.Free;
  end;
end.
