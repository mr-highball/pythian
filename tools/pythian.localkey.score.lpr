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
program pythian_localkey_score;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, jsonparser,
  pythian.audio, pythian.tools.files;

const
  CSourceRate = 22050;
  CChangeFlank = 22050;
  CChangeTolerance = 5513;
  CMaximumSegments = 16384;
  CGroups: array[0..3] of String =
    ('Schubert_D911-02', 'Schubert_D911-16',
     'Schubert_D911-05', 'Schubert_D911-19');
  CReferenceHashes: array[0..3] of String = (
    'e3c3f71cc6d56023498dffdf60f0349e2a786d92db049b680e809f73b78b4936',
    'e92896a0ea0d762d7bc8d0d290a9992de47c3b5a7d9004f80eb502e21d44dae0',
    '8a3de2a494cb89cd49e1851b2f19943e6b33c1258c6f1bbe88d624f2a85f2daa',
    '3c6f2dfde15de4319821f9276e578c8a21233470822c7b1bb84672172a2de4db');
  CWaveHashes: array[0..3] of String = (
    '82df858661d662f162ab3bd3066925dc0faefeb3429584c152bc7b5e91c4e0d2',
    'a3e314904d5c694826d85ddf4723b1988d4ef4571df47760c698a22cc094d253',
    '8bf3910a59742e39349fbd9d6002cfea9f94f738ce674de0e0a35e29af83433f',
    '2e4cb9fd8c22254d25dc9fddb543d063709f326f92ab7691e6013ca652164937');
  CNoKeyReferenceHashes: array[0..1] of String = (
    '1a42695f1064303311094a51d8d064d52fc554b2cde3bf420f90d6604cc4b0bd',
    'c347444a076e7e9df50c6db3acda0b867ac45f4c72b1f9b2cecb19d9bb5826d5');
  CNoKeyWaveHashes: array[0..1] of String = (
    '21f958d0842eee1dfa938dc62758eaca3415fe3f54caa15af16288d88d26e59d',
    '4d30dcedccb960d838c23103202717909867d6a544a1af41207586f6b1bc7dfb');
  CNoKeyWindowHashes: array[0..1] of String = (
    '606061791a90bf8d9b00c89bff53bc26b963dcdbea984d0cddc4a7f006d2702b',
    '1f5a2ba792abc78a74cc1609ad0589d5392c660ba843aba54a67c9deb83c0732');
  CNoKeySourceFrames: array[0..1] of Int64 = (1512630, 2592389);
  CNoKeyStartFrames: array[0..1] of Int64 = (352800, 793800);
  CNoKeyWindowFrames = 441000;
  CNoKeyRate = 44100;

type
  TReferenceClass = (rcUnlabelled, rcPartial, rcConflict, rcSupported);
  TRegion = record
    First: Int64;
    Limit: Int64;
    Kind: TReferenceClass;
    Key: Integer;
  end;
  TRegions = array of TRegion;
  TSegment = record
    First: Int64;
    Limit: Int64;
    Key: Integer;
  end;
  TSegments = array of TSegment;
  TScore = record
    SupportedFrames: Int64;
    SupportedAdmittedFrames: Int64;
    SupportedCorrectFrames: Int64;
    ConflictFrames: Int64;
    ConflictUnknownFrames: Int64;
    ExcludedUnlabelledFrames: Int64;
    ExcludedPartialFrames: Int64;
    ChangeEvents: Int64;
    CorrectChangeEvents: Int64;
    EligibleStableInteriorFrames: Int64;
    SpuriousKnownKeyTransitions: Int64;
  end;
  TNoKeyScore = record
    NoKeyFrames: Int64;
    CorrectUnknownFrames: Int64;
    FalseKeyFrames: Int64;
  end;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create(AMessage);
end;

function BoundJSON(const APath: String; const AMaximumBytes: Integer;
  out AHash: String): TJSONData;
var
  LBytes: TAudioBytes;
  LText: String;
begin
  LBytes := ReadFileBytes(APath, AMaximumBytes);
  Require(Length(LBytes) > 0, 'Empty packet JSON');
  AHash := HashAudioBytes(LBytes);
  SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
  Result := GetJSON(LText);
  try
    Require(Result.JSONType = jtObject, 'Expected packet object');
  except
    Result.Free;
    raise;
  end;
end;

