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
unit pythian.tools.studio.sounds;

{$mode delphi}{$H+}

interface

uses fpjson, pythian.instrument.recipe, pythian.mix.recipe;

const
  StudioSoundMaximumZones = 16;

{ JSON boundary only. Primary definitions/factories, clocks and effect catalog
  own sound behavior. No source PCM or inference is performed by this codec. }
function EncodeStudioInstrumentRecipe(const ARecipe: TInstrumentRecipe): TJSONObject;
function DecodeStudioInstrumentRecipe(const AValue: TJSONData): TInstrumentRecipe;
function EncodeStudioMixRecipe(const AMix: TStemMixRecipe): TJSONObject;
function DecodeStudioMixRecipe(const AValue: TJSONData;
  const ASampleRate: Integer): TStemMixRecipe;
function CanonicalStudioSoundDesign(const AValue: TJSONData;
  const ASampleRate: Integer): TJSONObject;
function StudioSoundCatalog: TJSONObject;
function StudioSoundMix(const ASettings: TJSONObject;
  const ASampleRate: Integer): TStemMixRecipe;
function StudioSoundTailFrames(const ASettings: TJSONObject;
  const ASampleRate: Integer): Int64;
function StudioFollowupSoundSettings(const AParent, ARequest: TJSONObject;
  const ASampleRate: Integer): TJSONObject;

implementation

uses pythian.tools.effects.json, SysUtils, pythian.audio, pythian.text,
  pythian.automation, pythian.additive,
  pythian.synth, pythian.source.wavetable, pythian.source.sample,
  pythian.oscillator, pythian.biquad, pythian.filter,
  pythian.instrument.catalog, pythian.effects.catalog, pythian.effects,
  pythian.tools.json, pythian.time;

type
  TSoundNumbers = array of Double;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function ObjectValue(const AValue: TJSONData; const AKeys: String;
  const ACount: Integer): TJSONObject;
var
  I: Integer;
begin
  Need((AValue <> nil) and (AValue.JSONType = jtObject), 'Sound settings need an object');
  Result := TJSONObject(AValue);
  Need(Result.Count = ACount, 'Sound settings have missing or extra fields');
  for I := 0 to Result.Count - 1 do
  begin
    Need((Pos('|' + Result.Names[I] + '|', AKeys) > 0) and
      (Result.IndexOfName(Result.Names[I]) = I), 'Unknown or repeated sound setting');
  end;
end;

function ArrayValue(const AValue: TJSONData; const AMinimum, AMaximum: Integer): TJSONArray;
begin
  Need((AValue <> nil) and (AValue.JSONType = jtArray), 'Sound setting needs a list');
  Result := TJSONArray(AValue);
  Need((Result.Count >= AMinimum) and (Result.Count <= AMaximum), 'Sound list exceeds its bounds');
end;

function NumericValue(const AValue: TJSONData; const AMinimum, AMaximum: Double): Double;
begin
  Need((AValue <> nil) and (AValue.JSONType = jtNumber), 'Sound setting needs a number');
  Result := AValue.AsFloat;
  RequireFinite(Result, 'Sound setting');
  Need((Result >= AMinimum) and (Result <= AMaximum), 'Sound number is outside its limits');
end;

function WholeValue(const AValue: TJSONData; const AMinimum, AMaximum: Integer): Integer;
var
  LNumber: Double;
begin
  LNumber := NumericValue(AValue, AMinimum, AMaximum);
  Need(LNumber = Trunc(LNumber), 'Sound setting needs a whole number');
  Result := Trunc(LNumber);
end;

function BooleanValue(const AValue: TJSONData): Boolean;
begin
  Need((AValue <> nil) and (AValue.JSONType = jtBoolean), 'Sound setting needs an explicit switch');
  Result := AValue.AsBoolean;
end;

function TextValue(const AValue: TJSONData; const AMaximum: Integer): TScalarText;
begin
  Need((AValue <> nil) and (AValue.JSONType = jtString), 'Sound setting needs text');
  Result := AValue.AsString;
  ValidateScalarText(Result, AMaximum, False);
end;

function EncodeNumbers(const AValues: array of Double): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to High(AValues) do
  begin
    Result.Add(AValues[I]);
  end;
end;

function DecodeNumbers(const AValue: TJSONData; const AMaximum: Integer): TSoundNumbers;
var
  LValues: TJSONArray;
  I: Integer;
