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
program pythian_tests_wfc_context;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.time,
  pythian.tonal,
  pythian.music.context,
  pythian.wfc.context,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_sequence_text;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckFiniteKey;
var
  LKeys: TKeyChanges;
  LRejected: Boolean;
begin
  LKeys := KeyChangesFromTokens([KeyContextToken(MakeKeyContext(0, dmMajor)),
    KeyContextToken(MakeKeyContext(-1, dmMajor)),
    KeyContextToken(MakeKeyContext(2, dmNaturalMinor))], 240, 500);
  Check((Length(LKeys) = 3) and (LKeys[0].Tick = 0) and (LKeys[0].Key.Root = 0) and
    (LKeys[1].Tick = 240) and (LKeys[1].Key.Root = -1) and
    (LKeys[2].Tick = 480) and (LKeys[2].Key.Mode = dmNaturalMinor),
    'Independent key provider retains exact changes and unknown values');
  LRejected := False;
  try
    LKeys := KeyChangesFromTokens([KeyContextToken(MakeKeyContext(0, dmMajor))], 240, 241);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (Length(LKeys) = 3), 'Uncovered key scope preserves accepted changes');
  LRejected := False;
  try
    KeyChangesFromTokens([KeyContextToken(MakeKeyContext(0, dmMajor)), 'invalid'], 240, 100);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Unused key tokens remain canonical');
  WriteLn('Finite key scope, explicit unknowns and canonical unused tokens pass');
end;

procedure CheckFiniteTempo;
var
  LClock: TTempoMap;
  LCandidate: TTempoMap;
  LRejected: Boolean;
begin
  LClock := TempoClockFromTokens([TempoContextToken(500000), TempoContextToken(750000),
    TempoContextToken(500000)], 480, 240, 300);
  LCandidate := nil;
  try
    Check((LClock.LengthTicks = 300) and (LClock.ChangeCount = 2) and
      (LClock.ChangeAt(1).Tick = 240) and (LClock.FrameAtTick(300, 8000) = 2750),
      'Tempo provider keeps its independent grid and exact partial-cell endpoint');
    LRejected := False;
    try
      LCandidate := TempoClockFromTokens([TempoContextToken(500000)], 480, 240, 300);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'Finite tempo provider cannot extrapolate its tail');
    LRejected := False;
    try
      LCandidate := TempoClockFromTokens([TempoContextToken(500000), 'invalid'], 480, 240, 100);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil) and (LClock.FrameAtTick(300, 8000) = 2750),
      'Unused provider cells still validate and rejection preserves accepted clock');
    WriteLn('Finite tempo provider coverage, partial endpoints and canonical tokens pass');
  finally
    LCandidate.Free;
    LClock.Free;
  end;
end;

procedure Run;
var
  LGrids: TMusicContextGrids;
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LManual: TWfcSequenceModel;
  LContext: TMusicContext;
  LClock: TTempoMap;
  LRejected: Boolean;
  LDimension: TContextDimension;
  LOrder: Integer;
  I: Integer;
  J: Integer;
