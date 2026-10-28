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

{ Validated size in canonical UTF-8 bytes on both targets. }
function ScalarTextByteCount(const AText: TScalarText; const AMaximumBytes: Integer;
  const AAllowEmpty: Boolean = True; const AAllowNul: Boolean = False;
  const AProgress: TWorkProgressCallback = nil): Integer;

{ Detached canonical conversion, using the same scalar decoder/emitter.
  Final callbacks precede managed result publication. Native text is tagged
  UTF-8 without transcoding. Individual allocations/final RTL joins stay
  synchronous; work reports actual consumed/written bytes, not elapsed time. }
function EncodeUTF8Text(const AText: TScalarText; const AMaximumBytes: Integer;
  const AAllowEmpty: Boolean = True; const AAllowNul: Boolean = False;
  const AProgress: TWorkProgressCallback = nil): TAudioBytes;
function DecodeUTF8Text(const ABytes: array of Byte; const AMaximumBytes: Integer;
  const AAllowEmpty: Boolean = True; const AAllowNul: Boolean = False;
  const AProgress: TWorkProgressCallback = nil): TScalarText;

{ No normalization. The caller declares the canonical UTF-8 byte limit and
  empty/NUL policy. Native input is raw bytes; pas2js input is UTF-16 scalars. }
procedure ValidateScalarText(const AText: TScalarText; const AMaximumBytes: Integer;
  const AAllowEmpty: Boolean = True; const AAllowNul: Boolean = False;
  const AProgress: TWorkProgressCallback = nil);
{ Canonical UTF-8 bytes on every target. No conversion through a native code
  page or browser UTF-16 string; borrows the original array without changing it. }
procedure ValidateUTF8Bytes(const ABytes: array of Byte; const AMaximumBytes: Integer;
  const AAllowEmpty: Boolean = True; const AAllowNul: Boolean = False;
  const AProgress: TWorkProgressCallback = nil);
{ Scalar order equals canonical UTF-8 byte order, independent of host locale. }
function CompareScalarText(const ALeft, ARight: TScalarText;
  const AMaximumBytes: Integer; const AAllowNul: Boolean = False;
  const AProgress: TWorkProgressCallback = nil): Integer;

implementation

{$ifdef pas2js}
uses SysUtils;
{$endif}

type
  TUTF8ScalarBytes = array[0..3] of Byte;

procedure InvalidText;
begin
  raise ETextValidation.Create('Text must contain canonical Unicode scalars within its UTF-8 policy');
end;

function NextUTF8Scalar(const ABytes: array of Byte; var AIndex: Integer): Cardinal;
var
  LFirst: Cardinal;
  LNext: Cardinal;
  LCount: Integer;
  LIndex: Integer;
  LMinimum: Cardinal;
begin
  if (AIndex < 0) or (AIndex >= Length(ABytes)) then
  begin
    InvalidText;
  end;
  LFirst := ABytes[AIndex];
  Inc(AIndex);
  if LFirst < $80 then
  begin
    Exit(LFirst);
  end;
  if (LFirst >= $C2) and (LFirst <= $DF) then
  begin
    LCount := 2;
    LMinimum := $80;
    Result := LFirst and $1F;
  end
  else if (LFirst >= $E0) and (LFirst <= $EF) then
  begin
    LCount := 3;
    LMinimum := $800;
    Result := LFirst and $0F;
  end
  else if (LFirst >= $F0) and (LFirst <= $F4) then
  begin
    LCount := 4;
    LMinimum := $10000;
    Result := LFirst and $07;
  end
  else
  begin
    InvalidText;
    Exit(0);
  end;
  for LIndex := 2 to LCount do
  begin
    if AIndex >= Length(ABytes) then
    begin
      InvalidText;
    end;
    LNext := ABytes[AIndex];
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

function NextScalar(const AText: TScalarText; var AIndex: Integer;
  out AByteCount: Integer): Cardinal;
