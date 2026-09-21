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
program pythian_tests_source;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.automation,
  pythian.wave,
  pythian.source,
  pythian.source.oscillator,
  pythian.source.sample,
  pythian.source.wavetable,
  pythian.oscillator,
  pythian.additive,
  pythian.synth;

type
  TGateFactory = class;
  TGateSource = class(TAudioSource)
  private
    FOwner: TGateFactory;
    FReads: Integer;
    FReleased: Boolean;
  public
    constructor Create(const AOwner: TGateFactory);
    destructor Destroy; override;
    procedure Reset; override;
    procedure NoteOff; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean; override;
  end;
  TGateFactory = class(TAudioSourceFactory)
  public
    NotifiedFrame: Integer;
    DestroyedSources: Integer;
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource; override;
    function Channels: Integer; override;
    function FrameCost(const ASampleRate: Integer): Integer; override;
  end;

constructor TGateSource.Create(const AOwner: TGateFactory);
begin
  inherited Create;
  FOwner := AOwner;
  Reset;
end;

destructor TGateSource.Destroy;
begin
  Inc(FOwner.DestroyedSources);
  inherited;
end;

procedure TGateSource.Reset;
begin
  FReads := 0;
  FReleased := False;
end;

procedure TGateSource.NoteOff;
begin
  if not FReleased then
  begin
    FOwner.NotifiedFrame := FReads;
    FReleased := True;
  end;
end;

function TGateSource.ReadFrame(const AFrequencyHz: Double;
  out ALeft, ARight: Double): Boolean;
begin
  Inc(FReads);
  ALeft := 0;
  ARight := 0;
  Result := True;
end;

function TGateFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  Result := TGateSource.Create(Self);
end;

function TGateFactory.Channels: Integer;
begin
  Result := 1;
end;

function TGateFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  Result := 1;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckWaveSources;
var
  LFactory: TAudioSourceFactory;
  LSource: TAudioSource;
  LOther: TAudioSource;
  LOscillator: TOscillator;
  LPartials: TAdditivePartials;
  LLeft: Double;
  LRight: Double;
  LOtherLeft: Double;
  LOtherRight: Double;
  LFrame: Integer;
begin
  LFactory := TWaveSourceFactory.Create(wsNoise, oqNaive);
  try
    LSource := LFactory.CreateSource(8000, 731);
    LOther := LFactory.CreateSource(8000, 731);
    LOscillator := TOscillator.Create(8000, 731);
    try
      for LFrame := 0 to 99 do
      begin
        Check(LSource.ReadFrame(440, LLeft, LRight), 'Wave source remains active');
        Check(LLeft = LOscillator.Next(wsNoise, 440), 'Precursor noise recurrence through source');
        LOther.ReadFrame(440, LOtherLeft, LOtherRight);
        Check((LLeft = LRight) and (LLeft = LOtherLeft), 'Independent seeded source replay');
      end;
      LSource.Reset;
      LOscillator.Reset;
      LSource.ReadFrame(440, LLeft, LRight);
      Check(LLeft = LOscillator.Next(wsNoise, 440), 'Source reset');
    finally
      LOscillator.Free;
      LOther.Free;
      LSource.Free;
    end;
  finally
    LFactory.Free;
  end;
  SetLength(LPartials, 1);
  LPartials[0].Ratio := 1;
  LPartials[0].Gain := 0.5;
  LPartials[0].PhaseCycles := 0.25;
  LFactory := TAdditiveSourceFactory.Create(LPartials);
  try
    LSource := LFactory.CreateSource(8000, 731);
    try
      LSource.ReadFrame(0, LLeft, LRight);
      Check(Abs(LLeft - 0.5) < 1E-12, 'Additive source adapter');
    finally
      LSource.Free;
    end;
  finally
    LFactory.Free;
  end;
  LFactory := TFmSourceFactory.Create(fsmPhase, 2, 0);
  try
    LSource := LFactory.CreateSource(8000, 731);
    try
      for LFrame := 0 to 31 do
      begin
        LSource.ReadFrame(1000, LLeft, LRight);
        Check(Abs(LLeft - Sin(2 * Pi * LFrame / 8)) < 1E-12, 'FM source zero-index carrier');
      end;
    finally
      LSource.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

procedure CheckSampleSources;
const
  CExpected: array[0..7] of Double = (0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.25);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LFactory: TSampleSourceFactory;
  LSource: TAudioSource;
  LLeft: Double;
  LRight: Double;
  LFrame: Integer;
  LRejected: Boolean;
