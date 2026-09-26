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

unit pythian.wave.resample;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.wave.read,
  pythian.resample.stream;

type
  { Borrows a WAVE reader at its current frame. The reader and its source must
    outlive this adapter and remain unchanged while borrowed. Reads bounded
    blocks, retaining floating samples outside unity until a caller selects
    an output gain/encoding policy. No channel summing or normalization. }
  TWavePcmReader = class(TPcmFrameReader)
  strict private
    FWave: TWaveFrameReader;
    FBlockFrames: Integer;
    FBlock: TAudioSamples;
    FIndex: Integer;
    FExpectedPosition: Int64;
    FFailed: Boolean;
    FPeak: Double;
  public
    constructor Create(const AReader: TWaveFrameReader; const ABlockFrames: Integer = 4096);
    function ReadFrame(out ALeft, ARight: Double): Boolean; override;
    property BlockFrames: Integer read FBlockFrames;
    property Peak: Double read FPeak;
  end;

implementation

uses
  Math;

constructor TWavePcmReader.Create(const AReader: TWaveFrameReader;
  const ABlockFrames: Integer);
begin
  if (AReader = nil) or (ABlockFrames < 1) or
    (ABlockFrames > MaximumWaveReadFrames) then
  begin
    raise EAudio.Create('WAVE PCM adapter requires a reader and 1..65536 block frames');
  end;
  inherited Create(AReader.SampleRate, AReader.Channels);
  FWave := AReader;
  FBlockFrames := ABlockFrames;
  FExpectedPosition := AReader.FramePosition;
end;

function TWavePcmReader.ReadFrame(out ALeft, ARight: Double): Boolean;
begin
  if FFailed then
  begin
    raise EAudio.Create('WAVE PCM adapter failed; create a new input pipeline');
  end;
  try
    if FWave.FramePosition <> FExpectedPosition then
    begin
      raise EAudio.Create('Borrowed WAVE reader position changed');
    end;
    if FIndex = Length(FBlock) then
    begin
      FBlock := FWave.ReadFrames(FBlockFrames);
      FExpectedPosition := FWave.FramePosition;
      FIndex := 0;
      if Length(FBlock) = 0 then
      begin
        Exit(False);
      end;
    end;
    ALeft := FBlock[FIndex];
    ARight := ALeft;
    if Channels = 2 then
    begin
      ARight := FBlock[FIndex + 1];
    end;
    FPeak := Max(FPeak, Max(Abs(ALeft), Abs(ARight)));
    Inc(FIndex, Channels);
    Result := True;
  except
    FFailed := True;
    raise;
  end;
end;

end.
