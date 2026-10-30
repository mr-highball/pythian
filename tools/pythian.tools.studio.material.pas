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

unit pythian.tools.studio.material;

{$mode delphi}
{$H+}

interface

uses fpjson, pythian.music.pattern, pythian.music.sound;

const
  StudioMaterialFormat = 'pythian.studio.musical-material.v1';

{ Owned detached metadata. Preparing and saving choices never learns a model,
  writes audio, queues a job or replaces the immutable analysis evidence. }
function DefaultStudioMaterial: TJSONObject;
function CanonicalStudioMaterial(const AInput: TJSONObject): TJSONObject;
function ProposeStudioMaterial(const ACatalogRoot, AJobId: String;
  const ATempo: Integer = 0; const AChannel: Integer = 0): TJSONObject;
procedure ValidateStudioMaterialBinding(const ACatalogRoot: String;
  const AMaterial: TJSONObject);
function DecodeStudioPitchPattern(const AInput: TJSONArray): TPitchPattern;
function EncodeStudioPitchPattern(const APattern: TPitchPattern): TJSONArray;
function DecodeStudioSound(const AInput: TJSONObject): TMusicalSound;

implementation

uses SysUtils, Math, pythian.audio, pythian.hash, pythian.text, pythian.pitch.track,
  pythian.tools.studio.jobs, pythian.tools.studio.capture,
  pythian.tools.annotations.catalog;

const
  CMaterialFields = '|format|analysis_job_id|analysis_result_sha256|source|' +
    'tempo_bpm|tonic|mode|part|channel|tempo_decision|key_decision|pitch_decision|pattern|notes|';
  CSourceFields = '|kind|id|source_sha256|sample_rate|start_frame|end_frame|' +
    'title|source_group|partition|clock_id|license|provenance|';
  CSoundFields = '|part|cutoff_hz|sustain_percent|decision|available|';

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure Fields(const AObject: TJSONObject; const AFields: String;
  const ACount: Integer);
var
  LIndex: Integer;
begin
  Need((AObject <> nil) and (AObject.Count = ACount), 'Musical input has incomplete fields');
  for LIndex := 0 to AObject.Count - 1 do
  begin
    Need(Pos('|' + AObject.Names[LIndex] + '|', AFields) > 0,
      'Unsupported musical input field: ' + AObject.Names[LIndex]);
  end;
end;

function Text(const AObject: TJSONObject; const AName: String;
  const AMaximum: Integer): TJSONStringType;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtString),
    'Musical input requires text: ' + AName);
  Result := LValue.AsString;
  Need(Length(Result) <= AMaximum, 'Musical input text is too long: ' + AName);
  ValidateScalarText(Result, AMaximum);
end;

function Number(const AObject: TJSONObject; const AName: String;
  const AMinimum, AMaximum: Int64): Int64;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtNumber),
    'Musical input requires a whole number: ' + AName);
  Need((LValue.AsFloat >= AMinimum) and (LValue.AsFloat <= AMaximum) and
    (LValue.AsFloat = LValue.AsInt64), 'Musical input number is out of range: ' + AName);
  Result := LValue.AsInt64;
end;

procedure Hash(const AValue: String);
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, 64);
  WriteSha256Hex(LBytes, 0, AValue);
end;

function Decision(const AObject: TJSONObject; const AName: String): String;
begin
  Result := Text(AObject, AName, 16);
  Need((Result = 'accepted') or (Result = 'corrected') or
    (Result = 'manual') or (Result = 'bypassed'), 'Choose how to use each musical suggestion');
end;

function DecodeStudioSound(const AInput: TJSONObject): TMusicalSound;
begin
  Result.CutoffHz := Number(AInput, 'cutoff_hz', 100, 10000);
  Result.SustainPercent := Number(AInput, 'sustain_percent', 0, 100);
  ValidateMusicalSound(Result);
end;

function OrderedCopy(const AObject: TJSONObject; const AFields: String): TJSONObject;
var
  LStart, LEnd: Integer;
  LName: String;
begin
  Result := TJSONObject.Create;
  try
    LStart := 2;
    while LStart < Length(AFields) do
    begin
      LEnd := LStart;
      while AFields[LEnd] <> '|' do
      begin
        Inc(LEnd);
      end;
      LName := Copy(AFields, LStart, LEnd - LStart);
      Result.Add(LName, AObject.Find(LName).Clone);
      LStart := LEnd + 1;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function DecodeStudioPitchPattern(const AInput: TJSONArray): TPitchPattern;