begin
  SetLength(LSamples, 12);
  for LFrame := 0 to 5 do
  begin
    LSamples[2 * LFrame] := LFrame / 10;
    LSamples[2 * LFrame + 1] := -LSamples[2 * LFrame];
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LFactory := TSampleSourceFactory.Create(LClip, 1, 5, 440, spSustainLoop, sqLinear);
  finally
    LClip.Free;
  end;
  try
    LSource := LFactory.CreateSource(8000, 0);
    try
      for LFrame := 0 to 7 do
      begin
        Check(LSource.ReadFrame(220, LLeft, LRight), 'Loop remains active');
        Check(Abs(LLeft - CExpected[LFrame]) < 1E-7, 'Owned region and periodic interpolation');
        Check(LRight = -LLeft, 'Stereo source polarity');
      end;
      LSource.Reset;
      for LFrame := 0 to 4 do
      begin
        LSource.ReadFrame(440, LLeft, LRight);
      end;
      LSource.NoteOff;
      LSource.NoteOff;
      for LFrame := 2 to 4 do
      begin
        Check(LSource.ReadFrame(440, LLeft, LRight), 'Release completes traversal');
        Check(Abs(LLeft - LFrame / 10) < 1E-7, 'Release retains current loop position');
      end;
      Check(not LSource.ReadFrame(440, LLeft, LRight), 'Released loop ends');
      Check((LLeft = 0) and (LRight = 0), 'Exhaustion is explicit silence');
      LSource.Reset;
      LRejected := False;
      try
        LSource.ReadFrame(3900, LLeft, LRight);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Sample step bound rejects');
      LSource.ReadFrame(440, LLeft, LRight);
      Check(Abs(LLeft - 0.1) < 1E-7, 'Rejected pitch preserves position');
      LSource.Reset;
      { Step six wraps across more than one four-frame period. }
      LSource.ReadFrame(2640, LLeft, LRight);
      LSource.ReadFrame(2640, LLeft, LRight);
      Check(Abs(LLeft - 0.3) < 1E-7, 'Multi-wrap advancement');
    finally
      LSource.Free;
    end;
  finally
    LFactory.Free;
  end;

  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LFactory := TSampleSourceFactory.Create(LClip, 1, 5, 440, spOneShot, sqLinear);
  finally
    LClip.Free;
  end;
  try
    LSource := LFactory.CreateSource(16000, 0);
    try
      LSource.NoteOff;
      for LFrame := 0 to 7 do
      begin
        Check(LSource.ReadFrame(440, LLeft, LRight), 'One-shot rate conversion retains duration');
        if LFrame < 7 then
        begin
          Check(Abs(LLeft - CExpected[LFrame]) < 1E-7, 'Source/output sample-rate ratio');
        end
        else
        begin
          Check(Abs(LLeft - 0.4) < 1E-7, 'One-shot last interpolation clamps');
        end;
      end;
      Check(not LSource.ReadFrame(440, LLeft, LRight), 'One-shot exhausts naturally');
    finally
      LSource.Free;
    end;
  finally
    LFactory.Free;
  end;

  SetLength(LSamples, 32);
  for LFrame := 0 to 31 do
  begin
    LSamples[LFrame] := 0.5 * Sin(2 * Pi * LFrame / 32);
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LFactory := TSampleSourceFactory.Create(LClip, 0, 32, 250, spLoop, sqSinc, 2);
  finally
    LClip.Free;
  end;
  try
    LSource := LFactory.CreateSource(8000, 0);
    try
      for LFrame := 0 to 127 do
      begin
        LSource.ReadFrame(500, LLeft, LRight);
        Check(Abs(LLeft - 0.5 * Sin(2 * Pi * LFrame / 16)) < 1E-5,
          'Periodic sinc kernel across loop boundary');
      end;
      LSource.NoteOff;
      Check(LSource.ReadFrame(0, LLeft, LRight), 'Unconditional loop ignores note-off and can hold');
    finally
      LSource.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

procedure CheckWavetable;
const
  CFrames = 8192;
var
  LSine: array of Double;
  LCosine: array of Double;
  LFactory: TWavetableSourceFactory;
  LSource: TAudioSource;
  LLeft: Double;
  LRight: Double;
  LFrame: Integer;
  LExpected: Double;
  LAliasSin: Double;
  LAliasCos: Double;
  LAmplitude: Double;
begin
  SetLength(LSine, 3);
  SetLength(LCosine, 2);
  LSine[0] := 0.5;
  LSine[2] := 0.2;
  LCosine[1] := 0.1;
  LFactory := TWavetableSourceFactory.Create(LSine, LCosine);
  try
    LSine[0] := 100;
    LSource := LFactory.CreateSource(32768, 0);
    try
      for LFrame := 0 to 127 do
      begin
        LSource.ReadFrame(512, LLeft, LRight);
        LExpected := 0.5 * Sin(2 * Pi * LFrame / 64) +
          0.1 * Cos(4 * Pi * LFrame / 64) + 0.2 * Sin(6 * Pi * LFrame / 64);
        Check(Abs(LLeft - LExpected) < 1E-7, 'Owned coefficient table at exact phase grid');
      end;
      LSource.Reset;
      LAliasSin := 0;
      LAliasCos := 0;
      for LFrame := 0 to CFrames - 1 do
      begin
        LSource.ReadFrame(6000, LLeft, LRight);
        LExpected := 0.5 * Sin(2 * Pi * 6000 * LFrame / 32768) +
          0.1 * (16384 / 12000 - 1) * Cos(2 * Pi * 12000 * LFrame / 32768);
        Check(Abs(LLeft - LExpected) < 1E-7, 'Harmonic cap crossfade has independent analytic value');
        LAliasSin := LAliasSin + LLeft * Sin(2 * Pi * 14768 * LFrame / 32768);
        LAliasCos := LAliasCos + LLeft * Cos(2 * Pi * 14768 * LFrame / 32768);
      end;
      LAmplitude := 2 * Sqrt(Sqr(LAliasSin) + Sqr(LAliasCos)) / CFrames;
      WriteLn('Wavetable omitted third-harmonic alias amplitude=', LAmplitude:0:12);
      Check(LAmplitude < 1E-7, 'Wavetable suppresses selected out-of-band harmonic');
    finally
      LSource.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

procedure CheckCycleRecipe;
var
  LData: TAudioSamples;
  LClip: TAudioClip;
  LRecipe: TWavetableCycleRecipe;
  LOther: TWavetableCycleRecipe;
  LFactory: TWavetableSourceFactory;
  LSource: TAudioSource;
  LFrame: Integer;
  LCase: Integer;
  LLeft: Double;
  LRight: Double;
  LExpected: Double;
  LRejected: Boolean;