begin
  Result := nil;
  LValues := ArrayValue(AValue, 0, AMaximum);
  SetLength(Result, LValues.Count);
  for I := 0 to High(Result) do
  begin
    Result[I] := NumericValue(LValues[I], -1E12, 1E12);
  end;
end;

function EncodeCurve(const ACurve: TInstrumentCurveRecipe): TJSONObject;
var
  LPoints: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create(['kind', Ord(ACurve.Kind)]);
  if ACurve.Kind = ickPoints then
  begin
    LPoints := TJSONArray.Create;
    Result.Add('points', LPoints);
    for I := 0 to High(ACurve.Points) do
    begin
      LPoints.Add(TJSONArray.Create([ACurve.Points[I].Seconds,
        ACurve.Points[I].Value, Ord(ACurve.Points[I].Transition)]));
    end;
  end
  else
  begin
    Result.Add('hz', ACurve.LfoHz);
    Result.Add('phase', ACurve.LfoPhaseCycles);
    Result.Add('shape', Ord(ACurve.LfoShape));
    Result.Add('scale', ACurve.Scale);
    Result.Add('offset', ACurve.Offset);
  end;
end;

function DecodeCurve(const AValue: TJSONData): TInstrumentCurveRecipe;
var
  LObject: TJSONObject;
  LPoints: TJSONArray;
  LPoint: TJSONArray;
  I: Integer;
begin
  Need((AValue <> nil) and (AValue.JSONType = jtObject), 'Sound curve needs an object');
  LObject := TJSONObject(AValue);
  Result := DefaultInstrumentCurve;
  Result.Kind := TInstrumentCurveKind(WholeValue(LObject.Find('kind'), 0, 1));
  if Result.Kind = ickPoints then
  begin
    ObjectValue(LObject, '|kind|points|', 2);
    LPoints := ArrayValue(LObject.Find('points'), 1, MaximumAutomationPoints);
    SetLength(Result.Points, LPoints.Count);
    for I := 0 to High(Result.Points) do
    begin
      LPoint := ArrayValue(LPoints[I], 3, 3);
      Result.Points[I].Seconds := NumericValue(LPoint[0], 0, 86400);
      Result.Points[I].Value := NumericValue(LPoint[1], -1E12, 1E12);
      Result.Points[I].Transition := TAutomationTransition(WholeValue(LPoint[2], 0, 2));
    end;
  end
  else
  begin
    ObjectValue(LObject, '|kind|hz|phase|shape|scale|offset|', 6);
    Result.LfoHz := NumericValue(LObject.Find('hz'), 0.0001, 24000);
    Result.LfoPhaseCycles := NumericValue(LObject.Find('phase'), 0, 1);
    Result.LfoShape := TAutomationLfoShape(WholeValue(LObject.Find('shape'), 0, 1));
    Result.Scale := NumericValue(LObject.Find('scale'), -1E12, 1E12);
    Result.Offset := NumericValue(LObject.Find('offset'), -1E12, 1E12);
  end;
end;

function EncodeSource(const ASource: TInstrumentSourceRecipe): TJSONObject;
var
  LRows: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create(['kind', Ord(ASource.Kind)]);
  case ASource.Kind of
    iskOscillator: ;
    iskAdditive:
    begin
      LRows := TJSONArray.Create;
      Result.Add('partials', LRows);
      for I := 0 to High(ASource.Partials) do
      begin
        LRows.Add(TJSONArray.Create([ASource.Partials[I].Ratio,
          ASource.Partials[I].Gain, ASource.Partials[I].PhaseCycles]));
      end;
    end;
    iskWavetable:
    begin
      Result.Add('table_size', ASource.TableSize);
      LRows := TJSONArray.Create;
      Result.Add('tables', LRows);
      for I := 0 to High(ASource.Tables) do
      begin
        LRows.Add(TJSONObject.Create(['sine', EncodeNumbers(ASource.Tables[I].Sine),
          'cosine', EncodeNumbers(ASource.Tables[I].Cosine), 'mean', ASource.Tables[I].Mean]));
      end;
      if Length(ASource.Tables) > 1 then
      begin
        Result.Add('motion', EncodeCurve(ASource.TableMotion));
      end
      else
      begin
        Result.Add('motion', TJSONNull.Create);
      end;
    end;
    iskFm, iskPm:
    begin
      Result.Add('ratio', ASource.ModulatorRatio);
      Result.Add('depth', ASource.ModulationDepth);
    end;
    iskSample:
    begin
      Result.Add('sample_id', NativeJSONText(ASource.SampleId));
      Result.Add('start_frame', ASource.SampleStartFrame);
      Result.Add('end_frame', ASource.SampleEndFrame);
      Result.Add('has_loop', ASource.SampleHasLoop);
      Result.Add('loop_start', ASource.SampleLoopStart);
      Result.Add('loop_end', ASource.SampleLoopEnd);
      Result.Add('root_hz', ASource.SampleRootHz);
      Result.Add('playback', Ord(ASource.SamplePlayback));
      Result.Add('quality', Ord(ASource.SampleQuality));
      Result.Add('maximum_step', ASource.SampleMaximumStep);
    end;
  else
    Result.Free;
    raise EAudio.Create('Unsupported sound source');
  end;
