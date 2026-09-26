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
unit pythian.wfc.joint;

{$mode delphi}
{$H+}

interface

uses
  pythian.activity,
  pythian.corpus,
  pythian.learning,
  pythian.wfc.generation,
  wfc,
  wfc_model,
  wfc_sequence;

const
  JointAcousticVersion = 1;

type
  TJointActions = set of TAcousticAction;
  TJointConstraint = record
    Position: Integer;
    AcousticToken: Integer; { -1 means any acoustic token. }
    AllowedActions: TJointActions; { Empty means an impossible constraint. }
  end;
  TJointConstraints = array of TJointConstraint;
  TJointSequence = record
    Tokens: TAcousticIndices;
    Actions: TAcousticActions;
  end;

function JointAcousticToken(const AToken: Integer;
  const AAction: TAcousticAction): TWfcModelToken;
procedure DecodeJointAcousticToken(const AToken: TWfcModelToken;
  out AIndex: Integer; out AAction: TAcousticAction);
function LearnJointAcousticModel(const ACorpus: TAcousticCorpusData;
  const AActivity: TActivityOptions; const AOrder: Integer = 2): TWfcSequenceModel;
{ Detached actual WFC domains for one bounded chunk; positions are chunk-local. }
function JointTokenConstraints(const AModel: TWfcSequenceModel;
  const AConstraints: TJointConstraints): TWfcSequenceTokenConstraints;
{ Real WFC constraints operate on paired acoustic/activity observations.
  Failure preserves both output arrays; solver report retains failure status. }
function TryGenerateJointSequence(const AModel: TWfcSequenceModel;
  const AOptions: TAcousticGenerationOptions; const AConstraints: TJointConstraints;
  var ASequence: TJointSequence; out AReport: TGraphSolveReport): Boolean;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.wfc.activity,
  wfc_music_sequence,
  wfc_sequence_learn;

const
  JointPrefix = 'pythian.joint.v1.';

function JointAcousticToken(const AToken: Integer;
  const AAction: TAcousticAction): TWfcModelToken;
var
  LActions: TAcousticActions;
begin
  if (AToken < 0) or (AToken >= MaximumAcousticVocabulary) or
    not (AAction in [aaSilence, aaOnset, aaSustain]) then
  begin
    raise EAudio.Create('Joint token or action is outside its vocabulary');
  end;
  SetLength(LActions, 1);
  LActions[0] := AAction;
  Result := JointPrefix + UTF8String(IntToStr(AToken)) + '/' +
    EncodeWfcMusicRhythmCell(ProjectAcousticRhythm(LActions)[0]);
end;

procedure DecodeJointAcousticToken(const AToken: TWfcModelToken;
  out AIndex: Integer; out AAction: TAcousticAction);
var
  LIndex: Integer;
  LAction: TAcousticAction;
  LSeparator: Integer;
  LText: String;
begin
  LText := String(AToken);
  LSeparator := Pos('/', LText);
  if (Copy(LText, 1, Length(JointPrefix)) <> JointPrefix) or
    (LSeparator <= Length(JointPrefix) + 1) or
    not TryStrToInt(Copy(LText, Length(JointPrefix) + 1,
      LSeparator - Length(JointPrefix) - 1), LIndex) then
  begin
    raise EAudio.Create('Invalid joint token encoding');
  end;
  { Decode through the actual rhythm vocabulary, then require a canonical pair. }
  case DecodeWfcMusicRhythmCell(UTF8String(Copy(LText, LSeparator + 1, MaxInt))).Action of
    wmcaRest:
    begin
      LAction := aaSilence;
    end;
    wmcaAttack:
    begin
      LAction := aaOnset;
    end;
    wmcaHold:
    begin
      LAction := aaSustain;
    end;
  end;
  if JointAcousticToken(LIndex, LAction) <> AToken then
  begin
    raise EAudio.Create('Noncanonical joint token');
  end;
  AIndex := LIndex;
  AAction := LAction;
end;

function LearnJointAcousticModel(const ACorpus: TAcousticCorpusData;
  const AActivity: TActivityOptions; const AOrder: Integer): TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LRecording: TAcousticRecording;
  LActivity: TAcousticActivity;
  LSource: Integer;
  LFrame: Integer;
