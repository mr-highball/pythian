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
unit pythian.synth.stream;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.synth,
  pythian.bus,
  pythian.schedule;

const
  SynthStreamBlockFrames = 2048;

type
  { Finite detached tone records with borrowed factories/automation/envelopes.
    Keep those definitions alive and unchanged through playback. Playing sources
    are admitted only at their start frame and own the scheduler's usual clones.
    Preflight includes release tails, exact simultaneous overlap and frame work.
    Output starts at frame zero; duration does not allocate an entire clip.
    Stable start order, then caller order, determines Double summation; the final
    stereo sample converts to Single once, as in TScheduledSynth.
    Invalid reads preserve state; source/processing errors poison the stream.
    No callbacks, devices, file I/O, reset or concurrent reads are supported. }
  TFrameToneStream = class
  private
    type
      TEvent = record
        Frame: Int64;
        ToneIndex: Integer;
        Starting: Boolean;
        Cost: Integer;
      end;
      TEvents = array of TEvent;
  private
    FTones: TFrameTones;
    FEvents: TEvents;
    FEventIndex: Integer;
    FGraph: TBusGraph;
    FSynth: TScheduledSynth;
    FSampleRate: Integer;
    FFrameCount: Int64;
    FEmittedFrames: Int64;
    FPeakVoices: Integer;
    FPeakWork: Integer;
    FReadLimit: Integer;
    FFailed: Boolean;
    FBusy: Boolean;
    procedure SortEvents;
    function GetFinished: Boolean;
  public
    constructor Create(const ATones: TFrameTones; const ASampleRate: Integer;
      const AMinimumFrames: Int64 = 0; const AVoiceLimit: Integer = 128;
      const AWorkLimit: Integer = 65536);
    destructor Destroy; override;
    { Returns 1..min(AMaxFrames, ReadLimit) frames, or False/nil at the end.
      ReadLimit also enforces the shared per-call weighted work budget. }
    function ReadSamples(const AMaxFrames: Integer; out ASamples: TAudioSamples): Boolean;
    property SampleRate: Integer read FSampleRate;
    property FrameCount: Int64 read FFrameCount;
    property EmittedFrames: Int64 read FEmittedFrames;
    property PeakVoices: Integer read FPeakVoices;
    property PeakFrameWork: Integer read FPeakWork;
    property ReadLimit: Integer read FReadLimit;
    property Finished: Boolean read GetFinished;
    property Failed: Boolean read FFailed;
  end;

implementation

uses
  Math,
  pythian.effects;

procedure TFrameToneStream.SortEvents;
var
  LBuffer: TEvents;
  LWidth: Integer;
  LStart: Integer;
  LMiddle: Integer;
  LEnd: Integer;
  LLeft: Integer;
  LRight: Integer;
  LOut: Integer;

  function Before(const ALeft, ARight: TEvent): Boolean;
  begin
    if ALeft.Frame <> ARight.Frame then
    begin
      Exit(ALeft.Frame < ARight.Frame);
    end;
    if ALeft.Starting <> ARight.Starting then
    begin
      Exit(not ALeft.Starting);
    end;
    Result := ALeft.ToneIndex <= ARight.ToneIndex;
  end;

begin
  SetLength(LBuffer, Length(FEvents));
  LWidth := 1;
  while LWidth < Length(FEvents) do
  begin
    LStart := 0;
    while LStart < Length(FEvents) do
    begin
      LMiddle := Min(LStart + LWidth, Length(FEvents));
      LEnd := Min(LMiddle + LWidth, Length(FEvents));
      LLeft := LStart;
      LRight := LMiddle;
      for LOut := LStart to LEnd - 1 do
      begin
        if (LLeft < LMiddle) and
          ((LRight >= LEnd) or Before(FEvents[LLeft], FEvents[LRight])) then
        begin
          LBuffer[LOut] := FEvents[LLeft];
          Inc(LLeft);
        end
        else
        begin
          LBuffer[LOut] := FEvents[LRight];
          Inc(LRight);
        end;
      end;
      LStart := LEnd;
    end;
    FEvents := Copy(LBuffer);
    LWidth := LWidth * 2;
  end;
end;

constructor TFrameToneStream.Create(const ATones: TFrameTones; const ASampleRate: Integer;
  const AMinimumFrames: Int64; const AVoiceLimit, AWorkLimit: Integer);
