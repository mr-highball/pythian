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
program InstrumentalEditStream;

{$mode delphi}
{$H+}

uses Classes, SysUtils, pythian.audio, pythian.chord, pythian.bus,
  pythian.progress, pythian.hash, pythian.music.form, pythian.music.controls,
  pythian.music.decisions, pythian.stream.bytes,
  pythian.wfc.layers, pythian.wfc.instrumental,
  pythian.wfc.instrumental.starter, pythian.wfc.instrumental.stream,
  pythian.wfc.instrumental.edit, pythian.wfc.instrumental.edit.stream,
  pythian.wfc.percussion, wfc_sequence_text, wfc_music_voices_graph;

type
  TObserver = class
    Writer: TMusicDecisionWriter;
    Normalized: TMusicDecisionWriter;
    Editor: TInstrumentalPassageStream;
    CancelReady: Boolean;
    ReentryRejected: Boolean;
    procedure Keep(const AChunk: TMusicDecisionChunk);
    procedure Observe(const AWork: TWorkProgress);
  end;

var Checks: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not AValue then raise EAudio.Create(AMessage);
end;

procedure TObserver.Keep(const AChunk: TMusicDecisionChunk);
var
  LNormalized: TMusicDecisionChunk;
  I: Integer;
begin
  Writer.Append(AChunk);
  LNormalized := CopyMusicDecisionChunk(AChunk);
  LNormalized.StartFrame := LNormalized.StartFrame * 3;
  for I := 0 to High(LNormalized.Cells) do
    LNormalized.Cells[I].FrameCount := LNormalized.Cells[I].FrameCount * 3;
  Normalized.Append(LNormalized);
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LAfter: TMusicDecisionChunk;
  LReport: TInstrumentalPassageReport;
begin
  if (Editor <> nil) and not ReentryRejected then
  begin
    try Editor.TryNext(LAfter, LReport);
    except on EAudio do ReentryRejected := True end;
  end;
  if Pos('learn', AWork.Stage) > 0 then
    raise EAudio.Create('Retained edit cannot learn again');
  if CancelReady and (AWork.Stage = 'instrumental_edit_ready') then
    raise EAbort.Create('Cancel provisional future before publishing its prefix');
end;

function Graph: TBusGraph;
var
  LSettings: array[0..6] of TBusSettings;
  I: Integer;
begin
  for I := 0 to 6 do LSettings[I] := DefaultBusSettings;
  Result := TBusGraph.Create(8000, LSettings);
  for I := 0 to 5 do Result.AddSend(I, 6, stPostFader, 1, 0);
end;

procedure Run;
var
  LStarter: TInstrumentalStarter;
  LGraph: TBusGraph;
  LSource: TInstrumentalMusicStream;
  LOptions: TInstrumentalStreamOptions;
  LForm: TMusicForm;
  LDrums: TPercussionDefinitions;
  LNames: TLayerNames;
  LBytes: TAudioBytesStream;
  LNormalized: TAudioBytesStream;
  LExpected: TAudioBytesStream;
  LWriter: TMusicDecisionWriter;
  LNormWriter: TMusicDecisionWriter;
  LReader: TMusicDecisionReader;
  LExpectedReader: TMusicDecisionReader;
  LEditor: TInstrumentalPassageStream;
  LObserver: TObserver;
  LEdit: TInstrumentalPassageEdit;
  LReport: TInstrumentalPassageReport;
  LBefore: TMusicDecisionChunk;
  LAfter: TMusicDecisionChunk;
  LConfig: TWfcMusicVoicesGraphConfig;
  LBlock: TAudioSamples;
  LOutputs: TBusSampleBlocks;
  LRoles: TInstrumentalRoles;
  LFrame: Int64;
  LSourceHash: String;
  LBeforeHash: String;
  LModelsBefore: String;
  LChanged: Integer;
  LReported: Integer;
  LCount: Integer;
  LInside: Boolean;
  LRejected: Boolean;
  I: Integer;
  J: Integer;
  function Models: String;
  var K: Integer;
  begin
    Result := EncodeWfcSequenceText(LStarter.Config.HarmonyModel) +
      EncodeWfcSequenceText(LStarter.Config.RhythmModel);
    for K := 0 to 2 do Result := Result + EncodeWfcSequenceText(LStarter.Config.Voices[K].Model);
    for K := 0 to 2 do Result := Result + EncodeWfcSequenceText(LDrums[K].Model);
  end;
