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
unit pythian.wfc.percussion;

{$mode delphi}
{$H+}

interface

uses
  pythian.time,
  pythian.progress,
  pythian.synth,
  pythian.percussion,
  pythian.wfc.layers,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph;

type
  TPercussionDefinition = record
    Name: String;
    Origin: String;
    Model: TWfcSequenceModel;
    Settings: TPercussionSettings;
    OutputBus: Integer;
    Enabled: Boolean;
    HitWeight: Integer;
    { Empty means every rhythm token. Nonempty is an explicit caller mapping. }
    AllowedHitRhythms: TWfcModelTokens;
    Constraints: TWfcSequenceTokenConstraints;
  end;
  TPercussionDefinitions = array of TPercussionDefinition;
  TPercussionPart = record
    Name: String;
    Origin: String;
    Settings: TPercussionSettings;
    OutputBus: Integer;
    Enabled: Boolean;
    HitWeight: Integer;
  end;
  TPercussionHit = record
    Part: Integer;
    Cell: Integer;
    Velocity: Integer;
    StartTick: Integer;
    StartFrame: Int64;
    GateFrames: Int64;
  end;
  TPercussionHits = array of TPercussionHit;
  TPercussionPlan = class
  private
    FSession: TLearnedLayerSession;
    FParts: array of TPercussionPart;
    FInstruments: array of TPercussionInstrument;
    FTones: array of TFrameTones;
    FSequences: TLayerSequences;
    FHits: TPercussionHits;
    constructor Create;
    procedure CheckPart(const AIndex: Integer);
  public
    destructor Destroy; override;
    function PartCount: Integer;
    function PartAt(const AIndex: Integer): TPercussionPart;
    function CopyGraph: TLayerGraphPasses;
    function CopyModel(const AName: String): TWfcSequenceModel;
    function CopySequences: TLayerSequences;
    function CopyHits: TPercussionHits;
    function CopyPartTones(const AIndex: Integer): TFrameTones;
  end;

function PercussionToken(const AVelocity: Integer): String;
function PercussionVelocity(const AToken: String): Integer;
function AllowedPercussionRhythms(const ARhythmModel: TWfcSequenceModel;
  const ADefinition: TPercussionDefinition; const AToken: String): TWfcModelTokens;
{ Big Boss: one actual dependent graph with an exactly pinned rhythm-input pass
  and one unpitched pass per drum. It does not alter/re-solve pitched providers.
  Generic WFC layers own learning/projections/solve. This adapter owns event and
  sound semantics. False/exception preserves APlan; success replaces/frees it.
  Source models are borrowed during this call; accepted clones are owned.
  Accepted plans own their drum instruments/curves through player construction. }
function TryCreatePercussionPlan(const ARhythmModel: TWfcSequenceModel;
  const ARhythm: TWfcModelTokens; const ADefinitions: TPercussionDefinitions;
  const ATicksPerQuarter, AStepTicks, ASampleRate: Integer;
  const ATempos: TTempoChanges; const ASeed: TGraphSeed;
  var APlan: TPercussionPlan; out AReport: TGraphNegotiationReport;
  const AProgress: TWorkProgressCallback = nil): Boolean;

implementation

uses
  SysUtils,
  pythian.audio;

function PercussionToken(const AVelocity: Integer): String;
begin
  if (AVelocity < 0) or (AVelocity > 127) then
  begin
    raise EAudio.Create('Percussion velocity requires 0..127');
  end;
  if AVelocity = 0 then
  begin
    Exit('rest');
  end;
  Result := 'hit:' + IntToStr(AVelocity);
end;

function PercussionVelocity(const AToken: String): Integer;
begin
  if AToken = 'rest' then
  begin
    Exit(0);
  end;
  if (Copy(AToken, 1, 4) <> 'hit:') or
    not TryStrToInt(Copy(AToken, 5, Length(AToken)), Result) then
  begin
    raise EAudio.Create('Unsupported percussion token; expected rest or hit:1..127');
  end;
  if (Result < 1) or (Result > 127) or (AToken <> PercussionToken(Result)) then
  begin
    raise EAudio.Create('Percussion hit token is not canonical');
  end;
end;

function AllowedPercussionRhythms(const ARhythmModel: TWfcSequenceModel;
  const ADefinition: TPercussionDefinition; const AToken: String): TWfcModelTokens;
var
  I: Integer;
begin
  Result := nil;
  if ARhythmModel = nil then raise EAudio.Create('Percussion needs a rhythm model');
  if (PercussionVelocity(AToken) = 0) or (Length(ADefinition.AllowedHitRhythms) = 0) then
  begin
    SetLength(Result, ARhythmModel.PublicTokenCount);
    for I := 0 to High(Result) do Result[I] := ARhythmModel.PublicTokenAt(I);
  end
  else Result := Copy(ADefinition.AllowedHitRhythms);
end;

constructor TPercussionPlan.Create;
begin
  inherited Create;
end;

destructor TPercussionPlan.Destroy;
var
  LInstrument: TPercussionInstrument;
