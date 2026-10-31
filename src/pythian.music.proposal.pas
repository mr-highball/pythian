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

unit pythian.music.proposal;

{$mode delphi}
{$H+}

interface

uses pythian.audio, pythian.chord, pythian.music.pattern,
  pythian.music.observations, pythian.music.sound, pythian.progress;

const
  MusicalProposalVersion = 1;
  MusicalProposalPolicy = 'periodic-spectral-arrangement-bands-v1';

type
  TMusicalProposalPitchOrigin = (mppUnknown, mppSilence, mppPeriodic, mppSpectral);
  TMusicalProposalPitchOrigins = array of TMusicalProposalPitchOrigin;
  TMusicalProposalFlags = array of Boolean;
  TMusicalProposalFrames = array of TChordFrame;
  TMusicalProposalDrumCell = array[0..2] of Integer;
  TMusicalProposalDrums = array of TMusicalProposalDrumCell;
  TMusicalProposalNames = array of String;
  TProposedMusicalGrid = record
    Version: Integer;
    Policy: String;
    SampleRate: Integer;
    SourceFrames: Integer;
    TempoMicroseconds: Integer;
    RoleNames: TMusicalProposalNames;
    RoleOrigins: TMusicalProposalNames;
    Frames: TMusicalProposalFrames;
    Known: TMusicalProposalFlags;
    PitchOrigins: TMusicalProposalPitchOrigins;
    Drums: TMusicalProposalDrums;
    HasSound: Boolean;
    Sound: TMusicalSound;
  end;

{ Experimental arrangement, not stem separation or admitted musical truth.
  Reuses the primary pitch-span quantizer. Complete eighth-note cells use
  duration-weighted chroma to propose bass/harmony; stable periodic pitch drives
  lead where available, otherwise a marked spectral pitch-class proposal does.
  Unusable nonsilent cells remain unknown, never measured rests. Quantized
  low/mid/high positive flux proposes drum actions, not instrument identity.
  The explicit clock is supplied by the caller, not inferred by this function. }
function ProposeMusicalGrid(const AObservations: TMusicalObservations;
  const ASampleRate, ASourceFrames, ATempoMicroseconds: Integer;
  const AChannel: Integer = 0;
  const AProgress: TWorkProgressCallback = nil): TProposedMusicalGrid;
procedure ValidateProposedMusicalGrid(const AGrid: TProposedMusicalGrid;
  const AProgress: TWorkProgressCallback = nil);
function CopyProposedMusicalGrid(const AGrid: TProposedMusicalGrid): TProposedMusicalGrid;

implementation

uses SysUtils, Math, pythian.time, pythian.pitch.track, pythian.analysis,
  pythian.tonal;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function SameTones(const ALeft, ARight: TChordTones): Boolean;
var
  I: Integer;
begin
  Result := Length(ALeft) = Length(ARight);
  if not Result then
  begin
    Exit;
  end;
  for I := 0 to High(ALeft) do
  begin
    if (ALeft[I].Pitch <> ARight[I].Pitch) or
      (ALeft[I].Velocity <> ARight[I].Velocity) then
    begin
      Exit(False);
    end;
  end;
end;

procedure ValidateProposedMusicalGrid(const AGrid: TProposedMusicalGrid;
  const AProgress: TWorkProgressCallback);
var
  I: Integer;
  J: Integer;
  K: Integer;
  LVoice: TChordVoice;
  LClock: TTempoMap;
