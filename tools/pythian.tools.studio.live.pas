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
unit pythian.tools.studio.live;

{$mode delphi}
{$H+}

interface

uses
  fpjson, pythian.audio;

const
  StudioLiveLeaseMs = 90000;
  StudioLiveChunkFrames = 65536;
  StudioLiveStateFile = 'live-state.json';
  StudioLiveCommandFile = 'live-command.json';
  StudioLiveLeaseFile = 'live-client.json';
  StudioLiveExcerptFile = 'live-excerpt-request.json';

{ One live job, one sequential consumer. These bounded checkpoints are separate
  from immutable job events. No source reads or synthesis run on HTTP threads. }
function ReadStudioLiveState(const ACatalogRoot, AJobId: String): TJSONObject;
function RequestStudioLive(const ACatalogRoot: String; const ARequest: TJSONObject): TJSONObject;
function ReadStudioLiveAudio(const ACatalogRoot, AJobId: String;
  const ASequence: Int64): String;
function StudioLiveClientActive(const ADirectory: String; const AStarted: QWord): Boolean;
procedure PublishStudioLiveChunk(const ADirectory: String; const AState: TJSONObject;
  const ASamples: TAudioSamples);

implementation

uses
  Classes, SysUtils, pythian.wave.stream, pythian.tools.studio.jobs;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

function ChunkPath(const ADirectory: String; const ASequence: Int64): String;
begin
  Need(ASequence >= 0, 'Live chunk sequence is invalid');
  Result := ADirectory + PathDelim + 'live-chunk-' + IntToStr(ASequence mod 2) + '.wav';
end;

function LiveJob(const ACatalogRoot, AJobId: String): TJSONObject;
begin
  Result := ReadStudioJob(ACatalogRoot, AJobId);
  if Result.Strings['kind'] <> 'stream_generate' then
  begin
    Result.Free;
    raise EAudio.Create('Choose a live generation session');
  end;
end;

procedure TouchClient(const ADirectory: String);
var
  LTouch: TJSONObject;
begin
  LTouch := TJSONObject.Create;
  try
    LTouch.Add('tick_ms', Int64(GetTickCount64));
    ReplaceStudioJSON(ADirectory + PathDelim + StudioLiveLeaseFile, LTouch);
  finally
    LTouch.Free;
  end;
end;

function StudioLiveClientActive(const ADirectory: String; const AStarted: QWord): Boolean;
var
  LTouch: TJSONObject;
  LTick, LNow: QWord;
begin
  LTick := AStarted;
  if FileExists(ADirectory + PathDelim + StudioLiveLeaseFile) then
  begin
    LTouch := ReadStudioJSON(ADirectory + PathDelim + StudioLiveLeaseFile);
    try
      Need(LTouch.Int64s['tick_ms'] >= 0, 'Live client clock is invalid');
      LTick := LTouch.Int64s['tick_ms'];
    finally
      LTouch.Free;
    end;
  end;
  LNow := GetTickCount64;
  Result := (LNow >= LTick) and (LNow - LTick <= StudioLiveLeaseMs);
end;

function ReadStudioLiveState(const ACatalogRoot, AJobId: String): TJSONObject;
var
  LJob: TJSONObject;
  LDirectory: String;
begin
  LJob := LiveJob(ACatalogRoot, AJobId);
  try
    LDirectory := StudioJobDirectory(ACatalogRoot, AJobId);
    if (LJob.Strings['status'] = 'running') or (LJob.Strings['status'] = 'queued') then
      TouchClient(LDirectory);
    if FileExists(LDirectory + PathDelim + StudioLiveStateFile) then
      Result := ReadStudioJSON(LDirectory + PathDelim + StudioLiveStateFile)
    else
    begin
      Result := TJSONObject.Create;
      Result.Add('sequence', -1);
      Result.Add('position', Int64(0));
    end;
    Result.Add('job_id', AJobId);
    Result.Add('job_status', LJob.Strings['status']);
    Result.Add('stage', LJob.Strings['stage']);
    Result.Add('error_code', LJob.Strings['error_code']);
    Result.Add('error_message', LJob.Strings['error_message']);
    if LJob.Find('results') <> nil then Result.Add('results', LJob.Find('results').Clone);
  finally
    LJob.Free;
  end;
end;

function RequestStudioLive(const ACatalogRoot: String; const ARequest: TJSONObject): TJSONObject;
var
  LDirectory, LAction: String;
  LCommand, LPrevious: TJSONObject;
  LSequence: Int64;
  LIndex: Integer;
