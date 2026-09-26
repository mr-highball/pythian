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
program pythian_tests_wfc_layers;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.oscillator,
  pythian.audio,
  pythian.synth,
  pythian.wave,
  pythian.wfc.layers,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_sequence_text,
  wfc_sequence_graph;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Learn(const AFirst, ASecond: TWfcModelTokens; const AOrder: Integer): TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
begin
  SetLength(LSamples, 2);
  LSamples[0] := MakeWfcSequenceSample(AFirst);
  LSamples[1] := MakeWfcSequenceSample(ASecond);
  Result := LearnSequenceModelCorpus(LSamples, AOrder);
end;

procedure SetLock(var ALayer: TLearnedLayer; const AToken: String);
begin
  SetLength(ALayer.Constraints, 1);
  ALayer.Constraints[0] := MakeWfcSequenceTokenConstraint(0, [AToken]);
end;

procedure CheckSameLayer(const AFirst, ASecond: TLayerSequences; const ALayer: Integer);
var
  LCell: Integer;
begin
  Check(Length(AFirst[ALayer].Tokens) = Length(ASecond[ALayer].Tokens), 'Preserved cell count');
  for LCell := 0 to High(AFirst[ALayer].Tokens) do
  begin
    Check(AFirst[ALayer].Tokens[LCell] = ASecond[ALayer].Tokens[LCell], 'Preserved accepted token');
    Check(AFirst[ALayer].StateIndices[LCell] = ASecond[ALayer].StateIndices[LCell],
      'Preserved accepted latent state');
  end;
end;

function RenderReplacementControl(const ASequences: TLayerSequences;
  const AKeyOnly: Boolean): TAudioClip;
var
  LTones: TFrameTones;
  LCell: Integer;
  LTone: Integer;
begin
  SetLength(LTones, 1);
  LTones[0].StartFrame := 0;
  LTones[0].GateFrames := 30400;
  LTones[0].FrequencyHz := 130.812783;
  if ASequences[0].Tokens[0] = 'F' then
  begin
    LTones[0].FrequencyHz := 174.614116;
  end;
  LTones[0].Velocity := 0.7;
  LTones[0].Voice := DefaultSynthVoice;
  LTones[0].Voice.Gain := 0.2;
  LTones[0].Voice.Pan := -0.5;
  if not AKeyOnly then
  begin
    for LCell := 0 to High(ASequences[2].Tokens) do
    begin
      if ASequences[2].Tokens[LCell] <> 'on' then
      begin
        Continue;
      end;
      LTone := Length(LTones);
      SetLength(LTones, LTone + 1);
      LTones[LTone].StartFrame := Int64(LCell) * 8000;
      LTones[LTone].GateFrames := 6000;
      LTones[LTone].FrequencyHz := LTones[0].FrequencyHz * 4;
      LTones[LTone].Velocity := 0.7;
      LTones[LTone].Voice := DefaultSynthVoice;
      LTones[LTone].Voice.Gain := 0.2;
      LTones[LTone].Voice.Pan := 0.5;
    end;
  end;
  Result := RenderFrameTones(LTones, 16000, 32000);
end;

function RenderMappedControl(const ASequences: TLayerSequences;
  const ARhythmOnly: Boolean; const APartitioned: Boolean = False): TAudioClip;
const
  VoiceTicks: array[0..8] of Integer = (0, 120, 360, 720, 960, 1200, 1560, 1800, 1920);
  RhythmTicks: array[0..4] of Integer = (0, 360, 960, 1560, 1920);
var
  LTones: TFrameTones;
  LLayer: Integer;
  LCell: Integer;
  LTone: Integer;
  LFramesPerCell: Integer;
begin
  LTones := nil;
  LLayer := 3;
  LFramesPerCell := 4000; { 240 ticks at declared 480 PPQ / 120 BPM / 16 kHz. }
  if ARhythmOnly then
  begin
    LLayer := 1;
    LFramesPerCell := 8000;
  end;
  for LCell := 0 to High(ASequences[LLayer].Tokens) do
  begin
    if (ASequences[LLayer].Tokens[LCell] = 'rest') or
      (ASequences[LLayer].Tokens[LCell] = 'off') then
    begin
      Continue;
    end;
    LTone := Length(LTones);
    SetLength(LTones, LTone + 1);
    LTones[LTone].StartFrame := Int64(LCell) * LFramesPerCell;
    LTones[LTone].GateFrames := LFramesPerCell * 3 div 4;
    if APartitioned then
    begin
      if ARhythmOnly then
      begin
        LTones[LTone].StartFrame := Int64(RhythmTicks[LCell]) * 50 div 3;
        LTones[LTone].GateFrames := (RhythmTicks[LCell + 1] - RhythmTicks[LCell]) * 25 div 2;
      end
      else
      begin
        LTones[LTone].StartFrame := Int64(VoiceTicks[LCell]) * 50 div 3;
        LTones[LTone].GateFrames := (VoiceTicks[LCell + 1] - VoiceTicks[LCell]) * 25 div 2;
      end;
    end;
    LTones[LTone].FrequencyHz := 110;
    if not ARhythmOnly then
    begin
      LTones[LTone].FrequencyHz := MidiFrequency(StrToInt(ASequences[LLayer].Tokens[LCell]));
    end;
    LTones[LTone].Velocity := 0.7;
    LTones[LTone].Voice := DefaultSynthVoice;
    LTones[LTone].Voice.Gain := 0.2;
  end;
  Result := RenderFrameTones(LTones, 16000, 32000);
end;

procedure CheckLayerAudio(const ABefore, AAfter: TLayerSequences;
  const AMapped: Boolean; const APartitioned: Boolean = False);
var
  LBefore: TAudioClip;
  LAfter: TAudioClip;
  LBeforeBytes: TAudioBytes;
  LAfterBytes: TAudioBytes;
  LKeyOnly: Boolean;
  LEqual: Boolean;
  LStem: String;
begin
  for LKeyOnly := False to True do
  begin
    LBefore := nil;
    LAfter := nil;
    try
      if AMapped then
      begin
        LBefore := RenderMappedControl(ABefore, LKeyOnly, APartitioned);
        LAfter := RenderMappedControl(AAfter, LKeyOnly, APartitioned);
      end
      else
      begin
        LBefore := RenderReplacementControl(ABefore, LKeyOnly);
        LAfter := RenderReplacementControl(AAfter, LKeyOnly);
      end;
      LBeforeBytes := EncodeWavePcm16(LBefore);
      LAfterBytes := EncodeWavePcm16(LAfter);
      if APartitioned and AMapped then
      begin
        Check((LBefore.FrameCount = 32000) and (LAfter.FrameCount = 32000),
          'Partition controls retain the exact two-second native render extent');
      end;
      LEqual := Length(LBeforeBytes) = Length(LAfterBytes);
      if LEqual then
      begin
        LEqual := CompareByte(LBeforeBytes[0], LAfterBytes[0], Length(LBeforeBytes)) = 0;
      end;
      Check(LEqual = LKeyOnly, 'Layer edit changes dependent audio and preserves independent stem');
      if ParamCount = 1 then
      begin
        LStem := IncludeTrailingPathDelimiter(ParamStr(1));
        if AMapped then
        begin
          if LKeyOnly then
          begin
            LStem := LStem + 'mapped-rhythm-';
          end
          else
          begin
            LStem := LStem + 'mapped-voice-';
          end;
        end
        else if LKeyOnly then
        begin
          LStem := LStem + 'independent-key-';
        end
        else
        begin
          LStem := LStem + 'replacement-';
        end;
        if APartitioned then
        begin
          LStem := LStem + 'partition-';
        end;
        SaveWavePcm16(LStem + 'before.wav', LBefore);
        SaveWavePcm16(LStem + 'after.wav', LAfter);
      end;
    finally
      LAfter.Free;
      LBefore.Free;
    end;
  end;
end;

procedure RunPreferences(const APartitioned: Boolean);
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LSession: TLearnedLayerSession;
  LReplay: TLearnedLayerSession;
  LHeavy: TWfcSequenceModel;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LAgain: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LReplacement: TLayerModelReplacementReport;
  LPreferences: TLayerTokenPreferences;
  LOriginal: String;
  LSeed: Integer;
  LCell: Integer;
  LLayer: Integer;
  LBaseHigh: Integer;
  LPreferredHigh: Integer;
  LRejected: Boolean;
  LHash: TGraphTraceSignature;