begin
  if (ACorpus = nil) or (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Joint learning requires corpus and order 1..4');
  end;
  ValidateActivityOptions(AActivity);
  SetLength(LSamples, ACorpus.SourceCount);
  for LSource := 0 to High(LSamples) do
  begin
    LRecording := ACorpus.RecordingAt(LSource);
    LActivity := AnalyzeAcousticActivity(LRecording.Features, ACorpus.Options,
      LRecording.Info.FrameCount, AActivity);
    SetLength(LTokens, Length(LRecording.Tokens));
    for LFrame := 0 to High(LTokens) do
    begin
      LTokens[LFrame] := JointAcousticToken(LRecording.Tokens[LFrame], LActivity.Actions[LFrame]);
    end;
    LSamples[LSource] := MakeWfcSequenceSample(LTokens);
  end;
  Result := LearnSequenceModelCorpus(LSamples, AOrder, wmbOpen);
end;

function JointTokenConstraints(const AModel: TWfcSequenceModel;
  const AConstraints: TJointConstraints): TWfcSequenceTokenConstraints;
var
  LConstraints: TWfcSequenceTokenConstraints;
  LAllowed: TWfcModelTokens;
  LIndices: TAcousticIndices;
  LActions: TAcousticActions;
  LIndex: Integer;
  LToken: Integer;
  LCount: Integer;
begin
  if (AModel = nil) or (Length(AConstraints) > MaximumGeneratedAcousticFrames) then
  begin
    raise EAudio.Create('Joint model or constraint count is invalid');
  end;
  if AModel.PublicTokenCount > MaximumAcousticVocabulary * 3 then
  begin
    raise EAudio.Create('Joint model exceeds paired vocabulary');
  end;
  SetLength(LIndices, AModel.PublicTokenCount);
  SetLength(LActions, AModel.PublicTokenCount);
  for LToken := 0 to AModel.PublicTokenCount - 1 do
  begin
    DecodeJointAcousticToken(AModel.PublicTokenAt(LToken), LIndices[LToken], LActions[LToken]);
  end;
  SetLength(LConstraints, Length(AConstraints));
  for LIndex := 0 to High(AConstraints) do
  begin
    if (AConstraints[LIndex].AcousticToken < -1) or
      (AConstraints[LIndex].AcousticToken >= MaximumAcousticVocabulary) then
    begin
      raise EAudio.Create('Joint acoustic lock outside vocabulary');
    end;
    SetLength(LAllowed, AModel.PublicTokenCount);
    LCount := 0;
    for LToken := 0 to AModel.PublicTokenCount - 1 do
    begin
      if ((AConstraints[LIndex].AcousticToken = -1) or
        (AConstraints[LIndex].AcousticToken = LIndices[LToken])) and
        (LActions[LToken] in AConstraints[LIndex].AllowedActions) then
      begin
        LAllowed[LCount] := AModel.PublicTokenAt(LToken);
        Inc(LCount);
      end;
    end;
    SetLength(LAllowed, LCount);
    LConstraints[LIndex] := MakeWfcSequenceTokenConstraint(AConstraints[LIndex].Position, LAllowed);
  end;
  Result := LConstraints;
end;

function TryGenerateJointSequence(const AModel: TWfcSequenceModel;
  const AOptions: TAcousticGenerationOptions; const AConstraints: TJointConstraints;
  var ASequence: TJointSequence; out AReport: TGraphSolveReport): Boolean;
var
  LConstraints: TWfcSequenceTokenConstraints;
  LGenerated: TWfcModelTokens;
  LCandidate: TJointSequence;
  LIndex: Integer;
begin
  LConstraints := JointTokenConstraints(AModel, AConstraints);
  Result := TryGenerateTokenSequence(AModel, AOptions, LConstraints, LGenerated, AReport);
  if not Result then
  begin
    Exit;
  end;
  SetLength(LCandidate.Tokens, Length(LGenerated));
  SetLength(LCandidate.Actions, Length(LGenerated));
  for LIndex := 0 to High(LGenerated) do
  begin
    DecodeJointAcousticToken(LGenerated[LIndex], LCandidate.Tokens[LIndex],
      LCandidate.Actions[LIndex]);
  end;
  ASequence := LCandidate;
end;

end.
