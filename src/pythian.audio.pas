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
unit pythian.audio;

{$mode delphi}
{$H+}

interface

uses
  SysUtils;

const
  AudioContractVersion = 1;
  MaximumSampleRate = 384000;
  MaximumClipSamples = 64000000;

type
  EAudio = class(Exception);
  TAudioSamples = array of Single;
  TAudioBytes = array of Byte;

  { Immutable interleaved linear samples. The caller owns each returned clip.
    Finite values outside [-1, 1] preserve mixing headroom until encoding. }
  TAudioClip = class
  strict private
    FSampleRate: Integer;
    FChannels: Integer;
    FSamples: TAudioSamples;
    function GetFrameCount: Integer;
  public
    constructor Create(const ASampleRate, AChannels: Integer;
      const ASamples: TAudioSamples);
    function SampleAt(const AFrame, AChannel: Integer): Single;
    function CopySamples: TAudioSamples;
    property SampleRate: Integer read FSampleRate;
    property Channels: Integer read FChannels;
    property FrameCount: Integer read GetFrameCount;
  end;

procedure RequireFinite(const AValue: Double; const AName: String);
procedure ValidateAudioFormat(const ASampleRate, AChannels: Integer);
function QuantizePcm16(const ASample: Double): SmallInt;
function DownmixMono(const AClip: TAudioClip): TAudioClip;

implementation

uses
  Math;

procedure RequireFinite(const AValue: Double; const AName: String);
begin
  if IsNan(AValue) or IsInfinite(AValue) then
  begin
    raise EAudio.Create(AName + ' must be finite');
  end;
end;

procedure ValidateAudioFormat(const ASampleRate, AChannels: Integer);
begin
  if (ASampleRate < 1) or (ASampleRate > MaximumSampleRate) then
  begin
    raise EAudio.Create('Sample rate must be 1..384000 Hz');
  end;
  if (AChannels < 1) or (AChannels > 2) then
  begin
    raise EAudio.Create('Channel count must be mono or stereo');
  end;
end;

constructor TAudioClip.Create(const ASampleRate, AChannels: Integer;
  const ASamples: TAudioSamples);
var
  LIndex: Integer;
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, AChannels);
  if (Length(ASamples) > MaximumClipSamples) or
    (Length(ASamples) mod AChannels <> 0) then
  begin
    raise EAudio.Create('Clip exceeds sample budget or contains a partial frame');
  end;
  for LIndex := 0 to High(ASamples) do
  begin
    RequireFinite(ASamples[LIndex], 'Sample');
  end;
  FSampleRate := ASampleRate;
  FChannels := AChannels;
  FSamples := Copy(ASamples);
end;

function TAudioClip.GetFrameCount: Integer;
begin
  Result := Length(FSamples) div FChannels;
end;

function TAudioClip.SampleAt(const AFrame, AChannel: Integer): Single;
begin
  if (AFrame < 0) or (AFrame >= FrameCount) or
    (AChannel < 0) or (AChannel >= FChannels) then
  begin
    raise EAudio.Create('Sample coordinate outside clip');
  end;
  Result := FSamples[AFrame * FChannels + AChannel];
end;

function TAudioClip.CopySamples: TAudioSamples;
begin
  Result := Copy(FSamples);
end;

function QuantizePcm16(const ASample: Double): SmallInt;
var
  LScaled: Double;
begin
  RequireFinite(ASample, 'Sample');
  if ASample <= -1 then
  begin
    Exit(-32768);
  end;
  if ASample >= 32767 / 32768 then
  begin
    Exit(32767);
  end;
  LScaled := ASample * 32768;
  { Round halves away from zero, independent of the host rounding mode. }
  if LScaled < 0 then
  begin
    Result := Trunc(LScaled - 0.5);
  end
  else
  begin
    Result := Trunc(LScaled + 0.5);
  end;
end;

function DownmixMono(const AClip: TAudioClip): TAudioClip;
var
  LSamples: TAudioSamples;
  LFrame: Integer;
  LLeft: Double;
  LRight: Double;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('Clip is required');
  end;
  SetLength(LSamples, AClip.FrameCount);
  for LFrame := 0 to High(LSamples) do
  begin
    if AClip.Channels = 1 then
    begin
      LSamples[LFrame] := AClip.SampleAt(LFrame, 0);
    end
    else
    begin
      LLeft := AClip.SampleAt(LFrame, 0);
      LRight := AClip.SampleAt(LFrame, 1);
      LSamples[LFrame] := LLeft * 0.5 + LRight * 0.5;
    end;
  end;
  Result := TAudioClip.Create(AClip.SampleRate, 1, LSamples);
end;

end.
