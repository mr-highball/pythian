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
program pythian_event_archive_test;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.granular, pythian.corpus,
  pythian.corpus.archive, pythian.learning,
  pythian.wfc.event.corpus, pythian.wfc.event.archive, pythian.tests.corpus.fixture,
  wfc_sequence_text;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Run;
var
  LCorpus: TAcousticCorpusData;
  LDecoded: TAcousticCorpusData;
  LSources: TAudioSources;
  LLearning: TRecordedEventLearning;
  LLoaded: TRecordedEventLearning;
  LBad: TRecordedEventLearning;
  LVariant: TRecordedEventLearning;
  LInputs: TRecordedEventInputs;
  LBytes: TAudioBytes;
  LAgain: TAudioBytes;
  LAttachment: TAudioBytes;
  LChanged: TAudioBytes;
  LContract: UTF8String;
  LPolicy: UTF8String;
  LCenters: TAcousticVectors;
  LMember: TRecordedEventMember;
  LRejected: Boolean;
  LOffset: Integer;
  I: Integer;
  J: Integer;

  procedure Reject(const AData: TAudioBytes);
  var
    LResult: TAcousticCorpusData;
    LOutput: TRecordedEventLearning;
    LDescription: UTF8String;
  begin
    LOutput := nil;
    LDescription := 'prior';
    LRejected := False;
    try
      LResult := DecodeRecordedEventCorpus(AData, LOutput, LDescription);
      LResult.Free;
      LOutput.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LOutput = nil) and (LDescription = ''),
      'Rejected archive clears all outputs');
  end;

begin
  LLearning := nil;
  LLoaded := nil;
  LBad := nil;
  LVariant := nil;
  LDecoded := nil;
  LCorpus := CreateCorpusFixture(LSources);
  try
    SetLength(LInputs, 2);
    for I := 0 to 1 do
    begin
      LInputs[I].SourceIndex := I;
      SetLength(LInputs[I].Bounds, 5);
      SetLength(LInputs[I].RunIndices, 4);
      SetLength(LInputs[I].StartsAtOnset, 4);
      for J := 0 to 4 do
      begin
        LInputs[I].Bounds[J] := J * 64;
        if J < 4 then
        begin
          LInputs[I].StartsAtOnset[J] := J > 0;
        end;
      end;
    end;
    LLearning := TRecordedEventLearning.Create(LCorpus, LInputs, 32, 4, 2);
    LBytes := EncodeRecordedEventCorpus(LCorpus, LLearning, 'authored intervals v1');
    LDecoded := DecodeRecordedEventCorpus(LBytes, LLoaded, LPolicy);
    Check((LPolicy = 'authored intervals v1') and (LLoaded.MemberCount = 8) and
      (LLoaded.RunCount = 2), 'Detached saved event learning');
    LCenters := LLearning.Palette.CopyCenters;
    for I := 0 to High(LCenters) do
    begin
      for J := 0 to 14 do
      begin
        Check(LCenters[I][J] = LLoaded.Palette.CenterAt(I)[J], 'Exact binary64 centers');
      end;
    end;
    Check(EncodeWfcSequenceText(LLearning.Model) = EncodeWfcSequenceText(LLoaded.Model),
      'Exact saved model semantics');
    for I := 0 to LLearning.MemberCount - 1 do
    begin
      LMember := LLoaded.MemberAt(I);
      Check((LMember.Token = LLearning.MemberAt(I).Token) and
        (LMember.Passage.SourceIndex = LLearning.MemberAt(I).Passage.SourceIndex) and
        (LMember.Passage.StartFrame = LLearning.MemberAt(I).Passage.StartFrame) and
        (LMember.Passage.FrameCount = LLearning.MemberAt(I).Passage.FrameCount) and
        (LMember.RunIndex = LLearning.MemberAt(I).RunIndex), 'Exact saved source members');
    end;
    LAgain := EncodeRecordedEventCorpus(LDecoded, LLoaded, LPolicy);
    Check((Length(LBytes) = Length(LAgain)) and
      CompareMem(@LBytes[0], @LAgain[0], Length(LBytes)), 'Canonical whole archive replay');
    LInputs := LLoaded.CopyInputs;
    LInputs[0].Bounds[1] := 1;
    Check(LLoaded.CopyInputs[0].Bounds[1] = 64, 'Detached loaded inputs');
    Reject(Copy(LBytes, 0, Length(LBytes) - 1));
    FreeAndNil(LDecoded);
    LDecoded := DecodeAcousticArchive(LBytes, LContract, LAttachment);
    { Six header integers, policy length/text, exact centers, then first input's
      source/count/first-bound. Each interval stores end, run+1 and onset flag. }
    LOffset := 28 + Length(LPolicy) + Length(LCenters) * 120 + 12;
    LChanged := Copy(LAttachment);
    LChanged[LOffset + 8] := 2;
    Reject(EncodeAcousticArchive(LDecoded, LContract, LChanged));
    LChanged := Copy(LAttachment);
    LChanged[LOffset + 8] := 1;
    Reject(EncodeAcousticArchive(LDecoded, LContract, LChanged));
    LChanged := Copy(LAttachment);
    LChanged[LOffset + 4] := 0;
    Reject(EncodeAcousticArchive(LDecoded, LContract, LChanged));
    SetLength(LChanged, Length(LAttachment) + 1);
    Move(LAttachment[0], LChanged[0], Length(LAttachment));
    Reject(EncodeAcousticArchive(LDecoded, LContract, LChanged));
    LInputs := LLearning.CopyInputs;
    LInputs[0].StartsAtOnset[0] := True;
    LBad := TRecordedEventLearning.Create(LCorpus, LInputs, 32, 4, 2);
    LRejected := False;
    try
      TRecordedEventLearning.CreateFromModel(LCorpus, LLearning.CopyInputs, 32,
        LCenters, LBad.Model).Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Structurally valid model with different observations is rejected');
    FreeAndNil(LBad);
    FreeAndNil(LDecoded);
    for I := 1 to 4 do
    begin
      if I = 2 then
      begin
        Continue;
      end;
      LBad := TRecordedEventLearning.Create(LCorpus, LLearning.CopyInputs, 32, 4, I);
      LBytes := EncodeRecordedEventCorpus(LCorpus, LBad, LPolicy);
      LDecoded := DecodeRecordedEventCorpus(LBytes, LVariant, LPolicy);
      Check((LVariant.Model.Order = I) and
        (EncodeWfcSequenceText(LBad.Model) = EncodeWfcSequenceText(LVariant.Model)),
        'Admission covers all supported history orders');
      FreeAndNil(LVariant);
      FreeAndNil(LDecoded);
      FreeAndNil(LBad);
    end;
    FreeAndNil(LCorpus);
    FreeAndNil(LDecoded);
    FreeAndNil(LLearning);
    Check(LLoaded.MemberAt(7).Passage.StartFrame = 192, 'Loaded learning has independent lifetime');
  finally
    LVariant.Free;
    LBad.Free;
    LLoaded.Free;
    LLearning.Free;
    LDecoded.Free;
    LCorpus.Free;
    ReleaseFixtureSources(LSources);
  end;
end;

begin
  try
    Run;
    WriteLn('Recorded event archive: exact centers/model/members, semantic admission, corruption and ownership passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
