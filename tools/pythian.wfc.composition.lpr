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
program pythian_wfc_compose_cli;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Classes,
  pythian.audio,
  pythian.music,
  pythian.music.compose,
  pythian.music.render,
  pythian.synth,
  pythian.articulation,
  pythian.wave,
  pythian.hash,
  pythian.wfc.compose;

const
  CSampleRate = 44100;
  CAttackFrames = 44;
  CReleaseFrames = 44;

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
  Require((LCode = 0) and (LValue >= 0) and (LValue <= High(Cardinal)),
    'Seed must be an unsigned 32-bit integer');
  Result := Cardinal(LValue);
end;

function ParseChord(const AText: String): TCompositionChord;
begin
  if AText = 'C' then
    Result := ccC
  else if AText = 'Am' then
    Result := ccAm
  else if AText = 'F' then
    Result := ccF
  else if AText = 'G' then
    Result := ccG
  else if AText = 'Em' then
    Result := ccEm
  else
    raise EAudio.Create('Unknown chord label: ' + AText);
end;

function ReadSources(const APath: String): TCompositionChordSources;
var
  LLines: TStringList;
  LWords: TStringList;
  LLine: String;
  LLineIndex: Integer;
  LSourceIndex: Integer;
  LStream: TFileStream;
  I: Integer;
begin
  Result := nil;
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require((LStream.Size > 0) and (LStream.Size <= 16384),
      'Chord source file exceeds the 16-KiB input bound');
  finally
    LStream.Free;
  end;
  LLines := TStringList.Create;
  LWords := TStringList.Create;
  try
    LLines.LoadFromFile(APath);
    Require(LLines.Count <= 64, 'Chord source file has too many lines');
    for LLineIndex := 0 to LLines.Count - 1 do
    begin
      LLine := Trim(LLines[LLineIndex]);
      if LLine = '' then
        Continue;
      if LLine[1] = '#' then
        Continue;
      Require(Length(Result) < 8,
        'Chord source file exceeds the eight-sample bound');
      LWords.Clear;
      ExtractStrings([' ', #9], [], PChar(LLine), LWords);
      Require(LWords.Count = SourceFreeCompositionBars,
        'Every chord source must have exactly sixteen bars');
      LSourceIndex := Length(Result);
      SetLength(Result, LSourceIndex + 1);
      for I := 0 to SourceFreeCompositionBars - 1 do
        Result[LSourceIndex][I] := ParseChord(LWords[I]);
    end;
    Require(Length(Result) > 0, 'Chord source file is empty');
  finally
    LWords.Free;
    LLines.Free;
  end;
end;

procedure WriteNewFile(const APath: String; const ABytes: TAudioBytes);
var
  LTemporaryPath: String;
  LStream: TFileStream;
begin
  Require(not FileExists(APath) and not DirectoryExists(APath),
    'Output path already exists');
  LTemporaryPath := APath + '.wfc-compose-tmp';
  Require(not FileExists(LTemporaryPath) and not DirectoryExists(LTemporaryPath),
    'Staging path already exists');
  try
    LStream := TFileStream.Create(LTemporaryPath, fmCreate);
    try
      if Length(ABytes) > 0 then
        LStream.WriteBuffer(ABytes[0], Length(ABytes));
    finally
      LStream.Free;
    end;
    if not RenameFile(LTemporaryPath, APath) then
      raise EInOutError.Create('Could not publish the staged WAV');
  except
    if FileExists(LTemporaryPath) then
      DeleteFile(LTemporaryPath);
    raise;
  end;
end;

procedure Run;
var
  LOutputPath: String;
  LSourcePath: String;
  LSeed: Cardinal;
  LSources: TCompositionChordSources;
  LSequence: TNoteSequence;
  LReport: TWfcCompositionReport;
  LVoices: TNoteVoices;
  LRender: TNoteRenderReport;
  LRaw: TAudioClip;
  LClip: TAudioClip;
  LPlan: TArticulationPlan;
  LOmitted: Integer;
  LWav: TAudioBytes;
begin
  Require((ParamCount >= 2) and (ParamCount <= 3),
    'Usage: pythian.wfc.composition OUTPUT.wav SOURCES.txt [SEED]');
  LOutputPath := ExpandFileName(ParamStr(1));
  LSourcePath := ExpandFileName(ParamStr(2));
  Require(not FileExists(LOutputPath) and not DirectoryExists(LOutputPath),
    'Output path already exists');
  LSeed := 1731;
  if ParamCount = 3 then
    LSeed := ParseSeed(ParamStr(3));
  LSources := ReadSources(LSourcePath);
  LSequence := nil;
  LRaw := nil;
  LClip := nil;
  LPlan := nil;
  try
    if not TryGenerateWfcChordComposition(LSources, LSeed,
      LSequence, LReport) then
      raise EAudio.Create('WFC chord composition stopped: ' +
        LReport.FailureReason);
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
      (LRender.SubFrameNotes = 0), 'Renderer omitted a note gate');
    LPlan := PlanNoteArticulation(LSequence, CSampleRate,
      CAttackFrames, CReleaseFrames, LOmitted);
    Require(LOmitted = 0, 'Articulation omitted a note gate');
    LClip := RenderArticulatedClip(LRaw, LPlan);
    Require(LClip.FrameCount = Integer(LSequence.FrameAtTick(
      SourceFreeCompositionTicks, CSampleRate)),
      'Rendered length does not match composition clock');
    LWav := EncodeWavePcm16(LClip);
    WriteNewFile(LOutputPath, LWav);
    Write(LReport.Text);
    WriteLn('wav=', LOutputPath);
    WriteLn('wav_sha256=', Sha256Bytes(LWav));
    WriteLn('source_file=', LSourcePath);
    WriteLn('seed=', LSeed);
    WriteLn('events=', LSequence.NoteCount);
    WriteLn('frames=', LClip.FrameCount);
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
      WriteLn('status=STOP reason=', E.Message);
      ExitCode := 1;
    end;
  end;
end.
