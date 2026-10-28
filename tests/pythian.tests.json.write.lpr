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
program pythian_tests_json_write;

{$mode delphi}{$H+}

uses
  SysUtils, pythian.text, pythian.json.text, pythian.progress
  {$ifndef pas2js}, Math, fpjson, pythian.tools.json{$endif};

type
  { Observe real byte increments and inject the exact borrowed exception. }
  TObserver = class
  public
    Calls: Integer;
    LastBytes: Int64;
    FinalBytes: Int64;
    Stage: String;
    Final: Boolean;
    Marker: Exception;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GObserver: TObserver;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LFinal: Boolean;
begin
  Inc(Calls);
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Invalid emitted work');
  if AWork.Stage = 'json_write_bytes' then
  begin
    if AWork.Done = 0 then
    begin
      LastBytes := 0;
      FinalBytes := 0;
    end;
    Check((AWork.Done >= LastBytes) and (AWork.Done - LastBytes <= 4099),
      'JSON byte checkpoints exceed the declared increment');
    LastBytes := AWork.Done;
    if AWork.Total > 0 then
    begin
      FinalBytes := AWork.Total;
    end;
  end;
  LFinal := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  if (AWork.Stage = Stage) and (AWork.Done > 0) and (LFinal = Final) then
  begin
    raise Marker;
  end;
end;

function Quoted(const ASource: TScalarText; const AMaximum: Integer;
  const AStrict: Boolean = False): TScalarText;
var
  LWriter: TJSONTextBuffer;
begin
  LWriter := TJSONTextBuffer.Create(AMaximum, GObserver.Observe);
  try
    LWriter.AppendQuoted(ASource, AStrict);
    Result := LWriter.Finish;
  finally
    LWriter.Free;
  end;
end;

procedure CheckPortable;
var
  LSource: TScalarText;
  LExpected: TScalarText;
  LActual: TScalarText;
  LBad: TScalarText;
  LPosition: Integer;
  LWriter: TJSONTextBuffer;
  LRejected: Boolean;
  I: Integer;
begin
  LSource := '"\/' + #0 + #8 + #9 + #10 + #12 + #13 + #31;
  LExpected := '"\"\\/\u0000\b\t\n\f\r\u001F"';
  Check(Quoted(LSource, Length(LExpected)) = LExpected, 'Explicit escape bytes differ');
  Check(Quoted('/', 4, True) = '"\/"', 'Strict slash differs');
  Check(Quoted('', 2) = '""', 'Empty string differs');
  LSource := '';
  for I := 0 to 31 do
  begin
    LSource := LSource + ScalarText(I);
  end;
  LSource := LSource + ScalarText($D7FF) + ScalarText($E000) + ScalarText($10000) +
    ScalarText($10FFFF) + 'e' + ScalarText($301);
  LActual := Quoted(LSource, 256);
  LPosition := 1;
  Check(CompareScalarText(ReadJSONString(LActual, LPosition, 256), LSource, 256, True) = 0,
    'Scalar/control round trip differs');
  Check(LPosition = Length(LActual) + 1, 'Quoted scalar cursor differs');
  Check(Quoted(ScalarText($10000), 6) = '"' + ScalarText($10000) + '"',
    'Exact UTF-8 byte budget differs');
  for I := 0 to 3 do
  begin
    LRejected := False;
    LActual := 'prior';
    try
      case I of
        0: LActual := Quoted('', 1);
        1: LActual := Quoted(ScalarText($10000), 5);
        2: LActual := Quoted(#0, 7);
        3:
          begin
            {$ifdef pas2js}
            LBad := #$D800;
            {$else}
            LBad := #$FF;
            {$endif}
            LActual := Quoted(LBad, 32);
          end;
      end;
    except
      on LException: ETextValidation do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LActual = 'prior'), 'Bad scalar/budget published text');
  end;
  LWriter := TJSONTextBuffer.Create(8, GObserver.Observe);
  try
    LRejected := False;
    try
      LWriter.AppendASCII(ScalarText($E9));
    except
      on LException: ETextValidation do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Non-ASCII syntax admitted');
    LRejected := False;
    try
      LActual := LWriter.Finish;
    except
      on LException: ETextValidation do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Failed staging was publishable');
  finally
    LWriter.Free;
  end;
  LSource := StringOfChar('x', 17000);
  for I := 0 to 3 do
  begin
    case I of
      0, 1: GObserver.Stage := 'json_write_bytes';
      2: GObserver.Stage := 'json_write_finish';
      3: GObserver.Stage := 'json_write_ready';
    end;
    GObserver.Final := I > 0;
    GObserver.Marker := Exception.Create('Big Boss original portable JSON write abort');
    LActual := 'prior';
    try
      try
        LActual := Quoted(LSource, 17002);
        Check(False, 'Portable writer ignored cancellation');
      except
        on LException: Exception do
        begin
          if LException <> GObserver.Marker then
          begin
            raise;
          end;
          GObserver.Marker := nil;
          Inc(GAborts);
        end;
      end;
      Check(LActual = 'prior', 'Portable abort published caller output');
    finally
      GObserver.Marker.Free;
      GObserver.Marker := nil;
      GObserver.Stage := '';
    end;
    Check(Quoted(LSource, 17002) = '"' + LSource + '"', 'Portable retry differs');
    Check(GObserver.FinalBytes = 17002, 'Final actual byte count differs');
  end;
