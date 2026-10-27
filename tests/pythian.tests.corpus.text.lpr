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
program pythian_tests_corpus_text;
{$mode delphi}{$H+}{$codepage utf8}
uses SysUtils, pythian.audio, pythian.corpus.text;
var
  LChecks: Integer;
procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(LChecks);
end;
procedure Reject(const AText: TCorpusText);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ValidateCorpusText(AText);
  except
    on E: EAudio do
    begin
      LRejected := True;
      Check(E.Message = 'Corpus text must be bounded UTF-8 without NUL bytes', 'Error contract');
    end;
  end;
  Check(LRejected, 'Invalid text accepted');
end;
var
  LText: TCorpusText;
  LIndex: Integer;
begin
  ValidateCorpusText('');
  ValidateCorpusText('é東😀é');
  ValidateCorpusText('￿');
  Check(CompareCorpusText('', '😀') < 0, 'UTF-8 scalar order');
  Check(CompareCorpusText('é', 'é') > 0, 'No normalization');
  Check(CompareCorpusText('a', 'ab') < 0, 'Prefix ordering');
  Check(CompareCorpusText('😀', '😀') = 0, 'Astral equality');
  LText := '';
  for LIndex := 1 to 1024 do
  begin
    LText := LText + '😀';
  end;
  ValidateCorpusText(LText);
  Reject(LText + 'a');
  Reject('abc' + #0);
  {$ifdef pas2js}
  Reject(Chr($D800));
  Reject(Chr($DC00));
  Reject(Chr($D800) + 'x');
  {$else}
  Reject(#$C0#$80);
  Reject(#$ED#$A0#$80);
  Reject(#$F4#$90#$80#$80);
  Reject(#$E2#$82);
  Reject(#$80);
  {$endif}
  WriteLn('Corpus text: ', LChecks, ' checks passed');
end.
