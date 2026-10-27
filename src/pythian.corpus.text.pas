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
  pythian.audio,
  pythian.text;

procedure ValidateCorpusText(const AText: TCorpusText);
begin
  try
    ValidateScalarText(AText, MaximumCorpusTextBytes, True, False);
  except
    on ETextValidation do
    begin
      raise EAudio.Create('Corpus text must be bounded UTF-8 without NUL bytes');
    end;
  end;
end;

function CompareCorpusText(const ALeft, ARight: TCorpusText): Integer;
begin
  try
    Result := CompareScalarText(ALeft, ARight, MaximumCorpusTextBytes, False);
  except
    on ETextValidation do
    begin
      raise EAudio.Create('Corpus text must be bounded UTF-8 without NUL bytes');
    end;
  end;
end;

end.