end;

function DecodeSource(const AValue: TJSONData): TInstrumentSourceRecipe;
var
  LObject: TJSONObject;
  LRow: TJSONObject;
  LRows: TJSONArray;
  LNumbers: TJSONArray;
  LZone: TInstrumentZoneRecipe;
  I: Integer;
begin
  Need((AValue <> nil) and (AValue.JSONType = jtObject), 'Sound source needs an object');
  LObject := TJSONObject(AValue);
  LZone := DefaultInstrumentZoneRecipe;
  Result := LZone.Source;
  Result.Kind := TInstrumentSourceKind(WholeValue(LObject.Find('kind'), 0, 5));
  case Result.Kind of
    iskOscillator:
      ObjectValue(LObject, '|kind|', 1);
    iskAdditive:
    begin
      ObjectValue(LObject, '|kind|partials|', 2);
      LRows := ArrayValue(LObject.Find('partials'), 1, MaximumAdditivePartials);
      SetLength(Result.Partials, LRows.Count);
      for I := 0 to High(Result.Partials) do
      begin
        LNumbers := ArrayValue(LRows[I], 3, 3);
        Result.Partials[I].Ratio := NumericValue(LNumbers[0], 0.0001, 128);
        Result.Partials[I].Gain := NumericValue(LNumbers[1], -16, 16);
        Result.Partials[I].PhaseCycles := NumericValue(LNumbers[2], 0, 1);
      end;
    end;
    iskWavetable:
    begin
      ObjectValue(LObject, '|kind|table_size|tables|motion|', 4);
      Result.TableSize := WholeValue(LObject.Find('table_size'), 2, MaximumTableSize);
      LRows := ArrayValue(LObject.Find('tables'), 1, MaximumWavetableTrajectoryRecipes);
      SetLength(Result.Tables, LRows.Count);
      for I := 0 to High(Result.Tables) do
      begin
        LRow := ObjectValue(LRows[I], '|sine|cosine|mean|', 3);
        Result.Tables[I].Sine := DecodeNumbers(LRow.Find('sine'), MaximumTableHarmonics);
        Result.Tables[I].Cosine := DecodeNumbers(LRow.Find('cosine'), MaximumTableHarmonics);
        Result.Tables[I].Mean := NumericValue(LRow.Find('mean'), -1E12, 1E12);
      end;
      if Length(Result.Tables) > 1 then
      begin
        Result.TableMotion := DecodeCurve(LObject.Find('motion'));
      end
      else
      begin
        Need((LObject.Find('motion') <> nil) and
          (LObject.Find('motion').JSONType = jtNull), 'One wavetable has no trajectory');
      end;
    end;
    iskFm, iskPm:
    begin
      ObjectValue(LObject, '|kind|ratio|depth|', 3);
      Result.ModulatorRatio := NumericValue(LObject.Find('ratio'), 0.0001, 128);
      Result.ModulationDepth := NumericValue(LObject.Find('depth'), 0, 24000);
    end;
    iskSample:
    begin
      ObjectValue(LObject,
        '|kind|sample_id|start_frame|end_frame|has_loop|loop_start|loop_end|root_hz|playback|quality|maximum_step|', 11);
      Result.SampleId := TextValue(LObject.Find('sample_id'), 256);
      Result.SampleStartFrame := WholeValue(LObject.Find('start_frame'), 0, High(Integer));
      Result.SampleEndFrame := WholeValue(LObject.Find('end_frame'), -1, High(Integer));
      Result.SampleHasLoop := BooleanValue(LObject.Find('has_loop'));
      Result.SampleLoopStart := WholeValue(LObject.Find('loop_start'), 0, High(Integer));
      Result.SampleLoopEnd := WholeValue(LObject.Find('loop_end'), 0, High(Integer));
      Result.SampleRootHz := NumericValue(LObject.Find('root_hz'), 0.001, 24000);
      Result.SamplePlayback := TSamplePlayback(WholeValue(LObject.Find('playback'), 0, Ord(High(TSamplePlayback))));
      Result.SampleQuality := TSampleQuality(WholeValue(LObject.Find('quality'), 0, Ord(High(TSampleQuality))));
      Result.SampleMaximumStep := NumericValue(LObject.Find('maximum_step'), 0.001, 128);
    end;
  end;
