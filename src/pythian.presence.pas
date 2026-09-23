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
unit pythian.presence;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  PresencePolicyVersion = 1;
  PresencePolicyId = 'pythian.presence.rest-contrast.v1';
  MaximumPresenceWindowFrames = 262144;

type
  TPresenceEvidence = (peExactZero, peAboveReviewedRest,
    peCompatibleWithReviewedRest, peUnknown);

  TPresenceObservation = record
    PolicyId: String;
    SampleRate: Integer;
    Channels: Integer;
    SourceFrameCount: Int64;
    StartFrame: Int64;
    FrameCount: Integer;
    ReferenceStartFrame: Int64;
    ReferenceFrameCount: Integer;
    ReferenceId: String;
    ReferenceReviewed: Boolean;
    CandidateRms: Double;
    CandidatePeak: Double;
    EarlyRms: Double;
    LateRms: Double;
    ReferenceRms: Double;
    Evidence: TPresenceEvidence;
  end;

  { Borrows immutable source content. ReadWindow supplies exactly Count
    interleaved frames or raises. The source may seek; it is not reentrant. }
  TPresenceSource = class abstract
  strict private
    FSampleRate: Integer;
    FChannels: Integer;
    FFrameCount: Int64;
  public
    constructor Create(const ASampleRate, AChannels: Integer;
      const AFrameCount: Int64);
    procedure ReadWindow(const AStartFrame: Int64; const AFrameCount: Integer;
      out ASamples: TAudioSamples); virtual; abstract;
    property SampleRate: Integer read FSampleRate;
    property Channels: Integer read FChannels;
    property FrameCount: Int64 read FFrameCount;
  end;

{ Exact-window signal contrast against a disjoint same-clip rest reference.
  A reviewed reference is a caller assertion, not something PCM can verify.
  Above-rest evidence does not identify an audible instrument or a note.
  Both windows are bounded; invalid input raises before returning a result. }
function ObservePresence(const AClip: TAudioClip;
  const AStartFrame, AFrameCount, AReferenceStartFrame,
  AReferenceFrameCount: Integer; const AReferenceId: String;
  const AReferenceReviewed: Boolean): TPresenceObservation;
function ObservePresenceSource(const ASource: TPresenceSource;
  const AStartFrame: Int64; const AFrameCount: Integer;
  const AReferenceStartFrame: Int64; const AReferenceFrameCount: Integer;
  const AReferenceId: String;
  const AReferenceReviewed: Boolean): TPresenceObservation;

implementation

uses
  Math;

type
  TClipPresenceSource = class(TPresenceSource)
  strict private
    FClip: TAudioClip;
  public
    constructor Create(const AClip: TAudioClip);
    procedure ReadWindow(const AStartFrame: Int64; const AFrameCount: Integer;
      out ASamples: TAudioSamples); override;
  end;

constructor TPresenceSource.Create(const ASampleRate, AChannels: Integer;
  const AFrameCount: Int64);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, AChannels);
  if AFrameCount < 0 then
    raise EAudio.Create('Presence source frame extent is invalid');
  FSampleRate := ASampleRate;
  FChannels := AChannels;
  FFrameCount := AFrameCount;
end;

constructor TClipPresenceSource.Create(const AClip: TAudioClip);
begin
  if AClip = nil then
    raise EAudio.Create('Presence clip is required');
  inherited Create(AClip.SampleRate, AClip.Channels, AClip.FrameCount);
  FClip := AClip;
end;

procedure TClipPresenceSource.ReadWindow(const AStartFrame: Int64;
  const AFrameCount: Integer; out ASamples: TAudioSamples);
var
  LFrame: Integer;
  LChannel: Integer;
begin
  SetLength(ASamples, AFrameCount * Channels);
  for LFrame := 0 to AFrameCount - 1 do
    for LChannel := 0 to Channels - 1 do
      ASamples[LFrame * Channels + LChannel] :=
        FClip.SampleAt(Integer(AStartFrame + LFrame), LChannel);
end;

procedure ValidateWindow(const ASource: TPresenceSource; const AStart: Int64;
  ACount: Integer; const AName: String);
begin
  if (AStart < 0) or (ACount < 2) or
    (ACount > MaximumPresenceWindowFrames) or
    (AStart > ASource.FrameCount) then
  begin
    raise EAudio.Create(AName + ' lies outside the bounded source extent');
  end;
  if ACount > ASource.FrameCount - AStart then
  begin
    raise EAudio.Create(AName + ' lies outside the bounded source extent');
  end;
end;

procedure MeasureWindow(const ASource: TPresenceSource; const AStart: Int64;
  ACount: Integer; out ARms, APeak, AEarlyRms, ALateRms: Double);
