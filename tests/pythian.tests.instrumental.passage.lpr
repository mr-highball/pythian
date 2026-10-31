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
program InstrumentalPassage;

{$mode delphi}
{$H+}

uses Classes, SysUtils, pythian.audio, pythian.time, pythian.bus, pythian.chord,
  pythian.hash, pythian.progress, pythian.instrument, pythian.percussion,
  pythian.music.stream, pythian.music.replay, pythian.music.controls,
  pythian.music.decisions, pythian.stream.bytes,
  pythian.wfc.instrumental, pythian.wfc.instrumental.starter,
  pythian.wfc.instrumental.stream, pythian.wfc.instrumental.edit,
  pythian.wfc.layers, pythian.wfc.voices, pythian.wfc.percussion,
  pythian.wfc.providers,
  pythian.wfc.musical.context,
  wfc, wfc_model, wfc_sequence, wfc_sequence_graph, wfc_sequence_learn,
  wfc_music, wfc_music_sequence, wfc_music_ensemble, wfc_music_voices_graph;

type
  TChunks = array of TMusicDecisionChunk;
  TCapture = class
    Chunks: TChunks;
    RejectReady: Boolean;
    procedure Keep(const AChunk: TMusicDecisionChunk);
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  Checks: Integer;
  Callbacks: Integer;
  LastStage: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure TCapture.Keep(const AChunk: TMusicDecisionChunk);
begin
  SetLength(Chunks, Length(Chunks) + 1);
  Chunks[High(Chunks)] := CopyMusicDecisionChunk(AChunk);
end;

procedure TCapture.Observe(const AWork: TWorkProgress);
begin
  LastStage := AWork.Stage;
  Inc(Callbacks);
  if Pos('learn', AWork.Stage) > 0 then
  begin
    raise EAudio.Create('Retained edits must never invoke learning');
  end;
  if RejectReady and (AWork.Stage = 'instrumental_edit_ready') then
  begin
    raise EAbort.Create('Reject final edit publication');
  end;
end;

function Graph: TBusGraph;
var
  LSettings: array[0..6] of TBusSettings;
  I: Integer;
begin
  for I := 0 to 6 do
  begin
    LSettings[I] := DefaultBusSettings;
    LSettings[I].Gain := 0.2;
  end;
  LSettings[6].Gain := 1;
  Result := TBusGraph.Create(8000, LSettings);
  for I := 0 to 5 do
  begin
    Result.AddSend(I, 6, stPostFader, 1, 0);
  end;
end;

function Journal(const AChunks: TChunks): TAudioBytes;
var
  LBytes: TAudioBytesStream;
  LWriter: TMusicDecisionWriter;
  LChunk: TMusicDecisionChunk;
  LPrevious: TChordFrame;
  I: Integer;
begin
  LBytes := TAudioBytesStream.Create(8388608);
  LWriter := TMusicDecisionWriter.Create(LBytes);
  LPrevious := CopyChordFrame(AChunks[0].Previous);
  try
    for I := 0 to High(AChunks) do
    begin
      LChunk := CopyMusicDecisionChunk(AChunks[I]);
      LChunk.Previous := CopyChordFrame(LPrevious);
      LWriter.Append(LChunk);
      LPrevious := CopyChordFrame(LChunk.Cells[High(LChunk.Cells)].Parts);
    end;
    LWriter.Seal;
    Result := LBytes.Snapshot;
  finally
    LWriter.Free;
    LBytes.Free;
  end;
end;

function Render(const ABytes: TAudioBytes; const AStarter: TInstrumentalStarter;
  const ADefinitions: TPercussionDefinitions; const AMusicFrames: Int64): TBusSampleBlocks;
var
  LBytes: TAudioBytesStream;
  LGraph: TBusGraph;
  LReplay: TMusicDecisionReplay;
  LBindings: TInstrumentStreamBindings;
  LRoles: TInstrumentalRoles;
  LDrums: array of TPercussionInstrument;
  LOptions: TInstrumentStreamOptions;
  LMaster: TAudioSamples;
  LBlock: TBusSampleBlocks;
  LResult: TBusSampleBlocks;
  I: Integer;
  J: Integer;
  LAt: Integer;
