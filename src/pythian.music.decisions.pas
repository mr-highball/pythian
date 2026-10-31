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
unit pythian.music.decisions;

{$mode delphi}
{$H+}

interface

uses Classes, pythian.audio, pythian.chord, pythian.progress, pythian.hash, pythian.text;

const
  MusicDecisionVersion = 1;
  MaximumMusicDecisionCells = 256;
  MaximumMusicDecisionParts = 12;
  MaximumMusicDecisionProviders = 16;
  MaximumMusicDecisionBytes = 2097152;

type
  TMusicDecisionTokens = array of TScalarText;
  TMusicDecisionStates = array of Integer;
  TMusicDecisionProvider = record
    Key: TScalarText;
    Tokens: TMusicDecisionTokens;
    States: TMusicDecisionStates;
  end;
  TMusicDecisionProviders = array of TMusicDecisionProvider;
  TMusicDecisionCell = record
    FrameCount: Int64;
    Parts: TChordFrame;
  end;
  TMusicDecisionCells = array of TMusicDecisionCell;
  TMusicDecisionChunk = record
    Version: Integer;
    FirstCell: Int64;
    StartFrame: Int64;
    Previous: TChordFrame;
    Cells: TMusicDecisionCells;
    Providers: TMusicDecisionProviders;
  end;
  { Borrowed synchronous sink. May abort, but must not mutate/free inputs or
    reenter its producer. A completed journal is accepted only with its owning
    generation's completion receipt. Planned chunks alone do not prove rendering. }
  TMusicDecisionSink = procedure(const AChunk: TMusicDecisionChunk) of object;

  { One sequential boundary, not a duration-sized score. Streams are borrowed.
    A journal binds to its caller's immutable models/settings/job receipt; token
    and latent state rows are observations, not caller-authorized solver state.
    I/O failure is terminal and can leave a partial record. Never append/retry a
    failed writer or treat partial bytes as a completed performance. }
  TMusicDecisionCursor = class
  private
    FCells: Int64;
    FFrames: Int64;
    FPrevious: TChordFrame;
    FKeys: TMusicDecisionTokens;
  protected
    procedure CheckNext(const AChunk: TMusicDecisionChunk);
    procedure Commit(const AChunk: TMusicDecisionChunk);
  public
    property CellCount: Int64 read FCells;
    property FrameCount: Int64 read FFrames;
  end;
  TMusicDecisionWriter = class(TMusicDecisionCursor)
  private
    FStream: TStream;
    FHash: TSha256Hasher;
    FFailed: Boolean;
    FSealed: Boolean;
    FBusy: Boolean;
    FBytes: Int64;
  public
    constructor Create(const AStream: TStream);
    destructor Destroy; override;
    procedure Append(const AChunk: TMusicDecisionChunk);
    function Seal: String;
    property ByteCount: Int64 read FBytes;
  end;
  TMusicDecisionReader = class(TMusicDecisionCursor)
  private
    FStream: TStream;
    FFailed: Boolean;
    FBusy: Boolean;
    function GetAtEnd: Boolean;
  public
    constructor Create(const AStream: TStream);
    function TryNext(var AChunk: TMusicDecisionChunk;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    property AtEnd: Boolean read GetAtEnd;
  end;

procedure ValidateMusicDecisionChunk(const AChunk: TMusicDecisionChunk;
  const AProgress: TWorkProgressCallback = nil);
function CopyMusicDecisionChunk(const AChunk: TMusicDecisionChunk): TMusicDecisionChunk;
function MusicDecisionFrameCount(const AChunk: TMusicDecisionChunk): Int64;
function EncodeMusicDecisions(const AChunk: TMusicDecisionChunk;
  const AProgress: TWorkProgressCallback = nil): TAudioBytes;
function DecodeMusicDecisions(const ABytes: TAudioBytes;
  const AProgress: TWorkProgressCallback = nil): TMusicDecisionChunk;

implementation

uses SysUtils, pythian.binary, pythian.time, pythian.stream.bytes;

const CMagic = $31444D50;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function SameFrame(const A, B: TChordFrame): Boolean;
  var I, J: Integer;
begin
  Result := False;
  if Length(A) <> Length(B) then Exit;
  for I := 0 to High(A) do
  begin
    if (A[I].Action <> B[I].Action) or (Length(A[I].Tones) <> Length(B[I].Tones)) then Exit;
    for J := 0 to High(A[I].Tones) do
    begin
      if (A[I].Tones[J].Pitch <> B[I].Tones[J].Pitch) or
        (A[I].Tones[J].Velocity <> B[I].Tones[J].Velocity) then Exit;
    end;
  end;
  Result := True;
end;

function MusicDecisionFrameCount(const AChunk: TMusicDecisionChunk): Int64;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(AChunk.Cells) do
  begin
    RequireExactTimingCounter(AChunk.Cells[I].FrameCount, 'Decision cell frames');
    Need((AChunk.Cells[I].FrameCount > 0) and
      (AChunk.Cells[I].FrameCount <= MaximumTimingInteger - Result),
      'Decision cell must have a positive exact frame extent');
    Inc(Result, AChunk.Cells[I].FrameCount);
  end;
end;

procedure ValidateMusicDecisionChunk(const AChunk: TMusicDecisionChunk;
  const AProgress: TWorkProgressCallback);
var
  LCaps: TChordCapacities;
  LPrevious: TChordFrame;
  I, J: Integer;
  procedure CheckFrame(const AFrame: TChordFrame);
  var LPart: Integer;
  begin
    for LPart := 0 to High(AFrame) do
    begin
      Need((Ord(AFrame[LPart].Action) >= Ord(caRest)) and
        (Ord(AFrame[LPart].Action) <= Ord(caHold)), 'Unknown decision action');
    end;
    ValidateChordTransition(AFrame, LPrevious, LCaps);
  end;
begin
  Need(AChunk.Version = MusicDecisionVersion, 'Unsupported music decision version');
  RequireExactTimingCounter(AChunk.FirstCell, 'Decision first cell');
  RequireExactTimingCounter(AChunk.StartFrame, 'Decision first frame');
  Need((Length(AChunk.Cells) > 0) and
    (Length(AChunk.Cells) <= MaximumMusicDecisionCells), 'Decision chunk cell bound exceeded');
  Need(AChunk.FirstCell <= MaximumTimingInteger - Length(AChunk.Cells),
    'Decision cell clock exceeds exact timing');
  Need(AChunk.StartFrame <= MaximumTimingInteger - MusicDecisionFrameCount(AChunk),
    'Decision frame clock exceeds exact timing');
  Need((Length(AChunk.Previous) > 0) and
    (Length(AChunk.Previous) <= MaximumMusicDecisionParts), 'Decision part bound exceeded');
  Need(Length(AChunk.Providers) <= MaximumMusicDecisionProviders,
    'Decision provider bound exceeded');
  SetLength(LCaps, Length(AChunk.Previous));
  for I := 0 to High(LCaps) do LCaps[I] := 128;
  LPrevious := AChunk.Previous;
  CheckFrame(AChunk.Previous);
  if AChunk.FirstCell = 0 then
  begin
    Need(AChunk.StartFrame = 0, 'First music decision must begin at frame zero');
    for I := 0 to High(AChunk.Previous) do
      Need(AChunk.Previous[I].Action = caRest, 'First decision has an active predecessor');
  end;
  for I := 0 to High(AChunk.Cells) do
  begin
    ReportWork(AProgress, 'music_decision_validate', wuItems, I, Length(AChunk.Cells));
    CheckFrame(AChunk.Cells[I].Parts);
    LPrevious := AChunk.Cells[I].Parts;
  end;
  for I := 0 to High(AChunk.Providers) do
  begin
    ValidateScalarText(AChunk.Providers[I].Key, 256, False);
    for J := 0 to I - 1 do
      Need(AChunk.Providers[I].Key <> AChunk.Providers[J].Key, 'Duplicate decision provider');
    Need((Length(AChunk.Providers[I].Tokens) = Length(AChunk.Cells)) and
      (Length(AChunk.Providers[I].States) = Length(AChunk.Cells)),
      'Decision provider length differs from its cell clock');
    for J := 0 to High(AChunk.Cells) do
    begin
      ValidateScalarText(AChunk.Providers[I].Tokens[J], 32768, False);
      Need(AChunk.Providers[I].States[J] >= 0, 'Decision latent state is negative');
    end;
  end;
  ReportWork(AProgress, 'music_decision_validate', wuItems,
    Length(AChunk.Cells), Length(AChunk.Cells));
end;

function CopyMusicDecisionChunk(const AChunk: TMusicDecisionChunk): TMusicDecisionChunk;
var LCopy: TMusicDecisionChunk; I: Integer;
begin
  LCopy := AChunk;
  LCopy.Previous := CopyChordFrame(AChunk.Previous);
  LCopy.Cells := Copy(AChunk.Cells);
  for I := 0 to High(LCopy.Cells) do
    LCopy.Cells[I].Parts := CopyChordFrame(AChunk.Cells[I].Parts);
  LCopy.Providers := Copy(AChunk.Providers);
  for I := 0 to High(LCopy.Providers) do
  begin
    LCopy.Providers[I].Tokens := Copy(AChunk.Providers[I].Tokens);
    LCopy.Providers[I].States := Copy(AChunk.Providers[I].States);
  end;
  Result := LCopy;
end;

function EncodeMusicDecisions(const AChunk: TMusicDecisionChunk;
  const AProgress: TWorkProgressCallback): TAudioBytes;
var
  LStream: TAudioBytesStream;
  LWord, LText, LBytes: TAudioBytes;
  LHash: String;
  I, J: Integer;
  procedure Number(const AValue: Integer);
  begin
    WriteInt32LE(LWord, 0, AValue);
    WriteStreamBytesExact(LStream, LWord, 0, 4);
  end;
  procedure Wide(const AValue: Int64);
  begin
    WriteInt64LE(LWord, 0, AValue);
    WriteStreamBytesExact(LStream, LWord, 0, 8);
  end;
  procedure Text(const AValue: TScalarText; const AMaximum: Integer);
  begin
    LText := EncodeUTF8Text(AValue, AMaximum, False);
    Number(Length(LText));
    WriteStreamBytesExact(LStream, LText, 0, Length(LText));
  end;
  procedure Frame(const AFrame: TChordFrame);
  var LPart, LTone: Integer;
  begin
    Number(Length(AFrame));
    for LPart := 0 to High(AFrame) do
    begin
      Number(Ord(AFrame[LPart].Action));
      Number(Length(AFrame[LPart].Tones));
      for LTone := 0 to High(AFrame[LPart].Tones) do
      begin
        Number(AFrame[LPart].Tones[LTone].Pitch);
        Number(AFrame[LPart].Tones[LTone].Velocity);
      end;
    end;
  end;
begin
  ValidateMusicDecisionChunk(AChunk, AProgress);
  LStream := TAudioBytesStream.Create(MaximumMusicDecisionBytes - 64);
  try
    SetLength(LWord, 8);
    Number(CMagic);
    Number(AChunk.Version);
    Wide(AChunk.FirstCell);
    Wide(AChunk.StartFrame);
    Frame(AChunk.Previous);
    Number(Length(AChunk.Cells));
    for I := 0 to High(AChunk.Cells) do
    begin
      Wide(AChunk.Cells[I].FrameCount);
      Frame(AChunk.Cells[I].Parts);
    end;
    Number(Length(AChunk.Providers));
    for I := 0 to High(AChunk.Providers) do
    begin
      Text(AChunk.Providers[I].Key, 256);
      for J := 0 to High(AChunk.Cells) do
      begin
        Text(AChunk.Providers[I].Tokens[J], 32768);
        Number(AChunk.Providers[I].States[J]);
      end;
    end;
    LBytes := LStream.Snapshot;
  finally
    LStream.Free;
  end;
  LHash := Sha256Bytes(LBytes, AProgress);
  SetLength(LBytes, Length(LBytes) + 64);
  WriteSha256Hex(LBytes, Length(LBytes) - 64, LHash);
  ReportWork(AProgress, 'music_decision_encode', wuItems, 1, 1);
  Result := LBytes;
end;

function DecodeMusicDecisions(const ABytes: TAudioBytes;
  const AProgress: TWorkProgressCallback): TMusicDecisionChunk;
var
  LChunk: TMusicDecisionChunk;
  LPayload: TAudioBytes;
  LAt, LCells, LParts, LTones, LProviders, I, J: Integer;
  function Number(const AMinimum, AMaximum: Integer): Integer;
  begin
    Need(LAt <= Length(LPayload) - 4, 'Truncated music decision number');
    Result := ReadInt32LE(LPayload, LAt);
    Inc(LAt, 4);
    Need((Result >= AMinimum) and (Result <= AMaximum), 'Music decision number out of range');
  end;
  function Wide: Int64;
  begin
    Need(LAt <= Length(LPayload) - 8, 'Truncated music decision clock');
    Result := ReadInt64LE(LPayload, LAt);
    Inc(LAt, 8);
    RequireExactTimingCounter(Result, 'Decoded decision clock');
  end;
  function Text(const AMaximum: Integer): TScalarText;
  var LCount: Integer;
  begin
    LCount := Number(1, AMaximum);
    Need(LCount <= Length(LPayload) - LAt, 'Truncated music decision text');
    Result := DecodeUTF8Text(Copy(LPayload, LAt, LCount), AMaximum, False);
    Inc(LAt, LCount);
  end;
  function Frame: TChordFrame;
  var LResult: TChordFrame; LPart, LTone: Integer;
  begin
    LParts := Number(1, MaximumMusicDecisionParts);
    SetLength(LResult, LParts);
    for LPart := 0 to LParts - 1 do
    begin
      LResult[LPart].Action := TChordAction(Number(Ord(caRest), Ord(caHold)));
      LTones := Number(0, 128);
      SetLength(LResult[LPart].Tones, LTones);
      for LTone := 0 to LTones - 1 do
      begin
        LResult[LPart].Tones[LTone].Pitch := Number(0, 127);
        LResult[LPart].Tones[LTone].Velocity := Number(1, 127);
      end;
    end;
    Result := LResult;
  end;
begin
  Need((Length(ABytes) > 64) and (Length(ABytes) <= MaximumMusicDecisionBytes),
    'Music decision byte bound exceeded');
  LPayload := Copy(ABytes, 0, Length(ABytes) - 64);
  Need(Sha256HexMatches(ABytes, Length(LPayload), Sha256Bytes(LPayload, AProgress)),
    'Music decision checksum differs');
  LAt := 0;
  Number(CMagic, CMagic);
  LChunk := Default(TMusicDecisionChunk);
  LChunk.Version := Number(MusicDecisionVersion, MusicDecisionVersion);
  LChunk.FirstCell := Wide;
  LChunk.StartFrame := Wide;
  LChunk.Previous := Frame;
  LCells := Number(1, MaximumMusicDecisionCells);
  SetLength(LChunk.Cells, LCells);
  for I := 0 to LCells - 1 do
  begin
    LChunk.Cells[I].FrameCount := Wide;
    LChunk.Cells[I].Parts := Frame;
  end;
  LProviders := Number(0, MaximumMusicDecisionProviders);
  SetLength(LChunk.Providers, LProviders);
  for I := 0 to LProviders - 1 do
  begin
    LChunk.Providers[I].Key := Text(256);
    SetLength(LChunk.Providers[I].Tokens, LCells);
    SetLength(LChunk.Providers[I].States, LCells);
    for J := 0 to LCells - 1 do
    begin
      LChunk.Providers[I].Tokens[J] := Text(32768);
      LChunk.Providers[I].States[J] := Number(0, High(Integer));
    end;
  end;
  Need(LAt = Length(LPayload), 'Music decision has trailing payload');
  ValidateMusicDecisionChunk(LChunk, AProgress);
  ReportWork(AProgress, 'music_decision_decode', wuItems, 1, 1);
  Result := LChunk;
end;

procedure TMusicDecisionCursor.CheckNext(const AChunk: TMusicDecisionChunk);
var I: Integer;
begin
  ValidateMusicDecisionChunk(AChunk);
  Need((AChunk.FirstCell = FCells) and (AChunk.StartFrame = FFrames),
    'Music decision journal has a discontinuous cell/frame clock');
  if FCells = 0 then Exit;
  Need(SameFrame(AChunk.Previous, FPrevious), 'Music decision predecessor differs');
  Need(Length(FKeys) = Length(AChunk.Providers), 'Music decision provider layout differs');
  for I := 0 to High(FKeys) do
    Need(FKeys[I] = AChunk.Providers[I].Key, 'Music decision provider order differs');
end;

procedure TMusicDecisionCursor.Commit(const AChunk: TMusicDecisionChunk);
var I: Integer;
begin
  Inc(FCells, Length(AChunk.Cells));
  Inc(FFrames, MusicDecisionFrameCount(AChunk));
  FPrevious := CopyChordFrame(AChunk.Cells[High(AChunk.Cells)].Parts);
  SetLength(FKeys, Length(AChunk.Providers));
  for I := 0 to High(FKeys) do FKeys[I] := AChunk.Providers[I].Key;
end;

constructor TMusicDecisionWriter.Create(const AStream: TStream);
begin
  inherited Create;
  Need(AStream <> nil, 'Decision writer needs a stream');
  FStream := AStream;
  FHash := TSha256Hasher.Create;
end;

destructor TMusicDecisionWriter.Destroy;
begin
  FHash.Free;
  inherited Destroy;
end;

procedure TMusicDecisionWriter.Append(const AChunk: TMusicDecisionChunk);
var LBytes, LLength: TAudioBytes;
begin
  Need(not FFailed and not FSealed and not FBusy, 'Decision writer is failed, sealed or busy');
  CheckNext(AChunk);
  LBytes := EncodeMusicDecisions(AChunk);
  Need(FBytes <= MaximumTimingInteger - 4 - Length(LBytes),
    'Decision journal byte count exceeds exact timing counters');
  SetLength(LLength, 4);
  WriteInt32LE(LLength, 0, Length(LBytes));
  FBusy := True;
  try
    try
      WriteStreamBytesExact(FStream, LLength, 0, 4);
      WriteStreamBytesExact(FStream, LBytes, 0, Length(LBytes));
      FHash.Update(LLength, 0, 4);
      FHash.Update(LBytes, 0, Length(LBytes));
      Inc(FBytes, 4 + Length(LBytes));
      Commit(AChunk);
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

function TMusicDecisionWriter.Seal: String;
begin
  Need(not FFailed and not FBusy and (CellCount > 0),
    'Cannot seal an empty, busy or failed decision journal');
  Result := FHash.Finish;
  FSealed := True;
end;

constructor TMusicDecisionReader.Create(const AStream: TStream);
begin
  inherited Create;
  Need(AStream <> nil, 'Decision reader needs a stream');
  FStream := AStream;
end;

function TMusicDecisionReader.GetAtEnd: Boolean;
begin
  Result := FStream.Position = FStream.Size;
end;

function TMusicDecisionReader.TryNext(var AChunk: TMusicDecisionChunk;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LBytes, LLength: TAudioBytes;
  LChunk: TMusicDecisionChunk;
  LSize: Integer;
begin
  Need(not FFailed and not FBusy, 'Decision reader is failed or busy');
  if AtEnd then Exit(False);
  FBusy := True;
  try
    try
      SetLength(LLength, 4);
      ReadStreamBytesExact(FStream, LLength, 0, 4);
      LSize := ReadInt32LE(LLength, 0);
      Need((LSize > 64) and (LSize <= MaximumMusicDecisionBytes),
        'Decision record length exceeds its byte bound');
      SetLength(LBytes, LSize);
      ReadStreamBytesExact(FStream, LBytes, 0, LSize);
      LChunk := DecodeMusicDecisions(LBytes, AProgress);
      CheckNext(LChunk);
      ReportWork(AProgress, 'music_decision_read', wuItems,
        CellCount + Length(LChunk.Cells), 0);
      Commit(LChunk);
      AChunk := LChunk;
      Result := True;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

end.
