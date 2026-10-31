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
unit pythian.music.form;

{$mode delphi}
{$H+}

interface

uses pythian.music.decisions, pythian.text;

const
  MusicFormVersion = 1;
  MaximumMusicFormPhrases = 4096;
  MaximumMusicFormRetainedCells = 1024;
  MaximumMusicFormTextBytes = 2097152;

type
  TMusicFormPhrase = record
    Section: TScalarText;
    Name: TScalarText;
    Cells: Integer;
    { -1 generates new material. Otherwise keep named providers from this
      earlier phrase; other providers remain free to make different decisions. }
    RepeatFrom: Integer;
    Keep: TMusicDecisionTokens;
  end;
  TMusicForm = array of TMusicFormPhrase;

  { Big Boss: an explicit caller-authored musical form, not solver chunk names.
    Carries sequential decision provenance and caches only phrases referenced
    later, within a fixed cell/text budget. Locks copy public musical tokens,
    never authorize latent states or manufacture model transitions. The musical
    producer must solve these locks against its actual domains and real frontier.
    It must not paste captured notes/PCM over a newly solved accompaniment.

    Chunks can subdivide a phrase. Recorded clocks/predecessors use the primary
    decision cursor. A repeated phrase must keep its declared providers exactly;
    conflicts reject rather than weakening Keep. No renderer, WFC dependency,
    inference, implicit mood interpretation or duration-sized score lives here. }
  TMusicFormCursor = class(TMusicDecisionCursor)
  private
    FForm: TMusicForm;
    FProviderKeys: TMusicDecisionTokens;
    FStarts: array of Int64;
    FNeeded: array of Boolean;
    FCache: array of array of TMusicDecisionChunk;
    FTotalCells: Int64;
    FPhrase: Integer;
    FTextBytes: Integer;
  public
    constructor Create(const AForm: TMusicForm; const AProviderKeys: TMusicDecisionTokens);
    function CopyForm: TMusicForm;
    function WindowCellsAt(const AFirstCell: Int64; const AMaximum: Integer): Integer;
    { Stop before passing the completion of a still-needed motif source. Its
      newly recorded choices must constrain the following planning request. }
    function ReadyLookaheadCells(const AMaximum: Integer): Integer;
    { False means a future motif has not yet been recorded. It does not invent
      tokens from an unperformed source phrase or relax a current required lock. }
    function TryCopyLocksAt(const AFirstCell: Int64; const ACellCount: Integer;
      out ALocks: TMusicDecisionProviders): Boolean;
    function CopyLocks(const ACellCount: Integer): TMusicDecisionProviders;
    procedure Append(const AChunk: TMusicDecisionChunk);
    property PhraseIndex: Integer read FPhrase;
    property TotalCells: Int64 read FTotalCells;
  end;

function CopyMusicForm(const AForm: TMusicForm): TMusicForm;
{ Largest fixed lookahead <= AMaximum that divides every declared phrase.
  Thus musical boundaries can never be crossed by an indivisible solve window. }
function MusicFormLookahead(const AForm: TMusicForm; const AMaximum: Integer): Integer;

implementation

uses SysUtils, Math, pythian.audio;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

function Whole(const AValue, AMinimum, AMaximum: Integer): Boolean;
begin
  Result := (AValue = Trunc(AValue)) and (AValue >= AMinimum) and (AValue <= AMaximum);
end;

function CopyMusicForm(const AForm: TMusicForm): TMusicForm;
var I: Integer;
begin
  Result := Copy(AForm);
  for I := 0 to High(Result) do Result[I].Keep := Copy(AForm[I].Keep);
end;

function MusicFormLookahead(const AForm: TMusicForm; const AMaximum: Integer): Integer;
var I, LLeft, LRight, LRemainder: Integer;
begin
  Need(Whole(AMaximum, 1, MaximumMusicDecisionCells), 'Form lookahead must be 1..256 cells');
  Result := AMaximum;
  for I := 0 to High(AForm) do
  begin
    Need(Whole(AForm[I].Cells, 1, MaximumMusicDecisionCells), 'Phrase length must be 1..256 cells');
    LLeft := Result;
    LRight := AForm[I].Cells;
    while LRight <> 0 do
    begin
      LRemainder := LLeft mod LRight;
      LLeft := LRight;
      LRight := LRemainder;
    end;
    Result := LLeft;
  end;
end;

constructor TMusicFormCursor.Create(const AForm: TMusicForm;
  const AProviderKeys: TMusicDecisionTokens);
var I, J, K, LRetainedCells: Integer;
  LFound: Boolean;
