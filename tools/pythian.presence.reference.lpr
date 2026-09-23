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
program pythian_presence_reference;

{$mode delphi}
{$H+}

uses
  Classes, Math, SysUtils,
  pythian.audio, pythian.hash, pythian.wave.read;

type
  TNoteSpec = record
    Id: String;
    SourceGroup: String;
    Sha256: String;
  end;

  TWindowSpec = record
    NoteIndex: Integer;
    Name: String;
    StartFrame: Integer;
    EndFrame: Integer;
  end;

const
  CRate = 16000;
  CFrames = 64000;
  CNoteOff = 48000;
  CNotes: array[0..3] of TNoteSpec = (
    (Id: 'brass_acoustic_046-084-075'; SourceGroup: 'brass_acoustic_046';
      Sha256: 'ff8300e7388f16b1476f23da0c93683d445bf764c85961ef99f5293f74ba2180'),
    (Id: 'guitar_acoustic_030-061-100'; SourceGroup: 'guitar_acoustic_030';
      Sha256: 'cfa08ed3659269a7d661276df25f6b8b7c8fe14b9fcccda214fccfa777c4014c'),
    (Id: 'guitar_acoustic_014-080-100'; SourceGroup: 'guitar_acoustic_014';
      Sha256: '579a4bc3fc2098e89b17094e6c9d7a0d8a8853908f31c9e2016db1531170c0ee'),
    (Id: 'mallet_acoustic_056-050-075'; SourceGroup: 'mallet_acoustic_056';
      Sha256: '2e72192db98fba6464cfed3977174d01c62649ef29d510e6d40a61c54c5d82bf')
  );
  CWindows: array[0..7] of TWindowSpec = (
    (NoteIndex: 0; Name: 'continuation'; StartFrame: 40000; EndFrame: 44000),
    (NoteIndex: 0; Name: 'early_tail'; StartFrame: 48000; EndFrame: 52000),
    (NoteIndex: 0; Name: 'late_tail'; StartFrame: 60000; EndFrame: 64000),
    (NoteIndex: 1; Name: 'continuation'; StartFrame: 40000; EndFrame: 44000),
    (NoteIndex: 1; Name: 'early_tail'; StartFrame: 48000; EndFrame: 52000),
    (NoteIndex: 1; Name: 'late_tail'; StartFrame: 60000; EndFrame: 64000),
    (NoteIndex: 2; Name: 'late_rest'; StartFrame: 60000; EndFrame: 64000),
    (NoteIndex: 3; Name: 'late_rest'; StartFrame: 60000; EndFrame: 64000)
  );