begin
  { Non-power-of-two period, offset, independent stereo, DC and signed phase. }
  SetLength(LData, 110 * 2);
  for LFrame := 0 to 109 do
  begin
    LData[2 * LFrame] := 0.75;
    LData[2 * LFrame + 1] := -0.9;
  end;
  for LFrame := 0 to 96 do
  begin
    LData[2 * (LFrame + 7) + 1] := 0.125 +
      0.5 * Sin(2 * Pi * LFrame / 97) - 0.2 * Cos(6 * Pi * LFrame / 97);
  end;
  LClip := TAudioClip.Create(16000, 2, LData);
  try
    if ParamCount >= 1 then
    begin
      SaveWavePcm16(ParamStr(1), LClip);
    end;
    LRecipe := AnalyzeWavetableCycle(LClip, 7, 97, 1, 5);
    Check(Abs(LRecipe.Mean - 0.125) < 1E-8, 'Cycle mean is measured separately');
    Check(Abs(LRecipe.Sine[0] - 0.5) < 1E-8, 'Cycle sine coefficient retains amplitude');
    Check(Abs(LRecipe.Cosine[2] + 0.2) < 1E-8, 'Cycle signed cosine retains phase');
    Check((Abs(LRecipe.Cosine[0]) < 1E-8) and (Abs(LRecipe.Sine[2]) < 1E-8),
      'Cycle analysis does not rotate phase');
    LOther := AnalyzeWavetableCycle(LClip, 7, 97, 0, 5);
    Check((LOther.Mean = 0.75) and (LOther.Sine[0] = 0) and (LOther.Cosine[0] = 0),
      'Explicit channel selection and constant cycle produce a silent recipe');
    LOther.Sine[0] := 4;
    Check(Abs(LRecipe.Sine[0] - 0.5) < 1E-8, 'Independent recipe ownership');
    for LCase := 0 to 4 do
    begin
      LRejected := False;
      try
        case LCase of
          0: LRecipe := AnalyzeWavetableCycle(LClip, 7, 97, 2, 5);
          1: LRecipe := AnalyzeWavetableCycle(LClip, High(Integer), 97, 1, 5);
          2: LRecipe := AnalyzeWavetableCycle(LClip, 7, 96, 1, 48);
          3: LRecipe := AnalyzeWavetableCycle(nil, 0, 97, 0, 5);
          4: LRecipe := AnalyzeWavetableCycle(LClip, 7, 8193, 1, 5);
        end;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (Length(LRecipe.Sine) = 5) and
        (Abs(LRecipe.Sine[0] - 0.5) < 1E-8), 'Invalid cycle preserves accepted recipe');
    end;
  finally
    LClip.Free;
  end;
  for LFrame := 0 to 96 do
  begin
    LData[2 * (LFrame + 7)] := 20 * Sin(2 * Pi * LFrame / 97);
  end;
  LClip := TAudioClip.Create(16000, 2, LData);
  try
    LRejected := False;
    try
      LRecipe := AnalyzeWavetableCycle(LClip, 7, 97, 0, 5);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Abs(LRecipe.Sine[0] - 0.5) < 1E-8),
      'Coefficient overflow after analysis preserves the accepted recipe');
  finally
    LClip.Free;
  end;
  LFactory := TWavetableSourceFactory.Create(LRecipe.Sine, LRecipe.Cosine);
  try
    LRecipe.Sine[0] := 7;
    LSource := LFactory.CreateSource(32768, 0);
    try
      for LFrame := 0 to 127 do
      begin
        LSource.ReadFrame(512, LLeft, LRight);
        LExpected := 0.5 * Sin(2 * Pi * LFrame / 64) - 0.2 * Cos(6 * Pi * LFrame / 64);
        Check((Abs(LLeft - LExpected) < 1E-7) and (LLeft = LRight),
          'Measured cycle renders at a new pitch after input release without DC');
      end;
    finally
      LSource.Free;
    end;
  finally
    LFactory.Free;
  end;
  WriteLn('Explicit PCM cycle: measured signed harmonics, DC separation, detached playback and bounds pass');
end;

procedure CheckMorph;
var
  LFrom: TWavetableCycleRecipe;
  LTo: TWavetableCycleRecipe;
  LPoints: TAutomationPoints;
  LCurve: TAutomationCurve;
  LFactory: TWavetableSourceFactory;
  LFromFactory: TWavetableSourceFactory;
  LToFactory: TWavetableSourceFactory;
  LSource: TAudioSource;
  LReplay: TAudioSource;
  LFromSource: TAudioSource;
  LToSource: TAudioSource;
  LFrame: Integer;
  LFrequency: Double;
  LWeight: Double;
  LLeft: Double;
  LRight: Double;
  LExpected: Double;
  LFirst: Double;
  LSecond: Double;
  LRejected: Boolean;
begin
  LFrom := Default(TWavetableCycleRecipe);
  LTo := Default(TWavetableCycleRecipe);
  SetLength(LFrom.Sine, 1);
  LFrom.Sine[0] := 0.7;
  SetLength(LTo.Cosine, 9);
  LTo.Cosine[0] := -0.3;
  LTo.Cosine[8] := 0.2;
  SetLength(LPoints, 3);
  LPoints[0].Value := 0;
  LPoints[0].Transition := atLinear;
  LPoints[1].Frame := 64;
  LPoints[1].Value := 1;
  LPoints[1].Transition := atLinear;
  LPoints[2].Frame := 128;
  LPoints[2].Value := 0;
  LCurve := TAutomationCurve.Create(LPoints);
  LFactory := nil;
  LFromFactory := nil;
  LToFactory := nil;
  try
    LFactory := TWavetableSourceFactory.CreateMorph(LFrom, LTo, LCurve);
    LFromFactory := TWavetableSourceFactory.Create(LFrom.Sine, LFrom.Cosine);
    LToFactory := TWavetableSourceFactory.Create(LTo.Sine, LTo.Cosine);
  finally
    LCurve.Free;
  end;
  try
    LFrom.Sine[0] := 16;
    LTo.Cosine := nil;
    LSource := LFactory.CreateSource(32768, 731);
    LReplay := LFactory.CreateSource(32768, 731);
    LFromSource := LFromFactory.CreateSource(32768, 731);
    LToSource := LToFactory.CreateSource(32768, 731);
    try
      for LFrame := 0 to 255 do
      begin
        if LFrame < 64 then
        begin
          LWeight := LFrame / 64;
        end
        else
        begin
          LWeight := Max(0, (128 - LFrame) / 64);
        end;
        { Different caps and changing pitch must retain a common phase. }
        LFrequency := 128 + (LFrame mod 7) * 2048;
        LFromSource.ReadFrame(LFrequency, LFirst, LRight);
        LToSource.ReadFrame(LFrequency, LSecond, LRight);
        LExpected := (1 - LWeight) * LFirst + LWeight * LSecond;
        if LFrame = 31 then
        begin
          LRejected := False;
          try
            LSource.ReadFrame(16384, LLeft, LRight);
          except
            on EAudio do
            begin
              LRejected := True;
            end;
          end;
          Check(LRejected, 'Morph rejects Nyquist before advancing phase or control');
          LSource.NoteOff;
          LSource.NoteOff;
        end;
        Check(LSource.ReadFrame(LFrequency, LLeft, LRight), 'Morph remains periodic');
        Check((Abs(LLeft - LExpected) < 1E-12) and (LLeft = LRight),
          'Morph matches independent capped sources and piecewise linear weights');
      end;
      LSource.Reset;
      for LFrame := 0 to 129 do
      begin
        LSource.ReadFrame(257, LLeft, LRight);
        LReplay.ReadFrame(257, LFirst, LSecond);
        Check((LLeft = LFirst) and (LRight = LSecond),
          'Morph reset restores phase and curve; new instances remain independent');
      end;
      Check(LFactory.FrameCost(32768) > LFromFactory.FrameCost(32768) +
        LToFactory.FrameCost(32768), 'Morph work budget includes both banks and control');
    finally
      LToSource.Free;
      LFromSource.Free;
      LReplay.Free;
      LSource.Free;
    end;
    LPoints[1].Value := 1.01;
    LCurve := TAutomationCurve.Create(LPoints);
    try
      LRejected := False;
      try
        LFactory := TWavetableSourceFactory.CreateMorph(LFrom, LTo, LCurve);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LFactory.Channels = 1), 'Invalid morph preserves accepted factory');
    finally
      LCurve.Free;
    end;
  finally
    LToFactory.Free;
    LFromFactory.Free;
    LFactory.Free;
  end;