var
  {$ifdef pas2js}
  LFirst: Cardinal;
  LNext: Cardinal;
  {$else}
  LBytes: array[0..3] of Byte;
  LCount: Integer;
  LIndex: Integer;
  LPosition: Integer;
  {$endif}
begin
  {$ifdef pas2js}
  LFirst := Ord(AText[AIndex]);
  Inc(AIndex);
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
  LCount := Length(AText) - AIndex + 1;
  if LCount > 4 then
  begin
    LCount := 4;
  end;
  for LIndex := 0 to LCount - 1 do
  begin
    LBytes[LIndex] := Ord(AText[AIndex + LIndex]);
  end;
  LPosition := 0;
  Result := NextUTF8Scalar(Slice(LBytes, LCount), LPosition);
  AByteCount := LPosition;
  Inc(AIndex, LPosition);
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

function EncodeScalarBytes(const AScalar: Cardinal;
  out ABytes: TUTF8ScalarBytes): Integer;
begin
  if (AScalar > $10FFFF) or ((AScalar >= $D800) and (AScalar <= $DFFF)) then
  begin
    InvalidText;
  end;
  if AScalar < $80 then
  begin
    Result := 1;
    ABytes[0] := AScalar;
  end
  else if AScalar < $800 then
  begin
    Result := 2;
    ABytes[0] := $C0 or (AScalar shr 6);
    ABytes[1] := $80 or (AScalar and $3F);
  end
  else if AScalar < $10000 then
  begin
    Result := 3;
    ABytes[0] := $E0 or (AScalar shr 12);
    ABytes[1] := $80 or ((AScalar shr 6) and $3F);
    ABytes[2] := $80 or (AScalar and $3F);
  end
  else
  begin
    Result := 4;
    ABytes[0] := $F0 or (AScalar shr 18);
    ABytes[1] := $80 or ((AScalar shr 12) and $3F);
    ABytes[2] := $80 or ((AScalar shr 6) and $3F);
    ABytes[3] := $80 or (AScalar and $3F);
  end;
end;

function ScalarText(const AScalar: Cardinal): TScalarText;
var
  {$ifdef pas2js}
  LScalar: Cardinal;
  {$else}
  LBytes: TUTF8ScalarBytes;
  LCount: Integer;
  LIndex: Integer;
  LCandidate: TScalarText;
  {$endif}
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
  LCount := EncodeScalarBytes(AScalar, LBytes);
  SetLength(LCandidate, LCount);
  for LIndex := 0 to LCount - 1 do
  begin
    LCandidate[LIndex + 1] := Chr(LBytes[LIndex]);
  end;
  SetCodePage(LCandidate, 65001, False);
  Result := LCandidate;
  {$endif}
end;

function ScalarTextByteCount(const AText: TScalarText; const AMaximumBytes: Integer;
  const AAllowEmpty, AAllowNul: Boolean; const AProgress: TWorkProgressCallback): Integer;
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
  Result := Integer(LBytes);
end;

procedure ValidateScalarText(const AText: TScalarText; const AMaximumBytes: Integer;
  const AAllowEmpty, AAllowNul: Boolean; const AProgress: TWorkProgressCallback);
begin
  ScalarTextByteCount(AText, AMaximumBytes, AAllowEmpty, AAllowNul, AProgress);
end;

