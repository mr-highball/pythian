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
program pythian_tests_tempo_evidence;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.hash,
  pythian.music.tempo.evidence;

const
  SourceHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

procedure Check(const AValue: Boolean; const AName: String);
begin
  if not AValue then raise Exception.Create(AName);
end;

function BaseSpans: TTempoEvidenceSpans;
begin
  Result := nil;
  SetLength(Result, 3);
  Result[0].StartFrame := 0;
  Result[0].EndFrame := 1000;
  Result[0].Availability := teaKnown;
  Result[0].ObservedMicroseconds := 500000;
  Result[0].SelectedMicroseconds := 500000;
  Result[0].SelectionOrigin := tsoAutomatic;
  Result[1].StartFrame := 1000;
  Result[1].EndFrame := 2000;
  Result[1].Availability := teaUnavailable;
  Result[1].ObservedMicroseconds := 0;
  Result[1].SelectedMicroseconds := 0;
  Result[1].SelectionOrigin := tsoNone;
  Result[2].StartFrame := 2000;
  Result[2].EndFrame := 3000;
  Result[2].Availability := teaKnown;
  Result[2].ObservedMicroseconds := 600000;
  Result[2].SelectedMicroseconds := 600000;
  Result[2].SelectionOrigin := tsoAutomatic;
end;

function MakeEvidence(const ASpans: TTempoEvidenceSpans): TTempoEvidence;
begin
  Result := TTempoEvidence.Create(SourceHash, 3000, 48000,
    'measure.raw.v1', 'admit.explicit.v1', ASpans);
end;

procedure ExpectCreateFailure(const ASpans: TTempoEvidenceSpans;
  const AName: String);
var E: TTempoEvidence; Rejected: Boolean;
begin
  Rejected := False; E := nil;
  try E := MakeEvidence(ASpans) except on X:EAudio do Rejected := True end;
  E.Free;
  Check(Rejected, AName);
end;

procedure ExpectDecodeFailure(const ABytes: TAudioBytes; const AName: String);
var E: TTempoEvidence; Rejected: Boolean;
begin
  Rejected := False; E := nil;
  try E := DecodeTempoEvidence(ABytes) except on X:EAudio do Rejected := True end;
  E.Free;
  Check(Rejected, AName);
end;

procedure Reseal(var ABytes: TAudioBytes);
var Body: TAudioBytes; Digest: String; I: Integer;
begin
  SetLength(Body, Length(ABytes)-64);
  Move(ABytes[0], Body[0], Length(Body));
  Digest := Sha256Bytes(Body);
  for I := 1 to 64 do ABytes[Length(Body)+I-1] := Ord(Digest[I]);
end;

procedure PositiveAndRoundTrip;
var Spans, CopySpans: TTempoEvidenceSpans; E,D: TTempoEvidence;
    Bytes, Replay: TAudioBytes; Rejected: Boolean;
begin
  Spans := BaseSpans;
  E := MakeEvidence(Spans);
  try
    Spans[0].ObservedMicroseconds := 1;
    CopySpans := E.CopySpans;
    Check(CopySpans[0].ObservedMicroseconds=500000, 'input alias');
    CopySpans[0].ObservedMicroseconds := 2;
    Check(E.CopySpans[0].ObservedMicroseconds=500000, 'output alias');
    Check(E.RequireConstantSelectedTempo(0,1000)=500000, 'known query');
    Rejected := False;
    try E.RequireConstantSelectedTempo(0,1001)
    except on X:EAudio do Rejected := True end;
    Check(Rejected,'one frame across half-open unknown boundary must reject');
    Rejected := False;
    try E.RequireConstantSelectedTempo(1000,2000)
    except on X:EAudio do Rejected := True end;
    Check(Rejected,'unknown cannot imply BPM');
    Bytes := EncodeTempoEvidence(E);
    D := DecodeTempoEvidence(Bytes);
    try
      Replay := EncodeTempoEvidence(D);
      Check(Sha256Bytes(Bytes)=Sha256Bytes(Replay), 'deterministic roundtrip');
      Check(D.SourceFrames=3000, 'source frame identity');
      Check(D.CopySpans[1].Availability=teaUnavailable, 'unknown persistence');
      Check(D.CopySpans[1].SelectionOrigin=tsoNone, 'unknown origin');
      WriteLn('v1_bytes=',Length(Bytes),' sha256=',Sha256Bytes(Bytes));
    finally D.Free end;
  finally E.Free end;

  Spans := BaseSpans;
  Spans[1].Availability := teaAmbiguous;
  Spans[1].ObservedMicroseconds := 490000;
  E := MakeEvidence(Spans);
  try
    D := DecodeTempoEvidence(EncodeTempoEvidence(E));
    try
      CopySpans := D.CopySpans;
      Check((CopySpans[1].Availability=teaAmbiguous) and
        (CopySpans[1].ObservedMicroseconds=490000) and
        (CopySpans[1].SelectedMicroseconds=0) and
        (CopySpans[1].SelectionOrigin=tsoNone),
        'ambiguous observed candidate roundtrip');
      Rejected := False;
      try D.RequireConstantSelectedTempo(1000,2000)
      except on X:EAudio do Rejected := True end;
      Check(Rejected,'reloaded ambiguous observed candidate must remain unselected');
    finally D.Free end;
  finally E.Free end;

  Spans := BaseSpans;
  Spans[1].SelectionOrigin := tsoCallerOverride;
  Spans[1].SelectedMicroseconds := 500000;
  E := MakeEvidence(Spans);
  try
    Check(E.RequireConstantSelectedTempo(0,2000)=500000,
      'override must allow constant selected range');
    Rejected := False;
    try E.RequireConstantSelectedTempo(0,3000)
    except on X:EAudio do Rejected := True end;
    Check(Rejected,'mixed selection must reject');
    D := DecodeTempoEvidence(EncodeTempoEvidence(E));
    try
      Check((D.CopySpans[1].Availability=teaUnavailable) and
        (D.CopySpans[1].ObservedMicroseconds=0) and
        (D.CopySpans[1].SelectionOrigin=tsoCallerOverride) and
        (D.CopySpans[1].SelectedMicroseconds=500000), 'override trace');
    finally D.Free end;
  finally E.Free end;
  WriteLn('known-unknown-known and override roundtrip PASS');
