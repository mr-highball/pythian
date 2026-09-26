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

program pythian_tests_sample_loop;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.source,
  pythian.source.sample,
  pythian.sample.sequence,
  pythian.resample;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function SourceClip: TAudioClip;
var
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  SetLength(LSamples, 20);
  for LIndex := 0 to 9 do
  begin
    LSamples[2 * LIndex] := (LIndex - 4) / 8;
    LSamples[2 * LIndex + 1] := (3 - LIndex) / 16;
  end;
  Result := TAudioClip.Create(4000, 2, LSamples);
end;

function ExpandedClip(const ASource: TAudioClip; const ARepeats: Integer): TAudioClip;
var
  LSamples: TAudioSamples;
  LRepeat: Integer;
  LFrame: Integer;
  LChannel: Integer;
  LOutput: Integer;
begin
  SetLength(LSamples, (2 + ARepeats * 4 + 4) * 2);
  LOutput := 0;
  for LFrame := 0 to 1 do
  begin
    for LChannel := 0 to 1 do
    begin
      LSamples[LOutput] := ASource.SampleAt(LFrame, LChannel);
      Inc(LOutput);
    end;
  end;
  for LRepeat := 1 to ARepeats do
  begin
    for LFrame := 2 to 5 do
    begin
      for LChannel := 0 to 1 do
      begin
        LSamples[LOutput] := ASource.SampleAt(LFrame, LChannel);
        Inc(LOutput);
      end;
    end;
  end;
  for LFrame := 6 to 9 do
  begin
    for LChannel := 0 to 1 do
    begin
      LSamples[LOutput] := ASource.SampleAt(LFrame, LChannel);
      Inc(LOutput);
    end;
  end;
  Result := TAudioClip.Create(4000, 2, LSamples);
end;

procedure LinearTrajectory;
const
  CExpected: array[0..10] of Integer = (1, 2, 3, 4, 2, 3, 4, 5, 6, 7, 8);
var
  LClip: TAudioClip;
  LFactory: TSampleSourceFactory;
  LSource: TAudioSource;
  LOther: TAudioSource;
  LLeft: Double;
  LRight: Double;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LClip := SourceClip;
  LFactory := nil;
  LSource := nil;
  LOther := nil;
  try
    LFactory := TSampleSourceFactory.CreateLoopRegion(LClip, 1, 9, 2, 5, 100,
      spSustainLoop, sqLinear, 8);
    FreeAndNil(LClip);
    LSource := LFactory.CreateSource(4000, 0);
    LOther := LFactory.CreateSource(4000, 0);
    for LIndex := 0 to High(CExpected) do
    begin
      if LIndex = 4 then
      begin
        LSource.NoteOff;
        LSource.NoteOff;
      end;
      if LIndex = 2 then
      begin
        LRejected := False;
        try
          LSource.ReadFrame(900, LLeft, LRight);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected, 'Pitch beyond maximum step rejects');
      end;
      Check(LSource.ReadFrame(100, LLeft, LRight), 'Intro/loop/tail frame available');
      Check((LLeft = (CExpected[LIndex] - 4) / 8) and
        (LRight = (3 - CExpected[LIndex]) / 16), 'Exact detached stereo trajectory');
    end;
    Check(not LSource.ReadFrame(100, LLeft, LRight) and (LLeft = 0) and (LRight = 0),
      'Released tail exhausts into zero');
    Check(LOther.ReadFrame(100, LLeft, LRight) and (LLeft = -3 / 8),
      'Second source retains independent intro and release state');
    LSource.Reset;
    LSource.NoteOff;
    for LIndex := 1 to 8 do
    begin
      Check(LSource.ReadFrame(100, LLeft, LRight) and (LLeft = (LIndex - 4) / 8),
        'Release during intro traverses original region once');
    end;
    Check(not LSource.ReadFrame(100, LLeft, LRight), 'Early release exact end');
  finally
    LOther.Free;
    LSource.Free;
    LFactory.Free;
    LClip.Free;
  end;
end;

procedure SincTrajectory;
var
  LClip: TAudioClip;
  LHeld: TAudioClip;
  LReleased: TAudioClip;
  LFactory: TSampleSourceFactory;
  LSource: TAudioSource;
  LOracleHeld: TSincSampler;
  LOracleReleased: TSincSampler;
  LOracle: TSincSampler;
  LLeft: Double;
  LRight: Double;
  LExpectedLeft: Double;
  LExpectedRight: Double;
  LPosition: Double;
  LStep: Double;
  LError: Double;
  LIndex: Integer;
  LMore: Boolean;
