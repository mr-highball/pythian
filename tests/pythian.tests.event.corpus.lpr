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
program pythian_event_corpus_test;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.corpus, pythian.granular, pythian.passage,
  pythian.wfc.event.corpus, pythian.tests.corpus.fixture,
  wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_text;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Run;
const
  CGains: array[0..10] of Double = (0, 1, 1, 1, 1, 0.5, 0, 0, 0.5, 0.5, 0);
var
  LCorpus: TAcousticCorpusData;
  LSources: TAudioSources;
  LInputs: TRecordedEventInputs;
  LLearning: TRecordedEventLearning;
  LManual: TWfcSequenceModel;
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LSelection: TPassageIndices;
  LPassages: TRecordedPassages;
  LClip: TAudioClip;
  LExpected: Single;
  LRejected: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LLearning := nil;
  LManual := nil;
  LClip := nil;
  LCorpus := CreateCorpusFixture(LSources);
  try
    SetLength(LInputs, 2);
    for I := 0 to 1 do
    begin
      LInputs[I].SourceIndex := I;
      SetLength(LInputs[I].Bounds, 9);
      SetLength(LInputs[I].RunIndices, 8);
      SetLength(LInputs[I].StartsAtOnset, 8);
      for J := 0 to 8 do
      begin
        LInputs[I].Bounds[J] := J * 32;
        if J < 8 then
        begin
          LInputs[I].StartsAtOnset[J] := J > 0;
        end;
      end;
    end;
    LInputs[0].RunIndices[2] := -1;
    for I := 3 to 7 do
    begin
      LInputs[0].RunIndices[I] := 1;
    end;
    LLearning := TRecordedEventLearning.Create(LCorpus, LInputs, 16, 4, 2);
    Check((LLearning.MemberCount = 15) and (LLearning.RunCount = 3),
      'Excluded interval omitted and both song/run boundaries retained');
    Check((LLearning.MemberAt(2).IntervalIndex = 3) and
      (LLearning.MemberAt(2).RunIndex = 1) and
      (LLearning.MemberAt(7).Passage.SourceIndex = 1) and
      (LLearning.MemberAt(7).RunIndex = 2), 'Detached source coordinates');
    SetLength(LSamples, 3);
    for I := 0 to 2 do
    begin
      if I = 0 then
      begin
        K := 2;
      end
      else if I = 1 then
      begin
        K := 5;
      end
      else
      begin
        K := 8;
      end;
      SetLength(LTokens, K);
      for J := 0 to K - 1 do
      begin
        if I = 0 then
        begin
          LTokens[J] := LLearning.MemberAt(J).Token;
        end
        else if I = 1 then
        begin
          LTokens[J] := LLearning.MemberAt(J + 2).Token;
        end
        else
        begin
          LTokens[J] := LLearning.MemberAt(J + 7).Token;
        end;
      end;
      LSamples[I] := MakeWfcSequenceSample(LTokens);
    end;
    LManual := LearnSequenceModelCorpus(LSamples, 2, wmbOpen);
    Check(EncodeWfcSequenceText(LManual) = EncodeWfcSequenceText(LLearning.Model),
      'Complete model bytes equal three independent manual samples');
    LTokens[0] := LLearning.MemberAt(0).Token;
    SetLength(LTokens, 1);
    LSelection := LLearning.SelectMembers(LTokens, 731);
    Check(LLearning.MemberAt(LSelection[0]).Token = LTokens[0], 'Matching reconstruction member');
    LRejected := False;
    LInputs[1].SourceIndex := 0;
    try
      TRecordedEventLearning.Create(LCorpus, LInputs, 16).Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Duplicate recording rejects without implicit weighting');
    LInputs[1].SourceIndex := 1;
    LInputs[0].RunIndices[3] := 0;
    LRejected := False;
    try
      TRecordedEventLearning.Create(LCorpus, LInputs, 16).Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Resuming a run across an excluded gap rejects');
    FreeAndNil(LCorpus);
    LInputs := nil;
    Check(LLearning.SourceInfoAt(1).FrameCount = 256, 'Learning survives source metadata release');

    SetLength(LPassages, 3);
    LPassages[0].StartFrame := 1;
    LPassages[0].FrameCount := 3;
    LPassages[1].StartFrame := 4;
    LPassages[1].FrameCount := 4;
    LPassages[2].SourceIndex := 1;
    LPassages[2].StartFrame := 8;
    LPassages[2].FrameCount := 4;
    LClip := RenderPassages(LSources, LPassages, 2);
    Check(LClip.FrameCount = 11, 'Exact concatenated multi-source duration');
    for I := 0 to 10 do
    begin
      if I < 7 then
      begin
        LExpected := LSources[0].SampleAt(I + 1, 0) * CGains[I];
      end
      else
      begin
        LExpected := LSources[1].SampleAt(I + 1, 0) * CGains[I];
      end;
      Check(LClip.SampleAt(I, 0) = LExpected,
        'Independent PCM oracle preserves same-source join and fades source switch');
    end;
    LPassages[2].FrameCount := 1000;
    LRejected := False;
    try
      RenderPassages(LSources, LPassages, 2).Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Late invalid passage rejects');
  finally
    LClip.Free;
    LManual.Free;
    LLearning.Free;
    LCorpus.Free;
    ReleaseFixtureSources(LSources);
  end;
end;

begin
  try
    Run;
    WriteLn('Recorded event corpus: shared model, separated songs/gaps, ownership and multi-source PCM passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
