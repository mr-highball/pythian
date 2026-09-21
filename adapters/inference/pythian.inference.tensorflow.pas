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
(*
Model topology, preprocessing and pitch decoding derived from CREPE.
The MIT License (MIT)

Copyright (c) 2018 Jong Wook Kim

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
unit pythian.inference.tensorflow;
{$mode delphi}
{$H+}
{$packrecords c}
interface
uses Classes, SysUtils, Dynlibs, fpjson, pythian.audio, pythian.inference.observation;
type
  TTFOutput = record
    Operation: Pointer;
    Index: LongInt;
  end;
  { One live instance per process. Concurrent construction and reentry reject.
    Dedicated worker is preferred; in-process calls are cooperative only. }
  TTinyPitchRuntime = class(TInferenceBackend)
  private
    FOwnsRuntime: Boolean;
    FBusy: LongInt;
    FRuntimeFile: TFileStream;
    FGraph: Pointer;
    FStatus: Pointer;
    FSession: Pointer;
    FInput: TTFOutput;
    FOutput: TTFOutput;
    FWeights: TStringList;
    FSerial: Integer;
    procedure Check;
    function Start(const AKind: String; const AInputs: array of TTFOutput): Pointer;
    function Finish(const ADescription: Pointer): TTFOutput;
    function Unary(const AKind: String; const AInput: TTFOutput): TTFOutput;
    function Binary(const AKind: String; const ALeft, ARight: TTFOutput): TTFOutput;
    function ConstantTensor(const AType: Integer; const AShape: array of Int64;
      const AData: Pointer; const ABytes: SizeUInt): TTFOutput;
    function Shape(const ADimensions: array of Int64): TTFOutput;
    function Weight(const AName: String): TTFOutput;
    procedure LoadWeights(const ADirectory: String; const AManifest: TJSONArray);
    procedure Build(const AModel: TJSONObject);
  public
    constructor Create(const ARuntimeDirectory, AModelDirectory: String);
    destructor Destroy; override;
    function Activate(const AWindow: TAudioSamples): TPitchSalience; override;
    function EstimatorIdentity: String; override;
    function Version: String;
  end;
implementation
uses jsonparser, pythian.tools.files, pythian.hash;
type
  TStoredOutput = class
    Value: TTFOutput;
  end;
var
  GLibrary: TLibHandle = NilHandle;
  GRuntimeReady: Boolean = False;
  GActive: LongInt = 0;
  TF_Version: function: PChar; cdecl;
  TF_NewGraph: function: Pointer; cdecl;
  TF_DeleteGraph: procedure(AGraph: Pointer); cdecl;
  TF_NewStatus: function: Pointer; cdecl;
  TF_DeleteStatus: procedure(AStatus: Pointer); cdecl;
  TF_GetCode: function(AStatus: Pointer): Integer; cdecl;
  TF_Message: function(AStatus: Pointer): PChar; cdecl;
  TF_NewOperation: function(AGraph: Pointer; AKind, AName: PChar): Pointer; cdecl;
  TF_AddInput: procedure(ADescription: Pointer; AInput: TTFOutput); cdecl;
  TF_FinishOperation: function(ADescription, AStatus: Pointer): Pointer; cdecl;
  TF_SetAttrType: procedure(ADescription: Pointer; AName: PChar; AType: Integer); cdecl;
  TF_SetAttrBool: procedure(ADescription: Pointer; AName: PChar; AValue: Byte); cdecl;
  TF_SetAttrFloat: procedure(ADescription: Pointer; AName: PChar; AValue: Single); cdecl;
  TF_SetAttrString: procedure(ADescription: Pointer; AName: PChar; AValue: Pointer; ALength: SizeUInt); cdecl;
  TF_SetAttrIntList: procedure(ADescription: Pointer; AName: PChar; AValues: PInt64; ACount: Integer); cdecl;
  TF_SetAttrShape: procedure(ADescription: Pointer; AName: PChar; AValues: PInt64; ACount: Integer); cdecl;
  TF_SetAttrTensor: procedure(ADescription: Pointer; AName: PChar; ATensor, AStatus: Pointer); cdecl;
  TF_AllocateTensor: function(AType: Integer; ADimensions: PInt64; ACount: Integer; ABytes: SizeUInt): Pointer; cdecl;
  TF_DeleteTensor: procedure(ATensor: Pointer); cdecl;
  TF_TensorData: function(ATensor: Pointer): Pointer; cdecl;
  TF_TensorByteSize: function(ATensor: Pointer): SizeUInt; cdecl;
  TF_NewSessionOptions: function: Pointer; cdecl;
  TF_SetConfig: procedure(AOptions, ABytes: Pointer; ACount: SizeUInt;
    AStatus: Pointer); cdecl;
  TF_TensorType: function(ATensor: Pointer): Integer; cdecl;
  TF_NumDims: function(ATensor: Pointer): Integer; cdecl;
  TF_Dim: function(ATensor: Pointer; AIndex: Integer): Int64; cdecl;
  TF_DeleteSessionOptions: procedure(AOptions: Pointer); cdecl;
  TF_NewSession: function(AGraph, AOptions, AStatus: Pointer): Pointer; cdecl;
  TF_CloseSession: procedure(ASession, AStatus: Pointer); cdecl;
  TF_DeleteSession: procedure(ASession, AStatus: Pointer); cdecl;
  TF_SessionRun: procedure(ASession, ARunOptions, AInputs, AInputValues: Pointer;
    AInputCount: Integer; AOutputs, AOutputValues: Pointer; AOutputCount: Integer;
    ATargets: Pointer; ATargetCount: Integer; AMetadata, AStatus: Pointer); cdecl;
procedure Bind(var AFunction; const AName: String);
var
  LAddress: Pointer;
begin
  LAddress := GetProcedureAddress(GLibrary, PChar(AName));
  if LAddress = nil then
  begin
    raise EAudio.Create('Missing C API: ' + AName);
  end;
  Move(LAddress, AFunction, SizeOf(LAddress));
end;
procedure LoadRuntime(const ADirectory: String);
begin
  if GLibrary <> NilHandle then
  begin
    if not GRuntimeReady then
    begin
      raise EAudio.Create('Prior runtime binding failed; start a fresh worker');
    end;
    Exit;
  end;
  GLibrary := LoadLibrary(IncludeTrailingPathDelimiter(ADirectory) + 'tensorflow.dll');
  if GLibrary = NilHandle then
  begin
    raise EAudio.Create('Cannot load reference runtime: ' + GetLoadErrorStr);
  end;
  Bind(TF_Version, 'TF_Version');
  Bind(TF_NewGraph, 'TF_NewGraph');
  Bind(TF_DeleteGraph, 'TF_DeleteGraph');
  Bind(TF_NewStatus, 'TF_NewStatus');
  Bind(TF_DeleteStatus, 'TF_DeleteStatus');
  Bind(TF_GetCode, 'TF_GetCode');
  Bind(TF_Message, 'TF_Message');
  Bind(TF_NewOperation, 'TF_NewOperation');
  Bind(TF_AddInput, 'TF_AddInput');
  Bind(TF_FinishOperation, 'TF_FinishOperation');
  Bind(TF_SetAttrType, 'TF_SetAttrType');
  Bind(TF_SetAttrBool, 'TF_SetAttrBool');
  Bind(TF_SetAttrFloat, 'TF_SetAttrFloat');
  Bind(TF_SetAttrString, 'TF_SetAttrString');
  Bind(TF_SetAttrIntList, 'TF_SetAttrIntList');
  Bind(TF_SetAttrShape, 'TF_SetAttrShape');
  Bind(TF_SetAttrTensor, 'TF_SetAttrTensor');
  Bind(TF_AllocateTensor, 'TF_AllocateTensor');
  Bind(TF_DeleteTensor, 'TF_DeleteTensor');
  Bind(TF_TensorData, 'TF_TensorData');
  Bind(TF_TensorByteSize, 'TF_TensorByteSize');
  Bind(TF_NewSessionOptions, 'TF_NewSessionOptions');
  Bind(TF_SetConfig, 'TF_SetConfig');
  Bind(TF_TensorType, 'TF_TensorType');
  Bind(TF_NumDims, 'TF_NumDims');
  Bind(TF_Dim, 'TF_Dim');
  Bind(TF_DeleteSessionOptions, 'TF_DeleteSessionOptions');
  Bind(TF_NewSession, 'TF_NewSession');
  Bind(TF_CloseSession, 'TF_CloseSession');
  Bind(TF_DeleteSession, 'TF_DeleteSession');
  Bind(TF_SessionRun, 'TF_SessionRun');
  if String(TF_Version()) <> '2.18.1' then
  begin
    raise EAudio.Create('Unexpected reference runtime version');
  end;
  GRuntimeReady := True;
end;
procedure TTinyPitchRuntime.Check;
begin
  if TF_GetCode(FStatus) <> 0 then
  begin
    raise EAudio.Create('TensorFlow: ' + String(TF_Message(FStatus)));
  end;
end;
function TTinyPitchRuntime.Start(const AKind: String; const AInputs: array of TTFOutput): Pointer;
var
  LInput: TTFOutput;
begin
  Inc(FSerial);
  Result := TF_NewOperation(FGraph, PChar(AKind), PChar('node_' + IntToStr(FSerial)));
  for LInput in AInputs do
  begin
    TF_AddInput(Result, LInput);
  end;
end;
function TTinyPitchRuntime.Finish(const ADescription: Pointer): TTFOutput;
begin
  Result := Default(TTFOutput);
  Result.Operation := TF_FinishOperation(ADescription, FStatus);
  Check;
end;
function TTinyPitchRuntime.Unary(const AKind: String; const AInput: TTFOutput): TTFOutput;
begin
  Result := Finish(Start(AKind, [AInput]));
end;
function TTinyPitchRuntime.Binary(const AKind: String; const ALeft, ARight: TTFOutput): TTFOutput;
begin
  Result := Finish(Start(AKind, [ALeft, ARight]));
end;
function TTinyPitchRuntime.ConstantTensor(const AType: Integer; const AShape: array of Int64;
  const AData: Pointer; const ABytes: SizeUInt): TTFOutput;
var
  LTensor: Pointer;
  LDescription: Pointer;
  LDimensions: PInt64;
begin
  LDimensions := nil;
  if Length(AShape) > 0 then
  begin
    LDimensions := @AShape[0];
  end;
  LTensor := TF_AllocateTensor(AType, LDimensions, Length(AShape), ABytes);
  if LTensor = nil then
  begin
    raise EAudio.Create('Reference tensor allocation failed');
  end;
  try
    Move(AData^, TF_TensorData(LTensor)^, ABytes);
    LDescription := Start('Const', []);
    TF_SetAttrType(LDescription, 'dtype', AType);
    TF_SetAttrTensor(LDescription, 'value', LTensor, FStatus);
    Check;
    Result := Finish(LDescription);
  finally
    TF_DeleteTensor(LTensor);
  end;
end;
function TTinyPitchRuntime.Shape(const ADimensions: array of Int64): TTFOutput;
begin
  Result := ConstantTensor(9, [Length(ADimensions)], @ADimensions[0], Length(ADimensions) * 8);
end;
function TTinyPitchRuntime.Weight(const AName: String): TTFOutput;
var
  LIndex: Integer;
begin
  LIndex := FWeights.IndexOf(AName);
  if LIndex < 0 then
  begin
    raise EAudio.Create('Missing named weight ' + AName);
  end;
  Result := TStoredOutput(FWeights.Objects[LIndex]).Value;
end;
procedure TTinyPitchRuntime.LoadWeights(const ADirectory: String; const AManifest: TJSONArray);
var
  LGroup: TJSONObject;
  LWeight: TJSONObject;
  LBytes: TAudioBytes;
  LShape: array of Int64;
  LOffset: Integer;
  LCount: Integer;
  LStored: TStoredOutput;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  if AManifest.Count <> 13 then
  begin
    raise EAudio.Create('Pinned model requires thirteen shard groups');
  end;
  for I := 0 to AManifest.Count - 1 do
  begin
    LGroup := AManifest.Objects[I];
    if LGroup.Arrays['paths'].Count <> 1 then
    begin
      raise EAudio.Create('Expected one shard per manifest group');
    end;
    if LGroup.Arrays['paths'].Strings[0] <> 'group' + IntToStr(I + 1) + '-shard1of1' then
    begin
      raise EAudio.Create('Unexpected pinned model shard name');
    end;
    LBytes := ReadFileBytes(IncludeTrailingPathDelimiter(ADirectory) +
      LGroup.Arrays['paths'].Strings[0], 1024 * 1024);
    if Sha256Bytes(LBytes) <> InferenceShardHashes[I + 1] then
    begin
      raise EAudio.Create('Pinned model shard SHA256 differs');
    end;
    LOffset := 0;
    for J := 0 to LGroup.Arrays['weights'].Count - 1 do
    begin
      LWeight := LGroup.Arrays['weights'].Objects[J];
      if LWeight.Get('dtype', '') <> 'float32' then
      begin
        raise EAudio.Create('Expected float32 weights');
      end;
      SetLength(LShape, LWeight.Arrays['shape'].Count);
      LCount := 1;
      for K := 0 to High(LShape) do
      begin
        LShape[K] := LWeight.Arrays['shape'].Integers[K];
        LCount := LCount * LShape[K];
      end;
      if (LCount < 1) or (LOffset + LCount * 4 > Length(LBytes)) then
      begin
        raise EAudio.Create('Manifest tensor exceeds shard');
      end;
      LStored := TStoredOutput.Create;
      try
        LStored.Value := ConstantTensor(1, LShape, @LBytes[LOffset], LCount * 4);
        FWeights.AddObject(LWeight.Get('name', ''), LStored);
      except
        LStored.Free;
        raise;
      end;
      Inc(LOffset, LCount * 4);
    end;
    if LOffset <> Length(LBytes) then
    begin
      raise EAudio.Create('Unconsumed shard bytes');
    end;
  end;
end;
procedure TTinyPitchRuntime.Build(const AModel: TJSONObject);
var
  LLayers: TJSONArray;
  LLayer: TJSONObject;
  LConfig: TJSONObject;
  LKind: String;
  LName: String;
  LValue: TTFOutput;
  LMean: TTFOutput;
  LAxis: TTFOutput;
  LDeviation: TTFOutput;
  LEpsilon: Single;
  LDescription: Pointer;
  LStrides: array[0..3] of Int64;
  LDimensions: array[0..0] of Int64;
  LPadding: String;
  I: Integer;
begin
  LDescription := Start('Placeholder', []);
  TF_SetAttrType(LDescription, 'dtype', 1);
  LDimensions[0] := 1024;
  TF_SetAttrShape(LDescription, 'shape', @LDimensions[0], 1);
  FInput := Finish(LDescription);
  LAxis := Shape([0]);
  LDescription := Start('Mean', [FInput, LAxis]);
  TF_SetAttrBool(LDescription, 'keep_dims', 0);
  LMean := Finish(LDescription);
  LValue := Binary('Sub', FInput, LMean);
  LDescription := Start('Mean', [Unary('Square', LValue), LAxis]);
  TF_SetAttrBool(LDescription, 'keep_dims', 0);
  LDeviation := Unary('Sqrt', Finish(LDescription));
  LEpsilon := 1e-8;
  LDeviation := Binary('Maximum', LDeviation, ConstantTensor(1, [], @LEpsilon, 4));
  LValue := Binary('RealDiv', LValue, LDeviation);
  LLayers := AModel.Objects['modelTopology'].Objects['model_config'].Objects['config'].Arrays['layers'];
  for I := 0 to LLayers.Count - 1 do
  begin
    LLayer := LLayers.Objects[I];
    LConfig := LLayer.Objects['config'];
    LKind := LLayer.Get('class_name', '');
    LName := LConfig.Get('name', '');
    if (LKind = 'InputLayer') or (LKind = 'Dropout') then
    begin
      Continue;
    end;
    if LKind = 'Reshape' then
    begin
      LValue := Binary('Reshape', LValue, Shape([1, 1024, 1, 1]));
    end
    else if LKind = 'Conv2D' then
    begin
      LDescription := Start('Conv2D', [LValue, Weight(LName + '/kernel')]);
      LStrides[0] := 1;
      LStrides[1] := LConfig.Arrays['strides'].Integers[0];
      LStrides[2] := LConfig.Arrays['strides'].Integers[1];
      LStrides[3] := 1;
      TF_SetAttrIntList(LDescription, 'strides', @LStrides[0], 4);
      LPadding := UpperCase(LConfig.Get('padding', ''));
      TF_SetAttrString(LDescription, 'padding', PChar(LPadding), Length(LPadding));
      LValue := Unary('Relu', Binary('BiasAdd', Finish(LDescription), Weight(LName + '/bias')));
    end
    else if LKind = 'BatchNormalization' then
    begin
      LDescription := Start('FusedBatchNormV3', [LValue, Weight(LName + '/gamma'),
        Weight(LName + '/beta'), Weight(LName + '/moving_mean'), Weight(LName + '/moving_variance')]);
      TF_SetAttrFloat(LDescription, 'epsilon', LConfig.Get('epsilon', 0.001));
      TF_SetAttrBool(LDescription, 'is_training', 0);
      LValue := Finish(LDescription);
    end
    else if LKind = 'MaxPooling2D' then
    begin
      LDescription := Start('MaxPool', [LValue]);
      LStrides[0] := 1;
      LStrides[1] := LConfig.Arrays['pool_size'].Integers[0];
      LStrides[2] := LConfig.Arrays['pool_size'].Integers[1];
      LStrides[3] := 1;
      TF_SetAttrIntList(LDescription, 'ksize', @LStrides[0], 4);
      LStrides[1] := LConfig.Arrays['strides'].Integers[0];
      LStrides[2] := LConfig.Arrays['strides'].Integers[1];
      TF_SetAttrIntList(LDescription, 'strides', @LStrides[0], 4);
      LPadding := UpperCase(LConfig.Get('padding', ''));
      TF_SetAttrString(LDescription, 'padding', PChar(LPadding), Length(LPadding));
      LValue := Finish(LDescription);
    end
    else if LKind = 'Flatten' then
    begin
      LValue := Binary('Reshape', LValue, Shape([1, -1]));
    end
    else if LKind = 'Dense' then
    begin
      LDescription := Start('MatMul', [LValue, Weight(LName + '/kernel')]);
      TF_SetAttrBool(LDescription, 'transpose_a', 0);
      TF_SetAttrBool(LDescription, 'transpose_b', 0);
      LValue := Unary('Sigmoid', Binary('BiasAdd', Finish(LDescription), Weight(LName + '/bias')));
    end
    else
    begin
      raise EAudio.Create('Unsupported pinned topology layer ' + LKind);
    end;
  end;
  FOutput := LValue;
end;
constructor TTinyPitchRuntime.Create(const ARuntimeDirectory, AModelDirectory: String);
const
  { TensorFlow v2.18.1 config.proto fields: intra_op=2, inter_op=5,
    use_per_session_threads=9, operation_timeout_in_ms=11 (5000).
    https://github.com/tensorflow/tensorflow/blob/v2.18.1/tensorflow/core/protobuf/config.proto }
  CConfig: array[0..8] of Byte = ($10, 1, $28, 1, $48, 1, $58, $88, $27);
var
  LModel: TJSONObject;
  LStream: TFileStream;
  LOptions: Pointer;
  LLicenseRoot: String;
  LSetting: String;
begin
  inherited Create;
  {$if not defined(CPUX86_64) or not defined(MSWINDOWS)}
  raise EAudio.Create('Pinned inference runtime supports Win64 only');
  {$endif}
  if InterlockedCompareExchange(GActive, 1, 0) <> 0 then
  begin
    raise EAudio.Create('Only one pinned inference runtime may be live per process');
  end;
  FOwnsRuntime := True;
  LLicenseRoot := IncludeTrailingPathDelimiter(ExpandFileName(
    IncludeTrailingPathDelimiter(ARuntimeDirectory) + '..'));
  if (Sha256Bytes(ReadFileBytes(IncludeTrailingPathDelimiter(AModelDirectory) +
      'LICENSE', 16384)) <> '7c6fab51c6f84ab934211c90fd1754c505a72049ca3da2ae699c2b693c1ecfc4') or
    (Sha256Bytes(ReadFileBytes(LLicenseRoot + 'LICENSE', 16384)) <>
      '71c6915d04265772a0339bed47276942c678b45cc01534210ebe6984fd1aec65') or
    (Sha256Bytes(ReadFileBytes(LLicenseRoot + 'THIRD_PARTY_TF_C_LICENSES', 262144)) <>
      '746b15ff281fd4e2fb2b785ff36d5f2bf08aa505f34068896c123787396b8933') then
  begin
    raise EAudio.Create('Pinned model/runtime complete notices are missing or changed');
  end;
  for LSetting in ['TF_OVERRIDE_GLOBAL_THREADPOOL', 'TF_XLA_FLAGS',
    'TF_NUM_INTRAOP_THREADS', 'TF_NUM_INTEROP_THREADS', 'TF_ENABLE_ONEDNN_OPTS'] do
  begin
    if GetEnvironmentVariable(LSetting) <> '' then
    begin
      raise EAudio.Create('Runtime environment override is outside pinned policy: ' + LSetting);
    end;
  end;
  FRuntimeFile := TFileStream.Create(IncludeTrailingPathDelimiter(
    ExpandFileName(ARuntimeDirectory)) + 'tensorflow.dll', fmOpenRead or fmShareDenyWrite);
  if (FRuntimeFile.Size <> 953598464) or
    (Sha256Stream(FRuntimeFile, FRuntimeFile.Size) <> InferenceRuntimeHash) then
  begin
    raise EAudio.Create('Pinned inference runtime SHA256 differs');
  end;
  LoadRuntime(ExpandFileName(ARuntimeDirectory));
  FStatus := TF_NewStatus();
  FGraph := TF_NewGraph();
  if (FStatus = nil) or (FGraph = nil) then
  begin
    raise EAudio.Create('Inference graph/status allocation failed');
  end;
  FWeights := TStringList.Create;
  LStream := TFileStream.Create(IncludeTrailingPathDelimiter(AModelDirectory) +
    'model.json', fmOpenRead or fmShareDenyWrite);
  try
    if (LStream.Size > 65536) or
      (Sha256Stream(LStream, LStream.Size) <> InferenceModelHash) then
    begin
      raise EAudio.Create('Pinned model topology SHA256 differs');
    end;
    LStream.Position := 0;
    LModel := TJSONObject(GetJSON(LStream));
    try
      LoadWeights(AModelDirectory, LModel.Arrays['weightsManifest']);
      Build(LModel);
    finally
      LModel.Free;
    end;
  finally
    LStream.Free;
  end;
  LOptions := TF_NewSessionOptions();
  if LOptions = nil then
  begin
    raise EAudio.Create('Inference session options allocation failed');
  end;
  try
    TF_SetConfig(LOptions, @CConfig[0], SizeOf(CConfig), FStatus);
    Check;
    FSession := TF_NewSession(FGraph, LOptions, FStatus);
    Check;
  finally
    TF_DeleteSessionOptions(LOptions);
  end;
end;
destructor TTinyPitchRuntime.Destroy;
var
  I: Integer;
begin
  if FSession <> nil then
  begin
    TF_CloseSession(FSession, FStatus);
    TF_DeleteSession(FSession, FStatus);
  end;
  if FWeights <> nil then
  begin
    for I := 0 to FWeights.Count - 1 do
    begin
      FWeights.Objects[I].Free;
    end;
    FWeights.Free;
  end;
  if FGraph <> nil then
  begin
    TF_DeleteGraph(FGraph);
  end;
  if FStatus <> nil then
  begin
    TF_DeleteStatus(FStatus);
  end;
  if FOwnsRuntime then
  begin
    { Framework process pools may outlive a session. Keep its verified module
      loaded until process exit; never unload code under those native threads. }
    FreeAndNil(FRuntimeFile);
    InterlockedExchange(GActive, 0);
  end;
  inherited Destroy;
end;
function TTinyPitchRuntime.Activate(const AWindow: TAudioSamples): TPitchSalience;
var
  LInput: Pointer;
  LOutput: Pointer;
  LDimension: Int64;
  LValue: Single;
  LObservation: TInferenceObservation;
begin
  if Length(AWindow) <> 1024 then
  begin
    raise EAudio.Create('Reference requires 1024 samples');
  end;
  for LValue in AWindow do
  begin
    RequireFinite(LValue, 'Inference input sample');
  end;
  if InterlockedCompareExchange(FBusy, 1, 0) <> 0 then
  begin
    raise EAudio.Create('Inference runtime reentry is unsupported');
  end;
  LDimension := 1024;
  LInput := nil;
  LOutput := nil;
  try
    LInput := TF_AllocateTensor(1, @LDimension, 1, 4096);
    if LInput = nil then
    begin
      raise EAudio.Create('Inference input tensor allocation failed');
    end;
    Move(AWindow[0], TF_TensorData(LInput)^, 4096);
    TF_SessionRun(FSession, nil, @FInput, @LInput, 1, @FOutput, @LOutput, 1, nil, 0, nil, FStatus);
    Check;
    if (LOutput = nil) or (TF_TensorByteSize(LOutput) <> SizeOf(Result)) or
      (TF_TensorType(LOutput) <> 1) or (TF_NumDims(LOutput) <> 2) or
      (TF_Dim(LOutput, 0) <> 1) or (TF_Dim(LOutput, 1) <> 360) then
    begin
      raise EAudio.Create('Reference output size differs');
    end;
    Move(TF_TensorData(LOutput)^, Result, SizeOf(Result));
    LObservation := Default(TInferenceObservation);
    LObservation.Salience := Result;
    ValidateInferenceObservation(LObservation);
  finally
    if LOutput <> nil then
    begin
      TF_DeleteTensor(LOutput);
    end;
    if LInput <> nil then
    begin
      TF_DeleteTensor(LInput);
    end;
    InterlockedExchange(FBusy, 0);
  end;
end;
function TTinyPitchRuntime.Version: String;
begin
  Result := String(TF_Version());
end;
function TTinyPitchRuntime.EstimatorIdentity: String;
begin
  Result := InferenceEstimator;
end;
end.
