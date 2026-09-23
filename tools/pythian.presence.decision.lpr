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
program pythian_presence_decision;

{$mode delphi}
{$H+}

uses
  Classes, Math, SysUtils,
  pythian.audio, pythian.analysis, pythian.activity, pythian.hash,
  pythian.wave.read;

type
  TNoteSpec = record
    Id: String;
    SourceGroup: String;
    Role: String;
    Sha256: String;
  end;

  TWindowSpec = record
    NoteIndex: Integer;
    Name: String;
    StartFrame: Integer;
    EndFrame: Integer;
  end;

  TWindowDecision = record
    Rms: Double;
    ActiveFeatures: Integer;
    Present: Boolean;
    LabelText: String;
  end;

const
  CRate = 16000;
  CFrames = 64000;
  CWindowFrames = 4000;
  CNoteOff = 48000;
  CDevelopmentNotes: array[0..3] of TNoteSpec = (
    (Id: 'brass_acoustic_046-084-075'; SourceGroup: 'brass_acoustic_046';
      Role: 'development';
      Sha256: 'ff8300e7388f16b1476f23da0c93683d445bf764c85961ef99f5293f74ba2180'),
    (Id: 'guitar_acoustic_030-061-100'; SourceGroup: 'guitar_acoustic_030';
      Role: 'development';
      Sha256: 'cfa08ed3659269a7d661276df25f6b8b7c8fe14b9fcccda214fccfa777c4014c'),
    (Id: 'guitar_acoustic_014-080-100'; SourceGroup: 'guitar_acoustic_014';
      Role: 'development';
      Sha256: '579a4bc3fc2098e89b17094e6c9d7a0d8a8853908f31c9e2016db1531170c0ee'),
    (Id: 'mallet_acoustic_056-050-075'; SourceGroup: 'mallet_acoustic_056';
      Role: 'development';
      Sha256: '2e72192db98fba6464cfed3977174d01c62649ef29d510e6d40a61c54c5d82bf')
  );
  CTrainNotes: array[0..3] of TNoteSpec = (
    (Id: 'flute_acoustic_028-049-075'; SourceGroup: 'flute_acoustic_028';
      Role: 'independent_evaluation';
      Sha256: 'ee8308494d159996eb74ab878ffcb6b4f4f736cf2ae09e427a45f66ee271ef8d'),
    (Id: 'guitar_acoustic_008-048-075'; SourceGroup: 'guitar_acoustic_008';
      Role: 'independent_evaluation';
      Sha256: '39d8f9db0976b5b784c84817bb97e73299c05324935b4ac162b8518deba350ef'),
    (Id: 'bass_acoustic_000-059-075'; SourceGroup: 'bass_acoustic_000';
      Role: 'independent_evaluation';
      Sha256: 'b6b93a65946943eb0d445f1d4e9d5d80843090a607e8d531d94a65c7deebef3b'),
    (Id: 'brass_acoustic_040-052-075'; SourceGroup: 'brass_acoustic_040';
      Role: 'independent_evaluation';
      Sha256: '9403cd938c72c6dffd803d5636acd678dba5a61000987260019e0b9e878501b1')
  );
  CTrainPacketHash =
    'abbf3b4b3d4243498e99f2b677406292008893961cbc17649744aa6c2f675b19';
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
  CReferenceHeader = 'source_group'#9'role'#9'note_id'#9'wave_sha256'#9 +
    'window'#9'start_frame'#9'end_frame'#9'rms'#9'review';

var
  GNotes: array[0..3] of TNoteSpec;
  GTrainMode: Boolean;

