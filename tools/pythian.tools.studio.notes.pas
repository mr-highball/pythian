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
unit pythian.tools.studio.notes;

{$mode delphi}
{$H+}

interface

uses Classes, fpjson, pythian.progress;

{ Big Boss: native metadata/I/O adapter only. The caller has verified the parent
  plan and opened its exact journal through OpenStudioDecisionJournal. Primary
  codecs, graph editing and decision writer own musical behavior and continuity.
  Borrows metadata/input; returns an owned receipt/report after full success. }
function EditStudioRetainedNotes(const ACatalogRoot, AJobId: String;
  const AMeta, AEdit: TJSONObject; const ASource: TStream;
  const AProgress: TWorkProgressCallback): TJSONObject;

implementation

uses SysUtils, pythian.audio, pythian.chord, pythian.music.decisions,
  pythian.wfc.layers, pythian.wfc.percussion, pythian.wfc.instrumental.edit,
  pythian.tools.studio.jobs, pythian.tools.studio.decisions,
  pythian.tools.studio.instrumental.config,
  pythian.tools.studio.instrumental.settings,
  wfc_sequence, wfc_sequence_text, wfc_sequence_graph,
  wfc_music_voices_graph, wfc_music_ensemble_graph, wfc_music_arrangement;

type
  TStoredMusicalModels = class
  public
    Models: array of TWfcSequenceModel;
    Config: TWfcMusicVoicesGraphConfig;
    Names: TLayerNames;
    Drums: TPercussionDefinitions;
    Context: TWfcSequenceModel;
    constructor Create(const AMeta: TJSONObject; const AProgress: TWorkProgressCallback);
    destructor Destroy; override;
  end;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

constructor TStoredMusicalModels.Create(const AMeta: TJSONObject;
  const AProgress: TWorkProgressCallback);
var
  I: Integer;
  J: Integer;
  K: Integer;
  LRole: TJSONObject;
  LConfig: TJSONObject;
  LPair: TJSONObject;
  LRow: TJSONObject;
  LModelText: String;
  LLabels: array[0..8] of String;
begin
  inherited Create;
  Need((AMeta.Arrays['roles'].Count = 3) and (AMeta.Arrays['percussion'].Count = 3) and
    (AMeta.Arrays['models'].Count = 9) and (AMeta.Arrays['model_labels'].Count = 9) and
    (AMeta.Strings['context_binding'] = 'all_roles'), 'Saved musical graph layout is unsupported');
  SetLength(Models, 9);
  SetLength(Names, 3);
  SetLength(Config.Voices, 3);
  SetLength(Drums, 3);
  LLabels[0] := 'harmony';
  LLabels[1] := 'rhythm';
  LLabels[5] := 'musical-context';
  for I := 0 to 2 do
  begin
    LRole := AMeta.Arrays['roles'].Objects[I];
    Names[I] := LRole.Strings['name'];
    LLabels[I + 2] := 'voice:' + Names[I];
    LLabels[I + 6] := 'percussion:' + AMeta.Arrays['percussion'].Objects[I].Strings['name'];
    Config.Voices[I].MinPitch := LRole.Integers['minimum_pitch'];
    Config.Voices[I].MaxPitch := LRole.Integers['maximum_pitch'];
  end;
  LModelText := '';
  for I := 0 to 8 do
  begin
    Need(AMeta.Arrays['model_labels'].Strings[I] = LLabels[I],
      'Saved musical model order differs from its role metadata');
    LModelText := LModelText + IntToStr(Length(AMeta.Arrays['models'].Strings[I])) +
      ':' + AMeta.Arrays['models'].Strings[I];
    ReportWork(AProgress, 'instrumental_edit_models', wuItems, I, 9);
    Models[I] := DecodeWfcSequenceText(AMeta.Arrays['models'].Strings[I]);
  end;
  Need(StudioTextHash(LModelText) = AMeta.Strings['model_sha256'],
    'Saved model text differs from its accepted identity');
  Config.HarmonyModel := Models[0];
  Config.RhythmModel := Models[1];
  Context := Models[5];
  LConfig := AMeta.Objects['musical_config'];
  Config.StepsPerOctave := LConfig.Integers['steps_per_octave'];
  Need(LConfig.Integers['harmony_mode'] in [0, 1], 'Saved harmony mode is unsupported');
  Config.HarmonyMode := TWfcMusicEnsembleHarmonyMode(LConfig.Integers['harmony_mode']);
  SetLength(Config.PairConstraints, LConfig.Arrays['voice_pairs'].Count);
  for I := 0 to High(Config.PairConstraints) do
  begin
    LPair := LConfig.Arrays['voice_pairs'].Objects[I];
    Config.PairConstraints[I].LowerVoice := LPair.Integers['lower'];
    Config.PairConstraints[I].UpperVoice := LPair.Integers['upper'];
    Config.PairConstraints[I].MinGap := LPair.Integers['min_gap'];
    Config.PairConstraints[I].MaxGap := LPair.Integers['max_gap'];
    Need(LPair.Integers['rest_policy'] in [0, 1], 'Saved rest policy is unsupported');
    Config.PairConstraints[I].RestPolicy := TWfcMusicVoicePairRestPolicy(LPair.Integers['rest_policy']);
  end;
  for I := 0 to 2 do
  begin
    Config.Voices[I].Model := Models[I + 2];
    LRow := AMeta.Arrays['percussion'].Objects[I];
    Drums[I].Name := LRow.Strings['name'];
    Drums[I].Origin := AMeta.Strings['material_origin'];
    Drums[I].Model := Models[I + 6];
    Drums[I].Settings := DecodeStudioPercussionSettings(LRow, StudioInstrumentalRate);
    Drums[I].OutputBus := LRow.Integers['output_bus'];
    Drums[I].Enabled := LRow.Booleans['enabled'];
    Drums[I].HitWeight := LRow.Integers['hit_weight'];
    SetLength(Drums[I].AllowedHitRhythms, LRow.Arrays['allowed_hit_rhythms'].Count);
    for J := 0 to High(Drums[I].AllowedHitRhythms) do
      Drums[I].AllowedHitRhythms[J] := LRow.Arrays['allowed_hit_rhythms'].Strings[J];
    SetLength(Drums[I].Constraints, LRow.Arrays['constraints'].Count);
    for J := 0 to High(Drums[I].Constraints) do
    begin
      Drums[I].Constraints[J].Position := LRow.Arrays['constraints'].Objects[J].Integers['position'];
      SetLength(Drums[I].Constraints[J].AllowedTokens,
        LRow.Arrays['constraints'].Objects[J].Arrays['allowed_tokens'].Count);
      for K := 0 to High(Drums[I].Constraints[J].AllowedTokens) do
        Drums[I].Constraints[J].AllowedTokens[K] :=
          LRow.Arrays['constraints'].Objects[J].Arrays['allowed_tokens'].Strings[K];
    end;
  end;
  ValidateWfcMusicVoicesGraphConfig(Config);
