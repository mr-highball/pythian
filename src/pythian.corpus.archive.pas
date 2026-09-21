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
unit pythian.corpus.archive;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.corpus;

const
  MaximumCorpusArchiveBytes = 32 * 1024 * 1024;
  MaximumCorpusAttachmentBytes = 16 * 1024 * 1024;

{ Canonical little-endian, IEEE binary64, bounded UTF-8 and SHA256 trailer.
  The optional attachment is opaque to core (for example, a companion model).
  The digest detects corruption and binds the payloads; it is not a signature. }
function EncodeAcousticArchive(const ACorpus: TAcousticCorpusData;
  const AAttachmentContract: UTF8String; const AAttachment: TAudioBytes): TAudioBytes;
function DecodeAcousticArchive(const ABytes: TAudioBytes;
  out AAttachmentContract: UTF8String; out AAttachment: TAudioBytes): TAcousticCorpusData;

implementation

uses
  Classes,
  SysUtils,
  pythian.analysis,
  pythian.learning,
  pythian.hash;

type
  TArchiveWriter = class
  strict private
    FStream: TMemoryStream;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Raw(const AData; const ACount: Integer);
    procedure Number(const AValue: Integer);
    procedure RealNumber(const AValue: Double);
    procedure TextValue(const AValue: UTF8String);
    function Finish: TAudioBytes;
  end;

  TArchiveReader = record
    Bytes: TAudioBytes;
    Offset: Integer;
    Limit: Integer;
    procedure Need(const ACount: Integer);
    function Number: Integer;
    function RealNumber: Double;
    function TextValue: UTF8String;
  end;

constructor TArchiveWriter.Create;
begin
  inherited Create;
  FStream := TMemoryStream.Create;
end;

destructor TArchiveWriter.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

procedure TArchiveWriter.Raw(const AData; const ACount: Integer);
begin
  if (ACount < 0) or (ACount > MaximumCorpusArchiveBytes - 64 - FStream.Size) then
  begin
    raise EAudio.Create('Corpus archive exceeds byte budget');
  end;
  if ACount > 0 then
  begin
    FStream.WriteBuffer(AData, ACount);
  end;
end;

procedure TArchiveWriter.Number(const AValue: Integer);
var
  LBytes: array[0..3] of Byte;
  LIndex: Integer;
begin
  if AValue < 0 then
  begin
    raise EAudio.Create('Archive integer must be nonnegative');
  end;
  for LIndex := 0 to 3 do
  begin
    LBytes[LIndex] := (Cardinal(AValue) shr (LIndex * 8)) and $FF;
  end;
  Raw(LBytes[0], SizeOf(LBytes));
end;

procedure TArchiveWriter.RealNumber(const AValue: Double);
var
  LBits: QWord;
  LBytes: array[0..7] of Byte;
  LIndex: Integer;
begin
  RequireFinite(AValue, 'Archive real');
  Move(AValue, LBits, SizeOf(LBits));
  for LIndex := 0 to 7 do
  begin
    LBytes[LIndex] := (LBits shr (LIndex * 8)) and $FF;
  end;
  Raw(LBytes[0], SizeOf(LBytes));
end;

procedure TArchiveWriter.TextValue(const AValue: UTF8String);
begin
  ValidateCorpusText(AValue);
  Number(Length(AValue));
  if AValue <> '' then
  begin
    Raw(AValue[1], Length(AValue));
  end;
end;

function TArchiveWriter.Finish: TAudioBytes;
var
  LHash: String;
  LCount: Integer;
begin
  LCount := FStream.Size;
  Result := nil;
  SetLength(Result, LCount);
  FStream.Position := 0;
  if LCount > 0 then
  begin
    FStream.ReadBuffer(Result[0], LCount);
  end;
  LHash := Sha256Bytes(Result);
  SetLength(Result, LCount + 64);
  Move(LHash[1], Result[LCount], 64);
end;

procedure TArchiveReader.Need(const ACount: Integer);
begin
  if (ACount < 0) or (ACount > Limit - Offset) then
  begin
    raise EAudio.Create('Truncated or oversized acoustic archive field');
  end;
end;

function TArchiveReader.Number: Integer;
var
  LValue: Cardinal;
  LIndex: Integer;
begin
  Need(4);
  LValue := 0;
  for LIndex := 0 to 3 do
  begin
    LValue := LValue or (Cardinal(Bytes[Offset + LIndex]) shl (LIndex * 8));
  end;
  Inc(Offset, 4);
  if LValue > High(Integer) then
  begin
    raise EAudio.Create('Archive integer exceeds supported range');
  end;
  Result := LValue;
end;

function TArchiveReader.RealNumber: Double;
var
  LBits: QWord;
  LIndex: Integer;