function KeyValue(const AText: String): Integer;
const
  CRoots: array[0..16] of String =
    ('C', 'C#', 'Db', 'D', 'D#', 'Eb', 'E', 'F', 'F#',
     'Gb', 'G', 'G#', 'Ab', 'A', 'A#', 'Bb', 'B');
  CValues: array[0..16] of Integer =
    (0, 1, 1, 2, 3, 3, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11);
var
  LColon: Integer;
  LRoot: String;
  LMode: String;
  I: Integer;
begin
  LColon := Pos(':', AText);
  Require(LColon > 1, 'Invalid key syntax');
  LRoot := Copy(AText, 1, LColon - 1);
  LMode := Copy(AText, LColon + 1, MaxInt);
  Require((LMode = 'maj') or (LMode = 'min'), 'Unsupported key mode');
  for I := Low(CRoots) to High(CRoots) do
  begin
    if LRoot = CRoots[I] then
    begin
      Result := CValues[I];
      if LMode = 'min' then Inc(Result, 12);
      Exit;
    end;
  end;
  raise EAudio.Create('Unsupported key root');
end;

function ReadKey(const AData: TJSONData): Integer;
begin
  Require(AData <> nil, 'Missing key field');
  if AData.JSONType = jtNull then Exit(-1);
  Require(AData.JSONType = jtString, 'Expected key string or null');
  Result := KeyValue(AData.AsString);
end;

function JSONInt64(const AObject: TJSONObject; const AName: String): Int64;
var
  LData: TJSONData;
begin
  LData := AObject.FindPath(AName);
  Require(LData <> nil, 'Missing integer: ' + AName);
  Require((LData.JSONType = jtNumber) and
    TryStrToInt64(LData.AsJSON, Result),
    'Expected exact integer: ' + AName);
end;

function ReferenceClass(const AText: String): TReferenceClass;
begin
  if AText = 'unlabelled' then Exit(rcUnlabelled);
  if AText = 'partial_coverage' then Exit(rcPartial);
  if AText = 'full_disagreement' then Exit(rcConflict);
  if AText = 'unanimous' then Exit(rcSupported);
  raise EAudio.Create('Unknown reference coverage class');
end;

function ParseReference(const AData: TJSONObject; const AHash: String;
  out AGroupIndex: Integer; out AFrames: Int64): TRegions;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  LKeys: TJSONArray;
  LGroup: String;
  LRole: String;
  I: Integer;
  J: Integer;
  LFirstKey: Integer;
  LCoverage: Integer;
  LDisagreement: Boolean;
begin
  Result := nil;
  LGroup := AData.Get('composition_group', '');
  AGroupIndex := -1;
  for I := Low(CGroups) to High(CGroups) do
    if LGroup = CGroups[I] then AGroupIndex := I;
  Require(AGroupIndex >= 0, 'Unbound composition group');
  Require(AHash = CReferenceHashes[AGroupIndex],
    'Reference report SHA256 mismatch');
  LRole := AData.Get('role', '');
  if AGroupIndex < 2 then
    Require(LRole = 'development', 'Development role mismatch')
  else
    Require(LRole = 'independent_evaluation', 'Evaluation role mismatch');
  Require(AData.Get('source_sha256', '') = CWaveHashes[AGroupIndex],
    'Reference source identity mismatch');
  Require(AData.Get('source_rate', 0) = CSourceRate,
    'Reference rate mismatch');
  AFrames := JSONInt64(AData, 'source_frames');
  Require((AFrames > 0) and (AFrames <= 360 * CSourceRate),
    'Reference extent out of bound');
  LRows := TJSONArray(AData.FindPath('regions'));
  Require((LRows <> nil) and (LRows.Count > 0) and
    (LRows.Count <= CMaximumSegments), 'Reference partition bound');
  SetLength(Result, LRows.Count);
  for I := 0 to LRows.Count - 1 do
  begin
    LRow := TJSONObject(LRows.Items[I]);
    Result[I].First := JSONInt64(LRow, 'start_frame');
    Result[I].Limit := JSONInt64(LRow, 'end_frame');
    if I = 0 then
      Require(Result[I].First = 0, 'Reference does not start at zero')
    else
      Require(Result[I].First = Result[I - 1].Limit,
        'Reference partition gap or overlap');
    Require((Result[I].First < Result[I].Limit) and
      (Result[I].Limit <= AFrames), 'Reference interval bounds');
    Result[I].Kind := ReferenceClass(LRow.Get('category', ''));
    LKeys := TJSONArray(LRow.FindPath('annotator_keys'));
    Require((LKeys <> nil) and (LKeys.Count = 3),
      'Reference annotator vector');
    LCoverage := 0;
    LFirstKey := -1;
    LDisagreement := False;
    for J := 0 to 2 do
    begin
      if LKeys.Items[J].JSONType <> jtNull then
      begin
        Inc(LCoverage);
        if LFirstKey < 0 then
          LFirstKey := ReadKey(LKeys.Items[J])
        else if ReadKey(LKeys.Items[J]) <> LFirstKey then
          LDisagreement := True;
      end;
    end;
    Result[I].Key := -1;
    case Result[I].Kind of
      rcUnlabelled: Require(LCoverage = 0, 'Unlabelled coverage mismatch');
      rcPartial: Require((LCoverage > 0) and (LCoverage < 3),
        'Partial coverage mismatch');
      rcConflict: Require((LCoverage = 3) and LDisagreement,
        'Conflict coverage mismatch');
      rcSupported:
      begin
        Require((LCoverage = 3) and not LDisagreement,
          'Supported coverage mismatch');
        Result[I].Key := LFirstKey;
      end;
    end;
  end;
  Require(Result[High(Result)].Limit = AFrames,
    'Reference partition does not finish');
