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
program pythian_tests_wfc_corpus;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.analysis,
  pythian.progress,
  pythian.hash,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.learning,
  pythian.granular,
  pythian.wave,
  pythian.wfc.learning,
  pythian.wfc.corpus,
  pythian.wfc.generation,
  pythian.tests.corpus.fixture,
  wfc,
  wfc_sequence,
  wfc_sequence_text;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

type
  EObserverAbort = class(Exception);
  TCorpusObserver = class
    AbortStage: String;
    RaisedObject: Exception;
    procedure Observe(const AWork: TWorkProgress);
  end;

procedure TCorpusObserver.Observe(const AWork: TWorkProgress);
begin
  if (AWork.Stage = AbortStage) and (AWork.Done > 0) and
    (AWork.Total > 0) and (AWork.Done < AWork.Total) then
  begin
    RaisedObject := EObserverAbort.Create('observer identity');
    raise RaisedObject;
  end;
end;

procedure CheckObservedAdapter(const ACorpus: TAcousticCorpusData;
  const AStage: String);
var
  LProbe: TCorpusObserver;
  LBytes: TAudioBytes;
  LObserved: TAudioBytes;
  LLoaded: TAcousticCorpusData;
  LModel: TWfcSequenceModel;
  LHash: String;
  LMode: Integer;
  LRejected: Boolean;
begin
  LProbe := TCorpusObserver.Create;
  try
    LBytes := EncodeWfcAcousticCorpus(ACorpus, 4);
    LHash := Sha256Bytes(LBytes);
    LObserved := EncodeWfcAcousticCorpus(ACorpus, 4, LProbe.Observe);
    Check((Length(LBytes) = Length(LObserved)) and
      (CompareByte(LBytes[0], LObserved[0], Length(LBytes)) = 0),
      'Observed adapter retains complete archive bytes');
    for LMode := 0 to 1 do
    begin
      LProbe.AbortStage := AStage;
      LModel := nil;
      LRejected := False;
      try
        if LMode = 0 then
        begin
          LObserved := EncodeWfcAcousticCorpus(ACorpus, 4, LProbe.Observe);
        end
        else
        begin
          LLoaded := DecodeWfcAcousticCorpus(LBytes, LModel, LProbe.Observe);
          LModel.Free;
          LLoaded.Free;
        end;
      except
        on LException: EObserverAbort do
        begin
          LRejected := LException = LProbe.RaisedObject;
        end;
      end;
      Check(LRejected and (LModel = nil) and (Sha256Bytes(LBytes) = LHash),
        'Adapter abort preserves exception, nil model and archive bytes');
      LProbe.AbortStage := '';
      LObserved := EncodeWfcAcousticCorpus(ACorpus, 4, LProbe.Observe);
      Check((Length(LBytes) = Length(LObserved)) and
        (CompareByte(LBytes[0], LObserved[0], Length(LBytes)) = 0),
        'Observed encode retry retains complete archive bytes');
      LLoaded := DecodeWfcAcousticCorpus(LBytes, LModel, LProbe.Observe);
      try
        Check((LLoaded.FeatureCount = ACorpus.FeatureCount) and
          (LModel.ObservationCount = ACorpus.FeatureCount), 'Adapter retry retains observations');
      finally
        LModel.Free;
        LLoaded.Free;
      end;
    end;
  finally
    LProbe.Free;
  end;
end;

procedure CheckObservedTokens;
var
  LOptions: TAnalysisOptions;
  LCenters: TAcousticVectors;
  LRecords: TAcousticRecordings;
  LCorpus: TAcousticCorpusData;
  LIndex: Integer;
begin
  LOptions := DefaultAnalysisOptions;
  LOptions.WindowFrames := 64;
  LOptions.HopFrames := 32;
  SetLength(LCenters, 1);
  SetLength(LRecords, 1);
  LRecords[0].Info.Name := 'authored-silence';
  LRecords[0].Info.Sha256 := StringOfChar('a', 64);
  LRecords[0].Info.Provenance := 'Synthetic measured test fixture';
  LRecords[0].Info.SampleRate := 8000;
  LRecords[0].Info.Channels := 1;
  LRecords[0].Info.FrameCount := 16384;
  SetLength(LRecords[0].Features, 512);
  SetLength(LRecords[0].Tokens, 512);
  for LIndex := 0 to 511 do
  begin
    LRecords[0].Features[LIndex].StartFrame := LIndex * 32;
    LRecords[0].Features[LIndex].ValidFrames := 64;
    if LIndex = 511 then
    begin
      LRecords[0].Features[LIndex].ValidFrames := 32;
    end;
    LRecords[0].Features[LIndex].Silent := True;
  end;
  LCorpus := TAcousticCorpusData.Create(LOptions, LCenters, LRecords);
  try
    CheckObservedAdapter(LCorpus, 'wfc_corpus_tokens');
  finally
    LCorpus.Free;
  end;
