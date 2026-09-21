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
unit pythian.wfc.audio;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  wfc_music_audio;

{ Both conversions return caller-owned detached clips. Conversion to WFC
  preserves its mono, sample-rate and preview-size limits; no implicit downmix. }
function FromWfcClip(const AClip: TWfcMusicPcm16Clip): TAudioClip;
function ToWfcClip(const AClip: TAudioClip): TWfcMusicPcm16Clip;

implementation

function FromWfcClip(const AClip: TWfcMusicPcm16Clip): TAudioClip;
var
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('WFC clip is required');
  end;
  SetLength(LSamples, AClip.FrameCount);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := AClip.SampleAt(LIndex) / 32768;
  end;
  Result := TAudioClip.Create(AClip.SampleRate, 1, LSamples);
end;

function ToWfcClip(const AClip: TAudioClip): TWfcMusicPcm16Clip;
var
  LSamples: TWfcMusicPcm16Samples;
  LIndex: Integer;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('Pythian clip is required');
  end;
  if (AClip.Channels <> 1) or
    (AClip.SampleRate < WFC_MUSIC_AUDIO_MIN_SAMPLE_RATE) or
    (AClip.SampleRate > WFC_MUSIC_AUDIO_MAX_SAMPLE_RATE) or
    (AClip.FrameCount > WFC_MUSIC_AUDIO_MAX_SAMPLE_FRAME_COUNT) then
  begin
    raise EAudio.Create('Clip is outside WFC mono preview contract');
  end;
  SetLength(LSamples, AClip.FrameCount);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := QuantizePcm16(AClip.SampleAt(LIndex, 0));
  end;
  Result := TWfcMusicPcm16Clip.Create(AClip.SampleRate, LSamples);
end;

end.