end;

function ParsePredictions(const AData: TJSONObject;
  const AGroupIndex: Integer; const AFrames: Int64;
  out AKind: String): TSegments;
var
  LJSONRows: TJSONData;
  LRows: TJSONArray;
  LRow: TJSONObject;
  I: Integer;
begin
  Result := nil;
  AKind := AData.Get('prediction_kind', '');
  Require((AKind = 'synthetic_control') or (AKind = 'candidate_inference'),
    'Prediction kind must identify synthetic or candidate inference');
  Require(AData.Get('composition_group', '') = CGroups[AGroupIndex],
    'Prediction composition mismatch');
  Require(AData.Get('source_sha256', '') = CWaveHashes[AGroupIndex],
    'Prediction source mismatch');
  Require(JSONInt64(AData, 'source_frames') = AFrames,
    'Prediction extent mismatch');
  LJSONRows := AData.FindPath('segments');
  Require((LJSONRows <> nil) and (LJSONRows.JSONType = jtArray),
    'Expected prediction segments');
  LRows := TJSONArray(LJSONRows);
  Require((LRows.Count > 0) and
    (LRows.Count <= CMaximumSegments), 'Prediction segment bound');
  SetLength(Result, LRows.Count);
  for I := 0 to LRows.Count - 1 do
  begin
    Require(LRows.Items[I].JSONType = jtObject,
      'Expected prediction segment object');
    LRow := TJSONObject(LRows.Items[I]);
    Result[I].First := JSONInt64(LRow, 'start_frame');
    Result[I].Limit := JSONInt64(LRow, 'end_frame');
    Result[I].Key := ReadKey(LRow.FindPath('key'));
    if I = 0 then
      Require(Result[I].First = 0, 'Prediction does not start at zero')
    else
    begin
      Require(Result[I].First = Result[I - 1].Limit,
        'Prediction gap or overlap');
      Require(Result[I].Key <> Result[I - 1].Key,
        'Redundant prediction boundary');
    end;
    Require((Result[I].First < Result[I].Limit) and
      (Result[I].Limit <= AFrames), 'Prediction interval bounds');
  end;
  Require(Result[High(Result)].Limit = AFrames,
    'Prediction does not cover source');
end;

function Score(const AReference: TRegions; const APredictions: TSegments;
  const AFrames: Int64): TScore;