end;

procedure CheckTrajectory;
var
  LRecipes: TWavetableCycleRecipes;
  LPoints: TAutomationPoints;
  LCurve: TAutomationCurve;
  LFactory: TWavetableSourceFactory;
  LSource: TAudioSource;
  LReplay: TAudioSource;
  LFrame: Integer;
  LIndex: Integer;
  LCase: Integer;
  LPosition: Double;
  LAngle: Double;
  LValues: array[0..2] of Double;
  LExpected: Double;
  LLeft: Double;
  LRight: Double;
  LOther: Double;
  LRejected: Boolean;
begin
  SetLength(LRecipes, 3);
  SetLength(LRecipes[0].Sine, 1);
  LRecipes[0].Sine[0] := 0.3;
  SetLength(LRecipes[1].Sine, 1);
  SetLength(LRecipes[1].Cosine, 2);
  LRecipes[1].Sine[0] := 0.1;
  LRecipes[1].Cosine[1] := 0.2;
  SetLength(LRecipes[2].Sine, 3);
  LRecipes[2].Sine[2] := -0.15;
  SetLength(LPoints, 5);
  LPoints[0].Transition := atLinear;
  LPoints[1].Frame := 64;
  LPoints[1].Value := 1;
  LPoints[1].Transition := atLinear;
  LPoints[2].Frame := 128;
  LPoints[2].Value := 2;
  LPoints[2].Transition := atHold;
  LPoints[3].Frame := 160;
  LPoints[3].Value := 0.5;
  LPoints[3].Transition := atLinear;
  LPoints[4].Frame := 224;
  LPoints[4].Value := 2;
  LCurve := TAutomationCurve.Create(LPoints);
  LFactory := nil;
  LSource := nil;
  LReplay := nil;
  try
    LFactory := TWavetableSourceFactory.CreateTrajectory(LRecipes, LCurve);
    FreeAndNil(LCurve);
    LRecipes[0].Sine[0] := 16;
    LRecipes[1].Cosine := nil;
    LSource := LFactory.CreateSource(32768, 1);
    LReplay := LFactory.CreateSource(32768, 2);
    for LFrame := 0 to 319 do
    begin
      if LFrame < 128 then
      begin
        LPosition := LFrame / 64;
      end
      else if LFrame < 160 then
      begin
        LPosition := 2;
      end
      else
      begin
        LPosition := Min(2, 0.5 + (LFrame - 160) * 1.5 / 64);
      end;
      LAngle := 2 * Pi * LFrame / 256;
      LValues[0] := 0.3 * Sin(LAngle);
      LValues[1] := 0.1 * Sin(LAngle) + 0.2 * Cos(2 * LAngle);
      LValues[2] := -0.15 * Sin(3 * LAngle);
      LIndex := Min(1, Trunc(LPosition));
      LPosition := LPosition - LIndex;
      LExpected := (1 - LPosition) * LValues[LIndex] + LPosition * LValues[LIndex + 1];
      if LFrame = 31 then
      begin
        LRejected := False;
        try
          LSource.ReadFrame(16384, LLeft, LRight);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected, 'Trajectory rejects invalid pitch before changing clocks');
      end;
      if LFrame = 95 then
      begin
        LSource.NoteOff;
      end;
      LSource.ReadFrame(128, LLeft, LRight);
      Check((Abs(LLeft - LExpected) < 1E-7) and (LLeft = LRight),
        'Detached trajectory follows analytic harmonics, knot joins and reverse jumps');
    end;
    LSource.Reset;
    for LFrame := 0 to 319 do
    begin
      LSource.ReadFrame(91 + LFrame, LLeft, LRight);
      LReplay.ReadFrame(91 + LFrame, LOther, LRight);
      Check(LLeft = LOther, 'Trajectory reset and independent voices replay under pitch motion');
    end;
    Check(LFactory.FrameCost(32768) = 15, 'Two active banks, index selection and point curve are reserved');
    for LCase := 0 to 3 do
    begin
      LRecipes := nil;
      SetLength(LRecipes, 3);
      for LIndex := 0 to High(LRecipes) do
      begin
        SetLength(LRecipes[LIndex].Sine, 1);
        LRecipes[LIndex].Sine[0] := 0.1;
      end;
      LPoints[4].Value := 2;
      case LCase of
        0: LPoints[4].Value := 2.01;
        1: SetLength(LRecipes, 33);
        2:
          begin
            SetLength(LRecipes, 32);
            for LIndex := 0 to High(LRecipes) do
            begin
              SetLength(LRecipes[LIndex].Sine, 128);
            end;
          end;
        3: LRecipes[2].Sine[0] := NaN;
      end;
      LCurve := TAutomationCurve.Create(LPoints);
      LRejected := False;
      try
        try
          LFactory := TWavetableSourceFactory.CreateTrajectory(LRecipes, LCurve, 8192);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and (LFactory.FrameCost(32768) = 15),
          'Invalid trajectory range/count/work/coefficient preserves accepted factory');
      finally
        FreeAndNil(LCurve);
      end;
    end;
  finally
    LReplay.Free;
    LSource.Free;
    LFactory.Free;
    LCurve.Free;
  end;
  WriteLn('Bounded spectral trajectory: analytic motion, ownership, replay and admission pass');