end;

function EncodeStudioInstrumentRecipe(const ARecipe: TInstrumentRecipe): TJSONObject;
var
  LRecipe: TInstrumentRecipe;
  LZone: TInstrumentZoneRecipe;
  LRows: TJSONArray;
  LControls: TJSONArray;
  LGate: TJSONObject;
  I: Integer;
  J: Integer;
begin
  LRecipe := CopyInstrumentRecipe(ARecipe);
  Result := TJSONObject.Create(['format', 'pythian.instrument.recipe.v1']);
  Result.Add('id', NativeJSONText(LRecipe.Id));
  Result.Add('caption', NativeJSONText(LRecipe.Caption));
  Result.Add('origin', NativeJSONText(LRecipe.Origin));
  LRows := TJSONArray.Create;
  Result.Add('zones', LRows);
  try
    for I := 0 to High(LRecipe.Zones) do
    begin
      LZone := LRecipe.Zones[I];
      LControls := TJSONArray.Create;
      LGate := TJSONObject.Create(['enabled', LZone.Gate.Enabled]);
      LRows.Add(TJSONObject.Create(['keys', TJSONArray.Create([LZone.MinimumKey, LZone.MaximumKey]),
        'velocity', TJSONArray.Create([LZone.MinimumVelocity, LZone.MaximumVelocity]),
        'voice', TJSONObject.Create(['shape', Ord(LZone.Voice.Shape),
          'quality', Ord(LZone.Voice.OscillatorQuality), 'gain', LZone.Voice.Gain,
          'pan', LZone.Voice.Pan, 'cutoff_hz', LZone.Voice.CutoffHz,
          'filter_model', Ord(LZone.Voice.FilterModel), 'filter_kind', Ord(LZone.Voice.FilterKind),
          'biquad_kind', Ord(LZone.Voice.BiquadKind), 'q', LZone.Voice.BiquadQ,
          'gain_db', LZone.Voice.BiquadGainDb,
          'envelope', TJSONArray.Create([LZone.Voice.Envelope.AttackSeconds,
            LZone.Voice.Envelope.DecaySeconds, LZone.Voice.Envelope.SustainLevel,
            LZone.Voice.Envelope.ReleaseSeconds])]),
        'controls', LControls, 'gate', LGate]));
      LRows.Objects[I].Add('source', EncodeSource(LZone.Source));
      for J := 0 to High(LZone.Controls) do
      begin
        LControls.Add(TJSONObject.Create(['target', Ord(LZone.Controls[J].Target),
          'curve', EncodeCurve(LZone.Controls[J].Curve)]));
      end;
      if LZone.Gate.Enabled then
      begin
        LGate.Add('held', EncodeCurve(LZone.Gate.Held));
        LGate.Add('release_seconds', LZone.Gate.ReleaseSeconds);
        if (LZone.Gate.ReleaseSeconds > 0) or (Length(LZone.Gate.Release.Points) > 0) or
          (LZone.Gate.Release.Kind = ickLfo) then
        begin
          LGate.Add('release', EncodeCurve(LZone.Gate.Release));
        end
        else
        begin
          LGate.Add('release', TJSONNull.Create);
        end;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function DecodeStudioInstrumentRecipe(const AValue: TJSONData): TInstrumentRecipe;