var
  LFirst: Int64;
  LLimit: Int64;
  LSpan: Int64;
  LBoundary: Int64;
  LTransitions: Integer;
  LMatched: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  I := 0;
  J := 0;
  while (I < Length(AReference)) and (J < Length(APredictions)) do
  begin
    if AReference[I].First > APredictions[J].First then
      LFirst := AReference[I].First
    else
      LFirst := APredictions[J].First;
    if AReference[I].Limit < APredictions[J].Limit then
      LLimit := AReference[I].Limit
    else
      LLimit := APredictions[J].Limit;
    Require(LFirst < LLimit, 'Partition intersection failure');
    LSpan := LLimit - LFirst;
    case AReference[I].Kind of
      rcUnlabelled: Inc(Result.ExcludedUnlabelledFrames, LSpan);
      rcPartial: Inc(Result.ExcludedPartialFrames, LSpan);
      rcConflict:
      begin
        Inc(Result.ConflictFrames, LSpan);
        if APredictions[J].Key = -1 then
          Inc(Result.ConflictUnknownFrames, LSpan);
      end;
      rcSupported:
      begin
        Inc(Result.SupportedFrames, LSpan);
        if APredictions[J].Key >= 0 then
          Inc(Result.SupportedAdmittedFrames, LSpan);
        if AReference[I].Key = APredictions[J].Key then
          Inc(Result.SupportedCorrectFrames, LSpan);
      end;
    end;
    if AReference[I].Limit = LLimit then Inc(I);
    if APredictions[J].Limit = LLimit then Inc(J);
  end;
  Require((I = Length(AReference)) and (J = Length(APredictions)) and
    (Result.SupportedFrames + Result.ConflictFrames +
     Result.ExcludedUnlabelledFrames + Result.ExcludedPartialFrames = AFrames),
    'Scored frame conservation');
  Require((Result.SupportedCorrectFrames <= Result.SupportedAdmittedFrames) and
    (Result.SupportedAdmittedFrames <= Result.SupportedFrames),
    'Supported admission counts are not conserved');
  for I := 1 to High(AReference) do
  begin
    if (AReference[I - 1].Kind <> rcSupported) or
      (AReference[I].Kind <> rcSupported) or
      (AReference[I - 1].Key = AReference[I].Key) or
      (AReference[I - 1].Limit - AReference[I - 1].First < CChangeFlank) or
      (AReference[I].Limit - AReference[I].First < CChangeFlank) then
      Continue;
    Inc(Result.ChangeEvents);
    LBoundary := AReference[I].First;
    LTransitions := 0;
    LMatched := False;
    for K := 1 to High(APredictions) do
    begin
      if Abs(APredictions[K].First - LBoundary) < CChangeFlank then
      begin
        Inc(LTransitions);
        if (Abs(APredictions[K].First - LBoundary) <= CChangeTolerance) and
          (APredictions[K - 1].Key = AReference[I - 1].Key) and
          (APredictions[K].Key = AReference[I].Key) then
          LMatched := True;
      end;
    end;
    if (LTransitions = 1) and LMatched then
      Inc(Result.CorrectChangeEvents);
  end;
  I := 0;
  while I < Length(AReference) do
  begin
    if AReference[I].Kind <> rcSupported then
    begin
      Inc(I);
      Continue;
    end;
    J := I + 1;
    while (J < Length(AReference)) and
      (AReference[J].Kind = rcSupported) and
      (AReference[J].Key = AReference[I].Key) and
      (AReference[J].First = AReference[J - 1].Limit) do
      Inc(J);
    LFirst := AReference[I].First;
    LLimit := AReference[J - 1].Limit;
    if LLimit - LFirst > 2 * CChangeFlank then
    begin
      Inc(Result.EligibleStableInteriorFrames,
        LLimit - LFirst - 2 * CChangeFlank);
      for K := 1 to High(APredictions) do
        if (APredictions[K - 1].Key >= 0) and
          (APredictions[K].Key >= 0) and
          (APredictions[K - 1].Key <> APredictions[K].Key) and
          (APredictions[K].First >= LFirst + CChangeFlank) and
          (APredictions[K].First <= LLimit - CChangeFlank) then
          Inc(Result.SpuriousKnownKeyTransitions);
    end;
    I := J;
  end;
end;

function ScoreNoKey(const APredictions: TSegments; const AStart,
  ALimit: Int64): TNoKeyScore;
var
  LSpan: Int64;
  I: Integer;
begin
  Result := Default(TNoKeyScore);
  Require((AStart >= 0) and (ALimit - AStart = CNoKeyWindowFrames),
    'Reviewed no-key window geometry differs');
  Require((Length(APredictions) > 0) and
    (Length(APredictions) <= CMaximumSegments),
    'No-key prediction segment count outside bound');
  for I := 0 to High(APredictions) do
  begin
    if I = 0 then
      Require(APredictions[I].First = AStart,
        'No-key prediction does not start at reviewed window')
    else
    begin
      Require(APredictions[I].First = APredictions[I - 1].Limit,
        'No-key prediction has a gap or overlap');
      Require(APredictions[I].Key <> APredictions[I - 1].Key,
        'Redundant no-key prediction boundary');
    end;
    Require((APredictions[I].First < APredictions[I].Limit) and
      (APredictions[I].Limit <= ALimit) and
      (APredictions[I].Key >= -1) and (APredictions[I].Key <= 23),
      'No-key prediction segment outside reviewed contract');
    LSpan := APredictions[I].Limit - APredictions[I].First;
    if APredictions[I].Key = -1 then
      Inc(Result.CorrectUnknownFrames, LSpan)
    else
      Inc(Result.FalseKeyFrames, LSpan);
  end;
  Require(APredictions[High(APredictions)].Limit = ALimit,
    'No-key prediction does not end at reviewed window');
  Result.NoKeyFrames := ALimit - AStart;
  Require(Result.CorrectUnknownFrames + Result.FalseKeyFrames =
    Result.NoKeyFrames, 'No-key denominator is not conserved');