begin
  LStarter := TInstrumentalStarter.Create;
  LGraph := Graph;
  LSource := nil;
  LBytes := TAudioBytesStream.Create(8388608);
  LNormalized := TAudioBytesStream.Create(8388608);
  LExpected := nil;
  LWriter := TMusicDecisionWriter.Create(LBytes);
  LNormWriter := TMusicDecisionWriter.Create(LNormalized);
  LReader := nil;
  LExpectedReader := nil;
  LEditor := nil;
  LObserver := TObserver.Create;
  try
    LObserver.Writer := LWriter;
    LObserver.Normalized := LNormWriter;
    LRoles := LStarter.CopyRoles;
    LDrums := LStarter.CopyPercussion(8000);
    SetLength(LNames, 3);
    for I := 0 to 2 do LNames[I] := LRoles[I].Name;
    SetLength(LForm, 3);
    for I := 0 to 2 do
    begin
      LForm[I].Name := 'Section ' + IntToStr(I);
      LForm[I].Section := LForm[I].Name;
      LForm[I].Cells := 64;
      LForm[I].RepeatFrom := -1;
    end;
    LForm[2].RepeatFrom := 0;
    LForm[2].Keep := ['harmony', 'rhythm', 'bass', 'harmony-voice', 'lead', 'kick', 'snare', 'hat'];
    LOptions := DefaultInstrumentalStreamOptions(8000 * 48);
    LOptions.Seed := 623803102;
    LSource := TInstrumentalMusicStream.Create(LStarter.Config, LRoles, LDrums,
      LGraph, LOptions, nil, LObserver.Keep, LForm, LStarter.GuideMasksRange);
    while LSource.ReadOutputs(2048, [], LBlock, LOutputs) do begin end;
    Check(LSource.PlannedCells = 192, 'Actual original 48 second arrangement completes');
    LSourceHash := LWriter.Seal;
    Check(LNormWriter.Seal = '11a4d055128d10559bde5cfc74d3e961b53218e650ec379cddcbd0a853f25220',
      'Sample-clock-normalized original exactly matches the actual failed Studio source journal');
    LModelsBefore := Models;
    LEdit := Default(TInstrumentalPassageEdit);
    LEdit.StartFrame := 8000 * 32;
    LEdit.EndFrame := 8000 * 48;
    LEdit.Seed := 1502445802;
    LEdit.MaxBacktracks := 256;
    LEdit.MaxPassBacktracks := 16;
    SetLength(LEdit.Parts, 6);
    LEdit.Parts[2] := True;
    SetLength(LEdit.Controls, 3);
    for I := 0 to 2 do LEdit.Controls[I] := DefaultMusicalPartControl;
    LBytes.Position := 0;
    LExpected := TAudioBytesReadStream.Create(LBytes.Snapshot);
    LReader := TMusicDecisionReader.Create(LBytes);
    LExpectedReader := TMusicDecisionReader.Create(LExpected);
    LConfig := CopyWfcMusicVoicesGraphConfig(LStarter.Config);
    LEditor := TInstrumentalPassageStream.Create(LConfig, LNames, LDrums, nil, LReader, 192, LEdit, 64);
    LObserver.Editor := LEditor;
    LEdit.Parts[2] := False;
    LConfig.Voices[2].MinPitch := 127;
    LChanged := 0;
    LReported := 0;
    LCount := 0;
    while LEditor.TryNext(LAfter, LReport, LObserver.Observe) do
    begin
      Check(LExpectedReader.TryNext(LBefore), 'Each edited prefix has a real source chunk');
      Check((LAfter.FirstCell = LBefore.FirstCell) and (LAfter.StartFrame = LBefore.StartFrame) and
        (Length(LAfter.Cells) = 16), 'Read-ahead preserves original published chunk sizes and clocks');
      LFrame := LBefore.StartFrame;
      for I := 0 to High(LAfter.Cells) do
      begin
        LInside := LFrame >= 8000 * 32;
        if not SameMusicDecisionFrame(LAfter.Cells[I].Parts, LBefore.Cells[I].Parts) then
        begin
          Inc(LChanged);
          Check(LInside, 'No outside-section musical decision changes');
        end;
        for J := 0 to High(LBefore.Providers) do
          if not LInside or (LBefore.Providers[J].Key <> 'lead') then
            Check((LBefore.Providers[J].States[I] = LAfter.Providers[J].States[I]) and
              (LBefore.Providers[J].Tokens[I] = LAfter.Providers[J].Tokens[I]),
              'Unrequested providers retain exact latent states and tokens across every prefix');
        Inc(LFrame, LBefore.Cells[I].FrameCount);
      end;
      Inc(LReported, LReport.ChangedCells);
      Inc(LCount);
      if LAfter.FirstCell = 112 then
      begin
        LAfter.Providers[0].Tokens[0] := 'caller owns its output';
        LAfter.Cells[15].Parts[2].Tones[0].Pitch := 0;
      end;
    end;
    Check((LEditor.State = ipesCompleted) and (LCount = 12) and (LEditor.Position = 192),
      'Original failed request and seed complete after proving known future accompaniment');
    Check((LChanged > 0) and (LChanged = LReported), 'Report counts actual published changes only');
    Check((LEditor.MaximumWindowCells = 64) and (LEditor.WindowLimit = 64) and
      (LEditor.MaximumBufferedCells = 80) and (LEditor.MaximumBufferedCells < 192),
      'Future proof and journal read-ahead obey fixed musical/state budgets');
    Check(LObserver.ReentryRejected, 'Borrowed callbacks cannot reenter the primary edit iterator');
    Check(Models = LModelsBefore, 'All borrowed musical models remain unchanged');
    Check(Sha256Bytes(LBytes.Snapshot) = Sha256Bytes(LExpected.Snapshot), 'Original source bytes stay unchanged');
    Check(LSourceHash <> '', 'Original source remains sealed');
    FreeAndNil(LEditor);
    FreeAndNil(LReader);
    LObserver.Editor := nil;
    LBytes.Position := 0;
    LReader := TMusicDecisionReader.Create(LBytes);
    LEdit.Parts[2] := True;
    LEditor := TInstrumentalPassageStream.Create(LStarter.Config, LNames, LDrums,
      nil, LReader, 192, LEdit);
    LObserver.Editor := LEditor;
    LObserver.CancelReady := True;
    LRejected := False;
    try
      while LEditor.TryNext(LAfter, LReport, LObserver.Observe) do
        LBeforeHash := Sha256Bytes(EncodeMusicDecisions(LAfter));
    except on EAbort do LRejected := True end;
    Check(LRejected and (LEditor.State = ipesFailed) and (LEditor.Position = 128),
      'Cancelling a provisional future proof publishes no part of its current prefix');
    Check(Sha256Bytes(EncodeMusicDecisions(LAfter)) = LBeforeHash,
      'Failed future proof preserves the caller’s previously accepted output');
    Check(not LEditor.TryNext(LAfter, LReport), 'Failed iterator cannot continue from partial proof');
    Check(Models = LModelsBefore, 'Cancellation restores all original model preferences');
    WriteLn('PASS ', Checks, ' instrumental edit stream checks; changes=', LChanged);
  finally
    LEditor.Free;
    LExpectedReader.Free;
    LReader.Free;
    LExpected.Free;
    LNormWriter.Free;
    LWriter.Free;
    LBytes.Free;
    LNormalized.Free;
    LSource.Free;
    LObserver.Free;
    LGraph.Free;
    LStarter.Free;
  end;
end;

begin
  try Run except on E: Exception do
  begin WriteLn('FAIL ', E.ClassName, ': ', E.Message); ExitCode := 1 end end;
end.
