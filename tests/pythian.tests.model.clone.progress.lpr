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
program pythian_tests_model_clone_progress;
{$mode delphi}{$H+}

uses
  SysUtils, pythian.audio, pythian.progress, pythian.wfc.progress,
  wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_text;

type
  { Big Boss: checks the actual Pythian adapter's stage/unit/pass mapping,
    original exceptions and observer lifetime. WFC owns clone math/validation. }
  TProbe = class
    Calls: Integer;
    Point: Integer;
    Last: Int64;
    Interior: Boolean;
    Final: Boolean;
    Marker: Exception;
    procedure Reset(const APoint: Integer);
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;

procedure Check(const ACondition: Boolean; const AWhy: String);
begin
  if not ACondition then raise Exception.Create(AWhy);
  Inc(GChecks);
end;

procedure TProbe.Reset(const APoint: Integer);
begin
  Calls := 0;
  Point := APoint;
  Last := 0;
  Interior := False;
  Final := False;
  Marker := nil;
end;

procedure TProbe.Observe(const AWork: TWorkProgress);
begin
  Inc(Calls);
  Check((AWork.Stage = 'wfc_sequence_model_build_visits') and
    (AWork.Units = wuItems) and (AWork.Pass = 0), 'Actual clone adapter mapping');
  Check((AWork.Done >= Last) and (AWork.Done - Last <= 256) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Primary clone visits preserved');
  Last := AWork.Done;
  Interior := Interior or ((AWork.Done > 0) and (AWork.Total = 0));
  Final := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  if ((Point = 1) and (AWork.Done = 0)) or
    ((Point = 2) and (AWork.Done > 0) and (AWork.Total = 0)) or
    ((Point = 3) and Final) then
  begin
    Marker := Exception.Create('Original Pythian clone cancellation');
    raise Marker;
  end;
end;

procedure Exercise;
var
  LTokens: TWfcModelTokens;
  LSource: TWfcSequenceModel;
  LCopy: TWfcSequenceModel;
  LKeep: TWfcSequenceModel;
  LProbe: TProbe;
  LBoundary: TWfcModelBoundary;
  LText: String;
  LCalls: Integer;
  I: Integer;
  LRejected: Boolean;
begin
  SetLength(LTokens, 64);
  for I := 0 to High(LTokens) do LTokens[I] := 'literal clone #' + IntToStr(I) + '|';
  LProbe := TProbe.Create;
  try
    LRejected := False;
    try
      LCopy := CloneWfcSequenceModel(nil);
      LCopy.Free;
    except
      on E: EAudio do LRejected := Pos('requires a model', E.Message) > 0;
    end;
    Check(LRejected, 'Nil model rejects explicitly');
    for LBoundary := Low(TWfcModelBoundary) to High(TWfcModelBoundary) do
    begin
      LSource := LearnSequenceModel(LTokens, 4, LBoundary);
      LKeep := nil;
      LCopy := nil;
      try
        LText := EncodeWfcSequenceText(LSource);
        LKeep := CloneWfcSequenceModel(LSource);
        LProbe.Reset(0);
        LCopy := CloneWfcSequenceModel(LSource, LProbe.Observe);
        Check(LProbe.Interior and LProbe.Final, 'Mapped clone has interior and completion');
        Check(EncodeWfcSequenceText(LCopy) = LText, 'Mapped clone exact model');
        FreeAndNil(LCopy);
        for I := 1 to 3 do
        begin
          LProbe.Reset(I);
          LCopy := LKeep;
          LRejected := False;
          try
            LCopy := CloneWfcSequenceModel(LSource, LProbe.Observe);
          except
            on E: Exception do
            begin
              LRejected := True;
              Check(E = LProbe.Marker, 'Adapter preserves original exception identity');
            end;
          end;
          Check(LRejected and (LCopy = LKeep), 'Failed adapter copy preserves caller result');
          LCopy := nil;
          Check(EncodeWfcSequenceText(LSource) = LText, 'Cancellation preserves source');
          Inc(GAborts);
        end;
        LProbe.Reset(0);
        LCopy := CloneWfcSequenceModel(LSource, LProbe.Observe);
        LCalls := LProbe.Calls;
        FreeAndNil(LSource);
        Check(EncodeWfcSequenceText(LCopy) = LText, 'Mapped clone outlives source');
        Check(LProbe.Calls = LCalls, 'Model/adapter retains no work observer');
      finally
        if LCopy = LKeep then LCopy := nil;
        LCopy.Free;
        LKeep.Free;
        LSource.Free;
      end;
    end;
  finally
    LProbe.Free;
  end;
end;

begin
  Exercise;
  WriteLn('Shared model clone: ', GChecks, ' checks / ', GAborts, ' original aborts');
end.