end;

{$ifndef pas2js}
procedure CheckNative;
var
  LRoot: TJSONObject;
  LRows: TJSONArray;
  LChild: TJSONArray;
  LData: TJSONData;
  LSource: TScalarText;
  LExpected: TJSONStringType;
  LActual: TJSONStringType;
  LCompressed: Boolean;
  LStrict: Boolean;
  LRejected: Boolean;
  I: Integer;
  J: Integer;
begin
  LCompressed := TJSONData.CompressedJSON;
  LStrict := TJSONString.StrictEscaping;
  LRoot := TJSONObject.Create;
  try
    LRoot.Add('empty-object', TJSONObject.Create);
    LRoot.Add('empty-array', TJSONArray.Create);
    LRows := TJSONArray.Create;
    LRoot.Add('rows', LRows);
    for I := 0 to 511 do
    begin
      LRows.Add(I);
    end;
    LRows.Add(TJSONInt64Number.Create(Low(Int64)));
    LRows.Add(TJSONQWordNumber.Create(High(QWord)));
    LRows.Add(TJSONFloatNumber.Create(1.0e-20));
    LRows.Add(TJSONFloatNumber.Create(-0.0));
    LRows.Add(True);
    LRows.Add(False);
    LRows.Add(TJSONData(nil));
    LSource := ScalarText($E000) + ScalarText($10000);
    LRows.Add(NativeJSONText(LSource));
    LSource := '';
    for I := 0 to 31 do
    begin
      LSource := LSource + AnsiChar(I);
    end;
    LSource := LSource + '"\/';
    LRoot.Add(NativeJSONText(ScalarText($E000) + '/'), NativeJSONText(LSource));
    LRoot.Add('long', StringOfChar('x', 18000));
    for I := 0 to 3 do
    begin
      TJSONData.CompressedJSON := I mod 2 = 1;
      TJSONString.StrictEscaping := I > 1;
      LExpected := LRoot.AsJSON;
      LActual := WriteNativeJSON(LRoot, Length(LExpected), GObserver.Observe);
      Check(LActual = LExpected, 'RTL canonical punctuation/numeric/scalar bytes differ');
      Check(GObserver.FinalBytes = Length(LExpected), 'Native emitted byte total differs');
      Check(LRoot.AsJSON = LExpected, 'Writer changed the input tree/settings');
    end;
    TJSONData.CompressedJSON := LCompressed;
    TJSONString.StrictEscaping := LStrict;
    LExpected := LRoot.AsJSON;
    for I := 0 to 7 do
    begin
      case I of
        0, 1: GObserver.Stage := 'json_write_bytes';
        2, 3: GObserver.Stage := 'native_json_write_items';
        4: GObserver.Stage := 'json_write_finish';
        5: GObserver.Stage := 'json_write_ready';
        6: GObserver.Stage := 'native_json_write_copy';
        7: GObserver.Stage := 'native_json_write_ready';
      end;
      GObserver.Final := not (I in [0, 2]);
      GObserver.Marker := Exception.Create('Big Boss original native JSON write abort');
      LActual := 'prior';
      try
        try
          LActual := WriteNativeJSON(LRoot, Length(LExpected), GObserver.Observe);
          Check(False, 'Native writer ignored cancellation');
        except
          on LException: Exception do
          begin
            if LException <> GObserver.Marker then
            begin
              raise;
            end;
            GObserver.Marker := nil;
            Inc(GAborts);
          end;
        end;
        Check((LActual = 'prior') and (LRoot.AsJSON = LExpected),
          'Native abort changed caller output/input');
      finally
        GObserver.Marker.Free;
        GObserver.Marker := nil;
        GObserver.Stage := '';
      end;
      Check(WriteNativeJSON(LRoot, Length(LExpected), GObserver.Observe) = LExpected,
        'Native cancellation retry differs');
    end;
    LRejected := False;
    LActual := 'prior';
    try
      LActual := WriteNativeJSON(LRoot, Length(LExpected) - 1, GObserver.Observe);
    except
      on LException: ETextValidation do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LActual = 'prior'), 'Output byte budget published text');
    LRows.Add(TJSONFloatNumber.Create(NaN));
    LRejected := False;
    try
      LActual := WriteNativeJSON(LRoot, High(Integer), GObserver.Observe);
    except
      on LException: Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LActual = 'prior'), 'Nonfinite JSON published output');
  finally
    LRoot.Free;
    TJSONData.CompressedJSON := LCompressed;
    TJSONString.StrictEscaping := LStrict;
  end;
  LRows := TJSONArray.Create;
  try
    LChild := LRows;
    for J := 1 to 512 do
    begin
      LData := TJSONArray.Create;
      LChild.Add(LData);
      LChild := TJSONArray(LData);
    end;
    LChild.Add('end');
    LExpected := LRows.AsJSON;
    Check(WriteNativeJSON(LRows, Length(LExpected), GObserver.Observe) = LExpected,
      'Deep iterative tree formatting differs');
  finally
    LRows.Free;
  end;
end;
{$endif}

begin
  GObserver := TObserver.Create;
  try
    CheckPortable;
    {$ifndef pas2js}
    CheckNative;
    {$endif}
    WriteLn('JSON write checks=', GChecks, ' original abort/retries=', GAborts,
      ' callbacks=', GObserver.Calls);
  finally
    GObserver.Free;
  end;
end.