begin
  LSession := nil;
  LReplay := nil;
  LHeavy := nil;
  SetLength(LLayers, 3);
  try
    LLayers[0].Model := Learn(['C', 'F'], ['F', 'C'], 1);
    LLayers[1].Model := Learn(['low', 'high'], ['high', 'low'], 1);
    LLayers[2].Model := Learn(['soft', 'loud'], ['loud', 'soft'], 1);
    LOriginal := EncodeWfcSequenceText(LLayers[1].Model);
    LMaps := nil;
    SetLength(LMaps, 1);
    LMaps[0].Provider := 1;
    LMaps[0].Consumer := 2;
    LMaps[0].Rules := [MakeWfcSequenceProjectionRule('soft', ['low']),
      MakeWfcSequenceProjectionRule('loud', ['high'])];
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := 8;
    if APartitioned then
    begin
      LOptions.TimeGrids := [MakeLayerTimePartition([0, 1, 3, 4, 7, 8, 10, 11, 12]),
        MakeLayerTimePartition([0, 1, 3, 4, 7, 8, 10, 11, 12]),
        MakeLayerTimePartition([0, 1, 3, 4, 7, 8, 10, 11, 12])];
    end;
    LBaseHigh := 0;
    LPreferredHigh := 0;
    for LSeed := 1 to 32 do
    begin
      LOptions.Seed := LSeed;
      LLayers[1].Preferences := nil;
      Check(TryGenerateLayers(LLayers, LMaps, LOptions, LBefore, LReport), 'Preference baseline');
      LLayers[1].Preferences := [MakeLayerTokenPreference('high', 16)];
      Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport), 'Preferred solve');
      CheckSameLayer(LBefore, LAfter, 0);
      for LCell := 0 to 7 do
      begin
        if LBefore[1].Tokens[LCell] = 'high' then
        begin
          Inc(LBaseHigh);
        end;
        if LAfter[1].Tokens[LCell] = 'high' then
        begin
          Inc(LPreferredHigh);
          Check(LAfter[2].Tokens[LCell] = 'loud', 'Preferred token preserves projection');
        end
        else
        begin
          Check(LAfter[2].Tokens[LCell] = 'soft', 'Alternative preserves projection');
        end;
      end;
    end;
    Check(LPreferredHigh > LBaseHigh + 64, 'Declared seed panel responds to preference');
    LHash := LReport.TranscriptHash;
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAgain, LReport), 'Preferred replay');
    Check(LReport.TranscriptHash = LHash, 'Preferred transcript replay');
    for LLayer := 0 to 2 do
    begin
      CheckSameLayer(LAfter, LAgain, LLayer);
    end;
    Check(EncodeWfcSequenceText(LLayers[1].Model) = LOriginal, 'Learning counts remain unchanged');

    LLayers[1].Preferences := nil;
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LBefore, LReport), 'Neutral baseline');
    LLayers[1].Preferences := [MakeLayerTokenPreference('low', 2),
      MakeLayerTokenPreference('high', 2)];
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport), 'Uniform scaling');
    for LLayer := 0 to 2 do
    begin
      CheckSameLayer(LBefore, LAfter, LLayer);
    end;

    LLayers[1].Preferences := [MakeLayerTokenPreference('high', 16)];
    SetLock(LLayers[1], 'low');
    LSession := TLearnedLayerSession.Create(LLayers, LMaps,
      ['key', 'voice', 'articulation'], LOptions);
    LReplay := TLearnedLayerSession.Create(LLayers, LMaps,
      ['key', 'voice', 'articulation'], LOptions);
    LLayers[1].Preferences[0].Token := 'caller mutation';
    Check(LSession.TryGenerate(LBefore, LReport), 'Session owns initial preferences');
    Check(LReplay.TryGenerate(LAgain, LReport), 'Replay session initial solve');
    Check(LBefore[1].Tokens[0] = 'low', 'Hard lock wins over preference');
    LPreferences := [MakeLayerTokenPreference('low', 16)];
    LSession.SetPreferences('voice', LPreferences);
    LReplay.SetPreferences('voice', LPreferences);
    LPreferences[0].Token := 'caller mutation';
    LPreferences := LSession.CopyPreferences('voice');
    Check(LPreferences[0].Token = 'low', 'Session owns preference edit');
    LPreferences[0].Multiplier := 0;
    Check(LSession.CopyPreferences('voice')[0].Multiplier = 16, 'Preference copies detach');
    Check(LSession.TryRegenerate(['articulation'], 987, LAfter, LSelective),
      'Pending preference participates in regeneration');
    Check((Length(LSelective.ActivePassIndices) = 2) and
      (LSelective.ActivePassIndices[0] = 1) and (LSelective.ActivePassIndices[1] = 2),
      'Preference dirty root closes through descendants');
    CheckSameLayer(LBefore, LAfter, 0);
    Check(LReplay.TryRegenerate(['articulation'], 987, LAgain, LSelective), 'Preference edit replay');
    for LLayer := 0 to 2 do
    begin
      CheckSameLayer(LAfter, LAgain, LLayer);
    end;
    LBefore := LSession.CopyAccepted;
    for LCell := 0 to 3 do
    begin
      LPreferences := [MakeLayerTokenPreference('low', 16)];
      case LCell of
        0: LPreferences[0].Token := 'unknown';
        1: LPreferences[0].Multiplier := 0;
        2: LPreferences[0].Multiplier := 1025;
        3: LPreferences := [LPreferences[0], LPreferences[0]];
      end;
      LRejected := False;
      try
        LSession.SetPreferences('voice', LPreferences);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Invalid preference rejects');
      Check(LSession.CopyPreferences('voice')[0].Multiplier = 16, 'Rejected edit preserves settings');
    end;
    LSession.SetConstraints('articulation', [MakeWfcSequenceTokenConstraint(0, ['loud'])]);
    Check(not LSession.TryRegenerate(['voice'], 988, LAfter, LSelective),
      'Preferences cannot override contradictory locks');
    for LLayer := 0 to 2 do
    begin
      CheckSameLayer(LBefore, LAfter, LLayer);
      CheckSameLayer(LBefore, LSession.CopyAccepted, LLayer);
    end;
    LSession.SetConstraints('articulation', nil);
    Check(LSession.TryRegenerate(['voice'], 989, LAfter, LSelective),
      'Failed preferred solve restores graph weights for later edits');
    Check(LSession.TryReplaceModel('voice', LLayers[1].Model, 990, LAfter, LReplacement),
      'Model replacement retains preferences');
    Check(LSession.CopyPreferences('voice')[0].Multiplier = 16, 'Replacement preference retained');
    LSession.SetPreferences('voice', nil);
    Check(Length(LSession.CopyPreferences('voice')) = 0, 'Clear restores learned choice policy');
    Check(LSession.TryRegenerate(['voice'], 991, LAfter, LSelective), 'Regenerate after clearing');

    LLayers[1].Preferences := [MakeLayerTokenPreference('high', 1024)];
    LBefore := LSession.CopyAccepted;
    LHeavy := TWfcSequenceModel.Create(1, [6000000], LLayers[1].Model.CopyPublicTokens,
      LLayers[1].Model.CopyStates, [3000000, 3000000], [1, 0], [0, 1], wmbOpen);
    LRejected := False;
    try
      LSession.SetPreferences('voice', LLayers[1].Preferences);
      LSession.TryReplaceModel('voice', LHeavy, 992, LAfter, LReplacement);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Preferred weight overflow rejects before candidate publication');
    Check(LSession.CopyPreferences('voice')[0].Multiplier = 1024, 'Failed replacement preserves edit');
    for LLayer := 0 to 2 do
    begin
      CheckSameLayer(LBefore, LAfter, LLayer);
      CheckSameLayer(LBefore, LSession.CopyAccepted, LLayer);
    end;
    WriteLn('Layer preferences: partitioned=', APartitioned, ' high selections=',
      LBaseHigh, ' -> ', LPreferredHigh, '/256; replay, ownership, constraints and rollback pass');
  finally
    LHeavy.Free;
    LReplay.Free;
    LSession.Free;
    for LLayer := 0 to High(LLayers) do
    begin
      LLayers[LLayer].Model.Free;
    end;
  end;
end;

procedure RunPreferencePreparationBound;
var
  LLayers: TLearnedLayers;
  LTokens: TWfcModelTokens;
  LOptions: TLayerGenerationOptions;
  LReport: TGraphNegotiationReport;
  LOutput: TLayerSequences;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LLayers, 1);
  SetLength(LTokens, 256);
  for LIndex := 0 to High(LTokens) do
  begin
    LTokens[LIndex] := IntToStr(LIndex);
  end;
  LLayers[0].Model := Learn(LTokens, LTokens, 1);
  try
    LLayers[0].Preferences := [MakeLayerTokenPreference('0', 2)];
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := 1;
    LRejected := False;
    try
      TryGenerateLayers(LLayers, nil, LOptions, LOutput, LReport);
    except
      on LException: EAudio do
      begin
        LRejected := Pos('preparation exceeds work budget', LException.Message) > 0;
      end;
    end;
    Check(LRejected and (Length(LOutput) = 0), 'Preference work bound rejects before publication');
    WriteLn('Preference public-domain preparation budget rejects before graph construction');
  finally
    LLayers[0].Model.Free;
  end;