begin
  Need((AGrid.Version = MusicalProposalVersion) and (AGrid.Policy <> ''),
    'Musical proposal version/policy is missing');
  ValidateAudioFormat(AGrid.SampleRate, 1);
  Need((AGrid.SourceFrames > 0) and
    (AGrid.SourceFrames <= MaximumMusicalObservationFrames) and
    (AGrid.SourceFrames <= Int64(AGrid.SampleRate) * MusicalObservationSeconds) and
    (AGrid.SourceFrames = Trunc(AGrid.SourceFrames)) and
    (AGrid.TempoMicroseconds >= 250000) and (AGrid.TempoMicroseconds <= 1500000) and
    (AGrid.TempoMicroseconds = Trunc(AGrid.TempoMicroseconds)),
    'Musical proposal requires bounded source extent and an explicit 40..240 BPM clock');
  Need((Length(AGrid.RoleNames) in [1..6]) and
    (Length(AGrid.RoleOrigins) = Length(AGrid.RoleNames)), 'Proposal requires named roles and actual origins');
  for I := 0 to High(AGrid.RoleNames) do
  begin
    Need((AGrid.RoleNames[I] <> '') and (AGrid.RoleOrigins[I] <> ''), 'Proposal role identity/origin is missing');
    for J := 0 to I - 1 do
    begin
      Need(AGrid.RoleNames[I] <> AGrid.RoleNames[J], 'Proposal role names repeat');
    end;
  end;
  Need((Length(AGrid.Frames) >= 1) and (Length(AGrid.Frames) <= MaximumPitchPatternCells) and
    (Length(AGrid.Known) = Length(AGrid.Frames)) and
    (Length(AGrid.PitchOrigins) = Length(AGrid.Frames)) and
    (Length(AGrid.Drums) = Length(AGrid.Frames)), 'Proposal vectors have incompatible cell counts');
  LClock := TTempoMap.Create(PitchPatternPpq, Length(AGrid.Frames) * PitchPatternStepTicks,
    [MakeTempoChange(0, AGrid.TempoMicroseconds)]);
  try
    Need(LClock.FrameAtTick(LClock.LengthTicks, AGrid.SampleRate, frCeiling) <= AGrid.SourceFrames,
      'Proposal cells exceed their measured source window');
  finally
    LClock.Free;
  end;
  for I := 0 to High(AGrid.Frames) do
  begin
    ReportWork(AProgress, 'musical_proposal_validate', wuItems, I, Length(AGrid.Frames));
    Need(AGrid.PitchOrigins[I] in [mppUnknown, mppSilence, mppPeriodic, mppSpectral], 'Invalid pitch proposal origin');
    for J := 0 to 2 do
    begin
      Need((AGrid.Drums[I][J] >= 0) and (AGrid.Drums[I][J] <= 127) and
        (AGrid.Drums[I][J] = Trunc(AGrid.Drums[I][J])), 'Invalid proposed drum velocity');
    end;
    if not AGrid.Known[I] then
    begin
      Need((Length(AGrid.Frames[I]) = 0) and (AGrid.PitchOrigins[I] = mppUnknown),
        'Unknown musical cells must omit pitched proposals');
      Continue;
    end;
    Need(Length(AGrid.Frames[I]) = Length(AGrid.RoleNames), 'Proposal frame role count differs');
    for J := 0 to High(AGrid.Frames[I]) do
    begin
      LVoice := AGrid.Frames[I][J];
      Need(LVoice.Action in [caRest, caAttack, caHold], 'Invalid proposed voice action');
      Need(((LVoice.Action = caRest) and (Length(LVoice.Tones) = 0)) or
        ((LVoice.Action <> caRest) and (Length(LVoice.Tones) in [1..12])), 'Proposal voice tones disagree with action');
      for K := 0 to High(LVoice.Tones) do
      begin
        Need((LVoice.Tones[K].Pitch >= 0) and (LVoice.Tones[K].Pitch <= 127) and
          (LVoice.Tones[K].Velocity in [1..127]) and
          (LVoice.Tones[K].Pitch = Trunc(LVoice.Tones[K].Pitch)) and
          (LVoice.Tones[K].Velocity = Trunc(LVoice.Tones[K].Velocity)), 'Proposed tone is outside MIDI bounds');
        if K > 0 then
        begin
          Need(LVoice.Tones[K].Pitch > LVoice.Tones[K - 1].Pitch,
            'Proposed tones must be unique and sorted');
        end;
      end;
      if LVoice.Action = caHold then
      begin
        Need((I > 0) and AGrid.Known[I - 1], 'A proposal hold cannot cross an unknown boundary');
        Need(SameTones(LVoice.Tones, AGrid.Frames[I - 1][J].Tones), 'Proposed hold changes active tones');
      end;
    end;
  end;
  if AGrid.HasSound then
  begin
    ValidateMusicalSound(AGrid.Sound);
  end;
  ReportWork(AProgress, 'musical_proposal_validate', wuItems, Length(AGrid.Frames), Length(AGrid.Frames));
