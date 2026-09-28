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
unit pythian.music.tempo.evidence;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  TempoEvidenceVersion = 1;
  MaximumTempoEvidenceSpans = 65536;
  MaximumTempoEvidenceBytes = 2 * 1024 * 1024;

type
  TTempoEvidenceAvailability = (teaKnown, teaUnavailable, teaAmbiguous);
  TTempoSelectionOrigin = (tsoNone, tsoAutomatic, tsoCallerOverride);
  TTempoEvidenceSpan = record
    StartFrame: Integer;
    EndFrame: Integer;
    Availability: TTempoEvidenceAvailability;
    ObservedMicroseconds: Integer;
    SelectedMicroseconds: Integer;
    SelectionOrigin: TTempoSelectionOrigin;
  end;
  TTempoEvidenceSpans = array of TTempoEvidenceSpan;

  { Source-frame evidence only. This never constructs a PPQ clock or supplies
    an implied BPM. Raw availability and observation survive caller overrides.
    Input arrays are borrowed; the instance and CopySpans are detached. }
  TTempoEvidence = class
  private
    FSourceSha256: String;
    FSourceFrames: Integer;
    FSampleRate: Integer;
    FMeasurementIdentity: String;
    FAdmissionPolicyIdentity: String;
    FSpans: TTempoEvidenceSpans;
  public
    constructor Create(const ASourceSha256: String;
      const ASourceFrames, ASampleRate: Integer;
      const AMeasurementIdentity, AAdmissionPolicyIdentity: String;
      const ASpans: TTempoEvidenceSpans);
    function CopySpans: TTempoEvidenceSpans;
    { Requires complete coverage and one positive selected tempo. Unknown or
      ambiguous evidence may be selected only by a caller override. }
    function RequireConstantSelectedTempo(const AStartFrame,
      AEndFrame: Integer): Integer;
    property SourceSha256: String read FSourceSha256;
    property SourceFrames: Integer read FSourceFrames;
    property SampleRate: Integer read FSampleRate;
    property MeasurementIdentity: String read FMeasurementIdentity;
    property AdmissionPolicyIdentity: String read FAdmissionPolicyIdentity;
  end;

{ Little-endian v1: magic/version/geometry/count, length-prefixed ASCII
  identities, six u32 fields per span, then 64 lowercase SHA-256 hex bytes
  over the preceding bytes. Neither routine reads a source file. }
function EncodeTempoEvidence(const AEvidence: TTempoEvidence): TAudioBytes;
function DecodeTempoEvidence(const ABytes: TAudioBytes): TTempoEvidence;

implementation

uses
  SysUtils,
  pythian.hash,
  pythian.time;

const
  EvidenceMagic = $31455054; { TPE1 }
  MaximumIdentityLength = 128;

procedure ValidateIdentity(const AValue, AName: String);
var
  I: Integer;
begin
  if (Length(AValue) < 1) or (Length(AValue) > MaximumIdentityLength) then
    raise EAudio.Create(AName + ' identity length is invalid');
  for I := 1 to Length(AValue) do
    if (Ord(AValue[I]) < 33) or (Ord(AValue[I]) > 126) then
      raise EAudio.Create(AName + ' identity must be printable ASCII without spaces');
end;

procedure ValidateSha(const AValue: String);
var
  I: Integer;
begin
  if Length(AValue) <> 64 then
    raise EAudio.Create('Tempo source SHA-256 must have 64 lowercase hex digits');
  for I := 1 to 64 do
    if not (AValue[I] in ['0'..'9', 'a'..'f']) then
      raise EAudio.Create('Tempo source SHA-256 must have 64 lowercase hex digits');
end;

procedure ValidateSpan(const ASpan: TTempoEvidenceSpan;
  const AExpectedStart, ASourceFrames: Integer);
