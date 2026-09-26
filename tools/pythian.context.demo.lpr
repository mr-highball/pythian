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
program pythian_context_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.time,
  pythian.tonal,
  pythian.music,
  pythian.music.context,
  pythian.music.render,
  pythian.synth,
  pythian.wave,
  pythian.hash,
  pythian.wfc.context,
  pythian.wfc.context.archive,
  pythian.wfc.context.profile,
  pythian.wfc.layers,
  pythian.tools.files,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_sequence_learn;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Run(const APrefix: String);
const
  CCells = 8;
  CPPQ = 480;
  CStep = 240;
  CRate = 24000;
  CNames: array[0..3] of String = ('c-fast', 'd-fast', 'c-slow', 'd-slow');
var
  LGrids: TMusicContextGrids;
  LEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LSourceProfiles: array[0..2] of TContextProfile;
  LProfiles: array[0..1] of TContextProfile;
  LProfileBytes: TAudioBytes;
  LBytes: TAudioBytes;
  LSourceText: UTF8String;
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LOptions: TLayerGenerationOptions;
  LGenerated: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LContext: TMusicContext;
  LClock: TTempoMap;
  LKeys: TKeyChanges;
  LGates: TNoteGates;
  LNotes: TNoteSequence;
  LVoice: TSynthVoice;
  LClip: TAudioClip;
  LRenderReport: TNoteRenderReport;
  LKey: TKeyContext;
  LTempo: Integer;
  LPitch: Integer;
  LGateTicks: Integer;
  LExpectedFrames: Int64;
  LVariant: Integer;
  LSample: Integer;
  LCell: Integer;
  LLayer: Integer;
