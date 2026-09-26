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
unit pythian.hash;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  pythian.audio;

{ SHA256 of exact bytes, retaining the Phanes provenance-helper contract.
  Native FIPS 180-4 algorithm with fixed-size working storage and RTL only. }
function Sha256Bytes(const ABytes: TAudioBytes): String;
{ Hash exactly AByteCount bytes from the current position, using fixed storage.
  Borrows the stream; short positive reads accumulate. Invalid counts reject
  before reading. Source errors/early EOF may advance its physical position. }
function Sha256Stream(const AStream: TStream; const AByteCount: Int64): String;

implementation

type
  TShaState = array[0..7] of Cardinal;
  TShaBlock = array[0..63] of Byte;

function RotateRight(const AValue: Cardinal; const ACount: Integer): Cardinal; inline;
begin
  Result := (AValue shr ACount) or (AValue shl (32 - ACount));
end;

procedure Compress(var AState: TShaState; const ABlock: TShaBlock);
const
  CK: array[0..63] of Cardinal = (
    $428A2F98, $71374491, $B5C0FBCF, $E9B5DBA5, $3956C25B, $59F111F1, $923F82A4, $AB1C5ED5,
    $D807AA98, $12835B01, $243185BE, $550C7DC3, $72BE5D74, $80DEB1FE, $9BDC06A7, $C19BF174,
    $E49B69C1, $EFBE4786, $0FC19DC6, $240CA1CC, $2DE92C6F, $4A7484AA, $5CB0A9DC, $76F988DA,
    $983E5152, $A831C66D, $B00327C8, $BF597FC7, $C6E00BF3, $D5A79147, $06CA6351, $14292967,
    $27B70A85, $2E1B2138, $4D2C6DFC, $53380D13, $650A7354, $766A0ABB, $81C2C92E, $92722C85,
    $A2BFE8A1, $A81A664B, $C24B8B70, $C76C51A3, $D192E819, $D6990624, $F40E3585, $106AA070,
    $19A4C116, $1E376C08, $2748774C, $34B0BCB5, $391C0CB3, $4ED8AA4A, $5B9CCA4F, $682E6FF3,
    $748F82EE, $78A5636F, $84C87814, $8CC70208, $90BEFFFA, $A4506CEB, $BEF9A3F7, $C67178F2);
var
  LW: array[0..63] of Cardinal;
  LV: TShaState;
  LIndex: Integer;
  LS0: Cardinal;
  LS1: Cardinal;
  LChoice: Cardinal;
  LMajority: Cardinal;
  LT1: Cardinal;
  LT2: Cardinal;
begin
  for LIndex := 0 to 15 do
  begin
    LW[LIndex] := (Cardinal(ABlock[LIndex * 4]) shl 24) or
      (Cardinal(ABlock[LIndex * 4 + 1]) shl 16) or
      (Cardinal(ABlock[LIndex * 4 + 2]) shl 8) or ABlock[LIndex * 4 + 3];
  end;
  for LIndex := 16 to 63 do
  begin
    LS0 := RotateRight(LW[LIndex - 15], 7) xor RotateRight(LW[LIndex - 15], 18) xor
      (LW[LIndex - 15] shr 3);
    LS1 := RotateRight(LW[LIndex - 2], 17) xor RotateRight(LW[LIndex - 2], 19) xor
      (LW[LIndex - 2] shr 10);
    LW[LIndex] := Cardinal((QWord(LW[LIndex - 16]) + LS0 + LW[LIndex - 7] + LS1) and $FFFFFFFF);
  end;
  LV := AState;
  for LIndex := 0 to 63 do
  begin
    LS1 := RotateRight(LV[4], 6) xor RotateRight(LV[4], 11) xor RotateRight(LV[4], 25);
    LChoice := (LV[4] and LV[5]) xor ((not LV[4]) and LV[6]);
    LT1 := Cardinal((QWord(LV[7]) + LS1 + LChoice + CK[LIndex] + LW[LIndex]) and $FFFFFFFF);
    LS0 := RotateRight(LV[0], 2) xor RotateRight(LV[0], 13) xor RotateRight(LV[0], 22);
    LMajority := (LV[0] and LV[1]) xor (LV[0] and LV[2]) xor (LV[1] and LV[2]);
    LT2 := Cardinal((QWord(LS0) + LMajority) and $FFFFFFFF);
    LV[7] := LV[6];
    LV[6] := LV[5];
    LV[5] := LV[4];
    LV[4] := Cardinal((QWord(LV[3]) + LT1) and $FFFFFFFF);
    LV[3] := LV[2];
    LV[2] := LV[1];
    LV[1] := LV[0];
    LV[0] := Cardinal((QWord(LT1) + LT2) and $FFFFFFFF);
  end;
  for LIndex := 0 to 7 do
  begin
    AState[LIndex] := Cardinal((QWord(AState[LIndex]) + LV[LIndex]) and $FFFFFFFF);
  end;