begin
  FSession.Free;
  for LInstrument in FInstruments do
  begin
    LInstrument.Free;
  end;
  inherited Destroy;
end;

procedure TPercussionPlan.CheckPart(const AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= Length(FParts)) then
  begin
    raise EAudio.Create('Percussion part index out of range');
  end;
end;

function TPercussionPlan.PartCount: Integer;
begin
  Result := Length(FParts);
end;

function TPercussionPlan.PartAt(const AIndex: Integer): TPercussionPart;
begin
  CheckPart(AIndex);
  Result := FParts[AIndex];
end;

function TPercussionPlan.CopyGraph: TLayerGraphPasses;
begin
  Result := FSession.CopyGraph;
end;

function TPercussionPlan.CopyModel(const AName: String): TWfcSequenceModel;
begin
  Result := FSession.CopyModel(AName);
end;

function TPercussionPlan.CopySequences: TLayerSequences;
begin
  Result := FSession.CopyAccepted;
end;

function TPercussionPlan.CopyHits: TPercussionHits;
begin
  Result := Copy(FHits);
end;

function TPercussionPlan.CopyPartTones(const AIndex: Integer): TFrameTones;
begin
  CheckPart(AIndex);
  Result := Copy(FTones[AIndex]);
end;

function TryCreatePercussionPlan(const ARhythmModel: TWfcSequenceModel;
  const ARhythm: TWfcModelTokens; const ADefinitions: TPercussionDefinitions;
  const ATicksPerQuarter, AStepTicks, ASampleRate: Integer;
  const ATempos: TTempoChanges; const ASeed: TGraphSeed;
  var APlan: TPercussionPlan; out AReport: TGraphNegotiationReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LCandidate: TPercussionPlan;
  LPrevious: TPercussionPlan;
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LNames: TLayerNames;
  LOptions: TLayerGenerationOptions;
  LPart: Integer;
  LOther: Integer;
  LCell: Integer;
  LToken: Integer;
  LVelocity: Integer;
  LAllowed: TWfcModelTokens;
  LHit: TPercussionHit;
  LTones: TFrameTones;
  LCount: Integer;
  LClock: TTempoMap;
  LMask: TWfcSequenceTokenConstraint;
  LAlternative: String;
  LRestAllowed: Boolean;
  LHasRest: Boolean;
begin
  Result := False;
  AReport := Default(TGraphNegotiationReport);
  if (ARhythmModel = nil) or (Length(ARhythm) < 1) or
    (Length(ARhythm) > MaximumLayerCells) or
    (Length(ADefinitions) < 1) or (Length(ADefinitions) > 6) or
    (AStepTicks < 1) or (Int64(Length(ARhythm)) * AStepTicks > High(Integer)) then
  begin
    raise EAudio.Create('Percussion requires a bounded rhythm, 1..6 parts and an explicit clock');
  end;
  LClock := TTempoMap.Create(ATicksPerQuarter, Length(ARhythm) * AStepTicks, ATempos);
  LCandidate := nil;
  try
    SetLength(LLayers, Length(ADefinitions) + 1);
    SetLength(LNames, Length(LLayers));
    SetLength(LMaps, Length(ADefinitions));
    LLayers[0].Model := ARhythmModel;
    LNames[0] := 'percussion.rhythm';
    SetLength(LLayers[0].Constraints, Length(ARhythm));
    for LCell := 0 to High(ARhythm) do
    begin
      LLayers[0].Constraints[LCell] := MakeWfcSequenceTokenConstraint(LCell, [ARhythm[LCell]]);
    end;
    for LPart := 0 to High(ADefinitions) do
    begin
      if (ADefinitions[LPart].Model = nil) or
        (Trim(ADefinitions[LPart].Origin) = '') or
        (ADefinitions[LPart].OutputBus < 0) or
        (ADefinitions[LPart].HitWeight < 1) or
        (ADefinitions[LPart].HitWeight > MaximumLayerPreferenceMultiplier) then
      begin
        raise EAudio.Create('Percussion part requires model, origin, bus and hit weight 1..1024');
      end;
      LNames[LPart + 1] := ADefinitions[LPart].Name;
      LLayers[LPart + 1].Model := ADefinitions[LPart].Model;
      LLayers[LPart + 1].Constraints := ADefinitions[LPart].Constraints;
      if not ADefinitions[LPart].Enabled then
      begin
        ValidateSequenceTokenConstraints(ADefinitions[LPart].Model,
          Length(ARhythm), ADefinitions[LPart].Constraints);
        for LMask in ADefinitions[LPart].Constraints do
        begin
          LRestAllowed := False;
          for LAlternative in LMask.AllowedTokens do
          begin
            LRestAllowed := LRestAllowed or (LAlternative = 'rest');
          end;
          if not LRestAllowed then
          begin
            raise EAudio.Create('Disabled percussion conflicts with a hit lock: ' +
              ADefinitions[LPart].Name);
          end;
        end;
        LLayers[LPart + 1].Constraints := nil;
        SetLength(LLayers[LPart + 1].Constraints, Length(ARhythm));
        for LCell := 0 to High(ARhythm) do
        begin
          LLayers[LPart + 1].Constraints[LCell] :=
            MakeWfcSequenceTokenConstraint(LCell, ['rest']);
        end;
      end;
      LMaps[LPart].Consumer := LPart + 1;
      LMaps[LPart].Provider := 0;
      SetLength(LMaps[LPart].Rules, ADefinitions[LPart].Model.PublicTokenCount);
      SetLength(LLayers[LPart + 1].Preferences, ADefinitions[LPart].Model.PublicTokenCount);
      LHasRest := False;
      for LToken := 0 to ADefinitions[LPart].Model.PublicTokenCount - 1 do
      begin
        LVelocity := PercussionVelocity(ADefinitions[LPart].Model.PublicTokenAt(LToken));
        LHasRest := LHasRest or (LVelocity = 0);
        LAllowed := AllowedPercussionRhythms(ARhythmModel, ADefinitions[LPart],
          ADefinitions[LPart].Model.PublicTokenAt(LToken));
        LMaps[LPart].Rules[LToken] := MakeWfcSequenceProjectionRule(
          ADefinitions[LPart].Model.PublicTokenAt(LToken), LAllowed);
        LCount := 1;
        if LVelocity > 0 then
        begin
          LCount := ADefinitions[LPart].HitWeight;
        end;
        LLayers[LPart + 1].Preferences[LToken] :=
          MakeLayerTokenPreference(ADefinitions[LPart].Model.PublicTokenAt(LToken), LCount);
      end;
      if not ADefinitions[LPart].Enabled and not LHasRest then
      begin
        raise EAudio.Create('Disabled percussion needs a learned rest token: ' + ADefinitions[LPart].Name);
      end;
    end;
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := Length(ARhythm);
    LOptions.Extent := wsePrefix;
    LOptions.Seed := ASeed;
    LCandidate := TPercussionPlan.Create;
    LCandidate.FSession := TLearnedLayerSession.Create(LLayers, LMaps, LNames,
      LOptions, AProgress);
    if not LCandidate.FSession.TryGenerate(LCandidate.FSequences, AReport, AProgress) then
    begin
      Exit;
    end;
    SetLength(LCandidate.FParts, Length(ADefinitions));
    SetLength(LCandidate.FTones, Length(ADefinitions));
    SetLength(LCandidate.FInstruments, Length(ADefinitions));
    for LPart := 0 to High(ADefinitions) do
    begin
      LCandidate.FParts[LPart].Name := ADefinitions[LPart].Name;
      LCandidate.FParts[LPart].Origin := ADefinitions[LPart].Origin;
      LCandidate.FParts[LPart].Settings := ADefinitions[LPart].Settings;
      LCandidate.FParts[LPart].OutputBus := ADefinitions[LPart].OutputBus;
      LCandidate.FParts[LPart].Enabled := ADefinitions[LPart].Enabled;
      LCandidate.FParts[LPart].HitWeight := ADefinitions[LPart].HitWeight;
      LCandidate.FInstruments[LPart] := TPercussionInstrument.Create(ASampleRate,
        ADefinitions[LPart].Settings);
      for LCell := 0 to High(ARhythm) do
      begin
        LVelocity := PercussionVelocity(LCandidate.FSequences[LPart + 1].Tokens[LCell]);
        if LVelocity = 0 then
        begin
          Continue;
        end;
        LHit.Part := LPart;
        LHit.Cell := LCell;
        LHit.Velocity := LVelocity;
        LHit.StartTick := LCell * AStepTicks;
        LHit.StartFrame := LClock.FrameAtTick(LHit.StartTick, ASampleRate);
        LTones := LCandidate.FInstruments[LPart].PlanHit(LHit.StartFrame,
          LVelocity, Cardinal((LPart + 1) * 65536 + LCell + 1));
        LHit.GateFrames := LTones[0].GateFrames;
        LCount := Length(LCandidate.FTones[LPart]);
        if Length(LTones) > MaximumToneEvents - LCount then
        begin
          raise EAudio.Create('Percussion part exceeds native tone capacity');
        end;
        SetLength(LCandidate.FTones[LPart], LCount + Length(LTones));
        for LOther := 0 to High(LTones) do
        begin
          LCandidate.FTones[LPart][LCount + LOther] := LTones[LOther];
        end;
        LCount := Length(LCandidate.FHits);
        SetLength(LCandidate.FHits, LCount + 1);
        LCandidate.FHits[LCount] := LHit;
      end;
      ReportWork(AProgress, 'percussion_instruments', wuItems, LPart + 1, Length(ADefinitions));
    end;
    ReportWork(AProgress, 'percussion_ready', wuItems, 1, 1);
    LPrevious := APlan;
    APlan := LCandidate;
    LCandidate := nil;
    LPrevious.Free;
    Result := True;
  finally
    LCandidate.Free;
    LClock.Free;
  end;
end;

end.