var
  LObject: TJSONObject;
  LZone: TJSONObject;
  LVoice: TJSONObject;
  LControl: TJSONObject;
  LGate: TJSONObject;
  LZones: TJSONArray;
  LArray: TJSONArray;
  LControls: TJSONArray;
  I: Integer;
  J: Integer;
begin
  Result := Default(TInstrumentRecipe);
  LObject := ObjectValue(AValue, '|format|id|caption|origin|zones|', 5);
  Need(TextValue(LObject.Find('format'), 64) = 'pythian.instrument.recipe.v1', 'Unknown instrument recipe format');
  Result.Id := TextValue(LObject.Find('id'), 128);
  Result.Caption := TextValue(LObject.Find('caption'), 128);
  Result.Origin := TextValue(LObject.Find('origin'), 512);
  LZones := ArrayValue(LObject.Find('zones'), 1, StudioSoundMaximumZones);
  SetLength(Result.Zones, LZones.Count);
  for I := 0 to High(Result.Zones) do
  begin
    Result.Zones[I] := DefaultInstrumentZoneRecipe;
    LZone := ObjectValue(LZones[I], '|keys|velocity|voice|source|controls|gate|', 6);
    LArray := ArrayValue(LZone.Find('keys'), 2, 2);
    Result.Zones[I].MinimumKey := WholeValue(LArray[0], 0, 127);
    Result.Zones[I].MaximumKey := WholeValue(LArray[1], Result.Zones[I].MinimumKey, 127);
    LArray := ArrayValue(LZone.Find('velocity'), 2, 2);
    Result.Zones[I].MinimumVelocity := WholeValue(LArray[0], 1, 127);
    Result.Zones[I].MaximumVelocity := WholeValue(LArray[1], Result.Zones[I].MinimumVelocity, 127);
    LVoice := ObjectValue(LZone.Find('voice'),
      '|shape|quality|gain|pan|cutoff_hz|filter_model|filter_kind|biquad_kind|q|gain_db|envelope|', 11);
    Result.Zones[I].Voice.Shape := TWaveShape(WholeValue(LVoice.Find('shape'), 0, Ord(High(TWaveShape))));
    Result.Zones[I].Voice.OscillatorQuality := TOscillatorQuality(WholeValue(LVoice.Find('quality'), 0, Ord(High(TOscillatorQuality))));
    Result.Zones[I].Voice.Gain := NumericValue(LVoice.Find('gain'), 0, 1);
    Result.Zones[I].Voice.Pan := NumericValue(LVoice.Find('pan'), -1, 1);
    Result.Zones[I].Voice.CutoffHz := NumericValue(LVoice.Find('cutoff_hz'), 0.001, 192000);
    Result.Zones[I].Voice.FilterModel := TVoiceFilterModel(WholeValue(LVoice.Find('filter_model'), 0, Ord(High(TVoiceFilterModel))));
    Result.Zones[I].Voice.FilterKind := TFilterKind(WholeValue(LVoice.Find('filter_kind'), 0, Ord(High(TFilterKind))));
    Result.Zones[I].Voice.BiquadKind := TBiquadKind(WholeValue(LVoice.Find('biquad_kind'), 0, Ord(High(TBiquadKind))));
    Result.Zones[I].Voice.BiquadQ := NumericValue(LVoice.Find('q'), 0.001, 1000);
    Result.Zones[I].Voice.BiquadGainDb := NumericValue(LVoice.Find('gain_db'), -120, 120);
    LArray := ArrayValue(LVoice.Find('envelope'), 4, 4);
    Result.Zones[I].Voice.Envelope.AttackSeconds := NumericValue(LArray[0], 0, 30);
    Result.Zones[I].Voice.Envelope.DecaySeconds := NumericValue(LArray[1], 0, 30);
    Result.Zones[I].Voice.Envelope.SustainLevel := NumericValue(LArray[2], 0, 1);
    Result.Zones[I].Voice.Envelope.ReleaseSeconds := NumericValue(LArray[3], 0, 30);
    Result.Zones[I].Source := DecodeSource(LZone.Find('source'));
    LControls := ArrayValue(LZone.Find('controls'), 0, 5);
    SetLength(Result.Zones[I].Controls, LControls.Count);
    for J := 0 to High(Result.Zones[I].Controls) do
    begin
      LControl := ObjectValue(LControls[J], '|target|curve|', 2);
      Result.Zones[I].Controls[J].Target := TInstrumentControlTarget(WholeValue(LControl.Find('target'), 0, 4));
      Result.Zones[I].Controls[J].Curve := DecodeCurve(LControl.Find('curve'));
    end;
    Need((LZone.Find('gate') <> nil) and (LZone.Find('gate').JSONType = jtObject), 'Gate needs an object');
    LGate := LZone.Objects['gate'];
    Result.Zones[I].Gate.Enabled := BooleanValue(LGate.Find('enabled'));
    if Result.Zones[I].Gate.Enabled then
    begin
      ObjectValue(LGate, '|enabled|held|release|release_seconds|', 4);
      Result.Zones[I].Gate.Held := DecodeCurve(LGate.Find('held'));
      Result.Zones[I].Gate.ReleaseSeconds := NumericValue(LGate.Find('release_seconds'), 0, 30);
      Need(LGate.Find('release') <> nil, 'Gate release is missing');
      if LGate.Find('release').JSONType <> jtNull then
      begin
        Result.Zones[I].Gate.Release := DecodeCurve(LGate.Find('release'));
      end
      else
      begin
        Need(Result.Zones[I].Gate.ReleaseSeconds = 0, 'Positive gate release needs a curve');
      end;
    end
    else
    begin
      ObjectValue(LGate, '|enabled|', 1);
    end;
  end;