begin
  inherited Create;
  Need(Whole(Length(AForm), 1, MaximumMusicFormPhrases), 'Form needs 1..4096 phrases');
  Need(Whole(Length(AProviderKeys), 1, MaximumMusicDecisionProviders),
    'Form needs the actual musical provider names');
  for I := 0 to High(AProviderKeys) do
  begin
    ValidateScalarText(AProviderKeys[I], 256, False);
    for J := 0 to I - 1 do
      Need(AProviderKeys[I] <> AProviderKeys[J], 'Duplicate form provider name');
  end;
  FForm := CopyMusicForm(AForm);
  FProviderKeys := Copy(AProviderKeys);
  SetLength(FStarts, Length(FForm));
  SetLength(FNeeded, Length(FForm));
  SetLength(FCache, Length(FForm));
  MusicFormLookahead(FForm, MaximumMusicDecisionCells);
  for I := 0 to High(FForm) do
  begin
    ValidateScalarText(FForm[I].Section, 128, False);
    ValidateScalarText(FForm[I].Name, 128, False);
    Need(Whole(FForm[I].RepeatFrom, -1, I - 1), 'Phrase references must name an earlier phrase');
    FStarts[I] := FTotalCells;
    Inc(FTotalCells, FForm[I].Cells);
    Need(Length(FForm[I].Keep) <= Length(AProviderKeys), 'Too many retained phrase providers');
    if FForm[I].RepeatFrom < 0 then
      Need(Length(FForm[I].Keep) = 0, 'A new phrase cannot retain an unspecified motif')
    else
    begin
      Need((FForm[I].Cells = FForm[FForm[I].RepeatFrom].Cells) and
        (Length(FForm[I].Keep) > 0), 'Repeated phrases need equal length and explicit retained providers');
      FNeeded[FForm[I].RepeatFrom] := True;
    end;
    for J := 0 to High(FForm[I].Keep) do
    begin
      LFound := False;
      for K := 0 to High(AProviderKeys) do
        LFound := LFound or (FForm[I].Keep[J] = AProviderKeys[K]);
      Need(LFound, 'A retained phrase provider does not exist');
      for K := 0 to J - 1 do
        Need(FForm[I].Keep[J] <> FForm[I].Keep[K], 'Duplicate retained phrase provider');
    end;
  end;
  LRetainedCells := 0;
  for I := 0 to High(FNeeded) do
    if FNeeded[I] then Inc(LRetainedCells, FForm[I].Cells);
  Need(LRetainedCells <= MaximumMusicFormRetainedCells,
    'Referenced motifs exceed the bounded 1024-cell cache');
end;

function TMusicFormCursor.CopyForm: TMusicForm;
begin
  Result := CopyMusicForm(FForm);
end;

function TMusicFormCursor.WindowCellsAt(const AFirstCell: Int64;
  const AMaximum: Integer): Integer;
var I: Integer;
begin
  Need((AFirstCell = Trunc(AFirstCell)) and (AFirstCell >= CellCount) and
    (AFirstCell < FTotalCells) and Whole(AMaximum, 1, MaximumMusicDecisionCells),
    'A form window must name a current or future musical cell');
  I := FPhrase;
  while AFirstCell >= FStarts[I] + FForm[I].Cells do Inc(I);
  Result := Min(Int64(AMaximum), FStarts[I] + FForm[I].Cells - AFirstCell);
end;

function TMusicFormCursor.ReadyLookaheadCells(const AMaximum: Integer): Integer;
var I: Integer;
begin
  Need((FPhrase < Length(FForm)) and Whole(AMaximum, 1, MaximumMusicDecisionCells),
    'Form lookahead needs a current phrase and bounded cells');
  Result := Min(Int64(AMaximum), FTotalCells - CellCount);
  for I := FPhrase to High(FNeeded) do
    if FNeeded[I] then
    begin
      Result := Min(Int64(Result), FStarts[I] + FForm[I].Cells - CellCount);
      Break;
    end;
end;

function TMusicFormCursor.TryCopyLocksAt(const AFirstCell: Int64;
  const ACellCount: Integer; out ALocks: TMusicDecisionProviders): Boolean;
var LPhrase, LSource, LOffset, LSourceOffset, LAt, LCount, I, J, K, LChunkIndex: Integer;
  LChunk: TMusicDecisionChunk;