end;

function CopyProposedMusicalGrid(const AGrid: TProposedMusicalGrid): TProposedMusicalGrid;
var
  I: Integer;
  J: Integer;
begin
  Result := AGrid;
  Result.RoleNames := Copy(AGrid.RoleNames);
  Result.RoleOrigins := Copy(AGrid.RoleOrigins);
  Result.Known := Copy(AGrid.Known);
  Result.PitchOrigins := Copy(AGrid.PitchOrigins);
  Result.Drums := Copy(AGrid.Drums);
  Result.Frames := nil;
  SetLength(Result.Frames, Length(AGrid.Frames));
  for I := 0 to High(AGrid.Frames) do
  begin
    Result.Frames[I] := Copy(AGrid.Frames[I]);
    for J := 0 to High(AGrid.Frames[I]) do
    begin
      Result.Frames[I][J].Tones := Copy(AGrid.Frames[I][J].Tones);
    end;
  end;
end;

function ProposeMusicalGrid(const AObservations: TMusicalObservations;
  const ASampleRate, ASourceFrames, ATempoMicroseconds, AChannel: Integer;
  const AProgress: TWorkProgressCallback): TProposedMusicalGrid;
var
  LResult: TProposedMusicalGrid;
  LClock: TTempoMap;
  LPattern: TPitchPattern;
  LFrame: TChordFrame;
  LClasses: TPitchClassWeights;
  LBandMax, LBandCell: array[0..2] of Double;
  LFeature: TAudioFeature;
  LFirst: Integer;
  LLast: Integer;
  LCell: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
  LCount: Integer;
  LChosen: Integer;
  LBest: Integer;
  LStart: Integer;
  LEnd: Integer;
  LOwnedStart: Integer;
  LOwnedEnd: Integer;
  LOverlap: Integer;
  LWeight: Double;
  LPower: Double;
  LMaximumRms: Double;
  LRms: Double;
  LFlux: Double;
  LTotal: Double;
  LMaximum: Double;
  LVelocity: Integer;
  LLead: Integer;
  LBass: Integer;
  LSelected: array[0..11] of Boolean;
  LOnset: Boolean;
  LPeriodic: Boolean;
  procedure Voice(const AIndex: Integer; const APitches: array of Integer);
  var
    P: Integer;
  begin
    LFrame[AIndex].Action := caAttack;
    SetLength(LFrame[AIndex].Tones, Length(APitches));
    for P := 0 to High(APitches) do
    begin
      LFrame[AIndex].Tones[P].Pitch := APitches[P];
      LFrame[AIndex].Tones[P].Velocity := LVelocity;
    end;
    if (LCell > 0) and LResult.Known[LCell - 1] and not LOnset and
      SameTones(LFrame[AIndex].Tones, LResult.Frames[LCell - 1][AIndex].Tones) then
    begin
      LFrame[AIndex].Action := caHold;
    end;
  end;