end;

procedure CheckMagnitudeTrajectory;
var
  LRecipes: TWavetableCycleRecipes;
  LShape: TWavetableMagnitudeShape;
  LPoints: TAutomationPoints;
  LCurve: TAutomationCurve;
  LFactory: TWavetableSourceFactory;
  LRawFactory: TWavetableSourceFactory;
  LSource: TAudioSource;
  LRaw: TAudioSource;
  LFrame: Integer;
  LIndex: Integer;
  LAngle: Double;
  LWeight: Double;
  LExpected: Double;
  LLeft: Double;
  LRight: Double;
  LPower: Double;
  LRawPower: Double;
  LRejected: Boolean;
begin
  SetLength(LRecipes, 3);
  SetLength(LRecipes[0].Sine, 2);
  SetLength(LRecipes[0].Cosine, 1);
  LRecipes[0].Sine[0] := 0.3;
  LRecipes[0].Cosine[0] := -0.4;
  LRecipes[0].Sine[1] := -0.5;
  LRecipes[0].Mean := 9;
  LShape := FactorWavetableMagnitudes(LRecipes[0]);
  Check((Abs(LShape.CycleRms - 0.5) < 1E-12) and
    (Abs(LShape.Recipe.Sine[0] - 1) < 1E-12) and
    (Abs(LShape.Recipe.Sine[1] - 1) < 1E-12) and
    (LShape.Recipe.Cosine[0] = 0) and (LShape.Recipe.Mean = 0),
    'Magnitude factor separates signed/phase/DC input from unit cycle RMS shape');
  LRecipes[0].Sine[0] := 0;
  Check(LShape.Recipe.Sine[0] > 0.99, 'Magnitude factor owns detached coefficients');
  for LIndex := 0 to 2 do
  begin
    LRecipes[LIndex] := Default(TWavetableCycleRecipe);
    SetLength(LRecipes[LIndex].Cosine, LIndex + 1);
    LRecipes[LIndex].Cosine[LIndex] := -0.1 * (LIndex + 1);
  end;
  { Tiny but representable input must not disappear through squared underflow. }
  LRecipes[0].Cosine[0] := 1E-200;
  LShape := FactorWavetableMagnitudes(LRecipes[0]);
  Check((LShape.CycleRms > 0) and (Abs(LShape.Recipe.Sine[0] - Sqrt(2)) < 1E-12),
    'Factoring scales tiny coefficients before power measurement');
  LRecipes[0].Cosine[0] := -0.1;
  SetLength(LPoints, 3);
  for LIndex := 0 to 2 do
  begin
    LPoints[LIndex].Frame := LIndex * 256;
    LPoints[LIndex].Value := LIndex;
    LPoints[LIndex].Transition := atLinear;
  end;
  LCurve := TAutomationCurve.Create(LPoints);
  LFactory := nil;
  LSource := nil;
  try
    LFactory := TWavetableSourceFactory.CreateMagnitudeTrajectory(LRecipes, LCurve, 0.2);
    Check(LFactory.FrameCost(32768) = 23, 'Magnitude trajectory reserves normalization work');
    LSource := LFactory.CreateSource(32768, 731);
    for LFrame := 0 to 767 do
    begin
      LIndex := Min(1, LFrame div 256);
      LWeight := Min(1, (LFrame - LIndex * 256) / 256);
      LAngle := 2 * Pi * LFrame / 256;
      LExpected := 0.2 * Sqrt(2) * ((1 - LWeight) * Sin((LIndex + 1) * LAngle) +
        LWeight * Sin((LIndex + 2) * LAngle)) / Sqrt(Sqr(1 - LWeight) + Sqr(LWeight));
      LSource.ReadFrame(128, LLeft, LRight);
      Check((Abs(LLeft - LExpected) < 1E-7) and (LLeft = LRight),
        'Magnitude motion matches independent normalized harmonic formula');
    end;
    LRecipes[2].Cosine[2] := 0;
    LRejected := False;
    try
      LFactory := TWavetableSourceFactory.CreateMagnitudeTrajectory(LRecipes, LCurve, 0.2);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LFactory.FrameCost(32768) = 23),
      'Silent shape rejects without replacing accepted factory');
    LRecipes[2].Cosine[2] := -0.3;
    LRejected := False;
    try
      LFactory := TWavetableSourceFactory.CreateMagnitudeTrajectory(LRecipes, LCurve, 0);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LFactory.FrameCost(32768) = 23), 'Zero target RMS rejects');
  finally
    LSource.Free;
    LFactory.Free;
    LCurve.Free;
  end;
  { Hold the midpoint for complete periods. Knot normalization alone dips by
    sqrt(1/2); pitch capping must still remove, rather than restore, upper energy. }
  SetLength(LRecipes, 2);
  LRecipes[1] := Default(TWavetableCycleRecipe);
  SetLength(LRecipes[1].Cosine, 3);
  LRecipes[1].Cosine[2] := 0.7;
  SetLength(LPoints, 1);
  LPoints[0].Value := 0.5;
  LCurve := TAutomationCurve.Create(LPoints);
  LFactory := nil;
  LRawFactory := nil;
  LSource := nil;
  LRaw := nil;
  try
    LFactory := TWavetableSourceFactory.CreateMagnitudeTrajectory(LRecipes, LCurve, 0.2);
    for LIndex := 0 to 1 do
    begin
      LShape := FactorWavetableMagnitudes(LRecipes[LIndex]);
      LRecipes[LIndex] := LShape.Recipe;
    end;
    LRawFactory := TWavetableSourceFactory.CreateTrajectory(LRecipes, LCurve);
    LSource := LFactory.CreateSource(32768, 0);
    LRaw := LRawFactory.CreateSource(32768, 0);
    LPower := 0;
    LRawPower := 0;
    for LFrame := 0 to 1023 do
    begin
      LSource.ReadFrame(128, LLeft, LRight);
      LPower := LPower + Sqr(LLeft);
      LRaw.ReadFrame(128, LLeft, LRight);
      LRawPower := LRawPower + Sqr(0.2 * LLeft);
    end;
    Check((Abs(Sqrt(LPower / 1024) - 0.2) < 1E-7) and
      (Abs(Sqrt(LRawPower / 1024) - 0.2 / Sqrt(2)) < 1E-7),
      'Continuous normalization removes the independently measured midpoint level dip');
    LSource.Reset;
    LPower := 0;
    for LFrame := 0 to 1023 do
    begin
      LSource.ReadFrame(8192, LLeft, LRight);
      LPower := LPower + Sqr(LLeft);
    end;
    Check(Abs(Sqrt(LPower / 1024) - 0.2 / Sqrt(2)) < 1E-7,
      'Pitch-cap attenuation remains; normalization never restores omitted high harmonics');
    FreeAndNil(LSource);
    FreeAndNil(LFactory);
    LRecipes[1] := Default(TWavetableCycleRecipe);
    SetLength(LRecipes[1].Cosine, 2);
    LRecipes[1].Cosine[0] := 3;
    LRecipes[1].Cosine[1] := 4;
    LFactory := TWavetableSourceFactory.CreateMagnitudeTrajectory(LRecipes, LCurve, 0.2);
    LSource := LFactory.CreateSource(32768, 0);
    for LFrame := 0 to 511 do
    begin
      LAngle := 2 * Pi * LFrame / 256;
      LExpected := 0.2 * Sqrt(2) * (0.8 * Sin(LAngle) + 0.4 * Sin(2 * LAngle)) / Sqrt(0.8);
      LSource.ReadFrame(128, LLeft, LRight);
      Check(Abs(LLeft - LExpected) < 1E-7,
        'Shared partials retain their cross term during shape normalization');
    end;
  finally
    LRaw.Free;
    LSource.Free;
    LRawFactory.Free;
    LFactory.Free;
    LCurve.Free;
  end;
  WriteLn('Magnitude trajectory: detached factors, analytic motion, level independence and bandwidth pass');
