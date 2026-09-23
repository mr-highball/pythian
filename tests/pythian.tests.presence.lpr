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
program pythian_tests_presence;

{$mode delphi}
{$H+}

uses
  Math, SysUtils, pythian.audio, pythian.presence;

type
  TLongPresenceSource = class(TPresenceSource)
  public
    ReturnPartial: Boolean;
    constructor Create;
    procedure ReadWindow(const AStartFrame: Int64; const AFrameCount: Integer;
      out ASamples: TAudioSamples); override;
  end;

constructor TLongPresenceSource.Create;
begin
  inherited Create(8000, 1, Int64(High(Integer)) + 1000);
end;

procedure TLongPresenceSource.ReadWindow(const AStartFrame: Int64;
  const AFrameCount: Integer; out ASamples: TAudioSamples);
var
  LIndex: Integer;
  LLevel: Single;
begin
  if ReturnPartial then
    SetLength(ASamples, AFrameCount - 1)
  else
    SetLength(ASamples, AFrameCount);
  if AStartFrame = Int64(High(Integer)) + 100 then
    LLevel := 0.001
  else
    LLevel := 0.01;
  for LIndex := 0 to High(ASamples) do
    ASamples[LIndex] := LLevel;
end;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
    raise Exception.Create(AMessage);
end;

procedure FillWindow(var ASamples: TAudioSamples; const AStart,
  ACount: Integer; const ALevel: Single);
var
  LIndex: Integer;
begin
  for LIndex := AStart to AStart + ACount - 1 do
  begin
    if (LIndex and 1) = 0 then
      ASamples[LIndex] := ALevel
    else
      ASamples[LIndex] := -ALevel;
  end;
end;

procedure CheckWindowEvidence;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LObservation: TPresenceObservation;
  LReplay: TPresenceObservation;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LSamples, 1700);
  FillWindow(LSamples, 0, 100, 0.001);
  FillWindow(LSamples, 200, 50, 0.04);
  FillWindow(LSamples, 250, 50, 0.01);
  FillWindow(LSamples, 300, 100, 0.005);
  FillWindow(LSamples, 400, 100, 0.0012);
  FillWindow(LSamples, 500, 100, 0.0025);
  for LIndex := 600 to 699 do
  begin
    if LIndex < 673 then
      LSamples[LIndex] := 0.01
    else
      LSamples[LIndex] := -0.01;
  end;
  FillWindow(LSamples, 700, 10, 0.03);
  for LIndex := 900 to 999 do
  begin
    if (LIndex and 1) = 0 then
      LSamples[LIndex] := 0.01
    else
      LSamples[LIndex] := -0.005;
  end;
  for LIndex := 1000 to 1239 do
    LSamples[LIndex] := 0.005 * Sin(2 * Pi * 55 *
      (LIndex - 1000) / 8000);
  for LIndex := 1300 to 1539 do
    LSamples[LIndex] := 0.01 * Sin(2 * Pi * 220 *
      (LIndex - 1300) / 8000) + 0.005 * Sin(2 * Pi * 330 *
      (LIndex - 1300) / 8000);
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LObservation := ObservePresence(LClip, 100, 100, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peExactZero, 'Exact-zero gap evidence');
    Check((LObservation.StartFrame = 100) and
      (LObservation.FrameCount = 100) and
      (LObservation.ReferenceStartFrame = 0) and
      (LObservation.ReferenceFrameCount = 100) and
      (LObservation.SampleRate = 8000) and
      (LObservation.Channels = 1) and
      (LObservation.SourceFrameCount = 1700),
      'Original source coordinates');
    Check(LObservation.PolicyId = PresencePolicyId, 'Policy identity');

    LObservation := ObservePresence(LClip, 200, 100, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peAboveReviewedRest,
      'Attack and fading continuation contrast');
    Check((LObservation.EarlyRms > LObservation.LateRms) and
      (LObservation.CandidatePeak > LObservation.CandidateRms),
      'Attack/tail envelope measurements');
    LReplay := ObservePresence(LClip, 200, 100, 0, 100,
      'reviewed-rest-1', True);
    Check((LReplay.CandidateRms = LObservation.CandidateRms) and
      (LReplay.Evidence = LObservation.Evidence) and
      (LReplay.ReferenceId = LObservation.ReferenceId),
      'Deterministic repeated observation');

    LObservation := ObservePresence(LClip, 300, 100, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peAboveReviewedRest,
      'Quiet source above known rest');
    LObservation := ObservePresence(LClip, 400, 100, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peCompatibleWithReviewedRest,
      'Noise-compatible source remains evidence only');
    LObservation := ObservePresence(LClip, 500, 100, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peUnknown, 'Ambiguous contrast is unknown');
    LObservation := ObservePresence(LClip, 600, 100, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peAboveReviewedRest,
      'Sustained candidate remains visible');
    LObservation := ObservePresence(LClip, 700, 100, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peAboveReviewedRest,
      'Short attack source remains visible');
    LObservation := ObservePresence(LClip, 800, 100, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peExactZero, 'Second gap stays exact zero');
    LObservation := ObservePresence(LClip, 900, 100, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peAboveReviewedRest,
      'Mixed-amplitude source is measured');
    LObservation := ObservePresence(LClip, 1000, 240, 0, 100,
      'reviewed-rest-1', True);
    Check((LObservation.Evidence = peUnknown) and
      (LObservation.CandidateRms > 0),
      'Quiet 30-ms 55-Hz signal must remain measured and uncertain');
    LObservation := ObservePresence(LClip, 1300, 240, 0, 100,
      'reviewed-rest-1', True);
    Check(LObservation.Evidence = peAboveReviewedRest,
      '220/330-Hz mixture is activity contrast, not one note');

    LObservation := ObservePresence(LClip, 200, 100, 0, 100, '', False);
    Check(LObservation.Evidence = peUnknown,
      'Unreviewed rest cannot support an activity contrast');
    LObservation := ObservePresence(LClip, 200, 100, 100, 100,
      'zero-rest', True);
    Check(LObservation.Evidence = peUnknown,
      'Nonzero source against exact-zero rest stays unknown');

    LObservation := ObservePresence(LClip, 200, 100, 0, 100,
      'reviewed-rest-1', True);
    LRejected := False;
    try
      LObservation := ObservePresence(LClip, 50, 100, 0, 100,
        'reviewed-rest-1', True);
    except
      on EAudio do
        LRejected := True;
    end;
    Check(LRejected and (LObservation.StartFrame = 200),
      'Overlapping input rejects without overwriting prior observation');
    LRejected := False;
    try
      LObservation := ObservePresence(LClip, 1650, 100, 0, 100,
        'reviewed-rest-1', True);
    except
      on EAudio do
        LRejected := True;
    end;
    Check(LRejected and (LObservation.StartFrame = 200),
      'Out-of-range input preserves prior observation');
    LRejected := False;
    try
      ObservePresence(LClip, 200, 100, 0, 100, '', True);
    except
      on EAudio do
        LRejected := True;
    end;
    Check(LRejected, 'Reviewed reference requires an identity');
    LRejected := False;
    try
      ObservePresence(LClip, 200, MaximumPresenceWindowFrames + 1,
        0, 100, 'reviewed-rest-1', True);
    except
      on EAudio do
        LRejected := True;
    end;
    Check(LRejected, 'Presence work cap');
  finally
    LClip.Free;
  end;