end;

procedure NegativeChecks;
var Spans: TTempoEvidenceSpans; E: TTempoEvidence;
    Bytes, Broken: TAudioBytes; Rejected: Boolean; SpanStart: Integer;
begin
  Spans := BaseSpans; Spans[1].StartFrame := 1001;
  ExpectCreateFailure(Spans,'gap');
  Spans := BaseSpans; Spans[2].StartFrame := 1999;
  ExpectCreateFailure(Spans,'overlap');
  Spans := BaseSpans; Spans[2].EndFrame := 2999;
  ExpectCreateFailure(Spans,'incomplete source');
  Spans := BaseSpans; Spans[1].SelectionOrigin := tsoAutomatic;
  Spans[1].SelectedMicroseconds := 500000;
  ExpectCreateFailure(Spans,'invented automatic unknown');
  Spans := BaseSpans; Spans[1].SelectedMicroseconds := 500000;
  ExpectCreateFailure(Spans,'selection without origin');
  Spans := BaseSpans; Spans[1].ObservedMicroseconds := 500000;
  ExpectCreateFailure(Spans,'unavailable observation');
  Spans := BaseSpans; Spans[0].ObservedMicroseconds := 0;
  ExpectCreateFailure(Spans,'known without observation');
  Spans := BaseSpans; Spans[0].SelectionOrigin := tsoAutomatic;
  Spans[0].SelectedMicroseconds := 500001;
  ExpectCreateFailure(Spans,'automatic changed value');
  Spans := BaseSpans;
  E := MakeEvidence(Spans);
  try Bytes := EncodeTempoEvidence(E) finally E.Free end;
  Broken := Copy(Bytes); Broken[15] := Broken[15] xor 1;
  ExpectDecodeFailure(Broken,'checksum corruption');
  Broken := Copy(Bytes); Broken[20] := 255; Reseal(Broken);
  ExpectDecodeFailure(Broken,'malformed identity with valid digest');
  SpanStart := Length(Bytes)-64-3*24;
  Broken := Copy(Bytes); Broken[SpanStart+8] := 255; Reseal(Broken);
  ExpectDecodeFailure(Broken,'invalid availability with valid digest');
  Broken := Copy(Bytes); Broken[SpanStart+20] := 255; Reseal(Broken);
  ExpectDecodeFailure(Broken,'invalid selection origin with valid digest');
  Broken := Copy(Bytes); Broken[12] := 0; Broken[13] := 0;
  Broken[14] := 0; Broken[15] := 0; Reseal(Broken);
  ExpectDecodeFailure(Broken,'zero sample rate with valid digest');
  Rejected := False;
  try E := TTempoEvidence.Create(UpperCase(SourceHash),3000,48000,
    'measure.raw.v1','admit.explicit.v1',Spans)
  except on X:EAudio do Rejected := True end;
  if not Rejected then E.Free;
  Check(Rejected,'uppercase source hash');
  SetLength(Spans,MaximumTempoEvidenceSpans+1);
  Rejected := False;
  try E := MakeEvidence(Spans)
  except on X:EAudio do Rejected := True end;
  if not Rejected then E.Free;
  Check(Rejected,'span budget');
  SetLength(Broken,MaximumTempoEvidenceBytes+1);
  ExpectDecodeFailure(Broken,'byte budget');
  WriteLn('malformed geometry, status, checksum and budgets PASS');
end;

begin
  try
    PositiveAndRoundTrip;
    NegativeChecks;
    WriteLn('tempo evidence PASS');
  except on E:Exception do begin WriteLn(StdErr,'FAIL ',E.Message); Halt(1) end end;
end.