function FileHash(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure CheckWindows;
var
  LIndex: Integer;
begin
  for LIndex := Low(CWindows) to High(CWindows) do
  begin
    if (CWindows[LIndex].NoteIndex < Low(CNotes)) or
      (CWindows[LIndex].NoteIndex > High(CNotes)) or
      (CWindows[LIndex].StartFrame < 0) or
      (CWindows[LIndex].StartFrame >= CWindows[LIndex].EndFrame) or
      (CWindows[LIndex].EndFrame > CFrames) then
    begin
      raise Exception.Create('Invalid frozen window geometry');
    end;
    if ((CWindows[LIndex].Name = 'continuation') and
        (CWindows[LIndex].EndFrame > CNoteOff)) or
      ((CWindows[LIndex].Name <> 'continuation') and
        (CWindows[LIndex].StartFrame < CNoteOff)) then
    begin
      raise Exception.Create('Frozen window crosses the documented note-off');
    end;
  end;
end;

function ReadNote(const ADirectory: String; const ANote: TNoteSpec): TAudioSamples;
var
  LPath: String;
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LBlock: TAudioSamples;
  LOffset, LTake: Integer;
begin
  Result := nil;
  LPath := IncludeTrailingPathDelimiter(ADirectory) + ANote.Id + '.wav';
  if FileHash(LPath) <> ANote.Sha256 then
  begin
    raise Exception.Create('WAV SHA256 mismatch: ' + ANote.Id);
  end;
  LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    if LStream.Size <> 128044 then
    begin
      raise Exception.Create('Unexpected WAV byte count: ' + ANote.Id);
    end;
    LReader := TWaveFrameReader.Create(LStream);
    try
      if (LReader.SampleRate <> CRate) or (LReader.Channels <> 1) or
        (LReader.FormatTag <> 1) or (LReader.BitsPerSample <> 16) or
        (LReader.FrameCount <> CFrames) then
      begin
        raise Exception.Create('Unexpected WAV geometry: ' + ANote.Id);
      end;
      SetLength(Result, CFrames);
      LOffset := 0;
      while LOffset < CFrames do
      begin
        LTake := Min(4096, CFrames - LOffset);
        LBlock := LReader.ReadFrames(LTake);
        if Length(LBlock) <> LTake then
        begin
          raise Exception.Create('Short WAV decode: ' + ANote.Id);
        end;
        Move(LBlock[0], Result[LOffset], LTake * SizeOf(Single));
        Inc(LOffset, LTake);
      end;
      if Length(LReader.ReadFrames(1)) <> 0 then
      begin
        raise Exception.Create('Trailing WAV frames: ' + ANote.Id);
      end;
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
  if FileHash(LPath) <> ANote.Sha256 then
  begin
    raise Exception.Create('WAV changed during read: ' + ANote.Id);
  end;
end;

function WindowRms(const ASamples: TAudioSamples;
  const AWindow: TWindowSpec): Double;
var
  LIndex: Integer;
  LSum: Double;
begin
  LSum := 0;
  for LIndex := AWindow.StartFrame to AWindow.EndFrame - 1 do
  begin
    LSum := LSum + Sqr(ASamples[LIndex]);
  end;
  Result := Sqrt(LSum / (AWindow.EndFrame - AWindow.StartFrame));
end;

procedure ReadReviews(const APath: String; const AReviews: TStringList);
var
  LLines, LFields: TStringList;
  LIndex: Integer;
  LWindow: TWindowSpec;
  LLabel: String;
begin
  if APath = '-' then
  begin
    for LIndex := Low(CWindows) to High(CWindows) do
    begin
      AReviews.Add('pending');
    end;
    Exit;
  end;
  LLines := TStringList.Create;
  LFields := TStringList.Create;
  try
    LLines.LoadFromFile(APath);
    if (LLines.Count <> Length(CWindows) + 1) or
      (LLines[0] <> 'note_id'#9'window'#9'start_frame'#9'end_frame'#9'label') then
    begin
      raise Exception.Create('Review TSV header or row count mismatch');
    end;
    for LIndex := Low(CWindows) to High(CWindows) do
    begin
      LFields.Clear;
      ExtractStrings([#9], [], PChar(LLines[LIndex + 1]), LFields);
      LWindow := CWindows[LIndex];
      if (LFields.Count <> 5) or
        (LFields[0] <> CNotes[LWindow.NoteIndex].Id) or
        (LFields[1] <> LWindow.Name) or
        (LFields[2] <> IntToStr(LWindow.StartFrame)) or
        (LFields[3] <> IntToStr(LWindow.EndFrame)) then
      begin
        raise Exception.Create('Review TSV window identity mismatch at row ' +
          IntToStr(LIndex + 1));
      end;
      LLabel := LFields[4];
      if (LLabel <> 'audible') and (LLabel <> 'not_audible') and
        (LLabel <> 'uncertain') then
      begin
        raise Exception.Create('Invalid review label at row ' +
          IntToStr(LIndex + 1));
      end;
      AReviews.Add(LLabel);
    end;
  finally
    LFields.Free;
    LLines.Free;
  end;
end;

var
  LReviews, LOutput: TStringList;
  LSamples: TAudioSamples;
  LFormat: TFormatSettings;
  LNoteIndex, LWindowIndex: Integer;
  LWindow: TWindowSpec;
begin
  if ParamCount <> 3 then
  begin
    raise Exception.Create('Usage: pythian.presence.reference AUDIO_DIR OUTPUT.tsv REVIEW.tsv|-');
  end;
  CheckWindows;
  LReviews := TStringList.Create;
  LOutput := TStringList.Create;
  try
    ReadReviews(ParamStr(3), LReviews);
    LFormat := DefaultFormatSettings;
    LFormat.DecimalSeparator := '.';
    LOutput.Add('source_group'#9'note_id'#9'wave_sha256'#9'window'#9 +
      'start_frame'#9'end_frame'#9'rms'#9'review');
    for LNoteIndex := Low(CNotes) to High(CNotes) do
    begin
      LSamples := ReadNote(ParamStr(1), CNotes[LNoteIndex]);
      for LWindowIndex := Low(CWindows) to High(CWindows) do
      begin
        LWindow := CWindows[LWindowIndex];
        if LWindow.NoteIndex = LNoteIndex then
        begin
          LOutput.Add(CNotes[LNoteIndex].SourceGroup + #9 +
            CNotes[LNoteIndex].Id + #9 + CNotes[LNoteIndex].Sha256 + #9 +
            LWindow.Name + #9 + IntToStr(LWindow.StartFrame) + #9 +
            IntToStr(LWindow.EndFrame) + #9 +
            FormatFloat('0.000000', WindowRms(LSamples, LWindow), LFormat) +
            #9 + LReviews[LWindowIndex]);
        end;
      end;
    end;
    LOutput.SaveToFile(ParamStr(2));
    WriteLn('packet_sha256=', FileHash(ParamStr(2)));
  finally
    LOutput.Free;
    LReviews.Free;
  end;
end.
