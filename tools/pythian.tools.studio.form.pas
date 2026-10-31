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
unit pythian.tools.studio.form;

{$mode delphi}
{$H+}

interface

uses fpjson, pythian.music.form;

{ Big Boss: transport only. The primary portable form cursor owns names,
  clocks, motif references, retained providers and capacity validation. }
function DecodeStudioForm(const AValue: TJSONData): TMusicForm;
function EncodeStudioForm(const AForm: TMusicForm): TJSONArray;
function StudioFormCells(const AForm: TMusicForm): Integer;
function StudioFormFrames(const AForm: TMusicForm;
  const ATempoBPM, ASampleRate: Integer): Int64;
function StudioFormFramesAtTempo(const AForm: TMusicForm;
  const ATempoMicroseconds, ASampleRate: Integer): Int64;
function StudioFormTimeline(const AForm: TMusicForm;
  const ATempoMicroseconds, ASampleRate: Integer): TJSONArray;

implementation

uses SysUtils, pythian.audio, pythian.time, pythian.music.decisions;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

function Whole(const AValue: TJSONObject; const AName: String;
  const AMinimum, AMaximum: Integer): Integer;
var LValue: TJSONData;
begin
  LValue := AValue.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtNumber), 'Section needs ' + AName);
  Need((LValue.AsFloat = LValue.AsInt64) and (LValue.AsInt64 >= AMinimum) and
    (LValue.AsInt64 <= AMaximum), 'Section setting is out of range: ' + AName);
  Result := LValue.AsInteger;
end;

function StudioFormCells(const AForm: TMusicForm): Integer;
var LCursor: TMusicFormCursor;
begin
  LCursor := TMusicFormCursor.Create(AForm,
    ['harmony', 'rhythm', 'bass', 'harmony-voice', 'lead', 'kick', 'snare', 'hat']);
  try
    Result := LCursor.TotalCells;
  finally
    LCursor.Free;
  end;
end;

function DecodeStudioForm(const AValue: TJSONData): TMusicForm;
var
  LRows, LKeep: TJSONArray;
  LRow: TJSONObject;
  I, J: Integer;
begin
  Result := nil;
  if AValue = nil then Exit;
  Need(AValue.JSONType = jtArray, 'Structure must be a list of sections');
  LRows := TJSONArray(AValue);
  Need((LRows.Count > 0) and (LRows.Count <= MaximumMusicFormPhrases),
    'Choose at least one section within the form limit');
  SetLength(Result, LRows.Count);
  for I := 0 to LRows.Count - 1 do
  begin
    Need(LRows[I].JSONType = jtObject, 'Each section must be an object');
    LRow := LRows.Objects[I];
    Need(LRow.Count = 5, 'Section needs section, name, cells, repeat_from and keep');
    Need((LRow.Find('section') <> nil) and (LRow.Find('section').JSONType = jtString) and
      (LRow.Find('name') <> nil) and (LRow.Find('name').JSONType = jtString),
      'Give each section a name');
    Result[I].Section := LRow.Strings['section'];
    Result[I].Name := LRow.Strings['name'];
    Result[I].Cells := Whole(LRow, 'cells', 1, MaximumMusicDecisionCells);
    Result[I].RepeatFrom := Whole(LRow, 'repeat_from', -1, I - 1);
    Need((LRow.Find('keep') <> nil) and (LRow.Find('keep').JSONType = jtArray),
      'Choose the parts to retain from the earlier section');
    LKeep := LRow.Arrays['keep'];
    Need(LKeep.Count <= 8, 'A section can retain the eight musical providers');
    SetLength(Result[I].Keep, LKeep.Count);
    for J := 0 to LKeep.Count - 1 do
    begin
      Need(LKeep[J].JSONType = jtString, 'Retained part name must be text');
      Result[I].Keep[J] := LKeep.Strings[J];
    end;
  end;
  StudioFormCells(Result);
end;

function EncodeStudioForm(const AForm: TMusicForm): TJSONArray;
var LRow: TJSONObject; LKeep: TJSONArray; I, J: Integer;
begin
  StudioFormCells(AForm);
  Result := TJSONArray.Create;
  try
    for I := 0 to High(AForm) do
    begin
      LKeep := TJSONArray.Create;
      LRow := TJSONObject.Create(['section', String(AForm[I].Section),
        'name', String(AForm[I].Name), 'cells', AForm[I].Cells,
        'repeat_from', AForm[I].RepeatFrom, 'keep', LKeep]);
      Result.Add(LRow);
      for J := 0 to High(AForm[I].Keep) do LKeep.Add(String(AForm[I].Keep[J]));
    end;
  except
    Result.Free;
    raise;
  end;
end;

function StudioFormFrames(const AForm: TMusicForm;
  const ATempoBPM, ASampleRate: Integer): Int64;
begin
  Need((ATempoBPM >= 40) and (ATempoBPM <= 240), 'Tempo must be 40..240 BPM');
  Result := StudioFormFramesAtTempo(AForm, Round(60000000 / ATempoBPM), ASampleRate);
end;

function StudioFormFramesAtTempo(const AForm: TMusicForm;
  const ATempoMicroseconds, ASampleRate: Integer): Int64;
var LClock: TIncrementalTempoClock;
begin
  Need((ATempoMicroseconds >= 250000) and (ATempoMicroseconds <= 1500000),
    'Section tempo must be 40..240 BPM');
  LClock := TIncrementalTempoClock.Create(480, ASampleRate);
  try
    Result := LClock.Advance(StudioFormCells(AForm) * 240, ATempoMicroseconds);
  finally
    LClock.Free;
  end;
end;

function StudioFormTimeline(const AForm: TMusicForm;
  const ATempoMicroseconds, ASampleRate: Integer): TJSONArray;
var LClock: TIncrementalTempoClock; LFrame, LCell: Int64; I: Integer;
begin
  Result := EncodeStudioForm(AForm);
  LClock := nil;
  try
    LClock := TIncrementalTempoClock.Create(480, ASampleRate);
    try
      LFrame := 0;
      LCell := 0;
      for I := 0 to High(AForm) do
      begin
        Result.Objects[I].Add('first_cell', LCell);
        Result.Objects[I].Add('start_frame', LFrame);
        Inc(LFrame, LClock.Advance(AForm[I].Cells * 240, ATempoMicroseconds));
        Result.Objects[I].Add('end_frame', LFrame);
        Inc(LCell, AForm[I].Cells);
      end;
    finally
      LClock.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