end;

function EncodeStudioMixRecipe(const AMix: TStemMixRecipe): TJSONObject;
var
  LParts: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create(['tail_seconds', AMix.TailSeconds,
    'bypass', AMix.BypassEffects, 'master', EncodeEffectRecipes(AMix.MasterEffects)]);
  LParts := TJSONArray.Create;
  Result.Add('parts', LParts);
  for I := 0 to High(AMix.Parts) do
  begin
    LParts.Add(TJSONObject.Create(['gain', AMix.Parts[I].Gain,
      'pan', AMix.Parts[I].Pan, 'bypass', AMix.Parts[I].BypassEffects,
      'effects', EncodeEffectRecipes(AMix.Parts[I].Effects)]));
  end;
end;

function DecodeStudioMixRecipe(const AValue: TJSONData;
  const ASampleRate: Integer): TStemMixRecipe;
var
  LObject: TJSONObject;
  LRow: TJSONObject;
  LParts: TJSONArray;
  I: Integer;
begin
  LObject := ObjectValue(AValue, '|tail_seconds|bypass|master|parts|', 4);
  Result := DefaultStemMixRecipe(6);
  Result.TailSeconds := NumericValue(LObject.Find('tail_seconds'), 0, 30);
  Result.BypassEffects := BooleanValue(LObject.Find('bypass'));
  Result.MasterEffects := DecodeEffectRecipes(LObject.Find('master'), MaximumEffects - 1, ASampleRate);
  LParts := ArrayValue(LObject.Find('parts'), 6, 6);
  for I := 0 to 5 do
  begin
    LRow := ObjectValue(LParts[I], '|gain|pan|bypass|effects|', 4);
    Result.Parts[I].Gain := NumericValue(LRow.Find('gain'), 0, 1);
    Result.Parts[I].Pan := NumericValue(LRow.Find('pan'), -1, 1);
    Result.Parts[I].BypassEffects := BooleanValue(LRow.Find('bypass'));
    Result.Parts[I].Effects := DecodeEffectRecipes(LRow.Find('effects'), MaximumEffects, ASampleRate);
  end;
  ValidateStemMixRecipe(Result, ASampleRate);
end;

function CanonicalStudioSoundDesign(const AValue: TJSONData;
  const ASampleRate: Integer): TJSONObject;
var
  LObject: TJSONObject;
  LRecipes: TJSONArray;
  LCanonical: TJSONArray;
  LRecipe: TInstrumentRecipe;
  I: Integer;
begin
  LObject := ObjectValue(AValue, '|version|instruments|mix|', 3);
  Need(WholeValue(LObject.Find('version'), 1, 1) = 1, 'Unsupported sound design version');
  LRecipes := ArrayValue(LObject.Find('instruments'), 3, 3);
  Result := TJSONObject.Create(['version', 1]);
  try
    LCanonical := TJSONArray.Create;
    Result.Add('instruments', LCanonical);
    for I := 0 to 2 do
    begin
      LRecipe := DecodeStudioInstrumentRecipe(LRecipes[I]);
      LCanonical.Add(EncodeStudioInstrumentRecipe(LRecipe));
    end;
    Result.Add('mix', EncodeStudioMixRecipe(DecodeStudioMixRecipe(LObject.Find('mix'), ASampleRate)));
  except
    Result.Free;
    raise;
  end;