end;

procedure CheckRenderer;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LFactory: TSampleSourceFactory;
  LTones: TFrameTones;
  LOutput: TAudioClip;
  LReplay: TAudioClip;
  LOriginalFrames: Integer;
  LFrame: Integer;
  LRejected: Boolean;
begin
  SetLength(LSamples, 8);
  for LFrame := 0 to 3 do
  begin
    LSamples[2 * LFrame] := 0.2;
    LSamples[2 * LFrame + 1] := -0.2;
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LFactory := TSampleSourceFactory.Create(LClip, 0, 4, 440, spSustainLoop, sqLinear);
  finally
    LClip.Free;
  end;
  try
    SetLength(LTones, 2);
    for LFrame := 0 to 1 do
    begin
      LTones[LFrame].StartFrame := LFrame * 100;
      LTones[LFrame].GateFrames := 5;
      LTones[LFrame].FrequencyHz := 440;
      LTones[LFrame].Velocity := 1;
      LTones[LFrame].Voice := DefaultSynthVoice;
      LTones[LFrame].Voice.SourceFactory := LFactory;
      LTones[LFrame].Voice.Envelope.AttackSeconds := 0;
      LTones[LFrame].Voice.Envelope.DecaySeconds := 0;
      LTones[LFrame].Voice.Envelope.SustainLevel := 1;
      LTones[LFrame].Voice.Envelope.ReleaseSeconds := 0.005;
    end;
    LOutput := RenderFrameTones(LTones, 8000);
    try
      LOriginalFrames := LOutput.FrameCount;
      for LFrame := 0 to 44 do
      begin
        Check(Abs(LOutput.SampleAt(LFrame, 0) + LOutput.SampleAt(LFrame, 1)) < 1E-7,
          'Renderer retains stereo anti-phase and independent filter history');
        Check(LOutput.SampleAt(LFrame, 0) = LOutput.SampleAt(100 + LFrame, 0),
          'Factory creates independent note state');
      end;
      Check(Abs(LOutput.SampleAt(30, 0)) < 1E-10, 'Note-off ends sustain-loop source before envelope tail');
      LReplay := RenderFrameTones(LTones, 8000);
      try
        for LFrame := 0 to LOutput.FrameCount - 1 do
        begin
          Check(LOutput.SampleAt(LFrame, 0) = LReplay.SampleAt(LFrame, 0), 'Source renderer replay');
        end;
      finally
        LReplay.Free;
      end;
      LTones[0].GateFrames := 30000000;
      LRejected := False;
      try
        LOutput := RenderFrameTones(LTones, 8000);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LOutput.FrameCount = LOriginalFrames),
        'Source work preflight preserves output');
    finally
      LOutput.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

procedure CheckHarmonicFit;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LFit: THarmonicFit;
  LReduced: THarmonicFit;
  LFactory: TWavetableSourceFactory;
  LSource: TAudioSource;
  LFrame: Integer;
  LAngle: Double;
  LLeft: Double;
  LRight: Double;
  LExpected: Double;
  LRejected: Boolean;
