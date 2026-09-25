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
program pythian.compose;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Classes,
  Math,
  pythian.audio,
  pythian.music,
  pythian.music.compose,
  pythian.music.render,
  pythian.synth,
  pythian.time,
  pythian.articulation,
  pythian.wave,
  pythian.hash;

const
  CSampleRate = 44100;
  CAttackFrames = 44;
  CReleaseFrames = 44;
  CMaximumJumps = 10;
  CMaximumNoteEndJump = 0.005;

type
  TJump = record
    Magnitude: Double;
    Frame: Integer;
    Channel: Integer;
    NearestEndFrames: Integer;
  end;
  TJumpArray = array[0..CMaximumJumps - 1] of TJump;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EAudio.Create(AMessage);
end;

function ParseSeed(const AText: String): Cardinal;
var
  LCode: Integer;
  LValue: Int64;
begin
  Val(AText, LValue, LCode);
  if (LCode <> 0) or (LValue < 0) or (LValue > High(Cardinal)) then
    raise EConvertError.Create('Seed must be an unsigned 32-bit integer');
  Result := Cardinal(LValue);
end;

function ParseChordSchedule(const AText: String): TCompositionChordSchedule;
var
  LWords: TStringList;
  I: Integer;
begin
  LWords := TStringList.Create;
  try
    ExtractStrings([' '], [], PChar(AText), LWords);
    Require(LWords.Count = SourceFreeCompositionBars,
      'Chord schedule must contain exactly sixteen labels');
    for I := 0 to SourceFreeCompositionBars - 1 do
    begin
      if LWords[I] = 'C' then
        Result[I] := ccC
      else if LWords[I] = 'Am' then
        Result[I] := ccAm
      else if LWords[I] = 'F' then
        Result[I] := ccF
      else if LWords[I] = 'G' then
        Result[I] := ccG
      else if LWords[I] = 'Em' then
        Result[I] := ccEm
      else
        raise EConvertError.CreateFmt('Unknown chord at bar %d: %s',
          [I, LWords[I]]);
    end;
  finally
    LWords.Free;
  end;
end;

procedure InsertJump(var AJumps: TJumpArray; const AJump: TJump);
var
  LIndex: Integer;
begin
  if AJump.Magnitude <= AJumps[High(AJumps)].Magnitude then
    Exit;
  AJumps[High(AJumps)] := AJump;
  LIndex := High(AJumps);
  while (LIndex > 0) and
    (AJumps[LIndex].Magnitude > AJumps[LIndex - 1].Magnitude) do
  begin
    AJumps[LIndex] := AJumps[LIndex - 1];
    AJumps[LIndex - 1] := AJump;
    Dec(LIndex);
  end;
end;

function NoteEndFrame(const ASequence: TNoteSequence;
  const AGateIndex: Integer): Integer;
begin
  Result := Integer(ASequence.FrameAtTick(
    ASequence.GateAt(AGateIndex).EndTick, CSampleRate));
end;

procedure AnalyzeClip(const ASequence: TNoteSequence;
  const AClip: TAudioClip; out APeak, AMeanSquare: Double;
  out AJumps: TJumpArray; out AClippedSampleCount: Integer);
var
  LFrame, LChannel, LIndex, LGate: Integer;
  LValue, LPrevious, LJump: Double;
  LSquareTotal: Extended;
  LCandidate: TJump;
  LDistance: Integer;