begin
  Need(8);
  LBits := 0;
  for LIndex := 0 to 7 do
  begin
    LBits := LBits or (QWord(Bytes[Offset + LIndex]) shl (LIndex * 8));
  end;
  Inc(Offset, 8);
  if (LBits and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then
  begin
    raise EAudio.Create('Archive contains non-finite binary64');
  end;
  Move(LBits, Result, SizeOf(Result));
end;

function TArchiveReader.TextValue: UTF8String;
var
  LCount: Integer;
begin
  LCount := Number;
  if LCount > MaximumCorpusTextBytes then
  begin
    raise EAudio.Create('Archive text exceeds byte budget');
  end;
  Need(LCount);
  Result := '';
  SetLength(Result, LCount);
  if LCount > 0 then
  begin
    Move(Bytes[Offset], Result[1], LCount);
  end;
  Inc(Offset, LCount);
  ValidateCorpusText(Result);
end;

procedure ValidateAttachment(const AContract: UTF8String; const ASize: Integer);
begin
  ValidateCorpusText(AContract);
  if (ASize < 0) or (ASize > MaximumCorpusAttachmentBytes) or
    ((AContract = '') <> (ASize = 0)) then
  begin
    raise EAudio.Create('Attachment must have a contract and bounded nonempty bytes, or both empty');
  end;
end;

function EncodeAcousticArchive(const ACorpus: TAcousticCorpusData;
  const AAttachmentContract: UTF8String; const AAttachment: TAudioBytes): TAudioBytes;
const
  CMagic: array[0..3] of Byte = ($50, $59, $41, $43);
var
  LWriter: TArchiveWriter;
  LPalette: TAcousticPalette;
  LRecording: TAcousticRecording;
  LFeature: TAudioFeature;
  LCenter: TAcousticVector;
  LIndex: Integer;
  LFrame: Integer;
  LComponent: Integer;
begin
  if ACorpus = nil then
  begin
    raise EAudio.Create('Corpus is required for persistence');
  end;
  ValidateAttachment(AAttachmentContract, Length(AAttachment));
  LWriter := TArchiveWriter.Create;
  try
    LWriter.Raw(CMagic[0], 4);
    LWriter.Number(AcousticCorpusVersion);
    LWriter.Number(AnalysisVersion);
    LWriter.Number(AcousticLearningVersion);
    LWriter.Number(ACorpus.Options.WindowFrames);
    LWriter.Number(ACorpus.Options.HopFrames);
    LWriter.RealNumber(ACorpus.Options.SilenceRms);
    LPalette := ACorpus.CopyPalette;
    try
      LWriter.Number(LPalette.Count);
      for LIndex := 0 to LPalette.Count - 1 do
      begin
        LCenter := LPalette.CenterAt(LIndex);
        for LComponent := 0 to High(LCenter) do
        begin
          LWriter.RealNumber(LCenter[LComponent]);
        end;
      end;
    finally
      LPalette.Free;
    end;
    LWriter.Number(ACorpus.SourceCount);
    for LIndex := 0 to ACorpus.SourceCount - 1 do
    begin
      LRecording := ACorpus.RecordingAt(LIndex);
      LWriter.TextValue(LRecording.Info.Name);
      LWriter.TextValue(UTF8String(LRecording.Info.Sha256));
      LWriter.TextValue(LRecording.Info.Provenance);
      LWriter.Number(LRecording.Info.SampleRate);
      LWriter.Number(LRecording.Info.Channels);
      LWriter.Number(LRecording.Info.FrameCount);
      LWriter.Number(Length(LRecording.Features));
      for LFrame := 0 to High(LRecording.Features) do
      begin
        LFeature := LRecording.Features[LFrame];
        LWriter.Number(LFeature.StartFrame);
        LWriter.Number(LFeature.ValidFrames);
        LWriter.Number(LRecording.Tokens[LFrame]);
        LWriter.Number(Ord(LFeature.Silent));
        LWriter.RealNumber(LFeature.Rms);
        LWriter.RealNumber(LFeature.Peak);
        LWriter.RealNumber(LFeature.CentroidHz);
        LWriter.RealNumber(LFeature.Flux);
        for LComponent := 0 to 11 do
        begin
          LWriter.RealNumber(LFeature.Chroma[LComponent]);
        end;
      end;
    end;
    LWriter.TextValue(AAttachmentContract);
    LWriter.Number(Length(AAttachment));
    if Length(AAttachment) > 0 then
    begin
      LWriter.Raw(AAttachment[0], Length(AAttachment));
    end;
    Result := LWriter.Finish;
  finally
    LWriter.Free;
  end;
end;

function DecodeAcousticArchive(const ABytes: TAudioBytes;
  out AAttachmentContract: UTF8String; out AAttachment: TAudioBytes): TAcousticCorpusData;
var
  LReader: TArchiveReader;
  LOptions: TAnalysisOptions;
  LCenters: TAcousticVectors;
  LRecordings: TAcousticRecordings;
  LHash: String;
  LAttachmentContract: UTF8String;
  LAttachment: TAudioBytes;
  LCount: Integer;
  LTotal: Integer;
  LIndex: Integer;
  LFrame: Integer;
  LComponent: Integer;
  LFlag: Integer;
begin
  AAttachmentContract := '';
  AAttachment := nil;
  if (Length(ABytes) < 100) or (Length(ABytes) > MaximumCorpusArchiveBytes) then
  begin
    raise EAudio.Create('Acoustic archive length is outside its byte budget');
  end;
  SetLength(LHash, 64);
  Move(ABytes[Length(ABytes) - 64], LHash[1], 64);
  if Sha256Bytes(Copy(ABytes, 0, Length(ABytes) - 64)) <> LHash then
  begin
    raise EAudio.Create('Acoustic archive SHA256 mismatch');
  end;
  if (ABytes[0] <> $50) or (ABytes[1] <> $59) or
    (ABytes[2] <> $41) or (ABytes[3] <> $43) then
  begin
    raise EAudio.Create('Invalid acoustic archive magic');
  end;
  LReader.Bytes := ABytes;
  LReader.Offset := 4;
  LReader.Limit := Length(ABytes) - 64;
  if (LReader.Number <> AcousticCorpusVersion) or
    (LReader.Number <> AnalysisVersion) or (LReader.Number <> AcousticLearningVersion) then
  begin
    raise EAudio.Create('Unsupported corpus, analysis or learning version');
  end;
  LOptions.WindowFrames := LReader.Number;
  LOptions.HopFrames := LReader.Number;
  LOptions.SilenceRms := LReader.RealNumber;
  LCount := LReader.Number;
  if (LCount < 1) or (LCount > MaximumAcousticVocabulary) then
  begin
    raise EAudio.Create('Archive palette size exceeds bounds');
  end;
  SetLength(LCenters, LCount);
  for LIndex := 0 to High(LCenters) do
  begin
    for LComponent := 0 to High(TAcousticVector) do
    begin
      LCenters[LIndex][LComponent] := LReader.RealNumber;
    end;
  end;
  LCount := LReader.Number;
  if (LCount < 1) or (LCount > MaximumCorpusSources) then
  begin
    raise EAudio.Create('Archive recording count exceeds bounds');
  end;
  SetLength(LRecordings, LCount);
  LTotal := 0;
  for LIndex := 0 to High(LRecordings) do
  begin
    LRecordings[LIndex].Info.Name := LReader.TextValue;
    LRecordings[LIndex].Info.Sha256 := String(LReader.TextValue);
    LRecordings[LIndex].Info.Provenance := LReader.TextValue;
    LRecordings[LIndex].Info.SampleRate := LReader.Number;
    LRecordings[LIndex].Info.Channels := LReader.Number;
    LRecordings[LIndex].Info.FrameCount := LReader.Number;
    ValidateSourceInfo(LRecordings[LIndex].Info);
    LCount := LReader.Number;
    if (LCount < 1) or (LCount > MaximumAnalysisFrames - LTotal) then
    begin
      raise EAudio.Create('Archive feature count exceeds bounds');
    end;
    LReader.Need(LCount * 144);
    Inc(LTotal, LCount);
    SetLength(LRecordings[LIndex].Features, LCount);
    SetLength(LRecordings[LIndex].Tokens, LCount);
    for LFrame := 0 to LCount - 1 do
    begin
      LRecordings[LIndex].Features[LFrame].StartFrame := LReader.Number;
      LRecordings[LIndex].Features[LFrame].ValidFrames := LReader.Number;
      LRecordings[LIndex].Tokens[LFrame] := LReader.Number;
      LFlag := LReader.Number;
      if LFlag > 1 then
      begin
        raise EAudio.Create('Archive Boolean must be zero or one');
      end;
      LRecordings[LIndex].Features[LFrame].Silent := LFlag = 1;
      LRecordings[LIndex].Features[LFrame].Rms := LReader.RealNumber;
      LRecordings[LIndex].Features[LFrame].Peak := LReader.RealNumber;
      LRecordings[LIndex].Features[LFrame].CentroidHz := LReader.RealNumber;
      LRecordings[LIndex].Features[LFrame].Flux := LReader.RealNumber;
      for LComponent := 0 to 11 do
      begin
        LRecordings[LIndex].Features[LFrame].Chroma[LComponent] := LReader.RealNumber;
      end;
    end;
  end;
  LAttachmentContract := LReader.TextValue;
  LCount := LReader.Number;
  ValidateAttachment(LAttachmentContract, LCount);
  LReader.Need(LCount);
  LAttachment := Copy(ABytes, LReader.Offset, LCount);
  Inc(LReader.Offset, LCount);
  if LReader.Offset <> LReader.Limit then
  begin
    raise EAudio.Create('Trailing bytes in acoustic archive');
  end;
  Result := TAcousticCorpusData.Create(LOptions, LCenters, LRecordings);
  AAttachmentContract := LAttachmentContract;
  AAttachment := LAttachment;
end;

end.