begin
  Need(ARequest <> nil, 'Live request is missing');
  for LIndex := 0 to ARequest.Count - 1 do
    Need(Pos('|' + ARequest.Names[LIndex] + '|', '|job_id|action|sequence|') > 0,
      'Unknown live request field');
  LAction := ARequest.Get('action', '');
  Need((LAction = 'pull') or (LAction = 'excerpt'), 'Choose pull or excerpt');
  Result := ReadStudioLiveState(ACatalogRoot, ARequest.Get('job_id', ''));
  try
    LDirectory := StudioJobDirectory(ACatalogRoot, ARequest.Strings['job_id']);
    Need(Result.Find('total_frames') <> nil, 'Session is still preparing');
    if LAction = 'excerpt' then
    begin
      Need((Result.Strings['job_status'] = 'running') and
        (Result.Int64s['position'] < Result.Int64s['total_frames']),
        'Start a new session to save an excerpt');
      if not FileExists(LDirectory + PathDelim + StudioLiveExcerptFile) then
        WriteStudioJSONNew(LDirectory + PathDelim + StudioLiveExcerptFile, ARequest);
      Exit;
    end;
    Need((ARequest.Find('sequence') <> nil) and
      (ARequest.Find('sequence').JSONType = jtNumber) and
      (ARequest.Floats['sequence'] = ARequest.Int64s['sequence']) and
      (ARequest.Int64s['sequence'] >= 0) and (ARequest.Int64s['sequence'] <= High(Integer)),
      'Live chunk sequence is invalid');
    LSequence := ARequest.Int64s['sequence'];
    if LSequence = Result.Int64s['sequence'] then Exit;
    Need((LSequence = Result.Int64s['sequence'] + 1) and
      (Result.Strings['job_status'] = 'running') and
      (Result.Int64s['position'] < Result.Int64s['total_frames']),
      'Live sequence is unavailable; restart playback');
    if FileExists(LDirectory + PathDelim + StudioLiveCommandFile) then
    begin
      LPrevious := ReadStudioJSON(LDirectory + PathDelim + StudioLiveCommandFile);
      try
        Need(LPrevious.Int64s['sequence'] <= LSequence, 'Another consumer advanced this session');
      finally
        LPrevious.Free;
      end;
    end;
    LCommand := TJSONObject.Create;
    try
      LCommand.Add('sequence', LSequence);
      ReplaceStudioJSON(LDirectory + PathDelim + StudioLiveCommandFile, LCommand);
    finally
      LCommand.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure PublishStudioLiveChunk(const ADirectory: String; const AState: TJSONObject;
  const ASamples: TAudioSamples);
var
  LMemory: TMemoryStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LBytes: TAudioBytes;
  LChannels: Integer;
begin
  LChannels := AState.Integers['channels'];
  Need((LChannels in [1, 2]) and (Length(ASamples) > 0) and
    (Length(ASamples) mod LChannels = 0) and
    (Length(ASamples) div LChannels <= StudioLiveChunkFrames), 'Live PCM chunk exceeds its bound');
  LMemory := TMemoryStream.Create;
  LSink := nil;
  LWriter := nil;
  try
    LSink := TStreamAudioSink.Create(LMemory);
    LWriter := TWavePcm16Writer.Create(LSink, AState.Integers['sample_rate'],
      LChannels, Length(ASamples) div LChannels);
    LWriter.AppendSamples(ASamples);
    LWriter.Finish;
    SetLength(LBytes, LMemory.Size);
    Move(LMemory.Memory^, LBytes[0], Length(LBytes));
    ReplaceStudioBinary(ChunkPath(ADirectory, AState.Int64s['sequence']), LBytes);
    ReplaceStudioJSON(ADirectory + PathDelim + StudioLiveStateFile, AState);
  finally
    LWriter.Free;
    LSink.Free;
    LMemory.Free;
  end;
end;

function ReadStudioLiveAudio(const ACatalogRoot, AJobId: String;
  const ASequence: Int64): String;
var
  LState: TJSONObject;
  LStream: TFileStream;
begin
  LState := ReadStudioLiveState(ACatalogRoot, AJobId);
  try
    Need((LState.Int64s['sequence'] = ASequence) and (ASequence >= 0),
      'This live chunk has expired; restart playback');
    LStream := OpenStudioReadStream(ChunkPath(StudioJobDirectory(ACatalogRoot, AJobId), ASequence));
    try
      Need((LStream.Size > 44) and (LStream.Size <= StudioLiveChunkFrames * 4 + 128),
        'Live audio exceeds its transport bound');
      SetLength(Result, LStream.Size);
      LStream.ReadBuffer(Result[1], Length(Result));
    finally
      LStream.Free;
    end;
  finally
    LState.Free;
  end;
end;

end.
