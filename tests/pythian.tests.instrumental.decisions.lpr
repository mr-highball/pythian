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
program pythian_tests_instrumental_decisions;

{$mode delphi}
{$H+}

uses SysUtils, Math, pythian.audio, pythian.chord, pythian.time, pythian.progress,
  pythian.bus, pythian.echo, pythian.instrument, pythian.percussion, pythian.synth,
  pythian.oscillator, pythian.music.stream, pythian.music.decisions,
  pythian.music.replay, pythian.music.pattern, pythian.pitch.track,
  pythian.stream.bytes, pythian.hash,
  pythian.wfc.instrumental, pythian.wfc.instrumental.starter,
  pythian.wfc.instrumental.stream, pythian.wfc.percussion,
  pythian.wfc.musical.context, wfc_sequence, wfc_music_voices_graph;

type
  TCaptured = class
    Storage: TAudioBytesStream;
    Writer: TMusicDecisionWriter;
    Starter: TInstrumentalStarter;
    Definitions: TPercussionDefinitions;
    Holds: Integer;
    Chunks: Integer;
    Abort: Boolean;
    procedure Capture(const AChunk: TMusicDecisionChunk);
    constructor Create(const AStarter: TInstrumentalStarter);
    destructor Destroy; override;
  end;
var Checks: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not AValue then raise Exception.Create(AMessage);
end;

constructor TCaptured.Create(const AStarter: TInstrumentalStarter);
begin
  inherited Create;
  Starter := AStarter;
  Definitions := Starter.CopyPercussion(8000);
  Storage := TAudioBytesStream.Create(8388608);
  Writer := TMusicDecisionWriter.Create(Storage);
end;

destructor TCaptured.Destroy;
begin
  Writer.Free;
  Storage.Free;
  inherited Destroy;
end;

procedure TCaptured.Capture(const AChunk: TMusicDecisionChunk);
var LModel: TWfcSequenceModel; I, J, K: Integer; LNames: TInstrumentalRoles;
begin
  if Abort then raise EAudio.Create('Deliberate decision capture stop');
  Check(Length(AChunk.Providers) = 9, 'All context/H/R/pitched/drum decisions are retained');
  LNames := Starter.CopyRoles;
  for I := 0 to High(AChunk.Providers) do
  begin
    LModel := nil;
    if AChunk.Providers[I].Key = MusicalContextPassName then LModel := Starter.ContextModel;
    if AChunk.Providers[I].Key = 'harmony' then LModel := Starter.Config.HarmonyModel;
    if AChunk.Providers[I].Key = 'rhythm' then LModel := Starter.Config.RhythmModel;
    for J := 0 to High(LNames) do
      if AChunk.Providers[I].Key = LNames[J].Name then LModel := Starter.Config.Voices[J].Model;
    for J := 0 to High(Definitions) do
      if AChunk.Providers[I].Key = Definitions[J].Name then LModel := Definitions[J].Model;
    Check(LModel <> nil, 'Decision rows bind the actual ordered providers');
    for J := 0 to High(AChunk.Cells) do
    begin
      Check((AChunk.Providers[I].States[J] < LModel.StateCount) and
        (LModel.ProjectStateToken(AChunk.Providers[I].States[J]) =
          AChunk.Providers[I].Tokens[J]), 'Saved latent states project to the actual public tokens');
    end;
  end;
  if AChunk.FirstCell > 0 then
    for K := 0 to High(AChunk.Cells[0].Parts) do
      if AChunk.Cells[0].Parts[K].Action = caHold then Inc(Holds);
  Writer.Append(AChunk);
  Inc(Chunks);
end;

function Graph: TBusGraph;
var LSettings: array[0..6] of TBusSettings; LEcho: TEchoSettings; I: Integer;
begin
  for I := 0 to 6 do
  begin
    LSettings[I] := DefaultBusSettings;
    LSettings[I].Gain := 0.2;
  end;
  LSettings[6].Gain := 1;
  Result := TBusGraph.Create(8000, LSettings);
  for I := 0 to 5 do Result.AddSend(I, 6, stPostFader, 1, 0);
  LEcho := DefaultEchoSettings(8000);
  LEcho.DelayFrames := 311;
  Result.AddEffect(6, TEchoEffect.Create(8000, LEcho));
end;

procedure AddBlock(var AOutputs: TBusSampleBlocks; const ABlock: TBusSampleBlocks;
  const AAt: Integer);
var I, J: Integer;
begin
  for I := 0 to High(ABlock) do
    for J := 0 to High(ABlock[I]) do AOutputs[I][AAt + J] := ABlock[I][J];