begin
  if (ASpan.StartFrame <> AExpectedStart) or
    (ASpan.EndFrame <= ASpan.StartFrame) or
    (ASpan.EndFrame > ASourceFrames) then
    raise EAudio.Create('Tempo evidence spans must cover the source contiguously');
  if not (ASpan.Availability in [teaKnown, teaUnavailable, teaAmbiguous]) or
    not (ASpan.SelectionOrigin in [tsoNone, tsoAutomatic, tsoCallerOverride]) then
    raise EAudio.Create('Tempo evidence enum is invalid');
  if (ASpan.ObservedMicroseconds < 0) or
    (ASpan.ObservedMicroseconds > MaximumTempoMicroseconds) or
    (ASpan.SelectedMicroseconds < 0) or
    (ASpan.SelectedMicroseconds > MaximumTempoMicroseconds) then
    raise EAudio.Create('Tempo evidence microseconds exceed bounds');
  if (ASpan.Availability = teaKnown) and (ASpan.ObservedMicroseconds = 0) then
    raise EAudio.Create('Known tempo requires a positive observation');
  if (ASpan.Availability = teaUnavailable) and
    (ASpan.ObservedMicroseconds <> 0) then
    raise EAudio.Create('Unavailable tempo cannot carry an observation');
  case ASpan.SelectionOrigin of
    tsoNone:
      if ASpan.SelectedMicroseconds <> 0 then
        raise EAudio.Create('Unselected tempo must remain zero');
    tsoAutomatic:
      if (ASpan.Availability <> teaKnown) or
        (ASpan.SelectedMicroseconds = 0) or
        (ASpan.SelectedMicroseconds <> ASpan.ObservedMicroseconds) then
        raise EAudio.Create('Automatic tempo needs the known observed value');
    tsoCallerOverride:
      if ASpan.SelectedMicroseconds = 0 then
        raise EAudio.Create('Caller tempo override must be positive');
  end;
end;

constructor TTempoEvidence.Create(const ASourceSha256: String;
  const ASourceFrames, ASampleRate: Integer;
  const AMeasurementIdentity, AAdmissionPolicyIdentity: String;
  const ASpans: TTempoEvidenceSpans);
var
  I, Expected: Integer;
begin
  inherited Create;
  ValidateSha(ASourceSha256);
  ValidateIdentity(AMeasurementIdentity, 'Measurement');
  ValidateIdentity(AAdmissionPolicyIdentity, 'Admission policy');
  if (ASourceFrames < 1) or (ASampleRate < 8000) or
    (ASampleRate > 384000) or (Length(ASpans) < 1) or
    (Length(ASpans) > MaximumTempoEvidenceSpans) then
    raise EAudio.Create('Tempo evidence source or span budget is invalid');
  Expected := 0;
  for I := 0 to High(ASpans) do
  begin
    ValidateSpan(ASpans[I], Expected, ASourceFrames);
    Expected := ASpans[I].EndFrame;
  end;
  if Expected <> ASourceFrames then
    raise EAudio.Create('Tempo evidence must cover the complete source');
  FSourceSha256 := ASourceSha256;
  FSourceFrames := ASourceFrames;
  FSampleRate := ASampleRate;
  FMeasurementIdentity := AMeasurementIdentity;
  FAdmissionPolicyIdentity := AAdmissionPolicyIdentity;
  FSpans := Copy(ASpans);
end;

function TTempoEvidence.CopySpans: TTempoEvidenceSpans;
begin
  Result := Copy(FSpans);
end;

function TTempoEvidence.RequireConstantSelectedTempo(const AStartFrame,
  AEndFrame: Integer): Integer;
var
  I: Integer;
  Seen: Boolean;
