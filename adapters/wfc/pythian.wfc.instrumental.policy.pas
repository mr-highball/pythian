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
unit pythian.wfc.instrumental.policy;

{$mode delphi}
{$H+}

interface

uses pythian.progress, pythian.wfc.layers, pythian.wfc.voices, wfc_model,
  wfc_sequence;

const MaximumInstrumentalControlScopes = 128;

type
  { Half-open musical ticks on the declared uniform provider clock. Extending
    a performance leaves the scope fixed; shortening below EndTick rejects.
    A positive preference never relaxes a hard domain. Origin describes an
    explicit request, not a stochastic audition promoted to training/locks. }
  TInstrumentalControlScope = record
    StartTick: Int64;
    EndTick: Int64;
    TicksPerQuarter: Integer;
    StepTicks: Integer;
    Origin: String;
    HasDomain: Boolean;
    AllowedTokens: TWfcModelTokens;
    Preferences: TLayerTokenPreferences;
  end;
  TInstrumentalControlScopes = array of TInstrumentalControlScope;
  TInstrumentalProviderPolicy = record
    Key: String;
    Constraints: TWfcSequenceTokenConstraints;
    Preferences: TLayerTokenPreferences;
    Scopes: TInstrumentalControlScopes;
  end;
  TInstrumentalProviderPolicies = array of TInstrumentalProviderPolicy;
  TInstrumentalPolicyModels = array of TWfcSequenceModel;