end;

procedure Run;
var
  LCorpus: TAcousticCorpusData;
  LLoaded: TAcousticCorpusData;
  LRejectedCorpus: TAcousticCorpusData;
  LSources: TAudioSources;
  LModel: TWfcSequenceModel;
  LReloaded: TWfcSequenceModel;
  LWrongModel: TWfcSequenceModel;
  LPalette: TAcousticPalette;
  LBytes: TAudioBytes;
  LWrongBytes: TAudioBytes;
  LWave: TAudioBytes;
  LReplayWave: TAudioBytes;
  LSequences: TAcousticCorpus;
  LGeneration: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LTokens: TAcousticIndices;
  LReplay: TAcousticIndices;
  LClip: TAudioClip;
  LText: String;
  LIndex: Integer;
  LOrder: Integer;
  LRejected: Boolean;
begin
  LCorpus := CreateCorpusFixture(LSources);
  try
    CheckObservedAdapter(LCorpus, 'wfc_corpus_lookup');
    CheckObservedTokens;
    for LOrder := 1 to 4 do
    begin
      LBytes := EncodeWfcAcousticCorpus(LCorpus, LOrder);
      LLoaded := DecodeWfcAcousticCorpus(LBytes, LModel);
      try
        Check((LModel.SampleCount = 2) and (LModel.ObservationCount = 16) and
          (LModel.Order = LOrder), 'Actual WFC model preserves corpus boundaries and order');
        LGeneration := DefaultAcousticGenerationOptions;
        LGeneration.FrameCount := 8;
        Check(TryGenerateAcousticSequence(LModel, LGeneration, nil, LTokens, LReport),
          'Generate from saved WFC corpus');
        LClip := RenderGrains(LSources, LLoaded.PlanGrains(LTokens),
          DefaultGrainRenderOptions(8192, 1));
        try
          LWave := EncodeWavePcm16(LClip);
        finally
          LClip.Free;
        end;
        LRejectedCorpus := DecodeWfcAcousticCorpus(LBytes, LReloaded);
        try
          Check(TryGenerateAcousticSequence(LReloaded, LGeneration, nil, LReplay, LReport),
            'Generate again after a separate load');
          Check(Length(LReplay) = Length(LTokens), 'Reloaded token length');
          for LIndex := 0 to High(LTokens) do
          begin
            Check(LReplay[LIndex] = LTokens[LIndex], 'Exact saved-model token replay');
          end;
          LClip := RenderGrains(LSources, LRejectedCorpus.PlanGrains(LReplay),
            DefaultGrainRenderOptions(8192, 1));
          try
            LReplayWave := EncodeWavePcm16(LClip);
          finally
            LClip.Free;
          end;
          Check((Length(LWave) = Length(LReplayWave)) and
            (CompareByte(LWave[0], LReplayWave[0], Length(LWave)) = 0),
            'Exact audio replay after loading');
        finally
          LReloaded.Free;
          LRejectedCorpus.Free;
        end;
      finally
        LModel.Free;
        LLoaded.Free;
      end;
    end;
    SetLength(LSequences, 2);
    LSequences[0] := LCorpus.RecordingAt(0).Tokens;
    LSequences[1] := LCorpus.RecordingAt(1).Tokens;
    LSequences[0][0] := (LSequences[0][0] + 1) mod LCorpus.PaletteCount;
    LPalette := LCorpus.CopyPalette;
    try
      LWrongModel := LearnAcousticModel(LSequences, LPalette, 2);
      try
        LText := EncodeWfcSequenceText(LWrongModel);
        SetLength(LWrongBytes, Length(LText));
        Move(LText[1], LWrongBytes[0], Length(LText));
        LWrongBytes := EncodeAcousticArchive(LCorpus, WfcCorpusAttachmentContract, LWrongBytes);
      finally
        LWrongModel.Free;
      end;
    finally
      LPalette.Free;
    end;
    LRejected := False;
    LModel := nil;
    try
      LRejectedCorpus := DecodeWfcAcousticCorpus(LWrongBytes, LModel);
      LRejectedCorpus.Free;
      LModel.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LModel = nil),
      'Valid digest and valid WFC model do not excuse mismatched corpus observations');
  finally
    LCorpus.Free;
    ReleaseFixtureSources(LSources);
  end;
end;

begin
  try
    Run;
    WriteLn('Persisted WFC corpus validation and audio replay checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