end;

destructor TStoredMusicalModels.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(Models) do
    Models[I].Free;
  inherited Destroy;
end;

function EditStudioRetainedNotes(const ACatalogRoot, AJobId: String;
  const AMeta, AEdit: TJSONObject; const ASource: TStream;
  const AProgress: TWorkProgressCallback): TJSONObject;
var
  LModels: TStoredMusicalModels;
  LReader: TMusicDecisionReader;
  LWriter: TStudioDecisionWriter;
  LCurrent: TMusicDecisionChunk;
  LNext: TMusicDecisionChunk;
  LAfter: TMusicDecisionChunk;
  LSourcePrevious: TMusicDecisionChunk;
  LCandidatePrevious: TMusicDecisionChunk;
  LEdges: TInstrumentalPassageEdges;
  LChunkEdit: TInstrumentalPassageEdit;
  LPreviousParts: TChordFrame;
  LEdit: TInstrumentalPassageEdit;
  LSupplied: TStudioPassageEdit;
  LReport: TInstrumentalPassageReport;
  LReportJson: TJSONObject;
  LResult: TJSONObject;
  LPasses: TStringList;
  LHasNext: Boolean;
  LChanged: Int64;
  LActualStart: Int64;
  LActualEnd: Int64;
  I: Integer;
  procedure Reject(const ADetail, AMessage: String);
  var
    LFailure: TJSONObject;
  begin
    LFailure := TJSONObject.Create(['first_cell', LCurrent.FirstCell,
      'group', LReport.Group, 'detail', ADetail]);
    try
      WriteStudioJSONNew(StudioJobDirectory(ACatalogRoot, AJobId) +
        PathDelim + 'note-conflict.json', LFailure);
    finally
      LFailure.Free;
    end;
    raise EAudio.Create(AMessage);
  end;
