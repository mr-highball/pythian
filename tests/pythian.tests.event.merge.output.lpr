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
program pythian_event_merge_output_test;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, fpjson, jsonparser, pythian.audio, pythian.wave,
  pythian.granular, pythian.passage, pythian.tools.files;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Verify;
var
  LDocument: TJSONData;
  LSourceRows: TJSONArray;
  LEvents: TJSONArray;
  LSources: TAudioSources;
  LPassages: TRecordedPassages;
  LMap: TPassageIndices;
  LOffsets: TPassageIndices;
  LClip: TAudioClip;
  LBytes: TAudioBytes;
  LText: String;
  LHash: String;
  LRow: TJSONObject;
  LSource: Integer;
  LStart: Integer;
  LCount: Integer;
  LTotal: Integer;
  LFade: Integer;
  LWidth: Integer;
  LIn: Boolean;
  LOut: Boolean;
  LGain: Double;
  LExpected: Single;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  if (ParamCount < 2) or (ParamCount > 33) then
  begin
    raise Exception.Create('Usage: pythian.tests.event.merge.output OUTPUT.wav SOURCE.wav [SOURCE.wav ...]');
  end;
  LDocument := nil;
  LClip := nil;
  try
    LBytes := ReadFileBytes(ParamStr(1) + '.json', 16 * 1024 * 1024);
    LText := '';
    if Length(LBytes) > 0 then
    begin
      SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
    end;
    LDocument := GetJSON(LText);
    Check(LDocument.FindPath('contract').AsString = 'pythian.event.merge.v1', 'Report contract');
    LSourceRows := TJSONArray(LDocument.FindPath('sources'));
    Check(LSourceRows.Count = ParamCount - 1, 'Source input count');
    SetLength(LSources, LSourceRows.Count);
    SetLength(LMap, 32);
    for I := 0 to High(LMap) do
    begin
      LMap[I] := -1;
    end;
    for I := 0 to High(LSources) do
    begin
      LSources[I] := LoadWaveSource(ParamStr(I + 2), LHash);
      LRow := LSourceRows.Objects[I];
      LSource := LRow.Integers['source_index'];
      Check((LSource >= 0) and (LSource < Length(LMap)), 'Source index bounds');
      Check(LMap[LSource] = -1, 'Unique source identity');
      LMap[LSource] := I;
      Check((LRow.Strings['sha256'] = LHash) and
        (LRow.Integers['frame_count'] = LSources[I].FrameCount), 'Exact source binding');
      Check((LSources[I].SampleRate = LDocument.FindPath('sample_rate').AsInteger) and
        (LSources[I].Channels = LDocument.FindPath('channels').AsInteger), 'Source format');
    end;
    LClip := LoadWaveSource(ParamStr(1), LHash);
    Check(LHash = LDocument.FindPath('output_sha256').AsString, 'Output hash');
    Check((LClip.SampleRate = LSources[0].SampleRate) and
      (LClip.Channels = LSources[0].Channels), 'Output format');
    LEvents := TJSONArray(LDocument.FindPath('events'));
    Check((LEvents.Count >= 1) and (LEvents.Count <= 1024), 'Event count');
    SetLength(LPassages, LEvents.Count);
    SetLength(LOffsets, LEvents.Count);
    LTotal := 0;
    for I := 0 to LEvents.Count - 1 do
    begin
      LRow := LEvents.Objects[I];
      LSource := LRow.Integers['source_index'];
      Check((LSource >= 0) and (LSource < Length(LMap)), 'Event source index');
      LSource := LMap[LSource];
      Check(LSource >= 0, 'Event uses an admitted source');
      LStart := LRow.Integers['source_start_frame'];
      LCount := LRow.Integers['frame_count'];
      Check((LStart >= 0) and (LCount > 0) and
        (LStart <= LSources[LSource].FrameCount) and
        (LCount <= LSources[LSource].FrameCount - LStart), 'Event source extent');
      Check((LRow.Integers['output_start_frame'] = LTotal) and
        (LCount <= LClip.FrameCount - LTotal), 'Output coordinates');
      LOffsets[I] := LTotal;
      Inc(LTotal, LCount);
      LPassages[I].SourceIndex := LSource;
      LPassages[I].StartFrame := LStart;
      LPassages[I].FrameCount := LCount;
    end;
    Check((LTotal = LClip.FrameCount) and
      (LTotal = LDocument.FindPath('output_frames').AsInteger), 'Exact output extent');
    LFade := LDocument.FindPath('fade_frames').AsInteger;
    Check(LFade = Max(1, LClip.SampleRate div 1000), 'Declared edge fade');
    for I := 0 to High(LPassages) do
    begin
      LSource := LPassages[I].SourceIndex;
      LStart := LPassages[I].StartFrame;
      LCount := LPassages[I].FrameCount;
      LWidth := Min(LFade, Max(1, LCount div 2));
      LIn := I = 0;
      if I > 0 then
      begin
        LIn := (LSource <> LPassages[I - 1].SourceIndex) or
          (LStart <> LPassages[I - 1].StartFrame + LPassages[I - 1].FrameCount);
      end;
      LOut := I = High(LPassages);
      if I < High(LPassages) then
      begin
        LOut := (LSource <> LPassages[I + 1].SourceIndex) or
          (LStart + LCount <> LPassages[I + 1].StartFrame);
      end;
      for J := 0 to LCount - 1 do
      begin
        LGain := 1;
        if LIn then
        begin
          LGain := Min(LGain, J / LWidth);
        end;
        if LOut then
        begin
          LGain := Min(LGain, (LCount - 1 - J) / LWidth);
        end;
        for K := 0 to LClip.Channels - 1 do
        begin
          LExpected := LSources[LSource].SampleAt(LStart + J, K) * LGain;
          LExpected := Min(1, Max(-1, LExpected));
          Check(Abs(LClip.SampleAt(LOffsets[I] + J, K) - LExpected) <= 0.502 / 32768,
            'Source sample plus independent gain differs from output PCM');
        end;
      end;
    end;
    WriteLn('Event merge output: exact source identities and all ', LClip.FrameCount,
      ' frames verified against source samples and independent fade calculation');
  finally
    LClip.Free;
    LDocument.Free;
    for I := 0 to High(LSources) do
    begin
      LSources[I].Free;
    end;
  end;
end;

begin
  try
    Verify;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
