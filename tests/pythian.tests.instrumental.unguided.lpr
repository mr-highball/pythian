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
program pythian_tests_instrumental_unguided;
{$mode delphi}{$H+}
uses SysUtils, pythian.audio, pythian.bus, pythian.hash,
  pythian.music.form, pythian.music.decisions, pythian.music.stream,
  pythian.wfc.instrumental.starter, pythian.wfc.instrumental.stream,
  pythian.wfc.musical.context, pythian.wfc.voices,
  wfc_sequence;

type
  TRendered = record
    Digest: String;
    Decisions: TMusicDecisionChunk;
  end;
  TCapture = class
    Form: TMusicForm;
    Cursor: TMusicFormCursor;
    Decisions: TMusicDecisionChunk;
    Chunks: Integer;
    destructor Destroy; override;
    procedure Keep(const AChunk: TMusicDecisionChunk);
  end;

var Checks: Integer;
procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then raise EAudio.Create(AMessage);
end;

destructor TCapture.Destroy;
begin
  Cursor.Free;
  inherited Destroy;
end;

procedure TCapture.Keep(const AChunk: TMusicDecisionChunk);
var LKeys: TMusicDecisionTokens; I: Integer;
begin
  if Cursor = nil then
  begin
    SetLength(LKeys, Length(AChunk.Providers));
    for I := 0 to High(LKeys) do LKeys[I] := AChunk.Providers[I].Key;
    Cursor := TMusicFormCursor.Create(Form, LKeys);
    Decisions := CopyMusicDecisionChunk(AChunk);
  end
  else Decisions := AppendMusicDecisionChunk(Decisions, AChunk);
  Cursor.Append(AChunk);
  Inc(Chunks);
end;

function ActualForm: TMusicForm;
var I: Integer;
begin
  Result := nil;
  SetLength(Result, 3);
  for I := 0 to 2 do
  begin
    Result[I].Name := 'Section ' + IntToStr(I + 1);
    Result[I].Section := Result[I].Name;
    Result[I].Cells := 64;
    Result[I].RepeatFrom := -1;
    Result[I].DensityOffset := -20;
  end;
  Result[1].DensityOffset := 25;
  Result[2].RepeatFrom := 0;
  SetLength(Result[2].Keep, 1);
  Result[2].Keep[0] := 'lead';
end;

procedure ContextDomainIntersection;
var
  LStarter: TInstrumentalStarter;
  LBase, LBound: TVoiceMasks;
  LToken, LOriginal: String;
  LRejected: Boolean;
begin
  LStarter := TInstrumentalStarter.Create;
  try
    LToken := LStarter.ContextModel.PublicTokenAt(0);
    LBase := BindMusicalContextTokens([LToken], 3, nil);
    LOriginal := LBase[0][0].AllowedTokens[0];
    LBound := BindMusicalContextTokens([LToken], 3, LBase);
    Check((Length(LBound[0]) = 1) and (Length(LBound[1]) = 1),
      'Existing full positional domains intersect without adding duplicate rows');
    LBound[0][0].AllowedTokens[0] := 'detached output';
    Check(LBase[0][0].AllowedTokens[0] = LOriginal,
      'Context domain projection preserves caller ownership');
    SetLength(LBase[0], 2);
    LBase[0][1] := LBase[0][0];
    LBound := BindMusicalContextTokens([LToken], 3, LBase);
    Check((Length(LBound[0]) = 1) and
      (LBound[0][0].AllowedTokens[0] = LOriginal),
      'Repeated compatible domain rows retain AND semantics in one canonical row');
    LBase[0][1].AllowedTokens := ['conflicting choice'];
    LRejected := False;
    try LBound := BindMusicalContextTokens([LToken], 3, LBase)
    except on E: EAudio do LRejected := True end;
    Check(LRejected, 'Context cannot overwrite a conflicting explicit restriction');
    Check((Length(LBase[0]) = 2) and
      (LBase[0][1].AllowedTokens[0] = 'conflicting choice'),
      'Failed intersection preserves the caller input');
  finally LStarter.Free end;
end;

function Render(const AGuided: Boolean; const APull: Integer): TRendered;
const CRate = 24000;
var
  LStarter: TInstrumentalStarter;
  LGraph: TBusGraph;
  LStream: TInstrumentalMusicStream;
  LCapture: TCapture;
  LSettings: array[0..6] of TBusSettings;
  LOptions: TInstrumentalStreamOptions;
  LDomain: TInstrumentalDomainProvider;
  LContext: TWfcSequenceModel;
  LProjection: TVoiceMasks;
  LBlock: TAudioSamples;
  LStems: TBusSampleBlocks;
  LEnergy: array[0..5] of Double;
  LFrames: Int64;
  I, J: Integer;
