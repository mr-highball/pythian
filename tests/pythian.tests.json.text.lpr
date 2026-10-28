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
program pythian_tests_json_text;

{$mode delphi}{$H+}

uses
  SysUtils, StrUtils, pythian.audio, pythian.text, pythian.json.text, pythian.progress
  {$ifndef pas2js}, fpjson, pythian.tools.json{$endif};

type
  TObserver = class
  public
    Calls: Integer;
    Stage: String;
    Final: Boolean;
    Marker: Exception;
    SourceLast: Int64;
    SourceFinal: Int64;
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
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Invalid JSON progress count');
  if AWork.Stage = 'json_string_bytes' then
  begin
    if AWork.Done = 0 then
    begin
      SourceLast := 0;
      SourceFinal := 0;
    end;
    Check((AWork.Units = wuBytes) and (AWork.Done >= SourceLast) and
      (AWork.Done - SourceLast <= 1027), 'Encoded source-byte checkpoint changed');
    SourceLast := AWork.Done;
    if AWork.Total > 0 then
    begin
      SourceFinal := AWork.Total;
    end;
  end;
  LFinal := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  if (AWork.Stage = Stage) and (AWork.Done > 0) and (LFinal = Final) then
  begin
    raise Marker;
  end;
end;

procedure ReadCase(const ASource, AExpected: TScalarText; const AMaximum: Integer);
var
  LPosition: Integer;
  LValue: TScalarText;
begin
  LPosition := 1;
  LValue := ReadJSONString(ASource, LPosition, AMaximum, GObserver.Observe);
  Check(CompareScalarText(LValue, AExpected, AMaximum, True) = 0, 'Decoded scalar bytes differ');
  Check(LPosition = Length(ASource) + 1, 'JSON string cursor differs');
end;

procedure RejectCase(const ASource: TScalarText; const AMaximum: Integer);
var
  LPosition: Integer;
  LValue: TScalarText;
  LRejected: Boolean;
begin
  LPosition := 1;
  LValue := 'prior';
  LRejected := False;
  try
    LValue := ReadJSONString(ASource, LPosition, AMaximum, GObserver.Observe);
  except
    on LException: ETextValidation do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Malformed scalar/escape/budget admitted');
  Check((LPosition = 1) and (LValue = 'prior'), 'Rejected decoder published output/cursor');
end;

procedure CheckLongStorage;
const
  CCount = 17003;
var
  LSource: TScalarText;
  LExpected: TScalarText;
  LValue: TScalarText;
  LDocument: TScalarText;
  LPosition: Integer;
  LMaximum: Integer;
  LSourceBytes: Integer;
  I: Integer;
  J: Integer;
