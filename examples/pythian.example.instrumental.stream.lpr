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
program InstrumentalStreamingCaller;
{$mode delphi}
{$H+}
uses Classes, SysUtils, fpjson, pythian.audio, pythian.bus, pythian.echo,
  pythian.music.pattern, pythian.pitch.track, pythian.wave.stream,
  pythian.wfc.instrumental, pythian.wfc.instrumental.starter,
  pythian.wfc.instrumental.stream, pythian.wfc.percussion,
  wfc_sequence, wfc_sequence_text, wfc_music_voices_graph;

procedure SaveDocument(const APath: String; const ADocument: TJSONObject);
var
  LText: TStringStream;
begin
  LText := TStringStream.Create(ADocument.AsJSON);
  try LText.SaveToFile(APath) finally LText.Free end;
end;

procedure Run;
const
  CRate = 24000;
var
  LStarter: TInstrumentalStarter;
  LPattern: TPitchPattern;
  LConfig: TWfcMusicVoicesGraphConfig;
  LRoles: TInstrumentalRoles;
  LDrums: TPercussionDefinitions;
  LOptions: TInstrumentalStreamOptions;
  LSettings: array[0..6] of TBusSettings;
  LEcho: TEchoSettings;
  LGraph: TBusGraph;
  LStream: TInstrumentalMusicStream;
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LDocument, LRow: TJSONObject;
  LModels: TJSONArray;
  LOutput: String;
  LSeconds, LBpm, I, LLastReported: Integer;
  LSeed: Cardinal;