end;

procedure RunSession;
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LNames: TLayerNames;
  LSession: TLearnedLayerSession;
  LOptions: TLayerGenerationOptions;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LCopy: TLayerSequences;
  LMask: TWfcSequenceTokenConstraints;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LSession := nil;
  SetLength(LLayers, 4);
  SetLength(LNames, 4);
  LNames[0] := 'key';
  LNames[1] := 'rhythm';
  LNames[2] := 'voice';
  LNames[3] := 'articulation';
  try
    LLayers[0].Model := Learn(['C', 'F', 'C', 'F'], ['F', 'C', 'F', 'C'], 2);
    LLayers[1].Model := Learn(['x', '.', 'x', '.'], ['.', 'x', '.', 'x'], 2);
    LLayers[2].Model := Learn(['on', 'off', 'on', 'off'], ['off', 'on', 'off', 'on'], 2);
    LLayers[3].Model := Learn(['attack', 'rest', 'attack', 'rest'],
      ['rest', 'attack', 'rest', 'attack'], 2);
    SetLock(LLayers[1], 'x');
    SetLength(LMaps, 2);
    LMaps[0].Provider := 1;
    LMaps[0].Consumer := 2;
    SetLength(LMaps[0].Rules, 2);
    LMaps[0].Rules[0] := MakeWfcSequenceProjectionRule('on', ['x']);
    LMaps[0].Rules[1] := MakeWfcSequenceProjectionRule('off', ['.']);
    LMaps[1].Provider := 2;
    LMaps[1].Consumer := 3;
    SetLength(LMaps[1].Rules, 2);
    LMaps[1].Rules[0] := MakeWfcSequenceProjectionRule('attack', ['on']);
    LMaps[1].Rules[1] := MakeWfcSequenceProjectionRule('rest', ['off']);
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := 4;
    LOptions.Extent := wseWhole;
    LSession := TLearnedLayerSession.Create(LLayers, LMaps, LNames, LOptions);
    for LIndex := 0 to High(LLayers) do
    begin
      FreeAndNil(LLayers[LIndex].Model);
    end;
    LMaps[0].Rules[0].SourceTokens[0] := 'caller mutation';
    LNames[1] := 'caller mutation';
    LLayers[1].Constraints[0] := MakeWfcSequenceTokenConstraint(0, ['caller mutation']);
    Check(LSession.TryGenerate(LBefore, LReport), 'Session owns models and all input arrays');
    Check(LBefore[1].Tokens[0] = 'x', 'Initial mask survives caller mutation');
    SetLength(LMask, 1);
    LMask[0] := MakeWfcSequenceTokenConstraint(0, ['.']);
    LSession.SetConstraints('rhythm', LMask);
    Check(LSession.TryRegenerate(['rhythm'], 991, LAfter, LSelective), 'Selective rhythm edit');
    Check((Length(LSelective.ActivePassIndices) = 3) and
      (LSelective.ActivePassIndices[0] = 1) and
      (LSelective.ActivePassIndices[1] = 2) and
      (LSelective.ActivePassIndices[2] = 3), 'Actual transitive WFC closure');
    CheckSameLayer(LBefore, LAfter, 0);
    Check((LAfter[1].Tokens[0] = '.') and (LAfter[2].Tokens[0] = 'off') and
      (LAfter[3].Tokens[0] = 'rest'), 'Changed provider reaches both descendants');
    LBefore := LAfter;
    LCopy := LSession.CopyAccepted;
    LCopy[0].Tokens[0] := 'mutation';
    LCopy[0].StateIndices[0] := -1;
    LCopy := LSession.CopyAccepted;
    CheckSameLayer(LBefore, LCopy, 0);

    LMask[0] := MakeWfcSequenceTokenConstraint(0, ['attack']);
    LSession.SetConstraints('articulation', LMask);
    Check(not LSession.TryRegenerate(['articulation'], 123, LAfter, LSelective),
      'An active descendant cannot rewrite a preserved incompatible provider');
    Check(LSelective.Search.Status = gnsContradiction, 'Selective contradiction reported');
    LCopy := LSession.CopyAccepted;
    for LIndex := 0 to 3 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
      CheckSameLayer(LBefore, LCopy, LIndex);
    end;
    LSession.SetConstraints('articulation', nil);
    Check(LSession.TryRegenerate(['articulation'], 123, LAfter, LSelective),
      'Clearing failed edit restores original model domains');
    for LIndex := 0 to 2 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
    end;

    LMask[0] := MakeWfcSequenceTokenConstraint(0, ['x']);
    LSession.SetConstraints('rhythm', LMask);
    Check(LSession.TryRegenerate(['articulation'], 731, LAfter, LSelective),
      'Pending provider edit becomes an effective regeneration root');
    Check((Length(LSelective.RequestedRootIndices) = 2) and
      (LSelective.RequestedRootIndices[0] = 1) and
      (LSelective.RequestedRootIndices[1] = 3), 'Dirty provider included with requested root');
    Check((LAfter[1].Tokens[0] = 'x') and (LAfter[3].Tokens[0] = 'attack'),
      'Pending provider edit was applied');
    CheckSameLayer(LBefore, LAfter, 0);
    LBefore := LAfter;
    LRejected := False;
    try
      LSession.TryRegenerate(['unknown'], 731, LAfter, LSelective);
    except
      on Exception do LRejected := True;
    end;
    Check(LRejected, 'Unknown root rejects');
    LMask[0] := MakeWfcSequenceTokenConstraint(4, ['.']);
    LRejected := False;
    try
      LSession.SetConstraints('rhythm', LMask);
    except
      on Exception do LRejected := True;
    end;
    Check(LRejected, 'Invalid mask rejects before mutation');
    Check(LSession.TryRegenerate(['articulation'], 731, LAfter, LSelective),
      'Invalid edits leave the session usable');
    for LIndex := 0 to 3 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
    end;
    WriteLn('Owned named sessions, selective WFC closure, retained states, pending edits and recovery pass');
  finally
    LSession.Free;
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
  end;
end;

procedure RunReplacement(const APartitioned: Boolean = False);
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LSession: TLearnedLayerSession;
  LReplay: TLearnedLayerSession;
  LReplacement: TWfcSequenceModel;
  LInvalid: TWfcSequenceModel;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LRepeated: TLayerSequences;
  LCopy: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LReplaced: TLayerModelReplacementReport;
  LMask: TWfcSequenceTokenConstraints;
  LIndex: Integer;
  LRejected: Boolean;
  LKey: String;
