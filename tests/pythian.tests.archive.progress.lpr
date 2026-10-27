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
program pythian_tests_archive_progress;
{$mode delphi}
{$H+}
uses
  SysUtils, pythian.audio, pythian.progress, pythian.analysis, pythian.learning,
  pythian.corpus, pythian.corpus.archive, pythian.hash;
type
  EProbe = class(Exception);
  TProbe = class
    AbortStage: String;
    RaisedObject: Exception;
    SeenEncode: Boolean;
    SeenDecode: Boolean;
    SeenValidation: Boolean;
    SeenAttachment: Boolean;
    EncodeCalls: Integer;
    DecodeCalls: Integer;
    ValidationCalls: Integer;
    AttachmentCalls: Integer;
    procedure Observe(const AWork: TWorkProgress);
  end;
var
  GChecks: Integer;
procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;
procedure TProbe.Observe(const AWork: TWorkProgress);
begin
  Check((AWork.Done >= 0) and ((AWork.Total = 0) or (AWork.Done <= AWork.Total)),
    'Progress bounds');
  if AWork.Stage = 'archive_encode_features' then
  begin
    Inc(EncodeCalls);
    Check(AWork.Units = wuObservations, 'Encoded feature units');
  end;
  if AWork.Stage = 'archive_decode_features' then
  begin
    Inc(DecodeCalls);
    Check(AWork.Units = wuObservations, 'Decoded feature units');
  end;
  if AWork.Stage = 'corpus_validate_features' then
  begin
    Inc(ValidationCalls);
    Check(AWork.Units = wuObservations, 'Validated feature units');
  end;
  if (AWork.Stage = 'archive_encode_attachment') or
    (AWork.Stage = 'archive_decode_attachment') then
  begin
    Inc(AttachmentCalls);
    Check(AWork.Units = wuBytes, 'Attachment byte units');
  end;
  if (AWork.Stage = 'archive_encode_features') and (AWork.Done = AWork.Total) then
  begin
    SeenEncode := True;
  end;
  if (AWork.Stage = 'archive_decode_features') and (AWork.Total > 0) and
    (AWork.Done = AWork.Total) then
  begin
    SeenDecode := True;
  end;
  if (AWork.Stage = 'corpus_validate_features') and (AWork.Done = AWork.Total) then
  begin
    SeenValidation := True;
  end;
  if (AWork.Stage = 'archive_decode_attachment') and (AWork.Done = AWork.Total) then
  begin
    SeenAttachment := True;
  end;
  if (AWork.Stage = AbortStage) and (AWork.Done > 0) and
    ((AWork.Total = 0) or (AWork.Done < AWork.Total)) then
  begin
    RaisedObject := EProbe.Create('archive observer abort');
    raise RaisedObject;
  end;
end;
procedure SameBytes(const AFirst, ASecond: TAudioBytes);
var
  LIndex: Integer;
begin
  Check(Length(AFirst) = Length(ASecond), 'Archive lengths match');
  for LIndex := 0 to High(AFirst) do
  begin
    if AFirst[LIndex] <> ASecond[LIndex] then
    begin
      raise Exception.Create('Archive byte mismatch');
    end;
  end;
