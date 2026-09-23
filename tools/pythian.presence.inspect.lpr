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
program pythian_presence_inspect;

{$mode delphi}
{$H+}

uses
  Classes, Math, SysUtils, pythian.audio, pythian.hash,
  pythian.presence, pythian.wave.read;

type
  TWavePresenceSource = class(TPresenceSource)
  strict private
    FReader: TWaveFrameReader;
  public
    constructor Create(const AReader: TWaveFrameReader);
    procedure ReadWindow(const AStartFrame: Int64; const AFrameCount: Integer;
      out ASamples: TAudioSamples); override;
  end;

constructor TWavePresenceSource.Create(const AReader: TWaveFrameReader);
begin
  if AReader = nil then
    raise EAudio.Create('Presence WAVE reader is required');
  inherited Create(AReader.SampleRate, AReader.Channels, AReader.FrameCount);
  FReader := AReader;
end;

procedure TWavePresenceSource.ReadWindow(const AStartFrame: Int64;
  const AFrameCount: Integer; out ASamples: TAudioSamples);
var
  LChunk: TAudioSamples;
  LFrames: Integer;
  LAt: Integer;
  LIndex: Integer;
begin
  SetLength(ASamples, AFrameCount * Channels);
  FReader.SeekFrame(AStartFrame);
  LAt := 0;
  while LAt < AFrameCount do
  begin
    LFrames := Min(MaximumWaveReadFrames, AFrameCount - LAt);
    LChunk := FReader.ReadFrames(LFrames);
    if Length(LChunk) <> LFrames * Channels then
      raise EAudio.Create('WAVE presence read returned a partial window');
    for LIndex := 0 to High(LChunk) do
      ASamples[LAt * Channels + LIndex] := LChunk[LIndex];
    Inc(LAt, LFrames);
  end;
end;

function EvidenceText(const AEvidence: TPresenceEvidence): String;
begin
  case AEvidence of
    peExactZero: Result := 'exact_zero';
    peAboveReviewedRest: Result := 'above_reviewed_rest';
    peCompatibleWithReviewedRest:
      Result := 'compatible_with_reviewed_rest';
  else
    Result := 'unknown';
  end;
end;

procedure Run;
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LSource: TWavePresenceSource;
  LExpectedHash: String;
  LActualHash: String;
  LReferenceId: String;
  LReviewed: Boolean;
  LObservation: TPresenceObservation;
  LFormat: TFormatSettings;
begin
  if ParamCount <> 8 then
    raise EAudio.Create('Usage: pythian.presence.inspect WAV SHA256 ' +
      'START_FRAME FRAME_COUNT REST_START REST_COUNT REST_ID reviewed|unreviewed');
  LExpectedHash := LowerCase(ParamStr(2));
  if Length(LExpectedHash) <> 64 then
    raise EAudio.Create('Expected SHA256 must have 64 hex digits');
  LReferenceId := ParamStr(7);
  if (Pos(#9, LReferenceId) > 0) or (Pos(#10, LReferenceId) > 0) or
    (Pos(#13, LReferenceId) > 0) then
    raise EAudio.Create('Reference ID must be one TSV field');
  if ParamStr(8) = 'reviewed' then
    LReviewed := True
  else if ParamStr(8) = 'unreviewed' then
    LReviewed := False
  else
    raise EAudio.Create('Reference role must be reviewed or unreviewed');
  LStream := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
  try
    LActualHash := Sha256Stream(LStream, LStream.Size);
    if LActualHash <> LExpectedHash then
      raise EAudio.Create('WAVE SHA256 differs from source binding');
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      LSource := TWavePresenceSource.Create(LReader);
      try
        LObservation := ObservePresenceSource(LSource,
          StrToInt64(ParamStr(3)), StrToInt(ParamStr(4)),
          StrToInt64(ParamStr(5)), StrToInt(ParamStr(6)),
          LReferenceId, LReviewed);
      finally
        LSource.Free;
      end;
    finally
      LReader.Free;
    end;
    LStream.Position := 0;
    if Sha256Stream(LStream, LStream.Size) <> LExpectedHash then
      raise EAudio.Create('WAVE SHA256 changed during presence observation');
  finally
    LStream.Free;
  end;
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  WriteLn('source_sha256'#9'policy_id'#9'evidence'#9 +
    'sample_rate'#9'channels'#9'source_frames'#9 +
    'start_frame'#9'frame_count'#9'rest_start_frame'#9'rest_frame_count'#9 +
    'rest_id'#9'rest_reviewed'#9'candidate_rms'#9'candidate_peak'#9 +
    'early_rms'#9'late_rms'#9'rest_rms');
  WriteLn(LActualHash, #9, LObservation.PolicyId, #9,
    EvidenceText(LObservation.Evidence), #9,
    LObservation.SampleRate, #9, LObservation.Channels, #9,
    LObservation.SourceFrameCount, #9,
    LObservation.StartFrame, #9, LObservation.FrameCount, #9,
    LObservation.ReferenceStartFrame, #9,
    LObservation.ReferenceFrameCount, #9, LObservation.ReferenceId, #9,
    Ord(LObservation.ReferenceReviewed), #9,
    FormatFloat('0.0000000000', LObservation.CandidateRms, LFormat), #9,
    FormatFloat('0.0000000000', LObservation.CandidatePeak, LFormat), #9,
    FormatFloat('0.0000000000', LObservation.EarlyRms, LFormat), #9,
    FormatFloat('0.0000000000', LObservation.LateRms, LFormat), #9,
    FormatFloat('0.0000000000', LObservation.ReferenceRms, LFormat));
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