begin
  LSession := nil;
  LReplay := nil;
  LReplacement := nil;
  LInvalid := nil;
  SetLength(LLayers, 4);
  try
    LLayers[0].Model := Learn(['C', 'F', 'C', 'F'], ['F', 'C', 'F', 'C'], 3);
    LLayers[1].Model := Learn(['x', '.', 'x', '.'], ['.', 'x', '.', 'x'], 2);
    LLayers[2].Model := Learn(['on', 'off', 'on', 'off'], ['off', 'on', 'off', 'on'], 1);
    LLayers[3].Model := Learn(['attack', 'rest', 'attack', 'rest'],
      ['rest', 'attack', 'rest', 'attack'], 1);
    SetLock(LLayers[1], 'x');
    SetLength(LMaps, 2);
    LMaps[0].Provider := 1;
    LMaps[0].Consumer := 2;
    LMaps[0].Rules := [MakeWfcSequenceProjectionRule('on', ['x']),
      MakeWfcSequenceProjectionRule('off', ['.'])];
    LMaps[1].Provider := 2;
    LMaps[1].Consumer := 3;
    LMaps[1].Rules := [MakeWfcSequenceProjectionRule('attack', ['on']),
      MakeWfcSequenceProjectionRule('rest', ['off'])];
    LOptions := DefaultLayerGenerationOptions;
    LOptions.Scopes := [MakeLayerScope(1, wsePrefix), MakeLayerScope(4, wseWhole),
      MakeLayerScope(4, wseWhole), MakeLayerScope(4, wseWhole)];
    if APartitioned then
    begin
      LOptions.TimeGrids := [MakeLayerTimePartition([0, 1920]),
        MakeLayerTimePartition([0, 480, 960, 1440, 1920]),
        MakeLayerTimePartition([0, 480, 960, 1440, 1920]),
        MakeLayerTimePartition([0, 480, 960, 1440, 1920])];
    end;
    LSession := TLearnedLayerSession.Create(LLayers, LMaps,
      ['key', 'rhythm', 'voice', 'articulation'], LOptions);
    LReplay := TLearnedLayerSession.Create(LLayers, LMaps,
      ['key', 'rhythm', 'voice', 'articulation'], LOptions);
    LLayers[1].Constraints[0].AllowedTokens[0] := 'caller mutation';
    LReplacement := Learn(['x', 'x', '.', '.'], ['x', 'x', '.', '.'], 4);
    LRejected := False;
    try
      LSession.TryReplaceModel('rhythm', LReplacement, 917, LAfter, LReplaced);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LAfter) = 0), 'Replacement requires initial acceptance');
    Check(LSession.TryGenerate(LBefore, LReport), 'Replacement baseline');
    Check(LReplay.TryGenerate(LRepeated, LReport), 'Independent replay baseline');
    LAfter := LSession.CopyAccepted;
    LMask := [MakeWfcSequenceTokenConstraint(1, ['rest'])];
    LSession.SetConstraints('articulation', LMask);
    LMask[0].AllowedTokens[0] := 'caller mutation';
    Check(not LSession.TryReplaceModel('rhythm', LReplacement, 917, LAfter, LReplaced),
      'Contradictory retained descendant mask rejects replacement');
    Check(LReplaced.Search.Status = gnsContradiction, 'Replacement contradiction report');
    LCopy := LSession.CopyAccepted;
    for LIndex := 0 to 3 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
      CheckSameLayer(LBefore, LCopy, LIndex);
    end;
    Check(LSession.TryRegenerate(['articulation'], 917, LAfter, LSelective),
      'Failed replacement retains original provider and pending descendant mask');
    Check(LAfter[3].Tokens[1] = 'rest', 'Pending nested mask is detached');
    LSession.SetConstraints('articulation', nil);
    Check(LSession.TryReplaceModel('rhythm', LReplacement, 917, LAfter, LReplaced),
      'Compatible replacement after clearing contradiction');
    Check((LReplaced.ReplacedLayerIndex = 1) and
      (Length(LReplaced.RootLayerIndices) = 1) and (LReplaced.RootLayerIndices[0] = 1) and
      (Length(LReplaced.AffectedLayerIndices) = 3) and
      (LReplaced.AffectedLayerIndices[0] = 1) and
      (LReplaced.AffectedLayerIndices[1] = 2) and
      (LReplaced.AffectedLayerIndices[2] = 3) and
      (Length(LReplaced.PreservedLayerIndices) = 1) and
      (LReplaced.PreservedLayerIndices[0] = 0), 'Replacement reports actual dependency closure');
    CheckSameLayer(LBefore, LAfter, 0);
    Check((LAfter[1].Tokens[1] = 'x') and (LAfter[1].Tokens[2] = '.') and
      (LAfter[2].Tokens[1] = 'on') and (LAfter[3].Tokens[1] = 'attack'),
      'Replacement changes learned temporal behavior through both descendants');
    CheckLayerAudio(LBefore, LAfter, False);
    Check(LReplay.TryReplaceModel('rhythm', LReplacement, 917, LRepeated, LReplaced),
      'Replacement replays in an independently constructed session');
    for LIndex := 0 to 3 do
    begin
      CheckSameLayer(LAfter, LRepeated, LIndex);
    end;
    FreeAndNil(LReplacement);
    LBefore := LSession.CopyAccepted;
    LAfter[1].Tokens[0] := 'caller mutation';
    LAfter[1].StateIndices[0] := -1;
    LCopy := LSession.CopyAccepted;
    CheckSameLayer(LBefore, LCopy, 1);
    LSession.SetConstraints('rhythm', nil);
    Check(LSession.TryRegenerate(['rhythm'], 312, LAfter, LSelective),
      'Owned replacement remains usable after source free and mask clear');
    for LIndex := 0 to 3 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
    end;
    LKey := 'C';
    if LBefore[0].Tokens[0] = LKey then
    begin
      LKey := 'F';
    end;
    LSession.SetConstraints('key', [MakeWfcSequenceTokenConstraint(0, [LKey])]);
    Check(LSession.TryRegenerate(['key'], 517, LAfter, LSelective),
      'Previously preserved independent layer can still regenerate');
    Check((Length(LSelective.ActivePassIndices) = 1) and
      (LSelective.ActivePassIndices[0] = 0), 'Independent key has no implicit predecessor chain');
    Check(LAfter[0].Tokens[0] = LKey, 'Temporary domains do not pin future edits');
    for LIndex := 1 to 3 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
    end;
    LSession.SetConstraints('key', [MakeWfcSequenceTokenConstraint(0, [LBefore[0].Tokens[0]])]);
    LBefore := LSession.CopyAccepted;
    LInvalid := Learn(['x', 'x', 'x', 'x'], ['x', 'x', 'x', 'x'], 2);
    LRejected := False;
    try
      LSession.TryReplaceModel('rhythm', LInvalid, 917, LAfter, LReplaced);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Replacement rejects incompatible projection vocabulary');
    LRejected := False;
    try
      LSession.TryReplaceModel('rhythm', nil, 917, LAfter, LReplaced);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Nil replacement rejects');
    LRejected := False;
    try
      LSession.TryReplaceModel('unknown', LLayers[1].Model, 917, LAfter, LReplaced);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unknown replacement layer rejects');
    LCopy := LSession.CopyAccepted;
    for LIndex := 0 to 3 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
      CheckSameLayer(LBefore, LCopy, LIndex);
    end;
    Check(LSession.TryReplaceModel('rhythm', LLayers[1].Model, 611, LAfter, LReplaced),
      'A second replacement includes pending independent edits after rejection');
    Check((Length(LReplaced.RootLayerIndices) = 2) and
      (LReplaced.RootLayerIndices[0] = 0) and (LReplaced.RootLayerIndices[1] = 1) and
      (Length(LReplaced.AffectedLayerIndices) = 4) and
      (Length(LReplaced.PreservedLayerIndices) = 0) and
      (LAfter[0].Tokens[0] <> LKey), 'All affected roots publish together');
    Check(LAfter[1].Tokens[0] <> LAfter[1].Tokens[1], 'Second replacement restores alternating model');
    LBefore := LSession.CopyAccepted;
    LReplacement := Learn(['on', 'on', 'off', 'off'], ['on', 'on', 'off', 'off'], 4);
    Check(not LSession.TryReplaceModel('voice', LReplacement, 319, LAfter, LReplaced),
      'A replaced consumer cannot renegotiate its preserved ancestor');
    Check((LReplaced.Search.Status = gnsContradiction) and
      (Length(LReplaced.AffectedLayerIndices) = 2) and
      (LReplaced.AffectedLayerIndices[0] = 2) and
      (LReplaced.AffectedLayerIndices[1] = 3) and
      (Length(LReplaced.PreservedLayerIndices) = 2), 'Consumer replacement scope remains bounded');
    LCopy := LSession.CopyAccepted;
    for LIndex := 0 to 3 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
      CheckSameLayer(LBefore, LCopy, LIndex);
    end;
    WriteLn('Model replacement: exact preservation, new latent model, masks, rollback, replay and future edits pass');
  finally
    LInvalid.Free;
    LReplacement.Free;
    LReplay.Free;
    LSession.Free;
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
  end;
end;

procedure Run;
var
  LLayers: TLearnedLayers;
  LSingle: TLearnedLayers;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LReport: TGraphNegotiationReport;
  LFirst: TLayerSequences;
  LSecond: TLayerSequences;
  LIndex: Integer;
  LPosition: Integer;
  LRejected: Boolean;
  LNeededNegotiation: Boolean;
  LValidation: TWfcSequenceGraphValidationReport;
  LPair: String;
  LExpected: String;