end;

procedure Controls;
var
  LReference: TRegions;
  LPredictions: TSegments;
  LScore: TScore;
  LNoKey: TNoKeyScore;
  LRejected: Boolean;
begin
  Require((KeyValue('A#:maj') = KeyValue('Bb:maj')) and
    (KeyValue('D:min') <> KeyValue('D:maj')),
    'Enharmonic equivalence or mode distinction');
  SetLength(LReference, 3);
  LReference[0].First := 0;
  LReference[0].Limit := 22050;
  LReference[0].Kind := rcSupported;
  LReference[0].Key := KeyValue('C:maj');
  LReference[1].First := 22050;
  LReference[1].Limit := 44100;
  LReference[1].Kind := rcSupported;
  LReference[1].Key := KeyValue('D:min');
  LReference[2].First := 44100;
  LReference[2].Limit := 55125;
  LReference[2].Kind := rcConflict;
  LReference[2].Key := -1;
  SetLength(LPredictions, 3);
  LPredictions[0].First := 0;
  LPredictions[0].Limit := 22050;
  LPredictions[0].Key := LReference[0].Key;
  LPredictions[1].First := 22050;
  LPredictions[1].Limit := 44100;
  LPredictions[1].Key := LReference[1].Key;
  LPredictions[2].First := 44100;
  LPredictions[2].Limit := 55125;
  LPredictions[2].Key := -1;
  LScore := Score(LReference, LPredictions, 55125);
  Require((LScore.SupportedFrames = 44100) and
    (LScore.SupportedAdmittedFrames = 44100) and
    (LScore.SupportedCorrectFrames = 44100) and
    (LScore.ConflictFrames = 11025) and
    (LScore.ConflictUnknownFrames = 11025) and
    (LScore.ChangeEvents = 1) and (LScore.CorrectChangeEvents = 1),
    'Exact key, conflict and change scores');
  LPredictions[0].Limit := 16537;
  LPredictions[1].First := 16537;
  LScore := Score(LReference, LPredictions, 55125);
  Require(LScore.CorrectChangeEvents = 1,
    'Change exactly at tolerance must pass');
  LPredictions[0].Limit := 16536;
  LPredictions[1].First := 16536;
  LScore := Score(LReference, LPredictions, 55125);
  Require((LScore.CorrectChangeEvents = 0) and
    (LScore.SupportedCorrectFrames < LScore.SupportedFrames),
    'Mistimed change must fail');
  SetLength(LPredictions, 5);
  LPredictions[0].First := 0;
  LPredictions[0].Limit := 22050;
  LPredictions[0].Key := LReference[0].Key;
  LPredictions[1].First := 22050;
  LPredictions[1].Limit := 30000;
  LPredictions[1].Key := LReference[1].Key;
  LPredictions[2].First := 30000;
  LPredictions[2].Limit := 40000;
  LPredictions[2].Key := LReference[0].Key;
  LPredictions[3].First := 40000;
  LPredictions[3].Limit := 44100;
  LPredictions[3].Key := LReference[1].Key;
  LPredictions[4].First := 44100;
  LPredictions[4].Limit := 55125;
  LPredictions[4].Key := -1;
  LScore := Score(LReference, LPredictions, 55125);
  Require((LScore.ChangeEvents = 1) and (LScore.CorrectChangeEvents = 0),
    'Flickering change must fail');
  SetLength(LPredictions, 1);
  LPredictions[0].First := 0;
  LPredictions[0].Limit := 55125;
  LPredictions[0].Key := -1;
  LScore := Score(LReference, LPredictions, 55125);
  Require((LScore.SupportedCorrectFrames = 0) and
    (LScore.SupportedAdmittedFrames = 0) and
    (LScore.ConflictUnknownFrames = LScore.ConflictFrames) and
    (LScore.CorrectChangeEvents = 0), 'All-unknown behavior');
  SetLength(LReference, 2);
  LReference[0].First := 0;
  LReference[0].Limit := 2 * CSourceRate;
  LReference[0].Kind := rcSupported;
  LReference[0].Key := KeyValue('C:maj');
  LReference[1].First := LReference[0].Limit;
  LReference[1].Limit := 5 * CSourceRate;
  LReference[1].Kind := rcSupported;
  LReference[1].Key := LReference[0].Key;
  SetLength(LPredictions, 3);
  LPredictions[0].First := 0;
  LPredictions[0].Limit := 2 * CSourceRate;
  LPredictions[0].Key := LReference[0].Key;
  LPredictions[1].First := LPredictions[0].Limit;
  LPredictions[1].Limit := 3 * CSourceRate;
  LPredictions[1].Key := KeyValue('D:maj');
  LPredictions[2].First := LPredictions[1].Limit;
  LPredictions[2].Limit := LReference[1].Limit;
  LPredictions[2].Key := LReference[0].Key;
  LScore := Score(LReference, LPredictions, LReference[1].Limit);
  Require((LScore.EligibleStableInteriorFrames = 3 * CSourceRate) and
    (LScore.SpuriousKnownKeyTransitions = 2) and
    (LScore.SupportedAdmittedFrames = LReference[1].Limit),
    'Continuous same-key interior and false-transition control');
  LPredictions[0].Limit := CSourceRate;
  LPredictions[1].First := LPredictions[0].Limit;
  LPredictions[1].Limit := 4 * CSourceRate;
  LPredictions[2].First := LPredictions[1].Limit;
  LScore := Score(LReference, LPredictions, LReference[1].Limit);
  Require((LScore.EligibleStableInteriorFrames = 3 * CSourceRate) and
    (LScore.SpuriousKnownKeyTransitions = 2),
    'Both exact one-second stable-span edges count');
  SetLength(LPredictions, 1);
  LPredictions[0].First := CNoKeyStartFrames[0];
  LPredictions[0].Limit := CNoKeyStartFrames[0] + CNoKeyWindowFrames;
  LPredictions[0].Key := -1;
  LNoKey := ScoreNoKey(LPredictions, CNoKeyStartFrames[0],
    CNoKeyStartFrames[0] + CNoKeyWindowFrames);
  Require((LNoKey.NoKeyFrames = CNoKeyWindowFrames) and
    (LNoKey.CorrectUnknownFrames = CNoKeyWindowFrames) and
    (LNoKey.FalseKeyFrames = 0), 'All-unknown no-key control');
  SetLength(LPredictions, 2);
  LPredictions[0].Limit := CNoKeyStartFrames[0] + CNoKeyWindowFrames div 2;
  LPredictions[1].First := LPredictions[0].Limit;
  LPredictions[1].Limit := CNoKeyStartFrames[0] + CNoKeyWindowFrames;
  LPredictions[1].Key := KeyValue('C:maj');
  LNoKey := ScoreNoKey(LPredictions, CNoKeyStartFrames[0],
    CNoKeyStartFrames[0] + CNoKeyWindowFrames);
  Require((LNoKey.CorrectUnknownFrames = CNoKeyWindowFrames div 2) and
    (LNoKey.FalseKeyFrames = CNoKeyWindowFrames div 2),
    'Half-window false-key denominator');
  LPredictions[1].First := LPredictions[1].First + 1;
  LRejected := False;
  try
    ScoreNoKey(LPredictions, CNoKeyStartFrames[0],
      CNoKeyStartFrames[0] + CNoKeyWindowFrames);
  except
    on E: EAudio do
      LRejected := True;
  end;
  Require(LRejected, 'No-key prediction gap must reject');
  WriteLn('PASS: key, conflict, change and acoustic no-key denominators');