begin
  LStarter := TInstrumentalStarter.Create;
  LGraph := nil; LStream := nil; LCapture := TCapture.Create;
  try
    LCapture.Form := ActualForm;
    for I := 0 to 6 do LSettings[I] := DefaultBusSettings;
    LGraph := TBusGraph.Create(CRate, LSettings);
    for I := 0 to 5 do LGraph.AddSend(I, 6, stPostFader, 0.2, 0);
    LOptions := DefaultInstrumentalStreamOptions(CRate * 48);
    LOptions.TailFrames := CRate;
    LOptions.Seed := 1704297163;
    LOptions.ContextBinding := icbDrivenRole;
    Check((LOptions.SegmentCells = 16) and (LOptions.MaxBacktracks = 256) and
      (LOptions.MaxPassBacktracks = 16), 'Original segment/search budgets remain unchanged');
    LDomain := nil; LContext := LStarter.ContextModel;
    if AGuided then
    begin
      LDomain := LStarter.GuideMasksRange;
      LContext := nil;
    end;
    if not AGuided then
    begin
      Check(LContext <> nil, 'Free authored material retains its synchronized chord/rhythm history');
      for I := 0 to LContext.PublicTokenCount - 1 do
      begin
        LProjection := BindMusicalContextTokens([LContext.PublicTokenAt(I)], 3, nil);
        Check((Length(LProjection[0]) = 1) and (Length(LProjection[1]) = 1) and
          (Length(LProjection[2]) = 0) and (Length(LProjection[3]) = 0) and
          (Length(LProjection[4]) = 0), 'Authored context never pins a pitched part');
      end;
    end;
    LStream := TInstrumentalMusicStream.Create(LStarter.Config, LStarter.CopyRoles,
      LStarter.CopyPercussion(CRate), LGraph, LOptions, LContext,
      LCapture.Keep, LCapture.Form, LDomain);
    Check(LStream.VoiceLookaheadCells = 256, 'Keep the complete bounded musical lookahead');
    for I := 0 to 5 do LEnergy[I] := 0;
    LFrames := 0;
    while LStream.ReadOutputs(APull, [0, 1, 2, 3, 4, 5], LBlock, LStems) do
    begin
      Inc(LFrames, Length(LBlock) div 2);
      for I := 0 to 5 do
        for J := 0 to High(LStems[I]) do LEnergy[I] := LEnergy[I] + Abs(LStems[I][J]);
    end;
    Check((LStream.State = issCompleted) and (LFrames = CRate * 49),
      'Original48second arrangement completes with its one-second tail');
    Check((LCapture.Cursor.CellCount = 192) and (LCapture.Cursor.FrameCount = CRate * 48) and
      (LCapture.Chunks = 12), 'Actual primary journal/form proof spans all sections and retained lead');
    for I := 0 to 5 do Check(LEnergy[I] > 1, 'Every synthesized pitched/drum part sounds');
    Result.Decisions := CopyMusicDecisionChunk(LCapture.Decisions);
    Result.Digest := Sha256Bytes(EncodeMusicDecisions(Result.Decisions));
  finally
    LStream.Free; LCapture.Free; LGraph.Free; LStarter.Free;
  end;
end;

var
  Guided, FreeMusic, Replay: TRendered;
  I: Integer;
  Different: Boolean;
begin
  ContextDomainIntersection;
  Guided := Render(True, 4096);
  WriteLn('Guided feasible witness: ', Guided.Digest);
  FreeMusic := Render(False, 4096);
  Different := False;
  Check(Length(Guided.Decisions.Cells) = Length(FreeMusic.Decisions.Cells),
    'Guided and free witnesses span the same actual musical clock');
  for I := 0 to High(FreeMusic.Decisions.Cells) do
    Different := Different or not SameMusicDecisionFrame(
      FreeMusic.Decisions.Cells[I].Parts, Guided.Decisions.Cells[I].Parts);
  Check(Different, 'Free performed notes are not merely different provider metadata');
  Replay := Render(False, 997);
  Check(Replay.Digest = FreeMusic.Digest,
    'Same seed and musical decisions survive different audio pull sizes');
  WriteLn('PASS unguided form ', Checks, ' checks; decision digest ', FreeMusic.Digest);
end.