end;

function Replay(const ABytes: TAudioBytes; const AStarter: TInstrumentalStarter;
  const AOptions: TInstrumentalStreamOptions; const AChanged: Boolean): TBusSampleBlocks;
var
  LGraph: TBusGraph;
  LStorage: TAudioBytesStream;
  LReplay: TMusicDecisionReplay;
  LBindings: TInstrumentStreamBindings;
  LRoles: TInstrumentalRoles;
  LDefinitions: TPercussionDefinitions;
  LDrums: array of TPercussionInstrument;
  LZones: TInstrumentZones;
  LChanged: TInstrument;
  LOptions: TInstrumentStreamOptions;
  LSamples: TAudioSamples;
  LBlock, LResult: TBusSampleBlocks;
  LAt, I: Integer;
begin
  LStorage := TAudioBytesStream.Create(8388608);
  LGraph := Graph;
  LReplay := nil;
  LChanged := nil;
  LRoles := AStarter.CopyRoles;
  LDefinitions := AStarter.CopyPercussion(8000);
  SetLength(LDrums, Length(LDefinitions));
  try
    SetLength(LBindings, Length(LRoles) + Length(LDefinitions));
    for I := 0 to High(LRoles) do
    begin
      LBindings[I].Instrument := LRoles[I].Instrument;
      LBindings[I].Bus := LRoles[I].OutputBus;
      LBindings[I].MaximumTones := 128;
    end;
    if AChanged then
    begin
      LZones := LRoles[0].Instrument.CopyZones;
      for I := 0 to High(LZones) do LZones[I].Voice.Shape := wsSquare;
      LChanged := TInstrument.Create(LZones);
      LBindings[0].Instrument := LChanged;
    end;
    for I := 0 to High(LDefinitions) do
    begin
      LDrums[I] := TPercussionInstrument.Create(8000, LDefinitions[I].Settings);
      LBindings[Length(LRoles) + I].Instrument := LDrums[I].Instrument;
      LBindings[Length(LRoles) + I].Bus := LDefinitions[I].OutputBus;
      LBindings[Length(LRoles) + I].MaximumTones := 1;
      LBindings[Length(LRoles) + I].GateFrames :=
        SampleFramesFromSeconds(LDefinitions[I].Settings.GateSeconds, 8000);
    end;
    WriteStreamBytesExact(LStorage, ABytes, 0, Length(ABytes));
    LStorage.Position := 0;
    LOptions := DefaultInstrumentStreamOptions(AOptions.MusicFrames);
    LOptions.TailFrames := AOptions.TailFrames;
    LOptions.Seed := AOptions.Seed;
    LReplay := TMusicDecisionReplay.Create(LStorage, LBindings, LGraph, LOptions);
    SetLength(LResult, 7);
    for I := 0 to 6 do SetLength(LResult[I], (AOptions.MusicFrames + AOptions.TailFrames) * 2);
    LAt := 0;
    while LReplay.ReadOutputs(173, [6, 0, 1, 2, 3, 4, 5], LSamples, LBlock) do
    begin
      AddBlock(LResult, LBlock, LAt);
      Inc(LAt, Length(LSamples));
    end;
    Check((LReplay.State = issCompleted) and (LAt = Length(LResult[0])),
      'Retained score completes through primary instruments without a model or solver');
    Result := LResult;
  finally
    LReplay.Free;
    for I := 0 to High(LDrums) do LDrums[I].Free;
    LChanged.Free;
    LGraph.Free;
    LStorage.Free;
  end;
end;

function Starter: TInstrumentalStarter;
var LPattern: TPitchPattern; I: Integer;
begin
  SetLength(LPattern, 8);
  for I := 0 to High(LPattern) do
  begin
    LPattern[I] := Default(TPitchPatternCell);
    LPattern[I].Kind := pskPitch;
    LPattern[I].Note := 60 + (I div 2) * 2;
    LPattern[I].Velocity := 80;
    LPattern[I].Attack := I mod 2 = 0;
  end;
  Result := TInstrumentalStarter.Create(0, False, LPattern);
end;

procedure Run;
var
  LStarter: TInstrumentalStarter;
  LGraph: TBusGraph;
  LStream: TInstrumentalMusicStream;
  LCaptured: TCaptured;
  LOptions: TInstrumentalStreamOptions;
  LBadOptions: TInstrumentalStreamOptions;
  LOriginal, LReplay, LChanged, LBlock: TBusSampleBlocks;
  LSamples: TAudioSamples;
  LBytes, LBadBytes: TAudioBytes;
  LChunk: TMusicDecisionChunk;
  LHash: String;
  LAt, I, J: Integer;
  LEqual, LDifferent, LRejected: Boolean;
