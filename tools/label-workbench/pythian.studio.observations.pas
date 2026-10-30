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

unit pythian.studio.observations;
{$mode delphi}
{$H+}
interface
uses JS, Web;
procedure DrawMusicalObservations(AParent: TJSElement; AResult: TJSObject;
  const AJob: String);
implementation
uses SysUtils, Math, pythian.studio.sources;

function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  AParent.appendChild(Result);
end;

function NoteName(const ANote: Integer): String;
const CNames: array[0..11] of String =
  ('C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B');
begin
  Result := CNames[ANote mod 12];
  if ANote >= 12 then
    Result := Result + IntToStr(ANote div 12 - 1);
end;

procedure DrawMusicalObservations(AParent: TJSElement; AResult: TJSObject;
  const AJob: String);
var
  LProposal, LRow, LChannel, LSpan, LBeats: TJSObject;
  LRows, LChannels, LSpans: TJSArray;
  LDetails, LList, LBox: TJSElement;
  LIndex, LChannelIndex, LPitched, LUnknown, LSilent: Integer;
  LRate, LOrigin, LStart, LEnd: Double;
  LText: String;
begin
  AParent.innerHTML := '';
  LProposal := TJSObject(AResult['musical_proposal']);
  if LProposal = nil then
  begin
    Add(AParent, 'p', 'Run Analyze again to see musical suggestions.');
    Exit;
  end;
  Add(AParent, 'h4', 'Musical suggestions · Experimental');
  LBox := Add(AParent, 'button', 'Use or edit these suggestions');
  LBox.setAttribute('type', 'button');
  LBox.setAttribute('data-musical-job', AJob);
  LBox.className := 'primary';
  LRate := StudioNumber(LProposal, 'sample_rate');
  LOrigin := StudioNumber(LProposal, 'start_frame') / LRate;
  Add(AParent, 'p', 'Analyzed ' + StudioTime(LOrigin) + '–' +
    StudioTime(StudioNumber(LProposal, 'end_frame') / LRate) +
    '. Suggestions only; your generation settings have not changed.').className := 'hint';
  LBeats := TJSObject(AResult['beat_proposal']);
  LText := '';
  if (LBeats <> nil) and isArray(LBeats['candidates']) then
  begin
    LRows := TJSArray(LBeats['candidates']);
    for LIndex := 0 to Min(2, LRows.length - 1) do
    begin
      if LText <> '' then LText := LText + ' / ';
      LText := LText + FormatFloat('0.0', StudioNumber(TJSObject(LRows[LIndex]), 'bpm'));
    end;
  end;
  if LText = '' then LText := 'No pulse suggestion'
  else LText := 'Tempo candidates: ' + LText + ' BPM';
  Add(AParent, 'p', LText);
  LRows := TJSArray(LProposal['tonal_candidates']);
  if isArray(LRows) and (LRows.length > 0) then
  begin
    LDetails := Add(AParent, 'details', '');
    LRow := TJSObject(LRows[0]);
    LText := StringReplace(StudioText(LRow, 'mode'), '_', ' ', [rfReplaceAll]);
    Add(LDetails, 'summary', 'Suggested key: ' +
      NoteName(Trunc(StudioNumber(LRow, 'root'))) + ' ' + LText + ' · alternatives');
    Add(LDetails, 'p', 'Ranked spectral fits. These scores are not confidence percentages.').className := 'hint';
    LList := Add(LDetails, 'ol', '');
    for LIndex := 0 to LRows.length - 1 do
    begin
      LRow := TJSObject(LRows[LIndex]);
      Add(LList, 'li', NoteName(Trunc(StudioNumber(LRow, 'root'))) + ' ' +
        StringReplace(StudioText(LRow, 'mode'), '_', ' ', [rfReplaceAll]) +
        ' · fit ' + FormatFloat('0.000', StudioNumber(LRow, 'fit')));
    end;
  end
  else Add(AParent, 'p', 'No key suggestion from this audio.');
  LDetails := Add(AParent, 'details', '');
  Add(LDetails, 'summary', 'Pitch suggestions · first ' +
    StudioTime(StudioNumber(LProposal, 'pitch_frame_count') /
      StudioNumber(LProposal, 'pitch_sample_rate')));
  Add(LDetails, 'p', 'Each channel is checked separately. Parts are not separated from a mix. Spans estimate stable pitch, not exact note attacks. Unmeasured edges are omitted.').className := 'hint';
  LChannels := TJSArray(LProposal['pitch_channels']);
  for LChannelIndex := 0 to LChannels.length - 1 do
  begin
    LChannel := TJSObject(LChannels[LChannelIndex]);
    LSpans := TJSArray(LChannel['spans']);
    LPitched := 0;
    LUnknown := 0;
    LSilent := 0;
    for LIndex := 0 to LSpans.length - 1 do
    begin
      case StudioText(TJSObject(LSpans[LIndex]), 'kind') of
        'pitch': Inc(LPitched);
        'silence': Inc(LSilent);
      else Inc(LUnknown);
      end;
    end;
    LBox := Add(LDetails, 'details', '');
    if LSpans.length = 0 then
    begin
      Add(LBox, 'summary', 'Channel ' + IntToStr(LChannelIndex + 1) + ': pitch unavailable');
      Add(LBox, 'p', 'This input is shorter than one complete pitch window.');
      Continue;
    end;
    Add(LBox, 'summary', 'Channel ' + IntToStr(LChannelIndex + 1) + ': ' +
      IntToStr(LPitched) + ' pitched, ' + IntToStr(LUnknown) + ' uncertain, ' +
      IntToStr(LSilent) + ' silent spans');
    Add(LBox, 'p', 'Measured ' + StudioTime(LOrigin +
      StudioNumber(LChannel, 'measured_start_frame') / StudioNumber(LProposal, 'pitch_sample_rate')) +
      '–' + StudioTime(LOrigin + StudioNumber(LChannel, 'measured_end_frame') /
      StudioNumber(LProposal, 'pitch_sample_rate')) + ' in the original.').className := 'hint';
    LList := Add(LBox, 'ul', '');
    for LIndex := 0 to LSpans.length - 1 do
    begin
      LSpan := TJSObject(LSpans[LIndex]);
      LText := StudioText(LSpan, 'kind');
      if LText = 'pitch' then
        LText := NoteName(Trunc(StudioNumber(LSpan, 'note')));
      LStart := LOrigin + StudioNumber(LSpan, 'start_frame') /
        StudioNumber(LProposal, 'pitch_sample_rate');
      LEnd := LOrigin + StudioNumber(LSpan, 'end_frame') /
        StudioNumber(LProposal, 'pitch_sample_rate');
      Add(LList, 'li', StudioTime(LStart) + '–' + StudioTime(LEnd) + ' · ' + LText);
    end;
  end;
  LDetails := Add(AParent, 'details', '');
  Add(LDetails, 'summary', 'Sound and volume');
  Add(LDetails, 'p', 'Spectral brightness: ' +
    FormatFloat('0', StudioNumber(LProposal, 'mean_centroid_hz')) + ' Hz centroid. ' +
    'Window loudness: ' + FormatFloat('0.000', StudioNumber(LProposal, 'minimum_window_rms')) +
    '–' + FormatFloat('0.000', StudioNumber(LProposal, 'maximum_window_rms')) + ' RMS.');
  Add(LDetails, 'p', 'Measurements of the mix; these do not identify instruments or create a style. Use or edit the suggestions to try a pitch motif with synthesized accompaniment.').className := 'hint';
end;
end.
