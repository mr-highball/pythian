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
program pythian_part_prepare;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, jsonparser, pythian.audio, pythian.hash,
  pythian.wave.read, pythian.wave.stream, pythian.tools.files;

const
  CByteLimit = 1073741824;
  CPolicyPath = 'docs/PART-PREPARATION.md';
  CSourcePath = 'tools/pythian.part.prepare.lpr';
  CArchiveHash = '6490dc83d8b59ccbe7e9e0304023af8e585d2065f9a5f5921952a273fac4a9b0';
  CFamilyDecisionHash = 'a8163978ed1cd303e79b39ed606e228676cde6a100908553e2f050214f155db5';
  CEvaluationMetadataHash = 'd8ce65e81c0d09c6445e4ff2a497647290ef5d0b8270401c830c58a12807182e';
  CEvaluationScoreHash = '0fedda3ebff9e0ffa5ba6462eec4f1f717e3602a34722327e975d24774aebd3d';

type
  TInput = class
  public
    Name: String;
    Stream: TFileStream;
    Reader: TWaveFrameReader;
    destructor Destroy; override;
  end;
  TInputs = array of TInput;
  TBlocks = array of TAudioSamples;

var
  GStart: QWord;
  GInputBytes: Int64;
  GOutputBytes: Int64;
  GInputs: TInputs;
  GArtifacts: TJSONArray;
  GDirectory: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure Budget;
begin
  Check(GetTickCount64 - GStart <= 180000, 'Preparation exceeds 180 seconds');
end;

destructor TInput.Destroy;
begin
  Reader.Free;
  Stream.Free;
  inherited;
end;

function SafeName(const AName: String; const APath: Boolean): Boolean;
var
  I: Integer;