begin
  LBytes := TAudioBytesStream.Create(8388608);
  LGraph := Graph;
  LReplay := nil;
  LRoles := AStarter.CopyRoles;
  SetLength(LBindings, 6);
  SetLength(LDrums, 3);
  try
    for I := 0 to 2 do
    begin
      LBindings[I].Instrument := LRoles[I].Instrument;
      LBindings[I].Bus := I;
      LBindings[I].MaximumTones := 128;
      LDrums[I] := TPercussionInstrument.Create(8000, ADefinitions[I].Settings);
      LBindings[I + 3].Instrument := LDrums[I].Instrument;
      LBindings[I + 3].Bus := I + 3;
      LBindings[I + 3].MaximumTones := 1;
      LBindings[I + 3].GateFrames :=
        SampleFramesFromSeconds(ADefinitions[I].Settings.GateSeconds, 8000);
    end;
    WriteStreamBytesExact(LBytes, ABytes, 0, Length(ABytes));
    LBytes.Position := 0;
    LOptions := DefaultInstrumentStreamOptions(AMusicFrames);
    LOptions.TailFrames := 800;
    LReplay := TMusicDecisionReplay.Create(LBytes, LBindings, LGraph, LOptions);
    SetLength(LResult, 7);
    for I := 0 to High(LResult) do
    begin
      SetLength(LResult[I], (AMusicFrames + 800) * 2);
    end;
    LAt := 0;
    while LReplay.ReadOutputs(511, [6, 0, 1, 2, 3, 4, 5], LMaster, LBlock) do
    begin
      for I := 0 to High(LBlock) do
      begin
        for J := 0 to High(LBlock[I]) do
        begin
          LResult[I][LAt + J] := LBlock[I][J];
        end;
      end;
      Inc(LAt, Length(LMaster));
    end;
    Check(LReplay.State = issCompleted, 'Edited actual decisions complete through Pythian instruments');
    Result := LResult;
  finally
    LReplay.Free;
    for I := 0 to High(LDrums) do
    begin
      LDrums[I].Free;
    end;
    LGraph.Free;
    LBytes.Free;
  end;
end;

