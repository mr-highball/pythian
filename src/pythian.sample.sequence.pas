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

unit pythian.sample.sequence;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  MaximumSampleSequenceFrames = 256000000;

type
  { Borrowed immutable clip viewed as intro, repeated [LoopStart, LoopEnd), tail.
    Before release the tail is unreachable. Release completes the current loop
    traversal, then continues into the tail. Integer tap addresses clamp at the
    complete sequence endpoints, so interpolation shares the playback trajectory. }
  TSampleLoopSequence = class
  private
    FSource: TAudioClip;
    FLoopStart: Integer;
    FLoopEnd: Integer;
    FExitFrame: Integer;
    function GetEndFrame: Integer;
  public
    constructor Create(const ASource: TAudioClip; const ALoopStart, ALoopEnd: Integer);
    procedure Reset;
    procedure ReleaseAt(const APosition: Double);
    function FrameAt(const AIndex: Integer): Integer;
    { Remove complete periods only after every possible past interpolation tap
      has left the intro. Caller supplies its maximum radius over all future
      pitch changes. Released trajectories are never rebased. }
    function RebasePosition(const APosition: Double; const AMaximumRadius: Integer): Double;
    property Source: TAudioClip read FSource;
    property ExitFrame: Integer read FExitFrame;
    property EndFrame: Integer read GetEndFrame;
  end;

implementation

uses
  Math;

constructor TSampleLoopSequence.Create(const ASource: TAudioClip;
  const ALoopStart, ALoopEnd: Integer);
begin
  inherited Create;
  if (ASource = nil) or (ALoopStart < 0) or (ALoopEnd <= ALoopStart) then
  begin
    raise EAudio.Create('Sample loop sequence requires a source and a nonempty loop');
  end;
  if ALoopEnd > ASource.FrameCount then
  begin
    raise EAudio.Create('Sample loop exceeds source frames');
  end;
  FSource := ASource;
  FLoopStart := ALoopStart;
  FLoopEnd := ALoopEnd;
  Reset;
end;

procedure TSampleLoopSequence.Reset;
begin
  FExitFrame := -1;
end;

function TSampleLoopSequence.GetEndFrame: Integer;
begin
  Result := MaximumSampleSequenceFrames;
  if FExitFrame >= 0 then
  begin
    Result := FExitFrame + FSource.FrameCount - FLoopEnd;
  end;
end;

procedure TSampleLoopSequence.ReleaseAt(const APosition: Double);
var
  LExit: Int64;
  LPeriod: Integer;
begin
  RequireFinite(APosition, 'Sample loop release position');
  if (APosition < 0) or (APosition >= EndFrame) then
  begin
    raise EAudio.Create('Sample loop release position exceeds sequence extent');
  end;
  if FExitFrame >= 0 then
  begin
    Exit;
  end;
  LPeriod := FLoopEnd - FLoopStart;
  LExit := FLoopEnd;
  if APosition >= FLoopEnd then
  begin
    LExit := Int64(FLoopEnd) + (Floor((APosition - FLoopEnd) / LPeriod) + 1) * LPeriod;
  end;
  if LExit + FSource.FrameCount - FLoopEnd > MaximumSampleSequenceFrames then
  begin
    raise EAudio.Create('Released sample loop exceeds bounded sequence extent');
  end;
  FExitFrame := Integer(LExit);
end;

function TSampleLoopSequence.FrameAt(const AIndex: Integer): Integer;
var
  LTailIndex: Integer;
begin
  if AIndex < 0 then
  begin
    Exit(0);
  end;
  if (FExitFrame >= 0) and (AIndex >= FExitFrame) then
  begin
    LTailIndex := AIndex - FExitFrame;
    if LTailIndex >= FSource.FrameCount - FLoopEnd then
    begin
      Exit(FSource.FrameCount - 1);
    end;
    Exit(FLoopEnd + LTailIndex);
  end;
  if AIndex < FLoopEnd then
  begin
    Exit(AIndex);
  end;
  Result := FLoopStart + (AIndex - FLoopStart) mod (FLoopEnd - FLoopStart);
end;

function TSampleLoopSequence.RebasePosition(const APosition: Double;
  const AMaximumRadius: Integer): Double;
var
  LAnchor: Integer;
  LPeriod: Integer;
begin
  RequireFinite(APosition, 'Sample loop position');
  if (APosition < 0) or (APosition >= MaximumSampleSequenceFrames) or
    (AMaximumRadius < 1) or (AMaximumRadius > 65536) then
  begin
    raise EAudio.Create('Sample loop position/radius exceeds bounded sequence contract');
  end;
  Result := APosition;
  LAnchor := FLoopEnd + AMaximumRadius + 1;
  LPeriod := FLoopEnd - FLoopStart;
  if (FExitFrame < 0) and (APosition >= LAnchor + LPeriod) then
  begin
    Result := APosition - Floor((APosition - LAnchor) / LPeriod) * LPeriod;
  end;
end;

end.