end;

const
  CInitial: TShaState = (
    $6A09E667, $BB67AE85, $3C6EF372, $A54FF53A, $510E527F, $9B05688C, $1F83D9AB, $5BE0CD19);

function FinishHash(var AState: TShaState; var ABlock: TShaBlock;
  const ARemaining: Integer; const AByteCount: QWord): String;
const
  CHex: String = '0123456789abcdef';
var
  LBits: QWord;
  LIndex: Integer;
  LNibble: Integer;
begin
  ABlock[ARemaining] := $80;
  if ARemaining >= 56 then
  begin
    Compress(AState, ABlock);
    FillChar(ABlock, SizeOf(ABlock), 0);
  end;
  LBits := AByteCount * 8;
  for LIndex := 0 to 7 do
  begin
    ABlock[63 - LIndex] := (LBits shr (LIndex * 8)) and $FF;
  end;
  Compress(AState, ABlock);
  SetLength(Result, 64);
  for LIndex := 0 to 7 do
  begin
    for LNibble := 0 to 7 do
    begin
      Result[LIndex * 8 + LNibble + 1] :=
        CHex[((AState[LIndex] shr ((7 - LNibble) * 4)) and $F) + 1];
    end;
  end;
end;

function Sha256Bytes(const ABytes: TAudioBytes): String;
var
  LState: TShaState;
  LBlock: TShaBlock;
  LOffset: SizeInt;
  LRemaining: Integer;
begin
  LState := CInitial;
  LOffset := 0;
  while Length(ABytes) - LOffset >= SizeOf(LBlock) do
  begin
    Move(ABytes[LOffset], LBlock[0], SizeOf(LBlock));
    Compress(LState, LBlock);
    Inc(LOffset, SizeOf(LBlock));
  end;
  FillChar(LBlock, SizeOf(LBlock), 0);
  LRemaining := Length(ABytes) - LOffset;
  if LRemaining > 0 then
  begin
    Move(ABytes[LOffset], LBlock[0], LRemaining);
  end;
  Result := FinishHash(LState, LBlock, LRemaining, QWord(Length(ABytes)));
end;

function Sha256Stream(const AStream: TStream; const AByteCount: Int64): String;
var
  LState: TShaState;
  LBlock: TShaBlock;
  LBuffer: array[0..8191] of Byte;
  LRemaining: Int64;
  LChunk: Integer;
  LRead: Integer;
  LReceived: Integer;
  LOffset: Integer;
begin
  if (AStream = nil) or (AByteCount < 0) or
    (AByteCount > 2305843009213693951) then
  begin
    raise EAudio.Create('Invalid SHA256 stream or byte count');
  end;
  LState := CInitial;
  LRemaining := AByteCount;
  FillChar(LBlock, SizeOf(LBlock), 0);
  LOffset := 0;
  LChunk := 0;
  while LRemaining > 0 do
  begin
    LChunk := SizeOf(LBuffer);
    if LRemaining < LChunk then
    begin
      LChunk := Integer(LRemaining);
    end;
    LReceived := 0;
    while LReceived < LChunk do
    begin
      LRead := AStream.Read(LBuffer[LReceived], LChunk - LReceived);
      if (LRead <= 0) or (LRead > LChunk - LReceived) then
      begin
        raise EAudio.Create('SHA256 source ended early or returned an invalid read count');
      end;
      Inc(LReceived, LRead);
    end;
    LOffset := 0;
    while LChunk - LOffset >= SizeOf(LBlock) do
    begin
      Move(LBuffer[LOffset], LBlock[0], SizeOf(LBlock));
      Compress(LState, LBlock);
      Inc(LOffset, SizeOf(LBlock));
    end;
    Dec(LRemaining, LChunk);
  end;
  FillChar(LBlock, SizeOf(LBlock), 0);
  if LChunk > LOffset then
  begin
    Move(LBuffer[LOffset], LBlock[0], LChunk - LOffset);
  end;
  Result := FinishHash(LState, LBlock, LChunk - LOffset, QWord(AByteCount));
end;

end.
