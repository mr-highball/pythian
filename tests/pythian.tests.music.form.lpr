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
program MusicFormConformance;
{$mode delphi}
{$H+}
uses SysUtils, pythian.audio, pythian.chord, pythian.text,
  pythian.music.decisions, pythian.music.form;

var GChecks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise EAudio.Create(AMessage);
end;

function Form: TMusicForm;
begin
  Result := nil;
  SetLength(Result, 3);
  Result[0].Section := 'Opening'; Result[0].Name := 'A';
  Result[0].Cells := 12; Result[0].RepeatFrom := -1;
  Result[1].Section := 'Contrast'; Result[1].Name := 'B';
  Result[1].Cells := 8; Result[1].RepeatFrom := -1;
  Result[2].Section := 'Return'; Result[2].Name := 'A variation';
  Result[2].Cells := 12; Result[2].RepeatFrom := 0;
  SetLength(Result[2].Keep, 1); Result[2].Keep[0] := 'lead';
end;

function Chunk(const AFirst, ACount: Integer): TMusicDecisionChunk;
var I: Integer;
begin
  Result := Default(TMusicDecisionChunk);
  Result.Version := MusicDecisionVersion;
  Result.FirstCell := AFirst;
  Result.StartFrame := AFirst * 10;
  SetLength(Result.Previous, 1);
  Result.Previous[0] := Default(TChordVoice);
  SetLength(Result.Cells, ACount);
  for I := 0 to ACount - 1 do
  begin
    Result.Cells[I].FrameCount := 10;
    Result.Cells[I].Parts := CopyChordFrame(Result.Previous);
  end;
  SetLength(Result.Providers, 2);
  Result.Providers[0].Key := 'lead'; Result.Providers[1].Key := 'bass';
  for I := 0 to 1 do
  begin
    SetLength(Result.Providers[I].Tokens, ACount);
    SetLength(Result.Providers[I].States, ACount);
  end;
  for I := 0 to ACount - 1 do
  begin
    Result.Providers[0].Tokens[I] := 'note-' + IntToStr((AFirst + I) mod 12);
    Result.Providers[1].Tokens[I] := 'bass-' + IntToStr(AFirst + I);
  end;
end;

procedure Run;
var LForm, LCopy: TMusicForm;
  LKeys: TMusicDecisionTokens;
  LCursor: TMusicFormCursor;
  LChunk: TMusicDecisionChunk;
  LLocks: TMusicDecisionProviders;
  I, J: Integer;
  LRejected: Boolean;