begin
  if (AStartFrame < 0) or (AEndFrame <= AStartFrame) or
    (AEndFrame > FSourceFrames) then
    raise EAudio.Create('Selected tempo query lies outside source');
  Result := 0;
  Seen := False;
  for I := 0 to High(FSpans) do
  begin
    if FSpans[I].EndFrame <= AStartFrame then Continue;
    if FSpans[I].StartFrame >= AEndFrame then Break;
    if (FSpans[I].SelectedMicroseconds = 0) or
      ((FSpans[I].Availability <> teaKnown) and
       (FSpans[I].SelectionOrigin <> tsoCallerOverride)) then
      raise EAudio.Create('Requested source range has unknown selected tempo');
    if Seen and (Result <> FSpans[I].SelectedMicroseconds) then
      raise EAudio.Create('Requested source range has mixed selected tempos');
    Result := FSpans[I].SelectedMicroseconds;
    Seen := True;
  end;
  if not Seen then raise EAudio.Create('Selected tempo query has no evidence');
end;

procedure Put32(var ABytes: TAudioBytes; var APos: Integer; const AValue: Cardinal);
var I: Integer;
begin
  for I := 0 to 3 do ABytes[APos + I] := (AValue shr (8 * I)) and $FF;
  Inc(APos, 4);
end;

function Get32(const ABytes: TAudioBytes; var APos: Integer;
  const ALimit: Integer): Cardinal;
var I: Integer;
begin
  if (APos < 0) or (APos > ALimit - 4) then
    raise EAudio.Create('Tempo evidence field truncated');
  Result := 0;
  for I := 0 to 3 do Result := Result or (Cardinal(ABytes[APos + I]) shl (8 * I));
  Inc(APos, 4);
end;

procedure PutText(var ABytes: TAudioBytes; var APos: Integer; const AText: String);
var I: Integer;
begin
  Put32(ABytes, APos, Length(AText));
  for I := 1 to Length(AText) do ABytes[APos + I - 1] := Ord(AText[I]);
  Inc(APos, Length(AText));
end;

function GetText(const ABytes: TAudioBytes; var APos: Integer;
  const ALimit: Integer): String;
var L, I: Integer;
begin
  L := Get32(ABytes, APos, ALimit);
  if (L < 1) or (L > MaximumIdentityLength) or (APos > ALimit - L) then
    raise EAudio.Create('Tempo evidence identity field is invalid');
  SetLength(Result, L);
  for I := 1 to L do Result[I] := Chr(ABytes[APos + I - 1]);
  Inc(APos, L);
end;

function EncodeTempoEvidence(const AEvidence: TTempoEvidence): TAudioBytes;
var Posn, I, BodyBytes: Integer; Spans: TTempoEvidenceSpans; Digest: String;
begin
  Result := nil;
  if AEvidence = nil then raise EAudio.Create('Tempo evidence is nil');
  Spans := AEvidence.CopySpans;
  BodyBytes := 20 + 4 + 64 + 4 + Length(AEvidence.MeasurementIdentity) +
    4 + Length(AEvidence.AdmissionPolicyIdentity) + Length(Spans) * 24;
  if BodyBytes + 64 > MaximumTempoEvidenceBytes then
    raise EAudio.Create('Tempo evidence byte budget exceeded');
  SetLength(Result, BodyBytes + 64);
  Posn := 0;
  Put32(Result, Posn, EvidenceMagic);
  Put32(Result, Posn, TempoEvidenceVersion);
  Put32(Result, Posn, AEvidence.SourceFrames);
  Put32(Result, Posn, AEvidence.SampleRate);
  Put32(Result, Posn, Length(Spans));
  PutText(Result, Posn, AEvidence.SourceSha256);
  PutText(Result, Posn, AEvidence.MeasurementIdentity);
  PutText(Result, Posn, AEvidence.AdmissionPolicyIdentity);
  for I := 0 to High(Spans) do
  begin
    Put32(Result, Posn, Spans[I].StartFrame);
    Put32(Result, Posn, Spans[I].EndFrame);
    Put32(Result, Posn, Ord(Spans[I].Availability));
    Put32(Result, Posn, Spans[I].ObservedMicroseconds);
    Put32(Result, Posn, Spans[I].SelectedMicroseconds);
    Put32(Result, Posn, Ord(Spans[I].SelectionOrigin));
  end;
  if Posn <> BodyBytes then raise EAudio.Create('Tempo evidence encoding length mismatch');
  SetLength(Result, BodyBytes);
  Digest := Sha256Bytes(Result);
  SetLength(Result, BodyBytes + 64);
  Move(Digest[1], Result[BodyBytes], 64);
