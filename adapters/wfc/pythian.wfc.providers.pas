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
    { Present for caller-declared independent voice roles only. Pitch identity
      is explicit; the name is never evidence of inferred instrument ownership. }
    RoleId: String;
    { Joint rhythm actions use this exact caller-declared role order. }
    RoleOrder: TLayerNames;
    PitchIdentity: TStylePitchIdentity;
    MinimumPitch: Integer;
    MaximumPitch: Integer;
  end;

{ Reuses canonical codecs; paired context binds harmony and ordered rhythm.
  No inferred roles, relative-pitch conversion or silence from empty onset cells. }
function EncodeMusicalContextToken(const AHarmony, ARhythm: String): String;
procedure DecodeMusicalContextToken(const AToken: String; out AHarmony, ARhythm: String);
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
  pythian.wfc.style;

function EncodeMusicalContextToken(const AHarmony, ARhythm: String): String;
begin
  DecodeWfcMusicPitchClassSet(AHarmony);
  DecodeWfcMusicRhythmFrame(ARhythm);
  Result := 'ctx1:' + IntToStr(Length(AHarmony)) + ':' + AHarmony + ARhythm;
end;

procedure DecodeMusicalContextToken(const AToken: String; out AHarmony, ARhythm: String);
var
  LText: String;
  LSeparator: Integer;
  LLength: Integer;
  LHarmony: String;
  LRhythm: String;
begin
  if (Copy(AToken, 1, 5) <> 'ctx1:') or (Length(AToken) > 16384) then
    raise EAudio.Create('Unknown musical context token');
  LText := Copy(AToken, 6, Length(AToken));
  LSeparator := Pos(':', LText);
  if (LSeparator < 2) or not TryStrToInt(Copy(LText, 1, LSeparator - 1), LLength) or
    (LLength < 1) or (LLength >= Length(LText) - LSeparator) then
    raise EAudio.Create('Invalid musical context token length');
  LHarmony := Copy(LText, LSeparator + 1, LLength);
  LRhythm := Copy(LText, LSeparator + LLength + 1, Length(LText));
  if EncodeMusicalContextToken(LHarmony, LRhythm) <> AToken then
    raise EAudio.Create('Noncanonical musical context token');
  AHarmony := LHarmony;
  ARhythm := LRhythm;
end;

function DecodeStyleProviderChoice(const AVocabulary: TStyleProviderVocabulary;
  const AToken: String): TStyleProviderChoice;
var
  LChoice: TStyleProviderChoice;
  LJoint: TPitchRhythmCell;
  LSpan: TPitchDurationCell;
  LFrame: TWfcMusicEnsembleFrame;
  LHarmony: String;
  LRhythm: String;
begin
  LChoice := Default(TStyleProviderChoice);
  LChoice.Token := AToken;
  LChoice.Intensity := -1;
  LChoice.Note := -1;
  LChoice.PitchKind := pskUnknown;
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
      DecodeMusicalContextToken(AToken, LHarmony, LRhythm);
      LChoice.Dimensions := [scdHarmony, scdRhythm];
      LChoice.Harmony := DecodeWfcMusicPitchClassSet(LHarmony);
      LChoice.Rhythm := DecodeWfcMusicRhythmFrame(LRhythm);
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
