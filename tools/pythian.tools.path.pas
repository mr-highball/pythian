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
unit pythian.tools.path;

{$mode delphi}{$H+}

interface

{ Canonical UTF-8 OS boundary. Logical identities remain unchanged. Raw bytes
  prevent host code-page conversion; invalid UTF-8 falls back to the tagged
  native filename encoding. Windows uses its extended Unicode filesystem API. }
function NativeFilePath(const APath: RawByteString): RawByteString;

implementation

uses SysUtils, pythian.audio;

function NativeFilePath(const APath: RawByteString): RawByteString;
{$IFDEF MSWINDOWS}
var
  LWide: UnicodeString;
  LEncoded: RawByteString;
  LValidUTF8: Boolean;
  I: Integer;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  LWide := UTF8Decode(APath);
  LEncoded := UTF8Encode(LWide);
  LValidUTF8 := Length(LEncoded) = Length(APath);
  if LValidUTF8 and (Length(APath) > 0) then
    LValidUTF8 := CompareByte(LEncoded[1], APath[1], Length(APath)) = 0;
  { Compare bytes explicitly: an ANSI/UTF-8 string comparison can reinterpret
    canonical UTF-8 through the host code page and select a false fallback. }
  if not LValidUTF8 then LWide := UnicodeString(APath);
  LWide := ExpandFileName(LWide);
  for I := 1 to Length(LWide) do
    if LWide[I] = '/' then LWide[I] := '\';
  if Copy(LWide, 1, 4) = '\\.\' then
    raise EAudio.Create('Native filesystem paths cannot name Windows devices');
  if Copy(LWide, 1, 4) <> '\\?\' then
  begin
    if Copy(LWide, 1, 2) = '\\' then
    begin
      Delete(LWide, 1, 2);
      Insert('\\?\UNC\', LWide, 1);
    end
    else Insert('\\?\', LWide, 1);
  end;
  Result := UTF8Encode(LWide);
  {$ELSE}
  Result := APath;
  {$ENDIF}
end;

end.