end;

function DecodeTempoEvidence(const ABytes: TAudioBytes): TTempoEvidence;
var Posn, BodyBytes, Count, I: Integer; SourceFrames, SampleRate: Cardinal;
    SourceSha, Measurement, Policy, Digest: String;
    Spans: TTempoEvidenceSpans; Body: TAudioBytes; N: Cardinal;
begin
  Result := nil;
  if (Length(ABytes) < 20 + 4 + 64 + 4 + 1 + 4 + 1 + 24 + 64) or
    (Length(ABytes) > MaximumTempoEvidenceBytes) then
    raise EAudio.Create('Tempo evidence byte budget or minimum length is invalid');
  BodyBytes := Length(ABytes) - 64;
  SetLength(Body, BodyBytes);
  Move(ABytes[0], Body[0], BodyBytes);
  Digest := Sha256Bytes(Body);
  for I := 1 to 64 do if ABytes[BodyBytes + I - 1] <> Ord(Digest[I]) then
    raise EAudio.Create('Tempo evidence SHA-256 mismatch');
  Posn := 0;
  if Get32(ABytes, Posn, BodyBytes) <> EvidenceMagic then
    raise EAudio.Create('Tempo evidence magic mismatch');
  if Get32(ABytes, Posn, BodyBytes) <> TempoEvidenceVersion then
    raise EAudio.Create('Tempo evidence version mismatch');
  SourceFrames := Get32(ABytes, Posn, BodyBytes);
  SampleRate := Get32(ABytes, Posn, BodyBytes);
  N := Get32(ABytes, Posn, BodyBytes);
  if (SourceFrames > High(Integer)) or (SampleRate > High(Integer)) or
    (N < 1) or (N > MaximumTempoEvidenceSpans) then
    raise EAudio.Create('Tempo evidence decoded geometry exceeds bounds');
  Count := N;
  SourceSha := GetText(ABytes, Posn, BodyBytes);
  Measurement := GetText(ABytes, Posn, BodyBytes);
  Policy := GetText(ABytes, Posn, BodyBytes);
  if (Int64(Count) * 24 <> BodyBytes - Posn) then
    raise EAudio.Create('Tempo evidence span byte count mismatch');
  SetLength(Spans, Count);
  for I := 0 to Count - 1 do
  begin
    N := Get32(ABytes, Posn, BodyBytes);
    if N > High(Integer) then raise EAudio.Create('Tempo span start exceeds Integer');
    Spans[I].StartFrame := N;
    N := Get32(ABytes, Posn, BodyBytes);
    if N > High(Integer) then raise EAudio.Create('Tempo span end exceeds Integer');
    Spans[I].EndFrame := N;
    N := Get32(ABytes, Posn, BodyBytes);
    if N > Ord(High(TTempoEvidenceAvailability)) then
      raise EAudio.Create('Tempo availability code is invalid');
    Spans[I].Availability := TTempoEvidenceAvailability(N);
    N := Get32(ABytes, Posn, BodyBytes);
    if N > High(Integer) then raise EAudio.Create('Observed tempo exceeds Integer');
    Spans[I].ObservedMicroseconds := N;
    N := Get32(ABytes, Posn, BodyBytes);
    if N > High(Integer) then raise EAudio.Create('Selected tempo exceeds Integer');
    Spans[I].SelectedMicroseconds := N;
    N := Get32(ABytes, Posn, BodyBytes);
    if N > Ord(High(TTempoSelectionOrigin)) then
      raise EAudio.Create('Tempo selection origin code is invalid');
    Spans[I].SelectionOrigin := TTempoSelectionOrigin(N);
  end;
  Result := TTempoEvidence.Create(SourceSha, SourceFrames, SampleRate,
    Measurement, Policy, Spans);
end;

end.
