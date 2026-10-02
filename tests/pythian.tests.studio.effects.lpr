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
program StudioEffectsConformance;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, fpjson,
  pythian.audio, pythian.hash, pythian.wave.stream, pythian.wave.read,
  pythian.effects, pythian.effects.catalog, pythian.effects.rack,
  pythian.tools.annotations.catalog, pythian.tools.studio.projects,
  pythian.tools.studio.jobs, pythian.tools.studio.effects;

var
  GChecks: Integer;
  GRoot: String;
  GCatalog: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function HashFile(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function MakeSource: String;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  LManifest: TJSONObject;
  LRow: TJSONObject;
  LReport: TJSONObject;
  LRows: TJSONArray;
  LIndex: Integer;
begin
  Check(ForceDirectories(GRoot + '/inbox'), 'Create source inbox');
  SetLength(LSamples, 32000);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := 0.45 * Sin(2 * Pi * 220 * LIndex / 8000) +
      0.2 * Sin(2 * Pi * 1900 * LIndex / 8000);
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LStream := TFileStream.Create(GRoot + '/inbox/control.wav', fmCreate);
    try
      WriteWavePcm16(LStream, LClip);
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
  Result := HashFile(GRoot + '/inbox/control.wav');
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LRows := TJSONArray.Create;
    LManifest.Add('tracks', LRows);
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('file', 'control.wav');
    LRow.Add('sha256', Result);
    LRow.Add('source_group', 'effects_authored_control');
    LRow.Add('clock_id', '');
    LRow.Add('partition', 'development');
    LRow.Add('title', 'Authored two-tone control');
    LRow.Add('provenance', 'Pascal oscillator fixture; no musical truth claim');
    LRow.Add('license', 'MIT');
    WriteStudioJSONNew(GRoot + '/inbox/manifest.json', LManifest);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(GRoot + '/inbox', GCatalog);
  try
    Check((LReport.Integers['imported'] = 1) and
      (LReport.Integers['failed'] = 0), 'Import native control');
  finally
    LReport.Free;
  end;
end;

function Preview(const AId, ASource: String; const AGain: Double;
  const ABypass: Boolean = False): TJSONObject;
var
  LEffects: TJSONArray;
  LEffect: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioJobWriteFormat);
  Result.Add('job_id', AId);
  Result.Add('kind', 'effect_preview');
  Result.Add('source_sha256', ASource);
  Result.Add('start_frame', 8000);
  Result.Add('end_frame', 24000);
  LEffects := TJSONArray.Create;
  Result.Add('effects', LEffects);
  LEffect := TJSONObject.Create;
  LEffects.Add(LEffect);
  LEffect.Add('kind', 'gain');
  LEffect.Add('bypass', ABypass);
  LEffect.Add('gain_db', AGain);
end;

function Execute(const AWrite: TJSONObject): TJSONObject;
var
  LJob: TJSONObject;
begin
  LJob := EnqueueStudioJob(GCatalog, AWrite);
  LJob.Free;
  LJob := ClaimStudioJob(GCatalog, AWrite.Strings['job_id']);
  LJob.Free;
  Result := nil;
  try
    try
      if AWrite.Strings['kind'] = 'effect_preview' then
      begin
        Result := RenderStudioEffectPreview(GCatalog, AWrite.Strings['job_id'], AWrite);
      end
      else
      begin
        Result := SaveStudioEffectPreview(GCatalog, AWrite.Strings['job_id'],
          GRoot + '/library', AWrite);
      end;
      AdvanceStudioJob(GCatalog, AWrite.Strings['job_id'], 'completed', 'completed', 1, 1, Result);
    except
      Result.Free;
      Result := nil;
      AdvanceStudioJob(GCatalog, AWrite.Strings['job_id'], 'failed', 'failed', 0, 0,
        nil, 'test_failure', 'Controlled test failure');
      raise;
    end;
  finally
    ReleaseStudioWorker(GCatalog);
  end;
end;

function SaveWrite(const AId, APreview: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioJobWriteFormat);
  Result.Add('job_id', AId);
  Result.Add('kind', 'effect_save');
  Result.Add('preview_job_id', APreview);
  Result.Add('collection_name', 'new sounds');
  Result.Add('title', 'Processed control');
end;

procedure RejectPreview(const AWrite: TJSONObject; const AMessage: String);
var
  LResult: TJSONObject;
  LFailed: Boolean;
