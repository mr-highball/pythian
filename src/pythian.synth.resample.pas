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

unit pythian.synth.resample;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.synth.stream,
  pythian.resample.stream;

type
  { Borrows a finite tone stream at its current emitted frame. The stream and
    its borrowed source definitions must outlive this reader and any converter.
    Do not advance the stream elsewhere while this reader is attached. Buffers
    at most BlockFrames stereo frames, preserving native Single PCM/headroom.
    This adapter does not retime tone plans or automation for oversampling. }
  TTonePcmReader = class(TPcmFrameReader)
  strict private
    FStream: TFrameToneStream;
    FBlockFrames: Integer;
    FBlock: TAudioSamples;
    FIndex: Integer;
    FExpectedPosition: Int64;
    FFramesRead: Int64;
    FFailed: Boolean;
  public
    constructor Create(const AStream: TFrameToneStream;
      const ABlockFrames: Integer = SynthStreamBlockFrames);
    { EOF/failure preserves output arguments. Failure poisons this adapter;
      buffered samples cannot be reused after an external advance or failure. }
    function ReadFrame(out ALeft, ARight: Double): Boolean; override;
    property BlockFrames: Integer read FBlockFrames;
    property FramesRead: Int64 read FFramesRead;
  end;

implementation

constructor TTonePcmReader.Create(const AStream: TFrameToneStream;
  const ABlockFrames: Integer);
begin
  if (AStream = nil) or (ABlockFrames < 1) or
    (ABlockFrames > SynthStreamBlockFrames) then
  begin
    raise EAudio.Create('Tone PCM reader requires a stream and 1..2048 block frames');
  end;
  if AStream.Failed then
  begin
    raise EAudio.Create('Tone PCM reader requires a usable stream');
  end;
  inherited Create(AStream.SampleRate, 2);
  FStream := AStream;
  FBlockFrames := ABlockFrames;
  FExpectedPosition := AStream.EmittedFrames;
end;

function TTonePcmReader.ReadFrame(out ALeft, ARight: Double): Boolean;
begin
  if FFailed then
  begin
    raise EAudio.Create('Tone PCM reader failed; create a new input pipeline');
  end;
  try
    if FStream.Failed or (FStream.EmittedFrames <> FExpectedPosition) then
    begin
      raise EAudio.Create('Borrowed tone stream failed or its position changed');
    end;
    if FIndex = Length(FBlock) then
    begin
      FIndex := 0;
      if not FStream.ReadSamples(FBlockFrames, FBlock) then
      begin
        Exit(False);
      end;
      FExpectedPosition := FStream.EmittedFrames;
    end;
    ALeft := FBlock[FIndex];
    ARight := FBlock[FIndex + 1];
    Inc(FIndex, 2);
    Inc(FFramesRead);
    Result := True;
  except
    FFailed := True;
    raise;
  end;
end;

end.