begin
  SetLength(LLayers, 4);
  try
    LLayers[0].Model := Learn(['C', 'F', 'C', 'F'], ['F', 'C', 'F', 'C'], 2);
    LLayers[1].Model := Learn(['E', 'A', 'E', 'A'], ['G', 'C', 'G', 'C'], 2);
    LLayers[2].Model := Learn(['C:E', 'F:A', 'C:E', 'F:A'],
      ['C:G', 'F:C', 'C:G', 'F:C'], 1);
    LLayers[3].Model := Learn(['third', 'third', 'third', 'third'],
      ['fifth', 'fifth', 'fifth', 'fifth'], 2);
    SetLength(LMaps, 3);
    LMaps[0].Consumer := 2;
    LMaps[0].Provider := 0;
    LMaps[1].Consumer := 2;
    LMaps[1].Provider := 1;
    SetLength(LMaps[0].Rules, 4);
    SetLength(LMaps[1].Rules, 4);
    LMaps[0].Rules[0] := MakeWfcSequenceProjectionRule('C:E', ['C']);
    LMaps[0].Rules[1] := MakeWfcSequenceProjectionRule('F:A', ['F']);
    LMaps[0].Rules[2] := MakeWfcSequenceProjectionRule('C:G', ['C']);
    LMaps[0].Rules[3] := MakeWfcSequenceProjectionRule('F:C', ['F']);
    LMaps[1].Rules[0] := MakeWfcSequenceProjectionRule('C:E', ['E']);
    LMaps[1].Rules[1] := MakeWfcSequenceProjectionRule('F:A', ['A']);
    LMaps[1].Rules[2] := MakeWfcSequenceProjectionRule('C:G', ['G']);
    LMaps[1].Rules[3] := MakeWfcSequenceProjectionRule('F:C', ['C']);
    LMaps[2].Consumer := 3;
    LMaps[2].Provider := 2;
    SetLength(LMaps[2].Rules, 2);
    LMaps[2].Rules[0] := MakeWfcSequenceProjectionRule('third', ['C:E', 'F:A']);
    LMaps[2].Rules[1] := MakeWfcSequenceProjectionRule('fifth', ['C:G', 'F:C']);
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := 4;
    LOptions.Extent := wseWhole;
    SetLock(LLayers[0], 'C');
    SetLock(LLayers[1], 'E');
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LFirst, LReport), 'Compatible layers solve');
    Check(LReport.Status = gnsSolved, 'Negotiation reports solved');
    for LIndex := 0 to 3 do
    begin
      Check(ValidateSequenceStatePath(LLayers[LIndex].Model, LFirst[LIndex].StateIndices,
        wseWhole, LValidation), 'Actual latent path');
    end;
    for LPosition := 0 to 3 do
    begin
      if LPosition mod 2 = 0 then
      begin
        LExpected := 'C:E';
      end
      else
      begin
        LExpected := 'F:A';
      end;
      LPair := LFirst[0].Tokens[LPosition] + ':' + LFirst[1].Tokens[LPosition];
      Check((LPair = LExpected) and (LFirst[2].Tokens[LPosition] = LPair),
        'Independent expected observed pair');
      Check(LFirst[3].Tokens[LPosition] = 'third', 'Temporal interval relation');
    end;
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport), 'Replay');
    for LIndex := 0 to 3 do
    begin
      for LPosition := 0 to 3 do
      begin
        Check(LFirst[LIndex].Tokens[LPosition] = LSecond[LIndex].Tokens[LPosition], 'Replay tokens');
        Check(LFirst[LIndex].StateIndices[LPosition] = LSecond[LIndex].StateIndices[LPosition],
          'Replay latent states');
      end;
    end;
    LSecond[0].Tokens[0] := 'caller mutation';
    LSecond[0].StateIndices[0] := -99;
    Check(LFirst[0].Tokens[0] = 'C', 'Detached caller result');
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport), 'Rerun after caller mutation');

    { Both marginal sequences are valid, but F:E was never an observed pair. }
    SetLock(LLayers[0], 'F');
    Check(not TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport),
      'Individually valid incompatible lanes must reject');
    Check(LReport.Status = gnsContradiction, 'Finite incompatible fixture is contradictory');
    Check((LSecond[0].Tokens[0] = 'C') and
      (LSecond[0].StateIndices[0] = LFirst[0].StateIndices[0]), 'False preserves prior output');
    SetLock(LLayers[0], 'C');

    LMaps[1].Provider := 0;
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSecond[0].Tokens[0] = 'C'), 'Duplicate provider rejected atomically');
    LMaps[1].Provider := 1;
    LMaps[2].Provider := 3;
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSecond[0].Tokens[0] = 'C'), 'Self-dependency rejected atomically');
    LMaps[2].Provider := 2;
    LMaps[2].Rules[0].SourceTokens[0] := 'unknown pair';
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSecond[0].Tokens[0] = 'C'), 'Invalid relation preserves prior output');
    LMaps[2].Rules[0].SourceTokens[0] := 'C:E';
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport), 'Retry after invalid map');
    LLayers[1].Constraints := nil;
    SetLock(LLayers[3], 'fifth');
    LNeededNegotiation := False;
    for LIndex := 1 to 16 do
    begin
      LOptions.Seed := LIndex;
      Check(TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport),
        'Downstream interval can negotiate an earlier melody');
      Check((LSecond[1].Tokens[0] = 'G') and (LSecond[3].Tokens[0] = 'fifth'),
        'Downstream relationship is honored');
      if LReport.PassBacktracks > 0 then
      begin
        LNeededNegotiation := True;
        Break;
      end;
    end;
    Check(LNeededNegotiation, 'Fixture exercised an actual provider retry');
    LOptions.MaxPassBacktracks := 0;
    Check(not TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport),
      'Zero provider-retry budget stops the same search');
    Check((LReport.Status = gnsPassBacktrackLimit) and (LSecond[1].Tokens[0] = 'G'),
      'Pass budget exhaustion is distinct and preserves prior output');
    LOptions.CellCount := MaximumLayerCells + 1;
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LSecond, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSecond[1].Tokens[0] = 'G'), 'Request budget preserves prior output');
    LOptions.CellCount := 4;
    SetLength(LSingle, 1);
    LSingle[0] := LLayers[0];
    Check(TryGenerateLayers(LSingle, nil, LOptions, LSecond, LReport), 'Single layer boundary');
    Check((Length(LSecond) = 1) and (LSecond[0].Tokens[0] = 'C'), 'Single layer projection');
    WriteLn('Four negotiated layers, pair/interval correlation, paths, replay and failure preservation pass');
  finally
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
  end;
end;

procedure RunTimeMaps(const APartitioned: Boolean = False);
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LSession: TLearnedLayerSession;
  LReplacement: TWfcSequenceModel;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LReplaced: TLayerModelReplacementReport;
  LIndex: Integer;
  LExpected: String;