procedure Require(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
    raise EAudio.Create(AMessage);
end;

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

procedure CheckFrozenWindows;
var
  I: Integer;
begin
  for I := Low(CWindows) to High(CWindows) do
  begin
    Require((CWindows[I].NoteIndex >= Low(GNotes)) and
      (CWindows[I].NoteIndex <= High(GNotes)) and
      (CWindows[I].StartFrame >= 0) and
      (CWindows[I].EndFrame - CWindows[I].StartFrame = CWindowFrames) and
      (CWindows[I].EndFrame <= CFrames), 'Invalid frozen window geometry');
    if CWindows[I].Name = 'continuation' then
      Require(CWindows[I].EndFrame <= CNoteOff,
        'Continuation window crosses documented control note-off')
    else
      Require(CWindows[I].StartFrame >= CNoteOff,
        'Post-control window precedes documented control note-off');
  end;
end;

function ReadNote(const ADirectory: String; const ANote: TNoteSpec): TAudioSamples;
var
  LPath: String;
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LBlock: TAudioSamples;
  LOffset: Integer;
  LTake: Integer;
begin
  Result := nil;
  LPath := IncludeTrailingPathDelimiter(ADirectory) + ANote.Id + '.wav';
  Require(FileHash(LPath) = ANote.Sha256, 'WAV SHA256 mismatch: ' + ANote.Id);
  LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    Require(LStream.Size = 128044, 'Unexpected WAV byte count: ' + ANote.Id);
    LReader := TWaveFrameReader.Create(LStream);
    try
      Require((LReader.SampleRate = CRate) and (LReader.Channels = 1) and
        (LReader.FormatTag = 1) and (LReader.BitsPerSample = 16) and
        (LReader.FrameCount = CFrames), 'Unexpected WAV geometry: ' + ANote.Id);
      SetLength(Result, CFrames);
      LOffset := 0;
      while LOffset < CFrames do
      begin
        LTake := Min(4096, CFrames - LOffset);
        LBlock := LReader.ReadFrames(LTake);
        Require(Length(LBlock) = LTake, 'Short WAV decode: ' + ANote.Id);
        Move(LBlock[0], Result[LOffset], LTake * SizeOf(Single));
        Inc(LOffset, LTake);
      end;
      Require(Length(LReader.ReadFrames(1)) = 0,
        'Trailing WAV frames: ' + ANote.Id);
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
  Require(FileHash(LPath) = ANote.Sha256, 'WAV changed during read: ' + ANote.Id);
end;

function MeasureWindow(const ASamples: TAudioSamples;
  const AWindow: TWindowSpec; const AAnalysis: TAnalysisOptions;
  const AActivityOptions: TActivityOptions): TWindowDecision;
var
  LClipSamples: TAudioSamples;
  LClip: TAudioClip;
  LFeatures: TAudioFeatures;
  LActivity: TAcousticActivity;
  LIndex: Integer;
  LSum: Double;
begin
  Require((AWindow.EndFrame - AWindow.StartFrame = CWindowFrames) and
    (Length(ASamples) = CFrames), 'Window audio and geometry differ');
  LClipSamples := Copy(ASamples, AWindow.StartFrame, CWindowFrames);
  Require(Length(LClipSamples) = CWindowFrames, 'Window sample copy is short');
  LClip := TAudioClip.Create(CRate, 1, LClipSamples);
  try
    LFeatures := AnalyzeAudio(LClip, AAnalysis);
    LActivity := AnalyzeAcousticActivity(LFeatures, AAnalysis,
      CWindowFrames, AActivityOptions);
    Result := Default(TWindowDecision);
    LSum := 0;
    for LIndex := 0 to High(LClipSamples) do
      LSum := LSum + Sqr(LClipSamples[LIndex]);
    Result.Rms := Sqrt(LSum / Length(LClipSamples));
    for LIndex := 0 to High(LActivity.Actions) do
      if LActivity.Actions[LIndex] <> aaSilence then
        Inc(Result.ActiveFeatures);
    Result.Present := Result.ActiveFeatures > 0;
  finally
    LClip.Free;
  end;
end;

function QuantizedTone(const APeakLSB: Integer): TAudioSamples;
var
  LFrame: Integer;
  LCode: Integer;
begin
  Result := nil;
  SetLength(Result, CFrames);
  for LFrame := 0 to CFrames - 1 do
  begin
    LCode := Round(APeakLSB * Sin(2 * Pi * 1000 * LFrame / CRate));
    Result[LFrame] := LCode / 32768;
  end;
end;

procedure RunControls;
var
  LZero: TAudioSamples;
  LBelow: TAudioSamples;
  LAbove: TAudioSamples;
  LWindow: TWindowSpec;
  LAnalysis: TAnalysisOptions;
  LActivityOptions: TActivityOptions;
  LZeroDecision: TWindowDecision;
  LBelowDecision: TWindowDecision;
  LAboveDecision: TWindowDecision;
  LReplayDecision: TWindowDecision;
  I: Integer;
begin
  CheckFrozenWindows;
  LAnalysis := DefaultAnalysisOptions;
  LActivityOptions := DefaultActivityOptions;
  LWindow := CWindows[0];
  LWindow.StartFrame := 0;
  LWindow.EndFrame := CWindowFrames;
  SetLength(LZero, CFrames);
  LBelow := QuantizedTone(2);
  LAbove := QuantizedTone(10);
  LZeroDecision := MeasureWindow(LZero, LWindow, LAnalysis, LActivityOptions);
  LBelowDecision := MeasureWindow(LBelow, LWindow, LAnalysis, LActivityOptions);
  LAboveDecision := MeasureWindow(LAbove, LWindow, LAnalysis, LActivityOptions);
  LReplayDecision := MeasureWindow(LAbove, LWindow, LAnalysis, LActivityOptions);
  Require(not LZeroDecision.Present and (LZeroDecision.ActiveFeatures = 0),
    'Digital silence control must remain inactive');
  Require(not LBelowDecision.Present and (LBelowDecision.ActiveFeatures = 0) and
    (LBelowDecision.Rms < LAnalysis.SilenceRms),
    'Quantized subfloor control must remain inactive');
  Require(LAboveDecision.Present and (LAboveDecision.ActiveFeatures > 0) and
    (LAboveDecision.Rms > LAnalysis.SilenceRms),
    'Quantized above-floor control must be active');
  Require((LAboveDecision.Present = LReplayDecision.Present) and
    (LAboveDecision.ActiveFeatures = LReplayDecision.ActiveFeatures) and
    (LAboveDecision.Rms = LReplayDecision.Rms),
    'Source-free activity decision must replay deterministically');
  for I := 0 to High(LAbove) do
    Require((LAbove[I] * 32768 = Round(LAbove[I] * 32768)),
      'Synthetic controls must remain PCM16 quantized');
  WriteLn('PASS silence, below-floor PCM16, above-floor PCM16, replay, frozen geometry');
end;

procedure ReadReference(const APath: String; const ADecisions: array of TWindowDecision;
  const AOutputPath: String);
var
  LLines: TStringList;
  LFields: TStringList;
  LOutput: TStringList;
  LWindow: TWindowSpec;
  LNote: TNoteSpec;
  LExpectedRms: Double;
  LFormat: TFormatSettings;
  LPacketHash: String;
  LReview: String;
  LDecision: String;
  LMatch: String;
  LAudibleCount: Integer;
  LNotAudibleCount: Integer;
  LUncertainCount: Integer;
  LMatchCount: Integer;
  I: Integer;
begin
  LLines := TStringList.Create;
  LFields := TStringList.Create;
  LOutput := TStringList.Create;
  try
    LLines.LoadFromFile(APath);
    Require((LLines.Count = Length(CWindows) + 1) and
      (LLines[0] = CReferenceHeader),
      'Reference packet header or row count differs');
    LPacketHash := FileHash(APath);
    if GTrainMode then
      Require(LPacketHash = CTrainPacketHash,
        'Independent reference packet SHA256 differs from frozen review');
    LFormat := DefaultFormatSettings;
    LFormat.DecimalSeparator := '.';
    LAudibleCount := 0;
    LNotAudibleCount := 0;
    LUncertainCount := 0;
    LMatchCount := 0;
    LOutput.Add('source_group'#9'role'#9'note_id'#9'wave_sha256'#9 +
      'reference_packet_sha256'#9'window'#9'start_frame'#9'end_frame'#9 +
      'window_rms'#9'silence_rms_floor'#9'active_features'#9 +
      'activity_decision'#9'review'#9'match');
    for I := Low(CWindows) to High(CWindows) do
    begin
      LFields.Clear;
      ExtractStrings([#9], [], PChar(LLines[I + 1]), LFields);
      Require(LFields.Count = 9, 'Reference packet row field count differs');
      LWindow := CWindows[I];
      LNote := GNotes[LWindow.NoteIndex];
      Require((LFields[0] = LNote.SourceGroup) and
        (LFields[1] = LNote.Role) and
        (LFields[2] = LNote.Id) and (LFields[3] = LNote.Sha256) and
        (LFields[4] = LWindow.Name) and
        (LFields[5] = IntToStr(LWindow.StartFrame)) and
        (LFields[6] = IntToStr(LWindow.EndFrame)),
        'Reference row source, role or window identity differs');
      Require(TryStrToFloat(LFields[7], LExpectedRms, LFormat) and
        (Abs(LExpectedRms - ADecisions[I].Rms) <= 0.00000051),
        'Reference packet RMS differs from independently measured window');
      LReview := LFields[8];
      Require((LReview = 'audible') or (LReview = 'not_audible') or
        (GTrainMode and (LReview = 'uncertain')),
        'Frozen review label is invalid');
      if LReview = 'audible' then
        Inc(LAudibleCount)
      else if LReview = 'not_audible' then
      begin
        Inc(LNotAudibleCount);
      end
      else
        Inc(LUncertainCount);
      if ADecisions[I].Present then
        LDecision := 'activity_present'
      else
        LDecision := 'no_activity';
      if LReview = 'uncertain' then
        LMatch := 'unknown'
      else if ((LReview = 'audible') = ADecisions[I].Present) then
      begin
        LMatch := 'match';
        Inc(LMatchCount);
      end
      else
        LMatch := 'mismatch';
      LOutput.Add(LNote.SourceGroup + #9 + LNote.Role + #9 + LNote.Id + #9 +
        LNote.Sha256 + #9 + LPacketHash + #9 + LWindow.Name + #9 +
        IntToStr(LWindow.StartFrame) + #9 + IntToStr(LWindow.EndFrame) + #9 +
        FormatFloat('0.000000', ADecisions[I].Rms, LFormat) + #9 +
        FormatFloat('0.000000', DefaultAnalysisOptions.SilenceRms, LFormat) + #9 +
        IntToStr(ADecisions[I].ActiveFeatures) + #9 + LDecision + #9 +
        LReview + #9 + LMatch);
    end;
    LOutput.SaveToFile(AOutputPath);
    WriteLn('reference_packet_sha256=', LPacketHash,
      ' rows=', Length(CWindows), ' audible_labels=', LAudibleCount,
      ' not_audible_labels=', LNotAudibleCount,
      ' uncertain_labels=', LUncertainCount,
      ' matched=', LMatchCount,
      ' output_sha256=', FileHash(AOutputPath));
    if not GTrainMode then
    begin
      Require((LAudibleCount = 6) and (LNotAudibleCount = 2),
        'Frozen label distribution differs from the declared 6/2 set');
      Require(LMatchCount = Length(CWindows),
        'Frozen activity observation missed one or more reviewed windows');
    end;
  finally
    LOutput.Free;
    LFields.Free;
    LLines.Free;
  end;
end;

procedure RunPacket(const AAudioDirectory, AReferencePath,
  AOutputPath: String);
var
  LNotes: array[0..High(GNotes)] of TAudioSamples;
  LDecisions: array[0..High(CWindows)] of TWindowDecision;
  LAnalysis: TAnalysisOptions;
  LActivityOptions: TActivityOptions;
  LWindow: TWindowSpec;
  I: Integer;
begin
  CheckFrozenWindows;
  LAnalysis := DefaultAnalysisOptions;
  LActivityOptions := DefaultActivityOptions;
  { Complete every decision from WAV samples before opening the reference TSV. }
  for I := Low(GNotes) to High(GNotes) do
    LNotes[I] := ReadNote(AAudioDirectory, GNotes[I]);
  for I := Low(CWindows) to High(CWindows) do
  begin
    LWindow := CWindows[I];
    LDecisions[I] := MeasureWindow(LNotes[LWindow.NoteIndex], LWindow,
      LAnalysis, LActivityOptions);
  end;
  ReadReference(AReferencePath, LDecisions, AOutputPath);
end;

var
  I: Integer;
begin
  try
    GTrainMode := (ParamCount = 5) and (ParamStr(5) = 'train');
    for I := Low(GNotes) to High(GNotes) do
      if GTrainMode then
        GNotes[I] := CTrainNotes[I]
      else
        GNotes[I] := CDevelopmentNotes[I];
    if (ParamCount = 1) and (ParamStr(1) = 'controls') then
      RunControls
    else if (((ParamCount = 4) or GTrainMode) and
      (ParamStr(1) = 'run')) then
      RunPacket(ParamStr(2), ParamStr(3), ParamStr(4))
    else
      raise EAudio.Create('Usage: pythian.presence.decision controls | ' +
        'run <audio-directory> <bound-reference.tsv> <output.tsv> [train]');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