end;

procedure CheckStereoPower;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LIndex: Integer;
  LObservation: TPresenceObservation;
begin
  SetLength(LSamples, 400);
  for LIndex := 0 to 99 do
  begin
    LSamples[2 * LIndex] := 0.001;
    LSamples[2 * LIndex + 1] := -0.001;
    LSamples[200 + 2 * LIndex] := 0.01;
    LSamples[200 + 2 * LIndex + 1] := -0.01;
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LObservation := ObservePresence(LClip, 100, 100, 0, 100,
      'stereo-rest', True);
    Check((LObservation.Evidence = peAboveReviewedRest) and
      (Abs(LObservation.CandidateRms - 0.01) < 0.000001),
      'Stereo phase opposition must not cancel power');
  finally
    LClip.Free;
  end;
end;

procedure CheckLongSource;
var
  LSource: TLongPresenceSource;
  LObservation: TPresenceObservation;
  LRejected: Boolean;
begin
  LSource := TLongPresenceSource.Create;
  try
    LObservation := ObservePresenceSource(LSource,
      Int64(High(Integer)) + 300, 100,
      Int64(High(Integer)) + 100, 100, 'long-source-rest', True);
    Check((LObservation.StartFrame = Int64(High(Integer)) + 300) and
      (LObservation.SourceFrameCount = Int64(High(Integer)) + 1000) and
      (LObservation.Evidence = peAboveReviewedRest),
      'Source-frame coordinates beyond 32-bit clip extent');
    LSource.ReturnPartial := True;
    LRejected := False;
    try
      LObservation := ObservePresenceSource(LSource,
        Int64(High(Integer)) + 300, 100,
        Int64(High(Integer)) + 100, 100, 'long-source-rest', True);
    except
      on EAudio do
        LRejected := True;
    end;
    Check(LRejected and
      (LObservation.StartFrame = Int64(High(Integer)) + 300),
      'Partial source read rejects and preserves prior observation');
    LSource.ReturnPartial := False;
    LRejected := False;
    try
      ObservePresenceSource(LSource, Low(Int64), 100,
        Int64(High(Integer)) + 100, 100, 'long-source-rest', True);
    except
      on EAudio do
        LRejected := True;
    end;
    Check(LRejected, 'Extreme negative frame coordinate rejects safely');
  finally
    LSource.Free;
  end;
end;

begin
  CheckWindowEvidence;
  CheckStereoPower;
  CheckLongSource;
  WriteLn('presence evidence boundary passed');
end.