begin
  if (ParamCount < 1) or (ParamCount > 4) then
    raise EAudio.Create('Usage: instrumental.stream OUTPUT.wav [SECONDS [SEED [BPM]]]');
  LOutput := ExpandFileName(ParamStr(1));
  LSeconds := 120;
  LSeed := 731;
  LBpm := 120;
  if ParamCount >= 2 then LSeconds := StrToInt(ParamStr(2));
  if ParamCount >= 3 then LSeed := StrToDWord(ParamStr(3));
  if ParamCount >= 4 then LBpm := StrToInt(ParamStr(4));
  if (LSeconds < 1) or (LSeconds > 86400) or (LBpm < 40) or (LBpm > 240) then
    raise EAudio.Create('Use1..86400 seconds and40..240 BPM');
  if FileExists(LOutput) or FileExists(LOutput + '.json') then
    raise EAudio.Create('Use a fresh output and replay document path');
  LPattern := nil;
  SetLength(LPattern, 8);
  for I := 0 to High(LPattern) do
  begin
    LPattern[I] := Default(TPitchPatternCell);
    LPattern[I].Kind := pskPitch;
    LPattern[I].Note := 72 + (I div 2) * 2;
    LPattern[I].Velocity := 80;
    LPattern[I].Attack := I mod 2 = 0;
  end;
  LStarter := TInstrumentalStarter.Create(0, False, LPattern);
  LGraph := nil;
  LStream := nil;
  LFile := nil;
  LSink := nil;
  LWriter := nil;
  LDocument := TJSONObject.Create;
  try
    LConfig := LStarter.Config;
    LRoles := LStarter.CopyRoles;
    LDrums := LStarter.CopyPercussion(CRate);
    for I := 0 to 6 do
    begin
      LSettings[I] := DefaultBusSettings;
      LSettings[I].SmoothingSeconds := 0;
    end;
    LGraph := TBusGraph.Create(CRate, LSettings);
    for I := 0 to 5 do LGraph.AddSend(I, 6, stPostFader, 1, 0);
    LEcho := DefaultEchoSettings(CRate);
    LGraph.AddEffect(1, TEchoEffect.Create(CRate, LEcho));
    LOptions := DefaultInstrumentalStreamOptions(Int64(CRate) * LSeconds);
    LOptions.TailFrames := CRate;
    LOptions.TempoMicroseconds := Round(60000000 / LBpm);
    LOptions.Seed := LSeed;
    LStream := TInstrumentalMusicStream.Create(LConfig, LRoles, LDrums, LGraph,
      LOptions, LStarter.ContextModel);
    LDocument.Add('format', 'pythian.instrumental.stream.example.v1');
    LDocument.Add('runtime_version', InstrumentalStreamVersion);
    LDocument.Add('status', 'requested');
    LDocument.Add('origin', 'Explicit authored symbolic example, not recording-derived learning');
    LDocument.Add('context_binding', 'all_roles');
    LDocument.Add('seed', Int64(LSeed));
    LDocument.Add('sample_rate', CRate);
    LDocument.Add('channels', 2);
    LDocument.Add('music_frames', LOptions.MusicFrames);
    LDocument.Add('tail_frames', LOptions.TailFrames);
    LDocument.Add('frame_count', LStream.FrameCount);
    LDocument.Add('ticks_per_quarter', LOptions.TicksPerQuarter);
    LDocument.Add('step_ticks', LOptions.StepTicks);
    LDocument.Add('tempo_microseconds', LOptions.TempoMicroseconds);
    LDocument.Add('lookahead_cells', LOptions.SegmentCells);
    LDocument.Add('total_cells', LStream.TotalCells);
    LDocument.Add('voice_limit', LOptions.VoiceLimit);
    LDocument.Add('work_limit', LOptions.WorkLimit);
    LDocument.Add('max_backtracks', LOptions.MaxBacktracks);
    LDocument.Add('max_pass_backtracks', LOptions.MaxPassBacktracks);
    LDocument.Add('output', 'StereoPCM16; primary RIFF/RF64 writer');
    LDocument.Add('graph', 'Context sequence; joint harmony/rhythm/three voices/coverage; three rhythm-conditioned drum sequences');
    LModels := TJSONArray.Create;
    LDocument.Add('models', LModels);
    for I := 0 to WfcMusicVoicesModelCount(LConfig) - 1 do
    begin
      LRow := TJSONObject.Create;
      LModels.Add(LRow);
      LRow.Add('name', WfcMusicVoicesPassLabel(I));
      LRow.Add('model', EncodeWfcSequenceText(WfcMusicVoicesModelAt(LConfig, I)));
    end;
    LModels.Add(TJSONObject.Create(['name', 'musical-context',
      'model', EncodeWfcSequenceText(LStarter.ContextModel)]));
    for I := 0 to High(LDrums) do
      LModels.Add(TJSONObject.Create(['name', LDrums[I].Name,
        'hit_weight', LDrums[I].HitWeight,
        'model', EncodeWfcSequenceText(LDrums[I].Model)]));
    SaveDocument(LOutput + '.json', LDocument);
    LFile := TFileStream.Create(LOutput, fmCreate);
    LSink := TStreamAudioSink.Create(LFile);
    LWriter := TWavePcm16Writer.Create(LSink, CRate, 2, LStream.FrameCount);
    LLastReported := -1;
    while LStream.ReadSamples(2048, LSamples) do
    begin
      LWriter.AppendSamples(LSamples);
      if LStream.Position div (CRate * 10) <> LLastReported then
      begin
        LLastReported := LStream.Position div (CRate * 10);
        WriteLn(LStream.Position div CRate, '/', LSeconds + 1, ' seconds; ',
          LStream.PlannedSegments, ' planned windows; ', LStream.PeakVoices, ' peak voices');
      end;
    end;
    LWriter.Finish;
    LDocument.Add('completed_frames', LStream.Position);
    LDocument.Add('planned_segments', LStream.PlannedSegments);
    LDocument.Add('peak_voices', LStream.PeakVoices);
    LDocument.Add('percussion_hits', LStream.PercussionHits);
    LDocument.Strings['status'] := 'completed';
    SaveDocument(LOutput + '.json', LDocument);
    WriteLn('Saved ', LOutput);
  finally
    LWriter.Free;
    LSink.Free;
    LFile.Free;
    LStream.Free;
    LGraph.Free;
    LStarter.Free;
    LDocument.Free;
  end;
end;
begin
  try Run except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
