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
unit pythian.text;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.progress;

type
  ETextValidation = class(EAudio);
  {$ifdef pas2js}
  TScalarText = String;
  {$else}
  { Raw UTF-8 bytes: the host code-page tag must not transcode caller identities. }
  TScalarText = RawByteString;
  {$endif}

{ Read one canonical scalar at a one-based position. On failure neither the
  caller position nor its byte-count output changes. Byte count is UTF-8 on
  both targets; native positions are bytes, pas2js positions are UTF-16 units. }
function ReadTextScalar(const AText: TScalarText; var APosition: Integer;
  out AUTF8Bytes: Integer): Cardinal;
{ Encode one Unicode scalar with no normalization or host code-page conversion. }
function ScalarText(const AScalar: Cardinal): TScalarText;

{ No normalization. The caller declares the canonical UTF-8 byte limit and
  empty/NUL policy. Native input is raw bytes; pas2js input is UTF-16 scalars. }
procedure ValidateScalarText(const AText: TScalarText; const AMaximumBytes: Integer;
  const AAllowEmpty: Boolean = True; const AAllowNul: Boolean = False;
  const AProgress: TWorkProgressCallback = nil);
{ Scalar order equals canonical UTF-8 byte order, independent of host locale. }
function CompareScalarText(const ALeft, ARight: TScalarText;
  const AMaximumBytes: Integer; const AAllowNul: Boolean = False;
  const AProgress: TWorkProgressCallback = nil): Integer;

implementation

procedure InvalidText;
begin
  raise ETextValidation.Create('Text must contain canonical Unicode scalars within its UTF-8 policy');
end;

function NextScalar(const AText: TScalarText; var AIndex: Integer;
  out AByteCount: Integer): Cardinal;
var
  LFirst: Cardinal;
  LNext: Cardinal;
  LIndex: Integer;
  LMinimum: Cardinal;
begin
  LFirst := Ord(AText[AIndex]);
  Inc(AIndex);
  {$ifdef pas2js}
  if (LFirst >= $D800) and (LFirst <= $DBFF) then
  begin
    if AIndex > Length(AText) then
    begin
      InvalidText;
    end;
    LNext := Ord(AText[AIndex]);
    if (LNext < $DC00) or (LNext > $DFFF) then
    begin
      InvalidText;
    end;
    Inc(AIndex);
    Result := $10000 + (LFirst - $D800) * $400 + LNext - $DC00;
  end
  else
  begin
    if (LFirst >= $DC00) and (LFirst <= $DFFF) then
    begin
      InvalidText;
    end;
    Result := LFirst;
  end;
  if Result < $80 then
  begin
    AByteCount := 1;
  end
  else if Result < $800 then
  begin
    AByteCount := 2;
  end
  else if Result < $10000 then
  begin
    AByteCount := 3;
  end
  else
  begin
    AByteCount := 4;
  end;
  {$else}
  if LFirst < $80 then
  begin
    Result := LFirst;
    AByteCount := 1;
  end
  else
  begin
    if (LFirst >= $C2) and (LFirst <= $DF) then
    begin
      AByteCount := 2;
      LMinimum := $80;
      Result := LFirst and $1F;
    end
    else if (LFirst >= $E0) and (LFirst <= $EF) then
    begin
      AByteCount := 3;
      LMinimum := $800;
      Result := LFirst and $0F;
    end
    else if (LFirst >= $F0) and (LFirst <= $F4) then
    begin
      AByteCount := 4;
      LMinimum := $10000;
      Result := LFirst and $07;
    end
    else
    begin
      InvalidText;
      Result := 0;
      AByteCount := 0;
      LMinimum := 0;
    end;
    for LIndex := 2 to AByteCount do
    begin
      if AIndex > Length(AText) then
      begin
        InvalidText;
      end;
      LNext := Ord(AText[AIndex]);
      Inc(AIndex);
      if (LNext < $80) or (LNext > $BF) then
      begin
        InvalidText;
      end;
      Result := Result * 64 + (LNext and $3F);
    end;
    if (Result < LMinimum) or (Result > $10FFFF) or
      ((Result >= $D800) and (Result <= $DFFF)) then
    begin
      InvalidText;
    end;
  end;
  {$endif}
end;

function ReadTextScalar(const AText: TScalarText; var APosition: Integer;
  out AUTF8Bytes: Integer): Cardinal;
var
  LPosition: Integer;
  LBytes: Integer;
begin
  if (APosition < 1) or (APosition > Length(AText)) then
  begin
    InvalidText;
  end;
  LPosition := APosition;
  Result := NextScalar(AText, LPosition, LBytes);
  AUTF8Bytes := LBytes;
  APosition := LPosition;
