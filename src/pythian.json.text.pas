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
unit pythian.json.text;

{$mode delphi}{$H+}

interface

uses
  pythian.text, pythian.progress;

{ Read a quoted JSON string at a one-based source position. Only scalar text is
  admitted: literal controls and malformed bytes, escapes or surrogate pairs
  reject. Escaped NUL is valid JSON; callers retain their own semantic policy.
  AMaximumBytes bounds decoded UTF-8 bytes on both targets. No normalization.
  On any exception the caller's string assignment and position are preserved.
  Borrowed callbacks count actual consumed source UTF-8 bytes, including quotes;
  total is unknown until closing quote. They do not yield an event loop. }
function ReadJSONString(const ADocument: TScalarText; var APosition: Integer;
  const AMaximumBytes: Integer;
  const AProgress: TWorkProgressCallback = nil): TScalarText;

implementation

procedure InvalidJSONText;
begin
  raise ETextValidation.Create('JSON string requires complete canonical scalar text and valid escapes');
end;

function ReadJSONString(const ADocument: TScalarText; var APosition: Integer;
  const AMaximumBytes: Integer; const AProgress: TWorkProgressCallback): TScalarText;
var
  LPosition: Integer;
  LFirst: Integer;
  LBytes: Integer;
  LDecodedBytes: Integer;
  LUsed: Integer;
  LCapacity: Integer;
  LSourceBytes: Int64;
  LNextReport: Int64;
  LScalar: Cardinal;
  LLow: Cardinal;
  LEscape: Char;
  LBuffer: TScalarText;
  LEncoded: TScalarText;
  LResult: TScalarText;

  procedure Consumed(const ACount: Integer);
  begin
    Inc(LSourceBytes, ACount);
    if LSourceBytes >= LNextReport then
    begin
      ReportWork(AProgress, 'json_string_bytes', wuBytes, LSourceBytes, 0);
      LNextReport := LSourceBytes + 1024;
    end;
  end;

  procedure Append(const AText: TScalarText; const AFirst, ACount, ABytes: Integer);
  var
    LNewCapacity: Integer;
    I: Integer;
  begin
    if LDecodedBytes > AMaximumBytes - ABytes then
    begin
      raise ETextValidation.Create('JSON string exceeds its decoded UTF-8 byte budget');
    end;
    Inc(LDecodedBytes, ABytes);
    if LCapacity < LUsed + ACount then
    begin
      if LCapacity > AMaximumBytes div 2 then
      begin
        LNewCapacity := AMaximumBytes;
      end
      else
      begin
        LNewCapacity := LCapacity * 2;
        if LNewCapacity < 16 then
        begin
          LNewCapacity := 16;
        end;
        if LNewCapacity > AMaximumBytes then
        begin
          LNewCapacity := AMaximumBytes;
        end;
      end;
      SetLength(LBuffer, LNewCapacity);
      LCapacity := LNewCapacity;
    end;
    for I := 0 to ACount - 1 do
    begin
      LBuffer[LUsed + I + 1] := AText[AFirst + I];
    end;
    Inc(LUsed, ACount);
  end;

  function HexQuad: Cardinal;
  var
    I: Integer;
    LDigit: Integer;
  begin
    Result := 0;
    for I := 1 to 4 do
    begin
      if LPosition > Length(ADocument) then
      begin
        InvalidJSONText;
      end;
      case ADocument[LPosition] of
        '0'..'9': LDigit := Ord(ADocument[LPosition]) - Ord('0');
        'a'..'f': LDigit := Ord(ADocument[LPosition]) - Ord('a') + 10;
        'A'..'F': LDigit := Ord(ADocument[LPosition]) - Ord('A') + 10;
      else
        InvalidJSONText;
        LDigit := 0;
      end;
      Result := Result * 16 + Cardinal(LDigit);
      Inc(LPosition);
      Consumed(1);
    end;
  end;

begin
  if (AMaximumBytes < 0) or (APosition < 1) or
    (APosition > Length(ADocument)) then
  begin
    InvalidJSONText;
  end;
  if ADocument[APosition] <> '"' then
  begin
    InvalidJSONText;
  end;
  LPosition := APosition + 1;
  LDecodedBytes := 0;
  LUsed := 0;
  LCapacity := 0;
  LBuffer := '';
  LSourceBytes := 1;
  LNextReport := 1024;
  ReportWork(AProgress, 'json_string_bytes', wuBytes, 0, 0);
  while LPosition <= Length(ADocument) do
  begin
    if ADocument[LPosition] = '"' then
    begin
      Inc(LPosition);
      Consumed(1);
      LResult := Copy(LBuffer, 1, LUsed);
      ReportWork(AProgress, 'json_string_bytes', wuBytes, LSourceBytes, LSourceBytes);
      APosition := LPosition;
      Result := LResult;
      Exit;
    end;
    if ADocument[LPosition] <> '\' then
    begin
      LFirst := LPosition;
      LScalar := ReadTextScalar(ADocument, LPosition, LBytes);
      if LScalar < 32 then
      begin
        InvalidJSONText;
      end;
      Consumed(LBytes);
      Append(ADocument, LFirst, LPosition - LFirst, LBytes);
      Continue;
    end;
    Inc(LPosition);
    Consumed(1);
    if LPosition > Length(ADocument) then
    begin
      InvalidJSONText;
    end;
    LEscape := ADocument[LPosition];
    Inc(LPosition);
    Consumed(1);
    case LEscape of
      '"': LScalar := 34;
      '\': LScalar := 92;
      '/': LScalar := 47;
      'b': LScalar := 8;
      'f': LScalar := 12;
      'n': LScalar := 10;
      'r': LScalar := 13;
      't': LScalar := 9;
      'u':
        begin
          LScalar := HexQuad;
          if (LScalar >= $D800) and (LScalar <= $DBFF) then
          begin
            if (Length(ADocument) - LPosition < 1) or
              (ADocument[LPosition] <> '\') or (ADocument[LPosition + 1] <> 'u') then
            begin
              InvalidJSONText;
            end;
            Inc(LPosition, 2);
            Consumed(2);
            LLow := HexQuad;
            if (LLow < $DC00) or (LLow > $DFFF) then
            begin
              InvalidJSONText;
            end;
            LScalar := $10000 + (LScalar - $D800) * $400 + LLow - $DC00;
          end
          else if (LScalar >= $DC00) and (LScalar <= $DFFF) then
          begin
            InvalidJSONText;
          end;
        end;
    else
      InvalidJSONText;
      LScalar := 0;
    end;
    LEncoded := ScalarText(LScalar);
    if LScalar < $80 then
    begin
      LBytes := 1;
    end
    else if LScalar < $800 then
    begin
      LBytes := 2;
    end
    else if LScalar < $10000 then
    begin
      LBytes := 3;
    end
    else
    begin
      LBytes := 4;
    end;
    Append(LEncoded, 1, Length(LEncoded), LBytes);
  end;
  InvalidJSONText;
end;

end.