begin
  Require(AClip.Channels = 2, 'Composed clip must be stereo');
  FillChar(AJumps, SizeOf(AJumps), 0);
  APeak := 0.0;
  LSquareTotal := 0.0;
  AClippedSampleCount := 0;
  for LFrame := 0 to AClip.FrameCount - 1 do
  begin
    for LChannel := 0 to 1 do
    begin
      LValue := AClip.SampleAt(LFrame, LChannel);
      Require(not IsNan(LValue) and not IsInfinite(LValue),
        'Renderer produced a non-finite sample');
      APeak := Max(APeak, Abs(LValue));
      LSquareTotal := LSquareTotal + Sqr(LValue);
      if Abs(LValue) >= 1.0 then
        Inc(AClippedSampleCount);
      if LFrame > 0 then
      begin
        LPrevious := AClip.SampleAt(LFrame - 1, LChannel);
        LJump := Abs(LValue - LPrevious);
        if LJump > AJumps[High(AJumps)].Magnitude then
        begin
          LCandidate.Magnitude := LJump;
          LCandidate.Frame := LFrame;
          LCandidate.Channel := LChannel;
          LCandidate.NearestEndFrames := MaxInt;
          InsertJump(AJumps, LCandidate);
        end;
      end;
    end;
  end;
  AMeanSquare := 0.0;
  if AClip.FrameCount > 0 then
    AMeanSquare := LSquareTotal / (AClip.FrameCount * 2);
  for LIndex := 0 to High(AJumps) do
  begin
    for LGate := 0 to ASequence.NoteCount - 1 do
    begin
      LDistance := Abs(AJumps[LIndex].Frame -
        NoteEndFrame(ASequence, LGate));
      if LDistance < AJumps[LIndex].NearestEndFrames then
        AJumps[LIndex].NearestEndFrames := LDistance;
    end;
  end;
end;

procedure AnalyzeNoteEnds(const ASequence: TNoteSequence;
  const AClip: TAudioClip; out ACheckedGates: Integer;
  out AMaximumJump: Double; out AMaximumFrame, AMaximumChannel,
  AMaximumGate: Integer);
var
  LGate, LFrame, LChannel: Integer;
  LEndFrame, LFirstFrame, LLastFrame: Integer;
  LJump, LPrevious, LCurrent: Double;
begin
  ACheckedGates := 0;
  AMaximumJump := 0.0;
  AMaximumFrame := -1;
  AMaximumChannel := -1;
  AMaximumGate := -1;
  for LGate := 0 to ASequence.NoteCount - 1 do
  begin
    LEndFrame := NoteEndFrame(ASequence, LGate);
    LFirstFrame := Max(1, LEndFrame - CReleaseFrames);
    LLastFrame := Min(AClip.FrameCount - 1, LEndFrame + CReleaseFrames);
    if LFirstFrame > LLastFrame then
      Continue;
    Inc(ACheckedGates);
    for LFrame := LFirstFrame to LLastFrame do
      for LChannel := 0 to 1 do
      begin
        LPrevious := AClip.SampleAt(LFrame - 1, LChannel);
        LCurrent := AClip.SampleAt(LFrame, LChannel);
        LJump := Abs(LCurrent - LPrevious);
        if LJump > AMaximumJump then
        begin
          AMaximumJump := LJump;
          AMaximumFrame := LFrame;
          AMaximumChannel := LChannel;
          AMaximumGate := LGate;
        end;
      end;
  end;
end;

function PcmBytes(const AClip: TAudioClip): TAudioBytes;
var
  LFrame, LChannel, LOffset: Integer;
  LQuantized: SmallInt;
begin
  Result := nil;
  SetLength(Result, AClip.FrameCount * 2 * SizeOf(SmallInt));
  LOffset := 0;
  for LFrame := 0 to AClip.FrameCount - 1 do
    for LChannel := 0 to 1 do
    begin
      LQuantized := QuantizePcm16(AClip.SampleAt(LFrame, LChannel));
      Result[LOffset] := Byte(Word(LQuantized) and $FF);
      Result[LOffset + 1] := Byte((Word(LQuantized) shr 8) and $FF);
      Inc(LOffset, 2);
    end;
end;

function Utf8Bytes(const AText: UTF8String): TAudioBytes;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  for LIndex := 1 to Length(AText) do
    Result[LIndex - 1] := Ord(AText[LIndex]);
end;

procedure WriteBytes(const APath: String; const ABytes: TAudioBytes);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if Length(ABytes) > 0 then
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
  finally
    LStream.Free;
  end;
end;

