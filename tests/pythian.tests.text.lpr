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
program pythian_tests_text;

{$mode delphi}{$H+}

uses SysUtils, pythian.audio, pythian.progress, pythian.text, pythian.corpus.text;

type
  TObserver = class
  public
    Stage: String;
    Marker: Exception;
    LastBytes: Int64;
    LastScalars: Int64;
    Calls: Integer;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
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
begin
  Inc(Calls);
  if (AWork.Done < 0) or (AWork.Total < 0) or
    ((AWork.Total > 0) and (AWork.Done > AWork.Total)) then
  begin
    raise Exception.Create('Invalid text work count');
  end;
  if ((AWork.Stage = 'text_validate_bytes') and (AWork.Units <> wuBytes)) or
    ((AWork.Stage = 'text_compare_scalars') and (AWork.Units <> wuItems)) then
  begin
    raise Exception.Create('Text work uses incorrect units');
  end;
  if (AWork.Stage = Stage) and (AWork.Done >= 256) and (AWork.Total = 0) then
  begin
    raise Marker;
  end;
  if AWork.Total > 0 then
  begin
    if AWork.Stage = 'text_validate_bytes' then
    begin
      LastBytes := AWork.Done;
    end;
    if AWork.Stage = 'text_compare_scalars' then
    begin
      LastScalars := AWork.Done;
    end;
  end;
end;

{$ifndef pas2js}
function Bytes(const ABytes: array of Byte): TScalarText;
var
  LIndex: Integer;
begin
  SetLength(Result, Length(ABytes));
  for LIndex := 0 to High(ABytes) do
  begin
    Result[LIndex + 1] := AnsiChar(ABytes[LIndex]);
  end;
end;
{$endif}

function ScalarCase(const AIndex: Integer): TScalarText;
begin
  {$ifdef pas2js}
  case AIndex of
    0: Result := Chr($7F);
    1: Result := Chr($80);
    2: Result := Chr($7FF);
    3: Result := Chr($800);
    4: Result := Chr($D7FF);
    5: Result := Chr($E000);
    6: Result := Chr($FFFF);
    7: Result := Chr($D800) + Chr($DC00);
    8: Result := Chr($DBFF) + Chr($DFFF);
    9: Result := Chr($D83D) + Chr($DE00);
    10: Result := Chr($E9);
    11: Result := 'e' + Chr($301);
  end;
  {$else}
  case AIndex of
    0: Result := Bytes([$7F]);
    1: Result := Bytes([$C2, $80]);
    2: Result := Bytes([$DF, $BF]);
    3: Result := Bytes([$E0, $A0, $80]);
    4: Result := Bytes([$ED, $9F, $BF]);
    5: Result := Bytes([$EE, $80, $80]);
    6: Result := Bytes([$EF, $BF, $BF]);
    7: Result := Bytes([$F0, $90, $80, $80]);
    8: Result := Bytes([$F4, $8F, $BF, $BF]);
    9: Result := Bytes([$F0, $9F, $98, $80]);
    10: Result := Bytes([$C3, $A9]);
    11: Result := Bytes([$65, $CC, $81]);
  end;
  {$endif}
end;

procedure Reject(const AText: TScalarText; const AMaximum: Integer;
  const AAllowEmpty: Boolean = True; const AAllowNul: Boolean = False);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ValidateScalarText(AText, AMaximum, AAllowEmpty, AAllowNul);
  except
    on ETextValidation do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Invalid scalar/policy accepted');
end;

procedure AbortAndRetry(const AText: TScalarText; const AComparison: Boolean);
var
  LRejected: Boolean;
begin
  GObserver.Stage := 'text_validate_bytes';
  if AComparison then
  begin
    GObserver.Stage := 'text_compare_scalars';
  end;
  GObserver.Marker := Exception.Create('Big Boss scalar observer marker');
  LRejected := False;
  try
    try
      if AComparison then
      begin
        CompareScalarText(AText, AText, 8192, False, GObserver.Observe);
      end
      else
      begin
        ValidateScalarText(AText, 8192, False, False, GObserver.Observe);
      end;
    except
      on LException: Exception do
      begin
        if LException <> GObserver.Marker then
        begin
          raise;
        end;
        GObserver.Marker := nil;
        LRejected := True;
      end;
    end;
  finally
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    GObserver.Stage := '';
  end;
  Check(LRejected, 'Original callback exception did not escape');
  ValidateScalarText(AText, 8192, False, False, GObserver.Observe);
  Check(CompareScalarText(AText, AText, 8192, False, GObserver.Observe) = 0,
    'Retry or borrowed input differs');