end;
var
  LOptions: TAnalysisOptions;
  LCenters: TAcousticVectors;
  LRecords: TAcousticRecordings;
  LCorpus: TAcousticCorpusData;
  LLoaded: TAcousticCorpusData;
  LBytes: TAudioBytes;
  LObserved: TAudioBytes;
  LAttachment: TAudioBytes;
  LDecodedAttachment: TAudioBytes;
  LContract: UTF8String;
  LHash: String;
  LAttachmentHash: String;
  LProbe: TProbe;
  LIndex: Integer;
  LMode: Integer;
  LRejected: Boolean;
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
  LRecords[0].Info.FrameCount := MaximumAnalysisFrames * 32;
  SetLength(LRecords[0].Features, MaximumAnalysisFrames);
  SetLength(LRecords[0].Tokens, MaximumAnalysisFrames);
  for LIndex := 0 to MaximumAnalysisFrames - 1 do
  begin
    LRecords[0].Features[LIndex].StartFrame := LIndex * 32;
    LRecords[0].Features[LIndex].ValidFrames := 64;
    if LIndex = MaximumAnalysisFrames - 1 then
    begin
      LRecords[0].Features[LIndex].ValidFrames := 32;
    end;
    LRecords[0].Features[LIndex].Silent := True;
  end;
  SetLength(LAttachment, 1048576);
  for LIndex := 0 to High(LAttachment) do
  begin
    LAttachment[LIndex] := LIndex mod 251;
  end;
  LAttachmentHash := Sha256Bytes(LAttachment);
  LCorpus := TAcousticCorpusData.Create(LOptions, LCenters, LRecords);
  try
    LBytes := EncodeAcousticArchive(LCorpus, 'opaque-test', LAttachment);
    LHash := Sha256Bytes(LBytes);
    LProbe := TProbe.Create;
    try
      LObserved := EncodeAcousticArchive(LCorpus, 'opaque-test', LAttachment, LProbe.Observe);
      SameBytes(LBytes, LObserved);
      Check(LProbe.SeenEncode, 'Encode features complete');
      Check((LProbe.EncodeCalls > 2) and (LProbe.EncodeCalls <= 400) and
        (LProbe.AttachmentCalls > 2) and (LProbe.AttachmentCalls <= 32),
        'Substantial encode uses bounded aggregate callbacks');
      WriteLn('archive_encode features=', MaximumAnalysisFrames,
        ' feature_callbacks=', LProbe.EncodeCalls,
        ' attachment_bytes=', Length(LAttachment),
        ' attachment_callbacks=', LProbe.AttachmentCalls);
    finally
      LProbe.Free;
    end;
    LProbe := TProbe.Create;
    try
      LLoaded := DecodeAcousticArchive(LBytes, LContract, LDecodedAttachment, LProbe.Observe);
      try
        Check((LContract = 'opaque-test') and LProbe.SeenDecode and
          LProbe.SeenValidation and LProbe.SeenAttachment, 'Decode phases complete');
        Check((LProbe.DecodeCalls > 2) and (LProbe.DecodeCalls <= 400) and
          (LProbe.ValidationCalls > 2) and (LProbe.ValidationCalls <= 400) and
          (LProbe.AttachmentCalls > 2) and (LProbe.AttachmentCalls <= 32),
          'Substantial decode and validation use bounded aggregate callbacks');
        WriteLn('archive_decode features=', MaximumAnalysisFrames,
          ' feature_callbacks=', LProbe.DecodeCalls,
          ' validation_callbacks=', LProbe.ValidationCalls,
          ' attachment_callbacks=', LProbe.AttachmentCalls);
        SameBytes(LAttachment, LDecodedAttachment);
        SameBytes(LBytes, EncodeAcousticArchive(LLoaded, LContract, LDecodedAttachment));
      finally
        LLoaded.Free;
      end;
    finally
      LProbe.Free;
    end;
    for LMode := 0 to 5 do
    begin
      LProbe := TProbe.Create;
      try
        case LMode of
          0:
            LProbe.AbortStage := 'archive_encode_features';
          1:
            LProbe.AbortStage := 'archive_encode_attachment';
          2:
            LProbe.AbortStage := 'verify_audio_bytes';
          3:
            LProbe.AbortStage := 'archive_decode_features';
          4:
            LProbe.AbortStage := 'archive_decode_attachment';
          5:
            LProbe.AbortStage := 'corpus_validate_features';
        end;
        LRejected := False;
        try
          if LMode < 2 then
          begin
            LObserved := EncodeAcousticArchive(LCorpus, 'opaque-test', LAttachment, LProbe.Observe)
          end
          else
          begin
            LLoaded := DecodeAcousticArchive(LBytes, LContract, LDecodedAttachment, LProbe.Observe);
            LLoaded.Free;
          end;
        except
          on LException: EProbe do
            LRejected := LException = LProbe.RaisedObject;
        end;
        Check(LRejected, 'Interior exception identity preserved');
        Check(Sha256Bytes(LBytes) = LHash, 'Borrowed archive unchanged');
        Check(Sha256Bytes(LAttachment) = LAttachmentHash, 'Borrowed attachment unchanged');
        if LMode >= 2 then
        begin
          Check((LContract = '') and (Length(LDecodedAttachment) = 0),
            'Cancelled decode leaves outputs empty');
        end;
      finally
        LProbe.Free;
      end;
      LLoaded := DecodeAcousticArchive(LBytes, LContract, LDecodedAttachment);
      try
        Check(LCorpus.FeatureCount = LLoaded.FeatureCount, 'Retry restores complete corpus');
      finally
        LLoaded.Free;
      end;
    end;
    LLoaded := DecodeAcousticArchive(LBytes, LContract, LDecodedAttachment);
    try
      SameBytes(LBytes, EncodeAcousticArchive(LLoaded, LContract, LDecodedAttachment));
    finally
      LLoaded.Free;
    end;
  finally
    LCorpus.Free;
  end;
  WriteLn('PASS ', GChecks, ' archive progress checks, ', MaximumAnalysisFrames, ' authored features');
end.