var
  LIndex: Integer;
  LRow: TJSONObject;
  LKind: String;
  LValue: TJSONData;
begin
  Need((AInput <> nil) and (AInput.Count <= MaximumPitchPatternCells),
    'Use at most 256 eighth-note pitch cells');
  Result := nil;
  SetLength(Result, AInput.Count);
  for LIndex := 0 to AInput.Count - 1 do
  begin
    Need(AInput[LIndex].JSONType = jtObject, 'Pitch cells must be objects');
    LRow := AInput.Objects[LIndex];
    Fields(LRow, '|kind|note|velocity|attack|', 4);
    LKind := Text(LRow, 'kind', 16);
    Result[LIndex] := Default(TPitchPatternCell);
    if LKind = 'pitch' then
    begin
      Result[LIndex].Kind := pskPitch;
    end
    else if LKind = 'silence' then
    begin
      Result[LIndex].Kind := pskSilence;
    end
    else
    begin
      Need(LKind = 'unknown', 'Pitch cells are notes, silence or unknown');
      Result[LIndex].Kind := pskUnknown;
    end;
    Result[LIndex].Note := Number(LRow, 'note', -1, 127);
    Result[LIndex].Velocity := Number(LRow, 'velocity', 0, 127);
    LValue := LRow.Find('attack');
    Need((LValue <> nil) and (LValue.JSONType = jtBoolean), 'Pitch attack must be true or false');
    Result[LIndex].Attack := LValue.AsBoolean;
  end;
  if Length(Result) > 0 then
  begin
    ValidatePitchPattern(Result);
  end;
end;

function EncodeStudioPitchPattern(const APattern: TPitchPattern): TJSONArray;
var
  LCell: TPitchPatternCell;
  LRow: TJSONObject;
begin
  if Length(APattern) > 0 then
  begin
    ValidatePitchPattern(APattern);
  end;
  Result := TJSONArray.Create;
  try
    for LCell in APattern do
    begin
      LRow := TJSONObject.Create;
      Result.Add(LRow);
      case LCell.Kind of
        pskPitch: LRow.Add('kind', 'pitch');
        pskSilence: LRow.Add('kind', 'silence');
        pskUnknown: LRow.Add('kind', 'unknown');
      end;
      LRow.Add('note', LCell.Note);
      LRow.Add('velocity', LCell.Velocity);
      LRow.Add('attack', LCell.Attack);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function DefaultStudioMaterial: TJSONObject;
var
  LSource, LSound: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioMaterialFormat);
  Result.Add('analysis_job_id', '');
  Result.Add('analysis_result_sha256', '');
  LSource := TJSONObject.Create;
  Result.Add('source', LSource);
  LSource.Add('kind', 'manual');
  LSource.Add('id', '');
  LSource.Add('source_sha256', '');
  LSource.Add('sample_rate', 0);
  LSource.Add('start_frame', 0);
  LSource.Add('end_frame', 0);
  LSource.Add('title', '');
  LSource.Add('source_group', '');
  LSource.Add('partition', '');
  LSource.Add('clock_id', '');
  LSource.Add('license', '');
  LSource.Add('provenance', 'Operator-authored musical input');
  Result.Add('tempo_bpm', 120);
  Result.Add('tonic', 0);
  Result.Add('mode', 'major');
  Result.Add('part', -1);
  Result.Add('channel', -1);
  Result.Add('tempo_decision', 'manual');
  Result.Add('key_decision', 'manual');
  Result.Add('pitch_decision', 'bypassed');
  Result.Add('pattern', TJSONArray.Create);
  Result.Add('notes', '');
  LSound := TJSONObject.Create;
  Result.Add('sound', LSound);
  LSound.Add('part', -1);
  LSound.Add('cutoff_hz', 1800);
  LSound.Add('sustain_percent', 70);
  LSound.Add('decision', 'bypassed');
  LSound.Add('available', False);
end;

function CanonicalStudioMaterial(const AInput: TJSONObject): TJSONObject;
var
  LSource: TJSONObject;
  LCopySource: TJSONObject;
  LValue: TJSONData;
  LKind, LJob, LText: String;
  LPattern: TPitchPattern;
  LRate, LStart, LEnd: Int64;
  LPart: Integer;
  LSound: TJSONObject;
  LSoundValue: TJSONData;
