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
unit pythian.tools.annotations.contract;

{$mode delphi}
{$H+}

interface

uses
  SysUtils,
  fpjson;

type
  EAnswerContract = class(Exception);

{ A normalized request is the immutable meaning copied into a v2 review.
  The SHA covers its exact canonical JSON, including the question. }
function NormalizeStructuredRequest(const AItem: TJSONObject): TJSONObject;
function StructuredRequestHash(const ARequest: TJSONObject): String;
function FindPublishedStructuredRequest(const ACatalogRoot, AId,
  AExpectedHash: String): TJSONObject;
procedure ValidateStructuredChange(const AChange: TJSONObject;
  const ASourceHash: String);
function StructuredUnknown(const AChange: TJSONObject): Boolean;

implementation

uses
  Classes,
  jsonparser,
  pythian.hash;

const
  CMaximumQueueBytes = 1048576;
  CMaximumItems = 256;
  CMaximumValues = 32;
  CMaximumLinks = 8;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EAnswerContract.Create('Invalid structured answer: ' + AMessage);
end;

function TextField(const AObject: TJSONObject; const AName: String;
  const AMaximum: Integer; const AAllowEmpty: Boolean = False): String;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AName);
  Need((LData <> nil) and (LData.JSONType = jtString),
    'missing or invalid ' + AName);
  Result := LData.AsString;
  Need((Length(Result) <= AMaximum) and
    (AAllowEmpty or (Trim(Result) <> '')), 'invalid length for ' + AName);
end;

function IntField(const AObject: TJSONObject; const AName: String): Int64;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AName);
  Need((LData <> nil) and (LData.JSONType = jtNumber) and
    TryStrToInt64(LData.AsJSON, Result), 'missing or invalid ' + AName);
end;

function SafeId(const AValue: String; const AMaximum: Integer): Boolean;
var
  LIndex: Integer;
