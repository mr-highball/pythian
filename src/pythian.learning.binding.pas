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

unit pythian.learning.binding;

{$mode delphi}
{$H+}

interface

uses
  pythian.analysis,
  pythian.learning;

{ Canonical semantic identity of an ordered palette and its analysis/frame clock.
  Includes current analysis/learning policies, sample rate and channel count.
  Source identity and model order are separate contracts. Signed zero normalizes. }
function AcousticVocabularySha256(const APalette: TAcousticPalette;
  const AOptions: TAnalysisOptions; const ASampleRate, AChannels: Integer): String;
{ Binds an exact serialized model digest to that vocabulary. This is an integrity
  check, not authorship authentication or verification of training evidence. }
function AcousticModelBindingSha256(const AVocabularySha256, AModelSha256: String): String;

implementation

uses
  Classes,
  pythian.audio,
  pythian.hash;

procedure CheckDigest(const AValue: String);
var
  LIndex: Integer;
begin
  if Length(AValue) <> 64 then
  begin
    raise EAudio.Create('Acoustic binding digest must contain 64 hex characters');
  end;
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      raise EAudio.Create('Acoustic binding digest must be lowercase hexadecimal');
    end;
  end;
end;

procedure PutNumber(const AStream: TStream; const AValue: QWord);
var
  LBytes: array[0..7] of Byte;
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
  begin
    LBytes[LIndex] := (AValue shr (LIndex * 8)) and $FF;
  end;
  AStream.WriteBuffer(LBytes, SizeOf(LBytes));
end;

procedure PutReal(const AStream: TStream; const AValue: Double);
var
  LBits: QWord;
begin
  RequireFinite(AValue, 'Acoustic binding value');
  LBits := 0;
  if AValue <> 0 then
  begin
    Move(AValue, LBits, SizeOf(LBits));
  end;
  PutNumber(AStream, LBits);
end;

function AcousticVocabularySha256(const APalette: TAcousticPalette;
  const AOptions: TAnalysisOptions; const ASampleRate, AChannels: Integer): String;
const
  CContract = 'pythian.acoustic.vocabulary';
var
  LStream: TMemoryStream;
  LFeatureCount: Integer;
  LWork: Int64;
  LToken: Integer;
  LComponent: Integer;
  LVector: TAcousticVector;
begin
  if APalette = nil then
  begin
    raise EAudio.Create('Acoustic vocabulary requires a palette');
  end;
  ValidateAudioFormat(ASampleRate, AChannels);
  PlanAudioAnalysis(1, AChannels, AOptions, LFeatureCount, LWork);
  LStream := TMemoryStream.Create;
  try
    LStream.WriteBuffer(CContract[1], Length(CContract));
    PutNumber(LStream, AnalysisVersion);
    PutNumber(LStream, AcousticLearningVersion);
    PutNumber(LStream, ASampleRate);
    PutNumber(LStream, AChannels);
    PutNumber(LStream, AOptions.WindowFrames);
    PutNumber(LStream, AOptions.HopFrames);
    PutReal(LStream, AOptions.SilenceRms);
    PutNumber(LStream, APalette.Count);
    for LToken := 0 to APalette.Count - 1 do
    begin
      LVector := APalette.CenterAt(LToken);
      for LComponent := 0 to High(LVector) do
      begin
        PutReal(LStream, LVector[LComponent]);
      end;
    end;
    LStream.Position := 0;
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function AcousticModelBindingSha256(const AVocabularySha256, AModelSha256: String): String;
const
  CContract = 'pythian.acoustic.bound-model';
var
  LStream: TMemoryStream;
begin
  CheckDigest(AVocabularySha256);
  CheckDigest(AModelSha256);
  LStream := TMemoryStream.Create;
  try
    LStream.WriteBuffer(CContract[1], Length(CContract));
    LStream.WriteBuffer(AVocabularySha256[1], 64);
    LStream.WriteBuffer(AModelSha256[1], 64);
    LStream.Position := 0;
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

end.
