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
unit pythian.meter;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

type
  TChannelLevels = record
    Peak: Double;
    Rms: Double;
    Mean: Double;
  end;
  TAudioLevels = array[0..1] of TChannelLevels;

{ Linear sample-domain measurements, without perceptual loudness weighting.
  Empty and unused channels report zero. The clip is borrowed. }
function MeasureAudio(const AClip: TAudioClip): TAudioLevels;

implementation

uses
  Math;

function MeasureAudio(const AClip: TAudioClip): TAudioLevels;
var
  LFrame: Integer;
  LChannel: Integer;
  LValue: Double;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('Audio metering requires a clip');
  end;
  Result := Default(TAudioLevels);
  for LFrame := 0 to AClip.FrameCount - 1 do
  begin
    for LChannel := 0 to AClip.Channels - 1 do
    begin
      LValue := AClip.SampleAt(LFrame, LChannel);
      Result[LChannel].Peak := Max(Result[LChannel].Peak, Abs(LValue));
      Result[LChannel].Rms := Result[LChannel].Rms + Sqr(LValue);
      Result[LChannel].Mean := Result[LChannel].Mean + LValue;
    end;
  end;
  if AClip.FrameCount > 0 then
  begin
    for LChannel := 0 to AClip.Channels - 1 do
    begin
      Result[LChannel].Rms := Sqrt(Result[LChannel].Rms / AClip.FrameCount);
      Result[LChannel].Mean := Result[LChannel].Mean / AClip.FrameCount;
    end;
  end;
end;

end.
