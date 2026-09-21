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
program pythian_tests_evaluation_reference;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.evaluation, pythian.evaluation.notes,
  pythian.evaluation.parts, pythian.evaluation.reference;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Note(const AId: String; const AFirst, AEnd: Int64; const APitch: Integer):
  TEvaluationNote;
begin
  Result := Default(TEvaluationNote);
  Result.Id := AId;
  Result.StartFrame := AFirst;
  Result.EndFrame := AEnd;
  Result.Pitch := APitch;
end;

function Region(const AFirst, AEnd: Int64; const AState: TEvaluationState):
  TEvaluationNoteRegion;
begin
  Result.FirstFrame := AFirst;
  Result.EndFrame := AEnd;
  Result.State := AState;
end;

procedure CheckNotes(const AActual: TPartPitchSet; const AExpected: array of Integer);
var
  I: Integer;
begin
  Check(Length(AActual) = Length(AExpected), 'Pitch union length');
  for I := 0 to High(AExpected) do
  begin
    Check(AActual[I] = AExpected[I], 'Pitch union member');
  end;
end;

procedure Run;
var
  LRoles: TPartRoleIds;
  LReferences: TPartNoteReferences;
  LUnassigned: TEvaluationNotes;
  LCells: TPartEvaluationCells;
  LRejected: Boolean;
  LFirstCenter: Int64;
  I: Integer;
  J: Integer;
begin
  SetLength(LRoles, 2);
  LRoles[0] := 'lead';
  LRoles[1] := 'chordal';
  SetLength(LReferences, 2);
  SetLength(LReferences[0].Regions, 3);
  LReferences[0].Regions[0] := Region(100, 300, esUnknown);
  LReferences[0].Regions[1] := Region(300, 700, esValue);
  LReferences[0].Regions[2] := Region(700, 900, esRest);
  SetLength(LReferences[0].Events, 3);
  LReferences[0].Events[0] := Note('lead-a', 200, 400, 60);
  LReferences[0].Events[1] := Note('lead-b', 350, 600, 60);
  LReferences[0].Events[2] := Note('lead-c', 500, 700, 64);
  SetLength(LReferences[1].Regions, 1);
  LReferences[1].Regions[0] := Region(100, 900, esValue);
  SetLength(LReferences[1].Events, 3);
  LReferences[1].Events[0] := Note('chord-a', 100, 300, 48);
  LReferences[1].Events[1] := Note('chord-b', 100, 300, 52);
  LReferences[1].Events[2] := Note('chord-c', 300, 500, 55);
  SetLength(LUnassigned, 1);
  LUnassigned[0] := Note('owner-unknown', 600, 800, 72);
  LCells := BuildPartReferenceCells(LRoles, LReferences, LUnassigned, 1000, 100, 900, 150, 100);
  Check(Length(LCells) = 8, 'Complete grid count');
  for I := 0 to 7 do
  begin
    Check(LCells[I].Frame = 150 + I * 100, 'Absolute center clock');
  end;
  Check((LCells[0].Parts[0].State = esUnknown) and
    (LCells[1].Parts[0].State = esUnknown), 'Unknown became rest or nominal pitch');
  CheckNotes(LCells[1].Parts[0].Notes, []);
  CheckNotes(LCells[2].Parts[0].Notes, [60]);
  CheckNotes(LCells[3].Parts[0].Notes, [60]);
  CheckNotes(LCells[4].Parts[0].Notes, [60, 64]);
  CheckNotes(LCells[5].Parts[0].Notes, [64]);
  Check(LCells[6].Parts[0].State = esRest, 'Explicit rest');
  CheckNotes(LCells[0].Parts[1].Notes, [48, 52]);
  CheckNotes(LCells[2].Parts[1].Notes, [55]);
  Check(LCells[4].Parts[1].State = esRest, 'Known complete gap did not become rest');
  CheckNotes(LCells[5].UnassignedNotes, [72]);
  CheckNotes(LCells[6].UnassignedNotes, [72]);
  CheckNotes(LCells[7].UnassignedNotes, []);
  LCells[2].Parts[0].Notes[0] := 61;
  Check((LCells[3].Parts[0].Notes[0] = 60) and
    (LReferences[0].Events[0].Pitch = 60) and
    (Length(LReferences[0].Events) = 3), 'Output aliases input or other cells');

  for I := 0 to 6 do
  begin
    LFirstCenter := 150;
    case I of
      0: LUnassigned[0].Id := 'lead-a';
      1: LReferences[0].Events[2].EndFrame := 701;
      2: LReferences[0].Regions[1].FirstFrame := 301;
      3: LReferences[0].Events[0].EndFrame := 1001;
      4: LFirstCenter := 250;
      5: LRoles[1] := 'lead';
      6: LReferences[0].Events[0].Pitch := 128;
    end;
    LRejected := False;
    try
      LCells := BuildPartReferenceCells(LRoles, LReferences, LUnassigned,
        1000, 100, 900, LFirstCenter, 100);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LCells) = 8) and
      (LCells[2].Parts[0].Notes[0] = 61), 'Rejection did not preserve previous result');
    LUnassigned[0].Id := 'owner-unknown';
    LReferences[0].Events[2].EndFrame := 700;
    LReferences[0].Regions[1].FirstFrame := 300;
    LReferences[0].Events[0].EndFrame := 400;
    LReferences[0].Events[0].Pitch := 60;
    LRoles[1] := 'chordal';
  end;
  { Exact endpoint convention: an event ending at a center is already absent. }
  LCells := BuildPartReferenceCells(LRoles, LReferences, LUnassigned, 1000, 100, 900, 100, 100);
  CheckNotes(LCells[2].Parts[1].Notes, [55]);
  CheckNotes(LCells[4].Parts[1].Notes, []);
  for J := 0 to 1 do
  begin
    LReferences[0].Regions[0].State := esAmbiguous;
    if J = 1 then
    begin
      LReferences[0].Regions[0].State := esUnsupported;
    end;
    LCells := BuildPartReferenceCells(LRoles, LReferences, LUnassigned,
      1000, 100, 900, 150, 100);
    Check(LCells[1].Parts[0].State = LReferences[0].Regions[0].State,
      'Uncertainty category changed');
  end;
  WriteLn('PASS reviewed part references, complete grid, uncertainty, unions and preservation');
end;

begin
  Run;
end.