begin
  LStarter := Starter;
  LGraph := Graph;
  LCaptured := TCaptured.Create(LStarter);
  LStream := nil;
  LOptions := DefaultInstrumentalStreamOptions(72017);
  LOptions.TailFrames := 800;
  LOptions.TempoMicroseconds := 500003;
  LOptions.SegmentCells := 15;
  try
    LStream := TInstrumentalMusicStream.Create(LStarter.Config, LStarter.CopyRoles,
      LStarter.CopyPercussion(8000), LGraph, LOptions, LStarter.ContextModel, LCaptured.Capture);
    SetLength(LOriginal, 7);
    for I := 0 to 6 do SetLength(LOriginal[I], LStream.FrameCount * 2);
    LAt := 0;
    while LStream.ReadOutputs(511, [6, 0, 1, 2, 3, 4, 5], LSamples, LBlock) do
    begin
      AddBlock(LOriginal, LBlock, LAt);
      Inc(LAt, Length(LSamples));
    end;
    Check((LStream.State = issCompleted) and (LCaptured.Writer.FrameCount = 72017) and
      (LCaptured.Writer.CellCount = LStream.TotalCells) and (LCaptured.Chunks = 3),
      'Actual WFC performance saves bounded decisions and its partial final cell');
    Check(LCaptured.Holds > 0, 'Actual continuation holds survive chunk boundaries');
    LChunk := LStream.CopyLastDecisions;
    LChunk.Cells[0].FrameCount := 1;
    Check(LStream.CopyLastDecisions.Cells[0].FrameCount <> 1,
      'Public stream chunk copies are detached');
    LHash := LCaptured.Writer.Seal;
    LBytes := LCaptured.Storage.Snapshot;
    Check(Sha256Bytes(LBytes) = LHash, 'Actual WFC journal digest binds all accepted decisions');
    LReplay := Replay(LBytes, LStarter, LOptions, False);
    LChanged := Replay(LBytes, LStarter, LOptions, True);
    for I := 0 to 6 do
    begin
      LEqual := True;
      LDifferent := False;
      for J := 0 to High(LOriginal[I]) do
      begin
        if LOriginal[I][J] <> LReplay[I][J] then LEqual := False;
        if LOriginal[I][J] <> LChanged[I][J] then LDifferent := True;
      end;
      Check(LEqual, 'Master and each actual part replay exactly across different pull sizes');
      if I <= 1 then Check(LDifferent, 'Changed bass instrument changes bass and master')
      else Check(not LDifferent, 'Unedited part PCM remains exact');
    end;
    Check(Sha256Bytes(LBytes) = LHash, 'Sound edits never mutate retained graph/score decisions');
    LBadOptions := LOptions;
    Dec(LBadOptions.MusicFrames);
    LRejected := False;
    try LReplay := Replay(LBytes, LStarter, LBadOptions, False);
    except on EAudio do LRejected := True; end;
    Check(LRejected, 'A changed declared music extent cannot silently truncate saved notes');
    LBadBytes := Copy(LBytes, 0, Length(LBytes) - 1);
    LRejected := False;
    try LReplay := Replay(LBadBytes, LStarter, LOptions, False);
    except on Exception do LRejected := True; end;
    Check(LRejected, 'Truncated saved decisions fail instead of completing a shorter performance');
    FreeAndNil(LStream);
    LGraph.Free;
    LGraph := Graph;
    LCaptured.Abort := True;
    LStream := TInstrumentalMusicStream.Create(LStarter.Config, LStarter.CopyRoles,
      LStarter.CopyPercussion(8000), LGraph, LOptions, LStarter.ContextModel, LCaptured.Capture);
    LRejected := False;
    try LStream.ReadOutputs(511, [], LSamples, LBlock);
    except on EAudio do LRejected := True; end;
    Check(LRejected and (LStream.State = issFailed) and (LStream.Position = 0) and
      (Length(LSamples) = 0) and (Length(LBlock) = 0),
      'Capture rejection publishes no failed PCM or completed performance');
    WriteLn('PASS instrumental decisions: ', Checks, ' checks');
  finally
    LStream.Free;
    LCaptured.Free;
    LGraph.Free;
    LStarter.Free;
  end;
end;

begin
  try Run;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