begin
  LSession := nil;
  LReplacement := nil;
  SetLength(LLayers, 4);
  try
    LLayers[0].Model := Learn(['C'], ['F'], 1);
    LLayers[1].Model := Learn(['on', 'off', 'on', 'off'], ['off', 'on', 'off', 'on'], 2);
    LLayers[2].Model := Learn(['C', 'G'], ['F', 'Bb'], 2);
    LLayers[3].Model := Learn(['60', '67', 'rest'], ['65', '70', 'rest'], 1);
    SetLock(LLayers[0], 'C');
    SetLock(LLayers[1], 'on');
    LOptions := DefaultLayerGenerationOptions;
    LOptions.Scopes := [MakeLayerScope(1, wseWhole), MakeLayerScope(4, wseWhole),
      MakeLayerScope(2, wseWhole), MakeLayerScope(8, wseFragment)];
    LOptions.TimeGrids := [MakeLayerTimeGrid(0, 1920), MakeLayerTimeGrid(0, 480),
      MakeLayerTimeGrid(0, 960), MakeLayerTimeGrid(0, 240)];
    if APartitioned then
    begin
      LOptions.TimeGrids[1] := MakeLayerTimePartition([0, 360, 960, 1560, 1920]);
      LOptions.TimeGrids[2] := MakeLayerTimePartition([0, 840, 1920]);
      LOptions.TimeGrids[3] := MakeLayerTimePartition(
        [0, 120, 360, 720, 960, 1200, 1560, 1800, 1920]);
    end;
    SetLength(LMaps, 3);
    LMaps[0].Provider := 0;
    LMaps[0].Consumer := 2;
    LMaps[0].TimeMapping := ltmWholeCell;
    LMaps[0].Rules := [MakeWfcSequenceProjectionRule('C', ['C']),
      MakeWfcSequenceProjectionRule('G', ['C']), MakeWfcSequenceProjectionRule('F', ['F']),
      MakeWfcSequenceProjectionRule('Bb', ['F'])];
    LMaps[1].Provider := 2;
    LMaps[1].Consumer := 3;
    LMaps[1].TimeMapping := ltmStartTick;
    LMaps[1].Rules := [MakeWfcSequenceProjectionRule('60', ['C']),
      MakeWfcSequenceProjectionRule('67', ['G']), MakeWfcSequenceProjectionRule('65', ['F']),
      MakeWfcSequenceProjectionRule('70', ['Bb']),
      MakeWfcSequenceProjectionRule('rest', ['C', 'G', 'F', 'Bb'])];
    LMaps[2].Provider := 1;
    LMaps[2].Consumer := 3;
    LMaps[2].TimeMapping := ltmWholeCell;
    LMaps[2].Rules := [MakeWfcSequenceProjectionRule('60', ['on']),
      MakeWfcSequenceProjectionRule('67', ['on']), MakeWfcSequenceProjectionRule('65', ['on']),
      MakeWfcSequenceProjectionRule('70', ['on']), MakeWfcSequenceProjectionRule('rest', ['off'])];
    LSession := TLearnedLayerSession.Create(LLayers, LMaps,
      ['key', 'rhythm', 'harmony', 'voice'], LOptions);
    if APartitioned then
    begin
      LOptions.TimeGrids[2].Boundaries[1] := 10;
      LOptions.TimeGrids[3].Boundaries[1] := -10;
    end;
    LOptions.TimeGrids[0].TicksPerCell := 0;
    LMaps[0].TimeMapping := ltmCellIndex;
    Check(LSession.TryGenerate(LBefore, LReport), 'Owned 1/4/2/8-cell grids solve');
    for LIndex := 0 to 7 do
    begin
      LExpected := 'rest';
      if LIndex mod 4 < 2 then
      begin
        if LIndex < 4 then
        begin
          LExpected := '60';
        end
        else
        begin
          LExpected := '67';
        end;
      end;
      Check(LBefore[3].Tokens[LIndex] = LExpected, 'Independent coarse harmony / beat oracle');
    end;
    LSession.SetConstraints('key', [MakeWfcSequenceTokenConstraint(0, ['F'])]);
    Check(LSession.TryRegenerate(['key'], 211, LAfter, LSelective),
      'Mapped key edit reaches harmony and voice');
    Check((Length(LSelective.ActivePassIndices) = 3) and
      (LSelective.ActivePassIndices[0] = 0) and
      (LSelective.ActivePassIndices[1] = 2) and
      (LSelective.ActivePassIndices[2] = 3), 'Actual mapped dependency closure');
    CheckSameLayer(LBefore, LAfter, 1);
    Check((LAfter[3].Tokens[0] = '65') and (LAfter[3].Tokens[4] = '70') and
      (LAfter[3].Tokens[2] = 'rest'), 'Key edit respects independent rhythm');
    CheckLayerAudio(LBefore, LAfter, True, APartitioned);
    LBefore := LAfter;
    LReplacement := Learn(['G', 'C'], ['Bb', 'F'], 2);
    Check(LSession.TryReplaceModel('harmony', LReplacement, 918, LAfter, LReplaced),
      'Model replacement retains time grids and mapped relations');
    CheckSameLayer(LBefore, LAfter, 0);
    CheckSameLayer(LBefore, LAfter, 1);
    Check((LAfter[3].Tokens[0] = '70') and (LAfter[3].Tokens[4] = '65'),
      'Replaced harmony changes dependent voice at the declared bar boundary');
    LBefore := LAfter;
    LSession.SetConstraints('voice', [MakeWfcSequenceTokenConstraint(0, ['60'])]);
    Check(not LSession.TryRegenerate(['voice'], 211, LAfter, LSelective),
      'Mapped descendant cannot rewrite fixed key or rhythm');
    for LIndex := 0 to 3 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
    end;
    LSession.SetConstraints('voice', nil);
    Check(LSession.TryRegenerate(['voice'], 211, LAfter, LSelective), 'Mapped failure recovery');
    LOptions.TimeGrids[0] := MakeLayerTimeGrid(0, 1920);
    LOptions.TimeGrids[1] := MakeLayerTimeGrid(0, 240);
    LOptions.Scopes[1] := MakeLayerScope(8, wseWhole);
    if APartitioned then
    begin
      LOptions.TimeGrids[2] := MakeLayerTimePartition([0, 840, 1920]);
      LOptions.TimeGrids[3] := MakeLayerTimePartition(
        [0, 120, 360, 720, 960, 1200, 1560, 1800, 1920]);
      LOptions.TimeGrids[1] := MakeLayerTimePartition(
        [0, 120, 360, 720, 960, 1200, 1560, 1800, 1920]);
    end;
    LMaps[0].TimeMapping := ltmWholeCell;
    LMaps[2].TimeMapping := ltmCellIndex;
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Mapped and ordinary projection bindings remain conjunctive');
    for LIndex := 0 to 7 do
    begin
      LExpected := 'rest';
      if LIndex mod 2 = 0 then
      begin
        if LIndex < 4 then
        begin
          LExpected := '60';
        end
        else
        begin
          LExpected := '67';
        end;
      end;
      Check(LAfter[3].Tokens[LIndex] = LExpected, 'Mixed mapped/index provider oracle');
    end;
    WriteLn('Explicit 1/4/2/8-cell key/rhythm/harmony/voice grids, conjunctive maps, selective edits and replacement pass');
  finally
    LReplacement.Free;
    LSession.Free;
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
  end;
end;

procedure RunMappingEdges;
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LIndex: Integer;
  LRejected: Boolean;
  LLarge: TWfcSequenceModel;
  LTokens: TWfcModelTokens;
begin
  SetLength(LLayers, 2);
  LLarge := nil;
  try
    LLayers[0].Model := Learn(['C', 'G', 'C', 'G'], ['C', 'G', 'C', 'G'], 2);
    LLayers[1].Model := Learn(['c'], ['g'], 1);
    SetLock(LLayers[0], 'C');
    LOptions := DefaultLayerGenerationOptions;
    LOptions.Scopes := [MakeLayerScope(2, wsePrefix), MakeLayerScope(1, wsePrefix)];
    LOptions.TimeGrids := [MakeLayerTimeGrid(-480, 480), MakeLayerTimeGrid(-240, 480)];
    SetLength(LMaps, 1);
    LMaps[0].Provider := 0;
    LMaps[0].Consumer := 1;
    LMaps[0].TimeMapping := ltmStartTick;
    LMaps[0].Rules := [MakeWfcSequenceProjectionRule('c', ['C']),
      MakeWfcSequenceProjectionRule('g', ['G'])];
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LBefore, LReport), 'Negative-origin point map');
    Check(LBefore[1].Tokens[0] = 'c', 'Start tick samples first provider cell');
    LAfter := LBefore;
    LMaps[0].TimeMapping := ltmWholeCell;
    Check(not TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Whole consumer cell crosses incompatible provider values');
    Check(LReport.Status = gnsContradiction, 'Coverage conflict is a solver contradiction');
    CheckSameLayer(LBefore, LAfter, 1);
    LMaps[0].Rules[0] := MakeWfcSequenceProjectionRule('c', ['C', 'G']);
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Whole-cell alternatives must admit every overlapped provider');
    Check(LAfter[1].Tokens[0] = 'c', 'All-match coverage admits both distinct cells');
    LOptions.TimeGrids[1].OriginTick := 240;
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Partial bounded coverage rejects before solving');
    LMaps[0].TimeMapping := ltmStartTick;
    LMaps[0].Rules[0] := MakeWfcSequenceProjectionRule('c', ['C']);
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Point semantics explicitly permit a gate beyond sampled context');
    Check(LAfter[1].Tokens[0] = 'g', 'Positive point maps to second provider cell');
    LOptions.TimeGrids[1].OriginTick := 480;
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Half-open provider endpoint cannot be silently held');
    LOptions.Scopes[0].Extent := wseWrap;
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport), 'Explicit wrapped point map');
    Check(LAfter[1].Tokens[0] = 'c', 'Wrapped endpoint samples first provider cell');
    LMaps[0].TimeMapping := ltmWholeCell;
    LMaps[0].Rules[0] := MakeWfcSequenceProjectionRule('c', ['C', 'G']);
    LOptions.TimeGrids[1].TicksPerCell := 2880;
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Wrapped coverage spans three periods without extending the model');
    Check(LAfter[1].Tokens[0] = 'c', 'Every distinct wrapped provider cell is admitted');
    LBefore := LAfter;
    LOptions.TimeGrids[1] := MakeLayerTimeGrid(High(Integer), 1);
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'World endpoint overflow rejects before graph construction');
    CheckSameLayer(LBefore, LAfter, 1);
    LOptions.TimeGrids := nil;
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Mapped relationships cannot infer a musical clock');
    SetLength(LTokens, 256);
    for LIndex := 0 to High(LTokens) do
    begin
      LTokens[LIndex] := IntToStr(LIndex);
    end;
    LLarge := Learn(LTokens, LTokens, 1);
    LLayers[0].Model.Free;
    LLayers[0].Model := LLarge;
    LLarge := nil;
    LLayers[0].Constraints := nil;
    LOptions.Scopes[0] := MakeLayerScope(1, wsePrefix);
    LOptions.TimeGrids := [MakeLayerTimeGrid(0, 1), MakeLayerTimeGrid(0, 1)];
    LMaps[0].Rules := [MakeWfcSequenceProjectionRule('c', ['0']),
      MakeWfcSequenceProjectionRule('g', ['1'])];
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport);
    except
      on LException: Exception do
      begin
        LRejected := Pos('preparation exceeds work budget', LException.Message) > 0;
      end;
    end;
    Check(LRejected, 'Mapped public-domain preparation is preflight bounded');
    CheckSameLayer(LBefore, LAfter, 1);
    WriteLn('Start/whole-cell distinctions, negative origins, missing coverage, wrapped periods and work bounds pass');
  finally
    LLarge.Free;
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
  end;