begin
  Result := (AName <> '') and (Pos('..', AName) = 0) and
    (Pos('//', AName) = 0);
  if not Result then
  begin
    Exit;
  end;
  for I := 1 to Length(AName) do
  begin
    if not (AName[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.']) and
      not (APath and (AName[I] = '/') and (I > 1) and (I < Length(AName))) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidateSourceIdentity(const ABinding: TJSONObject): Boolean;
var
  LEvaluation: Boolean;
  LDecision: TJSONObject;
  LRow: TJSONObject;
  LDecisionCount: Integer;
  LMetadataCount: Integer;
  LScoreCount: Integer;
  I: Integer;
begin
  Check(ABinding.Strings['archive_sha256'] = CArchiveHash,
    'Unsupported source archive');
  LEvaluation := ABinding.Strings['exposure'] = 'reference-only-evaluation';
  if LEvaluation then
  begin
    Check((ABinding.Strings['group'] = 'BabySlakh-4603870-Track00002') and
      (ABinding.Strings['source_uuid'] = '0c3b7bf33cd3d67970ecfc06339bfc49'),
      'Unsupported evaluation family identity');
  end
  else
  begin
    Check((ABinding.Strings['exposure'] = 'development') and
      (ABinding.Strings['group'] = 'BabySlakh-4603870-Track00001') and
      (ABinding.Strings['source_uuid'] = '1a81ae092884234f3264e2f45927f00a'),
      'Unsupported source exposure/identity');
  end;
  Result := ABinding.Find('family_decision') <> nil;
  Check(not LEvaluation or Result, 'Evaluation requires the accepted family decision');
  if not Result then
  begin
    Exit;
  end;
  Check(ABinding.Find('family_decision').JSONType = jtObject,
    'Family decision must be a path/hash object');
  LDecision := ABinding.Objects['family_decision'];
  Check((LDecision.Strings['path'] = 'family-decision.md') and
    (LDecision.Strings['sha256'] = CFamilyDecisionHash),
    'Unsupported family decision');
  LDecisionCount := 0;
  LMetadataCount := 0;
  LScoreCount := 0;
  for I := 0 to ABinding.Arrays['auxiliary'].Count - 1 do
  begin
    LRow := ABinding.Arrays['auxiliary'].Objects[I];
    if LRow.Strings['path'] = 'family-decision.md' then
    begin
      Check(LRow.Strings['sha256'] = CFamilyDecisionHash,
        'Family decision auxiliary identity mismatch');
      Inc(LDecisionCount);
    end;
    if LRow.Strings['sha256'] = CEvaluationMetadataHash then
    begin
      Inc(LMetadataCount);
    end;
    if LRow.Strings['sha256'] = CEvaluationScoreHash then
    begin
      Inc(LScoreCount);
    end;
  end;
  Check(LDecisionCount = 1, 'Exactly one bound family decision auxiliary is required');
  if LEvaluation then
  begin
    Check((LMetadataCount = 1) and (LScoreCount = 1),
      'Evaluation requires its exact original metadata and score auxiliaries');
  end;
end;

function FileHash(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Check(LStream.Size <= CByteLimit, 'File exceeds byte bound');
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
  Budget;
end;

function Bind(const ARoot: String; const AEntry: TJSONObject): TInput;
var
  LName: String;
  I: Integer;
begin
  LName := AEntry.Strings['path'];
  Check(SafeName(LName, True), 'Unsafe source member path');
  for I := 0 to High(GInputs) do
  begin
    Check(LowerCase(GInputs[I].Name) <> LowerCase(LName), 'Duplicate source member');
  end;
  Result := TInput.Create;
  SetLength(GInputs, Length(GInputs) + 1);
  GInputs[High(GInputs)] := Result;
  Result.Name := LName;
  Result.Stream := TFileStream.Create(ARoot + LName, fmOpenRead or fmShareDenyWrite);
  Check(Result.Stream.Size <= CByteLimit - GInputBytes, 'Source closure exceeds 1 GiB');
  Inc(GInputBytes, Result.Stream.Size);
  Check(Sha256Stream(Result.Stream, Result.Stream.Size) = AEntry.Strings['sha256'],
    'Source identity mismatch: ' + LName);
  Result.Stream.Position := 0;
  Budget;
end;

procedure Artifact(const AName: String);
var
  LStream: TFileStream;
  LRow: TJSONObject;
begin
  LStream := TFileStream.Create(GDirectory + AName, fmOpenRead or fmShareDenyWrite);
  try
    Check(LStream.Size <= CByteLimit - GOutputBytes, 'Output closure exceeds 1 GiB');
    Inc(GOutputBytes, LStream.Size);
    LRow := TJSONObject.Create;
    GArtifacts.Add(LRow);
    LRow.Add('path', AName);
    LRow.Add('bytes', LStream.Size);
    LRow.Add('sha256', Sha256Stream(LStream, LStream.Size));
  finally
    LStream.Free;
  end;
  Budget;
end;

procedure CopyBound(const AStream: TStream; const AName: String);
var
  LOutput: TFileStream;
begin
  LOutput := TFileStream.Create(GDirectory + AName, fmCreate);
  try
    AStream.Position := 0;
    LOutput.CopyFrom(AStream, AStream.Size);
  finally
    LOutput.Free;
  end;
  Artifact(AName);
end;

function IntegerSample(const ASample: Single): Integer;
begin
  Result := Round(ASample * 32768);
  Check((Result >= -32768) and (Result <= 32767) and
    (ASample = Result / 32768), 'Expected exact PCM16 sample');
end;

function ScaledOracle(const ASource: Integer): Integer;
begin
  { Independent signed integer oracle for nearest, ties away from zero. }
  if ASource < 0 then
  begin
    Result := -((-ASource + 8) div 16);
  end
  else
  begin
    Result := (ASource + 8) div 16;
  end;
end;

procedure OpenWave(const AFile: TInput);
begin
  AFile.Stream.Position := 0;
  AFile.Reader := TWaveFrameReader.Create(AFile.Stream);
  Check((AFile.Reader.EncodingTag = 1) and (AFile.Reader.BitsPerSample = 16) and
    (AFile.Reader.SampleRate <= 48000) and (AFile.Reader.FrameCount > 0) and
    (AFile.Reader.FrameCount <= Int64(AFile.Reader.SampleRate) * 960),
    'Expected PCM16 within rate/duration bounds');
end;

function PrepareStem(const AInput: TInput; const AName: String): TJSONObject;
var
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LReader: TWaveFrameReader;
  LSource: TAudioSamples;
  LOutput: TAudioSamples;
  LCount: Int64;
  LChanged: Int64;
  LSourcePeak: Integer;
  LOutputPeak: Integer;
  LError: Integer;
  LMaxError: Integer;
  LOriginal: Integer;
  LActual: Integer;
  I: Integer;
begin
  Result := nil;
  LFile := TFileStream.Create(GDirectory + AName, fmCreate);
  LSink := nil;
  LWriter := nil;
  try
    LSink := TStreamAudioSink.Create(LFile);
    LWriter := TWavePcm16Writer.Create(LSink, AInput.Reader.SampleRate,
      AInput.Reader.Channels, AInput.Reader.FrameCount);
    repeat
      Budget;
      LSource := AInput.Reader.ReadFrames(4096);
      for I := 0 to High(LSource) do
      begin
        LSource[I] := LSource[I] / 16;
      end;
      LWriter.AppendSamples(LSource);
    until Length(LSource) = 0;
    LWriter.Finish;
  finally
    LWriter.Free;
    LSink.Free;
    LFile.Free;
  end;

  LFile := TFileStream.Create(GDirectory + AName, fmOpenRead or fmShareDenyWrite);
  LReader := nil;
  try
    LReader := TWaveFrameReader.Create(LFile);
    Check((LReader.FrameCount = AInput.Reader.FrameCount) and
      (LReader.SampleRate = AInput.Reader.SampleRate) and
      (LReader.Channels = AInput.Reader.Channels) and
      (LReader.EncodingTag = 1) and (LReader.BitsPerSample = 16),
      'Derived stem geometry mismatch');
    AInput.Reader.SeekFrame(0);
    LCount := 0;
    LChanged := 0;
    LSourcePeak := 0;
    LOutputPeak := 0;
    LMaxError := 0;
    repeat
      Budget;
      LSource := AInput.Reader.ReadFrames(4096);
      LOutput := LReader.ReadFrames(4096);
      Check(Length(LSource) = Length(LOutput), 'Derived stem length mismatch');
      for I := 0 to High(LSource) do
      begin
        LOriginal := IntegerSample(LSource[I]);
        LActual := IntegerSample(LOutput[I]);
        Check(LActual = ScaledOracle(LOriginal), 'Derived stem sample mismatch');
        LError := Abs(16 * LActual - LOriginal);
        Check(LError <= 8, 'Scaled quantization error exceeds half LSB');
        if LError > 0 then
        begin
          Inc(LChanged);
        end;
        if LError > LMaxError then
        begin
          LMaxError := LError;
        end;
        if Abs(LOriginal) > LSourcePeak then
        begin
          LSourcePeak := Abs(LOriginal);
        end;
        if Abs(LActual) > LOutputPeak then
        begin
          LOutputPeak := Abs(LActual);
        end;
      end;
      Inc(LCount, Length(LOutput));
    until Length(LOutput) = 0;
    Check(LCount = AInput.Reader.FrameCount * AInput.Reader.Channels,
      'Incomplete derived stem verification');
    Result := TJSONObject.Create;
    Result.Add('path', AName);
    Result.Add('source_path', AInput.Name);
    Result.Add('verified_samples', LCount);
    Result.Add('input_peak_pcm16_lsb', LSourcePeak);
    Result.Add('output_peak_pcm16_lsb', LOutputPeak);
    Result.Add('quantized_samples', LChanged);
    Result.Add('maximum_error_sixteenths_of_output_lsb', LMaxError);
  finally
    LReader.Free;
    LFile.Free;
  end;
end;

function SumAt(const ABlocks: TBlocks; const AIndex: Integer): Integer;
var
  I: Integer;
  LValue: Integer;
begin
  Check((Length(ABlocks) >= 1) and (Length(ABlocks) <= 15), 'Stem count bound');
  Result := 0;
  for I := 0 to High(ABlocks) do
  begin
    LValue := IntegerSample(ABlocks[I][AIndex]);
    Check(Abs(LValue) <= 2048, 'Derived stem exceeds fixed gain bound');
    Inc(Result, LValue);
  end;
  Check((Result >= -30720) and (Result <= 30720), 'Mixture headroom bound');
end;

function PrepareMix(const AStems: TInputs): TJSONObject;
var
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LReader: TWaveFrameReader;
  LBlocks: TBlocks;
  LOutput: TAudioSamples;
  LCount: Int64;
  LPeak: Integer;
  LValue: Integer;
  I: Integer;
  J: Integer;

  procedure ReadStems;
  var
    K: Integer;
  begin
    for K := 0 to High(AStems) do
    begin
      LBlocks[K] := AStems[K].Reader.ReadFrames(4096);
      Check(Length(LBlocks[K]) = Length(LBlocks[0]), 'Derived stem block mismatch');
    end;
  end;

begin
  Result := nil;
  SetLength(LBlocks, Length(AStems));
  LFile := TFileStream.Create(GDirectory + 'mix.wav', fmCreate);
  LSink := nil;
  LWriter := nil;
  try
    LSink := TStreamAudioSink.Create(LFile);
    LWriter := TWavePcm16Writer.Create(LSink, AStems[0].Reader.SampleRate,
      AStems[0].Reader.Channels, AStems[0].Reader.FrameCount);
    repeat
      Budget;
      ReadStems;
      SetLength(LOutput, Length(LBlocks[0]));
      for J := 0 to High(LOutput) do
      begin
        LOutput[J] := SumAt(LBlocks, J) / 32768;
      end;
      LWriter.AppendSamples(LOutput);
    until Length(LOutput) = 0;
    LWriter.Finish;
  finally
    LWriter.Free;
    LSink.Free;
    LFile.Free;
  end;
  for I := 0 to High(AStems) do
  begin
    AStems[I].Reader.SeekFrame(0);
  end;
  LFile := TFileStream.Create(GDirectory + 'mix.wav', fmOpenRead or fmShareDenyWrite);
  LReader := nil;
  try
    LReader := TWaveFrameReader.Create(LFile);
    Check((LReader.FrameCount = AStems[0].Reader.FrameCount) and
      (LReader.SampleRate = AStems[0].Reader.SampleRate) and
      (LReader.Channels = AStems[0].Reader.Channels) and
      (LReader.EncodingTag = 1) and (LReader.BitsPerSample = 16), 'Mix geometry');
    LCount := 0;
    LPeak := 0;
    repeat
      Budget;
      ReadStems;
      LOutput := LReader.ReadFrames(4096);
      Check(Length(LOutput) = Length(LBlocks[0]), 'Mix block mismatch');
      for J := 0 to High(LOutput) do
      begin
        LValue := IntegerSample(LOutput[J]);
        Check(LValue = SumAt(LBlocks, J), 'Stored mix is not the exact stem sum');
        if Abs(LValue) > LPeak then
        begin
          LPeak := Abs(LValue);
        end;
      end;
      Inc(LCount, Length(LOutput));
    until Length(LOutput) = 0;
    Check(LCount = LReader.FrameCount * LReader.Channels, 'Incomplete mix verification');
    Result := TJSONObject.Create;
    Result.Add('path', 'mix.wav');
    Result.Add('frames', LReader.FrameCount);
    Result.Add('channels', LReader.Channels);
    Result.Add('sample_rate', LReader.SampleRate);
    Result.Add('verified_samples', LCount);
    Result.Add('peak_pcm16_lsb', LPeak);
    Result.Add('exact_stored_stem_sum', True);
    Result.Add('residual_pcm16_lsb', 0);
  finally
    LReader.Free;
    LFile.Free;
  end;
end;

function IdentityFixture(const AEvaluation, ADecision: Boolean): TJSONObject;
var
  LDecision: TJSONObject;
  LAuxiliary: TJSONArray;
  LRow: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('archive_sha256', CArchiveHash);
  if AEvaluation then
  begin
    Result.Add('exposure', 'reference-only-evaluation');
    Result.Add('group', 'BabySlakh-4603870-Track00002');
    Result.Add('source_uuid', '0c3b7bf33cd3d67970ecfc06339bfc49');
  end
  else
  begin
    Result.Add('exposure', 'development');
    Result.Add('group', 'BabySlakh-4603870-Track00001');
    Result.Add('source_uuid', '1a81ae092884234f3264e2f45927f00a');
  end;
  LAuxiliary := TJSONArray.Create;
  Result.Add('auxiliary', LAuxiliary);
  if ADecision then
  begin
    LDecision := TJSONObject.Create;
    LDecision.Add('path', 'family-decision.md');
    LDecision.Add('sha256', CFamilyDecisionHash);
    Result.Add('family_decision', LDecision);
    LAuxiliary.Add(LDecision.Clone);
  end;
  if AEvaluation then
  begin
    LRow := TJSONObject.Create;
    LRow.Add('path', 'Track00002/metadata.yaml');
    LRow.Add('sha256', CEvaluationMetadataHash);
    LAuxiliary.Add(LRow);
    LRow := TJSONObject.Create;
    LRow.Add('path', 'Track00002/all_src.mid');
    LRow.Add('sha256', CEvaluationScoreHash);
    LAuxiliary.Add(LRow);
  end;
end;

procedure ExpectIdentityRejected(const ABinding: TJSONObject);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ValidateSourceIdentity(ABinding);
  except
    on E: Exception do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Invalid identity/exposure must reject');
end;

procedure IdentityControls;
var
  LBinding: TJSONObject;
  I: Integer;
begin
  LBinding := IdentityFixture(False, False);
  try
    Check(not ValidateSourceIdentity(LBinding), 'Existing development binding remains supported');
  finally
    LBinding.Free;
  end;
  LBinding := IdentityFixture(False, True);
  try
    Check(ValidateSourceIdentity(LBinding), 'Optional development decision binding');
  finally
    LBinding.Free;
  end;
  LBinding := IdentityFixture(True, True);
  try
    Check(ValidateSourceIdentity(LBinding), 'Accepted reference-only evaluation tuple');
  finally
    LBinding.Free;
  end;
  LBinding := IdentityFixture(True, False);
  try
    ExpectIdentityRejected(LBinding);
  finally
    LBinding.Free;
  end;
  for I := 0 to 10 do
  begin
    LBinding := IdentityFixture(True, True);
    try
      case I of
        0:
          begin
            LBinding.Strings['exposure'] := 'development';
          end;
        1:
          begin
            LBinding.Strings['exposure'] := 'evaluation';
          end;
        2:
          begin
            LBinding.Strings['group'] := 'BabySlakh-4603870-Track00003';
          end;
        3:
          begin
            LBinding.Strings['source_uuid'] := '1a81ae092884234f3264e2f45927f00a';
          end;
        4:
          begin
            LBinding.Strings['archive_sha256'] := StringOfChar('0', 64);
          end;
        5:
          begin
            LBinding.Objects['family_decision'].Strings['sha256'] := StringOfChar('0', 64);
          end;
        6:
          begin
            LBinding.Objects['family_decision'].Strings['path'] := '../family-decision.md';
          end;
        7:
          begin
            LBinding.Arrays['auxiliary'].Delete(0);
          end;
        8:
          begin
            LBinding.Arrays['auxiliary'].Objects[1].Strings['sha256'] := StringOfChar('0', 64);
          end;
        9:
          begin
            LBinding.Arrays['auxiliary'].Delete(2);
          end;
        10:
          begin
            LBinding.Arrays['auxiliary'].Objects[0].Strings['sha256'] := StringOfChar('0', 64);
          end;
      end;
      ExpectIdentityRejected(LBinding);
    finally
      LBinding.Free;
    end;
  end;
end;

procedure Controls;
var
  I: Integer;
  LBlocks: TBlocks;
  LRejected: Boolean;
begin
  IdentityControls;
  { Complete source-code domain; includes both signed extremes and every tie. }
  for I := -32768 to 32767 do
  begin
    Check(QuantizePcm16(I / 524288) = ScaledOracle(I), 'Signed scaling oracle');
    Check(Abs(ScaledOracle(I) * 16 - I) <= 8, 'Quantization error bound');
  end;
  SetLength(LBlocks, 15);
  for I := 0 to 14 do
  begin
    SetLength(LBlocks[I], 1);
    LBlocks[I][0] := 2048 / 32768;
  end;
  Check(SumAt(LBlocks, 0) = 30720, 'Positive worst-case headroom');
  for I := 0 to 14 do
  begin
    LBlocks[I][0] := -2048 / 32768;
  end;
  Check(SumAt(LBlocks, 0) = -30720, 'Negative worst-case headroom');
  LBlocks[0][0] := -2049 / 32768;
  LRejected := False;
  try
    SumAt(LBlocks, 0);
  except
    on E: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Invalid derived gain rejection');
  Check(not SafeName('../outside.wav', True) and not SafeName('C:/outside.wav', True)
    and not SafeName('/outside.wav', True) and SafeName('stems/S00.wav', True),
    'Member path controls');
  WriteLn('Derived scaling, headroom, path and identity/exposure controls passed');
end;

procedure Run;
var
  LBindingFile: TFileStream;
  LData: TJSONData;
  LBinding: TJSONObject;
  LManifest: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LStems: TInputs;
  LDerived: TInputs;
  LLicense: TInput;
  LFamilyDecision: TInput;
  LHasDecision: Boolean;
  LInput: TInput;
  LRoot: String;
  LBase: String;
  LName: String;
  LHash: String;
  LPolicyHash: String;
  LSourceHash: String;
  LManifestText: String;
  LExpectedBytes: Int64;
  I: Integer;
  J: Integer;
begin
  if (ParamCount = 1) and (ParamStr(1) = '--controls') then
  begin
    Controls;
    Exit;
  end;
  Check(ParamCount = 3, 'Use SOURCE_BINDING.json SHA256 NEW_BUILD_DIRECTORY');
  GStart := GetTickCount64;
  LBase := IncludeTrailingPathDelimiter(ExpandFileName('build/role-prepared'));
  GDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(3)));
  Check((ExtractFilePath(ExcludeTrailingPathDelimiter(GDirectory)) = LBase) and
    SafeName(ExtractFileName(ExcludeTrailingPathDelimiter(GDirectory)), False),
    'Output must be a direct child of build/role-prepared');
  Check(not DirectoryExists(GDirectory) and
    not FileExists(ExcludeTrailingPathDelimiter(GDirectory)), 'Output already exists');
  LPolicyHash := FileHash(CPolicyPath);
  LSourceHash := FileHash(CSourcePath);
  LBindingFile := nil;
  LData := nil;
  LManifest := nil;
  LLicense := nil;
  LFamilyDecision := nil;
  LStems := nil;
  LDerived := nil;
  try
    LBindingFile := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
    Check(LBindingFile.Size <= 1048576, 'Source binding exceeds 1 MiB');
    LHash := Sha256Stream(LBindingFile, LBindingFile.Size);
    Check(LHash = LowerCase(ParamStr(2)), 'Source binding SHA256 mismatch');
    LBindingFile.Position := 0;
    LData := GetJSON(LBindingFile);
    Check(LData.JSONType = jtObject, 'Source binding must be an object');
    LBinding := TJSONObject(LData);
    LHasDecision := ValidateSourceIdentity(LBinding);
    Check((LBinding.Arrays['stems'].Count >= 1) and
      (LBinding.Arrays['stems'].Count <= 15), 'Supported stem count is 1 to 15');
    LRoot := IncludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(ParamStr(1))));
    Bind(LRoot, LBinding.Objects['mix']);
    for I := 0 to LBinding.Arrays['auxiliary'].Count - 1 do
    begin
      LInput := Bind(LRoot, LBinding.Arrays['auxiliary'].Objects[I]);
      if LInput.Name = 'CC-BY-4.0.txt' then
      begin
        LLicense := LInput;
      end;
      if LHasDecision and (LInput.Name = 'family-decision.md') then
      begin
        LFamilyDecision := LInput;
      end;
    end;
    Check(LLicense <> nil, 'Full source license must be bound');
    Check(not LHasDecision or (LFamilyDecision <> nil), 'Accepted family decision bytes must be bound');
    SetLength(LStems, LBinding.Arrays['stems'].Count);
    SetLength(LDerived, Length(LStems));
    for I := 0 to High(LStems) do
    begin
      LRow := LBinding.Arrays['stems'].Objects[I];
      LName := LRow.Strings['stem_id'];
      Check(SafeName(LName, False) and (LowerCase(LName) <> 'mix'),
        'Unsafe or reserved stem ID');
      for J := 0 to I - 1 do
      begin
        Check(LowerCase(LName) <>
          LowerCase(LBinding.Arrays['stems'].Objects[J].Strings['stem_id']),
          'Duplicate stem ID');
      end;
      LStems[I] := Bind(LRoot, LRow.Objects['wave']);
      Bind(LRoot, LRow.Objects['midi']);
      OpenWave(LStems[I]);
      Check((LStems[I].Reader.FrameCount = LStems[0].Reader.FrameCount) and
        (LStems[I].Reader.Channels = LStems[0].Reader.Channels) and
        (LStems[I].Reader.SampleRate = LStems[0].Reader.SampleRate),
        'Source stem geometry mismatch');
    end;
    LExpectedBytes := (LStems[0].Reader.FrameCount * LStems[0].Reader.Channels * 2 + 44)
      * (Length(LStems) + 1) + LBindingFile.Size + LLicense.Stream.Size + 1048576;
    if LHasDecision then
    begin
      Inc(LExpectedBytes, LFamilyDecision.Stream.Size);
    end;
    Check(LExpectedBytes <= CByteLimit, 'Planned output exceeds 1 GiB');
    Check(ForceDirectories(GDirectory), 'Cannot create output directory');
    LManifest := TJSONObject.Create;
    GArtifacts := TJSONArray.Create;
    LManifest.Add('artifacts', GArtifacts);
    LManifest.Add('kind', 'derived-stem-mixture');
    LManifest.Add('source_binding_sha256', LHash);
    LManifest.Add('policy_sha256', LPolicyHash);
    LManifest.Add('tool_sha256', LSourceHash);
    LManifest.Add('audio_unit_sha256', FileHash('src/pythian.audio.pas'));
    LManifest.Add('wave_reader_sha256', FileHash('src/pythian.wave.read.pas'));
    LManifest.Add('wave_writer_sha256', FileHash('src/pythian.wave.stream.pas'));
    LManifest.Add('hash_unit_sha256', FileHash('src/pythian.hash.pas'));
    LManifest.Add('file_helpers_sha256', FileHash('tools/pythian.tools.files.pas'));
    LManifest.Add('group', LBinding.Strings['group']);
    LManifest.Add('source_uuid', LBinding.Strings['source_uuid']);
    LManifest.Add('archive_sha256', LBinding.Strings['archive_sha256']);
    LManifest.Add('exposure', LBinding.Strings['exposure']);
    LManifest.Add('model_training_overlap', 'unknown');
    LManifest.Add('independent_accuracy_verified', False);
    if LHasDecision then
    begin
      LManifest.Add('family_decision', LBinding.Objects['family_decision'].Clone);
      LManifest.Add('family_qualification', 'accepted-two-family-reference-scope');
    end
    else
    begin
      LManifest.Add('family_qualification', 'not-bound');
    end;
    LManifest.Add('source_stem_gain_numerator', 1);
    LManifest.Add('source_stem_gain_denominator', 16);
    LManifest.Add('source_stem_offset_frames', 0);
    LManifest.Add('metadata_gain_reapplied', False);
    LManifest.Add('original_mix_qualified', False);
    LManifest.Add('musical_roles_verified', False);
    LManifest.Add('acoustic_note_timing_verified', False);
    LManifest.Add('independent_family_verified', False);
    LManifest.Add('source_credit', 'Ethan Manilow, Gordon Wichern, Prem Seetharaman, '
      + 'Jonathan Le Roux; BabySlakh, doi:10.5281/zenodo.4603870; CC BY 4.0');
    CopyBound(LBindingFile, 'source-binding.json');
    CopyBound(LLicense.Stream, 'CC-BY-4.0.txt');
    if LHasDecision then
    begin
      CopyBound(LFamilyDecision.Stream, 'family-decision.md');
    end;
    LRows := TJSONArray.Create;
    LManifest.Add('stems', LRows);
    for I := 0 to High(LStems) do
    begin
      LName := LBinding.Arrays['stems'].Objects[I].Strings['stem_id'] + '.wav';
      LRows.Add(PrepareStem(LStems[I], LName));
      Artifact(LName);
      LDerived[I] := TInput.Create;
      LDerived[I].Stream := TFileStream.Create(GDirectory + LName,
        fmOpenRead or fmShareDenyWrite);
      OpenWave(LDerived[I]);
    end;
    LManifest.Add('mix', PrepareMix(LDerived));
    Artifact('mix.wav');
    LManifest.Add('artifact_bytes', GOutputBytes);
    LManifest.Add('bound_input_bytes', GInputBytes);
    LManifestText := LManifest.FormatJSON + #10;
    Check((Length(LManifestText) <= 1048576) and
      (Length(LManifestText) <= CByteLimit - GOutputBytes), 'Manifest byte bound');
    Budget;
    WriteTextFile(GDirectory + 'manifest.json', LManifestText);
    WriteLn('Derived stored-stem mixture verified; role/timing annotations remain unknown');
  finally
    for I := 0 to High(LDerived) do
    begin
      LDerived[I].Free;
    end;
    for I := 0 to High(GInputs) do
    begin
      GInputs[I].Free;
    end;
    GInputs := nil;
    GArtifacts := nil;
    LManifest.Free;
    LData.Free;
    LBindingFile.Free;
  end;
end;

begin
  try
    Run;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
