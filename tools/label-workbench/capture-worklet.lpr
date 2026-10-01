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
program capture_worklet;
{$mode delphi}
{$H+}
{$modeswitch externalclass}
uses JS;
type
  TCaptureMessage = reference to procedure(AEvent: TJSObject);
  TCapturePort = class external name 'MessagePort' (TJSObject)
  public
    onmessage: TCaptureMessage;
    procedure postMessage(AValue: JSValue);
  end;
var
  ProcessorBase: TJSFunction; external name 'AudioWorkletProcessor';
  ProcessorSelf: TJSObject; external name 'this';
  WorkletRate: Double; external name 'sampleRate';
function Construct(ATarget: TJSFunction; AArguments: TJSArray;
  AConstructor: TJSFunction): TJSObject; external name 'Reflect.construct';
procedure SetPrototype(AObject, APrototype: TJSObject); external name 'Object.setPrototypeOf';
procedure Register(const AName: String; AConstructor: TJSFunction);
  external name 'registerProcessor';
procedure Flush(AProcessor: TJSObject; AFinal: Boolean);
var
  LMessage: TJSObject;
  LBuffer: TJSFloat32Array;
  LCount: NativeInt;
  LFrames: NativeInt;
begin
  LCount := NativeInt(AProcessor['count']);
  LFrames := NativeInt(AProcessor['frames']);
  if LCount > 0 then
  begin
    LBuffer := TJSFloat32Array(AProcessor['samples']);
    LMessage := TJSObject.new;
    LMessage['kind'] := 'samples';
    LMessage['start_frame'] := LFrames - LCount;
    LMessage['samples'] := LBuffer.subarray(0, LCount);
    TCapturePort(AProcessor['port']).postMessage(LMessage);
    AProcessor['count'] := 0;
  end;
  if AFinal and not Boolean(AProcessor['finished']) then
  begin
    AProcessor['finished'] := True;
    LMessage := TJSObject.new;
    LMessage['kind'] := 'ended';
    LMessage['frames'] := LFrames;
    LMessage['sample_rate'] := WorkletRate;
    TCapturePort(AProcessor['port']).postMessage(LMessage);
  end;
end;
function Process(AInputs, AOutputs: TJSArray; AParameters: TJSObject): Boolean;
var
  LChannels: TJSArray;
  LOutput: TJSArray;
  LSamples: TJSFloat32Array;
  LBuffer: TJSFloat32Array;
  LIndex: NativeInt;
  LChannel: NativeInt;
  LCount: NativeInt;
  LFrames: NativeInt;
  LValue: Double;
begin
  for LChannel := 0 to AOutputs.length - 1 do
  begin
    LOutput := TJSArray(AOutputs[LChannel]);
    for LIndex := 0 to LOutput.length - 1 do
    begin
      TJSFloat32Array(LOutput[LIndex]).fill(0);
    end;
  end;
  Result := not Boolean(ProcessorSelf['finished']);
  if not Result or (AInputs.length = 0) then
  begin
    Exit;
  end;
  LChannels := TJSArray(AInputs[0]);
  if LChannels.length = 0 then
  begin
    Exit;
  end;
  LSamples := TJSFloat32Array(LChannels[0]);
  LBuffer := TJSFloat32Array(ProcessorSelf['samples']);
  LCount := NativeInt(ProcessorSelf['count']);
  LFrames := NativeInt(ProcessorSelf['frames']);
  for LIndex := 0 to LSamples.length - 1 do
  begin
    if LFrames >= Trunc(WorkletRate * 120) then
    begin
      ProcessorSelf['count'] := LCount;
      ProcessorSelf['frames'] := LFrames;
      Flush(ProcessorSelf, True);
      Result := False;
      Exit;
    end;
    LValue := 0;
    for LChannel := 0 to LChannels.length - 1 do
    begin
      LValue := LValue + Double(TJSFloat32Array(LChannels[LChannel])[LIndex]);
    end;
    LBuffer[LCount] := LValue / LChannels.length;
    Inc(LCount);
    Inc(LFrames);
    if LCount = 4096 then
    begin
      ProcessorSelf['count'] := LCount;
      ProcessorSelf['frames'] := LFrames;
      Flush(ProcessorSelf, False);
      LCount := 0;
    end;
  end;
  ProcessorSelf['count'] := LCount;
  ProcessorSelf['frames'] := LFrames;
end;
function ProcessorConstructor: TJSObject;
var
  LProcessor: TJSObject;
begin
  LProcessor := Construct(ProcessorBase, TJSArray.new, TJSFunction(@ProcessorConstructor));
  LProcessor['samples'] := TJSFloat32Array.new(4096);
  LProcessor['count'] := 0;
  LProcessor['frames'] := 0;
  LProcessor['finished'] := False;
  TCapturePort(LProcessor['port']).onmessage :=
    procedure(AEvent: TJSObject)
    begin
      if String(AEvent['data']) = 'stop' then
      begin
        Flush(LProcessor, True);
      end;
    end;
  Result := LProcessor;
end;
var
  ConstructorFunction: TJSFunction;
begin
  ConstructorFunction := TJSFunction(@ProcessorConstructor);
  SetPrototype(TJSObject(ConstructorFunction['prototype']), TJSObject(ProcessorBase['prototype']));
  TJSObject(ConstructorFunction['prototype'])['process'] := @Process;
  Register('pythian-capture', ConstructorFunction);
end.