begin
  SetLength(LSamples, 2000 * 2);
  for LFrame := 0 to 1999 do
  begin
    LAngle := 2 * Pi * 213.7 * (LFrame - 7) / 8000;
    LSamples[2 * LFrame] := 0.6 * Sin(2 * Pi * 701 * LFrame / 8000);
    LSamples[2 * LFrame + 1] := 0.13 + 0.42 * Sin(LAngle) +
      0.17 * Cos(2 * LAngle) - 0.09 * Sin(5 * LAngle);
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LFit := FitWavetableHarmonics(LClip, 7, 1499, 1, 5, 213.7);
    Check((Abs(LFit.Recipe.Mean - 0.13) < 1E-7) and
      (Abs(LFit.Recipe.Sine[0] - 0.42) < 1E-7) and
      (Abs(LFit.Recipe.Cosine[1] - 0.17) < 1E-7) and
      (Abs(LFit.Recipe.Sine[4] + 0.09) < 1E-7) and
      (Abs(LFit.Recipe.Cosine[0]) < 1E-7) and (LFit.RelativeError < 1E-6),
      'Joint harmonic fit recovers noninteger-period coefficients, phase and DC');
    LReduced := FitWavetableHarmonics(LClip, 7, 1499, 1, 1, 213.7);
    Check(LReduced.RelativeError > 0.4, 'Omitted measured partials appear in residual');
    LReduced := FitWavetableHarmonics(LClip, 7, 1499, 1, 5, 220);
    Check(LReduced.RelativeError > 0.8, 'Wrong frequency is exposed by measured residual');
    LRejected := False;
    try
      LFit := FitWavetableHarmonics(LClip, 7, 1499, 1, 5, 800);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Abs(LFit.Recipe.Sine[0] - 0.42) < 1E-7),
      'Source Nyquist rejection preserves accepted harmonic recipe');
    LRejected := False;
    try
      LReduced := FitWavetableHarmonics(LClip, 7, 1499, 1, 1, 3999.999999999);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Near-Nyquist rank-deficient sinusoid rejects');
    if ParamCount > 1 then
    begin
      SaveWavePcm16(ParamStr(2), LClip);
    end;
  finally
    LClip.Free;
  end;
  LFactory := TWavetableSourceFactory.Create(LFit.Recipe.Sine, LFit.Recipe.Cosine);
  try
    LFit.Recipe.Sine[0] := 10;
    LSource := LFactory.CreateSource(48000, 731);
    try
      for LFrame := 0 to 499 do
      begin
        LAngle := 2 * Pi * 330 * LFrame / 48000;
        LExpected := 0.42 * Sin(LAngle) + 0.17 * Cos(2 * LAngle) -
          0.09 * Sin(5 * LAngle);
        LSource.ReadFrame(330, LLeft, LRight);
        Check((Abs(LLeft - LExpected) < 1E-5) and (LLeft = LRight),
          'Detached fitted waveform transposes through the native source factory');
      end;
    finally
      LSource.Free;
    end;
  finally
    LFactory.Free;
  end;
  SetLength(LSamples, 65536);
  for LFrame := 0 to High(LSamples) do
  begin
    LSamples[LFrame] := 0.25;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LFit := FitWavetableHarmonics(LClip, 0, 1000, 0, 3, 213.7);
    Check((LFit.AcRms = 0) and (LFit.RelativeError = 0) and
      (LFit.ResidualRms < 1E-12), 'Constant input explicitly retains zero AC evidence');
    LRejected := False;
    try
      LReduced := FitWavetableHarmonics(LClip, 0, 65536, 0, 128, 20);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Harmonic fit preflights total QR work');
  finally
    LClip.Free;
  end;
  WriteLn('Harmonic fitting: fractional periods, independent residual, rank/work limits and transposed source passed');
end;

procedure CheckPhaseHarmonicFit;
const
  CRate = 8000;
  CFrames = 6400;
var
  LSamples: TAudioSamples;
  LRendered: TAudioSamples;
  LPhases: array of Double;
  LClip: TAudioClip;
  LOutput: TAudioClip;
  LFactory: TWavetableSourceFactory;
  LSource: TAudioSource;
  LFit: THarmonicPhaseFit;
  LRepeated: THarmonicPhaseFit;
  LFixed: THarmonicFit;
  LCase: Integer;
  LFrame: Integer;
  LBad: Integer;
  LTime: Double;
  LCycles: Double;
  LScale: Double;
  LLeft: Double;
  LRight: Double;
  LFrequency: Double;
  LExpected: Double;
  LOriginalPhase: Double;
  LRejected: Boolean;