begin
  Need(AInput <> nil, 'Musical input is missing');
  LSoundValue := AInput.Find('sound');
  Fields(AInput, CMaterialFields + 'sound|', 14 + Ord(LSoundValue <> nil));
  Need(Text(AInput, 'format', 64) = StudioMaterialFormat, 'Unknown musical input format');
  LJob := Text(AInput, 'analysis_job_id', 64);
  LValue := AInput.Find('source');
  Need((LValue <> nil) and (LValue.JSONType = jtObject), 'Musical input needs its source receipt');
  LSource := TJSONObject(LValue);
  Fields(LSource, CSourceFields, 12);
  LKind := Text(LSource, 'kind', 16);
  if LSoundValue <> nil then
  begin
    Need(LSoundValue.JSONType = jtObject, 'Sound starting point must be an object');
    LSound := TJSONObject(LSoundValue);
    Fields(LSound, CSoundFields, 5);
    LPart := Number(LSound, 'part', -1, 2);
    LText := Decision(LSound, 'decision');
    Need((LPart = -1) = (LText = 'bypassed'), 'Choose a sound target or bypass sound');
    DecodeStudioSound(LSound);
    LValue := LSound.Find('available');
    Need((LValue <> nil) and (LValue.JSONType = jtBoolean), 'Sound proposal availability is missing');
    if LKind = 'manual' then
      Need(not LValue.AsBoolean and ((LText = 'manual') or (LText = 'bypassed')),
        'Manual sound cannot claim a measured proposal');
    if (LText = 'accepted') or (LText = 'corrected') then
      Need(LValue.AsBoolean, 'This analysis has no sound suggestion; use manual controls');
  end;
  Text(LSource, 'title', 256);
  Text(LSource, 'source_group', 256);
  Text(LSource, 'partition', 32);
  Text(LSource, 'clock_id', 128);
  Text(LSource, 'license', 4096);
  Text(LSource, 'provenance', 8192);
  LRate := Number(LSource, 'sample_rate', 0, 384000);
  LStart := Number(LSource, 'start_frame', 0, 9007199254740991);
  LEnd := Number(LSource, 'end_frame', 0, 9007199254740991);
  if LKind = 'manual' then
  begin
    Need((LJob = '') and (Text(AInput, 'analysis_result_sha256', 64) = '') and
      (Text(LSource, 'id', 64) = '') and (Text(LSource, 'source_sha256', 64) = '') and
      (LRate = 0) and (LStart = 0) and (LEnd = 0), 'Manual input cannot claim measured source coordinates');
    Need((Decision(AInput, 'tempo_decision') = 'manual') or
      (Decision(AInput, 'tempo_decision') = 'bypassed'),
      'Manual input cannot claim an accepted tempo observation');
    Need((Decision(AInput, 'key_decision') = 'manual') or
      (Decision(AInput, 'key_decision') = 'bypassed'),
      'Manual input cannot claim an accepted key observation');
    Need((Decision(AInput, 'pitch_decision') = 'manual') or
      (Decision(AInput, 'pitch_decision') = 'bypassed'),
      'Manual input cannot claim accepted pitch observations');
  end
  else
  begin
    Need(((LKind = 'catalog') or (LKind = 'capture')) and (LJob <> ''),
      'Analyzed input requires a recording and analysis job');
    Hash(Text(AInput, 'analysis_result_sha256', 64));
    Hash(Text(LSource, 'source_sha256', 64));
    Need(Text(LSource, 'id', 64) <> '', 'Musical source ID is empty');
    ValidateAudioFormat(Integer(LRate), 1);
    Need((LEnd > LStart) and (LEnd - LStart <= LRate * 30), 'Musical input source exceeds its analyzed range');
  end;
  Number(AInput, 'tempo_bpm', 40, 240);
  Number(AInput, 'tonic', 0, 11);
  LText := Text(AInput, 'mode', 16);
  Need((LText = 'major') or (LText = 'natural_minor'), 'Choose major or natural minor accompaniment');
  LPart := Number(AInput, 'part', -1, 2);
  Number(AInput, 'channel', -1, 31);
  Decision(AInput, 'tempo_decision');
  Decision(AInput, 'key_decision');
  LText := Decision(AInput, 'pitch_decision');
  Need((LPart >= 0) or (LText = 'bypassed'), 'Assign pitch cells to a part or bypass them');
  if LText = 'bypassed' then
  begin
    Need(LPart = -1, 'Bypassed pitch cells cannot drive a part');
  end;
  LValue := AInput.Find('pattern');
  Need((LValue <> nil) and (LValue.JSONType = jtArray), 'Musical input needs its pitch cells');
  LPattern := DecodeStudioPitchPattern(TJSONArray(LValue));
  Need((LPart < 0) or (Length(LPattern) > 0), 'Enter pitch cells or bypass the pitch suggestion');
  Text(AInput, 'notes', 2048);
  Result := OrderedCopy(AInput, CMaterialFields);
  try
    Result.Integers['tempo_bpm'] := AInput.Integers['tempo_bpm'];
    Result.Integers['tonic'] := AInput.Integers['tonic'];
    Result.Integers['part'] := LPart;
    Result.Integers['channel'] := AInput.Integers['channel'];
    Result.Delete('source');
    LCopySource := OrderedCopy(LSource, CSourceFields);
    Result.Add('source', LCopySource);
    LCopySource.Integers['sample_rate'] := LRate;
    LCopySource.Int64s['start_frame'] := LStart;
    LCopySource.Int64s['end_frame'] := LEnd;
    Result.Delete('pattern');
    Result.Add('pattern', EncodeStudioPitchPattern(LPattern));
    if LSoundValue <> nil then
    begin
      Result.Add('sound', OrderedCopy(TJSONObject(LSoundValue), CSoundFields));
      LSound := Result.Objects['sound'];
      LSound.Integers['part'] := TJSONObject(LSoundValue).Integers['part'];
      LSound.Integers['cutoff_hz'] := TJSONObject(LSoundValue).Integers['cutoff_hz'];
      LSound.Integers['sustain_percent'] := TJSONObject(LSoundValue).Integers['sustain_percent'];
    end;
  except
    Result.Free;
    raise;
  end;