end;

var
  LIndex: Integer;
  LBytes: Integer;
  LValue: TScalarText;
  LLong: TScalarText;
  LTagged: TScalarText;
begin
  GObserver := TObserver.Create;
  try
    ValidateScalarText('', 0);
    ValidateScalarText(#0, 1, False, True);
    ValidateScalarText('a' + #0 + 'b', 3, False, True);
    Reject('', 0, False);
    Reject('', -1);
    Reject(#0, 1);
    Reject('a' + #0 + 'b', 3);
    Check(CompareScalarText('', 'a', 1) = -1, 'Empty prefix order');
    Check(CompareScalarText('a' + #0, 'a' + #1, 2, True) = -1, 'Explicit NUL order');
    for LIndex := 0 to 11 do
    begin
      LValue := ScalarCase(LIndex);
      LBytes := 3;
      case LIndex of
        0: LBytes := 1;
        1, 2, 10: LBytes := 2;
        7, 8, 9: LBytes := 4;
      end;
      ValidateScalarText(LValue, LBytes, False, False, GObserver.Observe);
      Check(GObserver.LastBytes = LBytes, 'UTF-8 byte count uses host code units');
      Reject(LValue, LBytes - 1);
      Check(CompareScalarText(LValue, LValue, LBytes) = 0, 'Scalar self order');
      if LIndex in [1..8] then
      begin
        Check(CompareScalarText(ScalarCase(LIndex - 1), LValue, 4) = -1,
          'Scalar/UTF-8 byte order differs');
      end;
    end;
    Check(CompareScalarText(ScalarCase(10), ScalarCase(11), 3) <> 0,
      'Text must not normalize distinct identities');
    {$ifdef pas2js}
    Reject(Chr($D800), 4);
    Reject(Chr($DC00), 4);
    Reject(Chr($D800) + 'x', 4);
    Reject(Chr($DBFF) + Chr($E000), 4);
    {$else}
    Reject(Bytes([$80]), 4);
    Reject(Bytes([$C0, $AF]), 4);
    Reject(Bytes([$C1, $80]), 4);
    Reject(Bytes([$C2]), 4);
    Reject(Bytes([$E0, $80, $80]), 4);
    Reject(Bytes([$ED, $A0, $80]), 4);
    Reject(Bytes([$F0, $80, $80, $80]), 4);
    Reject(Bytes([$F0, $90, $80]), 4);
    Reject(Bytes([$F4, $90, $80, $80]), 4);
    Reject(Bytes([$F5, $80, $80, $80]), 4);
    Reject(Bytes([$FF]), 4);
    LTagged := Bytes([$E2, $82, $AC]);
    SetCodePage(LTagged, 1252, False);
    ValidateScalarText(LTagged, 3, False);
    Check(CompareScalarText(LTagged, Bytes([$E2, $82, $AC]), 3) = 0,
      'Host code-page tag must not transcode raw UTF-8');
    {$endif}
    LLong := '';
    LValue := ScalarCase(9);
    for LIndex := 1 to 2048 do
    begin
      LLong := LLong + LValue;
    end;
    ValidateScalarText(LLong, 8192, False, False, GObserver.Observe);
    Check(GObserver.LastBytes = 8192, 'Long validation byte total');
    Reject(LLong, 8191);
    Check(CompareScalarText(LLong, LLong, 8192, False, GObserver.Observe) = 0,
      'Long scalar comparison');
    Check(GObserver.LastScalars = 2048, 'Comparison counts scalars, not code units');
    AbortAndRetry(LLong, False);
    AbortAndRetry(LLong, True);
    Check((GObserver.LastBytes = 8192) and (GObserver.LastScalars = 2048),
      'Retry work totals differ');
    Check(GObserver.Calls < 200, 'Scalar callbacks must remain aggregated');
    ValidateCorpusText('a');
    WriteLn('Primary scalar text: ', GChecks,
      ' checks; explicit byte/NUL/empty policies, scalar order and original abort/retry pass');
  finally
    GObserver.Free;
  end;
end.
