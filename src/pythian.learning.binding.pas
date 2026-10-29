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
  pythian.hash,
  pythian.binary,
  pythian.text,
  pythian.stream.bytes;

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
  LBytes: TAudioBytes;
begin
  if AValue > QWord(MaximumBinaryInteger) then
  begin
    raise EAudio.Create('Acoustic binding integer exceeds the target exact range');
  end;
  SetLength(LBytes, 8);
  WriteUnsignedLE(LBytes, 0, 8, Int64(AValue));
  WriteStreamBytesExact(AStream, LBytes, 0, Length(LBytes));
end;

procedure PutReal(const AStream: TStream; const AValue: Double);
var
  LBytes: TAudioBytes;
  LValue: Double;
begin
  { The existing vocabulary identity normalizes both signed zeros. Journal
    observations retain their original sign; this binding is intentionally
    semantic rather than an opaque record hash. }
  LValue := AValue;
  if AValue = 0 then
  begin
    LValue := 0;
  end;
  SetLength(LBytes, 8);
  WriteFloat64LE(LBytes, 0, LValue);
  WriteStreamBytesExact(AStream, LBytes, 0, Length(LBytes));
end;

procedure PutText(const AStream: TStream; const AText: String);
var
  LBytes: TAudioBytes;
begin
  LBytes := EncodeUTF8Text(AText, 64, False, False);
  WriteStreamBytesExact(AStream, LBytes, 0, Length(LBytes));
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
    PutText(LStream, CContract);
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
    PutText(LStream, CContract);
    PutText(LStream, AVocabularySha256);
    PutText(LStream, AModelSha256);
    LStream.Position := 0;
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

end.
