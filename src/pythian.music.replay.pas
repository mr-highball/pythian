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
unit pythian.music.replay;

{$mode delphi}
{$H+}

interface

uses Classes, pythian.audio, pythian.progress, pythian.bus,
  pythian.music.stream, pythian.music.decisions;

type
  { Big Boss: performs a retained source-free score with the primary instrument
    stream. No WFC/model/learning dependency. Borrowed stream, instruments and bus
    graph must outlive this object. Retains one bounded chunk and normal active
    voices/effects. Sound changes are caller instrument bindings, not score edits.
    The caller must verify the complete journal hash against its immutable owning
    completion receipt before replay; per-chunk checks also detect read damage.
    Pull/admission/observer/I/O failures are terminal and publish no failed block. }
  TMusicDecisionReplay = class
  private
    FReader: TMusicDecisionReader;
    FMusic: TInstrumentMusicStream;
    FChunk: TMusicDecisionChunk;
    FCell: Integer;
    FOptions: TInstrumentStreamOptions;
    FFailed: Boolean;
    FBusy: Boolean;
    procedure RequireIdle;
    procedure Admit(const AProgress: TWorkProgressCallback);
    function GetState: TInstrumentStreamState;
    function GetPosition: Int64;
  public
    constructor Create(const AJournal: TStream;
      const ABindings: TInstrumentStreamBindings; const AGraph: TBusGraph;
      const AOptions: TInstrumentStreamOptions);
    destructor Destroy; override;
    function ReadOutputs(const AMaximumFrames: Integer; const ABuses: array of Integer;
      out ASamples: TAudioSamples; out AOutputs: TBusSampleBlocks;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    procedure Pause;
    procedure Resume;
    procedure Stop;
    property Position: Int64 read GetPosition;
    property State: TInstrumentStreamState read GetState;
  end;

implementation

constructor TMusicDecisionReplay.Create(const AJournal: TStream;
  const ABindings: TInstrumentStreamBindings; const AGraph: TBusGraph;
  const AOptions: TInstrumentStreamOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FReader := TMusicDecisionReader.Create(AJournal);
  FMusic := TInstrumentMusicStream.Create(ABindings, AGraph, AOptions);
end;

destructor TMusicDecisionReplay.Destroy;
begin
  FMusic.Free;
  FReader.Free;
  inherited Destroy;
end;

procedure TMusicDecisionReplay.RequireIdle;
begin
  if FBusy then raise EAudio.Create('Decision replay calls cannot reenter');
end;

procedure TMusicDecisionReplay.Admit(const AProgress: TWorkProgressCallback);
begin
  if FCell = Length(FChunk.Cells) then
  begin
    if not FReader.TryNext(FChunk, AProgress) then
      raise EAudio.Create('Decision journal ended before the requested music clock');
    if FReader.FrameCount > FOptions.MusicFrames then
      raise EAudio.Create('Decision journal exceeds the requested music clock');
    FCell := 0;
  end;
  { Check the complete final boundary before admitting its last musical cell. }
  if (FReader.FrameCount = FOptions.MusicFrames) and
    (FCell = High(FChunk.Cells)) and not FReader.AtEnd then
    raise EAudio.Create('Decision journal continues beyond the requested music');
  FMusic.AdmitFrame(FChunk.Cells[FCell].Parts, FChunk.Cells[FCell].FrameCount, AProgress);
  Inc(FCell);
end;

function TMusicDecisionReplay.ReadOutputs(const AMaximumFrames: Integer;
  const ABuses: array of Integer; out ASamples: TAudioSamples;
  out AOutputs: TBusSampleBlocks; const AProgress: TWorkProgressCallback): Boolean;
begin
  RequireIdle;
  ASamples := nil;
  AOutputs := nil;
  FMusic.ValidatePull(AMaximumFrames, ABuses);
  if FFailed then raise EAudio.Create('Decision replay failed; open a fresh verified journal');
  if State <> issReady then Exit(False);
  FBusy := True;
  try
    try
      if FMusic.NeedsInput then Admit(AProgress);
      Result := FMusic.ReadOutputs(AMaximumFrames, ABuses, ASamples, AOutputs, AProgress);
    except
      FFailed := True;
      ASamples := nil;
      AOutputs := nil;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

function TMusicDecisionReplay.GetState: TInstrumentStreamState;
begin
  if FFailed then Result := issFailed else Result := FMusic.State;
end;

function TMusicDecisionReplay.GetPosition: Int64;
begin
  Result := FMusic.Position;
end;

procedure TMusicDecisionReplay.Pause;
begin
  RequireIdle;
  FMusic.Pause;
end;

procedure TMusicDecisionReplay.Resume;
begin
  RequireIdle;
  FMusic.Resume;
end;

procedure TMusicDecisionReplay.Stop;
begin
  RequireIdle;
  FMusic.Stop;
end;

end.