begin
  LFailed := False;
  try
    LResult := Execute(AWrite);
    LResult.Free;
  except
    on E: EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, AMessage);
end;

function GainStage(const ADb: Double): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('kind', 'gain');
  Result.Add('bypass', False);
  Result.Add('gain_db', ADb);
end;

function CompressorStage: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('kind', 'compressor');
  Result.Add('bypass', False);
  Result.Add('threshold_db', -12);
  Result.Add('ratio', 8);
  Result.Add('attack_ms', 0);
  Result.Add('release_ms', 100);
  Result.Add('makeup_db', 0);
end;

function LimiterStage: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('kind', 'limiter');
  Result.Add('bypass', False);
  Result.Add('ceiling_db', -6);
  Result.Add('release_ms', 100);
end;

function FilterStage(const AKind: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('kind', AKind);
  Result.Add('bypass', False);
  Result.Add('frequency_hz', 600);
  if (AKind <> 'lowshelf') and (AKind <> 'highshelf') then
  begin
    Result.Add('q', 0.707);
  end;
end;

function ToneAmplitude(const AId: String; const AFrequency: Double): Double;
var
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LSamples: TAudioSamples;
  LHash: String;
  LSin: Double;
  LCos: Double;
  LAngle: Double;
  LIndex: Integer;
begin
  LStream := OpenStudioEffectPreview(GCatalog, AId, LHash);
  try
    LWave := TWaveFrameReader.Create(LStream);
    try
      Check((LWave.SampleRate = 8000) and (LWave.Channels = 2) and
        (LWave.FrameCount = 16000), 'Actual DSP control geometry');
      LWave.SeekFrame(8000);
      LSamples := LWave.ReadFrames(8000);
      LSin := 0;
      LCos := 0;
      for LIndex := 0 to 7999 do
      begin
        LAngle := 2 * Pi * AFrequency * LIndex / 8000;
        LSin := LSin + LSamples[LIndex * 2] * Sin(LAngle);
        LCos := LCos + LSamples[LIndex * 2] * Cos(LAngle);
      end;
      Result := 2 * Sqrt(Sqr(LSin) + Sqr(LCos)) / 8000;
    finally
      LWave.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure CheckExpandedFilters(const ASource: String);
const
  CKinds: array[0..5] of String = ('bandpass', 'notch', 'allpass',
    'peak', 'lowshelf', 'highshelf');
var
  LWrite: TJSONObject;
  LResult: TJSONObject;
  LStage: TJSONObject;
  LHash: String;
  LDryHash: String;
  LLow, LHigh: Double;
  LIndex: Integer;
begin
  LResult := ReadStudioJob(GCatalog, 'dry');
  try
    LDryHash := LResult.Objects['results'].Strings['output_sha256'];
  finally
    LResult.Free;
  end;
  for LIndex := 0 to High(CKinds) do
  begin
    LWrite := Preview('filter-' + CKinds[LIndex], ASource, 0);
    try
      LWrite.Arrays['effects'].Clear;
      LStage := FilterStage(CKinds[LIndex]);
      LWrite.Arrays['effects'].Add(LStage);
      if LIndex <= 3 then LStage.Floats['frequency_hz'] := 220;
      if LIndex in [0, 1, 3] then LStage.Floats['q'] := 2;
      if LIndex >= 3 then LStage.Add('gain_db', 6);
      LResult := Execute(LWrite);
      try
        LHash := LResult.Strings['output_sha256'];
        Check(LResult.Objects['recipe'].Arrays['effects'].AsJSON =
          LWrite.Arrays['effects'].AsJSON, 'Exact expanded filter recipe retained');
      finally
        LResult.Free;
      end;
      LLow := ToneAmplitude(LWrite.Strings['job_id'], 220);
      LHigh := ToneAmplitude(LWrite.Strings['job_id'], 1900);
      case LIndex of
        0: Check((LLow > 0.44) and (LHigh < 0.02), 'Bandpass retains center, rejects distant tone');
        1: Check((LLow < 0.001) and (LHigh > 0.19), 'Notch rejects center, retains distant tone');
        2: Check((Abs(LLow - 0.45) < 0.001) and (Abs(LHigh - 0.2) < 0.001) and
          (LHash <> LDryHash),
          'Allpass changes phase while preserving tone magnitudes');
        3: Check((LLow > 0.88) and (LHigh < 0.21), 'Peaking EQ boosts chosen band');
        4: Check((LLow > 0.85) and (LHigh < 0.21), 'Low shelf boosts lows');
        5: Check((LLow < 0.48) and (LHigh > 0.38), 'High shelf boosts highs');
      end;
      LWrite.Strings['job_id'] := 'replay-' + CKinds[LIndex];
      LResult := Execute(LWrite);
      try
        Check(LResult.Strings['output_sha256'] = LHash, 'Expanded filter deterministic replay');
      finally
        LResult.Free;
      end;
      LStage.Floats['frequency_hz'] := 3999.92;
      LWrite.Strings['job_id'] := 'upper-' + CKinds[LIndex];
      LResult := Execute(LWrite);
      try
        Check(LResult.Strings['output_sha256'] <> '', 'Shared upper frequency bound renders');
      finally
        LResult.Free;
      end;
      LWrite.Strings['job_id'] := 'invalid-' + CKinds[LIndex];
      LStage.Booleans['bypass'] := True;
      LStage.Floats['frequency_hz'] := 4000;
      RejectPreview(LWrite, 'Bypass cannot hide source Nyquist violation');
      LWrite.Strings['job_id'] := 'margin-' + CKinds[LIndex];
      LStage.Floats['frequency_hz'] := 3999.99;
      RejectPreview(LWrite, 'Bypass preserves the core DSP frequency safety margin');
      LWrite.Strings['job_id'] := 'missing-' + CKinds[LIndex];
      LStage.Delete('frequency_hz');
      RejectPreview(LWrite, 'Missing filter parameter rejected before enqueue');
      if LIndex >= 3 then
      begin
        LStage.Add('frequency_hz', 600);
        LStage.Floats['gain_db'] := 25;
        RejectPreview(LWrite, 'EQ gain bound enforced even while bypassed');
        LStage.Delete('gain_db');
        RejectPreview(LWrite, 'Missing EQ gain cannot silently default');
      end;
    finally
      LWrite.Free;
    end;
  end;
end;

procedure CheckDSPOrder(const ASource: String);
var
  LWrite: TJSONObject;
  LResult: TJSONObject;
  LFirstHash: String;
  LFirstPeak: Double;
  LDryLow: Double;
  LDryHigh: Double;
  LLow: Double;
  LHigh: Double;
begin
  LDryLow := ToneAmplitude('dry', 220);
  LDryHigh := ToneAmplitude('dry', 1900);
  Check((Abs(LDryLow - 0.45) < 0.001) and (Abs(LDryHigh - 0.2) < 0.001),
    'Independent decoded-PCM projection recovers authored dry tones');
  CheckExpandedFilters(ASource);
  LWrite := Preview('gain-compressor', ASource, -12);
  try
    LWrite.Arrays['effects'].Add(CompressorStage);
    LResult := Execute(LWrite);
    try
      LFirstHash := LResult.Strings['output_sha256'];
      LFirstPeak := LResult.Floats['peak_before_encoding'];
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'compressor-gain';
    LWrite.Arrays['effects'].Clear;
    LWrite.Arrays['effects'].Add(CompressorStage);
    LWrite.Arrays['effects'].Add(GainStage(-12));
    LResult := Execute(LWrite);
    try
      Check(LResult.Strings['output_sha256'] <> LFirstHash,
        'Gain/compressor order changes actual nonlinear PCM');
      Check(LFirstPeak > LResult.Floats['peak_before_encoding'] + 0.01,
        'Compression before attenuation reduces measured peak');
      Check(LResult.Objects['recipe'].Floats['compressor_knee_db'] = 6,
        'Effective compressor knee persisted in recipe');
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'gain-limiter';
    LWrite.Arrays['effects'].Clear;
    LWrite.Arrays['effects'].Add(GainStage(12));
    LWrite.Arrays['effects'].Add(LimiterStage);
    LResult := Execute(LWrite);
    try
      LFirstHash := LResult.Strings['output_sha256'];
      Check((LResult.Int64s['clipped_samples'] = 0) and
        (LResult.Floats['peak_before_encoding'] <= Power(10, -6 / 20) + 0.00001),
        'Last limiter enforces actual output ceiling');
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'limiter-gain';
    LWrite.Arrays['effects'].Clear;
    LWrite.Arrays['effects'].Add(LimiterStage);
    LWrite.Arrays['effects'].Add(GainStage(12));
    LResult := Execute(LWrite);
    try
      Check((LResult.Strings['output_sha256'] <> LFirstHash) and
        (LResult.Int64s['clipped_samples'] > 0), 'Post-limiter gain remains audibly distinct and counted');
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'lowpass';
    LWrite.Arrays['effects'].Clear;
    LWrite.Arrays['effects'].Add(FilterStage('lowpass'));
    LResult := Execute(LWrite);
    LResult.Free;
    LLow := ToneAmplitude('lowpass', 220);
    LHigh := ToneAmplitude('lowpass', 1900);
    Check((LLow > 0.3) and (LHigh / LLow < LDryHigh / LDryLow * 0.3),
      'Lowpass removes high tone relative to low tone in actual saved PCM');
    LWrite.Strings['job_id'] := 'highpass';
    LWrite.Arrays['effects'].Clear;
    LWrite.Arrays['effects'].Add(FilterStage('highpass'));
    LResult := Execute(LWrite);
    LResult.Free;
    LLow := ToneAmplitude('highpass', 220);
    LHigh := ToneAmplitude('highpass', 1900);
    Check((LHigh > 0.15) and (LLow / LHigh < LDryLow / LDryHigh * 0.3),
      'Highpass removes low tone relative to high tone in actual saved PCM');
    LWrite.Strings['job_id'] := 'nyquist-reject';
    LWrite.Arrays['effects'].Objects[0].Floats['frequency_hz'] := 4000;
    RejectPreview(LWrite, 'Filter at actual source Nyquist rejects before DSP');
  finally
    LWrite.Free;
  end;
end;

procedure CheckFurtherDerivation(const AOriginal, AParent: String);
var
  LWrite: TJSONObject;
  LResult: TJSONObject;
  LTrack: TJSONObject;
  LChild: String;
begin
  LWrite := Preview('further-gain', AParent, -6);
  try
    LWrite.Int64s['start_frame'] := 0;
    LWrite.Int64s['end_frame'] := 16000;
    LResult := Execute(LWrite);
    try
      LChild := LResult.Strings['output_sha256'];
      Check((LChild <> AParent) and (LResult.Objects['recipe'].Strings['source_sha256'] = AParent),
        'Further processing binds immediate immutable parent');
    finally
      LResult.Free;
    end;
  finally
    LWrite.Free;
  end;
  LWrite := SaveWrite('further-save', 'further-gain');
  try
    LWrite.Strings['title'] := 'Second-generation processed control';
    LResult := Execute(LWrite);
    try
      Check((LResult.Strings['source_sha256'] = LChild) and
        (LResult.Strings['parent_source_sha256'] = AParent) and
        not LResult.Booleans['independent_recording'], 'Saved second generation retains dependent lineage');
    finally
      LResult.Free;
    end;
    LTrack := ReadCatalogTrack(GCatalog, LChild);
    try
      Check((LTrack.Strings['source_group'] = 'effects_authored_control') and
        (LTrack.Strings['partition'] = 'development') and
        (Pos(AParent, LTrack.Strings['provenance']) > 0), 'Derived child inherits original family and use');
    finally
      LTrack.Free;
    end;
    LTrack := ReadCatalogTrack(GCatalog, AParent);
    try
      Check(Pos(AOriginal, LTrack.Strings['provenance']) > 0,
        'Retained parent still traces original source rather than inventing independence');
    finally
      LTrack.Free;
    end;
  finally
    LWrite.Free;
  end;
end;

procedure SetSetting(var ASettings: TCatalogEffectSettings;
  const AKey: String; const AValue: Double);
var
  LDefinition: TEffectDefinition;
  LIndex: Integer;
begin
  LDefinition := EffectDefinition(ASettings.Kind);
  for LIndex := 0 to High(LDefinition.Parameters) do
  begin
    if LDefinition.Parameters[LIndex].Key = AKey then
    begin
      ASettings.Values[LIndex] := AValue;
      Exit;
    end;
  end;
  raise Exception.Create('Unknown test setting');
end;

function CatalogStage(const AKind: TCatalogEffect): TJSONObject;
var
  LDefinition: TEffectDefinition;
  LIndex: Integer;
begin
  LDefinition := EffectDefinition(AKind);
  Result := TJSONObject.Create;
  Result.Add('kind', LDefinition.Key);
  Result.Add('bypass', False);
  for LIndex := 0 to High(LDefinition.Parameters) do
  begin
    Result.Add(LDefinition.Parameters[LIndex].Key,
      LDefinition.Parameters[LIndex].DefaultValue);
  end;
end;

procedure CheckTimeEffects(const ASource: String);
var
  LKind: TCatalogEffect;
  LSettings: TCatalogEffectSettings;
  LEffect: TAudioEffect;
  LLeft: Double;
  LRight: Double;
  LValue: Double;
  LEnergy: Double;
  LFirst: array[0..7999] of Double;
  LFrame: Integer;
  LPass: Integer;
  LWrite: TJSONObject;
  LSave: TJSONObject;
  LResult: TJSONObject;
  LTrack: TJSONObject;
  LStage: TJSONObject;
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LSamples: TAudioSamples;
  LHash: String;
  LKey: String;
begin
  for LKind := ceDelay to ceReverb do
  begin
    LSettings := DefaultCatalogEffect(LKind);
    SetSetting(LSettings, 'mix', 1);
    if LKind = ceDelay then
    begin
      SetSetting(LSettings, 'delay_ms', 10);
      SetSetting(LSettings, 'feedback', 0.5);
    end;
    LEffect := CreateCatalogEffect(8000, LSettings);
    try
      for LPass := 0 to 1 do
      begin
        LEffect.Reset;
        LEnergy := 0;
        for LFrame := 0 to High(LFirst) do
        begin
          LValue := 0;
          if LFrame = 0 then
          begin
            LValue := 1;
          end;
          LEffect.Process(LValue, LValue, LLeft, LRight);
          LEnergy := LEnergy + Sqr(LLeft) + Sqr(LRight);
          if LPass = 0 then
          begin
            LFirst[LFrame] := LLeft;
          end
          else if LFirst[LFrame] <> LLeft then
          begin
            raise Exception.Create('Time effect Reset changed impulse replay');
          end;
        end;
        Check(LEnergy > 0.0001, 'Native time effect has impulse tail energy');
      end;
      Check(True, 'Native time effect deterministic reset over 8000 frames');
      if LKind = ceDelay then
      begin
        Check((LFirst[0] = 0) and (LFirst[79] = 0) and
          (LFirst[80] = 1) and (LFirst[160] = 0.5), 'Delay timing and feedback are exact');
      end;
    finally
      LEffect.Free;
    end;
    if LKind = ceDelay then
    begin
      SetSetting(LSettings, 'depth_ms', 5);
      LEffect := CreateCatalogEffect(8000, LSettings);
      try
        LEnergy := 0;
        for LFrame := 0 to 7999 do
        begin
          LValue := Sin(2 * Pi * 220 * LFrame / 8000);
          LEffect.Process(LValue, LValue, LLeft, LRight);
          LEnergy := LEnergy + Sqr(LLeft - LRight);
        end;
        Check(LEnergy > 1, 'Opposed delay modulation actually changes stereo timing');
      finally
        LEffect.Free;
      end;
    end;
    LKey := EffectDefinition(LKind).Key;
    LWrite := Preview('tail-' + LKey, ASource, 0);
    try
      LWrite.Arrays['effects'].Clear;
      LStage := CatalogStage(LKind);
      LWrite.Arrays['effects'].Add(LStage);
      LWrite.Add('tail_seconds', 0.5);
      LResult := Execute(LWrite);
      try
        LHash := LResult.Strings['output_sha256'];
        Check((LResult.Int64s['frame_count'] = 20000) and
          (LResult.Objects['recipe'].Int64s['tail_frames'] = 4000) and
          (LResult.Objects['recipe'].Int64s['start_frame'] = 8000) and
          (LResult.Objects['recipe'].Int64s['end_frame'] = 24000),
          'Tail changes output duration, never original source range');
      finally
        LResult.Free;
      end;
      LStream := OpenStudioEffectPreview(GCatalog, 'tail-' + LKey, LHash);
      try
        LReader := TWaveFrameReader.Create(LStream);
        try
          Check(LReader.FrameCount = 20000, 'Saved WAV includes exact requested tail');
          LReader.SeekFrame(16000);
          LSamples := LReader.ReadFrames(4000);
          LEnergy := 0;
          for LFrame := 0 to High(LSamples) do
          begin
            LEnergy := LEnergy + Sqr(LSamples[LFrame]);
          end;
          Check(LEnergy > 0.01, 'Appended PCM contains real effect tail, not silent padding');
        finally
          LReader.Free;
        end;
      finally
        LStream.Free;
      end;
      LWrite.Strings['job_id'] := 'tail-replay-' + LKey;
      LResult := Execute(LWrite);
      try
        Check(LResult.Strings['output_sha256'] = LHash, 'Tail preview deterministic replay');
      finally
        LResult.Free;
      end;
      LSave := SaveWrite('tail-save-' + LKey, 'tail-' + LKey);
      try
        LResult := Execute(LSave);
        try
          LTrack := ReadCatalogTrack(GCatalog, LResult.Strings['source_sha256']);
          try
            Check((LTrack.Int64s['frame_count'] = 20000) and
              (LTrack.Strings['source_group'] = 'effects_authored_control'),
              'Derived catalog clip retains full tail and original family');
          finally
            LTrack.Free;
          end;
        finally
          LResult.Free;
        end;
      finally
        LSave.Free;
      end;
      LWrite.Strings['job_id'] := 'tail-order-a-' + LKey;
      LWrite.Arrays['effects'].Add(LimiterStage);
      LResult := Execute(LWrite);
      try
        LHash := LResult.Strings['output_sha256'];
      finally
        LResult.Free;
      end;
      LWrite.Arrays['effects'].Exchange(0, 1);
      LWrite.Strings['job_id'] := 'tail-order-b-' + LKey;
      LResult := Execute(LWrite);
      try
        Check(LResult.Strings['output_sha256'] <> LHash,
          'Time effect and nonlinear limiter honor rack order');
      finally
        LResult.Free;
      end;
      LWrite.Arrays['effects'].Delete(0);
      LStage := LWrite.Arrays['effects'].Objects[0];
      LStage.Booleans['bypass'] := True;
      LWrite.Strings['job_id'] := 'tail-bypass-' + LKey;
      LResult := Execute(LWrite);
      LResult.Free;
      LStream := OpenStudioEffectPreview(GCatalog, 'tail-bypass-' + LKey, LHash);
      try
        LReader := TWaveFrameReader.Create(LStream);
        try
          LReader.SeekFrame(16000);
          LSamples := LReader.ReadFrames(4000);
          LEnergy := 0;
          for LFrame := 0 to High(LSamples) do
          begin
            LEnergy := LEnergy + Sqr(LSamples[LFrame]);
          end;
          Check(LEnergy = 0, 'Bypassed time effect contributes no tail');
        finally
          LReader.Free;
        end;
      finally
        LStream.Free;
      end;
      LWrite.Strings['job_id'] := 'tail-too-long-' + LKey;
      LWrite.Floats['tail_seconds'] := 10.001;
      RejectPreview(LWrite, 'Unbounded tail rejected');
      LWrite.Floats['tail_seconds'] := 0;
      LWrite.Strings['job_id'] := 'tail-invalid-' + LKey;
      LStage.Booleans['bypass'] := True;
      if LKind = ceDelay then
      begin
        LStage.Floats['delay_ms'] := 1;
        LStage.Floats['depth_ms'] := 2;
      end
      else
      begin
        LStage.Floats['decay_seconds'] := 11;
      end;
      RejectPreview(LWrite, 'Bypass cannot hide invalid time-effect settings');
    finally
      LWrite.Free;
    end;
  end;
end;

procedure Run;
var
  LSource: String;
  LFirstHash: String;
  LDryHash: String;
  LHash: String;
  LWrite: TJSONObject;
  LResult: TJSONObject;
  LTrack: TJSONObject;
  LStream: TFileStream;
  LByte: Byte;
  LFailed: Boolean;
begin
  Check(not DirectoryExists(GRoot), 'Use a fresh isolated fixture root');
  LSource := MakeSource;
  LWrite := Preview('gain', LSource, -6);
  try
    LResult := Execute(LWrite);
    try
      LFirstHash := LResult.Strings['output_sha256'];
      Check((LResult.Int64s['frame_count'] = 16000) and
        (LResult.Integers['sample_rate'] = 8000), 'Exact original range clock');
      Check(LResult.Integers['channels'] = 2, 'Declared stereo preview');
      Check(LResult.Int64s['clipped_samples'] = 0, 'Attenuated output not clipped');
      Check(LResult.Floats['peak_before_encoding'] < 0.34, 'Actual gain attenuates signal');
      Check(LResult.Objects['recipe'].Strings['source_group'] = 'effects_authored_control',
        'Recipe preserves source family');
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'replay';
    LResult := Execute(LWrite);
    try
      Check(LResult.Strings['output_sha256'] = LFirstHash, 'Byte-exact deterministic replay');
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'bypass';
    LWrite.Arrays['effects'].Objects[0].Booleans['bypass'] := True;
    LResult := Execute(LWrite);
    try
      LDryHash := LResult.Strings['output_sha256'];
      Check(LDryHash <> LFirstHash, 'Bypass changes processed audio');
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'dry';
    LWrite.Arrays['effects'].Clear;
    LResult := Execute(LWrite);
    try
      Check(LResult.Strings['output_sha256'] = LDryHash, 'Bypass equals empty rack');
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'bad-range';
    LWrite.Int64s['end_frame'] := 999999;
    RejectPreview(LWrite, 'Out-of-source range rejected');
  finally
    LWrite.Free;
  end;
  LWrite := Preview('clipping', LSource, 12);
  try
    LResult := Execute(LWrite);
    try
      Check(LResult.Int64s['clipped_samples'] > 0, 'Clipping counted honestly');
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'bad-gain';
    LWrite.Arrays['effects'].Objects[0].Floats['gain_db'] := 100;
    RejectPreview(LWrite, 'Out-of-bound gain rejected');
  finally
    LWrite.Free;
  end;
  LWrite := SaveWrite('save', 'gain');
  try
    LResult := Execute(LWrite);
    try
      Check(LResult.Strings['source_sha256'] = LFirstHash, 'Save publishes exact preview');
      Check(not LResult.Booleans['independent_recording'], 'Variant not independent recording');
      Check(FileExists(GRoot + '/library/collections/new sounds/' + LFirstHash + '.wav'),
        'Saved clip exists in chosen private collection');
    finally
      LResult.Free;
    end;
    LTrack := ReadCatalogTrack(GCatalog, LFirstHash);
    try
      Check((LTrack.Strings['source_group'] = 'effects_authored_control') and
        (LTrack.Strings['partition'] = 'development'), 'Saved family/use inherited');
      Check(Pos(LSource, LTrack.Strings['provenance']) > 0, 'Saved original lineage');
    finally
      LTrack.Free;
    end;
    LWrite.Strings['job_id'] := 'save-again';
    LResult := Execute(LWrite);
    try
      Check(LResult.Booleans['already_catalogued'], 'Explicit retry deduplicates source');
    finally
      LResult.Free;
    end;
    LWrite.Strings['job_id'] := 'bad-path';
    LWrite.Strings['collection_name'] := '../escape';
    RejectPreview(LWrite, 'Collection traversal rejected');
  finally
    LWrite.Free;
  end;
  LStream := OpenStudioSourceAudio(GCatalog, LSource);
  try
    Check(Sha256Stream(LStream, LStream.Size) = LSource, 'Original preserved after processing');
  finally
    LStream.Free;
  end;
  CheckDSPOrder(LSource);
  CheckFurtherDerivation(LSource, LFirstHash);
  CheckTimeEffects(LSource);
  LStream := OpenStudioEffectPreview(GCatalog, 'gain', LHash);
  try
    Check((LHash = LFirstHash) and (LStream.Size = 64044), 'Verified bounded preview playback');
  finally
    LStream.Free;
  end;
  LStream := TFileStream.Create(StudioJobDirectory(GCatalog, 'replay') + '/effect.wav', fmOpenReadWrite);
  try
    LStream.Position := 44;
    LStream.ReadBuffer(LByte, 1);
    LByte := LByte xor 1;
    LStream.Position := 44;
    LStream.WriteBuffer(LByte, 1);
  finally
    LStream.Free;
  end;
  LFailed := False;
  try
    LStream := OpenStudioEffectPreview(GCatalog, 'replay', LHash);
    LStream.Free;
  except
    on E: EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, 'Tampered preview cannot be played or saved');
end;

begin
  try
    Check(ParamCount = 1, 'Usage: studio effects test FRESH_ROOT');
    GRoot := ExpandFileName(ParamStr(1));
    GCatalog := GRoot + '/catalog';
    Run;
    WriteLn('PASS ', GChecks, ' Studio effects checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
