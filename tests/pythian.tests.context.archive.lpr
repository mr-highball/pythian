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
program pythian_tests_context_archive;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.hash,
  pythian.tonal,
  pythian.music.context,
  pythian.wfc.context,
  pythian.wfc.context.archive,
  wfc_sequence,
  wfc_sequence_text;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure PutNumber(var ABytes: TAudioBytes; const AOffset, AValue: Integer);
var
  I: Integer;
begin
  for I := 0 to 3 do
  begin
    ABytes[AOffset + I] := (Cardinal(AValue) shr (I * 8)) and $FF;
  end;
end;

function NumberAt(const ABytes: TAudioBytes; const AOffset: Integer): Integer;
begin
  Result := ABytes[AOffset] + (Integer(ABytes[AOffset + 1]) shl 8) +
    (Integer(ABytes[AOffset + 2]) shl 16) + (Integer(ABytes[AOffset + 3]) shl 24);
end;

procedure Redigest(var ABytes: TAudioBytes);
var
  LHash: String;
begin
  LHash := Sha256Bytes(Copy(ABytes, 0, Length(ABytes) - 64));
  Move(LHash[1], ABytes[Length(ABytes) - 64], 64);
end;

procedure ExpectRejected(const ABytes: TAudioBytes; var APrior: TContextLearningBundle);
var
  LOriginal: TContextLearningBundle;
  LRejected: Boolean;
begin
  LOriginal := APrior;
  LRejected := False;
  try
    APrior := DecodeContextLearning(ABytes);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (APrior = LOriginal), 'Invalid archive preserves prior assigned bundle');
end;

procedure Run;
var
  LEvidence: TContextEvidenceArray;
  LCopy: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LLoaded: TContextLearningBundle;
  LModel: TWfcSequenceModel;
  LBytes: TAudioBytes;
  LRoundTrip: TAudioBytes;
  LBad: TAudioBytes;
  LKeyText: UTF8String;
  LTempoText: UTF8String;
  LFirstCell: Integer;
  I: Integer;
  J: Integer;
begin
  LBundle := nil;
  LLoaded := nil;
  LModel := nil;
  SetLength(LEvidence, 2);
  for I := 0 to 1 do
  begin
    LEvidence[I].Name := 'authored source ' + IntToStr(I);
    LEvidence[I].SourceSha256 := Sha256Bytes([Byte(I)]);
    LEvidence[I].AdmissionPolicy := 'Explicit authored context, no inferred key or tempo';
    LEvidence[I].Grid.TicksPerQuarter := 480;
    LEvidence[I].Grid.StartTick := I * 1920;
    LEvidence[I].Grid.StepTicks := 240;
    SetLength(LEvidence[I].Grid.Keys, 8);
    SetLength(LEvidence[I].Grid.Tempos, 8);
    for J := 0 to 7 do
    begin
      LEvidence[I].Grid.Keys[J] := MakeKeyContext(I * 2, TDiatonicMode(I));
      LEvidence[I].Grid.Tempos[J] := 500001 + I * 100000;
    end;
  end;
  try
    LBundle := TContextLearningBundle.Create(Copy(LEvidence, 0, 1));
    LLoaded := DecodeContextLearning(EncodeContextLearning(LBundle));
    LCopy := LLoaded.CopyEvidence;
    Check(Length(LCopy) = 1, 'Single-source learning retains one independent excerpt');
    FreeAndNil(LLoaded);
    FreeAndNil(LBundle);
    LEvidence[1].SourceFrameOffset := 973;
    LBundle := TContextLearningBundle.Create(LEvidence, 3, 2);
    LEvidence[0].Grid.Keys[0].Root := 8;
    LCopy := LBundle.CopyEvidence;
    LCopy[0].Grid.Tempos[0] := 1;
    LCopy[0].AdmissionPolicy := 'changed';
    LKeyText := LBundle.ModelText(cdKey);
    LTempoText := LBundle.ModelText(cdTempo);
    LBytes := EncodeContextLearning(LBundle);
    FreeAndNil(LBundle);
    LLoaded := DecodeContextLearning(LBytes);
    LRoundTrip := EncodeContextLearning(LLoaded);
    Check((Length(LBytes) = Length(LRoundTrip)) and
      CompareMem(@LBytes[0], @LRoundTrip[0], Length(LBytes)), 'Exact archive round trip');
    Check((LLoaded.ModelText(cdKey) = LKeyText) and
      (LLoaded.ModelText(cdTempo) = LTempoText) and
      (LLoaded.KeyOrder = 3) and (LLoaded.TempoOrder = 2) and
      (LLoaded.TicksPerQuarter = 480) and (LLoaded.StepTicks = 240),
      'Actual provider models and distinct orders retain timing');
    LCopy := LLoaded.CopyEvidence;
    Check((LCopy[0].Grid.Keys[0].Root = 0) and
      (LCopy[0].Grid.Tempos[0] = 500001) and (LCopy[1].Grid.StartTick = 1920) and
      (LCopy[0].SourceFrameOffset = 0) and (LCopy[1].SourceFrameOffset = 973) and
      (LCopy[0].AdmissionPolicy = 'Explicit authored context, no inferred key or tempo'),
      'Source scopes, admission and nested ownership survive');
    LModel := LLoaded.CopyModel(cdKey);
    Check(EncodeWfcSequenceText(LModel) = LKeyText, 'Detached actual model copy');
    { Independently locate the first cell after 10 u32 header fields,
      name/hash fields, the source frame offset, policy and four grid integers. }
    LFirstCell := 40;
    for I := 0 to 1 do
    begin
      Inc(LFirstCell, 4 + NumberAt(LBytes, LFirstCell));
    end;
    Inc(LFirstCell, 4);
    Inc(LFirstCell, 4 + NumberAt(LBytes, LFirstCell));
    Inc(LFirstCell, 16);
    LBad := Copy(LBytes);
    PutNumber(LBad, LFirstCell, 5);
    Redigest(LBad);
    ExpectRejected(LBad, LLoaded);
    LBad := Copy(LBytes);
    PutNumber(LBad, LFirstCell - 4, 65537);
    Redigest(LBad);
    ExpectRejected(LBad, LLoaded);
    LBad := Copy(LBytes);
    PutNumber(LBad, 4, 2);
    Redigest(LBad);
    ExpectRejected(LBad, LLoaded);
    LBad := Copy(LBytes, 0, Length(LBytes) - 64);
    SetLength(LBad, Length(LBytes) + 1);
    LBad[Length(LBytes) - 64] := 0;
    Redigest(LBad);
    ExpectRejected(LBad, LLoaded);
    LBad := Copy(LBytes, 0, Length(LBytes) - 1);
    ExpectRejected(LBad, LLoaded);
    FreeAndNil(LLoaded);
    Check(EncodeWfcSequenceText(LModel) = LKeyText, 'Copied model survives bundle lifetime');
    WriteLn('Context archive: exact evidence/model replay, ownership, semantic mismatch and bounds passed');
  finally
    LModel.Free;
    LLoaded.Free;
    LBundle.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