end;

procedure RunScore(const AReferencePath, APredictionPath: String);
var
  LReferenceJSON: TJSONData;
  LPredictionJSON: TJSONData;
  LReferenceHash: String;
  LPredictionHash: String;
  LGroupIndex: Integer;
  LFrames: Int64;
  LPredictionKind: String;
  LReference: TRegions;
  LPredictions: TSegments;
  LScore: TScore;
  LOutput: TJSONObject;
begin
  LReferenceJSON := BoundJSON(AReferencePath, 131072, LReferenceHash);
  try
    LReference := ParseReference(TJSONObject(LReferenceJSON),
      LReferenceHash, LGroupIndex, LFrames);
    LPredictionJSON := BoundJSON(APredictionPath, 1048576, LPredictionHash);
    try
      LPredictions := ParsePredictions(TJSONObject(LPredictionJSON),
        LGroupIndex, LFrames, LPredictionKind);
      LScore := Score(LReference, LPredictions, LFrames);
      LOutput := TJSONObject.Create;
      try
        LOutput.Add('composition_group', CGroups[LGroupIndex]);
        if LGroupIndex < 2 then
          LOutput.Add('role', 'development')
        else
          LOutput.Add('role', 'independent_evaluation');
        LOutput.Add('source_sha256', CWaveHashes[LGroupIndex]);
        LOutput.Add('reference_report_sha256', LReferenceHash);
        LOutput.Add('prediction_sha256', LPredictionHash);
        LOutput.Add('prediction_kind', LPredictionKind);
        LOutput.Add('scoring_policy', 'swd-localkey-score-2');
        LOutput.Add('source_frames', LFrames);
        LOutput.Add('supported_key_frames', LScore.SupportedFrames);
        LOutput.Add('supported_key_admitted_frames',
          LScore.SupportedAdmittedFrames);
        LOutput.Add('supported_key_correct_frames', LScore.SupportedCorrectFrames);
        LOutput.Add('conflict_frames', LScore.ConflictFrames);
        LOutput.Add('conflict_unknown_frames', LScore.ConflictUnknownFrames);
        LOutput.Add('agreed_change_events', LScore.ChangeEvents);
        LOutput.Add('correct_change_events', LScore.CorrectChangeEvents);
        LOutput.Add('eligible_stable_interior_frames',
          LScore.EligibleStableInteriorFrames);
        LOutput.Add('spurious_known_key_transitions',
          LScore.SpuriousKnownKeyTransitions);
        LOutput.Add('supported_key_available', LScore.SupportedFrames > 0);
        LOutput.Add('conflict_available', LScore.ConflictFrames > 0);
        LOutput.Add('agreed_change_available', LScore.ChangeEvents > 0);
        LOutput.Add('excluded_unlabelled_frames',
          LScore.ExcludedUnlabelledFrames);
        LOutput.Add('excluded_partial_frames', LScore.ExcludedPartialFrames);
        LOutput.Add('acoustic_no_key_evaluated', False);
        WriteLn(LOutput.AsJSON);
      finally LOutput.Free; end;
    finally LPredictionJSON.Free; end;
  finally LReferenceJSON.Free; end;