begin
  Need(WindowCellsAt(AFirstCell, ACellCount) = ACellCount,
    'A form window must remain inside the current phrase');
  ALocks := nil;
  LPhrase := FPhrase;
  while AFirstCell >= FStarts[LPhrase] + FForm[LPhrase].Cells do Inc(LPhrase);
  LSource := FForm[LPhrase].RepeatFrom;
  if LSource < 0 then Exit(True);
  if CellCount < FStarts[LSource] + FForm[LSource].Cells then Exit(False);
  LOffset := Integer(AFirstCell - FStarts[LPhrase]);
  SetLength(ALocks, Length(FForm[LPhrase].Keep));
  for I := 0 to High(ALocks) do
  begin
    ALocks[I].Key := FForm[LPhrase].Keep[I];
    SetLength(ALocks[I].Tokens, ACellCount);
    SetLength(ALocks[I].States, ACellCount);
    LAt := 0;
    for LChunkIndex := 0 to High(FCache[LSource]) do
    begin
      LChunk := FCache[LSource][LChunkIndex];
      LSourceOffset := Integer(LChunk.FirstCell - FStarts[LSource]);
      LCount := Min(LOffset + ACellCount, LSourceOffset + Length(LChunk.Cells)) -
        Max(LOffset, LSourceOffset);
      if LCount <= 0 then Continue;
      J := 0;
      while (J < Length(LChunk.Providers)) and
        (LChunk.Providers[J].Key <> ALocks[I].Key) do Inc(J);
      Need(J < Length(LChunk.Providers), 'Recorded motif is missing a retained provider');
      for K := 0 to LCount - 1 do
      begin
        ALocks[I].Tokens[LAt] := LChunk.Providers[J].Tokens[Max(LOffset - LSourceOffset, 0) + K];
        { These indices remain source provenance only. The musical solver must
          generate and authenticate new states compatible with its real frontier. }
        ALocks[I].States[LAt] := LChunk.Providers[J].States[Max(LOffset - LSourceOffset, 0) + K];
        Inc(LAt);
      end;
    end;
    Need(LAt = ACellCount, 'Referenced motif is not completely recorded');
  end;
  Result := True;
end;

function TMusicFormCursor.CopyLocks(const ACellCount: Integer): TMusicDecisionProviders;
begin
  Need(TryCopyLocksAt(CellCount, ACellCount, Result), 'Referenced motif is not completely recorded');
end;

procedure TMusicFormCursor.Append(const AChunk: TMusicDecisionChunk);
var LLocks: TMusicDecisionProviders;
  LCopy: TMusicDecisionChunk;
  LBytes, I, J, K, LCount: Integer;
begin
  CheckNext(AChunk);
  for I := 0 to High(FProviderKeys) do
  begin
    J := 0;
    while (J < Length(AChunk.Providers)) and (AChunk.Providers[J].Key <> FProviderKeys[I]) do Inc(J);
    Need(J < Length(AChunk.Providers), 'Generated form differs from its declared provider names');
  end;
  LLocks := CopyLocks(Length(AChunk.Cells));
  for I := 0 to High(LLocks) do
  begin
    J := 0;
    while (J < Length(AChunk.Providers)) and (AChunk.Providers[J].Key <> LLocks[I].Key) do Inc(J);
    Need(J < Length(AChunk.Providers), 'Generated phrase is missing a retained provider');
    for K := 0 to High(LLocks[I].Tokens) do
      Need(AChunk.Providers[J].Tokens[K] = LLocks[I].Tokens[K],
        'Generated phrase changed an explicitly retained motif');
  end;
  LBytes := 0;
  if FNeeded[FPhrase] then
  begin
    for I := 0 to High(AChunk.Providers) do
    begin
      Inc(LBytes, ScalarTextByteCount(AChunk.Providers[I].Key, 256, False));
      Need(LBytes <= MaximumMusicFormTextBytes - FTextBytes,
        'Motif text cache exceeds its explicit budget');
      for J := 0 to High(AChunk.Providers[I].Tokens) do
      begin
        Inc(LBytes, ScalarTextByteCount(AChunk.Providers[I].Tokens[J], 32768, False));
        Need(LBytes <= MaximumMusicFormTextBytes - FTextBytes,
          'Motif text cache exceeds its explicit budget');
      end;
    end;
    LCopy := CopyMusicDecisionChunk(AChunk);
    LCount := Length(FCache[FPhrase]);
    SetLength(FCache[FPhrase], LCount + 1);
    FCache[FPhrase][LCount] := LCopy;
  end;
  Commit(AChunk);
  Inc(FTextBytes, LBytes);
  if CellCount = FStarts[FPhrase] + FForm[FPhrase].Cells then Inc(FPhrase);
end;

end.