end;

procedure RunPartitionEdges;
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LBounds: TLayerTickBoundaries;
  LGrid: TLayerTimeGrid;
  LIndex: Integer;
  LRejected: Boolean;

  procedure Reject(const AMessage: String);
  var
    LFailed: Boolean;
  begin
    LFailed := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport);
    except
      on EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, AMessage);
    CheckSameLayer(LBefore, LAfter, 1);
  end;

begin
  SetLength(LLayers, 2);
  try
    LLayers[0].Model := Learn(['C', 'G', 'C', 'G'], ['C', 'G', 'C', 'G'], 2);
    LLayers[1].Model := Learn(['c'], ['g'], 1);
    SetLock(LLayers[0], 'C');
    LOptions := DefaultLayerGenerationOptions;
    LOptions.Scopes := [MakeLayerScope(2, wsePrefix), MakeLayerScope(1, wseFragment)];
    LBounds := [-480, -120, 480];
    LGrid := MakeLayerTimePartition(LBounds);
    LBounds[1] := -480;
    Check(LGrid.Boundaries[1] = -120, 'Partition helper owns its boundary copy');
    LOptions.TimeGrids := [LGrid, MakeLayerTimePartition([-240, 120])];
    SetLength(LMaps, 1);
    LMaps[0].Provider := 0;
    LMaps[0].Consumer := 1;
    LMaps[0].TimeMapping := ltmStartTick;
    LMaps[0].Rules := [MakeWfcSequenceProjectionRule('c', ['C']),
      MakeWfcSequenceProjectionRule('g', ['G'])];
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LBefore, LReport), 'Partition start map');
    Check(LBefore[1].Tokens[0] = 'c', 'Negative attack samples first irregular interval');
    LAfter := LBefore;
    LMaps[0].TimeMapping := ltmWholeCell;
    Check(not TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Partition whole span intersects incompatible provider cells');
    Check(LReport.Status = gnsContradiction, 'Partition crossing is a contradiction');
    CheckSameLayer(LBefore, LAfter, 1);
    LOptions.TimeGrids[1] := MakeLayerTimePartition([-480, -120]);
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Half-open span ending at provider boundary excludes the next cell');
    Check(LAfter[1].Tokens[0] = 'c', 'Exact-end whole span oracle');
    LMaps[0].TimeMapping := ltmStartTick;
    LOptions.TimeGrids[1] := MakeLayerTimePartition([-120, 480]);
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Exact boundary attack samples the next cell');
    Check(LAfter[1].Tokens[0] = 'g', 'Exact-start point oracle');
    LBefore := LAfter;
    LOptions.TimeGrids[1] := MakeLayerTimePartition([480, 600]);
    Reject('Bounded endpoint is outside half-open provider');
    LOptions.Scopes[0].Extent := wseWrap;
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Wrapped endpoint maps to first partition');
    Check(LAfter[1].Tokens[0] = 'c', 'Wrapped endpoint oracle');
    LBefore := LAfter;
    LMaps[0].TimeMapping := ltmWholeCell;
    LOptions.TimeGrids[1] := MakeLayerTimePartition([360, 600]);
    Check(not TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Wrapped seam intersects both unequal provider cells');
    Check(LReport.Status = gnsContradiction, 'Wrapped seam contradiction');
    LMaps[0].Rules[0] := MakeWfcSequenceProjectionRule('c', ['C', 'G']);
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Wrapped seam admits the conjunction');
    LOptions.TimeGrids[1] := MakeLayerTimePartition([Low(Integer), High(Integer)]);
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Signed Int32 extreme span covers many wrapped periods using Int64 arithmetic');
    Check(LAfter[1].Tokens[0] = 'c', 'All provider values must admit extreme span');
    LOptions.Scopes[0].Extent := wsePrefix;
    LOptions.TimeGrids[0] := MakeLayerTimePartition([Low(Integer), 0, High(Integer)]);
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Bounded extreme provider span uses exact endpoints');
    LBefore := LAfter;
    LOptions.TimeGrids[1].TicksPerCell := 1;
    Reject('Partition cannot also declare a uniform width');
    LOptions.TimeGrids[1].TicksPerCell := 0;
    LOptions.TimeGrids[1].OriginTick := 1;
    Reject('Partition cannot also declare a uniform origin');
    LOptions.TimeGrids[1] := MakeLayerTimePartition([0, 1, 2]);
    Reject('Partition requires exactly count+1 boundaries');
    LOptions.TimeGrids[1] := MakeLayerTimePartition([0, 1]);
    LOptions.TimeGrids[1].Boundaries[1] := 0;
    Reject('Mutated nonincreasing partition rejects before solving');
    LRejected := False;
    try
      LGrid := MakeLayerTimePartition([1, 1]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Helper rejects zero-length cells');
    LOptions.TimeGrids := [MakeLayerTimePartition([0, 120, 480]),
      MakeLayerTimePartition([0, 121, 480])];
    LOptions.Scopes[1] := MakeLayerScope(2, wseFragment);
    LMaps[0].TimeMapping := ltmCellIndex;
    Reject('Same-position mapping requires identical partition boundaries');
    LOptions.TimeGrids[1] := MakeLayerTimePartition([0, 120, 480]);
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport),
      'Identical partitions permit same-position relationships');
    WriteLn('Partition ownership, half-open spans, wrapped seams, signed extremes and invalid declarations pass');
  finally
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
  end;
end;

procedure RunPartitionExtents;
var
  LLayers: TLearnedLayers;
  LOptions: TLayerGenerationOptions;
  LOrdinary: TLayerSequences;
  LPositioned: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LExtent: TWfcSequenceExtent;
  LCount: Integer;
  LIndex: Integer;
  LOriginalSolved: Boolean;
  LPartitionSolved: Boolean;
  LBoundaries: TLayerTickBoundaries;
begin
  SetLength(LLayers, 1);
  LLayers[0].Model := Learn(['a', 'b', 'a', 'b', 'a', 'b'],
    ['a', 'b', 'a', 'b', 'a', 'b'], 3);
  try
    LOptions := DefaultLayerGenerationOptions;
    for LExtent := Low(TWfcSequenceExtent) to High(TWfcSequenceExtent) do
    begin
      for LCount := 1 to 8 do
      begin
        LOptions.CellCount := LCount;
        LOptions.Extent := LExtent;
        LOptions.TimeGrids := nil;
        LOriginalSolved := TryGenerateLayers(LLayers, nil, LOptions, LOrdinary, LReport);
        Check(LOriginalSolved or (LReport.Status = gnsContradiction),
          'Extent control reaches a terminal decision');
        SetLength(LBoundaries, LCount + 1);
        for LIndex := 0 to LCount do
        begin
          LBoundaries[LIndex] := LIndex * LIndex * 120;
        end;
        LOptions.TimeGrids := [MakeLayerTimePartition(LBoundaries)];
        LPartitionSolved := TryGenerateLayers(LLayers, nil, LOptions, LPositioned, LReport);
        Check(LOriginalSolved = LPartitionSolved, 'Partition compiler preserves extent feasibility');
        Check(LPartitionSolved or (LReport.Status = gnsContradiction),
          'Partition extent reaches the same terminal decision');
      end;
    end;
    WriteLn('Order-three partition paths agree with original adapter over all five extents and 1..8 cells');
  finally
    LLayers[0].Model.Free;
  end;
end;

procedure RunPartitionBudgets;
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LSession: TLearnedLayerSession;
  LLarge: TWfcSequenceModel;
  LTokens: TWfcModelTokens;
  LBoundaries: TLayerTickBoundaries;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LCopy: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LReplaced: TLayerModelReplacementReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LSession := nil;
  LLarge := nil;
  SetLength(LLayers, 2);
  try
    LLayers[0].Model := Learn(['a', 'a'], ['a', 'a'], 1);
    LLayers[1].Model := Learn(['b'], ['b'], 1);
    SetLength(LBoundaries, 65);
    for LIndex := 0 to High(LBoundaries) do
    begin
      LBoundaries[LIndex] := LIndex;
    end;
    LOptions := DefaultLayerGenerationOptions;
    LOptions.Scopes := [MakeLayerScope(64, wseFragment), MakeLayerScope(1, wseWhole)];
    LOptions.TimeGrids := [MakeLayerTimePartition(LBoundaries), MakeLayerTimeGrid(0, 64)];
    LSession := TLearnedLayerSession.Create(LLayers, nil, ['base', 'other'], LOptions);
    Check(LSession.TryGenerate(LBefore, LReport), 'Partition budget baseline');
    LAfter := LSession.CopyAccepted;
    SetLength(LTokens, 32);
    LTokens[0] := 'a';
    for LIndex := 1 to High(LTokens) do
    begin
      LTokens[LIndex] := IntToStr(LIndex);
    end;
    LLarge := Learn(LTokens, LTokens, 1);
    LSession.SetConstraints('base', [MakeWfcSequenceTokenConstraint(0, ['a'])]);
    LRejected := False;
    try
      LSession.TryReplaceModel('base', LLarge, 731, LAfter, LReplaced);
    except
      on LException: EAudio do
      begin
        LRejected := Pos('value budget exceeded', LException.Message) > 0;
      end;
    end;
    Check(LRejected, 'Expanded model replacement rejects before candidate construction');
    LCopy := LSession.CopyAccepted;
    for LIndex := 0 to 1 do
    begin
      CheckSameLayer(LBefore, LAfter, LIndex);
      CheckSameLayer(LBefore, LCopy, LIndex);
    end;
    Check(LSession.TryRegenerate(['other'], 731, LAfter, LSelective),
      'Oversized replacement retains usable old model and pending masks');
    Check(Length(LSelective.ActivePassIndices) = 2, 'Pending provider edit survives resource rejection');
    FreeAndNil(LSession);
    LLayers[0].Model.Free;
    LLayers[0].Model := LLarge;
    LLarge := nil;
    LLayers[1].Model.Free;
    LLayers[1].Model := Learn(LTokens, LTokens, 1);
    SetLength(LBoundaries, 33);
    LOptions.Scopes := [MakeLayerScope(32, wseFragment), MakeLayerScope(32, wseFragment)];
    LOptions.TimeGrids := [MakeLayerTimePartition(LBoundaries), MakeLayerTimeGrid(0, 1)];
    LRejected := False;
    try
      TryGenerateLayers(LLayers, nil, LOptions, LAfter, LReport);
    except
      on LException: EAudio do
      begin
        LRejected := Pos('Combined position-expanded', LException.Message) > 0;
      end;
    end;
    Check(LRejected, 'Individually valid expanded layers exceed aggregate matrix budget');
    CheckSameLayer(LBefore, LAfter, 0);
    for LIndex := 0 to High(LLayers) do
    begin
      FreeAndNil(LLayers[LIndex].Model);
    end;
    SetLength(LLayers, 7);
    SetLength(LOptions.Scopes, 7);
    SetLength(LOptions.TimeGrids, 7);
    SetLength(LMaps, 6);
    for LIndex := 0 to 6 do
    begin
      LLayers[LIndex].Model := Learn(['a', 'a'], ['a', 'a'], 1);
      LOptions.Scopes[LIndex] := MakeLayerScope(64, wseWrap);
      LOptions.TimeGrids[LIndex] := MakeLayerTimeGrid(0, 1);
      if LIndex < 6 then
      begin
        LMaps[LIndex].Provider := LIndex;
        LMaps[LIndex].Consumer := 6;
        LMaps[LIndex].TimeMapping := ltmWholeCell;
        LMaps[LIndex].Rules := [MakeWfcSequenceProjectionRule('a', ['a'])];
      end;
    end;
    SetLength(LBoundaries, 65);
    for LIndex := 0 to High(LBoundaries) do
    begin
      LBoundaries[LIndex] := LIndex;
    end;
    LOptions.TimeGrids[0] := MakeLayerTimePartition(LBoundaries);
    LOptions.Scopes[6] := MakeLayerScope(256, wseFragment);
    LOptions.TimeGrids[6] := MakeLayerTimeGrid(0, 64);
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport);
    except
      on LException: EAudio do
      begin
        LRejected := Pos('requirement budget exceeded', LException.Message) > 0;
      end;
    end;
    Check(LRejected, 'All-overlap mapped clauses have an aggregate preflight bound');
    CheckSameLayer(LBefore, LAfter, 0);
    WriteLn('Expanded value, aggregate matrix and mapped-clause budgets reject atomically; pending edits recover');
  finally
    LSession.Free;
    LLarge.Free;
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
  end;
