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

program pythian_part_controls;
{$mode delphi}
{$H+}
uses
  Classes, SysUtils, fpjson, pythian.audio, pythian.wave, pythian.oscillator,
  pythian.evaluation, pythian.evaluation.parts, pythian.evaluation.notes, pythian.tools.files;
const
  CFrames = 192000;
  CRate = 16000;
  CNames: array[0..3] of String = ('bass', 'chordal', 'lead', 'other');
type
  TEvent = record
    Id: String;
    Role: Integer;
    First: Integer;
    Last: Integer;
    Pitch: Integer;
    Amplitude: Double;
  end;
  TEvents = array of TEvent;
  TClips = array[0..3] of TAudioClip;
var
  GEvents: TEvents;
  GDirectory: String;
  GArtifacts: TJSONArray;
  GBytes: Int64;
  GStart: QWord;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Add(const ARole, AFirst, ALast, APitch: Integer; const AAmplitude: Double);
var
  I: Integer;
begin
  I := Length(GEvents);
  SetLength(GEvents, I + 1);
  GEvents[I].Id := 'event-' + IntToStr(I);
  GEvents[I].Role := ARole;
  GEvents[I].First := AFirst;
  GEvents[I].Last := ALast;
  GEvents[I].Pitch := APitch;
  GEvents[I].Amplitude := AAmplitude;
end;

procedure Score;
begin
  Add(0, 8000, 32000, 48, 0.10);
  Add(0, 48000, 80000, 45, 0.08);
  Add(0, 96000, 128000, 48, 0.10);
  Add(0, 144000, 160000, 43, 0.08);
  Add(1, 8000, 32000, 60, 0.025);
  Add(1, 8000, 32000, 64, 0.025);
  Add(1, 8000, 32000, 67, 0.025);
  Add(1, 48000, 80000, 57, 0.025);
  Add(1, 48000, 80000, 60, 0.025);
  Add(1, 48000, 80000, 64, 0.025);
  Add(1, 96000, 128000, 60, 0.05);
  Add(1, 96000, 128000, 64, 0.05);
  Add(1, 96000, 128000, 67, 0.05);
  Add(2, 8000, 20000, 76, 0.05);
  Add(2, 20000, 32000, 64, 0.05);
  Add(2, 48000, 64000, 69, 0.04);
  Add(2, 56000, 72000, 69, 0.04);
  Add(2, 96000, 128000, 64, 0.001);
  Add(3, 8000, 20000, 64, 0.05);
  Add(3, 20000, 32000, 76, 0.05);
  Add(3, 144000, 160000, 72, 0.04);
end;
function Active(const E: TEvent; const F: Integer): Boolean;
begin
  Result := (F >= E.First) and (F < E.Last);
end;

