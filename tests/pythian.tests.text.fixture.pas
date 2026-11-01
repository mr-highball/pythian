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
unit pythian.tests.text.fixture;

{$mode delphi}{$H+}

interface

uses pythian.text;

{ Already encoded fixture parts: never transcode through the host code page. }
function FixtureText(const AParts: array of TScalarText): TScalarText;
function RepeatFixture(const APart: TScalarText; const ACount: Integer): TScalarText;

implementation

{$ifdef pas2js}
uses StrUtils;
{$endif}

function FixtureText(const AParts: array of TScalarText): TScalarText;
var
  I: Integer;
  {$ifndef pas2js}
  LSize: Integer;
  LPosition: Integer;
  {$endif}
begin
  Result := '';
  {$ifdef pas2js}
  for I := 0 to High(AParts) do
  begin
    Result := Result + AParts[I];
  end;
  {$else}
  LSize := 0;
  for I := 0 to High(AParts) do
  begin
    Inc(LSize, Length(AParts[I]));
  end;
  SetLength(Result, LSize);
  LPosition := 1;
  for I := 0 to High(AParts) do
  begin
    if Length(AParts[I]) > 0 then
    begin
      Move(AParts[I][1], Result[LPosition], Length(AParts[I]));
      Inc(LPosition, Length(AParts[I]));
    end;
  end;
  {$endif}
end;

function RepeatFixture(const APart: TScalarText; const ACount: Integer): TScalarText;
{$ifndef pas2js}
var
  I: Integer;
{$endif}
begin
  {$ifdef pas2js}
  Result := DupeString(APart, ACount);
  {$else}
  SetLength(Result, Length(APart) * ACount);
  if Length(APart) > 0 then
  begin
    for I := 0 to ACount - 1 do
    begin
      Move(APart[1], Result[I * Length(APart) + 1], Length(APart));
    end;
  end;
  {$endif}
end;

end.