end;

function StudioSoundCatalog: TJSONObject;
var
  LRecipes: TInstrumentRecipes;
  LRows: TJSONArray;
  I: Integer;
begin
  LRecipes := BuiltInInstrumentRecipes;
  Result := TJSONObject.Create(['format', 'pythian.studio.sound-catalog.v1',
    'maximum_zones', StudioSoundMaximumZones, 'sampler_connected', False,
    'maximum_partials', MaximumAdditivePartials,
    'maximum_tables', MaximumWavetableTrajectoryRecipes,
    'maximum_table_harmonics', MaximumTableHarmonics,
    'maximum_curve_points', MaximumAutomationPoints]);
  Result.Add('default_mix', EncodeStudioMixRecipe(DefaultStemMixRecipe(6)));
  LRows := TJSONArray.Create;
  Result.Add('instruments', LRows);
  try
    for I := 0 to High(LRecipes) do
    begin
      LRows.Add(EncodeStudioInstrumentRecipe(LRecipes[I]));
    end;
  except
    Result.Free;
    raise;
  end;
end;

function StudioSoundMix(const ASettings: TJSONObject;
  const ASampleRate: Integer): TStemMixRecipe;
begin
  if (ASettings <> nil) and (ASettings.Find('sound_design') <> nil) then
  begin
    Result := DecodeStudioMixRecipe(ASettings.Objects['sound_design'].Find('mix'), ASampleRate);
  end
  else
  begin
    Result := DefaultStemMixRecipe(6);
  end;
end;

function StudioSoundTailFrames(const ASettings: TJSONObject;
  const ASampleRate: Integer): Int64;
var
  LMix: TStemMixRecipe;
  LRecipe: TInstrumentRecipe;
  LFrames: Int64;
  I: Integer;
  J: Integer;
begin
  LMix := StudioSoundMix(ASettings, ASampleRate);
  Result := SampleFramesFromSeconds(LMix.TailSeconds, ASampleRate, frCeiling);
  if (ASettings = nil) or (ASettings.Find('sound_design') = nil) then
  begin
    Exit;
  end;
  for I := 0 to 2 do
  begin
    LRecipe := DecodeStudioInstrumentRecipe(ASettings.Objects['sound_design'].Arrays['instruments'][I]);
    for J := 0 to High(LRecipe.Zones) do
    begin
      if LRecipe.Zones[J].Gate.Enabled then
      begin
        LFrames := SampleFramesFromSeconds(LRecipe.Zones[J].Gate.ReleaseSeconds,
          ASampleRate, frFloor);
      end
      else
      begin
        LFrames := SampleFramesFromSeconds(LRecipe.Zones[J].Voice.Envelope.ReleaseSeconds,
          ASampleRate, frCeiling);
      end;
      if LFrames > Result then
      begin
        Result := LFrames;
      end;
    end;
  end;
end;

function StudioFollowupSoundSettings(const AParent, ARequest: TJSONObject;
  const ASampleRate: Integer): TJSONObject;
begin
  Need((AParent <> nil) and (ARequest <> nil), 'Sound changes need the saved settings');
  Result := TJSONObject(AParent.Clone);
  try
    if ARequest.Strings['kind'] = 'instrumental_reperform' then
    begin
      if Result.Find('sound_design') <> nil then
      begin
        Result.Delete('sound_design');
      end;
      if ARequest.Find('sound_design') <> nil then
      begin
        Result.Add('sound_design', CanonicalStudioSoundDesign(ARequest.Find('sound_design'), ASampleRate));
      end
      else
      begin
        ArrayValue(ARequest.Find('instruments'), 3, 3);
        Result.Delete('instruments');
        Result.Add('instruments', ARequest.Arrays['instruments'].Clone);
      end;
    end
    else
    begin
      Need(ARequest.Strings['kind'] = 'instrumental_regenerate', 'Unsupported sound follow-up');
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