var
  LIndex: Integer;
  LCount: Integer;
  LVoices: Integer;
  LWork: Int64;
  LFrames: Int64;
  LCost: Integer;
  LSettings: array[0..0] of TBusSettings;
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 2);
  if (Length(ATones) > MaximumToneEvents) or (AMinimumFrames < 0) or
    (AVoiceLimit < 1) or (AVoiceLimit > MaximumScheduledVoices) or
    (AWorkLimit < 1) or (AWorkLimit > MaximumRenderVisits) then
  begin
    raise EAudio.Create('Tone stream exceeds event, extent, voice or work bounds');
  end;
  FSampleRate := ASampleRate;
  FFrameCount := AMinimumFrames;
  FTones := Copy(ATones);
  SetLength(FEvents, Length(FTones) * 2);
  LCount := 0;
  for LIndex := 0 to High(FTones) do
  begin
    LFrames := ValidateFrameTone(FTones[LIndex], ASampleRate);
    LCost := SynthFrameCost(FTones[LIndex].Voice, ASampleRate) + 16;
    FFrameCount := Max(FFrameCount, FTones[LIndex].StartFrame + LFrames);
    if LFrames = 0 then
    begin
      Continue;
    end;
    FEvents[LCount].Frame := FTones[LIndex].StartFrame;
    FEvents[LCount].ToneIndex := LIndex;
    FEvents[LCount].Starting := True;
    FEvents[LCount].Cost := LCost;
    Inc(LCount);
    FEvents[LCount].Frame := FTones[LIndex].StartFrame + LFrames;
    FEvents[LCount].ToneIndex := LIndex;
    FEvents[LCount].Cost := -LCost;
    Inc(LCount);
  end;
  SetLength(FEvents, LCount);
  SortEvents;
  LVoices := 0;
  LWork := 0;
  for LIndex := 0 to High(FEvents) do
  begin
    if FEvents[LIndex].Starting then
    begin
      Inc(LVoices);
    end
    else
    begin
      Dec(LVoices);
    end;
    Inc(LWork, FEvents[LIndex].Cost);
    if (LVoices > AVoiceLimit) or (LWork > AWorkLimit) then
    begin
      raise EAudio.Create('Tone stream overlapping voices or frame work exceeds admission limit');
    end;
    FPeakVoices := Max(FPeakVoices, LVoices);
    FPeakWork := Max(Int64(FPeakWork), LWork);
  end;
  LSettings[0] := DefaultBusSettings;
  LSettings[0].SmoothingSeconds := 0;
  FGraph := TBusGraph.Create(ASampleRate, LSettings);
  { Reserve dispatch/slot visits as well as the scheduler's weighted voices.
    PeakFrameWork reports the voice reservation; ReadLimit includes overhead. }
  LWork := Int64(FPeakWork) + 4 * Max(1, FPeakVoices) + FGraph.FrameCost;
  FReadLimit := Min(Int64(SynthStreamBlockFrames), MaximumEffectVisits div LWork);
  FSynth := TScheduledSynth.Create(FGraph, Max(1, FPeakVoices), AWorkLimit);
end;

destructor TFrameToneStream.Destroy;
begin
  FSynth.Free;
  FGraph.Free;
  inherited Destroy;
end;

function TFrameToneStream.GetFinished: Boolean;
begin
  Result := not FFailed and (FEmittedFrames = FFrameCount);
end;

function TFrameToneStream.ReadSamples(const AMaxFrames: Integer;
  out ASamples: TAudioSamples): Boolean;
var
  LSamples: TAudioSamples;
  LFrames: Integer;
  LIndex: Integer;
  LLeft: Double;
  LRight: Double;
  LId: Int64;
begin
  ASamples := nil;
  if FBusy or FFailed then
  begin
    raise EAudio.Create('Tone stream is active or failed');
  end;
  if (AMaxFrames < 1) or (AMaxFrames > SynthStreamBlockFrames) then
  begin
    raise EAudio.Create('Tone stream read requires 1..2048 frames');
  end;
  if Finished then
  begin
    Exit(False);
  end;
  LFrames := Min(Int64(Min(AMaxFrames, FReadLimit)), FFrameCount - FEmittedFrames);
  SetLength(LSamples, LFrames * 2);
  FBusy := True;
  try
    try
      for LIndex := 0 to LFrames - 1 do
      begin
        while (FEventIndex < Length(FEvents)) and
          (FEvents[FEventIndex].Frame = FSynth.NextFrame) do
        begin
          if FEvents[FEventIndex].Starting then
          begin
            if FSynth.TrySchedule(FTones[FEvents[FEventIndex].ToneIndex], 0, 0, LId) <>
              srScheduled then
            begin
              raise EAudio.Create('Tone stream source no longer satisfies its admitted reservation');
            end;
          end;
          Inc(FEventIndex);
        end;
        FSynth.Process(LLeft, LRight);
        if (Abs(LLeft) > MaxSingle) or (Abs(LRight) > MaxSingle) then
        begin
          raise EAudio.Create('Tone stream sample exceeds Single magnitude');
        end;
        LSamples[LIndex * 2] := LLeft;
        LSamples[LIndex * 2 + 1] := LRight;
      end;
      Inc(FEmittedFrames, LFrames);
      ASamples := LSamples;
      Result := True;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

end.