end;

procedure RunNoKeyScore(const AReferencePath, APredictionPath: String);
var
  LReferenceJSON: TJSONData;
  LPredictionJSON: TJSONData;
  LReferenceHash: String;
  LPredictionHash: String;
  LReference: TJSONObject;
  LPrediction: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LSegments: TSegments;
  LScore: TNoKeyScore;
  LOutput: TJSONObject;
  LKind: String;
  LGroupIndex: Integer;
  I: Integer;
begin
  LReferenceJSON := BoundJSON(AReferencePath, 131072, LReferenceHash);
  try
    LGroupIndex := -1;
    for I := 0 to 1 do
    begin
      if LReferenceHash = CNoKeyReferenceHashes[I] then
        LGroupIndex := I;
    end;
    Require(LGroupIndex >= 0, 'Unreviewed no-key reference report');
    LReference := TJSONObject(LReferenceJSON);
    Require((LReference.Get('policy', '') = 'acoustic-nokey-reference-1') and
      (LReference.Get('source_rate', 0) = CNoKeyRate) and
      (LReference.Get('wave_sha256', '') = CNoKeyWaveHashes[LGroupIndex]) and
      (LReference.Get('window_sha256', '') = CNoKeyWindowHashes[LGroupIndex]) and
      (JSONInt64(LReference, 'source_frames') =
        CNoKeySourceFrames[LGroupIndex]) and
      (JSONInt64(LReference, 'start_frame') =
        CNoKeyStartFrames[LGroupIndex]) and
      (JSONInt64(LReference, 'end_frame') =
        CNoKeyStartFrames[LGroupIndex] + CNoKeyWindowFrames) and
      (LReference.Get('label_status', '') = 'reviewed_acoustic_no_key') and
      (LReference.Get('review_method', '') = 'human_full_10_second_window') and
      (LReference.Get('reviewed_label', '') = 'no_key'),
      'No-key reference identity, geometry or review differs');
    if LGroupIndex = 0 then
      Require(LReference.Get('role', '') = 'development',
        'No-key development role differs')
    else
      Require(LReference.Get('role', '') = 'independent_evaluation',
        'No-key evaluation role differs');
    LPredictionJSON := BoundJSON(APredictionPath, 1048576, LPredictionHash);
    try
      LPrediction := TJSONObject(LPredictionJSON);
      LKind := LPrediction.Get('prediction_kind', '');
      Require((LKind = 'control') or (LKind = 'candidate'),
        'No-key prediction kind differs');
      Require((LPrediction.Get('policy', '') = 'acoustic-nokey-prediction-1') and
        (LPrediction.Get('source_sha256', '') =
          CNoKeyWaveHashes[LGroupIndex]) and
        (LPrediction.Get('window_sha256', '') =
          CNoKeyWindowHashes[LGroupIndex]) and
        (LPrediction.Get('source_rate', 0) = CNoKeyRate) and
        (JSONInt64(LPrediction, 'source_frames') =
          CNoKeySourceFrames[LGroupIndex]) and
        (JSONInt64(LPrediction, 'start_frame') =
          CNoKeyStartFrames[LGroupIndex]) and
        (JSONInt64(LPrediction, 'end_frame') =
          CNoKeyStartFrames[LGroupIndex] + CNoKeyWindowFrames),
        'No-key prediction source/window binding differs');
      Require((LPrediction.FindPath('segments') <> nil) and
        (LPrediction.FindPath('segments').JSONType = jtArray),
        'Expected no-key prediction segments');
      LRows := TJSONArray(LPrediction.FindPath('segments'));
      Require((LRows.Count > 0) and (LRows.Count <= CMaximumSegments),
        'No-key prediction segment count outside bound');
      LSegments := nil;
      SetLength(LSegments, LRows.Count);
      for I := 0 to LRows.Count - 1 do
      begin
        Require(LRows.Items[I].JSONType = jtObject,
          'Expected no-key prediction segment object');
        LRow := TJSONObject(LRows.Items[I]);
        LSegments[I].First := JSONInt64(LRow, 'start_frame');
        LSegments[I].Limit := JSONInt64(LRow, 'end_frame');
        LSegments[I].Key := ReadKey(LRow.FindPath('key'));
      end;
      LScore := ScoreNoKey(LSegments, CNoKeyStartFrames[LGroupIndex],
        CNoKeyStartFrames[LGroupIndex] + CNoKeyWindowFrames);
      LOutput := TJSONObject.Create;
      try
        LOutput.Add('reference_report_sha256', LReferenceHash);
        LOutput.Add('prediction_sha256', LPredictionHash);
        LOutput.Add('prediction_kind', LKind);
        LOutput.Add('source_sha256', CNoKeyWaveHashes[LGroupIndex]);
        LOutput.Add('window_sha256', CNoKeyWindowHashes[LGroupIndex]);
        LOutput.Add('role', LReference.Get('role', ''));
        LOutput.Add('scoring_policy', 'acoustic-nokey-score-1');
        LOutput.Add('start_frame', CNoKeyStartFrames[LGroupIndex]);
        LOutput.Add('end_frame', CNoKeyStartFrames[LGroupIndex] +
          CNoKeyWindowFrames);
        LOutput.Add('reviewed_no_key_frames', LScore.NoKeyFrames);
        LOutput.Add('correct_unknown_frames', LScore.CorrectUnknownFrames);
        LOutput.Add('false_key_admission_frames', LScore.FalseKeyFrames);
        LOutput.Add('false_key_admission_rate',
          LScore.FalseKeyFrames / LScore.NoKeyFrames);
        LOutput.Add('acoustic_no_key_evaluated', True);
        WriteLn(LOutput.AsJSON);
      finally
        LOutput.Free;
      end;
    finally
      LPredictionJSON.Free;
    end;
  finally
    LReferenceJSON.Free;
  end;
end;

begin
  try
    if (ParamCount = 1) and (ParamStr(1) = 'controls') then
      Controls
    else if (ParamCount = 3) and (ParamStr(1) = 'score') then
      RunScore(ParamStr(2), ParamStr(3))
    else if (ParamCount = 3) and (ParamStr(1) = 'score-nokey') then
      RunNoKeyScore(ParamStr(2), ParamStr(3))
    else
      raise EAudio.Create(
        'Usage: pythian.localkey.score controls | score <bound-reference.json> ' +
        '<predictions.json> | score-nokey <reviewed-reference.json> ' +
        '<window-predictions.json>');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