procedure Run;
var
  LStarter: TInstrumentalStarter;
  LGraph: TBusGraph;
  LStream: TInstrumentalMusicStream;
  LCapture: TCapture;
  LOptions: TInstrumentalStreamOptions;
  LEdit: TInstrumentalPassageEdit;
  LReport: TInstrumentalPassageReport;
  LRoles: TInstrumentalRoles;
  LNames: TLayerNames;
  LDrums: TPercussionDefinitions;
  LMasks: TVoiceMasks;
  LMask: TWfcSequenceTokenConstraint;
  LAfter: TMusicDecisionChunk;
  LTampered: TMusicDecisionChunk;
  LAcross: TMusicDecisionChunk;
  LAcrossLast: TMusicDecisionChunk;
  LEdges: TInstrumentalPassageEdges;
  LEdited: TChunks;
  LMaster: TAudioSamples;
  LOutputs: TBusSampleBlocks;
  LBeforePcm: TBusSampleBlocks;
  LAfterPcm: TBusSampleBlocks;
  LBeforeBytes: TAudioBytes;
  LAfterBytes: TAudioBytes;
  I: Integer;
  J: Integer;
  LChanged: Boolean;
  LRejected: Boolean;
  LConfig: TWfcMusicVoicesGraphConfig;
  LLead: TWfcSequenceModel;
  LSamples: TWfcSequenceSamples;
  LCellFrame: TWfcMusicEnsembleFrame;
  LTokens: TWfcModelTokens;
  LContext: TWfcSequenceModel;
  LContextCell: TMusicalContextCell;
  LPartFrame: TWfcMusicEnsembleFrame;
  LAcceptedChunkHash: String;
  LBound: TVoiceMasks;
  K: Integer;
  function Edges(const APrevious, ANext: Integer): TInstrumentalPassageEdges;
  var
    LPrevious: TMusicDecisionChunk;
    LNext: TMusicDecisionChunk;
  begin
    LPrevious := Default(TMusicDecisionChunk);
    LNext := Default(TMusicDecisionChunk);
    if APrevious >= 0 then LPrevious := LCapture.Chunks[APrevious];
    if ANext >= 0 then LNext := LCapture.Chunks[ANext];
    Result := RetainedInstrumentalPassageEdges(LPrevious, LNext);
  end;
  procedure CheckChildPreferences;
  var
    LPrivate: TGraph;
    LScope: TSequencePreferenceScope;
    LBounds: TWfcMusicVoicesBoundaries;
    LKeys: TGraphValues;
    LHarmonyKeys: TGraphValues;
    LOld: array of TGraphWeight;
    LHarmonyWeight: TGraphWeight;
    LToken: String;
    LExpected: TGraphWeight;
    P: Integer;
  begin
    SetLength(LBounds, 5);
    for P := 0 to 4 do LBounds[P] := MakeWfcSequenceInitialSegmentBoundary(False);
    LPrivate := BuildWfcMusicVoicesSegmentGraph(LConfig, 4, 73, LBounds);
    LScope := nil;
    try
      LKeys := LPrivate.PassGraph[1].CopyRegisteredValues;
      LHarmonyKeys := LPrivate.PassGraph[0].CopyRegisteredValues;
      LHarmonyWeight := LPrivate.PassGraph[0].Rules[LHarmonyKeys[0]].Weight;
      SetLength(LOld, Length(LKeys));
      for P := 0 to High(LKeys) do LOld[P] := LPrivate.PassGraph[1].Rules[LKeys[P]].Weight;
      LToken := LConfig.RhythmModel.PublicTokenAt(0);
      LScope := TSequencePreferenceScope.Create(LConfig.RhythmModel, LPrivate.PassGraph[1],
        [MakeLayerTokenPreference(LToken, 2)], LCapture.Observe);
      for P := 0 to High(LKeys) do
      begin
        LExpected := LOld[P];
        if LConfig.RhythmModel.ProjectStateToken(P) = LToken then LExpected := LExpected * 2;
        Check(LPrivate.PassGraph[1].Rules[LKeys[P]].Weight = LExpected,
          'Shared preference scope targets the supplied child pass');
      end;
      Check(LPrivate.PassGraph[0].Rules[LHarmonyKeys[0]].Weight = LHarmonyWeight,
        'Child-pass preferences do not write through to parent pass zero');
      FreeAndNil(LScope);
      for P := 0 to High(LKeys) do
        Check(LPrivate.PassGraph[1].Rules[LKeys[P]].Weight = LOld[P],
          'Shared child preference scope restores every original weight');
    finally
      LScope.Free;
      LPrivate.Free;
    end;
  end;