begin
  SetLength(LGrids, 2);
  for I := 0 to 1 do
  begin
    LGrids[I].TicksPerQuarter := 480;
    LGrids[I].StartTick := I * 960;
    LGrids[I].StepTicks := 240;
    SetLength(LGrids[I].Keys, 4);
    SetLength(LGrids[I].Tempos, 4);
    for J := 0 to 3 do
    begin
      LGrids[I].Keys[J] := MakeKeyContext(I * 2, TDiatonicMode(I));
      LGrids[I].Tempos[J] := 500001 + I * 100000;
    end;
  end;
  SetLength(LSamples, 2);
  for LDimension := cdKey to cdTempo do
  begin
    if LDimension = cdKey then
    begin
      LSamples[0] := MakeWfcSequenceSample(['pythian.context.key.v1.0',
        'pythian.context.key.v1.0', 'pythian.context.key.v1.0', 'pythian.context.key.v1.0']);
      LSamples[1] := MakeWfcSequenceSample(['pythian.context.key.v1.5',
        'pythian.context.key.v1.5', 'pythian.context.key.v1.5', 'pythian.context.key.v1.5']);
    end
    else
    begin
      LSamples[0] := MakeWfcSequenceSample(['pythian.context.tempo.v1.500001',
        'pythian.context.tempo.v1.500001', 'pythian.context.tempo.v1.500001',
        'pythian.context.tempo.v1.500001']);
      LSamples[1] := MakeWfcSequenceSample(['pythian.context.tempo.v1.600001',
        'pythian.context.tempo.v1.600001', 'pythian.context.tempo.v1.600001',
        'pythian.context.tempo.v1.600001']);
    end;
    for LOrder := 1 to 4 do
    begin
      LModel := LearnContextModel(LGrids, LDimension, LOrder);
      LManual := nil;
      try
        LManual := LearnSequenceModelCorpus(LSamples, LOrder, wmbOpen);
        Check(EncodeWfcSequenceText(LModel) = EncodeWfcSequenceText(LManual),
          'Separate source samples retain exact independent WFC model semantics');
      finally
        LManual.Free;
        LModel.Free;
      end;
    end;
  end;
  LContext := MusicContextFromTokens(
    ['pythian.context.key.v1.unknown', 'pythian.context.key.v1.0', 'pythian.context.key.v1.5'],
    ['pythian.context.tempo.v1.500001', 'pythian.context.tempo.v1.600001',
     'pythian.context.tempo.v1.600001'], 480, 240);
  LClock := nil;
  try
    LClock := LContext.CopyClock;
    Check((LContext.KeyAtTick(0).Root = -1) and (LContext.KeyAtTick(240).Root = 0) and
      (LContext.KeyAtTick(480).Mode = dmNaturalMinor) and (LClock.ChangeCount = 2),
      'Generated providers reconstruct unknown/key changes and coalesced tempos');
    Check(LClock.FrameAtTick(720, 44100) = 37485,
      'Generated tempo uses fractional PPQ clock, not rounded BPM');
  finally
    LClock.Free;
    LContext.Free;
  end;
  LRejected := False;
  try
    TempoContextFromToken('pythian.context.tempo.v1.0500001');
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Noncanonical numeric tokens reject');
  LGrids[1].StepTicks := 480;
  LRejected := False;
  try
    LModel := LearnContextModel(LGrids, cdKey);
    LModel.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Different beat resolutions require explicit normalization');
  WriteLn('Key/tempo corpus models, orders 1..4, source separation and exact output clock passed');
end;

procedure RunHeld;
var
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LText: String;
  LRejected: Boolean;
begin
  SetLength(LSamples, 1);
  LSamples[0] := MakeWfcSequenceSample(['pythian.context.key.v1.unknown',
    'pythian.context.key.v1.unknown']);
  LModel := LearnSequenceModelCorpus(LSamples, 3, wmbOpen);
  try
    LText := EncodeWfcSequenceText(LModel);
    Check(HeldContextToken(LModel, cdKey) = 'pythian.context.key.v1.unknown',
      'Holding an unknown key never manufactures tonal knowledge');
    Check(EncodeWfcSequenceText(LModel) = LText, 'Holding leaves saved observations/model untouched');
  finally
    LModel.Free;
  end;
  LSamples[0] := MakeWfcSequenceSample(['pythian.context.tempo.v1.500000',
    'pythian.context.tempo.v1.750000']);
  LModel := LearnSequenceModelCorpus(LSamples, 3, wmbOpen);
  try
    LRejected := False;
    try
      HeldContextToken(LModel, cdTempo);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Holding rejects explicit tempo changes instead of flattening them');
  finally
    LModel.Free;
  end;
  LSamples[0] := MakeWfcSequenceSample(['pythian.context.tempo.v1.500000']);
  LModel := LearnSequenceModelCorpus(LSamples, 3, wmbOpen);
  try
    Check(TempoContextFromToken(HeldContextToken(LModel, cdTempo)) = 500000,
      'A single declared tempo can hold without repeated observations');
  finally
    LModel.Free;
  end;
  WriteLn('Explicit held context preserves unknowns, original observations and changing-context rejection');
end;

begin
  try
    CheckFiniteKey;
    CheckFiniteTempo;
    Run;
    RunHeld;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