function ActiveCount(const ARole, AFrame: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(GEvents) do
  begin
    if (GEvents[I].Role = ARole) and Active(GEvents[I], AFrame) then
    begin
      Inc(Result);
    end;
  end;
end;

procedure VerifyScoreCohorts;
var
  R: Integer;
begin
  Check(Length(GEvents) = 21, 'Authored event cardinality');
  Check(ActiveCount(1, 16000) = 3, 'True simultaneous chord');
  Check(ActiveCount(2, 60000) = 2, 'Repeated same-pitch multiplicity retained');
  Check((ActiveCount(2, 112000) = 1) and (ActiveCount(1, 112000) = 3),
    'Quiet part and masker coexist');
  for R := 0 to 3 do
  begin
    Check(ActiveCount(R, 4000) = 0, 'Initial full rest');
    Check(ActiveCount(R, 176000) = 0, 'Final full rest');
  end;
end;
function Save(const AName, AText: String; const AParents: array of String): String;
var
  LRow: TJSONObject;
  LParents: TJSONArray;
  I: Integer;
begin
  Check(not FileExists(GDirectory + AName), 'Output already exists');
  WriteTextFile(GDirectory + AName, AText);
  Inc(GBytes, Length(AText));
  Result := HashText(AText);
  LRow := TJSONObject.Create;
  GArtifacts.Add(LRow);
  LRow.Add('path', AName);
  LRow.Add('sha256', Result);
  LParents := TJSONArray.Create;
  LRow.Add('parents', LParents);
  for I := 0 to High(AParents) do
  begin
    LParents.Add(AParents[I]);
  end;
end;

function WriteScore(const APolicy, ACode: String): String;
var
  LDoc: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  I: Integer;
begin
  LDoc := TJSONObject.Create;
  try
    LDoc.Add('kind', 'authored-source-score');
    LDoc.Add('sample_rate', CRate);
    LDoc.Add('source_frames', CFrames);
    LDoc.Add('roles', TJSONArray.Create(['bass', 'chordal', 'lead', 'other']));
    LRows := TJSONArray.Create;
    LDoc.Add('events', LRows);
    for I := 0 to High(GEvents) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('id', GEvents[I].Id);
      LRow.Add('role_id', CNames[GEvents[I].Role]);
      LRow.Add('start_frame', GEvents[I].First);
      LRow.Add('end_frame', GEvents[I].Last);
      LRow.Add('pitch', GEvents[I].Pitch);
      LRow.Add('amplitude', GEvents[I].Amplitude);
    end;
    Result := Save('score.json', LDoc.AsJSON, [APolicy, ACode]);
  finally
    LDoc.Free;
  end;
end;

function StoreWave(const AName: String; const ASamples: TAudioSamples;
  const AParents: array of String): TAudioClip;
var
  LClip: TAudioClip;
  LBytes: TAudioBytes;
  LRow: TJSONObject;
  LParents: TJSONArray;
  I: Integer;
begin
  LClip := TAudioClip.Create(CRate, 1, ASamples);
  try
    LBytes := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
  WriteFileBytes(GDirectory + AName, LBytes);
  Inc(GBytes, Length(LBytes));
  LRow := TJSONObject.Create;
  GArtifacts.Add(LRow);
  LRow.Add('path', AName);
  LRow.Add('sha256', HashAudioBytes(LBytes));
  LParents := TJSONArray.Create;
  LRow.Add('parents', LParents);
  for I := 0 to High(AParents) do
  begin
    LParents.Add(AParents[I]);
  end;
  Result := LoadWave(GDirectory + AName);
  Check((Result.FrameCount = CFrames) and (Result.SampleRate = CRate) and
    (Result.Channels = 1), 'Stored WAV geometry');
end;

function Render(const AScoreHash: String): String;
var
  LStems: TClips;
  LMix: TAudioClip;
  LWork: array of Double;
  LSamples: TAudioSamples;
  LDoc: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LStemHashes: array[0..3] of String;
  LPhase: Integer;
  LStep: Integer;
  LSum: Integer;
  LCount: Integer;
  LFirst: Integer;
  LLast: Integer;
  LGate: Boolean;
  LValue: Double;
  LQuiet: Double;
  LMasker: Double;
  R: Integer;
  F: Integer;
  E: Integer;
begin
  LStems := Default(TClips);
  LMix := nil;
  LDoc := TJSONObject.Create;
  try
    LRows := TJSONArray.Create;
    LDoc.Add('stems', LRows);
    SetLength(LWork, CFrames);
    SetLength(LSamples, CFrames);
    for R := 0 to 3 do
    begin
      FillChar(LWork[0], Length(LWork) * SizeOf(Double), 0);
      for E := 0 to High(GEvents) do
      begin
        if GEvents[E].Role <> R then
        begin
          Continue;
        end;
        LPhase := 0;
        LStep := FixedPhaseIncrement(GEvents[E].Pitch, CRate);
        for F := GEvents[E].First to GEvents[E].Last - 1 do
        begin
          LValue := FixedTriangleSample(LPhase);
          LValue := LValue / EnvelopeScale;
          LValue := LValue * FixedEnvelopeGain(F - GEvents[E].First,
            GEvents[E].Last - GEvents[E].First, 80, 80) / EnvelopeScale;
          LWork[F] := LWork[F] + LValue * GEvents[E].Amplitude;
          LPhase := (LPhase + LStep) and PhaseMask;
        end;
      end;
      for F := 0 to CFrames - 1 do
      begin
        Check(Abs(LWork[F]) < 0.9, 'Stem clipping');
        LSamples[F] := QuantizePcm16(LWork[F]) / 32768;
      end;
      LStems[R] := StoreWave(CNames[R] + '.wav', LSamples, [AScoreHash]);
      LStemHashes[R] := HashAudioBytes(ReadFileBytes(GDirectory + CNames[R] + '.wav', 1000000));
      LCount := 0;
      LFirst := -1;
      LLast := -1;
      for F := 0 to CFrames - 1 do
      begin
        Check(LStems[R].SampleAt(F, 0) = LSamples[F], 'Stem quantization replay');
        LGate := False;
        for E := 0 to High(GEvents) do
        begin
          if (GEvents[E].Role = R) and Active(GEvents[E], F) then
          begin
            LGate := True;
          end;
        end;
        if not LGate then
        begin
          Check(LStems[R].SampleAt(F, 0) = 0, 'Outside-gate tail');
        end;
        if LStems[R].SampleAt(F, 0) <> 0 then
        begin
          Inc(LCount);
          if LFirst < 0 then
          begin
            LFirst := F;
          end;
          LLast := F;
        end;
      end;
      Check(LCount > 0, 'Empty authored stem');
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('role_id', CNames[R]);
      LRow.Add('nonzero_samples', LCount);
      LRow.Add('first_nonzero_frame', LFirst);
      LRow.Add('last_nonzero_frame', LLast);
      LRow.Add('gain', 1);
      LRow.Add('offset_frames', 0);
    end;
    LQuiet := 0;
    LMasker := 0;
    for F := 0 to CFrames - 1 do
    begin
      LSum := 0;
      for R := 0 to 3 do
      begin
        Inc(LSum, Round(LStems[R].SampleAt(F, 0) * 32768));
      end;
      Check((LSum >= -32768) and (LSum <= 32767), 'Mix clipping');
      LSamples[F] := LSum / 32768;
      if (F >= 96000) and (F < 128000) then
      begin
        LValue := LStems[2].SampleAt(F, 0);
        LQuiet := LQuiet + LValue * LValue;
        LValue := LStems[1].SampleAt(F, 0);
        LMasker := LMasker + LValue * LValue;
      end;
    end;
    Check((LQuiet > 0) and (LMasker > LQuiet * 100), 'Quiet masked part energy cohort');
    LMix := StoreWave('mix.wav', LSamples, LStemHashes);
    for F := 0 to CFrames - 1 do
    begin
      Check(LMix.SampleAt(F, 0) = LSamples[F], 'Exact stored integer mixture');
    end;
    LDoc.Add('verified_frames', CFrames);
    LDoc.Add('quiet_lead_energy', LQuiet);
    LDoc.Add('chordal_masker_energy', LMasker);
    LDoc.Add('energy_masking_not_listening_verdict', True);
    Save('audio-verification.json', LDoc.AsJSON, LStemHashes);
    Result := HashAudioBytes(ReadFileBytes(GDirectory + 'mix.wav', 1000000));
  finally
    LMix.Free;
    for R := 0 to 3 do
    begin
      LStems[R].Free;
    end;
    LDoc.Free;
  end;
end;

function ReferenceCells: TPartEvaluationCells;
var
  LFlags: array[0..127] of Boolean;
  I: Integer;
  R: Integer;
  E: Integer;
  P: Integer;
  N: Integer;
begin
  Result := nil;
  SetLength(Result, 1200);
  for I := 0 to 1199 do
  begin
    Result[I].Frame := 80 + 160 * I;
    SetLength(Result[I].Parts, 4);
    for R := 0 to 3 do
    begin
      FillChar(LFlags, SizeOf(LFlags), 0);
      for E := 0 to High(GEvents) do
      begin
        if (GEvents[E].Role = R) and Active(GEvents[E], Result[I].Frame) then
        begin
          LFlags[GEvents[E].Pitch] := True;
        end;
      end;
      Result[I].Parts[R].State := esRest;
      for P := 0 to 127 do
      begin
        if LFlags[P] then
        begin
          Result[I].Parts[R].State := esValue;
          N := Length(Result[I].Parts[R].Notes);
          SetLength(Result[I].Parts[R].Notes, N + 1);
          Result[I].Parts[R].Notes[N] := P;
        end;
      end;
    end;
    if (Result[I].Frame >= 144000) and (Result[I].Frame < 160000) then
    begin
      for R := 2 to 3 do
      begin
        Result[I].Parts[R].State := esAmbiguous;
        Result[I].Parts[R].Notes := nil;
      end;
      SetLength(Result[I].UnassignedNotes, 1);
      Result[I].UnassignedNotes[0] := 72;
    end;
  end;
end;

function EncodeCells(const ACells: TPartEvaluationCells): TJSONArray;
const
  CStates: array[TEvaluationState] of String =
    ('value', 'rest', 'unknown', 'ambiguous', 'unsupported');
var
  LCell: TJSONObject;
  LPart: TJSONObject;
  LParts: TJSONArray;
  LNotes: TJSONArray;
  I: Integer;
  R: Integer;
  N: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to High(ACells) do
  begin
    LCell := TJSONObject.Create;
    Result.Add(LCell);
    LCell.Add('frame', ACells[I].Frame);
    LParts := TJSONArray.Create;
    LCell.Add('parts', LParts);
    for R := 0 to 3 do
    begin
      LPart := TJSONObject.Create;
      LParts.Add(LPart);
      LPart.Add('state', CStates[ACells[I].Parts[R].State]);
      LNotes := TJSONArray.Create;
      LPart.Add('notes', LNotes);
      for N := 0 to High(ACells[I].Parts[R].Notes) do
      begin
        LNotes.Add(ACells[I].Parts[R].Notes[N]);
      end;
    end;
    LNotes := TJSONArray.Create;
    LCell.Add('unassigned_notes', LNotes);
    for N := 0 to High(ACells[I].UnassignedNotes) do
    begin
      LNotes.Add(ACells[I].UnassignedNotes[N]);
    end;
  end;
end;

procedure AssignNote(var APart: TPartObservation; const APitch: Integer);
begin
  APart.State := esValue;
  SetLength(APart.Notes, 1);
  APart.Notes[0] := APitch;
end;

function ComparisonDocument(const ACells: TPartEvaluationCells;
  const ASource: String): TJSONObject;
var
  LCross: TJSONObject;
  LCrosses: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.Add('kind', 'authored-control-part-note-sets');
  Result.Add('source_sha256', ASource);
  Result.Add('sample_rate', CRate);
  Result.Add('first_frame', 0);
  Result.Add('end_frame', CFrames);
  Result.Add('role_ids', TJSONArray.Create(['bass', 'chordal', 'lead', 'other']));
  Result.Add('observations', EncodeCells(ACells));
  LCrosses := TJSONArray.Create;
  Result.Add('crossings', LCrosses);
  LCross := TJSONObject.Create;
  LCrosses.Add(LCross);
  LCross.Add('first_role', 2);
  LCross.Add('second_role', 3);
  LCross.Add('before_frame', 12080);
  LCross.Add('after_frame', 28080);
end;

procedure Cases(const ASource, AScore: String);
const
  CExpected: array[0..3] of Integer = (650, 1650, 500, 150);
  CCases: array[0..5] of String = ('perfect', 'missing-chord', 'crossing-swap',
    'rest-hallucination', 'quiet-abstention', 'uncertain-assignment');
var
  LReference: TPartEvaluationCells;
  LPrediction: TPartEvaluationCells;
  LRoles: TPartRoleIds;
  LCrossings: TPartCrossings;
  LScore: TPartEvaluation;
  LDoc: TJSONObject;
  LReport: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LRoleRows: TJSONArray;
  LRoleRow: TJSONObject;
  LRefHash: String;
  LPredHash: String;
  LPredictionHashes: array[0..5] of String;
  I: Integer;
  R: Integer;
  K: Integer;
begin
  LReference := ReferenceCells;
  SetLength(LRoles, 4);
  for R := 0 to 3 do
  begin
    LRoles[R] := CNames[R];
  end;
  SetLength(LCrossings, 1);
  LCrossings[0].FirstRole := 2;
  LCrossings[0].SecondRole := 3;
  LCrossings[0].BeforeFrame := 12080;
  LCrossings[0].AfterFrame := 28080;
  LDoc := ComparisonDocument(LReference, ASource);
  try
    LRefHash := Save('reference.json', LDoc.AsJSON, [AScore, ASource]);
  finally
    LDoc.Free;
  end;
  LReport := TJSONObject.Create;
  try
    LReport.Add('independent_inference_claim', False);
    LReport.Add('interval_multiplicity_scored', False);
    LRows := TJSONArray.Create;
    LReport.Add('cases', LRows);
    for K := 0 to 5 do
    begin
      LPrediction := ReferenceCells;
      for I := 0 to High(LPrediction) do
      begin
        case K of
          1:
            if (I >= 50) and (I < 200) then
            begin
              SetLength(LPrediction[I].Parts[1].Notes, 2);
              LPrediction[I].Parts[1].Notes[0] := 60;
              LPrediction[I].Parts[1].Notes[1] := 67;
            end;
          2:
            if (I >= 125) and (I < 200) then
            begin
              AssignNote(LPrediction[I].Parts[2], 76);
              AssignNote(LPrediction[I].Parts[3], 64);
            end;
          3:
            begin
              if I < 50 then
              begin
                AssignNote(LPrediction[I].Parts[0], 55);
              end;
            end;
          4:
            if (I >= 600) and (I < 800) then
            begin
              LPrediction[I].Parts[2].State := esUnknown;
              LPrediction[I].Parts[2].Notes := nil;
            end;
          5:
            begin
              if (I >= 900) and (I < 1000) then
              begin
                AssignNote(LPrediction[I].Parts[3], 72);
              end;
            end;
        end;
      end;
      LDoc := ComparisonDocument(LPrediction, ASource);
      try
        LPredHash := Save('prediction-' + CCases[K] + '.json', LDoc.AsJSON, [AScore, ASource]);
      finally
        LDoc.Free;
      end;
      LPredictionHashes[K] := LPredHash;
      LScore := EvaluatePartCells(LRoles, LReference, LPrediction, LCrossings, 0, CFrames);
      Check(LScore.CellCount = 1200, 'Complete center coverage');
      Check(LScore.ReferenceUnassignedNotes = 100, 'Uncertain annotation cohort');
      for R := 0 to 3 do
      begin
        Check(LScore.Roles[R].ReferenceNotes = CExpected[R], 'Fixed reference cardinality');
      end;
      case K of
        0:
          begin
            for R := 0 to 3 do
            begin
              Check((LScore.Roles[R].CorrectNotes = CExpected[R]) and
                (LScore.Roles[R].ExtraNotes = 0) and (LScore.Roles[R].MissedNotes = 0), 'Perfect exact counts');
            end;
            Check(LScore.CrossingEndpointsCorrect = 1, 'Declared crossing positive');
          end;
        1:
          begin
            Check(LScore.Roles[1].MissedNotes = 150, 'Missing chord member');
          end;
        2:
          begin
            Check((LScore.CrossingEndpointsWrong = 1) and
              (LScore.Roles[2].WrongOwnerNotes = 75) and
              (LScore.Roles[3].AmbiguousWrongOwnerNotes = 75),
              'Crossing swap and shared-pitch ambiguity');
          end;
        3:
          begin
            Check(LScore.Roles[0].FalseNotesInRest = 50, 'Rest hallucination');
          end;
        4:
          begin
            Check(LScore.Roles[2].MissedNotes = 200, 'Quiet role abstention');
          end;
        5:
          begin
            Check(LScore.Roles[3].AdmittedUnscorable = 100, 'Uncertain truth not primary credit');
          end;
      end;
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('case', CCases[K]);
      LRow.Add('prediction_sha256', LPredHash);
      LRow.Add('crossings_correct', LScore.CrossingEndpointsCorrect);
      LRow.Add('crossings_wrong', LScore.CrossingEndpointsWrong);
      LRow.Add('reference_unassigned', LScore.ReferenceUnassignedNotes);
      LRoleRows := TJSONArray.Create;
      LRow.Add('roles', LRoleRows);
      for R := 0 to 3 do
      begin
        LRoleRow := TJSONObject.Create;
        LRoleRows.Add(LRoleRow);
        LRoleRow.Add('role_id', CNames[R]);
        LRoleRow.Add('reference_notes', LScore.Roles[R].ReferenceNotes);
        LRoleRow.Add('correct_notes', LScore.Roles[R].CorrectNotes);
        LRoleRow.Add('missed_notes', LScore.Roles[R].MissedNotes);
        LRoleRow.Add('extra_notes', LScore.Roles[R].ExtraNotes);
        LRoleRow.Add('wrong_owner_notes', LScore.Roles[R].WrongOwnerNotes);
        LRoleRow.Add('ambiguous_wrong_owner_notes', LScore.Roles[R].AmbiguousWrongOwnerNotes);
        LRoleRow.Add('admitted_unscorable', LScore.Roles[R].AdmittedUnscorable);
      end;
    end;
    Check(HashAudioBytes(ReadFileBytes(GDirectory + 'reference.json', 4000000)) = LRefHash,
      'Reference mutated by scripted predictions');
    Save('scores.json', LReport.AsJSON, [LRefHash, LPredictionHashes[0],
      LPredictionHashes[1], LPredictionHashes[2], LPredictionHashes[3],
      LPredictionHashes[4], LPredictionHashes[5]]);
  finally
    LReport.Free;
  end;
end;

function RoleEvents(const ARole: Integer; const APrediction: Boolean): TEvaluationNotes;
var
  I: Integer;
  N: Integer;
begin
  Result := nil;
  for I := 0 to High(GEvents) do
  begin
    if GEvents[I].Role = ARole then
    begin
      N := Length(Result);
      SetLength(Result, N + 1);
      Result[N].Id := GEvents[I].Id;
      if APrediction then
      begin
        Result[N].Id := 'p-' + Result[N].Id;
      end;
      Result[N].StartFrame := GEvents[I].First;
      Result[N].EndFrame := GEvents[I].Last;
      Result[N].Pitch := GEvents[I].Pitch;
    end;
  end;
end;

function EventDocument(const AEvents: TEvaluationNotes; const ARole: Integer;
  const ASource: String): TJSONObject;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('kind', 'authored-role-event-control');
  Result.Add('source_sha256', ASource);
  Result.Add('role_id', CNames[ARole]);
  Result.Add('sample_rate', CRate);
  Result.Add('complete_exact_region_first', 0);
  Result.Add('complete_exact_region_end', CFrames);
  LRows := TJSONArray.Create;
  Result.Add('events', LRows);
  for I := 0 to High(AEvents) do
  begin
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('id', AEvents[I].Id);
    LRow.Add('start_frame', AEvents[I].StartFrame);
    LRow.Add('end_frame', AEvents[I].EndFrame);
    LRow.Add('pitch', AEvents[I].Pitch);
  end;
end;

function AssignmentDocument(const AValue: TNoteAssignment): TJSONObject;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  LIds: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('onset_error_frames', AValue.OnsetErrorFrames);
  Result.Add('offset_error_frames', AValue.OffsetErrorFrames);
  LRows := TJSONArray.Create;
  Result.Add('pairs', LRows);
  for I := 0 to High(AValue.Pairs) do
  begin
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('reference_id', AValue.Pairs[I].ReferenceId);
    LRow.Add('prediction_id', AValue.Pairs[I].PredictionId);
    LRow.Add('onset_error_frames', AValue.Pairs[I].OnsetErrorFrames);
    LRow.Add('offset_error_frames', AValue.Pairs[I].OffsetErrorFrames);
  end;
  LIds := TJSONArray.Create;
  Result.Add('missed_ids', LIds);
  for I := 0 to High(AValue.MissedIds) do
  begin
    LIds.Add(AValue.MissedIds[I]);
  end;
  LIds := TJSONArray.Create;
  Result.Add('extra_ids', LIds);
  for I := 0 to High(AValue.ExtraIds) do
  begin
    LIds.Add(AValue.ExtraIds[I]);
  end;
end;

procedure ExactEventPairs(const AValue: TNoteAssignment; const ACount: Integer);
var
  I: Integer;
begin
  Check((Length(AValue.Pairs) = ACount) and (Length(AValue.MissedIds) = 0) and
    (Length(AValue.ExtraIds) = 0) and (AValue.OnsetErrorFrames = 0) and
    (AValue.OffsetErrorFrames = 0), 'Exact authored timing count/errors');
  for I := 0 to High(AValue.Pairs) do
  begin
    Check((AValue.Pairs[I].PredictionId = 'p-' + AValue.Pairs[I].ReferenceId) and
      (AValue.Pairs[I].OnsetErrorFrames = 0) and
      (AValue.Pairs[I].OffsetErrorFrames = 0), 'Exact authored timing identities');
  end;
end;

procedure TimingCases(const ASource, AScore: String);
const
  CCounts: array[0..3] of Integer = (4, 9, 5, 3);
var
  LReferences: array[0..3] of TEvaluationNotes;
  LReferenceHashes: array[0..3] of String;
  LPrediction: TEvaluationNotes;
  LRegions: TEvaluationNoteRegions;
  LOptions: TOverlappingNoteOptions;
  LScore: TOverlappingNoteEvaluation;
  LSwap: TEvaluationNote;
  LDoc: TJSONObject;
  LReport: TJSONObject;
  LIds: TJSONArray;
  LPolicyHash: String;
  LUnitHash: String;
  LRegionRows: TJSONArray;
  LRegionRow: TJSONObject;
  LPredictionHash: String;
  LCaseName: String;
  R: Integer;
  K: Integer;
  I: Integer;
begin
  LPolicyHash := HashAudioBytes(ReadFileBytes('docs/PART-CONTROL-TIMING-POLICY.md', 65536));
  LUnitHash := HashAudioBytes(ReadFileBytes('src/pythian.evaluation.notes.pas', 262144));
  for R := 0 to 3 do
  begin
    LReferences[R] := RoleEvents(R, False);
    Check(Length(LReferences[R]) = CCounts[R], 'Per-role authored event count');
    LDoc := EventDocument(LReferences[R], R, ASource);
    try
      LReferenceHashes[R] := Save('timing-reference-' + CNames[R] + '.json',
        LDoc.AsJSON, [AScore, ASource, LPolicyHash]);
    finally
      LDoc.Free;
    end;
  end;
  LOptions := Default(TOverlappingNoteOptions);
  LOptions.OffsetFractionDenominator := 1;
  for K := 0 to 6 do
  begin
    R := K;
    if K in [4, 5] then
    begin
      R := 2;
    end;
    if K = 6 then
    begin
      R := 3;
    end;
    LCaseName := CNames[R] + '-exact';
    LPrediction := RoleEvents(R, True);
    SetLength(LRegions, 1);
    LRegions[0].FirstFrame := 0;
    LRegions[0].EndFrame := CFrames;
    LRegions[0].State := esValue;
    if K = 4 then
    begin
      LCaseName := 'lead-offset';
      Check(LPrediction[2].Id = 'p-event-15', 'Offset damage target');
      Inc(LPrediction[2].EndFrame, 160);
    end;
    if K = 5 then
    begin
      LCaseName := 'lead-reversed';
      for I := 0 to Length(LPrediction) div 2 - 1 do
      begin
        LSwap := LPrediction[I];
        LPrediction[I] := LPrediction[High(LPrediction) - I];
        LPrediction[High(LPrediction) - I] := LSwap;
      end;
    end;
    if K = 6 then
    begin
      LCaseName := 'other-uncertain';
      SetLength(LRegions, 3);
      LRegions[0].EndFrame := 144000;
      LRegions[1].FirstFrame := 144000;
      LRegions[1].EndFrame := 160000;
      LRegions[1].State := esUnknown;
      LRegions[2].FirstFrame := 160000;
      LRegions[2].EndFrame := CFrames;
      LRegions[2].State := esValue;
    end;
    LDoc := EventDocument(LPrediction, R, ASource);
    try
      LPredictionHash := Save('timing-prediction-' + LCaseName + '.json',
        LDoc.AsJSON, [AScore, ASource, LPolicyHash]);
    finally
      LDoc.Free;
    end;
    LScore := EvaluateOverlappingNotes(LReferences[R], LPrediction, LRegions, 0, CFrames, LOptions);
    if K in [0, 1, 2, 3, 5] then
    begin
      ExactEventPairs(LScore.Onsets, CCounts[R]);
      ExactEventPairs(LScore.FullNotes, CCounts[R]);
    end;
    if K = 4 then
    begin
      Check((Length(LScore.Onsets.Pairs) = 5) and
        (LScore.Onsets.OnsetErrorFrames = 0) and (LScore.Onsets.OffsetErrorFrames = 160),
        'Offset damage keeps onsets distinct');
      Check((Length(LScore.FullNotes.Pairs) = 4) and
        (Length(LScore.FullNotes.MissedIds) = 1) and
        (Length(LScore.FullNotes.ExtraIds) = 1) and
        (LScore.FullNotes.MissedIds[0] = 'event-15') and
        (LScore.FullNotes.ExtraIds[0] = 'p-event-15') and
        (LScore.FullNotes.OnsetErrorFrames = 0) and (LScore.FullNotes.OffsetErrorFrames = 0),
        'Full-note offset damage identities');
      for I := 0 to High(LScore.Onsets.Pairs) do
      begin
        Check(LScore.Onsets.Pairs[I].PredictionId = 'p-' + LScore.Onsets.Pairs[I].ReferenceId,
          'Damaged onset pair identity');
      end;
    end;
    if K = 6 then
    begin
      ExactEventPairs(LScore.Onsets, 2);
      ExactEventPairs(LScore.FullNotes, 2);
      Check((Length(LScore.ReferenceUncertain) = 1) and
        (Length(LScore.PredictionUnscorable) = 1) and
        (LScore.ReferenceUncertain[0] = 'event-20') and
        (LScore.PredictionUnscorable[0] = 'p-event-20') and
        (LScore.RegionFrames[esUnknown] = 16000), 'Explicit interval uncertainty cohort');
    end;
    LReport := TJSONObject.Create;
    try
      LReport.Add('case', LCaseName);
      LReport.Add('role_id', CNames[R]);
      LReport.Add('source_sha256', ASource);
      LReport.Add('timing_unit_sha256', LUnitHash);
      LReport.Add('policy_sha256', LPolicyHash);
      LReport.Add('independent_acoustic_inference', False);
      LReport.Add('onsets', AssignmentDocument(LScore.Onsets));
      LReport.Add('full_notes', AssignmentDocument(LScore.FullNotes));
      LReport.Add('unknown_region_frames', LScore.RegionFrames[esUnknown]);
      LRegionRows := TJSONArray.Create;
      LReport.Add('scoring_regions', LRegionRows);
      for I := 0 to High(LRegions) do
      begin
        LRegionRow := TJSONObject.Create;
        LRegionRows.Add(LRegionRow);
        LRegionRow.Add('first_frame', LRegions[I].FirstFrame);
        LRegionRow.Add('end_frame', LRegions[I].EndFrame);
        if LRegions[I].State = esValue then
        begin
          LRegionRow.Add('state', 'value');
        end
        else
        begin
          LRegionRow.Add('state', 'unknown');
        end;
      end;
      LReport.Add('onset_tolerance_frames', 0);
      LReport.Add('minimum_offset_tolerance_frames', 0);
      LReport.Add('offset_fraction_numerator', 0);
      LReport.Add('offset_fraction_denominator', 1);
      LReport.Add('edge_frames', 0);
      LIds := TJSONArray.Create;
      LReport.Add('reference_uncertain', LIds);
      for I := 0 to High(LScore.ReferenceUncertain) do
      begin
        LIds.Add(LScore.ReferenceUncertain[I]);
      end;
      LIds := TJSONArray.Create;
      LReport.Add('prediction_unscorable', LIds);
      for I := 0 to High(LScore.PredictionUnscorable) do
      begin
        LIds.Add(LScore.PredictionUnscorable[I]);
      end;
      Save('timing-report-' + LCaseName + '.json', LReport.AsJSON,
        [LReferenceHashes[R], LPredictionHash, LPolicyHash, LUnitHash]);
    finally
      LReport.Free;
    end;
  end;
end;

procedure Controls;
begin
  Check(QuantizePcm16(0.5 / 32768) = 1, 'Positive half LSB');
  Check(QuantizePcm16(-0.5 / 32768) = -1, 'Negative half LSB');
  Check(QuantizePcm16((123 - 71 + 9) / 32768) = 61, 'Signed integer mixture');
  Check(FixedEnvelopeGain(0, 16000, 80, 80) = 0, 'No pre-gate attack energy');
  WriteLn('Independent quantization/signed-sum/envelope controls passed');
end;

procedure Run;
var
  LManifest: TJSONObject;
  LScoreHash: String;
  LSourceHash: String;
  LPolicyHash: String;
  LCodeHash: String;
  LRoot: String;
  LText: String;
begin
  if (ParamCount = 1) and (ParamStr(1) = '--controls') then
  begin
    Controls;
    Exit;
  end;
  Check(ParamCount = 1, 'Use NEW_OUTPUT_DIRECTORY or --controls');
  LRoot := IncludeTrailingPathDelimiter(ExpandFileName('build/role-controls'));
  GDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  Check((Pos(LRoot, GDirectory) = 1) and (Length(GDirectory) > Length(LRoot)), 'Output outside control workspace');
  Check(not DirectoryExists(GDirectory), 'Output directory already exists');
  Check(ForceDirectories(GDirectory), 'Cannot create output directory');
  GStart := GetTickCount64;
  GBytes := 0;
  LManifest := TJSONObject.Create;
  GArtifacts := TJSONArray.Create;
  LManifest.Add('artifacts', GArtifacts);
  try
    LPolicyHash := HashAudioBytes(ReadFileBytes('docs/PART-CONTROL-POLICY.md', 65536));
    LCodeHash := HashAudioBytes(ReadFileBytes('tools/pythian.part.controls.lpr', 262144));
    LManifest.Add('kind', 'authored-control-ancestry-manifest');
    LManifest.Add('partition', 'development');
    LManifest.Add('group_id', 'authored-role-controls');
    LManifest.Add('policy_sha256', LPolicyHash);
    LManifest.Add('renderer_sha256', LCodeHash);
    LManifest.Add('prediction_method', 'score-derived scorer controls, not inference');
    Score;
    VerifyScoreCohorts;
    LScoreHash := WriteScore(LPolicyHash, LCodeHash);
    Save('annotation.json', '{"kind":"authored-control-annotation",' +
      '"roles_declared_by_construction":true,"acoustic_gate_convention":' +
      '"5ms attack/release inside half-open gates; quantized support may be shorter",' +
      '"uncertain_first_frame":144000,"uncertain_end_frame":160000,' +
      '"uncertain_roles": ["lead","other"],"unassigned_pitch":72,' +
      '"scope_first_frame":0,"scope_end_frame":192000}', [LScoreHash, LPolicyHash]);
    LSourceHash := Render(LScoreHash);
    Cases(LSourceHash, LScoreHash);
    TimingCases(LSourceHash, LScoreHash);
    Check(HashAudioBytes(ReadFileBytes(GDirectory + 'score.json', 65536)) = LScoreHash, 'Authored score changed');
    LManifest.Add('elapsed_ms', GetTickCount64 - GStart);
    LText := LManifest.AsJSON;
    Check((GBytes + Length(LText) <= 8 * 1024 * 1024) and
      (GetTickCount64 - GStart <= 30000), 'Control packet resource budget');
    WriteTextFile(GDirectory + 'manifest.json', LText);
    WriteLn('Authored 12-second packet, exact integer mixture and six scoring controls verified');
  finally
    LManifest.Free;
    GArtifacts := nil;
  end;
end;

begin
  try
    Run;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