begin
  for I := 0 to 3 do
  begin
    case I of
      0:
        begin
          LExpected := StringOfChar('a', CCount);
          LSource := '"' + LExpected + '"';
          LMaximum := CCount;
          LSourceBytes := CCount + 2;
        end;
      1:
        begin
          LExpected := StringOfChar(#0, CCount);
          LSource := '"' + DupeString('\u0000', CCount) + '"';
          LMaximum := CCount;
          LSourceBytes := CCount * 6 + 2;
        end;
      2:
        begin
          LExpected := DupeString(ScalarText($10000), CCount);
          LSource := '"' + DupeString('\uD800\uDC00', CCount) + '"';
          LMaximum := CCount * 4;
          LSourceBytes := CCount * 12 + 2;
        end;
      3:
        begin
          LExpected := DupeString(ScalarText($E000) + ScalarText($10000), CCount);
          LSource := '"' + LExpected + '"';
          LMaximum := CCount * 7;
          LSourceBytes := LMaximum + 2;
        end;
    end;
    ReadCase(LSource, LExpected, LMaximum);
    Check(GObserver.SourceFinal = LSourceBytes, 'Final encoded UTF-8 source bytes differ');
    RejectCase(LSource, LMaximum - 1);
    LDocument := 'skip' + LSource + 'tail';
    LPosition := 5;
    LValue := ReadJSONString(LDocument, LPosition, LMaximum, GObserver.Observe);
    Check((CompareScalarText(LValue, LExpected, LMaximum, True) = 0) and
      (LPosition = Length(LSource) + 5), 'Offset decode changed text/cursor');
    Check(GObserver.SourceFinal = LSourceBytes, 'Offset decode counted unrelated prefix/suffix');
    for J := 0 to 1 do
    begin
      GObserver.Stage := 'json_string_bytes';
      GObserver.Final := J = 1;
      GObserver.Marker := Exception.Create('Big Boss original long decoder marker');
      LValue := 'prior';
      LPosition := 5;
      try
        try
          LValue := ReadJSONString(LDocument, LPosition, LMaximum, GObserver.Observe);
          Check(False, 'Long decoder ignored original abort');
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
        Check((LValue = 'prior') and (LPosition = 5),
          'Long decoder published output/cursor on abort');
      finally
        GObserver.Marker.Free;
        GObserver.Marker := nil;
        GObserver.Stage := '';
      end;
      ReadCase(LSource, LExpected, LMaximum);
    end;
  end;
  LSource := '"' + StringOfChar('x', CCount);
  RejectCase(LSource, CCount + 8);
  RejectCase(LSource + '\uD800"', CCount + 8);
  RejectCase(LSource + #0 + '"', CCount + 8);
end;

procedure CheckStrings;
var
  LBad: TScalarText;
  LSource: TScalarText;
  LValue: TScalarText;
  LPosition: Integer;
  LBytes: Integer;
  LScalar: Cardinal;
  I: Integer;
begin
  ReadCase('""', '', 0);
  ReadCase('"hello"', 'hello', 5);
  ReadCase('"\"\\\/\b\f\n\r\t\u0000"', '"\/' + #8 + #12 + #10 + #13 + #9 + #0, 9);
  ReadCase('"\u00e9"', ScalarText($E9), 2);
  ReadCase('"\uD7FF\uE000"', ScalarText($D7FF) + ScalarText($E000), 6);
  ReadCase('"\uD800\uDC00"', ScalarText($10000), 4);
  ReadCase('"\uDBFF\uDFFF"', ScalarText($10FFFF), 4);
  ReadCase('"e\u0301"', 'e' + ScalarText($301), 3);
  ReadCase('"' + ScalarText($10000) + '"', ScalarText($10000), 4);
  for I := 0 to 14 do
  begin
    case I of
      0: LBad := '';
      1: LBad := 'x';
      2: LBad := '"';
      3: LBad := '"x';
      4: LBad := '"\"';
      5: LBad := '"\v"';
      6: LBad := '"\u123"';
      7: LBad := '"\uX000"';
      8: LBad := '"\uD800"';
      9: LBad := '"\uDC00"';
      10: LBad := '"\uD800\u0041"';
      11: LBad := '"\uD800x"';
      12: LBad := '"' + #1 + '"';
      13: LBad := '"' + #0 + '"';
      14: LBad := '"\uD800\uD800"';
    end;
    RejectCase(LBad, 64);
  end;
  RejectCase('"\u00e9"', 1);
  RejectCase('"\uD800\uDC00"', 3);
  RejectCase('"a"', 0);
  {$ifdef pas2js}
  RejectCase('"' + #$D800 + '"', 8);
  RejectCase('"' + #$DC00 + '"', 8);
  {$else}
  RejectCase(TScalarText('"') + #$ED#$A0#$80 + '"', 8);
  RejectCase(TScalarText('"') + #$C0#$AF + '"', 8);
  RejectCase(TScalarText('"') + #$F4#$90#$80#$80 + '"', 8);
  {$endif}
  LSource := ScalarText($E000) + ScalarText($10000);
  LPosition := 1;
  LScalar := ReadTextScalar(LSource, LPosition, LBytes);
  Check((LScalar = $E000) and (LBytes = 3), 'Primary scalar traversal differs');
  LScalar := ReadTextScalar(LSource, LPosition, LBytes);
  Check((LScalar = $10000) and (LBytes = 4) and
    (LPosition = Length(LSource) + 1), 'Primary astral traversal differs');
  LSource := 'x"' + StringOfChar('a', 12000) + '"y';
  for I := 0 to 1 do
  begin
    LPosition := 2;
    LValue := 'prior';
    GObserver.Stage := 'json_string_bytes';
    GObserver.Final := I = 1;
    GObserver.Marker := Exception.Create('Big Boss original JSON string marker');
    try
      try
        LValue := ReadJSONString(LSource, LPosition, 12000, GObserver.Observe);
        Check(False, 'JSON decoder ignored original abort');
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
    finally
      GObserver.Marker.Free;
      GObserver.Marker := nil;
      GObserver.Stage := '';
    end;
    Check((LValue = 'prior') and (LPosition = 2), 'Abort published JSON string/cursor');
    LValue := ReadJSONString(LSource, LPosition, 12000, GObserver.Observe);
    Check((Length(LValue) = 12000) and (LPosition = Length(LSource)), 'JSON retry differs');
  end;
end;

{$ifndef pas2js}
procedure CheckNative;
const
  CDocument: RawByteString = '{"\uE000\uD800\uDC00":"\uE000\uD800\uDC00\u0000",' +
    '"n":9007199254740991,"f":1e-20,"s":"0","a":[true,null]}';
  CExpectedFloat: Double = 1e-20;
var
  LData: TJSONData;
  LPrior: TJSONData;
  LSource: TScalarText;
  LInvalid: TScalarText;
  LRejected: Boolean;
  LStage: String;
  I: Integer;
  LFinal: Boolean;
begin
  LData := ParseNativeJSON(CDocument, 1024, 4, GObserver.Observe);
  try
    Check(LData.JSONType = jtObject, 'Native JSON root differs');
    Check(CompareScalarText(TJSONObject(LData).Names[0],
      ScalarText($E000) + ScalarText($10000), 8) = 0, 'Native escaped key differs');
    Check(CompareScalarText(TJSONObject(LData).Items[0].AsString,
      ScalarText($E000) + ScalarText($10000) + #0, 8, True) = 0, 'Native escaped value differs');
    Check(TJSONObject(LData).Int64s['n'] = 9007199254740991, 'Native exact integer changed');
    Check(TJSONObject(LData).Strings['s'] = '0', 'Native string token collided with framing');
    Check(TJSONObject(LData).Find('f').AsFloat = CExpectedFloat, 'Native numeric value changed');
  finally
    LData.Free;
  end;
  for I := 0 to 7 do
  begin
    case I of
      0: LInvalid := '{"a":1,"\u0061":2}';
      1: LInvalid := '{"a":1,}';
      2: LInvalid := '{a:1}';
      3: LInvalid := '{"a":"\uD800"}';
      4: LInvalid := '{"a":1} trailing';
      5: LInvalid := '{"a":[' + StringOfChar('[', 8) + '0' + StringOfChar(']', 8) + ']}';
      6: LInvalid := '{"a":"x' + #0 + 'y"}';
      7: LInvalid := '{"a":1}' + #0;
    end;
    LRejected := False;
    LPrior := TJSONIntegerNumber.Create(42);
    LData := LPrior;
    try
      try
        LData := ParseNativeJSON(LInvalid, 1024, 4, GObserver.Observe);
      except
        on LException: Exception do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LData = LPrior), 'Native malformed JSON published tree');
    finally
      if LData <> LPrior then
      begin
        LData.Free;
      end;
      LPrior.Free;
    end;
  end;
  LSource := '{"x":"' + StringOfChar('a', 12000) + '"}';
  for I := 0 to 3 do
  begin
    case I of
      0, 1: LStage := 'native_json_prepare_bytes';
      2: LStage := 'native_json_parse';
      3: LStage := 'native_json_ready';
    end;
    LFinal := I <> 0;
    LPrior := TJSONIntegerNumber.Create(42);
    LData := LPrior;
    GObserver.Stage := LStage;
    GObserver.Final := LFinal;
    GObserver.Marker := Exception.Create('Big Boss original native JSON marker');
    try
      try
        LData := ParseNativeJSON(LSource, 16000, 4, GObserver.Observe);
        Check(False, 'Native JSON ignored original abort');
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
      Check((LData = LPrior) and (LPrior.AsInteger = 42), 'Native abort changed caller tree');
    finally
      GObserver.Marker.Free;
      GObserver.Marker := nil;
      GObserver.Stage := '';
      if LData <> LPrior then
      begin
        LData.Free;
      end;
      LPrior.Free;
    end;
    LData := ParseNativeJSON(LSource, 16000, 4, GObserver.Observe);
    try
      Check(Length(TJSONObject(LData).Strings['x']) = 12000, 'Native JSON retry differs');
    finally
      LData.Free;
    end;
  end;
end;
{$endif}

begin
  GObserver := TObserver.Create;
  try
    CheckStrings;
    CheckLongStorage;
    {$ifndef pas2js}
    CheckNative;
    {$endif}
    WriteLn('JSON scalar/consumer checks=', GChecks, ' original abort/retries=', GAborts,
      ' callbacks=', GObserver.Calls);
  finally
    GObserver.Free;
  end;
end.