end;

function ProposeStudioMaterial(const ACatalogRoot, AJobId: String;
  const ATempo, AChannel: Integer): TJSONObject;
var
  LJob, LResult, LProposal, LSource, LTrack, LBeat, LChannel, LRow, LSound: TJSONObject;
  LRows: TJSONArray;
  LSpans: TPitchSpans;
  LPattern: TPitchPattern;
  LIndex, LTempo, LSuggested, LMicroseconds, LFrames, LRate: Integer;
  LKind: String;
  LCanonical: TJSONObject;
  LSoundRecipe: TMusicalSound;
begin
  LJob := ReadStudioJob(ACatalogRoot, AJobId);
  LTrack := nil;
  Result := nil;
  try
    try
      LKind := LJob.Strings['kind'];
      Need((LJob.Strings['status'] = 'completed') and
        ((LKind = 'inspect_source') or (LKind = 'capture_inspect')),
        'Finish recording analysis before using its musical suggestions');
      LResult := LJob.Objects['results'];
      Need((LResult.Find('musical_proposal') <> nil) and
        (LResult.Find('musical_proposal').JSONType = jtObject), 'Run Analyze again to prepare musical suggestions');
      LProposal := LResult.Objects['musical_proposal'];
      Result := DefaultStudioMaterial;
      LSound := Result.Objects['sound'];
      LSound.Booleans['available'] := ProposeMusicalSound(LProposal.Floats['mean_centroid_hz'],
        LProposal.Floats['minimum_window_rms'], LProposal.Floats['maximum_window_rms'], LSoundRecipe);
      if LSound.Booleans['available'] then
      begin
        LSound.Integers['cutoff_hz'] := LSoundRecipe.CutoffHz;
        LSound.Integers['sustain_percent'] := LSoundRecipe.SustainPercent;
      end;
      Result.Strings['analysis_job_id'] := AJobId;
      Result.Strings['analysis_result_sha256'] := StudioTextHash(LResult.AsJSON);
      LSource := Result.Objects['source'];
      LSource.Strings['source_sha256'] := LProposal.Strings['source_sha256'];
      LSource.Integers['sample_rate'] := LProposal.Integers['sample_rate'];
      LSource.Int64s['start_frame'] := LProposal.Int64s['start_frame'];
      LSource.Int64s['end_frame'] := LProposal.Int64s['end_frame'];
      if LKind = 'inspect_source' then
      begin
        Need(LJob.Objects['request'].Strings['source_sha256'] = LSource.Strings['source_sha256'],
          'Analysis source differs from its request');
        LTrack := ReadCatalogTrack(ACatalogRoot, LSource.Strings['source_sha256']);
        LSource.Strings['kind'] := 'catalog';
        LSource.Strings['id'] := LSource.Strings['source_sha256'];
        LSource.Strings['title'] := LTrack.Strings['title'];
        LSource.Strings['source_group'] := LTrack.Strings['source_group'];
        LSource.Strings['partition'] := LTrack.Strings['partition'];
        LSource.Strings['clock_id'] := LTrack.Strings['clock_id'];
        LSource.Strings['license'] := LTrack.Strings['license'];
        LSource.Strings['provenance'] := LTrack.Strings['provenance'];
      end
      else
      begin
        LTrack := ReadStudioCapture(ACatalogRoot, LJob.Objects['request'].Strings['capture_id']);
        LSource.Strings['kind'] := 'capture';
        LSource.Strings['id'] := LJob.Objects['request'].Strings['capture_id'];
        LSource.Strings['title'] := LTrack.Strings['name'];
        LSource.Strings['source_group'] := 'recording-' + LSource.Strings['source_sha256'];
        LSource.Strings['partition'] := 'unassigned';
        LSource.Strings['clock_id'] := '';
        LSource.Strings['license'] := 'unknown; caller-supplied private audio';
        LSource.Strings['provenance'] := 'Operator ' + LTrack.Strings['origin'] +
          '; independent recording status unverified';
      end;
      LSuggested := 0;
      if (LResult.Find('beat_proposal') <> nil) and
        (LResult.Objects['beat_proposal'].Find('candidates') <> nil) then
      begin
        LBeat := LResult.Objects['beat_proposal'];
        LRows := LBeat.Arrays['candidates'];
        if LRows.Count > 0 then
        begin
          LSuggested := Round(LRows.Objects[0].Floats['bpm']);
          if (LSuggested < 40) or (LSuggested > 240) then
          begin
            LSuggested := 0;
          end;
        end;
      end;
      LTempo := ATempo;
      if LTempo = 0 then
      begin
        LTempo := LSuggested;
      end;
      if LTempo = 0 then
      begin
        LTempo := 120;
      end;
      Need((LTempo >= 40) and (LTempo <= 240), 'Use 40 to 240 BPM for the musical grid');
      Result.Integers['tempo_bpm'] := LTempo;
      if LSuggested > 0 then
      begin
        Result.Strings['tempo_decision'] := 'accepted';
        if LTempo <> LSuggested then
        begin
          Result.Strings['tempo_decision'] := 'corrected';
        end;
      end;
      LRows := LProposal.Arrays['tonal_candidates'];
      if LRows.Count > 0 then
      begin
        Result.Integers['tonic'] := LRows.Objects[0].Integers['root'];
        Result.Strings['mode'] := LRows.Objects[0].Strings['mode'];
        Result.Strings['key_decision'] := 'accepted';
      end;
      LRows := LProposal.Arrays['pitch_channels'];
      Need((AChannel >= 0) and (AChannel < LRows.Count), 'Choose an analyzed audio channel');
      Result.Integers['channel'] := AChannel;
      LChannel := LRows.Objects[AChannel];
      LRows := LChannel.Arrays['spans'];
      SetLength(LSpans, LRows.Count);
      for LIndex := 0 to LRows.Count - 1 do
      begin
        LRow := LRows.Objects[LIndex];
        LSpans[LIndex] := Default(TPitchSpan);
        LKind := LRow.Strings['kind'];
        LSpans[LIndex].Kind := pskUnknown;
        if LKind = 'pitch' then
        begin
          LSpans[LIndex].Kind := pskPitch;
        end
        else if LKind = 'silence' then
        begin
          LSpans[LIndex].Kind := pskSilence;
        end
        else
        begin
          Need(LKind = 'unknown', 'Stored pitch observation has an unknown kind');
        end;
        LSpans[LIndex].StartFrame := LRow.Integers['start_frame'];
        LSpans[LIndex].EndFrame := LRow.Integers['end_frame'];
        LSpans[LIndex].Note := LRow.Integers['note'];
      end;
      LMicroseconds := Round(60000000 / LTempo);
      LFrames := LProposal.Integers['pitch_frame_count'];
      LRate := LProposal.Integers['pitch_sample_rate'];
      LPattern := nil;
      if (LRate > 0) and
        (LFrames >= (Int64(LMicroseconds) * LRate + 1999999) div 2000000) then
      begin
        LPattern := QuantizePitchPattern(LSpans, LRate, LFrames, LMicroseconds);
      end;
      Result.Delete('pattern');
      Result.Add('pattern', EncodeStudioPitchPattern(LPattern));
      LCanonical := CanonicalStudioMaterial(Result);
      Result.Free;
      Result := LCanonical;
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    LTrack.Free;
    LJob.Free;
  end;