procedure ValidateUTF8Bytes(const ABytes: array of Byte; const AMaximumBytes: Integer;
  const AAllowEmpty, AAllowNul: Boolean; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LReported: Integer;
  LScalar: Cardinal;
begin
  if (AMaximumBytes < 0) or ((Length(ABytes) = 0) and not AAllowEmpty) then
  begin
    InvalidText;
  end;
  LIndex := 0;
  LReported := 0;
  ReportWork(AProgress, 'text_validate_bytes', wuBytes, 0, 0);
  while LIndex < Length(ABytes) do
  begin
    LScalar := NextUTF8Scalar(ABytes, LIndex);
    if ((LScalar = 0) and not AAllowNul) or (LIndex > AMaximumBytes) then
    begin
      InvalidText;
    end;
    if Assigned(AProgress) and (LIndex - LReported >= 1024) then
    begin
      LReported := LIndex;
      ReportWork(AProgress, 'text_validate_bytes', wuBytes, LIndex, 0);
    end;
  end;
  ReportWork(AProgress, 'text_validate_bytes', wuBytes, LIndex, LIndex);
end;

function EncodeUTF8Text(const AText: TScalarText; const AMaximumBytes: Integer;
  const AAllowEmpty, AAllowNul: Boolean; const AProgress: TWorkProgressCallback): TAudioBytes;
var
  LCandidate: TAudioBytes;
  LBytes: TUTF8ScalarBytes;
  LTotal: Integer;
  LPosition: Integer;
  LOffset: Integer;
  LReported: Integer;
  LCount: Integer;
  LIndex: Integer;
  LSourceBytes: Integer;
  LScalar: Cardinal;
begin
  LTotal := ScalarTextByteCount(AText, AMaximumBytes, AAllowEmpty, AAllowNul, AProgress);
  ReportWork(AProgress, 'text_encode_bytes', wuBytes, 0, LTotal);
  SetLength(LCandidate, LTotal);
  LPosition := 1;
  LOffset := 0;
  LReported := 0;
  while LPosition <= Length(AText) do
  begin
    LScalar := NextScalar(AText, LPosition, LSourceBytes);
    LCount := EncodeScalarBytes(LScalar, LBytes);
    for LIndex := 0 to LCount - 1 do
    begin
      LCandidate[LOffset + LIndex] := LBytes[LIndex];
    end;
    Inc(LOffset, LCount);
    if Assigned(AProgress) and (LOffset - LReported >= 65536) and (LOffset < LTotal) then
    begin
      LReported := LOffset;
      ReportWork(AProgress, 'text_encode_bytes', wuBytes, LOffset, LTotal);
    end;
  end;
  ReportWork(AProgress, 'text_encode_bytes', wuBytes, LOffset, LTotal);
  Result := LCandidate;
end;

function DecodeUTF8Text(const ABytes: array of Byte; const AMaximumBytes: Integer;
  const AAllowEmpty, AAllowNul: Boolean; const AProgress: TWorkProgressCallback): TScalarText;
var
  LCandidate: TScalarText;
  LIndex: Integer;
  LReported: Integer;
  {$ifdef pas2js}
  LBuilder: TStringBuilder;
  LScalar: Cardinal;
  {$endif}
begin
  ValidateUTF8Bytes(ABytes, AMaximumBytes, AAllowEmpty, AAllowNul, AProgress);
  ReportWork(AProgress, 'text_decode_bytes', wuBytes, 0, Length(ABytes));
  LReported := 0;
  {$ifdef pas2js}
  LBuilder := TStringBuilder.Create;
  try
    LIndex := 0;
    while LIndex < Length(ABytes) do
    begin
      LScalar := NextUTF8Scalar(ABytes, LIndex);
      LBuilder.Append(ScalarText(LScalar));
      if Assigned(AProgress) and (LIndex - LReported >= 65536) and (LIndex < Length(ABytes)) then
      begin
        LReported := LIndex;
        ReportWork(AProgress, 'text_decode_bytes', wuBytes, LIndex, Length(ABytes));
      end;
    end;
    LCandidate := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
  {$else}
  SetLength(LCandidate, Length(ABytes));
  for LIndex := 0 to High(ABytes) do
  begin
    LCandidate[LIndex + 1] := Chr(ABytes[LIndex]);
    if Assigned(AProgress) and (LIndex + 1 - LReported >= 65536) and
      (LIndex + 1 < Length(ABytes)) then
    begin
      LReported := LIndex + 1;
      ReportWork(AProgress, 'text_decode_bytes', wuBytes, LIndex + 1, Length(ABytes));
    end;
  end;
  SetCodePage(LCandidate, 65001, False);
  {$endif}
  ReportWork(AProgress, 'text_decode_bytes', wuBytes, Length(ABytes), Length(ABytes));
  Result := LCandidate;
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