begin
  LForm := Form;
  LForm[0].DensityOffset := -50;
  LForm[1].DensityOffset := 50;
  SetLength(LKeys, 2); LKeys[0] := 'lead'; LKeys[1] := 'bass';
  Check(MusicFormLookahead(LForm, 16) = 4, 'Solve windows divide unequal musical phrase boundaries');
  LCursor := TMusicFormCursor.Create(LForm, LKeys);
  try
    Check((LCursor.DensityOffsetAt(0) = -50) and
      (LCursor.DensityOffsetAt(11) = -50) and (LCursor.DensityOffsetAt(12) = 50) and
      (LCursor.DensityOffsetAt(19) = 50) and (LCursor.DensityOffsetAt(20) = 0),
      'Density uses exact half-open musical phrase boundaries');
    LForm[0].DensityOffset := 999;
    Check(LCursor.DensityOffsetAt(0) = -50, 'Section density is detached from caller edits');
    LRejected := False;
    try LCursor.DensityOffsetAt(32) except on E: EAudio do LRejected := True end;
    Check(LRejected, 'Density lookup rejects the exclusive form end');
    Check(LCursor.ReadyLookaheadCells(32) = 12,
      'Planning waits for the first motif source before choosing its later transition');
    Check(not LCursor.TryCopyLocksAt(20, 4, LLocks),
      'Unrecorded future motifs are unknown rather than invented');
    LForm[2].Keep[0] := 'mutated caller';
    LCopy := LCursor.CopyForm;
    Check(LCopy[2].Keep[0] = 'lead', 'Form owns detached caller inputs');
    LCopy[2].Keep[0] := 'mutated copy';
    Check(LCursor.CopyForm[2].Keep[0] = 'lead', 'Copied form does not alias the accepted form');
    for I := 0 to 4 do
    begin
      LCursor.Append(Chunk(I * 4, 4));
      if I = 2 then
        Check(LCursor.ReadyLookaheadCells(32) = 20,
          'Completed motifs become available to constrain future contrasting sections');
    end;
    Check((LCursor.CellCount = 20) and (LCursor.PhraseIndex = 2) and
      (LCursor.TotalCells = 32), 'Musical section/phrase clock differs from solve windows');
    LLocks := LCursor.CopyLocks(4);
    Check((Length(LLocks) = 1) and (LLocks[0].Key = 'lead') and
      (LLocks[0].Tokens[0] = 'note-0'), 'Only the named motif provider is retained');
    LLocks[0].Tokens[0] := 'mutated lock';
    Check(LCursor.CopyLocks(4)[0].Tokens[0] = 'note-0', 'Returned locks do not mutate retained motifs');
    LChunk := Chunk(20, 4);
    LRejected := False;
    try LCursor.Append(LChunk) except on E: EAudio do LRejected := True end;
    Check(LRejected and (LCursor.CellCount = 20), 'Wrong repeated choices cannot advance the form');
    LRejected := False;
    try LCursor.CopyLocks(13) except on E: EAudio do LRejected := True end;
    Check(LRejected and (LCursor.CellCount = 20), 'A window cannot cross a musical phrase boundary');
    for I := 0 to 2 do
    begin
      LChunk := Chunk(20 + I * 4, 4);
      LLocks := LCursor.CopyLocks(4);
      for J := 0 to 3 do
      begin
        LChunk.Providers[0].Tokens[J] := LLocks[0].Tokens[J];
        LChunk.Providers[0].States[J] := 99;
      end;
      LCursor.Append(LChunk);
    end;
    Check((LCursor.CellCount = 32) and (LCursor.PhraseIndex = 3),
      'Exact musical tokens allow new independently authenticated latent states');
  finally LCursor.Free end;
  for I := 0 to 6 do
  begin
    LForm := Form;
    case I of
      0: LForm[2].RepeatFrom := 2;
      1: LForm[2].Cells := 8;
      2: LForm[2].Keep[0] := 'missing';
      3: LForm[0].Keep := Copy(LForm[2].Keep);
      4: LForm[1].Cells := 0;
      5: LForm[1].DensityOffset := -51;
      6: LForm[1].DensityOffset := 51;
    end;
    LRejected := False;
    LCursor := nil;
    try
      try LCursor := TMusicFormCursor.Create(LForm, LKeys)
      except on E: EAudio do LRejected := True end;
    finally LCursor.Free end;
    Check(LRejected, 'Invalid form geometry/reference/provider must reject');
  end;
  SetLength(LForm, 10);
  for I := 0 to 9 do
  begin
    LForm[I] := Default(TMusicFormPhrase);
    LForm[I].Name := 'Bounded'; LForm[I].Section := 'Cache';
    LForm[I].Cells := 256; LForm[I].RepeatFrom := -1;
    if I >= 5 then
    begin
      LForm[I].RepeatFrom := I - 5;
      SetLength(LForm[I].Keep, 1); LForm[I].Keep[0] := 'lead';
    end;
  end;
  LCursor := nil; LRejected := False;
  try
    try LCursor := TMusicFormCursor.Create(LForm, LKeys)
    except on E: EAudio do LRejected := True end;
  finally LCursor.Free end;
  Check(LRejected, 'Long arrangements cannot allocate an unbounded retained-motif score');
  WriteLn('PASS ', GChecks, ' portable musical form checks');
end;

begin
  try Run except on E: Exception do
  begin WriteLn('FAIL: ', E.Message); ExitCode := 1 end end;
end.