begin
  SetLength(LGrids, 2);
  SetLength(LLayers, 4);
  SetLength(LMaps, 2);
  LContext := nil;
  LClock := nil;
  LNotes := nil;
  LClip := nil;
  LBundle := nil;
  for LSample := 0 to 2 do
  begin
    LSourceProfiles[LSample] := nil;
  end;
  LProfiles[0] := nil;
  LProfiles[1] := nil;
  try
    { Two authored, explicitly admitted context excerpts, not WAV key inference.
      Source A: C major and 500001 us/quarter; B: D minor and 600001. }
    SetLength(LKeys, 1);
    for LSample := 0 to 1 do
    begin
      LClock := TTempoMap.Create(CPPQ, CCells * CStep,
        [MakeTempoChange(0, 500001 + LSample * 100000)]);
      LKeys[0].Key := MakeKeyContext(LSample * 2, TDiatonicMode(LSample));
      LContext := TMusicContext.Create(LClock, LKeys);
      LGrids[LSample] := LContext.Grid(0, CStep, CCells);
      FreeAndNil(LContext);
      FreeAndNil(LClock);
    end;
    SetLength(LEvidence, 2);
    for LSample := 0 to 1 do
    begin
      LSourceText := 'Authored context declaration v1' + #10 +
        'ppq=480; step_ticks=240; cells=8; start_tick=0' + #10 +
        'key_root=' + IntToStr(LSample * 2) + '; mode_ordinal=' + IntToStr(LSample) + #10 +
        'tempo_us_per_quarter=' + IntToStr(500001 + LSample * 100000) + #10;
      SetLength(LBytes, Length(LSourceText));
      Move(LSourceText[1], LBytes[0], Length(LSourceText));
      WriteFileBytes(APrefix + '.source-' + IntToStr(LSample) + '.txt', LBytes);
      LEvidence[LSample].Name := 'Authored context ' + IntToStr(LSample);
      LEvidence[LSample].SourceSha256 := Sha256Bytes(LBytes);
      LEvidence[LSample].AdmissionPolicy := 'Explicit authored declaration; no WAV inference';
      LEvidence[LSample].Grid := LGrids[LSample];
    end;
    LBundle := TContextLearningBundle.Create(LEvidence);
    LBytes := EncodeContextLearning(LBundle);
    WriteFileBytes(APrefix + '.ptc', LBytes);
    FreeAndNil(LBundle);
    LGrids := nil;
    LEvidence := nil;
    LBytes := nil;
    { Reload from disk after releasing original evidence/models. Source files
      are independently rebound to the saved hashes before this demo uses them. }
    LBytes := ReadFileBytes(APrefix + '.ptc', MaximumContextArchiveBytes);
    LBundle := DecodeContextLearning(LBytes);
    Check(Sha256Bytes(EncodeContextLearning(LBundle)) = Sha256Bytes(LBytes),
      'Context bundle must round-trip exactly from disk');
    Check((LBundle.TicksPerQuarter = CPPQ) and (LBundle.StepTicks = CStep),
      'Saved context timing must match this demo consumer');
    LEvidence := LBundle.CopyEvidence;
    for LSample := 0 to High(LEvidence) do
    begin
      Check(Sha256Bytes(ReadFileBytes(APrefix + '.source-' + IntToStr(LSample) + '.txt', 4096)) =
        LEvidence[LSample].SourceSha256, 'Saved source identity must match actual declaration bytes');
    end;
    LSourceProfiles[2] := TContextProfile.Create(LBundle);
    FreeAndNil(LBundle);
    for LSample := 0 to 1 do
    begin
      LBundle := TContextLearningBundle.Create(Copy(LEvidence, LSample, 1));
      LSourceProfiles[LSample] := TContextProfile.Create(LBundle);
      FreeAndNil(LBundle);
    end;
    { First select keys from the two-source profile and tempo from source B.
      Reuse that derived result, replacing only tempo with source A. }
    LProfiles[1] := SelectContextProfile(LSourceProfiles[2], LSourceProfiles[1]);
    LProfiles[0] := SelectContextProfile(LProfiles[1], LSourceProfiles[0]);
    Check((LProfiles[0].ParentIdentity(cdKey) = LProfiles[1].Identity) and
      (LProfiles[0].ProviderIdentity(cdKey) = LSourceProfiles[2].ProviderIdentity(cdKey)) and
      (LProfiles[0].ProviderIdentity(cdTempo) = LSourceProfiles[0].ProviderIdentity(cdTempo)),
      'Second selection must retain parent lineage and replace only tempo');
    for LSample := 0 to 1 do
    begin
      WriteFileBytes(APrefix + '.profile-' + IntToStr(LSample) + '.pcp',
        EncodeContextProfile(LProfiles[LSample]));
      FreeAndNil(LProfiles[LSample]);
    end;
    for LSample := 0 to 2 do
    begin
      FreeAndNil(LSourceProfiles[LSample]);
    end;
    for LSample := 0 to 1 do
    begin
      LProfileBytes := ReadFileBytes(APrefix + '.profile-' + IntToStr(LSample) + '.pcp',
        MaximumContextProfileBytes);
      LProfiles[LSample] := DecodeContextProfile(LProfileBytes);
      Check(LProfiles[LSample].Identity = Sha256Bytes(LProfileBytes),
        'Saved derived profile must retain exact identity');
    end;
    WriteLn('Reloaded context bundle from disk; source hashes, timing and both actual models verified.');
    WriteLn('Reloaded two-stage context profiles with complete parents; key and tempo selected independently.');
    { Small independent bass and gate vocabularies with explicit dependencies.
      No joint key/tempo constraint is requested in this example. }
    SetLength(LSamples, 2);
    SetLength(LTokens, CCells);
    for LSample := 0 to 1 do
    begin
      for LCell := 0 to CCells - 1 do
      begin
        LTokens[LCell] := IntToStr(48 + LSample * 2);
      end;
      LSamples[LSample] := MakeWfcSequenceSample(LTokens);
    end;
    LLayers[2].Model := LearnSequenceModelCorpus(LSamples, 2, wmbOpen);
    LMaps[0].Provider := 0;
    LMaps[0].Consumer := 2;
    SetLength(LMaps[0].Rules, 2);
    LMaps[0].Rules[0] := MakeWfcSequenceProjectionRule('48',
      [KeyContextToken(MakeKeyContext(0, dmMajor))]);
    LMaps[0].Rules[1] := MakeWfcSequenceProjectionRule('50',
      [KeyContextToken(MakeKeyContext(2, dmNaturalMinor))]);
    LMaps[1].Provider := 1;
    LMaps[1].Consumer := 3;
    SetLength(LMaps[1].Rules, 1);
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := CCells;
    LOptions.Extent := wseWhole;
    SetLength(LLayers[0].Constraints, 1);
    SetLength(LLayers[1].Constraints, 1);
    LVoice := DefaultSynthVoice;
    LVoice.Envelope.ReleaseSeconds := 0;
    SetLength(LGates, CCells);
    for LVariant := 0 to 3 do
    begin
      FreeAndNil(LLayers[0].Model);
      FreeAndNil(LLayers[1].Model);
      LLayers[0].Model := LProfiles[LVariant div 2].CopyModel(cdKey);
      LLayers[1].Model := LProfiles[LVariant div 2].CopyModel(cdTempo);
      LKey := MakeKeyContext((LVariant mod 2) * 2, TDiatonicMode(LVariant mod 2));
      LTempo := 500001 + (LVariant div 2) * 100000;
      LPitch := 48 + (LVariant mod 2) * 2;
      LGateTicks := 240 - (LVariant div 2) * 120;
      { Recompile this authored dependent gate vocabulary for the selected
        tempo provider. WFC requires complete maps using existing source tokens. }
      FreeAndNil(LLayers[3].Model);
      for LCell := 0 to CCells - 1 do
      begin
        LTokens[LCell] := IntToStr(LGateTicks);
      end;
      SetLength(LSamples, 1);
      LSamples[0] := MakeWfcSequenceSample(LTokens);
      LLayers[3].Model := LearnSequenceModelCorpus(LSamples, 2, wmbOpen);
      LMaps[1].Rules[0] := MakeWfcSequenceProjectionRule(IntToStr(LGateTicks),
        [TempoContextToken(LTempo)]);
      LLayers[0].Constraints[0] := MakeWfcSequenceTokenConstraint(0, [KeyContextToken(LKey)]);
      LLayers[1].Constraints[0] := MakeWfcSequenceTokenConstraint(0, [TempoContextToken(LTempo)]);
      Check(TryGenerateLayers(LLayers, LMaps, LOptions, LGenerated, LReport),
        'Pinned context must solve through real WFC passes');
      for LCell := 0 to CCells - 1 do
      begin
        Check((LGenerated[0].Tokens[LCell] = KeyContextToken(LKey)) and
          (LGenerated[1].Tokens[LCell] = TempoContextToken(LTempo)) and
          (LGenerated[2].Tokens[LCell] = IntToStr(LPitch)) and
          (LGenerated[3].Tokens[LCell] = IntToStr(LGateTicks)),
          'Context pins must control declared descendants independently');
        LGates[LCell] := Default(TNoteGate);
        LGates[LCell].StartTick := LCell * CStep;
        LGates[LCell].EndTick := LGates[LCell].StartTick +
          StrToInt(LGenerated[3].Tokens[LCell]);
        LGates[LCell].Pitch := StrToInt(LGenerated[2].Tokens[LCell]);
        LGates[LCell].Velocity := 96;
        LGates[LCell].Channel := 0;
      end;
      LContext := MusicContextFromTokens(LGenerated[0].Tokens, LGenerated[1].Tokens, CPPQ, CStep);
      LClock := LContext.CopyClock;
      LNotes := TNoteSequence.Create(CPPQ, LClock.LengthTicks, LClock.CopyChanges, LGates);
      LClip := RenderNoteSequence(LNotes, CRate, LVoice, LRenderReport);
      LExpectedFrames := CCells * CStep;
      LExpectedFrames := LExpectedFrames * LTempo * CRate div (Int64(CPPQ) * 1000000);
      Check((LClip.FrameCount = LExpectedFrames) and (LRenderReport.RenderedNotes = CCells),
        'Generated tempo must control exact rendered duration');
      SaveWavePcm16(APrefix + '.' + CNames[LVariant] + '.wav', LClip);
      WriteLn(CNames[LVariant], ': ', LClip.FrameCount, ' stereo frames; pitch ',
        LPitch, '; gate ', LGateTicks, ' ticks; tempo ', LTempo, ' us/quarter');
      FreeAndNil(LClip);
      FreeAndNil(LNotes);
      FreeAndNil(LClock);
      FreeAndNil(LContext);
    end;
    WriteLn('Four actual WFC passes: key -> bass; tempo -> gate length and native output clock.');
  finally
    for LSample := 0 to 1 do
    begin
      LProfiles[LSample].Free;
    end;
    for LSample := 0 to 2 do
    begin
      LSourceProfiles[LSample].Free;
    end;
    LBundle.Free;
    LClip.Free;
    LNotes.Free;
    LClock.Free;
    LContext.Free;
    for LLayer := 0 to High(LLayers) do
    begin
      LLayers[LLayer].Model.Free;
    end;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.context.demo OUTPUT_PREFIX');
      Halt(2);
    end;
    Run(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      DumpExceptionBackTrace(StdErr);
      Halt(1);
    end;
  end;
end.