function CopyInstrumentalScopes(const AScopes: TInstrumentalControlScopes): TInstrumentalControlScopes;
function CopyInstrumentalPolicies(const APolicies: TInstrumentalProviderPolicies): TInstrumentalProviderPolicies;
procedure ValidateInstrumentalPolicies(const APolicies: TInstrumentalProviderPolicies;
  const AKeys: TLayerNames; const AModels: TInstrumentalPolicyModels;
  const ATotalCells: Int64; const ATicksPerQuarter, AStepTicks: Integer;
  const AProgress: TWorkProgressCallback = nil);
{ Validate against the actual models/clock before resolving windows. Resolution
  does not repeat complete model validation. Detached local masks include future
  cells. Providers bind by key, never by the stream/editor's differing order. }
function InstrumentalPolicyMasks(const APolicies: TInstrumentalProviderPolicies;
  const AKeys: TLayerNames; const AFirstCell: Int64; const ACellCount: Integer;
  const AProgress: TWorkProgressCallback = nil): TVoiceMasks;
{ Compose saved global/scoped weights and caller/form/drum weights once per
  actual cell. Apply through primary sequence position scopes; no solver here. }
function InstrumentalPolicyRows(const APolicies: TInstrumentalProviderPolicies;
  const AKey: String; const AFirstCell: Int64; const ACellCount: Integer;
  const AGlobal: TLayerTokenPreferences = nil;
  const ARows: TLayerPositionPreferences = nil;
  const AProgress: TWorkProgressCallback = nil): TLayerPositionPreferences;

implementation

uses SysUtils, pythian.audio, pythian.time, wfc_sequence_graph;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

function CopyInstrumentalScopes(const AScopes: TInstrumentalControlScopes): TInstrumentalControlScopes;
var I: Integer;
begin
  Result := Copy(AScopes);
  for I := 0 to High(Result) do
  begin
    Result[I].AllowedTokens := Copy(AScopes[I].AllowedTokens);
    Result[I].Preferences := Copy(AScopes[I].Preferences);
  end;
end;

function CopyInstrumentalPolicies(const APolicies: TInstrumentalProviderPolicies): TInstrumentalProviderPolicies;
var I: Integer;
begin
  Result := Copy(APolicies);
  for I := 0 to High(Result) do
  begin
    Result[I].Constraints := CopyVoiceTokenConstraints(APolicies[I].Constraints);
    Result[I].Preferences := Copy(APolicies[I].Preferences);
    Result[I].Scopes := CopyInstrumentalScopes(APolicies[I].Scopes);
  end;
end;

function PolicyIndex(const APolicies: TInstrumentalProviderPolicies; const AKey: String): Integer;
var I: Integer;
begin
  for I := 0 to High(APolicies) do if APolicies[I].Key = AKey then Exit(I);
  Result := -1;
end;

procedure Visit(var AWork: Int64; const AProgress: TWorkProgressCallback);
begin
  Inc(AWork);
  Need(AWork <= MaximumLayerPreferencePreparationWork, 'Policy window exceeds its preparation work budget');
  if (AWork mod 4096) = 0 then ReportWork(AProgress, 'instrumental_policy_visits', wuItems, AWork, 0);
end;

function Contains(const ATokens: TWfcModelTokens; const AToken: String;
  var AWork: Int64; const AProgress: TWorkProgressCallback): Boolean;
var LToken: String;
begin
  for LToken in ATokens do
  begin
    Visit(AWork, AProgress);
    if LToken = AToken then Exit(True);
  end;
  Result := False;
end;

procedure MergePreferences(var ATarget: TLayerTokenPreferences; const ASource: TLayerTokenPreferences;
  var AWork: Int64; const AProgress: TWorkProgressCallback);
var I, J: Integer; LFound: Boolean;
begin
  for I := 0 to High(ASource) do
  begin
    Visit(AWork, AProgress);
    Need((ASource[I].Multiplier >= 1) and
      (ASource[I].Multiplier <= MaximumLayerPreferenceMultiplier), 'Invalid positive policy multiplier');
    LFound := False;
    for J := 0 to High(ATarget) do
    begin
      Visit(AWork, AProgress);
      if ATarget[J].Token = ASource[I].Token then
      begin
        Need(ATarget[J].Multiplier <= MaximumLayerPreferenceMultiplier div ASource[I].Multiplier,
          'Overlapping policy preferences exceed their combined multiplier budget');
        ATarget[J].Multiplier := ATarget[J].Multiplier * ASource[I].Multiplier;
        LFound := True;
        Break;
      end;
    end;
    if not LFound then
    begin
      Need(Length(ATarget) < MaximumLayerPreferences, 'Policy preferences exceed their token budget');
      SetLength(ATarget, Length(ATarget) + 1);
      ATarget[High(ATarget)] := ASource[I];
    end;
  end;
end;

procedure Intersect(var AMasks: TWfcSequenceTokenConstraints; const APosition: Integer;
  const ATokens: TWfcModelTokens; const AKey: String;
  var AWork: Int64; const AProgress: TWorkProgressCallback);
var I: Integer; LToken: String; LAllowed: TWfcModelTokens;
begin
  Need(Length(ATokens) > 0, 'Empty hard policy domain for ' + AKey);
  for I := 0 to High(AMasks) do
    if AMasks[I].Position = APosition then
    begin
      LAllowed := nil;
      for LToken in AMasks[I].AllowedTokens do
        if Contains(ATokens, LToken, AWork, AProgress) then
        begin
          SetLength(LAllowed, Length(LAllowed) + 1);
          LAllowed[High(LAllowed)] := LToken;
        end;
      Need(Length(LAllowed) > 0, 'Conflicting hard policy domains for ' + AKey);
      AMasks[I].AllowedTokens := LAllowed;
      Exit;
    end;
  SetLength(AMasks, Length(AMasks) + 1);
  AMasks[High(AMasks)].Position := APosition;
  AMasks[High(AMasks)].AllowedTokens := Copy(ATokens);
end;

function InstrumentalPolicyMasks(const APolicies: TInstrumentalProviderPolicies;
  const AKeys: TLayerNames; const AFirstCell: Int64; const ACellCount: Integer;
  const AProgress: TWorkProgressCallback): TVoiceMasks;
var P, I, C, LPolicy: Integer; LCell: Int64; LScope: TInstrumentalControlScope;
  LWork: Int64;
begin
  Result := nil;
  LWork := 0;
  RequireExactTimingCounter(AFirstCell, 'Policy window start');
  Need((AFirstCell >= 0) and (ACellCount > 0) and (ACellCount <= MaximumLayerCells),
    'Policy window must be bounded and nonnegative');
  SetLength(Result, Length(AKeys));
  for P := 0 to High(AKeys) do
  begin
    LPolicy := PolicyIndex(APolicies, AKeys[P]);
    if LPolicy < 0 then Continue;
    for I := 0 to High(APolicies[LPolicy].Constraints) do
    begin
      LCell := APolicies[LPolicy].Constraints[I].Position;
      if (LCell >= AFirstCell) and (LCell < AFirstCell + ACellCount) then
        Intersect(Result[P], LCell - AFirstCell,
          APolicies[LPolicy].Constraints[I].AllowedTokens, AKeys[P], LWork, AProgress);
    end;
    for LScope in APolicies[LPolicy].Scopes do
    begin
      Need(LScope.StepTicks > 0, 'Policy scope requires its actual tick grid');
      if not LScope.HasDomain then Continue;
      for C := 0 to ACellCount - 1 do
      begin
        LCell := AFirstCell + C;
        if (LCell >= LScope.StartTick div LScope.StepTicks) and
          (LCell < LScope.EndTick div LScope.StepTicks) then
          Intersect(Result[P], C, LScope.AllowedTokens, AKeys[P], LWork, AProgress);
      end;
    end;
  end;
end;

function InstrumentalPolicyRows(const APolicies: TInstrumentalProviderPolicies;
  const AKey: String; const AFirstCell: Int64; const ACellCount: Integer;
  const AGlobal: TLayerTokenPreferences; const ARows: TLayerPositionPreferences;
  const AProgress: TWorkProgressCallback): TLayerPositionPreferences;
var C, I, P: Integer; LCell: Int64; LPreferences: TLayerTokenPreferences;
  LScope: TInstrumentalControlScope;
  LWork: Int64;
begin
  Result := nil;
  LWork := 0;
  RequireExactTimingCounter(AFirstCell, 'Policy preference start');
  Need((AFirstCell >= 0) and (ACellCount > 0) and (ACellCount <= MaximumLayerCells),
    'Policy preference window must be bounded and nonnegative');
  for I := 0 to High(ARows) do
    Need((ARows[I].Position >= 0) and (ARows[I].Position < ACellCount),
      'Additional preference lies outside its policy window');
  P := PolicyIndex(APolicies, AKey);
  for C := 0 to ACellCount - 1 do
  begin
    LPreferences := Copy(AGlobal);
    LCell := AFirstCell + C;
    if P >= 0 then
    begin
      MergePreferences(LPreferences, APolicies[P].Preferences, LWork, AProgress);
      for LScope in APolicies[P].Scopes do
      begin
        Need(LScope.StepTicks > 0, 'Policy scope requires its actual tick grid');
        if (LCell >= LScope.StartTick div LScope.StepTicks) and
          (LCell < LScope.EndTick div LScope.StepTicks) then
          MergePreferences(LPreferences, LScope.Preferences, LWork, AProgress);
      end;
    end;
    for I := 0 to High(ARows) do
      if ARows[I].Position = C then MergePreferences(LPreferences, ARows[I].Preferences, LWork, AProgress);
    if Length(LPreferences) = 0 then Continue;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := MakeLayerPositionPreference(C, LPreferences);
  end;
end;

procedure ValidateInstrumentalPolicies(const APolicies: TInstrumentalProviderPolicies;
  const AKeys: TLayerNames; const AModels: TInstrumentalPolicyModels;
  const ATotalCells: Int64; const ATicksPerQuarter, AStepTicks: Integer;
  const AProgress: TWorkProgressCallback);
var P, I, LCount: Integer; J: Int64; LFound: Boolean; LScope: TInstrumentalControlScope;
  LRows: TLayerPositionPreferences; LMasks: TWfcSequenceTokenConstraints;
  LWindow: TVoiceMasks; LModel: TWfcSequenceModel;
  procedure CheckPoint(const ACell: Int64);
  begin
    LWindow := InstrumentalPolicyMasks(APolicies, [APolicies[P].Key], ACell, 1, AProgress);
    LRows := InstrumentalPolicyRows(APolicies, APolicies[P].Key, ACell, 1, nil, nil, AProgress);
    LRows := ValidateSequencePositionPreferences(LModel, 1, LRows, AProgress);
  end;
begin
  Need((Length(AKeys) = Length(AModels)) and (Length(AKeys) <= 16) and (Length(APolicies) <= 16) and
    (ATicksPerQuarter > 0) and (AStepTicks > 0) and (ATotalCells > 0),
    'Policy requires actual providers and musical clock');
  RequireExactTimingCounter(ATotalCells, 'Policy musical extent');
  LCount := 0;
  for P := 0 to High(AKeys) do
    for I := 0 to P - 1 do Need(AKeys[P] <> AKeys[I], 'Ambiguous actual policy provider identity');
  for P := 0 to High(APolicies) do
  begin
    ReportWork(AProgress, 'instrumental_policy_validate', wuItems, P, Length(APolicies));
    Need((Trim(APolicies[P].Key) <> '') and (Length(APolicies[P].Key) <= 255),
      'Policy requires a bounded provider identity');
    for I := 0 to P - 1 do Need(APolicies[I].Key <> APolicies[P].Key, 'Duplicate policy provider');
    LFound := False; LModel := nil;
    for I := 0 to High(AKeys) do if AKeys[I] = APolicies[P].Key then
    begin LFound := True; LModel := AModels[I]; Break end;
    Need(LFound and (LModel <> nil), 'Policy references unknown provider ' + APolicies[P].Key);
    ValidateSequenceTokenConstraints(LModel, ATotalCells, APolicies[P].Constraints);
    LRows := ValidateSequencePositionPreferences(LModel, 1,
      [MakeLayerPositionPreference(0, APolicies[P].Preferences)], AProgress);
    Inc(LCount, Length(APolicies[P].Scopes));
    Need(LCount <= MaximumInstrumentalControlScopes, 'Policy exceeds 128 scope budget');
    for I := 0 to High(APolicies[P].Scopes) do
    begin
      LScope := APolicies[P].Scopes[I];
      RequireExactTimingCounter(LScope.StartTick, 'Policy scope start');
      RequireExactTimingCounter(LScope.EndTick, 'Policy scope end');
      Need((LScope.TicksPerQuarter = ATicksPerQuarter) and (LScope.StepTicks = AStepTicks) and
        (LScope.StartTick >= 0) and (LScope.EndTick > LScope.StartTick) and
        (LScope.StartTick mod AStepTicks = 0) and (LScope.EndTick mod AStepTicks = 0),
        'Policy scope differs from its musical clock or has invalid tick bounds');
      Need(LScope.EndTick div AStepTicks <= ATotalCells,
        'Choose a longer track: saved passage controls extend beyond this length');
      Need((Trim(LScope.Origin) <> '') and (Length(LScope.Origin) <= 4096),
        'Policy scope requires actual request origin');
      Need(LScope.HasDomain or (Length(LScope.AllowedTokens) = 0), 'Undeclared policy domain');
      Need(LScope.HasDomain or (Length(LScope.Preferences) > 0), 'Empty policy scope');
      Need(Length(LScope.AllowedTokens) <= MaximumLayerPositionValues, 'Scoped domain exceeds its token budget');
      if LScope.HasDomain then
      begin
        SetLength(LMasks, 1); LMasks[0].Position := 0; LMasks[0].AllowedTokens := LScope.AllowedTokens;
        ValidateSequenceTokenConstraints(LModel, 1, LMasks);
      end;
      LRows := ValidateSequencePositionPreferences(LModel, 1,
        [MakeLayerPositionPreference(0, LScope.Preferences)], AProgress);
    end;
    { Domain/preference combinations change only at scope starts/ends or a
      sparse lock. Check those points, never unroll a duration-sized score. }
    for I := 0 to High(APolicies[P].Constraints) do CheckPoint(APolicies[P].Constraints[I].Position);
    for I := 0 to High(APolicies[P].Scopes) do
    begin
      CheckPoint(APolicies[P].Scopes[I].StartTick div AStepTicks);
      J := APolicies[P].Scopes[I].EndTick div AStepTicks;
      if J < ATotalCells then CheckPoint(J);
    end;
  end;
  ReportWork(AProgress, 'instrumental_policy_ready', wuItems, Length(APolicies), Length(APolicies));
end;

end.