end;

procedure ValidateStudioMaterialBinding(const ACatalogRoot: String;
  const AMaterial: TJSONObject);
var
  LCanonical, LExpected, LJob, LRow, LSound, LExpectedSound: TJSONObject;
  LRows: TJSONArray;
  LFound: Boolean;
  LIndex, LChannel: Integer;
begin
  LCanonical := CanonicalStudioMaterial(AMaterial);
  LExpected := nil;
  LJob := nil;
  try
    if LCanonical.Strings['analysis_job_id'] = '' then
    begin
      Need((Decision(LCanonical, 'key_decision') <> 'accepted') and
        (Decision(LCanonical, 'key_decision') <> 'corrected') and
        (Decision(LCanonical, 'pitch_decision') <> 'accepted') and
        (Decision(LCanonical, 'pitch_decision') <> 'corrected'),
        'Manual input cannot claim a measured observation');
      Exit;
    end;
    LChannel := LCanonical.Integers['channel'];
    if LChannel < 0 then
    begin
      LChannel := 0;
    end;
    LExpected := ProposeStudioMaterial(ACatalogRoot, LCanonical.Strings['analysis_job_id'],
      LCanonical.Integers['tempo_bpm'], LChannel);
    Need((LExpected.Strings['analysis_result_sha256'] = LCanonical.Strings['analysis_result_sha256']) and
      (LExpected.Objects['source'].AsJSON = LCanonical.Objects['source'].AsJSON),
      'Saved musical input differs from its original analysis; prepare it again');
    if LCanonical.Find('sound') <> nil then
    begin
      LSound := LCanonical.Objects['sound'];
      LExpectedSound := LExpected.Objects['sound'];
      Need(not LSound.Booleans['available'] or LExpectedSound.Booleans['available'],
        'Sound suggestion is not available in its original analysis');
      if LSound.Strings['decision'] = 'accepted' then
        Need((LSound.Integers['cutoff_hz'] = LExpectedSound.Integers['cutoff_hz']) and
          (LSound.Integers['sustain_percent'] = LExpectedSound.Integers['sustain_percent']),
          'Edited sound controls must be marked corrected or manual');
    end;
    if LCanonical.Strings['tempo_decision'] = 'accepted' then
    begin
      Need(LExpected.Strings['tempo_decision'] = 'accepted',
        'A changed tempo must be marked corrected or manual');
    end;
    if LCanonical.Strings['key_decision'] = 'accepted' then
    begin
      LJob := ReadStudioJob(ACatalogRoot, LCanonical.Strings['analysis_job_id']);
      LRows := LJob.Objects['results'].Objects['musical_proposal'].Arrays['tonal_candidates'];
      LFound := False;
      for LIndex := 0 to LRows.Count - 1 do
      begin
        LRow := LRows.Objects[LIndex];
        if (LRow.Integers['root'] = LCanonical.Integers['tonic']) and
          (LRow.Strings['mode'] = LCanonical.Strings['mode']) then
        begin
          LFound := True;
        end;
      end;
      Need(LFound, 'A different key must be marked corrected or manual');
    end;
    if LCanonical.Strings['pitch_decision'] = 'accepted' then
    begin
      Need((LCanonical.Integers['channel'] >= 0) and
        (LCanonical.Arrays['pattern'].AsJSON = LExpected.Arrays['pattern'].AsJSON),
        'Edited pitch cells must be marked corrected or manual');
    end;
  finally
    LJob.Free;
    LExpected.Free;
    LCanonical.Free;
  end;
end;

end.