begin
  LStarter := TInstrumentalStarter.Create(0);
  LLead := nil;
  LContext := nil;
  LCapture := TCapture.Create;
  LGraph := Graph;
  LStream := nil;
  try
    { Explicit authored alternative: both C octaves fit the same held harmony.
      Alternating and repeated pairs provide actual order-two transitions;
      a hard octave request must change the result without inventing edges. }
    SetLength(LTokens, 4);
    SetLength(LCellFrame.Voices, 1);
    for I := 0 to 3 do
    begin
      if I mod 2 = 0 then
        LCellFrame.Voices[0] := MakeWfcMusicVoiceCell(wmcaAttack,
          [MakeWfcMusicTone(72 + (I div 2) * 12, 84)])
      else
        LCellFrame.Voices[0] := MakeWfcMusicVoiceCell(wmcaHold,
          [MakeWfcMusicTone(72 + (I div 2) * 12, 84)]);
      LTokens[I] := EncodeWfcMusicEnsembleFrame(LCellFrame);
    end;
    SetLength(LSamples, 2);
    LSamples[0].Tokens := [LTokens[0], LTokens[1], LTokens[0], LTokens[1],
      LTokens[2], LTokens[3], LTokens[2], LTokens[3], LTokens[0], LTokens[1]];
    LSamples[1].Tokens := [LTokens[2], LTokens[3], LTokens[0], LTokens[1],
      LTokens[2], LTokens[3], LTokens[2], LTokens[3], LTokens[0], LTokens[1]];
    LLead := LearnSequenceModelCorpus(LSamples, 2, wmbOpen);
    LConfig := LStarter.Config;
    LConfig.Voices := Copy(LConfig.Voices);
    LConfig.Voices[2].Model := LLead;
    CheckChildPreferences;
    LRoles := LStarter.CopyRoles;
    LDrums := LStarter.CopyPercussion(8000);
    SetLength(LNames, Length(LRoles));
    for I := 0 to High(LNames) do
    begin
      LNames[I] := LRoles[I].Name;
    end;
    LOptions := DefaultInstrumentalStreamOptions(16000);
    LOptions.TailFrames := 800;
    LOptions.SegmentCells := 4;
    LastStage := 'construct source stream';
    LStream := TInstrumentalMusicStream.Create(LConfig, LRoles, LDrums,
      LGraph, LOptions, nil, LCapture.Keep);
    LMasks := LStarter.GuideMasks(8);
    for I := 0 to High(LMasks) do
    begin
      for LMask in LMasks[I] do
      begin
        LStream.IntersectFutureTokens(I, LMask.Position, LMask.AllowedTokens);
      end;
    end;
    for I := 0 to 7 do
    begin
      LStream.IntersectFutureTokens(4, I, [LTokens[I mod 2]]);
    end;
    while LStream.ReadOutputs(511, [], LMaster, LOutputs, LCapture.Observe) do
    begin
    end;
    Check((LStream.State = issCompleted) and (Length(LCapture.Chunks) = 2),
      'Actual generated source retains two bounded musical chunks');
    LEdit := Default(TInstrumentalPassageEdit);
    LEdit.StartFrame := 8000;
    LEdit.EndFrame := 16000;
    LEdit.Seed := 991;
    LEdit.MaxBacktracks := 256;
    LEdit.MaxPassBacktracks := 16;
    SetLength(LEdit.Parts, 6);
    LEdit.Parts[2] := True;
    SetLength(LEdit.Controls, 3);
    for I := 0 to 2 do
    begin
      LEdit.Controls[I] := DefaultMusicalPartControl;
    end;
    LEdit.Controls[2].MinimumPitch := 84;
    LEdit.Controls[2].MaximumPitch := 84;
    LAfter := Default(TMusicDecisionChunk);
    LastStage := 'edit retained source';
    Check(TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, nil,
      LCapture.Chunks[1], Edges(0, -1), LEdit, LAfter,
      LReport, LCapture.Observe), 'Actual selected Lead passage fits the retained graph: ' + LReport.Detail);
    LEdited := Copy(LCapture.Chunks);
    LEdited[1] := LAfter;
    Check(LReport.ChangedCells > 0, 'Requested octave changes actual Lead decisions');
    for I := 0 to High(LAfter.Providers) do
    begin
      if I = 4 then
      begin
        Continue;
      end;
      for J := 0 to High(LAfter.Cells) do
      begin
        Check((LAfter.Providers[I].States[J] = LCapture.Chunks[1].Providers[I].States[J]) and
          (LAfter.Providers[I].Tokens[J] = LCapture.Chunks[1].Providers[I].Tokens[J]),
          'Other actual provider states/tokens remain exact');
      end;
    end;
    LBeforeBytes := Journal(LCapture.Chunks);
    LAfterBytes := Journal(LEdited);
    LAcceptedChunkHash := Sha256Bytes(EncodeMusicDecisions(LAfter));
    Check(Sha256Bytes(LBeforeBytes) <> Sha256Bytes(LAfterBytes), 'Changed notes acquire a different journal identity');
    LBeforePcm := Render(LBeforeBytes, LStarter, LDrums, 16000);
    LAfterPcm := Render(LAfterBytes, LStarter, LDrums, 16000);
    for I := 0 to High(LBeforePcm) do
    begin
      LChanged := False;
      for J := 0 to High(LBeforePcm[I]) do
      begin
        LChanged := LChanged or (LBeforePcm[I][J] <> LAfterPcm[I][J]);
      end;
      if (I = 0) or (I = 3) then
      begin
        Check(LChanged, 'Selected Lead and actual instrumental mix change');
      end
      else
      begin
        Check(not LChanged, 'Unselected actual instrumental stems remain exact');
      end;
    end;
    LCapture.RejectReady := True;
    LRejected := False;
    try
      TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, nil,
        LCapture.Chunks[1], Edges(0, -1), LEdit, LAfter,
        LReport, LCapture.Observe);
    except
      on E: EAbort do LRejected := True;
    end;
    Check(LRejected and (Sha256Bytes(EncodeMusicDecisions(LAfter)) = LAcceptedChunkHash),
      'Final edit cancellation preserves the caller and accepted journal');
    LCapture.RejectReady := False;
    LEdit.Controls[2].MinimumPitch := 1;
    LEdit.Controls[2].MaximumPitch := 2;
    LRejected := False;
    try
      LRejected := not TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, nil,
        LCapture.Chunks[1], Edges(0, -1), LEdit, LAfter,
        LReport, LCapture.Observe);
    except
      on E: EAudio do LRejected := True;
    end;
    Check(LRejected and (Sha256Bytes(EncodeMusicDecisions(LAfter)) = LAcceptedChunkHash),
      'Contradictory pitch choices are not silently relaxed');
    Check(Sha256Bytes(Journal(LCapture.Chunks)) = Sha256Bytes(LBeforeBytes),
      'All edit attempts preserve the original accepted source');

    LEdit.Controls[2].MinimumPitch := 72;
    LEdit.Controls[2].MaximumPitch := 84;
    LEdit.StartFrame := 1;
    LEdit.EndFrame := 5999;
    Check(TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, nil,
      LCapture.Chunks[0], Edges(-1, 1), LEdit, LAfter,
      LReport, LCapture.Observe), 'Initial partial passage reconnects to its recorded successor');
    Check((LReport.ActualStartFrame = 0) and (LReport.ActualEndFrame = 6000),
      'Fractional-step selection reports actual outward musical bounds');
    for I := 3 to 3 do
    begin
      Check(SameMusicDecisionFrame(LAfter.Cells[I].Parts, LCapture.Chunks[0].Cells[I].Parts),
        'Outside-range notes stay exact inside the edited planning chunk');
      for J := 0 to High(LAfter.Providers) do
      begin
        Check(LAfter.Providers[J].States[I] = LCapture.Chunks[0].Providers[J].States[I],
          'Outside-range latent states stay exact inside the edited chunk');
      end;
    end;
    LAcceptedChunkHash := Sha256Bytes(EncodeMusicDecisions(LAfter));
    LEdit.EndFrame := 8000;
    LEdit.Controls[2].MinimumPitch := 84;
    Check(not TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, nil,
      LCapture.Chunks[0], Edges(-1, 1), LEdit, LAfter,
      LReport, LCapture.Observe), 'Conflicting recorded outgoing latent seam rejects the edit');
    Check((LReport.Detail <> '') and
      (Sha256Bytes(EncodeMusicDecisions(LAfter)) = LAcceptedChunkHash),
      'Outgoing-seam rejection explains the conflict and preserves accepted candidate');

    LEdit.StartFrame := 0;
    LEdit.EndFrame := 16000;
    LEdges := Edges(-1, 1);
    LEdges.FollowingCells := 4;
    Check(TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, nil,
      LCapture.Chunks[0], LEdges, LEdit, LAcross,
      LReport, LCapture.Observe), 'Planning chunks must not lock decisions inside the selected passage');
    LEdges := Edges(0, -1);
    LEdges.CandidatePrevious := LAcross;
    Check(TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, nil,
      LCapture.Chunks[1], LEdges, LEdit, LAcrossLast, LReport, LCapture.Observe),
      'Changed decisions continue across the original planning seam');
    Check((LReport.ChangedCells = 4) and
      SameMusicDecisionFrame(LAcrossLast.Previous, LAcross.Cells[High(LAcross.Cells)].Parts),
      'Continued candidate retains its actual changed predecessor');
    LEdited := [LAcross, LAcrossLast];
    LAfterPcm := Render(Journal(LEdited), LStarter, LDrums, 16000);
    for I := 0 to High(LBeforePcm) do
    begin
      LChanged := False;
      for J := 0 to High(LBeforePcm[I]) do
        LChanged := LChanged or (LBeforePcm[I][J] <> LAfterPcm[I][J]);
      Check(LChanged = ((I = 0) or (I = 3)),
        'Cross-chunk variation changes only actual Lead/mix audio');
    end;

    LEdit.StartFrame := 8000;
    LEdit.EndFrame := 16000;
    LEdit.Parts[2] := False;
    LEdit.Parts[5] := True;
    LEdit.Controls[2] := DefaultMusicalPartControl;
    LDrums[2].Enabled := False;
    Check(TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, nil,
      LCapture.Chunks[1], Edges(0, -1), LEdit, LAfter,
      LReport, LCapture.Observe), 'Selected Hat can be regenerated to explicit silence');
    Check(LReport.ChangedCells > 0, 'Disabled selected Hat changes existing hits');
    LEdited := Copy(LCapture.Chunks);
    LEdited[1] := LAfter;
    LAfterPcm := Render(Journal(LEdited), LStarter, LDrums, 16000);
    for I := 0 to High(LBeforePcm) do
    begin
      LChanged := False;
      for J := 0 to High(LBeforePcm[I]) do
      begin
        LChanged := LChanged or (LBeforePcm[I][J] <> LAfterPcm[I][J]);
      end;
      Check(LChanged = ((I = 0) or (I = 6)),
        'Actual Hat edit changes mix/Hat and preserves the other five instrumental stems');
    end;
    LDrums[2].Enabled := True;
    LEdit.Parts[2] := True;
    LEdit.Parts[5] := False;

    { Real paired context provider, built from explicit authored alternatives.
      It has the same nine-provider layout as ordinary learned Studio jobs. }
    SetLength(LSamples, 4);
    for I := 0 to 3 do
    begin
      SetLength(LSamples[I].Tokens, 8);
      for J := 0 to 7 do
      begin
        LContextCell := Default(TMusicalContextCell);
        LContextCell.DrivenRole := -1;
        SetLength(LContextCell.Frame.Voices, 3);
        for K := 0 to 2 do
        begin
          LPartFrame := DecodeWfcMusicEnsembleFrame(
            LCapture.Chunks[J div 4].Providers[2 + K].Tokens[J mod 4]);
          LContextCell.Frame.Voices[K] := LPartFrame.Voices[0];
        end;
        if ((I = 1) and (J >= 6)) or (I = 2) or ((I = 3) and (J < 6)) then
        begin
          LPartFrame := DecodeWfcMusicEnsembleFrame(LTokens[2 + J mod 2]);
          LContextCell.Frame.Voices[2] := LPartFrame.Voices[0];
        end;
        LSamples[I].Tokens[J] := EncodeMusicalContextToken(LContextCell);
        if I = 0 then
        begin
          LBound := BindMusicalContextTokens([LSamples[I].Tokens[J]], 3, nil, True);
          for K := 0 to 4 do
          begin
            Check(LBound[K][0].AllowedTokens[0] =
              LCapture.Chunks[J div 4].Providers[K].Tokens[J mod 4],
              'Authored context projects exactly to its accepted source');
          end;
        end;
      end;
    end;
    LContext := LearnSequenceModelCorpus(LSamples, 2, wmbOpen);
    FreeAndNil(LStream);
    FreeAndNil(LGraph);
    LGraph := Graph;
    LCapture.Chunks := nil;
    LStream := TInstrumentalMusicStream.Create(LConfig, LRoles, LDrums,
      LGraph, LOptions, LContext, LCapture.Keep);
    while LStream.ReadOutputs(511, [], LMaster, LOutputs, LCapture.Observe) do
    begin
    end;
    Check((Length(LCapture.Chunks) = 2) and (Length(LCapture.Chunks[1].Providers) = 9),
      'Actual context stream retains all nine providers');
    LBeforeBytes := Journal(LCapture.Chunks);
    LEdit.StartFrame := 12000;
    LEdit.EndFrame := 16000;
    LPartFrame := DecodeWfcMusicEnsembleFrame(LCapture.Chunks[1].Providers[5].Tokens[2]);
    LEdit.Controls[2].MinimumPitch := 72;
    if LPartFrame.Voices[0].Tones[0].Pitch = 72 then
    begin
      LEdit.Controls[2].MinimumPitch := 84;
    end;
    LEdit.Controls[2].MaximumPitch := LEdit.Controls[2].MinimumPitch;
    Check(TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, LContext,
      LCapture.Chunks[1], Edges(0, -1), LEdit, LAfter,
      LReport, LCapture.Observe), 'Selected notes edit through actual context and pitched graphs');
    Check((LReport.ChangedCells = 2) and (LReport.ChangedProviders = 2),
      'Only context and Lead provider decisions change');
    for I := 0 to High(LAfter.Providers) do
    begin
      for J := 0 to High(LAfter.Cells) do
      begin
        if ((I = 0) or (I = 5)) and (J >= 2) then
        begin
          Continue;
        end;
        Check((LAfter.Providers[I].States[J] = LCapture.Chunks[1].Providers[I].States[J]) and
          (LAfter.Providers[I].Tokens[J] = LCapture.Chunks[1].Providers[I].Tokens[J]),
          'Context editing preserves all held provider cells');
      end;
    end;
    LEdited := Copy(LCapture.Chunks);
    LEdited[1] := LAfter;
    LBeforePcm := Render(LBeforeBytes, LStarter, LDrums, 16000);
    LAfterPcm := Render(Journal(LEdited), LStarter, LDrums, 16000);
    for I := 0 to High(LBeforePcm) do
    begin
      LChanged := False;
      for J := 0 to High(LBeforePcm[I]) do
      begin
        LChanged := LChanged or (LBeforePcm[I][J] <> LAfterPcm[I][J]);
      end;
      Check(LChanged = ((I = 0) or (I = 3)),
        'Context edit changes actual Lead/mix and retains the other five stems');
    end;
    Check(Sha256Bytes(Journal(LCapture.Chunks)) = Sha256Bytes(LBeforeBytes),
      'Context edit preserves the accepted nine-provider source');
    LAcceptedChunkHash := Sha256Bytes(EncodeMusicDecisions(LAfter));
    LTampered := CopyMusicDecisionChunk(LCapture.Chunks[1]);
    Inc(LTampered.Cells[0].Parts[2].Tones[0].Pitch);
    LRejected := False;
    try
      TryEditInstrumentalPassageChunk(LConfig, LNames, LDrums, LContext,
        LTampered, Edges(0, -1), LEdit, LAfter,
        LReport, LCapture.Observe);
    except
      on E: EAudio do LRejected := True;
    end;
    Check(LRejected and (Sha256Bytes(EncodeMusicDecisions(LAfter)) = LAcceptedChunkHash),
      'Divergent performed notes cannot be admitted as the saved provider graph');
    Check(Callbacks > 0, 'Actual preparation, solver and publication work remains observable');
  finally
    LStream.Free;
    LGraph.Free;
    LCapture.Free;
    LStarter.Free;
    LLead.Free;
    LContext.Free;
  end;
end;

begin
  try
    Run;
    Writeln('PASS actual instrumental passage edits: ', Checks,
      ' checks; ', Callbacks, ' progress callbacks');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ' at ', LastStage, ': ', E.Message);
      {$ifndef pas2js}
      DumpExceptionBackTrace(Output);
      {$endif}
      ExitCode := 1;
    end;
  end;
end.