procedure WriteUtf8(const APath: String; const AText: UTF8String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if Length(AText) > 0 then
      LStream.WriteBuffer(AText[1], Length(AText));
  finally
    LStream.Free;
  end;
end;

function CreateSiblingTemp(const ATarget, APrefix: String): String;
var
  LDirectory: String;
begin
  LDirectory := ExtractFileDir(ATarget);
  if LDirectory = '' then
    LDirectory := GetCurrentDir;
  Result := GetTempFileName(LDirectory, APrefix);
  if Result = '' then
    raise EInOutError.Create('Could not allocate a sibling temporary file');
end;

procedure RemoveOwnedFile(const APath: String);
begin
  if (APath <> '') and FileExists(APath) then
    if not DeleteFile(APath) then
      raise EInOutError.Create('Could not remove staged output: ' + APath);
end;

function UniqueBackupPath(const ATarget: String): String;
var
  LDirectory: String;
  LAttempt: Integer;
begin
  if DirectoryExists(ATarget) then
    raise EInOutError.Create('Output target is a directory: ' + ATarget);
  LDirectory := ExtractFileDir(ATarget);
  if LDirectory = '' then
    LDirectory := GetCurrentDir;
  for LAttempt := 0 to 999 do
  begin
    Result := IncludeTrailingPathDelimiter(LDirectory) + 'pythian-' +
      IntToStr(GetTickCount64) + '-' + IntToStr(LAttempt) + '.bak';
    if not FileExists(Result) and not DirectoryExists(Result) then
      Exit;
  end;
  raise EInOutError.Create('Could not allocate an unused output rollback path');
end;

procedure BackupTarget(const ATarget: String; out ABackup: String);
var
  LBackup: String;
begin
  ABackup := '';
  if DirectoryExists(ATarget) then
    raise EInOutError.Create('Output target is a directory: ' + ATarget);
  if not FileExists(ATarget) then
    Exit;
  LBackup := UniqueBackupPath(ATarget);
  if not RenameFile(ATarget, LBackup) then
    raise EInOutError.Create('Could not preserve existing output: ' + ATarget);
  ABackup := LBackup;
end;

procedure RestoreTarget(const ATarget: String; var ABackup: String);
begin
  if ABackup = '' then
    Exit;
  if FileExists(ATarget) and not DeleteFile(ATarget) then
    raise EInOutError.Create('Could not remove failed new output: ' + ATarget);
  if not RenameFile(ABackup, ATarget) then
    raise EInOutError.Create('Could not restore previous output: ' + ATarget);
  ABackup := '';
end;

procedure CommitOutputPair(const AOutputPath, AReportPath: String;
  const AWav: TAudioBytes; const AReport: UTF8String);
var
  LStagedWav, LStagedReport: String;
  LBackupWav, LBackupReport: String;
  LWavPromoted, LReportPromoted: Boolean;
begin
  if DirectoryExists(AOutputPath) then
    raise EInOutError.Create('WAV output target is a directory: ' + AOutputPath);
  if DirectoryExists(AReportPath) then
    raise EInOutError.Create('Report output target is a directory: ' + AReportPath);

  LStagedWav := '';
  LStagedReport := '';
  LBackupWav := '';
  LBackupReport := '';
  LWavPromoted := False;
  LReportPromoted := False;
  try
    LStagedWav := CreateSiblingTemp(AOutputPath, 'pcw');
    LStagedReport := CreateSiblingTemp(AReportPath, 'pcr');
    WriteBytes(LStagedWav, AWav);
    WriteUtf8(LStagedReport, AReport);

    BackupTarget(AOutputPath, LBackupWav);
    BackupTarget(AReportPath, LBackupReport);
    if not RenameFile(LStagedWav, AOutputPath) then
      raise EInOutError.Create('Could not publish staged WAV output');
    LStagedWav := '';
    LWavPromoted := True;
    if not RenameFile(LStagedReport, AReportPath) then
      raise EInOutError.Create('Could not publish staged report output');
    LStagedReport := '';
    LReportPromoted := True;
  except
    try
      if LReportPromoted then
        RemoveOwnedFile(AReportPath);
      if LWavPromoted then
        RemoveOwnedFile(AOutputPath);
      RestoreTarget(AReportPath, LBackupReport);
      RestoreTarget(AOutputPath, LBackupWav);
    finally
      if LStagedWav <> '' then
        RemoveOwnedFile(LStagedWav);
      if LStagedReport <> '' then
        RemoveOwnedFile(LStagedReport);
    end;
    raise;
  end;

  { Once both new files are in place, old versions are no longer needed. A
    cleanup failure leaves a recoverable private backup but does not make the
    already committed pair appear failed. }
  if LBackupReport <> '' then
    DeleteFile(LBackupReport);
  if LBackupWav <> '' then
    DeleteFile(LBackupWav);
end;

function BuildReport(const AComposition: TCompositionScaffoldReport;
  const ASequence: TNoteSequence; const ARender: TNoteRenderReport;
  const AClip: TAudioClip; const APeak, AMeanSquare: Double;
  const AClippedSamples: Integer; const AJumps: TJumpArray;
  const APcm, AWav: TAudioBytes): UTF8String;
var
  LIndex: Integer;
begin
  Result := AComposition.Text;
  Result := Result + 'render_sample_rate=44100' + #10;
  Result := Result + 'render_channels=2' + #10;
  Result := Result + 'render_frames=' + IntToStr(AClip.FrameCount) + #10;
  Result := Result + 'rendered_notes=' + IntToStr(ARender.RenderedNotes) + #10;
  Result := Result + 'subframe_notes=' + IntToStr(ARender.SubFrameNotes) + #10;
  Result := Result + 'source_phrase_union_count=0; generated_phrase_comparison=not_applicable_empty_source_union; copied_phrase_run=not_applicable_empty_source_union' + #10;
  Result := Result + 'peak_q1e9=' + IntToStr(Round(APeak * 1000000000.0)) + #10;
  Result := Result + 'mean_square_q1e9=' +
    IntToStr(Round(AMeanSquare * 1000000000.0)) + #10;
  Result := Result + 'full_scale_sample_count=' + IntToStr(AClippedSamples) + #10;
  Result := Result + 'pcm_sha256=' + Sha256Bytes(APcm) + #10;
  Result := Result + 'event_ledger_sha256=' +
    Sha256Bytes(Utf8Bytes(AComposition.EventLedger)) + #10;
  Result := Result + 'wav_sha256=' + Sha256Bytes(AWav) + #10;
  Result := Result + 'note_end_pop_check=top-10 adjacent jumps compared with nearest authored gate end' + #10;
  for LIndex := 0 to High(AJumps) do
    Result := Result + Format('jump_%d_frame=%d channel=%d magnitude_q1e9=%d nearest_note_end_frames=%d',
      [LIndex + 1, AJumps[LIndex].Frame, AJumps[LIndex].Channel,
       Round(AJumps[LIndex].Magnitude * 1000000000.0),
       AJumps[LIndex].NearestEndFrames]) + #10;
  Result := Result + 'wav_bytes=' + IntToStr(Length(AWav)) + #10;
end;

procedure Run;
var
  LOutputPath, LReportPath: String;
  LSeed: Cardinal;
  LComposition: TCompositionScaffoldReport;
  LSchedule: TCompositionChordSchedule;
  LSequence: TNoteSequence;
  LVoices: TNoteVoices;
  LRender: TNoteRenderReport;
  LRaw, LClip: TAudioClip;
  LPlan: TArticulationPlan;
  LOmitted, LClippedSamples, LCheckedEndGates: Integer;
  LMaximumEndFrame, LMaximumEndChannel, LMaximumEndGate: Integer;
  LPeak, LMeanSquare: Double;
  LMaximumEndJump: Double;
  LJumps: TJumpArray;
  LPcm, LWav: TAudioBytes;
  LReport: UTF8String;
begin
  if (ParamCount < 1) or (ParamCount > 3) then
    raise EConvertError.Create(
      'Usage: pythian.compose OUTPUT.wav [SEED] ["16 chord labels"]');
  LOutputPath := ExpandFileName(ParamStr(1));
  LReportPath := LOutputPath + '.report.txt';
  LSeed := 1731;
  if ParamCount >= 2 then
    LSeed := ParseSeed(ParamStr(2));
  if ParamCount = 3 then
    LSchedule := ParseChordSchedule(ParamStr(3));
  LSequence := nil;
  LRaw := nil;
  LClip := nil;
  LPlan := nil;
  try
    if ParamCount = 3 then
      LSequence := GenerateCompositionWithChordSchedule(
        LSchedule, LSeed, LComposition)
    else
      LSequence := GenerateSourceFreeComposition(LSeed, LComposition);
    SetLength(LVoices, 2);
    LVoices[0] := DefaultSynthVoice;
    LVoices[0].Gain := 0.12;
    LVoices[0].Pan := -0.25;
    LVoices[0].Envelope.ReleaseSeconds := 0.005;
    LVoices[1] := DefaultSynthVoice;
    LVoices[1].Gain := 0.12;
    LVoices[1].Pan := 0.25;
    LVoices[1].Envelope.ReleaseSeconds := 0.005;
    LRaw := RenderNoteSequence(LSequence, CSampleRate, LVoices, LRender);
    Require((LRender.SourceNotes = LSequence.NoteCount) and
      (LRender.RenderedNotes = LSequence.NoteCount) and
      (LRender.SubFrameNotes = 0), 'Native renderer did not render each gate');
    LPlan := PlanNoteArticulation(LSequence, CSampleRate,
      CAttackFrames, CReleaseFrames, LOmitted);
    Require(LOmitted = 0, 'Articulation omitted one or more note gates');
    LClip := RenderArticulatedClip(LRaw, LPlan);
    Require(LClip.FrameCount = Integer(LSequence.FrameAtTick(
      SourceFreeCompositionTicks, CSampleRate)),
      'Rendered frame count does not match the sequence clock');
    AnalyzeClip(LSequence, LClip, LPeak, LMeanSquare, LJumps,
      LClippedSamples);
    Require(LClippedSamples = 0, 'Rendered PCM reaches full scale');
    AnalyzeNoteEnds(LSequence, LClip, LCheckedEndGates, LMaximumEndJump,
      LMaximumEndFrame, LMaximumEndChannel, LMaximumEndGate);
    Require(LCheckedEndGates = LSequence.NoteCount,
      'Note-end pop check did not cover every gate');
    Require(LMaximumEndJump <= CMaximumNoteEndJump,
      'Note-end adjacent-sample jump exceeds the fixed 0.005 full-scale limit');
    LPcm := PcmBytes(LClip);
    LWav := EncodeWavePcm16(LClip);
    LReport := BuildReport(LComposition, LSequence, LRender, LClip,
      LPeak, LMeanSquare, LClippedSamples, LJumps, LPcm, LWav);
    LReport := LReport + 'note_end_jump_check=each gate end +/-44 frames, both channels' + #10;
    LReport := LReport + 'note_end_checked_gates=' + IntToStr(LCheckedEndGates) + #10;
    LReport := LReport + 'note_end_max_jump_threshold_q1e9=5000000' + #10;
    LReport := LReport + 'note_end_max_jump_q1e9=' +
      IntToStr(Round(LMaximumEndJump * 1000000000.0)) + #10;
    LReport := LReport + 'note_end_max_jump_frame=' + IntToStr(LMaximumEndFrame) + #10;
    LReport := LReport + 'note_end_max_jump_channel=' + IntToStr(LMaximumEndChannel) + #10;
    LReport := LReport + 'note_end_max_jump_gate_index=' + IntToStr(LMaximumEndGate) + #10;
    LReport := LReport + 'status=PASS' + #10;
    CommitOutputPair(LOutputPath, LReportPath, LWav, LReport);
    WriteLn('wav=', LOutputPath);
    WriteLn('report=', LReportPath);
    WriteLn('event_count=', LComposition.EventCount);
    WriteLn('event_ledger_sha256=', Sha256Bytes(Utf8Bytes(LComposition.EventLedger)));
    WriteLn('pcm_sha256=', Sha256Bytes(LPcm));
    WriteLn('wav_sha256=', Sha256Bytes(LWav));
    WriteLn('status=PASS');
  finally
    LPlan.Free;
    LClip.Free;
    LRaw.Free;
    LSequence.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'status=STOP');
      WriteLn(StdErr, 'error=', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