end;

function ScalarText(const AScalar: Cardinal): TScalarText;
var
  LScalar: Cardinal;
begin
  if (AScalar > $10FFFF) or ((AScalar >= $D800) and (AScalar <= $DFFF)) then
  begin
    InvalidText;
  end;
  {$ifdef pas2js}
  if AScalar < $10000 then
  begin
    Result := Chr(AScalar);
  end
  else
  begin
    LScalar := AScalar - $10000;
    Result := Chr($D800 + LScalar div $400) + Chr($DC00 + LScalar mod $400);
  end;
  {$else}
  LScalar := AScalar;
  if LScalar < $80 then
  begin
    Result := Chr(LScalar);
  end
  else if LScalar < $800 then
  begin
    Result := Chr($C0 or (LScalar shr 6)) + Chr($80 or (LScalar and $3F));
  end
  else if LScalar < $10000 then
  begin
    Result := Chr($E0 or (LScalar shr 12)) + Chr($80 or ((LScalar shr 6) and $3F)) +
      Chr($80 or (LScalar and $3F));
  end
  else
  begin
    Result := Chr($F0 or (LScalar shr 18)) + Chr($80 or ((LScalar shr 12) and $3F)) +
      Chr($80 or ((LScalar shr 6) and $3F)) + Chr($80 or (LScalar and $3F));
  end;
  {$endif}
end;

procedure ValidateScalarText(const AText: TScalarText; const AMaximumBytes: Integer;
  const AAllowEmpty, AAllowNul: Boolean; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LBytes: Int64;
  LReported: Int64;
  LCount: Integer;
  LScalar: Cardinal;
begin
  if (AMaximumBytes < 0) or ((AText = '') and not AAllowEmpty) then
  begin
    InvalidText;
  end;
  LIndex := 1;
  LBytes := 0;
  LReported := 0;
  ReportWork(AProgress, 'text_validate_bytes', wuBytes, 0, 0);
  while LIndex <= Length(AText) do
  begin
    LScalar := NextScalar(AText, LIndex, LCount);
    if (LScalar = 0) and not AAllowNul then
    begin
      InvalidText;
    end;
    Inc(LBytes, LCount);
    if LBytes > AMaximumBytes then
    begin
      InvalidText;
    end;
    if Assigned(AProgress) and (LBytes - LReported >= 1024) then
    begin
      LReported := LBytes;
      ReportWork(AProgress, 'text_validate_bytes', wuBytes, LBytes, 0);
    end;
  end;
  ReportWork(AProgress, 'text_validate_bytes', wuBytes, LBytes, LBytes);
end;

function CompareScalarText(const ALeft, ARight: TScalarText;
  const AMaximumBytes: Integer; const AAllowNul: Boolean;
  const AProgress: TWorkProgressCallback): Integer;
var
  LLeftIndex: Integer;
  LRightIndex: Integer;
  LCount: Integer;
  LLeft: Cardinal;
  LRight: Cardinal;
  LCompared: Integer;
begin
  ValidateScalarText(ALeft, AMaximumBytes, True, AAllowNul, AProgress);
  ValidateScalarText(ARight, AMaximumBytes, True, AAllowNul, AProgress);
  LLeftIndex := 1;
  LRightIndex := 1;
  LCompared := 0;
  ReportWork(AProgress, 'text_compare_scalars', wuItems, 0, 0);
  while (LLeftIndex <= Length(ALeft)) and (LRightIndex <= Length(ARight)) do
  begin
    LLeft := NextScalar(ALeft, LLeftIndex, LCount);
    LRight := NextScalar(ARight, LRightIndex, LCount);
    Inc(LCompared);
    if LLeft <> LRight then
    begin
      if LLeft < LRight then
      begin
        Result := -1;
      end
      else
      begin
        Result := 1;
      end;
      ReportWork(AProgress, 'text_compare_scalars', wuItems, LCompared, LCompared);
      Exit;
    end;
    if Assigned(AProgress) and ((LCompared mod 256) = 0) then
    begin
      ReportWork(AProgress, 'text_compare_scalars', wuItems, LCompared, 0);
    end;
  end;
  if LLeftIndex <= Length(ALeft) then
  begin
    Result := 1;
  end
  else if LRightIndex <= Length(ARight) then
  begin
    Result := -1;
  end
  else
  begin
    Result := 0;
  end;
  ReportWork(AProgress, 'text_compare_scalars', wuItems, LCompared, LCompared);
end;

end.
