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
unit pythian.wfc.providers;

{$mode delphi}
{$H+}

interface

uses
  pythian.progress,
  pythian.music.context,
  pythian.pitch.track,
  pythian.wfc.layers,
  pythian.wfc.provider.codecs,
  wfc_sequence,
  wfc_music_ensemble;

type
  TStyleProviderVocabulary = (spvKey, spvTempo, spvOnsets, spvIntensity,
    spvPitch, spvPitchRhythm, spvPerformance, spvHarmony, spvRhythm, spvVoice, spvCaller,
    spvMusicalContext);
  TStyleChoiceDimension = (scdKey, scdTempo, scdOnset, scdIntensity,
    scdPitch, scdDuration, scdHarmony, scdRhythm, scdVoice);
  TStyleChoiceDimensions = set of TStyleChoiceDimension;
  TMusicalContextCell = record
    Frame: TWfcMusicEnsembleFrame;
    { -1 projects H/R only; otherwise the upstream context also decides this
      explicitly caller-selected role. Other role pitches stay unpinned. }
    DrivenRole: Integer;
  end;
  TStyleProviderChoice = record
    Token: String;
    Dimensions: TStyleChoiceDimensions;
    Key: TKeyContext;
    TempoMicroseconds: Integer;
    Onset: Boolean;
    Intensity: Integer;
    PitchKind: TPitchSpanKind;
    Note: Integer;
    DurationTicks: Integer;
    Harmony: TWfcMusicPitchClassSet;
    Rhythm: TWfcMusicRhythmFrame;
    Voice: TWfcMusicVoiceCell;
    { Joint context keeps a synchronized witness and an explicit driven role.
      H/R and that role feed the next graph; other performed roles stay free. }
    Context: TMusicalContextCell;
    CallerValue: TProviderCodecChoice;
  end;
  TStyleProviderChoices = array of TStyleProviderChoice;
  TStyleProviderTiming = (sptUniform, sptHeld, sptGeneratedSpans);
  TStyleProviderDependency = record
    Name: String;
    TimeMapping: TLayerTimeMapping;
  end;
  TStyleProviderDependencies = array of TStyleProviderDependency;
  TStylePitchIdentity = (spiUnspecified, spiAbsoluteMidi);
  { A detached snapshot of the definition, not the session's pending edits or
    position-specific feasibility. Choice tokens can be used with existing
    session masks/preferences. Dependencies describe actual WFC projections.
    StepTicks is positive only for uniform timing. Held values cover the captured
    plan; generated-span cells acquire cumulative boundaries only after solving.
    Musical values are meaningful only for the choice's listed Dimensions. }
  TStyleProviderDescription = record
    Name: String;
    Vocabulary: TStyleProviderVocabulary;
    CodecBinding: TProviderCodecBinding;
    TicksPerQuarter: Integer;
    Timing: TStyleProviderTiming;
    StepTicks: Integer;
    Scope: TLayerScope;
    Dependencies: TStyleProviderDependencies;
    Choices: TStyleProviderChoices;
    Preferences: TLayerTokenPreferences;
    { Declared independent voice or context-driven role. Pitch identity is
      explicit; the name never claims inferred instrument ownership. }
    RoleId: String;
    { Joint rhythm actions use this exact caller-declared role order. }
    RoleOrder: TLayerNames;
    PitchIdentity: TStylePitchIdentity;
    MinimumPitch: Integer;
    MaximumPitch: Integer;
  end;

{ Reuses the canonical ensemble codec. Context retains synchronized role
  histories before deriving harmony and ordered rhythm; no lossy H/R token merge.
  No inferred roles, relative-pitch conversion or silence from empty onset cells. }
function EncodeMusicalContextToken(const ACell: TMusicalContextCell): String;
function DecodeMusicalContextToken(const AToken: String): TMusicalContextCell;
function DecodeStyleProviderChoice(const AVocabulary: TStyleProviderVocabulary;
  const AToken: String): TStyleProviderChoice;
{ Borrows the immutable model synchronously; returns detached choices in its
  public vocabulary order. Failure leaves a previously assigned result intact.
  Progress is borrowed per call; totals describe the current phase only. }
function CopyStyleProviderChoices(const AModel: TWfcSequenceModel;
  const AVocabulary: TStyleProviderVocabulary;
  const AProgress: TWorkProgressCallback = nil): TStyleProviderChoices; overload;
function CopyStyleProviderChoices(const AModel: TWfcSequenceModel;
  const AVocabulary: TStyleProviderVocabulary; const ABinding: TProviderCodecBinding;
  const ARegistry: TProviderCodecRegistry = nil;
  const AAdmission: TProviderCodecAdmission = nil;
  const AProgress: TWorkProgressCallback = nil): TStyleProviderChoices; overload;
function CloneStyleProviderChoices(const AChoices: TStyleProviderChoices;
  const AProgress: TWorkProgressCallback = nil): TStyleProviderChoices;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.wfc.context,
  pythian.wfc.pitch,
  pythian.wfc.style,
  wfc_music;

function EncodeMusicalContextToken(const ACell: TMusicalContextCell): String;
var
  LVoice: TWfcMusicVoiceCell;
  LTone: TWfcMusicTone;
begin
  if (Length(ACell.Frame.Voices) < 1) or (Length(ACell.Frame.Voices) > 6) then
    raise EAudio.Create('Musical context requires 1..6 ordered roles');
  if (ACell.DrivenRole < -1) or (ACell.DrivenRole >= Length(ACell.Frame.Voices)) or
    (ACell.DrivenRole <> Trunc(ACell.DrivenRole)) then
    raise EAudio.Create('Musical context driven role is outside its ordered roles');
  for LVoice in ACell.Frame.Voices do
    for LTone in LVoice.Tones do
      if (LTone.Pitch < 0) or (LTone.Pitch > 127) or
        (LTone.Pitch <> Trunc(LTone.Pitch)) or (LTone.Velocity <> Trunc(LTone.Velocity)) then
        raise EAudio.Create('Musical context requires absolute MIDI pitches 0..127');
  Result := 'ctx2:' + IntToStr(ACell.DrivenRole) + ':' + EncodeWfcMusicEnsembleFrame(ACell.Frame);
end;

function DecodeMusicalContextToken(const AToken: String): TMusicalContextCell;
var
  LCell: TMusicalContextCell;
  LText: String;
  LSeparator: Integer;
begin
  if (Copy(AToken, 1, 5) <> 'ctx2:') or (Length(AToken) > 16384) then
    raise EAudio.Create('Unknown musical context token');
  LText := Copy(AToken, 6, Length(AToken));
  LSeparator := Pos(':', LText);
  if (LSeparator < 2) or
    not TryStrToInt(Copy(LText, 1, LSeparator - 1), LCell.DrivenRole) then
    raise EAudio.Create('Musical context requires an explicit driven-role index');
  LCell.Frame := DecodeWfcMusicEnsembleFrame(Copy(LText, LSeparator + 1, Length(LText)));
  if EncodeMusicalContextToken(LCell) <> AToken then
    raise EAudio.Create('Noncanonical musical context token');
  Result := LCell;
end;

function DecodeStyleProviderChoice(const AVocabulary: TStyleProviderVocabulary;
  const AToken: String): TStyleProviderChoice;
var
  LChoice: TStyleProviderChoice;
  LJoint: TPitchRhythmCell;
  LSpan: TPitchDurationCell;
  LFrame: TWfcMusicEnsembleFrame;
begin
  LChoice := Default(TStyleProviderChoice);
  LChoice.Token := AToken;
  LChoice.Intensity := -1;
  LChoice.Note := -1;
  LChoice.PitchKind := pskUnknown;
  LChoice.Context.DrivenRole := -1;
  case AVocabulary of
    spvKey:
    begin
      LChoice.Dimensions := [scdKey];
      LChoice.Key := KeyContextFromToken(AToken);
    end;
    spvTempo:
    begin
      LChoice.Dimensions := [scdTempo];
      LChoice.TempoMicroseconds := TempoContextFromToken(AToken);
    end;
    spvOnsets:
    begin
      if (AToken <> RhythmOnsetToken) and (AToken <> RhythmEmptyToken) then
      begin
        raise EAudio.Create('Unknown onset provider choice');
      end;
      LChoice.Dimensions := [scdOnset];
      LChoice.Onset := AToken = RhythmOnsetToken;
    end;
    spvIntensity:
    begin
      LChoice.Dimensions := [scdIntensity];
      LChoice.Intensity := DecodeStyleIntensityToken(AToken);
    end;
    spvPitch:
    begin
      LChoice.Dimensions := [scdPitch];
      LChoice.PitchKind := pskPitch;
      LChoice.Note := DecodePitchNoteToken(AToken);
    end;
    spvPitchRhythm:
    begin
      LJoint := DecodePitchRhythmToken(AToken);
      LChoice.Dimensions := [scdPitch, scdOnset];
      LChoice.PitchKind := pskPitch;
      LChoice.Note := LJoint.Note;
      LChoice.Onset := LJoint.Level > 0;
      if LJoint.Level <= 4 then
      begin
        Include(LChoice.Dimensions, scdIntensity);
        LChoice.Intensity := LJoint.Level;
      end;
    end;
    spvPerformance:
    begin
      LSpan := DecodePitchDurationToken(AToken);
      LChoice.Dimensions := [scdPitch, scdDuration];
      LChoice.PitchKind := LSpan.Kind;
      LChoice.Note := LSpan.Note;
      LChoice.DurationTicks := LSpan.Duration;
    end;
    spvHarmony:
    begin
      LChoice.Dimensions := [scdHarmony];
      LChoice.Harmony := DecodeWfcMusicPitchClassSet(AToken);
    end;
    spvRhythm:
    begin
      LChoice.Dimensions := [scdRhythm];
      LChoice.Rhythm := DecodeWfcMusicRhythmFrame(AToken);
    end;
    spvMusicalContext:
    begin
      LChoice.Context := DecodeMusicalContextToken(AToken);
      LChoice.Dimensions := [scdHarmony, scdRhythm, scdVoice];
      LChoice.Harmony := ProjectWfcMusicEnsembleFrameToPitchClassSet(LChoice.Context.Frame, 12);
      LChoice.Rhythm := ProjectWfcMusicEnsembleFrameToRhythm(LChoice.Context.Frame);
    end;
    spvVoice:
    begin
      LFrame := DecodeWfcMusicEnsembleFrame(AToken);
      if Length(LFrame.Voices) <> 1 then
      begin
        raise EAudio.Create('A role choice requires a singleton voice frame');
      end;
      LChoice.Dimensions := [scdVoice];
      LChoice.Voice := LFrame.Voices[0];
    end;
  else
    raise EAudio.Create('Unknown style provider vocabulary');
  end;
  Result := LChoice;
end;

function CopyStyleProviderChoices(const AModel: TWfcSequenceModel;
  const AVocabulary: TStyleProviderVocabulary;
  const AProgress: TWorkProgressCallback): TStyleProviderChoices;
begin
  Result := CopyStyleProviderChoices(AModel, AVocabulary,
    Default(TProviderCodecBinding), nil, nil, AProgress);
end;

function CloneStyleProviderChoices(const AChoices: TStyleProviderChoices;
  const AProgress: TWorkProgressCallback): TStyleProviderChoices;
var
  LIndex: Integer;
  LRole: Integer;
  LChoices: TStyleProviderChoices;
begin
  LChoices := Copy(AChoices);
  ReportWork(AProgress, 'provider_clone_choices', wuItems, 0, Length(LChoices));
  for LIndex := 0 to High(LChoices) do
  begin
    LChoices[LIndex].CallerValue := CopyProviderCodecChoice(AChoices[LIndex].CallerValue);
    LChoices[LIndex].Harmony.PitchClasses := Copy(AChoices[LIndex].Harmony.PitchClasses);
    LChoices[LIndex].Rhythm.Actions := Copy(AChoices[LIndex].Rhythm.Actions);
    LChoices[LIndex].Voice.Tones := Copy(AChoices[LIndex].Voice.Tones);
    LChoices[LIndex].Context.Frame.Voices := Copy(AChoices[LIndex].Context.Frame.Voices);
    for LRole := 0 to High(LChoices[LIndex].Context.Frame.Voices) do
      LChoices[LIndex].Context.Frame.Voices[LRole].Tones :=
        Copy(AChoices[LIndex].Context.Frame.Voices[LRole].Tones);
    if ((LIndex + 1) mod 64) = 0 then
    begin
      ReportWork(AProgress, 'provider_clone_choices', wuItems, LIndex + 1, Length(LChoices));
    end;
  end;
  ReportWork(AProgress, 'provider_clone_choices', wuItems, Length(LChoices), Length(LChoices));
  Result := LChoices;
end;

function CopyStyleProviderChoices(const AModel: TWfcSequenceModel;
  const AVocabulary: TStyleProviderVocabulary; const ABinding: TProviderCodecBinding;
  const ARegistry: TProviderCodecRegistry; const AAdmission: TProviderCodecAdmission;
  const AProgress: TWorkProgressCallback): TStyleProviderChoices;
var
  LChoices: TStyleProviderChoices;
  LIndex: Integer;
  LAdmission: TProviderCodecAdmission;
  LOwned: Boolean;
begin
  if AModel = nil then
  begin
    raise EAudio.Create('Style provider requires a model');
  end;
  if (AVocabulary <> spvCaller) and not EmptyProviderCodecBinding(ABinding) then
  begin
    raise EAudio.Create('Built-in vocabulary cannot carry caller codec meaning');
  end;
  LAdmission := BorrowProviderCodecAdmission(ARegistry, AAdmission, LOwned);
  try
    if AVocabulary = spvCaller then
    begin
      LAdmission.ValidateBinding(ABinding, AProgress);
    end;
    LChoices := nil;
    SetLength(LChoices, AModel.PublicTokenCount);
    ReportWork(AProgress, 'provider_decode_choices', wuItems, 0, Length(LChoices));
    for LIndex := 0 to High(LChoices) do
    begin
      if AVocabulary = spvCaller then
      begin
        LChoices[LIndex] := Default(TStyleProviderChoice);
        LChoices[LIndex].Token := AModel.PublicTokenAt(LIndex);
        LChoices[LIndex].CallerValue := LAdmission.DecodeChoice(ABinding,
          LChoices[LIndex].Token, AProgress);
      end
      else
      begin
        LChoices[LIndex] := DecodeStyleProviderChoice(AVocabulary, AModel.PublicTokenAt(LIndex));
      end;
      if ((LIndex + 1) mod 64) = 0 then
      begin
        ReportWork(AProgress, 'provider_decode_choices', wuItems, LIndex + 1, Length(LChoices));
      end;
    end;
    ReportWork(AProgress, 'provider_decode_choices', wuItems, Length(LChoices), Length(LChoices));
    Result := LChoices;
  finally
    if LOwned then
    begin
      LAdmission.Free;
    end;
  end;
end;

end.