begin
  Result := nil;
  LModels := nil;
  LReader := nil;
  LWriter := nil;
  LResult := TJSONObject.Create;
  LPasses := TStringList.Create;
  try
    LSupplied := DecodeStudioPassageEdit(AEdit, AMeta.Objects['decisions'].Int64s['music_frames']);
    LEdit := Default(TInstrumentalPassageEdit);
    LEdit.StartFrame := LSupplied.StartFrame;
    LEdit.EndFrame := LSupplied.EndFrame;
    LEdit.Parts := LSupplied.Parts;
    LEdit.Harmony := LSupplied.Harmony;
    LEdit.Rhythm := LSupplied.Rhythm;
    LEdit.Tonic := LSupplied.Tonic;
    LEdit.TonicBias := LSupplied.TonicBias;
    LEdit.Controls := LSupplied.Controls;
    LEdit.Seed := LSupplied.Seed;
    LEdit.MaxBacktracks := 256;
    LEdit.MaxPassBacktracks := 16;
    LModels := TStoredMusicalModels.Create(AMeta, AProgress);
    LReader := TMusicDecisionReader.Create(ASource);
    LWriter := TStudioDecisionWriter.Create(ACatalogRoot, AJobId);
    LPasses.Sorted := True;
    LPasses.Duplicates := dupIgnore;
    LSourcePrevious := Default(TMusicDecisionChunk);
    LCandidatePrevious := Default(TMusicDecisionChunk);
    LChanged := 0;
    LActualStart := -1;
    LActualEnd := -1;
    Need(LReader.TryNext(LCurrent, AProgress), 'Saved musical decisions are empty');
    LPreviousParts := CopyChordFrame(LCurrent.Previous);
    repeat
      LNext := Default(TMusicDecisionChunk);
      LHasNext := LReader.TryNext(LNext, AProgress);
      LEdges := RetainedInstrumentalPassageEdges(LSourcePrevious, LNext);
      LEdges.CandidatePrevious := LCandidatePrevious;
      LEdges.FollowingCells := AMeta.Int64s['total_cells'] -
        LCurrent.FirstCell - Length(LCurrent.Cells);
      LChunkEdit := LEdit;
      LChunkEdit.Seed := WfcMusicArrangementSectionSeed(LEdit.Seed, LCurrent.FirstCell);
      try
        if not TryEditInstrumentalPassageChunk(LModels.Config, LModels.Names, LModels.Drums,
          LModels.Context, LCurrent, LEdges, LChunkEdit, LAfter, LReport, AProgress) then
        begin
          Reject(LReport.Detail,
            'These changes cannot fit the kept music. Try more parts, a later Start or a longer passage.');
        end;
      except
        on E: EAudio do
        begin
          if Pos('Pitch bounds leave role', E.Message) = 1 then
            Reject(E.Message, 'No learned notes fit that pitch range. Try a wider range.');
          raise;
        end;
      end;
      Inc(LChanged, LReport.ChangedCells);
      if LReport.ActualEndFrame > LReport.ActualStartFrame then
      begin
        if LActualStart < 0 then LActualStart := LReport.ActualStartFrame;
        LActualEnd := LReport.ActualEndFrame;
      end;
      for I := 0 to High(LReport.ActivePasses) do
        LPasses.Add(LReport.ActivePasses[I]);
      LAfter.Previous := CopyChordFrame(LPreviousParts);
      LWriter.Append(LAfter);
      LSourcePrevious := LCurrent;
      LCandidatePrevious := LAfter;
      LPreviousParts := CopyChordFrame(LAfter.Cells[High(LAfter.Cells)].Parts);
      ReportWork(AProgress, 'instrumental_edit_progress', wuItems,
        LAfter.FirstCell + Length(LAfter.Cells), AMeta.Int64s['total_cells']);
      LCurrent := LNext;
    until not LHasNext;
    Need((LReader.CellCount = AMeta.Objects['decisions'].Int64s['cells']) and
      (LReader.FrameCount = AMeta.Objects['decisions'].Int64s['music_frames']),
      'Saved musical decisions differ from their declared extent');
    LResult.Add('decisions', LWriter.Finish(LReader.CellCount, LReader.FrameCount, AProgress));
    LReportJson := TJSONObject.Create(['runtime_version', InstrumentalPassageEditVersion,
      'changed_cells', LChanged,
      'requested_start_frame', LEdit.StartFrame, 'requested_end_frame', LEdit.EndFrame,
      'actual_start_frame', LActualStart, 'actual_end_frame', LActualEnd,
      'seam_policy', 'retain_outside_scope; continue_candidate_inside_scope']);
    LResult.Add('edit_report', LReportJson);
    LReportJson.Add('active_passes', TJSONArray.Create);
    for I := 0 to LPasses.Count - 1 do
      LReportJson.Arrays['active_passes'].Add(LPasses[I]);
    ReportWork(AProgress, 'instrumental_edit_complete', wuItems, 1, 1);
    Result := LResult;
    LResult := nil;
  finally
    LPasses.Free;
    LResult.Free;
    LWriter.Free;
    LReader.Free;
    LModels.Free;
  end;
end;

end.