begin
  LClip := SourceClip;
  LHeld := nil;
  LReleased := nil;
  LFactory := nil;
  LSource := nil;
  LOracleHeld := nil;
  LOracleReleased := nil;
  try
    LHeld := ExpandedClip(LClip, 1024);
    { 1600*0.5 + 16*8 + 84*1.5 = 1054, exactly at a new loop traversal.
      Finish that traversal at 1058, then the four-frame tail ends at 1062. }
    LReleased := ExpandedClip(LClip, 264);
    LOracleHeld := TSincSampler.Create(LHeld, 0.5);
    LOracleReleased := TSincSampler.Create(LReleased, 1.5);
    LFactory := TSampleSourceFactory.CreateLoopRegion(LClip, 0, 10, 2, 6, 100,
      spSustainLoop, sqSinc, 8);
    LSource := LFactory.CreateSource(4000, 0);
    FreeAndNil(LClip);
    LPosition := 0;
    LError := 0;
    for LIndex := 0 to 1705 do
    begin
      LStep := 0.5;
      if (LIndex >= 1600) and (LIndex < 1616) then
      begin
        LStep := 8;
      end;
      if LIndex >= 1616 then
      begin
        LStep := 1.5;
      end;
      LOracle := LOracleHeld;
      if LIndex >= 1700 then
      begin
        LOracle := LOracleReleased;
      end;
      if LIndex = 1700 then
      begin
        Check(LPosition = 1054, 'Independent release coordinate');
        LSource.NoteOff;
      end;
      LOracle.SetSourceStep(LStep);
      LOracle.ReadFrame(LPosition, LExpectedLeft, LExpectedRight);
      LMore := LSource.ReadFrame(LStep * 100, LLeft, LRight);
      Check(LMore, 'Sinc trajectory remains available through the tail');
      LError := Max(LError, Max(Abs(LLeft - LExpectedLeft), Abs(LRight - LExpectedRight)));
      LPosition := LPosition + LStep;
    end;
    Check(not LSource.ReadFrame(150, LLeft, LRight), 'Fractional released extent');
    Check(LError < 1E-12, 'Sinc interpolation matches physically expanded intro/loops/tail');
    WriteLn('Expanded-PCM sinc oracle maximum error: ', LError);
  finally
    LOracleReleased.Free;
    LOracleHeld.Free;
    LSource.Free;
    LFactory.Free;
    LReleased.Free;
    LHeld.Free;
    LClip.Free;
  end;
end;

procedure SequenceBounds;
var
  LClip: TAudioClip;
  LSequence: TSampleLoopSequence;
  LFactory: TSampleSourceFactory;
  LRejected: Boolean;
  LPosition: Double;
begin
  LClip := SourceClip;
  LSequence := nil;
  LFactory := nil;
  try
    LSequence := TSampleLoopSequence.Create(LClip, 2, 6);
    Check((LSequence.FrameAt(-1) = 0) and (LSequence.FrameAt(6) = 2),
      'Intro clamping and first loop seam');
    LPosition := LSequence.RebasePosition(1000000.5, 545);
    Check((LPosition >= 552) and (LPosition < 556), 'Long held trajectory stays bounded');
    LSequence.ReleaseAt(8.5);
    Check((LSequence.ExitFrame = 10) and (LSequence.EndFrame = 14) and
      (LSequence.FrameAt(10) = 6) and (LSequence.FrameAt(High(Integer)) = 9),
      'Released virtual end and overflow-safe clamp');
    LRejected := False;
    try
      LSequence.ReleaseAt(-1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSequence.ExitFrame = 10), 'Rejected release preserves trajectory');
    LRejected := False;
    try
      LFactory := TSampleSourceFactory.CreateLoopRegion(LClip, 1, 9, 0, 5, 100);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LFactory = nil), 'Loop must lie inside the copied region');
  finally
    LFactory.Free;
    LSequence.Free;
    LClip.Free;
  end;
end;

procedure ContinuousLoop;
var
  LClip: TAudioClip;
  LFactory: TSampleSourceFactory;
  LSource: TAudioSource;
  LLeft: Double;
  LRight: Double;
  LIndex: Integer;
begin
  LClip := SourceClip;
  LFactory := nil;
  LSource := nil;
  try
    LFactory := TSampleSourceFactory.CreateLoopRegion(LClip, 1, 9, 2, 3, 100,
      spLoop, sqLinear, 8);
    LSource := LFactory.CreateSource(4000, 0);
    Check(LSource.ReadFrame(800, LLeft, LRight) and (LLeft = -3 / 8),
      'Large initial step still emits intro frame zero');
    LSource.NoteOff;
    for LIndex := 0 to 19 do
    begin
      Check(LSource.ReadFrame(800, LLeft, LRight) and (LLeft = -2 / 8),
        'One-frame loop handles multiple wraps and ignores note-off');
    end;
    Check(LSource.ReadFrame(0, LLeft, LRight) and (LLeft = -2 / 8),
      'Zero frequency holds the loop position');
  finally
    LSource.Free;
    LFactory.Free;
    LClip.Free;
  end;
end;

begin
  try
    LinearTrajectory;
    SincTrajectory;
    SequenceBounds;
    ContinuousLoop;
    WriteLn('Interior-loop ownership, intro/tail, reset, pitch, sinc trajectory and bounds pass');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