begin
  Need((ASampleRate >= 8000) and (ASampleRate <= 192000) and
    (ASampleRate = Trunc(ASampleRate)) and (ASourceFrames = Trunc(ASourceFrames)) and
    (ASourceFrames > 0) and (ASourceFrames <= MaximumMusicalObservationFrames) and
    (ASourceFrames <= Int64(ASampleRate) * MusicalObservationSeconds), 'Proposal requires bounded measured audio');
  Need((ATempoMicroseconds >= 250000) and (ATempoMicroseconds <= 1500000) and
    (ATempoMicroseconds = Trunc(ATempoMicroseconds)), 'Proposal clock must be 40..240 BPM');
  Need((AChannel >= 0) and (AChannel < Length(AObservations.ChannelPitches)) and
    (AChannel = Trunc(AChannel)), 'Choose a measured pitch channel');
  { Validate feature geometry through the primary duration-weighting contract. }
  FeaturePitchClassWeights(AObservations.Features,
    AObservations.AnalysisOptions, ASourceFrames, True);
  Need(Length(AObservations.Bands) = 3, 'Proposal requires the shared low/mid/high band measurements');
  LMaximumRms := 0;
  for I := 0 to High(AObservations.Features) do
  begin
    LMaximumRms := Max(LMaximumRms, AObservations.Features[I].Rms);
  end;
  for J := 0 to 2 do
  begin
    LBandMax[J] := 0;
    Need(Length(AObservations.Bands[J].PositiveFlux) = Length(AObservations.Features), 'Band measurements differ from feature count');
    for I := 0 to High(AObservations.Features) do
    begin
      RequireFinite(AObservations.Bands[J].PositiveFlux[I], 'Band flux');
      Need(AObservations.Bands[J].PositiveFlux[I] >= 0, 'Band flux must be nonnegative');
      LBandMax[J] := Max(LBandMax[J], AObservations.Bands[J].PositiveFlux[I]);
    end;
  end;
  Need((AObservations.Bands[0].LowerHz = 0) and (AObservations.Bands[0].UpperHz = 200) and
    (AObservations.Bands[1].LowerHz = 200) and (AObservations.Bands[1].UpperHz = 2000) and
    (AObservations.Bands[2].LowerHz = 2000) and (AObservations.Bands[2].UpperHz = ASampleRate / 2),
    'Musical proposal band meanings differ from the measurement policy');
  LResult := Default(TProposedMusicalGrid);
  LResult.Version := MusicalProposalVersion;
  LResult.Policy := MusicalProposalPolicy;
  LResult.SampleRate := ASampleRate;
  LResult.SourceFrames := ASourceFrames;
  LResult.TempoMicroseconds := ATempoMicroseconds;
  LResult.RoleNames := ['bass', 'harmony-voice', 'lead'];
  LResult.RoleOrigins := ['Arranged bass from spectral pitch class',
    'Spectral harmony candidates', 'Periodic pitch or marked spectral lead candidate'];
  LPattern := nil;
  if (AObservations.PitchFrames > 0) and
    (Int64(AObservations.PitchFrames) * 2000000 >= Int64(MusicalPitchRate) * ATempoMicroseconds) then
  begin
    LPattern := QuantizePitchPattern(AObservations.ChannelPitches[AChannel], MusicalPitchRate,
      AObservations.PitchFrames, ATempoMicroseconds);
  end;
  LClock := TTempoMap.Create(PitchPatternPpq, MaximumPitchPatternCells * PitchPatternStepTicks,
    [MakeTempoChange(0, ATempoMicroseconds)]);
  try
    Need(LClock.FrameAtTick(LClock.LengthTicks, ASampleRate, frCeiling) >= ASourceFrames, 'Proposal exceeds its finite grid budget');
    LCount := LClock.NextGridTick(ASourceFrames, ASampleRate, PitchPatternStepTicks) div PitchPatternStepTicks;
    if LClock.FrameAtTick(LCount * PitchPatternStepTicks, ASampleRate, frCeiling) > ASourceFrames then
    begin
      Dec(LCount);
    end;
    Need(LCount > 0, 'Audio does not contain one complete musical cell');
    SetLength(LResult.Frames, LCount);
    SetLength(LResult.Known, LCount);
    SetLength(LResult.PitchOrigins, LCount);
    SetLength(LResult.Drums, LCount);
    for LCell := 0 to LCount - 1 do
    begin
      ReportWork(AProgress, 'musical_propose_cells', wuItems, LCell, LCount);
      LStart := LClock.FrameAtTick(LCell * PitchPatternStepTicks, ASampleRate, frCeiling);
      LEnd := LClock.FrameAtTick((LCell + 1) * PitchPatternStepTicks, ASampleRate, frCeiling);
      LClasses := Default(TPitchClassWeights);
      LPower := 0;
      LWeight := 0;
      LFlux := 0;
      for J := 0 to 2 do
      begin
        LBandCell[J] := 0;
      end;
      LFirst := LStart div AObservations.AnalysisOptions.HopFrames;
      LLast := Min(High(AObservations.Features), (LEnd - 1) div AObservations.AnalysisOptions.HopFrames);
      for I := LFirst to LLast do
      begin
        LFeature := AObservations.Features[I];
        LOwnedStart := Max(LStart, LFeature.StartFrame);
        LOwnedEnd := Min(LEnd, Min(ASourceFrames,
          LFeature.StartFrame + AObservations.AnalysisOptions.HopFrames));
        LOverlap := Max(0, LOwnedEnd - LOwnedStart);
        LWeight := LWeight + LOverlap;
        LPower := LPower + Sqr(LFeature.Rms) * LOverlap;
        for J := 0 to 11 do
        begin
          LClasses[J] := LClasses[J] + LFeature.Chroma[J] * LOverlap;
        end;
        LFlux := Max(LFlux, LFeature.Flux);
        for J := 0 to 2 do
        begin
          LBandCell[J] := Max(LBandCell[J], AObservations.Bands[J].PositiveFlux[I]);
        end;
      end;
      LRms := 0;
      if LWeight > 0 then
      begin
        LRms := Sqrt(LPower / LWeight);
      end;
      if LRms <= AObservations.AnalysisOptions.SilenceRms then
      begin
        LResult.Known[LCell] := True;
        LResult.PitchOrigins[LCell] := mppSilence;
        SetLength(LResult.Frames[LCell], 3);
        Continue;
      end;
      LTotal := 0;
      LMaximum := 0;
      LBest := 0;
      for J := 0 to 11 do
      begin
        LTotal := LTotal + LClasses[J];
        if LClasses[J] > LMaximum then
        begin
          LMaximum := LClasses[J];
          LBest := J;
        end;
      end;
      if (LTotal <= 0) or (LMaximum / LTotal < 0.12) then
      begin
        Continue;
      end;
      LVelocity := 48;
      if LRms >= LMaximumRms * 0.35 then
      begin
        LVelocity := 80;
      end;
      if LRms >= LMaximumRms * 0.7 then
      begin
        LVelocity := 112;
      end;
      LOnset := LFlux >= 0.12;
      LLead := 72 + LBest;
      LPeriodic := (LCell < Length(LPattern)) and (LPattern[LCell].Kind = pskPitch);
      LResult.PitchOrigins[LCell] := mppSpectral;
      if LPeriodic then
      begin
        LLead := LPattern[LCell].Note;
        LOnset := LOnset or LPattern[LCell].Attack;
        LResult.PitchOrigins[LCell] := mppPeriodic;
      end;
      LBass := 36 + LBest;
      LFrame := nil;
      SetLength(LFrame, 3);
      Voice(0, [LBass]);
      Voice(2, [LLead]);
      for J := 0 to 11 do
      begin
        LSelected[J] := False;
      end;
      for K := 0 to 2 do
      begin
        LChosen := -1;
        for J := 0 to 11 do
        begin
          if not LSelected[J] and ((LChosen < 0) or (LClasses[J] > LClasses[LChosen])) then
          begin
            LChosen := J;
          end;
        end;
        if (LChosen < 0) or (LClasses[LChosen] < LMaximum * 0.35) then
        begin
          Break;
        end;
        LSelected[LChosen] := True;
      end;
      LFrame[1].Tones := nil;
      for J := 0 to 11 do
        if LSelected[J] then
        begin
          I := Length(LFrame[1].Tones);
          SetLength(LFrame[1].Tones, I + 1);
          LFrame[1].Tones[I].Pitch := 60 + J;
          LFrame[1].Tones[I].Velocity := LVelocity;
        end;
      LFrame[1].Action := caAttack;
      if (LCell > 0) and LResult.Known[LCell - 1] and not LOnset and
        SameTones(LFrame[1].Tones, LResult.Frames[LCell - 1][1].Tones) then
      begin
        LFrame[1].Action := caHold;
      end;
      LResult.Frames[LCell] := LFrame;
      LResult.Known[LCell] := True;
      for J := 0 to 2 do
      begin
        if (LBandMax[J] > 0) and (LBandCell[J] >= LBandMax[J] * 0.2) then
        begin
          LResult.Drums[LCell][J] := 80;
        end;
      end;
    end;
  finally
    LClock.Free;
  end;
  LResult.HasSound := ProposeMusicalSound(AObservations.MeanCentroidHz,
    AObservations.MinimumRms, AObservations.MaximumRms, LResult.Sound);
  ValidateProposedMusicalGrid(LResult, AProgress);
  Result := LResult;
end;

end.