begin
  SetLength(LPhases, CFrames);
  SetLength(LSamples, (CFrames + 7) * 2);
  SetLength(LRendered, CFrames);
  for LCase := 0 to 3 do
  begin
    LScale := 1;
    if LCase = 3 then
    begin
      LScale := 0.001;
    end;
    for LFrame := 0 to CFrames - 1 do
    begin
      LTime := LFrame / CRate;
      if LCase = 0 then
      begin
        LCycles := 220 * LTime;
      end
      else if LCase = 1 then
      begin
        LCycles := 180 * LTime + 100 * Sqr(LTime);
      end
      else
      begin
        LCycles := 220 * LTime + 5 / (2 * Pi * 5) * (1 - Cos(2 * Pi * 5 * LTime));
      end;
      LPhases[LFrame] := LCycles;
      LSamples[(LFrame + 7) * 2] := 0.6 * Sin(2 * Pi * 701 * LTime);
      LSamples[(LFrame + 7) * 2 + 1] := 0.13 + LScale * (0.1 * Sin(2 * Pi * LCycles) +
        0.3 * Sin(4 * Pi * LCycles) + 0.08 * Cos(6 * Pi * LCycles));
    end;
    LClip := TAudioClip.Create(CRate, 2, LSamples);
    LFactory := nil;
    LSource := nil;
    LOutput := nil;
    try
      LFit := FitWavetableHarmonicsByPhase(LClip, 7, 1, 4, LPhases);
      Check((Abs(LFit.Recipe.Mean - 0.13) < 1E-7) and
        (Abs(LFit.Recipe.Sine[0] - 0.1 * LScale) < 1E-7) and
        (Abs(LFit.Recipe.Sine[1] - 0.3 * LScale) < 1E-7) and
        (Abs(LFit.Recipe.Cosine[2] - 0.08 * LScale) < 1E-7) and
        (Abs(LFit.Recipe.Sine[3]) < 1E-7) and (LFit.RelativeError < 1E-4),
        'Phase path recovers weak fundamental, harmonic coefficients and DC');
      Check((LFit.MinimumHz > 0) and (LFit.MaximumHz < CRate / 8),
        'Phase fit reports sampled frequency bounds');
      LFixed := FitWavetableHarmonics(LClip, 7, CFrames, 1, 4, 220);
      if LCase = 0 then
      begin
        Check((Abs(LFit.MinimumHz - 220) < 1E-7) and
          (Abs(LFit.MaximumHz - 220) < 1E-7) and
          (Abs(LFit.Recipe.Sine[0] - LFixed.Recipe.Sine[0]) < 1E-10) and
          (Abs(LFit.ResidualRms - LFixed.ResidualRms) < 1E-10),
          'Constant phase path agrees with the original fixed-frequency fit');
      end
      else
      begin
        Check(LFixed.RelativeError > 0.1, 'Fixed-frequency residual exposes declared pitch motion');
      end;
      LRepeated := FitWavetableHarmonicsByPhase(LClip, 7, 1, 4, LPhases);
      LFit.Recipe.Sine[0] := 16;
      Check(Abs(LRepeated.Recipe.Sine[0] - 0.1 * LScale) < 1E-7,
        'Separate phase fits own detached recipe arrays');
      LFit := LRepeated;
      LFactory := TWavetableSourceFactory.Create(LFit.Recipe.Sine, LFit.Recipe.Cosine);
      LSource := LFactory.CreateSource(CRate, 731);
      for LFrame := 0 to CFrames - 1 do
      begin
        if LFrame < CFrames - 1 then
        begin
          LFrequency := (LPhases[LFrame + 1] - LPhases[LFrame]) * CRate;
        end;
        LSource.ReadFrame(LFrequency, LLeft, LRight);
        LExpected := LSamples[(LFrame + 7) * 2 + 1] - 0.13;
        Check((Abs(LLeft - LExpected) < 1E-5) and (LLeft = LRight),
          'Recovered recipe follows changing pitch through the native source');
        LRendered[LFrame] := LLeft;
      end;
      if ParamCount > 2 then
      begin
        LOutput := TAudioClip.Create(CRate, 1, LRendered);
        SaveWavePcm16(ParamStr(3) + '-' + IntToStr(LCase) + '.wav', LOutput);
      end;
      if LCase = 1 then
      begin
        Check((LFit.MinimumHz > 180) and (LFit.MinimumHz < 181) and
          (LFit.MaximumHz > 339) and (LFit.MaximumHz < 340), 'Linear chirp interval frequencies');
        for LBad := 0 to 6 do
        begin
          LOriginalPhase := LPhases[20];
          case LBad of
            0: LPhases[0] := 0.1;
            1: LPhases[20] := LPhases[19];
            2: LPhases[20] := LPhases[19] - 0.001;
            3: LPhases[20] := LPhases[19] + 0.125;
            4: LPhases[20] := NaN;
            5: LPhases[20] := Infinity;
            6: LPhases[20] := 1E300;
          end;
          LRejected := False;
          try
            LFit := FitWavetableHarmonicsByPhase(LClip, 7, 1, 4, LPhases);
          except
            on EAudio do
            begin
              LRejected := True;
            end;
          end;
          Check(LRejected and (Abs(LFit.Recipe.Sine[0] - 0.1) < 1E-7),
            'Invalid phase origin, order, sampling or finite value preserves fit');
          LPhases[0] := 0;
          LPhases[20] := LOriginalPhase;
        end;
      end;
      WriteLn('Phase fit case=', LCase, ' relative_error=', LFit.RelativeError:0:9,
        ' fixed_frequency_error=', LFixed.RelativeError:0:6,
        ' sampled_hz=', LFit.MinimumHz:0:4, '..', LFit.MaximumHz:0:4);
    finally
      LOutput.Free;
      LSource.Free;
      LFactory.Free;
      LClip.Free;
    end;
  end;
  SetLength(LPhases, 16);
  for LFrame := 0 to High(LPhases) do
  begin
    LPhases[LFrame] := LFrame * 0.01;
  end;
  LRejected := False;
  try
    PhaseHarmonicFitWork(LPhases, CRate, 1);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Insufficient declared cycles reject');
  SetLength(LSamples, 16);
  for LFrame := 0 to 15 do
  begin
    LPhases[LFrame] := LFrame * 4.0 / 15;
    LSamples[LFrame] := 0.25;
  end;
  LClip := TAudioClip.Create(CRate, 1, LSamples);
  try
    LFit := FitWavetableHarmonicsByPhase(LClip, 0, 0, 1, LPhases);
    Check((LFit.AcRms = 0) and (LFit.RelativeError = 0) and
      (LFit.ResidualRms < 1E-12), 'Four-cycle boundary and constant input retain zero AC evidence');
    for LBad := 0 to 3 do
    begin
      LRejected := False;
      try
        case LBad of
          0: LFit := FitWavetableHarmonicsByPhase(nil, 0, 0, 1, LPhases);
          1: LFit := FitWavetableHarmonicsByPhase(LClip, 1, 0, 1, LPhases);
          2: LFit := FitWavetableHarmonicsByPhase(LClip, 0, 1, 1, LPhases);
          3:
            begin
              for LFrame := 0 to 15 do
              begin
                LPhases[LFrame] := LFrame * (0.5 - 1E-14);
              end;
              LFit := FitWavetableHarmonicsByPhase(LClip, 0, 0, 1, LPhases);
            end;
        end;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (Abs(LFit.Recipe.Mean - 0.25) < 1E-12),
        'Nil input, bad source bounds/channel and deficient phase rank preserve accepted fit');
    end;
  finally
    LClip.Free;
  end;
  SetLength(LPhases, MaximumHarmonicFitFrames);
  LRejected := False;
  try
    PhaseHarmonicFitWork(LPhases, CRate, MaximumTableHarmonics);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Phase-fit QR work is preflight bounded');
end;

procedure CheckGateDelivery;
var
  LFactory: TGateFactory;
  LTones: TFrameTones;
  LClip: TAudioClip;
begin
  LFactory := TGateFactory.Create;
  try
    SetLength(LTones, 1);
    LTones[0].Voice := DefaultSynthVoice;
    LTones[0].Voice.SourceFactory := LFactory;
    LTones[0].StartFrame := 7;
    LTones[0].GateFrames := 3;
    LTones[0].FrequencyHz := 440;
    LTones[0].Velocity := 1;
    LClip := RenderFrameTones(LTones, 8000);
    LClip.Free;
    Check(LFactory.NotifiedFrame = 3, 'Exact source note-off before first release frame');
    Check(LFactory.DestroyedSources = 1, 'Renderer owns source lifetime and borrows factory');
  finally
    LFactory.Free;
  end;
end;

begin
  try
    CheckWaveSources;
    CheckSampleSources;
    CheckWavetable;
    CheckCycleRecipe;
    CheckMorph;
    CheckTrajectory;
    CheckMagnitudeTrajectory;
    CheckHarmonicFit;
    CheckPhaseHarmonicFit;
    CheckRenderer;
    CheckGateDelivery;
    WriteLn('Source factories, sample loops, wavetable and shared renderer checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
