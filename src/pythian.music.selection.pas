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

unit pythian.music.selection;

{$mode delphi}
{$H+}

interface

uses pythian.text;

const
  MusicalClassificationPolicy = 'exact-label-whole-before-clips-v1';
  MaximumClassifiedMusicSelections = 256;
  MaximumMusicClassifications = 16;
  MaximumMusicClassificationBytes = 256;

type
  TMusicClassifications = array of TScalarText;
  TClassifiedMusicSelection = record
    SourceId: String;
    WholeRecording: Boolean;
    StartFrame: Int64;
    EndFrame: Int64;
    Classifications: TMusicClassifications;
  end;
  TClassifiedMusicSelections = array of TClassifiedMusicSelection;
  TMusicSelectionFlags = array of Boolean;

procedure ValidateMusicClassification(const ALabel: TScalarText);
function FindMusicClassification(const ALabels: TMusicClassifications;
  const ALabel: TScalarText): Integer;
function AvailableMusicClassifications(const ASelections: TClassifiedMusicSelections):
  TMusicClassifications;
{ Big Boss: an explicit teaching-selection action, never genre/instrument
  inference. Exact canonical Unicode labels are case-sensitive. A matching whole
  recording suppresses its clips. Otherwise matching disjoint clips are selected.
  Rows retain their input order and original half-open clocks. Invalid/no-match/
  overlapping requests raise before publishing flags; inputs remain unchanged. }
function ClassifyMusicSelection(const ASelections: TClassifiedMusicSelections;
  const ALabel: TScalarText): TMusicSelectionFlags;

implementation

uses pythian.audio, pythian.time;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure ValidateMusicClassification(const ALabel: TScalarText);
begin
  ValidateScalarText(ALabel, MaximumMusicClassificationBytes, False);
end;

function FindMusicClassification(const ALabels: TMusicClassifications;
  const ALabel: TScalarText): Integer;
var
  I: Integer;
begin
  for I := 0 to High(ALabels) do
  begin
    if ALabels[I] = ALabel then Exit(I);
  end;
  Result := -1;
end;

procedure ValidateSelections(const ASelections: TClassifiedMusicSelections);
var
  I: Integer;
  J: Integer;
  LWhole: Integer;
begin
  Need(Length(ASelections) <= MaximumClassifiedMusicSelections,
    'Too many recordings or clips for classification selection');
  for I := 0 to High(ASelections) do
  begin
    ValidateScalarText(ASelections[I].SourceId, 256, False);
    RequireExactTimingCounter(ASelections[I].StartFrame, 'Classified selection start');
    RequireExactTimingCounter(ASelections[I].EndFrame, 'Classified selection end');
    Need(ASelections[I].StartFrame < ASelections[I].EndFrame,
      'Classified music must have a nonempty original source range');
    Need(Length(ASelections[I].Classifications) <= MaximumMusicClassifications,
      'Too many labels for one recording or clip');
    for J := 0 to High(ASelections[I].Classifications) do
    begin
      ValidateMusicClassification(ASelections[I].Classifications[J]);
    end;
    LWhole := -1;
    for J := 0 to High(ASelections) do
    begin
      if (ASelections[J].SourceId = ASelections[I].SourceId) and
        ASelections[J].WholeRecording then
      begin
        Need(LWhole < 0, 'A classified source has more than one whole recording');
        LWhole := J;
      end;
    end;
    Need(LWhole >= 0, 'Classified clips require a declared whole-recording clock');
    Need((ASelections[LWhole].StartFrame = 0) and
      (ASelections[I].EndFrame <= ASelections[LWhole].EndFrame),
      'Classified clip exceeds its original recording clock');
  end;
end;

function AvailableMusicClassifications(const ASelections: TClassifiedMusicSelections):
  TMusicClassifications;
var
  LLabels: TMusicClassifications;
  I: Integer;
  J: Integer;
begin
  ValidateSelections(ASelections);
  LLabels := nil;
  for I := 0 to High(ASelections) do
  begin
    for J := 0 to High(ASelections[I].Classifications) do
    begin
      if FindMusicClassification(LLabels, ASelections[I].Classifications[J]) < 0 then
      begin
        SetLength(LLabels, Length(LLabels) + 1);
        LLabels[High(LLabels)] := ASelections[I].Classifications[J];
      end;
    end;
  end;
  Result := LLabels;
end;

function ClassifyMusicSelection(const ASelections: TClassifiedMusicSelections;
  const ALabel: TScalarText): TMusicSelectionFlags;
var
  LSelected: TMusicSelectionFlags;
  LFound: Boolean;
  I: Integer;
  J: Integer;
begin
  ValidateMusicClassification(ALabel);
  ValidateSelections(ASelections);
  SetLength(LSelected, Length(ASelections));
  for I := 0 to High(ASelections) do
  begin
    LSelected[I] := FindMusicClassification(ASelections[I].Classifications, ALabel) >= 0;
  end;
  LFound := False;
  for I := 0 to High(ASelections) do
  begin
    if not LSelected[I] or ASelections[I].WholeRecording then
    begin
      Continue;
    end;
    for J := 0 to High(ASelections) do
    begin
      if LSelected[J] and ASelections[J].WholeRecording and
        (ASelections[J].SourceId = ASelections[I].SourceId) then
      begin
        LSelected[I] := False;
      end;
    end;
  end;
  for I := 0 to High(ASelections) do
  begin
    if not LSelected[I] then
    begin
      Continue;
    end;
    LFound := True;
    for J := 0 to I - 1 do
    begin
      Need(not (LSelected[J] and (ASelections[I].SourceId = ASelections[J].SourceId) and
        (ASelections[I].StartFrame < ASelections[J].EndFrame) and
        (ASelections[I].EndFrame > ASelections[J].StartFrame)),
        'Matching clips overlap. Choose disjoint clips or the whole track.');
    end;
  end;
  Need(LFound, 'No music has that label. Choose another label or select music manually.');
  Result := LSelected;
end;

end.
