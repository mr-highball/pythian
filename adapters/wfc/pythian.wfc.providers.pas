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
  pythian.music.context,
  pythian.pitch.track,
  pythian.wfc.layers,
  wfc_sequence,
  wfc_music_ensemble;

type
  TStyleProviderVocabulary = (spvKey, spvTempo, spvOnsets, spvIntensity,
    spvPitch, spvPitchRhythm, spvPerformance, spvHarmony, spvRhythm, spvVoice);
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

{ Uses existing canonical codecs. No inferred roles, relative-pitch conversion,
  silence from empty onset cells, new vocabulary or schema compatibility branch. }
function DecodeStyleProviderChoice(const AVocabulary: TStyleProviderVocabulary;
  const AToken: String): TStyleProviderChoice;
{ Borrows the immutable model synchronously; returns detached choices in its
  public vocabulary order. Failure leaves a previously assigned result intact. }
function CopyStyleProviderChoices(const AModel: TWfcSequenceModel;
  const AVocabulary: TStyleProviderVocabulary): TStyleProviderChoices;

implementation

uses
  pythian.audio,
  pythian.wfc.context,
  pythian.wfc.pitch,
  pythian.wfc.style;

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
  const AVocabulary: TStyleProviderVocabulary): TStyleProviderChoices;
var
  LChoices: TStyleProviderChoices;
  LIndex: Integer;
begin
  if AModel = nil then
  begin
    raise EAudio.Create('Style provider requires a model');
  end;
  LChoices := nil;
  SetLength(LChoices, AModel.PublicTokenCount);
  for LIndex := 0 to High(LChoices) do
  begin
    LChoices[LIndex] := DecodeStyleProviderChoice(AVocabulary, AModel.PublicTokenAt(LIndex));
  end;
  Result := LChoices;
end;

end.
