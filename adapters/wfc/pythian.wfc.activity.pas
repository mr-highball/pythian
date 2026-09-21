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
unit pythian.wfc.activity;

{$mode delphi}
{$H+}

interface

uses
  pythian.activity,
  pythian.corpus,
  wfc_music_sequence,
  wfc_sequence;

{ Explicit activity projection onto WFC's real rest/attack/hold contract.
  One cell is one analysis hop in samples; no beat grid is inferred. }
function ProjectAcousticRhythm(const AActions: TAcousticActions): TWfcMusicRhythmCells;
function LearnAcousticRhythmModel(const ACorpus: TAcousticCorpusData;
  const AOptions: TActivityOptions; const AOrder: Integer = 2): TWfcSequenceModel;

implementation

uses
  pythian.audio,
  pythian.analysis,
  wfc_model,
  wfc_sequence_learn;

function ProjectAcousticRhythm(const AActions: TAcousticActions): TWfcMusicRhythmCells;
var
  LIndex: Integer;
begin
  if Length(AActions) > MaximumAnalysisFrames then
  begin
    raise EAudio.Create('Acoustic rhythm projection exceeds feature budget');
  end;
  Result := nil;
  SetLength(Result, Length(AActions));
  for LIndex := 0 to High(AActions) do
  begin
    case AActions[LIndex] of
      aaSilence:
      begin
        Result[LIndex] := MakeWfcMusicRhythmCell(wmcaRest);
      end;
      aaOnset:
      begin
        Result[LIndex] := MakeWfcMusicRhythmCell(wmcaAttack);
      end;
      aaSustain:
      begin
        Result[LIndex] := MakeWfcMusicRhythmCell(wmcaHold);
      end;
    end;
  end;
end;

function LearnAcousticRhythmModel(const ACorpus: TAcousticCorpusData;
  const AOptions: TActivityOptions; const AOrder: Integer): TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
  LRecording: TAcousticRecording;
  LActivity: TAcousticActivity;
  LIndex: Integer;
begin
  if (ACorpus = nil) or (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Acoustic rhythm learning requires a corpus and order 1..4');
  end;
  ValidateActivityOptions(AOptions);
  SetLength(LSamples, ACorpus.SourceCount);
  for LIndex := 0 to High(LSamples) do
  begin
    LRecording := ACorpus.RecordingAt(LIndex);
    LActivity := AnalyzeAcousticActivity(LRecording.Features, ACorpus.Options,
      LRecording.Info.FrameCount, AOptions);
    LSamples[LIndex] := MakeWfcSequenceSample(
      EncodeWfcMusicRhythmCells(ProjectAcousticRhythm(LActivity.Actions)));
  end;
  Result := LearnSequenceModelCorpus(LSamples, AOrder, wmbOpen);
end;

end.