var
  LSamples: TAudioSamples;
  LFrame: Integer;
  LChannel: Integer;
  LSample: Double;
  LSquared: Double;
  LTotalPower: Double;
  LEarlyPower: Double;
  LLatePower: Double;
  LEarlyFrames: Integer;
begin
  LSamples := nil;
  ASource.ReadWindow(AStart, ACount, LSamples);
  if Length(LSamples) <> ACount * ASource.Channels then
    raise EAudio.Create('Presence source returned a partial window');
  LTotalPower := 0;
  LEarlyPower := 0;
  LLatePower := 0;
  APeak := 0;
  LEarlyFrames := (ACount + 1) div 2;
  for LFrame := 0 to ACount - 1 do
  begin
    for LChannel := 0 to ASource.Channels - 1 do
    begin
      LSample := LSamples[LFrame * ASource.Channels + LChannel];
      RequireFinite(LSample, 'Presence sample');
      LSquared := LSample * LSample;
      LTotalPower := LTotalPower + LSquared;
      APeak := Max(APeak, Abs(LSample));
      if LFrame < LEarlyFrames then
        LEarlyPower := LEarlyPower + LSquared
      else
        LLatePower := LLatePower + LSquared;
    end;
  end;
  ARms := Sqrt(LTotalPower / (Int64(ACount) * ASource.Channels));
  AEarlyRms := Sqrt(LEarlyPower /
    (Int64(LEarlyFrames) * ASource.Channels));
  ALateRms := Sqrt(LLatePower /
    (Int64(ACount - LEarlyFrames) * ASource.Channels));
end;

function ObservePresence(const AClip: TAudioClip;
  const AStartFrame, AFrameCount, AReferenceStartFrame,
  AReferenceFrameCount: Integer; const AReferenceId: String;
  const AReferenceReviewed: Boolean): TPresenceObservation;
var
  LSource: TClipPresenceSource;
begin
  LSource := TClipPresenceSource.Create(AClip);
  try
    Result := ObservePresenceSource(LSource, AStartFrame, AFrameCount,
      AReferenceStartFrame, AReferenceFrameCount, AReferenceId,
      AReferenceReviewed);
  finally
    LSource.Free;
  end;
end;

function ObservePresenceSource(const ASource: TPresenceSource;
  const AStartFrame: Int64; const AFrameCount: Integer;
  const AReferenceStartFrame: Int64; const AReferenceFrameCount: Integer;
  const AReferenceId: String;
  const AReferenceReviewed: Boolean): TPresenceObservation;
var
  LUnusedEarly: Double;
  LUnusedLate: Double;
  LUnusedPeak: Double;
begin
  if ASource = nil then
    raise EAudio.Create('Presence source is required');
  ValidateWindow(ASource, AStartFrame, AFrameCount, 'Candidate window');
  ValidateWindow(ASource, AReferenceStartFrame, AReferenceFrameCount,
    'Reference window');
  if (Int64(AStartFrame) < Int64(AReferenceStartFrame) +
    AReferenceFrameCount) and
    (Int64(AReferenceStartFrame) < Int64(AStartFrame) + AFrameCount) then
    raise EAudio.Create('Candidate and reference windows overlap');
  if AReferenceReviewed and (AReferenceId = '') then
    raise EAudio.Create('Reviewed rest requires a source-bound identity');

  Result := Default(TPresenceObservation);
  Result.PolicyId := PresencePolicyId;
  Result.SampleRate := ASource.SampleRate;
  Result.Channels := ASource.Channels;
  Result.SourceFrameCount := ASource.FrameCount;
  Result.StartFrame := AStartFrame;
  Result.FrameCount := AFrameCount;
  Result.ReferenceStartFrame := AReferenceStartFrame;
  Result.ReferenceFrameCount := AReferenceFrameCount;
  Result.ReferenceId := AReferenceId;
  Result.ReferenceReviewed := AReferenceReviewed;
  MeasureWindow(ASource, AStartFrame, AFrameCount,
    Result.CandidateRms, Result.CandidatePeak,
    Result.EarlyRms, Result.LateRms);
  MeasureWindow(ASource, AReferenceStartFrame, AReferenceFrameCount,
    Result.ReferenceRms, LUnusedPeak, LUnusedEarly, LUnusedLate);

  if Result.CandidateRms = 0 then
    Result.Evidence := peExactZero
  else if not AReferenceReviewed or (Result.ReferenceRms = 0) then
    Result.Evidence := peUnknown
  else if Result.CandidateRms >= 4 * Result.ReferenceRms then
    Result.Evidence := peAboveReviewedRest
  else if Result.CandidateRms <= 1.5 * Result.ReferenceRms then
    Result.Evidence := peCompatibleWithReviewedRest
  else
    Result.Evidence := peUnknown;
end;

end.
