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
unit pythian.corpus.text;

{$mode delphi}
{$H+}

interface

const
  MaximumCorpusTextBytes = 4096;

type
  {$ifdef pas2js}
  TCorpusText = String;
  {$else}
  TCorpusText = UTF8String;
  {$endif}

{ Exact Unicode scalar text; no normalization. NUL and malformed encodings
  reject, and the UTF-8 representation is bounded to 4096 bytes. }
procedure ValidateCorpusText(const AText: TCorpusText);
{ Canonical UTF-8 byte order for validated identities, independent of target. }
function CompareCorpusText(const ALeft, ARight: TCorpusText): Integer;

implementation

uses
  pythian.audio;

procedure InvalidText;
begin
  raise EAudio.Create('Corpus text must be bounded UTF-8 without NUL bytes');
end;

function NextScalar(const AText: TCorpusText; var AIndex: Integer;
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
  if Result = 0 then
  begin
    InvalidText;
  end;
end;

procedure ValidateCorpusText(const AText: TCorpusText);
var
  LIndex: Integer;
  LBytes: Integer;
  LCount: Integer;
begin
  LIndex := 1;
  LBytes := 0;
  while LIndex <= Length(AText) do
  begin
    NextScalar(AText, LIndex, LCount);
    Inc(LBytes, LCount);
    if LBytes > MaximumCorpusTextBytes then
    begin
      InvalidText;
    end;
  end;
end;

function CompareCorpusText(const ALeft, ARight: TCorpusText): Integer;
var
  LLeftIndex: Integer;
  LRightIndex: Integer;
  LCount: Integer;
  LLeft: Cardinal;
  LRight: Cardinal;
begin
  ValidateCorpusText(ALeft);
  ValidateCorpusText(ARight);
  LLeftIndex := 1;
  LRightIndex := 1;
  while (LLeftIndex <= Length(ALeft)) and (LRightIndex <= Length(ARight)) do
  begin
    LLeft := NextScalar(ALeft, LLeftIndex, LCount);
    LRight := NextScalar(ARight, LRightIndex, LCount);
    if LLeft < LRight then
    begin
      Result := -1;
      Exit;
    end;
    if LLeft > LRight then
    begin
      Result := 1;
      Exit;
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
end;

end.