end;

procedure RunScopes;
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LSession: TLearnedLayerSession;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LIndex: Integer;
  LRejected: Boolean;
  LToken: String;
begin
  SetLength(LLayers, 3);
  LSession := nil;
  try
    LLayers[0].Model := Learn(['C', 'C'], ['F', 'F'], 3);
    LLayers[1].Model := Learn(['slow', 'fast', 'slow'], ['fast', 'slow', 'fast'], 2);
    LLayers[2].Model := Learn(['on', 'off', 'on', 'off'], ['off', 'on', 'off', 'on'], 2);
    LOptions := DefaultLayerGenerationOptions;
    SetLength(LOptions.Scopes, 3);
    LOptions.Scopes[0] := MakeLayerScope(1, wsePrefix);
    LOptions.Scopes[1] := MakeLayerScope(3, wseWhole);
    LOptions.Scopes[2] := MakeLayerScope(6, wseWrap);
    LOptions.CellCount := 0; { Explicit scopes replace the shared default extent. }
    LSession := TLearnedLayerSession.Create(LLayers, nil, ['key', 'tempo', 'performance'], LOptions);
    LOptions.Scopes[0].CellCount := 9;
    Check(LSession.TryGenerate(LBefore, LReport), 'Independent actual WFC pass layouts solve');
    Check((Length(LBefore[0].Tokens) = 1) and (Length(LBefore[1].Tokens) = 3) and
      (Length(LBefore[2].Tokens) = 6), 'Session owns distinct per-layer scopes');
    LToken := 'on';
    if LBefore[2].Tokens[5] = LToken then
    begin
      LToken := 'off';
    end;
    LSession.SetConstraints('performance', [MakeWfcSequenceTokenConstraint(5, [LToken])]);
    Check(LSession.TryRegenerate(['performance'], 731, LAfter, LSelective),
      'Longest layer permits a constraint at its own final cell');
    Check((Length(LSelective.ActivePassIndices) = 1) and
      (LSelective.ActivePassIndices[0] = 2) and (LAfter[2].Tokens[5] = LToken),
      'Scoped edit reaches the actual selected pass');
    CheckSameLayer(LBefore, LAfter, 0);
    CheckSameLayer(LBefore, LAfter, 1);
    LRejected := False;
    try
      LSession.SetConstraints('key', [MakeWfcSequenceTokenConstraint(1, ['C'])]);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Short provider rejects a constraint outside its scope');
    LBefore := LSession.CopyAccepted;
    CheckSameLayer(LBefore, LAfter, 0);
    LOptions.Scopes[0].CellCount := 1;
    SetLength(LMaps, 1);
    LMaps[0].Provider := 0;
    LMaps[0].Consumer := 2;
    LMaps[0].Rules := [MakeWfcSequenceProjectionRule('on', ['C']),
      MakeWfcSequenceProjectionRule('off', ['F'])];
    LRejected := False;
    try
      TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unequal scopes cannot use an implicit same-position projection');
    CheckSameLayer(LBefore, LAfter, 2);
    SetLength(LOptions.Scopes, 2);
    LRejected := False;
    try
      TryGenerateLayers(LLayers, nil, LOptions, LAfter, LReport);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Every explicit scope must identify one layer');
    WriteLn('Independent 1/3/6-cell prefix/whole/wrapped passes, owned scopes and selective edits pass');
  finally
    LSession.Free;
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
  end;
end;

begin
  try
    Run;
    RunSession;
    RunScopes;
    RunReplacement;
    RunTimeMaps;
    RunMappingEdges;
    WriteLn('Position-compiled session controls:');
    RunReplacement(True);
    RunTimeMaps(True);
    RunPartitionEdges;
    RunPartitionExtents;
    RunPartitionBudgets;
    RunPreferences(False);
    RunPreferences(True);
    RunPreferencePreparationBound;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