begin
  Result := (Length(AValue) > 0) and (Length(AValue) <= AMaximum);
  for LIndex := 1 to Length(AValue) do
    if not (AValue[LIndex] in
      ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.']) then
      Exit(False);
end;

function ValidHash(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := Length(AValue) = 64;
  for LIndex := 1 to Length(AValue) do
    if not (AValue[LIndex] in ['0'..'9', 'a'..'f']) then
      Exit(False);
end;

function ValidStructuredValue(const AType, AValue: String): Boolean;
var
  LIndex: Integer;
  LSeparator: Integer;
  LCode: Integer;
  LNumerator: Integer;
  LDenominator: Integer;
  LBpm: Double;
  LName: String;
begin
  if (AType = 'key') or (AType = 'harmony') then
  begin
    if (AValue = 'unknown') or (AValue = 'ambiguous') then
      Exit(True);
    if (AType = 'key') and (AValue = 'no_key') then
      Exit(True);
    LSeparator := Pos(':', AValue);
    if not (LSeparator in [2, 3]) or
      not (AValue[1] in ['A'..'G']) then
      Exit(False);
    if (LSeparator = 3) and not (AValue[2] in ['#', 'b']) then
      Exit(False);
    LName := Copy(AValue, LSeparator + 1, MaxInt);
    if (Length(LName) < 1) or (Length(LName) > 48) then
      Exit(False);
    for LIndex := 1 to Length(LName) do
      if not (LName[LIndex] in ['a'..'z', '0'..'9', '_']) then
        Exit(False);
    Exit(True);
  end;
  if AType = 'tempo' then
  begin
    if (AValue = 'unknown') or (AValue = 'ambiguous') then
      Exit(True);
    if (Length(AValue) < 1) or (Length(AValue) > 10) then
      Exit(False);
    LSeparator := 0;
    for LIndex := 1 to Length(AValue) do
      if AValue[LIndex] = '.' then
      begin
        if (LSeparator <> 0) or (LIndex = 1) or
          (LIndex = Length(AValue)) then Exit(False);
        LSeparator := LIndex;
      end
      else if not (AValue[LIndex] in ['0'..'9']) then Exit(False);
    if (LSeparator > 0) and
      (Length(AValue) - LSeparator > 6) then Exit(False);
    Val(AValue, LBpm, LCode);
    Exit((LCode = 0) and (LBpm >= 0.1) and (LBpm <= 1000));
  end;
  if AType = 'meter' then
  begin
    if (AValue = 'unknown') or (AValue = 'ambiguous') then
      Exit(True);
    LSeparator := Pos('/', AValue);
    if (LSeparator < 2) or (LSeparator >= Length(AValue)) or
      (Length(AValue) > 5) then Exit(False);
    for LIndex := 1 to Length(AValue) do
      if (LIndex <> LSeparator) and
        not (AValue[LIndex] in ['0'..'9']) then Exit(False);
    Result := TryStrToInt(Copy(AValue, 1, LSeparator - 1),
      LNumerator) and
      TryStrToInt(Copy(AValue, LSeparator + 1, MaxInt), LDenominator);
    if Result then
      Result := (LNumerator >= 1) and (LNumerator <= 64) and
        (LDenominator in [1, 2, 4, 8, 16, 32, 64]);
    Exit;
  end;
  if AType = 'presence' then
    Exit((AValue = 'audible') or (AValue = 'rest') or
      (AValue = 'unknown'));
  if AType = 'activity' then
    Exit((AValue = 'attack') or (AValue = 'continuation') or
      (AValue = 'release_tail') or (AValue = 'rest') or
      (AValue = 'unknown') or (AValue = 'noise_only'));
  Result := SafeId(AValue, 64);
end;

procedure Fields(const AObject: TJSONObject; const AAllowed: array of String);
var
  LIndex: Integer;
  LOther: Integer;
  LAllowedIndex: Integer;
  LFound: Boolean;
begin
  for LIndex := 0 to AObject.Count - 1 do
  begin
    LFound := False;
    for LAllowedIndex := Low(AAllowed) to High(AAllowed) do
      if AObject.Names[LIndex] = AAllowed[LAllowedIndex] then
        LFound := True;
    Need(LFound, 'unsupported field ' + AObject.Names[LIndex]);
    for LOther := 0 to LIndex - 1 do
      Need(AObject.Names[LIndex] <> AObject.Names[LOther],
        'duplicate field ' + AObject.Names[LIndex]);
  end;
end;

function FacetAllowed(const AType, AFacet: String): Boolean;
begin
  if (AType = 'beat') or (AType = 'downbeat') or
    (AType = 'note') or (AType = 'presence') or
    (AType = 'activity') or (AType = 'key') or
    (AType = 'tempo') or (AType = 'meter') or
    (AType = 'harmony') or (AType = 'part_role') or
    (AType = 'source_role') or (AType = 'phrase') or
    (AType = 'section') or (AType = 'style_preference') then
    Exit(AFacet = AType);
  if AType = 'ext.groove_trait' then
    Exit((AFacet = 'accent') or (AFacet = 'swing') or
      (AFacet = 'syncopation') or (AFacet = 'microtiming') or
      (AFacet = 'articulation') or (AFacet = 'role_relation') or
      (AFacet = 'velocity_relation'));
  if AType = 'ext.motif_relation' then
    Exit((AFacet = 'repetition') or (AFacet = 'variation') or
      (AFacet = 'section_transition'));
  Result := (AType = 'ext.pulse_evidence') and
    ((AFacet = 'omission') or (AFacet = 'distractor') or
     (AFacet = 'clock_gap') or (AFacet = 'phase_rate'));
end;

function ContainsText(const AValues: TJSONArray; const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  for LIndex := 0 to AValues.Count - 1 do
    if AValues.Strings[LIndex] = AValue then
      Exit(True);
end;

function NormalizeStructuredRequest(const AItem: TJSONObject): TJSONObject;
var
  LSpec: TJSONObject;
  LNormalizedSpec: TJSONObject;
  LValues: TJSONArray;
  LNormalizedValues: TJSONArray;
  LLinks: TJSONArray;
  LNormalizedLinks: TJSONArray;
  LLink: TJSONObject;
  LNormalizedLink: TJSONObject;
  LId: String;
  LHash: String;
  LType: String;
  LGeometry: String;
  LFacet: String;
  LValue: String;
  LKind: String;
  LRole: String;
  LTarget: String;
  LTargetType: String;
  LTargetRevision: Int64;
  LProposal: String;
  LPitches: TJSONArray;
  LNormalizedPitches: TJSONArray;
  LParts: TJSONArray;
  LNormalizedParts: TJSONArray;
  LPart: String;
  LPitch: Int64;
  LStart: Int64;
  LEnd: Int64;
  LIndex: Integer;
  LOther: Integer;
  LProposalLinks: Integer;
begin
  Need(AItem <> nil, 'request is missing');
  Fields(AItem, ['id', 'source_sha256', 'start_frame', 'end_frame',
    'question', 'title', 'label_type', 'answer_geometry', 'answer_spec']);
  LId := TextField(AItem, 'id', 128);
  Need(SafeId(LId, 128), 'invalid request id');
  LHash := TextField(AItem, 'source_sha256', 64);
  Need(ValidHash(LHash), 'invalid source hash');
  LStart := IntField(AItem, 'start_frame');
  LEnd := IntField(AItem, 'end_frame');
  Need((LStart >= 0) and (LEnd > LStart), 'invalid request interval');
  LType := TextField(AItem, 'label_type', 128);
  LGeometry := TextField(AItem, 'answer_geometry', 16);
  Need((LGeometry = 'exact') or (LGeometry = 'point') or
    (LGeometry = 'contained'), 'invalid structured answer geometry');
  Need((AItem.Find('answer_spec') <> nil) and
    (AItem.Find('answer_spec').JSONType = jtObject),
    'missing answer_spec');
  LSpec := AItem.Objects['answer_spec'];
  Fields(LSpec, ['facet', 'vocabulary', 'links', 'proposal_id',
    'pitch_midi_values', 'part_vocabulary']);
  LFacet := TextField(LSpec, 'facet', 48);
  Need(FacetAllowed(LType, LFacet), 'unsupported type or facet');
  if (LType = 'beat') or (LType = 'downbeat') then
    Need(LGeometry = 'point', 'beat marker needs point geometry')
  else if (LType = 'presence') or (LType = 'activity') then
    Need(LGeometry = 'exact', 'guided activity needs exact geometry')
  else if (LType = 'ext.pulse_evidence') and
    ((LFacet = 'omission') or (LFacet = 'distractor')) then
    Need(LGeometry = 'point', 'pulse marker needs point geometry')
  else if (LType = 'ext.motif_relation') and
    (LFacet = 'section_transition') then
    Need(LGeometry = 'point', 'section transition needs point geometry')
  else
    Need((LGeometry = 'exact') or (LGeometry = 'contained'),
      'facet needs span geometry');
  Need((LSpec.Find('vocabulary') <> nil) and
    (LSpec.Find('vocabulary').JSONType = jtArray),
    'missing vocabulary');
  LValues := LSpec.Arrays['vocabulary'];
  Need((LValues.Count >= 2) and (LValues.Count <= CMaximumValues),
    'vocabulary count exceeds bound');
  Need((LSpec.Find('links') <> nil) and
    (LSpec.Find('links').JSONType = jtArray), 'missing links');
  LLinks := LSpec.Arrays['links'];
  Need(LLinks.Count <= CMaximumLinks, 'link count exceeds bound');
  LProposal := TextField(LSpec, 'proposal_id', 128, True);
  Need((LProposal = '') or SafeId(LProposal, 128),
    'invalid proposal_id');
  Result := TJSONObject.Create;
  try
    Result.Add('id', LId);
    Result.Add('source_sha256', LHash);
    Result.Add('start_frame', LStart);
    Result.Add('end_frame', LEnd);
    Result.Add('question', TextField(AItem, 'question', 1024));
    if AItem.Find('title') <> nil then
      Result.Add('title', TextField(AItem, 'title', 256));
    Result.Add('label_type', LType);
    Result.Add('answer_geometry', LGeometry);
    LNormalizedSpec := TJSONObject.Create;
    Result.Add('answer_spec', LNormalizedSpec);
    LNormalizedSpec.Add('facet', LFacet);
    LNormalizedValues := TJSONArray.Create;
    LNormalizedSpec.Add('vocabulary', LNormalizedValues);
    for LIndex := 0 to LValues.Count - 1 do
    begin
      Need(LValues[LIndex].JSONType = jtString,
        'vocabulary value is not text');
      LValue := LValues.Strings[LIndex];
      Need((Length(LValue) <= 64) and
        ValidStructuredValue(LType, LValue),
        'invalid vocabulary value');
      for LOther := 0 to LIndex - 1 do
        Need(LNormalizedValues.Strings[LOther] <> LValue,
          'duplicate vocabulary value');
      LNormalizedValues.Add(LValue);
    end;
    Need(ContainsText(LNormalizedValues, 'unknown'),
      'vocabulary requires unknown');
    LNormalizedLinks := TJSONArray.Create;
    LNormalizedSpec.Add('links', LNormalizedLinks);
    LProposalLinks := 0;
    for LIndex := 0 to LLinks.Count - 1 do
    begin
      Need(LLinks[LIndex].JSONType = jtObject, 'link must be an object');
      LLink := LLinks.Objects[LIndex];
      Fields(LLink, ['role', 'kind', 'source_sha256', 'target_id',
        'target_type', 'target_revision']);
      LRole := TextField(LLink, 'role', 48);
      Need(SafeId(LRole, 48), 'invalid link role');
      for LOther := 0 to LIndex - 1 do
        Need(LNormalizedLinks.Objects[LOther].Strings['role'] <> LRole,
          'duplicate link role');
      LKind := TextField(LLink, 'kind', 16);
      Need((LKind = 'label') or (LKind = 'proposal'),
        'invalid link kind');
      Need(TextField(LLink, 'source_sha256', 64) = LHash,
        'cross-source link is unsupported');
      LTarget := TextField(LLink, 'target_id', 128);
      Need(SafeId(LTarget, 128), 'invalid link target');
      LNormalizedLink := TJSONObject.Create;
      LNormalizedLinks.Add(LNormalizedLink);
      LNormalizedLink.Add('role', LRole);
      LNormalizedLink.Add('kind', LKind);
      LNormalizedLink.Add('source_sha256', LHash);
      LNormalizedLink.Add('target_id', LTarget);
      if LKind = 'label' then
      begin
        LTargetType := TextField(LLink, 'target_type', 128);
        Need(SafeId(LTargetType, 128), 'invalid target type');
        Need(LTarget <> LId, 'self link is unsupported');
        LTargetRevision := IntField(LLink, 'target_revision');
        Need((LTargetRevision > 0) and (LTargetRevision <= 100000),
          'invalid target revision');
        LNormalizedLink.Add('target_type', LTargetType);
        LNormalizedLink.Add('target_revision', LTargetRevision);
      end
      else
      begin
        Need(LLink.Find('target_type') = nil,
          'proposal link cannot declare target_type');
        Need(LLink.Find('target_revision') = nil,
          'proposal link cannot declare target_revision');
        Inc(LProposalLinks);
      end;
    end;
    if (LType = 'ext.motif_relation') or
      (LFacet = 'role_relation') or (LFacet = 'velocity_relation') then
      Need(LNormalizedLinks.Count >= 1, 'facet requires a target link');
    if LFacet = 'phase_rate' then
      Need(LProposalLinks = 2, 'phase_rate requires two proposal links');
    LNormalizedSpec.Add('proposal_id', LProposal);
    if LSpec.Find('pitch_midi_values') <> nil then
    begin
      Need(LType = 'note', 'pitch vocabulary requires note type');
      Need(LSpec.Find('pitch_midi_values').JSONType = jtArray,
        'pitch_midi_values must be an array');
      LPitches := LSpec.Arrays['pitch_midi_values'];
      Need((LPitches.Count > 0) and (LPitches.Count <= 128),
        'pitch vocabulary count exceeds bound');
      LNormalizedPitches := TJSONArray.Create;
      LNormalizedSpec.Add('pitch_midi_values', LNormalizedPitches);
      for LIndex := 0 to LPitches.Count - 1 do
      begin
        Need((LPitches[LIndex].JSONType = jtNumber) and
          TryStrToInt64(LPitches[LIndex].AsJSON, LPitch) and
          (LPitch >= 0) and (LPitch <= 127),
          'invalid pitch vocabulary value');
        for LOther := 0 to LIndex - 1 do
          Need(LNormalizedPitches.Integers[LOther] <> LPitch,
            'duplicate pitch vocabulary value');
        LNormalizedPitches.Add(LPitch);
      end;
    end;
    if LSpec.Find('part_vocabulary') <> nil then
    begin
      Need(LSpec.Find('part_vocabulary').JSONType = jtArray,
        'part_vocabulary must be an array');
      LParts := LSpec.Arrays['part_vocabulary'];
      Need((LParts.Count > 0) and (LParts.Count <= 32),
        'part vocabulary count exceeds bound');
      LNormalizedParts := TJSONArray.Create;
      LNormalizedSpec.Add('part_vocabulary', LNormalizedParts);
      for LIndex := 0 to LParts.Count - 1 do
      begin
        Need(LParts[LIndex].JSONType = jtString,
          'part vocabulary value is not text');
        LPart := LParts.Strings[LIndex];
        Need((LPart = '') or SafeId(LPart, 128),
          'invalid part vocabulary value');
        for LOther := 0 to LIndex - 1 do
          Need(LNormalizedParts.Strings[LOther] <> LPart,
            'duplicate part vocabulary value');
        LNormalizedParts.Add(LPart);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function StructuredRequestHash(const ARequest: TJSONObject): String;
var
  LStream: TMemoryStream;
  LText: UTF8String;
begin
  LText := UTF8String(ARequest.AsJSON);
  LStream := TMemoryStream.Create;
  try
    if Length(LText) > 0 then
      LStream.WriteBuffer(LText[1], Length(LText));
    LStream.Position := 0;
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function FindPublishedStructuredRequest(const ACatalogRoot, AId,
  AExpectedHash: String): TJSONObject;
var
  LPath: String;
  LStream: TFileStream;
  LText: String;
  LData: TJSONData;
  LRoot: TJSONObject;
  LItems: TJSONArray;
  LIndex: Integer;
begin
  Result := nil;
  Need(SafeId(AId, 128) and ValidHash(AExpectedHash),
    'invalid request identity');
  LPath := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'review-queue.json';
  LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size > 0) and (LStream.Size <= CMaximumQueueBytes),
      'queue size exceeds bound');
    SetLength(LText, Integer(LStream.Size));
    LStream.ReadBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
  LData := GetJSON(LText);
  try
    try
      Need(LData.JSONType = jtObject, 'queue root must be an object');
      LRoot := TJSONObject(LData);
      Fields(LRoot, ['version', 'items']);
      Need(IntField(LRoot, 'version') = 2,
        'current queue is not structured version 2');
      Need((LRoot.Find('items') <> nil) and
        (LRoot.Find('items').JSONType = jtArray), 'queue items missing');
      LItems := LRoot.Arrays['items'];
      Need(LItems.Count <= CMaximumItems, 'queue item count exceeds bound');
      for LIndex := 0 to LItems.Count - 1 do
      begin
        Need(LItems[LIndex].JSONType = jtObject,
          'queue item is not an object');
        if TextField(LItems.Objects[LIndex], 'id', 128) = AId then
        begin
          Need(Result = nil, 'duplicate request id');
          Result := NormalizeStructuredRequest(LItems.Objects[LIndex]);
        end;
      end;
      Need(Result <> nil, 'request is absent from current queue');
      Need(StructuredRequestHash(Result) = AExpectedHash,
        'request meaning changed');
    except
      Result.Free;
      raise;
    end;
  finally
    LData.Free;
  end;
end;

procedure ValidateStructuredChange(const AChange: TJSONObject;
  const ASourceHash: String);
var
  LRequest: TJSONObject;
  LNormalized: TJSONObject;
  LSpec: TJSONObject;
  LValues: TJSONArray;
  LStart: Int64;
  LEnd: Int64;
  LRegionStart: Int64;
  LRegionEnd: Int64;
  LGeometry: String;
  LPitches: TJSONArray;
  LParts: TJSONArray;
  LPitch: Int64;
  LIndex: Integer;
  LFound: Boolean;
begin
  Need((AChange.Find('request') <> nil) and
    (AChange.Find('request').JSONType = jtObject),
    'v2 change requires request');
  LRequest := AChange.Objects['request'];
  LNormalized := NormalizeStructuredRequest(LRequest);
  try
    Need(LNormalized.AsJSON = LRequest.AsJSON,
      'request snapshot is not canonical');
    Need(TextField(AChange, 'request_sha256', 64) =
      StructuredRequestHash(LRequest), 'request hash differs');
    Need(LRequest.Strings['source_sha256'] = ASourceHash,
      'request source differs');
    Need(LRequest.Strings['id'] = AChange.Strings['label_id'],
      'request label identity differs');
    Need(LRequest.Strings['label_type'] = AChange.Strings['type'],
      'request label type differs');
    if Copy(AChange.Strings['type'], 1, 4) = 'ext.' then
      Need(IntField(AChange, 'extension_version') = 2,
        'extension version differs');
    LSpec := LRequest.Objects['answer_spec'];
    LValues := LSpec.Arrays['vocabulary'];
    Need(ContainsText(LValues, AChange.Strings['value']),
      'value is outside declared vocabulary');
    Need(AChange.Strings['proposal_id'] =
      LSpec.Strings['proposal_id'], 'proposal binding differs');
    if LSpec.Find('part_vocabulary') = nil then
      Need(AChange.Strings['part'] = '',
        'part is outside declared vocabulary')
    else
    begin
      LParts := LSpec.Arrays['part_vocabulary'];
      Need(ContainsText(LParts, AChange.Strings['part']),
        'part is outside declared vocabulary');
    end;
    if AChange.Strings['type'] = 'note' then
    begin
      if (AChange.Strings['value'] = 'unknown') or
        (AChange.Strings['value'] = 'ambiguous') then
        Need(AChange.Find('pitch_midi') = nil,
          'unknown note cannot assert MIDI pitch')
      else
      begin
        LPitch := IntField(AChange, 'pitch_midi');
        Need((LPitch >= 0) and (LPitch <= 127), 'invalid MIDI pitch');
        if LSpec.Find('pitch_midi_values') <> nil then
        begin
          LPitches := LSpec.Arrays['pitch_midi_values'];
          LFound := False;
          for LIndex := 0 to LPitches.Count - 1 do
            if LPitches.Integers[LIndex] = LPitch then
              LFound := True;
          Need(LFound, 'pitch is outside declared vocabulary');
        end;
      end;
    end;
    LStart := AChange.Int64s['start_frame'];
    LEnd := AChange.Int64s['end_frame'];
    LRegionStart := LRequest.Int64s['start_frame'];
    LRegionEnd := LRequest.Int64s['end_frame'];
    LGeometry := LRequest.Strings['answer_geometry'];
    Need((LStart >= LRegionStart) and (LEnd <= LRegionEnd) and
      (LEnd > LStart), 'answer lies outside request region');
    if LGeometry = 'point' then
      Need(LEnd = LStart + 1, 'point answer must span one frame')
    else if LGeometry = 'exact' then
      Need((LStart = LRegionStart) and (LEnd = LRegionEnd),
        'exact answer differs from request region');
  finally
    LNormalized.Free;
  end;
end;

function StructuredUnknown(const AChange: TJSONObject): Boolean;
begin
  Result := (AChange.Find('request') <> nil) and
    ((AChange.Strings['value'] = 'unknown') or
     (AChange.Strings['value'] = 'ambiguous'));
end;

end.
