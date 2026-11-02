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
unit pythian.wfc.semantic.archive;

{$mode delphi}{$H+}

interface

uses pythian.audio, pythian.progress, pythian.stream.bytes;

const
  MaximumSemanticArchiveBytes = 32 * 1024 * 1024;
  MaximumSemanticArchiveNodes = 64;
  MaximumSemanticArchiveSections = 131072;
  { Four bounded read/build/verify/write traversals per admitted node. }
  MaximumSemanticArchiveWork = Int64(4) * MaximumSemanticArchiveNodes * MaximumSemanticArchiveBytes;
  { Preserve every producer's per-model bound, up to 16 providers and two
    primary learning passes per node. Codec work uses a separate counter. }
  MaximumSemanticArchiveLearningWork = Int64(MaximumSemanticArchiveNodes) * 32 * 512 * 1024 * 1024;

type
  TSemanticByteSections = array of TAudioBytes;
  { Internal immutable snapshots. Managed blocks are shared inside the primary
    style owner; public style callers receive detached definitions/bytes. }
  TSemanticArchiveNode = record
    Identity: String;
    Format: Integer;
    Kind: Integer;
    Parent: String;
    OtherParent: String;
    Recipe: TAudioBytes;
    Definition: TSemanticByteSections;
  end;
  TSemanticArchiveNodes = array of TSemanticArchiveNode;
  TSemanticArchiveWork = class
  private
    FBytes: Int64;
    FSteps: Int64;
    FBudget: TWorkBudget;
    function GetSteps: Int64;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Charge(const ABytes, ASteps: Int64);
    property Bytes: Int64 read FBytes;
    property Steps: Int64 read GetSteps;
    property Budget: TWorkBudget read FBudget;
  end;

  TSemanticArchiveRefs = array of Integer;
  { Only this owner computes/trusts payload digests. No caller can supply a
    cached digest or mutate an interned block; all byte views are detached. }
  TSemanticArchive = class
  private
    FNodes: TSemanticArchiveNodes;
    FPayloads: TSemanticByteSections;
    FHashes: array of String;
    FSlots: TSemanticArchiveRefs;
    FRecipeRefs: TSemanticArchiveRefs;
    FDefinitionRefs: array of TSemanticArchiveRefs;
    FPayloadBytes: Int64;
    function Intern(const ABytes: TAudioBytes; const AKnownHash: String;
      const ADetach: Boolean; const AWork: TSemanticArchiveWork;
      const AProgress: TWorkProgressCallback): Integer;
    procedure Import(const AParent: TSemanticArchive; const AWork: TSemanticArchiveWork;
      const AProgress: TWorkProgressCallback);
    procedure Append(const ANode: TSemanticArchiveNode; const AWork: TSemanticArchiveWork;
      const AProgress: TWorkProgressCallback);
    function GetCount: Integer;
  public
    constructor Create(const ALeft, ARight: TSemanticArchive;
      const ANode: TSemanticArchiveNode; const AWork: TSemanticArchiveWork;
      const AProgress: TWorkProgressCallback);
    constructor CreateEncoded(const ABytes: TAudioBytes;
      const AWork: TSemanticArchiveWork; const AProgress: TWorkProgressCallback);
    function NodeHeader(const AIndex: Integer): TSemanticArchiveNode;
    function DefinitionBytes(const AIndex: Integer;
      const AProgress: TWorkProgressCallback): TAudioBytes;
    function RecipeBytes(const AIndex: Integer): TAudioBytes;
    function Encode(const ARoot: Integer; const AWork: TSemanticArchiveWork;
      const AProgress: TWorkProgressCallback = nil): TAudioBytes;
    function Identity(const AIndex: Integer): String;
    function ParentIdentity(const ASide: Integer): String;
    procedure SetRootFormat(const AFormat: Integer);
    procedure SealRoot(const AIdentity: String);
    property Count: Integer read GetCount;
    property PayloadBytes: Int64 read FPayloadBytes;
  end;

  TStyleIO = class
  private
    FStream: TAudioBytesStream;
    FNumberBytes: TAudioBytes;
    FReading: Boolean;
    FProgress: TWorkProgressCallback;
    FFields: Int64;
    FSectionOffsets: array of Integer;
    FCaptureSections: Boolean;
    function GetPosition: Int64;
    function GetSize: Int64;
    procedure VisitField;
  public
    constructor Create(const ABytes: TAudioBytes; const AReading: Boolean;
      const AProgress: TWorkProgressCallback = nil; const ACaptureSections: Boolean = False);
    destructor Destroy; override;
    function N(const AValue: Integer = 0): Integer;
    function U(const AValue: Cardinal): Cardinal;
    function Q(const AValue: Int64 = 0): Int64;
    function R(const AValue: Double): Double;
    function Count(const AValue, AMaximum: Integer): Integer;
    function Text(const AValue: String = ''; const AMaximum: Integer = 1048576): String;
    function Blob(const AValue: TAudioBytes;
      const AMaximum: Integer = MaximumSemanticArchiveBytes): TAudioBytes;
    function Bytes: TAudioBytes;
    procedure Raw(const ABytes: TAudioBytes);
    procedure EndOfInput;
    procedure MarkSection;
    function Sections: TSemanticByteSections;
    property Reading: Boolean read FReading;
    property Progress: TWorkProgressCallback read FProgress;
    property Position: Int64 read GetPosition;
    property Size: Int64 read GetSize;
  end;

function SemanticArchiveJoin(const ASections: TSemanticByteSections;
  const AProgress: TWorkProgressCallback = nil): TAudioBytes;

implementation

uses SysUtils, pythian.text, pythian.binary, pythian.hash;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

constructor TSemanticArchiveWork.Create;
begin
  inherited Create;
  FBudget := TWorkBudget.Create(MaximumSemanticArchiveLearningWork,
    'Style ancestry aggregate learning; choose fewer independent parent histories');
end;

destructor TSemanticArchiveWork.Destroy;
begin FBudget.Free; inherited Destroy end;

function TSemanticArchiveWork.GetSteps: Int64;
begin Result := FSteps end;

procedure TSemanticArchiveWork.Charge(const ABytes, ASteps: Int64);
begin
  Need((ABytes >= 0) and (ASteps >= 0) and (ABytes = Trunc(ABytes)) and (ASteps = Trunc(ASteps)) and
    (ABytes <= MaximumSemanticArchiveWork - FBytes) and
    (ASteps <= MaximumSemanticArchiveWork - FSteps),
    'Style ancestry exceeds its aggregate codec byte/work budget; use fewer independent parent histories');
  Inc(FSteps, ASteps); Inc(FBytes, ABytes);
end;

constructor TStyleIO.Create(const ABytes: TAudioBytes; const AReading: Boolean;
  const AProgress: TWorkProgressCallback; const ACaptureSections: Boolean);
var
  LOffset: Integer;
  LBlock: Integer;
begin
  inherited Create;
  FStream := TAudioBytesStream.Create(MaximumSemanticArchiveBytes);
  SetLength(FNumberBytes, 8);
  FReading := AReading;
  FCaptureSections := ACaptureSections;
  FProgress := AProgress;
  ReportWork(FProgress, 'semantic_archive_fields', wuItems, 0, 0);
  if Length(ABytes) > MaximumSemanticArchiveBytes then
  begin
    raise EAudio.Create('Semantic archive exceeds 32 MiB');
  end;
  if AReading and (Length(ABytes) > 0) then
  begin
    ReportWork(FProgress, 'semantic_archive_input', wuBytes, 0, Length(ABytes));
    LOffset := 0;
    while LOffset < Length(ABytes) do
    begin
      LBlock := Length(ABytes) - LOffset;
      if LBlock > 65536 then
      begin
        LBlock := 65536;
      end;
      WriteStreamBytesExact(FStream, ABytes, LOffset, LBlock);
      Inc(LOffset, LBlock);
      ReportWork(FProgress, 'semantic_archive_input', wuBytes, LOffset, Length(ABytes));
    end;
    FStream.Position := 0;
  end;
end;

destructor TStyleIO.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

procedure TStyleIO.VisitField;
begin
  Inc(FFields);
  if FFields mod 4096 = 0 then
  begin
    ReportWork(FProgress, 'semantic_archive_fields', wuItems, FFields, 0);
  end;
end;

function TStyleIO.N(const AValue: Integer): Integer;
begin
  VisitField;
  Result := AValue;
  if FReading then
  begin
    if FStream.Size - FStream.Position < 4 then
    begin
      raise EAudio.Create('Truncated semantic number');
    end;
    ReadStreamBytesExact(FStream, FNumberBytes, 0, 4);
    Result := ReadInt32LE(FNumberBytes, 0);
  end
  else
  begin
    WriteInt32LE(FNumberBytes, 0, AValue);
    WriteStreamBytesExact(FStream, FNumberBytes, 0, 4);
  end;
end;

function TStyleIO.U(const AValue: Cardinal): Cardinal;
begin
  VisitField;
  Result := AValue;
  if FReading then
  begin
    ReadStreamBytesExact(FStream, FNumberBytes, 0, 4);
    Result := ReadUInt32LE(FNumberBytes, 0);
  end
  else
  begin
    WriteUInt32LE(FNumberBytes, 0, AValue);
    WriteStreamBytesExact(FStream, FNumberBytes, 0, 4);
  end;
end;

function TStyleIO.Q(const AValue: Int64): Int64;
begin
  Result := AValue;
  if FReading then
  begin
    if FStream.Size - FStream.Position < 8 then
    begin
      raise EAudio.Create('Truncated semantic wide number');
    end;
    ReadStreamBytesExact(FStream, FNumberBytes, 0, 8);
    Result := ReadInt64LE(FNumberBytes, 0);
  end
  else
  begin
    WriteInt64LE(FNumberBytes, 0, AValue);
    WriteStreamBytesExact(FStream, FNumberBytes, 0, 8);
  end;
end;

function TStyleIO.Count(const AValue, AMaximum: Integer): Integer;
begin
  Result := N(AValue);
  if (Result < 0) or (Result > AMaximum) then
  begin
    raise EAudio.Create('Semantic count or enum exceeds contract');
  end;
end;

function TStyleIO.R(const AValue: Double): Double;
begin
  Result := AValue;
  if FReading then
  begin
    ReadStreamBytesExact(FStream, FNumberBytes, 0, 8);
    Result := ReadFloat64LE(FNumberBytes, 0);
  end
  else
  begin
    WriteFloat64LE(FNumberBytes, 0, AValue);
    WriteStreamBytesExact(FStream, FNumberBytes, 0, 8);
  end;
  RequireFinite(Result, 'Semantic instrumental recipe');
end;

function TStyleIO.Blob(const AValue: TAudioBytes; const AMaximum: Integer): TAudioBytes;
var
  LCount: Integer;
  LOffset: Integer;
  LBlock: Integer;
begin
  Result := nil;
  LCount := Count(Length(AValue), AMaximum);
  if LCount >= 65536 then
    ReportWork(FProgress, 'semantic_archive_blob', wuBytes, 0, LCount);
  if FReading then
  begin
    if LCount > FStream.Size - FStream.Position then
    begin
      raise EAudio.Create('Truncated semantic blob');
    end;
    SetLength(Result, LCount);
    LOffset := 0;
    while LOffset < LCount do
    begin
      LBlock := LCount - LOffset;
      if LBlock > 65536 then
      begin
        LBlock := 65536;
      end;
      ReadStreamBytesExact(FStream, Result, LOffset, LBlock);
      Inc(LOffset, LBlock);
      if LCount >= 65536 then
        ReportWork(FProgress, 'semantic_archive_blob', wuBytes, LOffset, LCount);
    end;
  end
  else
  begin
    Result := AValue;
    LOffset := 0;
    while LOffset < LCount do
    begin
      LBlock := LCount - LOffset;
      if LBlock > 65536 then
      begin
        LBlock := 65536;
      end;
      WriteStreamBytesExact(FStream, AValue, LOffset, LBlock);
      Inc(LOffset, LBlock);
      if LCount >= 65536 then
        ReportWork(FProgress, 'semantic_archive_blob', wuBytes, LOffset, LCount);
    end;
    if FStream.Size > MaximumSemanticArchiveBytes then
    begin
      raise EAudio.Create('Semantic archive exceeds 32 MiB');
    end;
  end;
end;

function TStyleIO.Text(const AValue: String; const AMaximum: Integer): String;
var
  LBytes: TAudioBytes;
begin
  LBytes := nil;
  if not FReading then
  begin
    LBytes := EncodeUTF8Text(TScalarText(AValue), AMaximum, True, True);
    Blob(LBytes, AMaximum);
    Exit(AValue);
  end;
  LBytes := Blob(LBytes, AMaximum);
  Result := String(DecodeUTF8Text(LBytes, AMaximum, True, True));
end;

function TStyleIO.Bytes: TAudioBytes;
var
  LOffset: Integer;
  LBlock: Integer;
  LPosition: Int64;
begin
  Result := nil;
  SetLength(Result, FStream.Size);
  if FStream.Size >= 65536 then
    ReportWork(FProgress, 'semantic_archive_output', wuBytes, 0, FStream.Size);
  LPosition := FStream.Position;
  try
    FStream.Position := 0;
    LOffset := 0;
    while LOffset < FStream.Size do
    begin
      LBlock := FStream.Size - LOffset;
      if LBlock > 65536 then
      begin
        LBlock := 65536;
      end;
      ReadStreamBytesExact(FStream, Result, LOffset, LBlock);
      Inc(LOffset, LBlock);
      if FStream.Size >= 65536 then
      begin
        ReportWork(FProgress, 'semantic_archive_output', wuBytes, LOffset, FStream.Size);
      end;
    end;
  finally
    FStream.Position := LPosition;
  end;
end;

procedure TStyleIO.EndOfInput;
begin
  if FReading and (FStream.Position <> FStream.Size) then
  begin
    raise EAudio.Create('Trailing semantic payload');
  end;
end;

function TStyleIO.GetPosition: Int64;
begin Result := FStream.Position end;

function TStyleIO.GetSize: Int64;
begin Result := FStream.Size end;

procedure TStyleIO.MarkSection;
var N: Integer;
begin
  if FReading or not FCaptureSections or (FStream.Position = 0) then Exit;
  N := Length(FSectionOffsets);
  if (N > 0) and (FSectionOffsets[N - 1] = FStream.Position) then Exit;
  Need(N < MaximumSemanticArchiveSections, 'Style definition exceeds its section-reference budget');
  SetLength(FSectionOffsets, N + 1); FSectionOffsets[N] := FStream.Position;
end;

function TStyleIO.Sections: TSemanticByteSections;
var LBytes: TAudioBytes; I, LFirst: Integer;
begin
  Result := nil;
  if not FCaptureSections or FReading then
    raise EAudio.Create('Semantic sections require an explicit writing snapshot');
  MarkSection; LBytes := Bytes; LFirst := 0;
  SetLength(Result, Length(FSectionOffsets));
  for I := 0 to High(Result) do
  begin
    Result[I] := Copy(LBytes, LFirst, FSectionOffsets[I] - LFirst);
    LFirst := FSectionOffsets[I];
  end;
end;

procedure TStyleIO.Raw(const ABytes: TAudioBytes);
var LOffset, LBlock: Integer;
begin
  Need(not FReading, 'Raw semantic output requires a writer');
  Need(Length(ABytes) <= MaximumSemanticArchiveBytes - FStream.Size,
    'Semantic archive exceeds 32 MiB');
  LOffset := 0;
  while LOffset < Length(ABytes) do
  begin
    LBlock := Length(ABytes) - LOffset;
    if LBlock > 65536 then LBlock := 65536;
    WriteStreamBytesExact(FStream, ABytes, LOffset, LBlock);
    Inc(LOffset, LBlock);
    ReportWork(FProgress, 'semantic_archive_raw', wuBytes, LOffset, Length(ABytes));
  end;
end;

function SemanticArchiveJoin(const ASections: TSemanticByteSections;
  const AProgress: TWorkProgressCallback): TAudioBytes;
var LStream: TAudioBytesStream; I, LTotal: Integer;
begin
  Result := nil; LTotal := 0;
  Need(Length(ASections) <= MaximumSemanticArchiveSections, 'Too many semantic definition sections');
  for I := 0 to High(ASections) do
  begin
    Need(Length(ASections[I]) <= MaximumSemanticArchiveBytes - LTotal,
      'Semantic definition exceeds 32 MiB');
    Inc(LTotal, Length(ASections[I]));
  end;
  LStream := TAudioBytesStream.Create(MaximumSemanticArchiveBytes);
  try
    for I := 0 to High(ASections) do
    begin
      ReportWork(AProgress, 'semantic_archive_sections', wuItems, I, Length(ASections));
      WriteStreamBytesExact(LStream, ASections[I], 0, Length(ASections[I]));
    end;
    SetLength(Result, LTotal); LStream.Position := 0;
    ReadStreamBytesExact(LStream, Result, 0, LTotal);
  finally LStream.Free end;
end;

function PayloadSlot(const AHash: String; const ASize: Integer): Integer;
var I, N: Integer;
begin
  Result := 0;
  for I := 1 to 6 do
  begin
    N := Ord(AHash[I]) - Ord('0');
    if N > 9 then N := Ord(AHash[I]) - Ord('a') + 10;
    Result := Result * 16 + N;
  end;
  Result := Result and (ASize - 1);
end;

function TSemanticArchive.Intern(const ABytes: TAudioBytes;
  const AKnownHash: String; const ADetach: Boolean; const AWork: TSemanticArchiveWork;
  const AProgress: TWorkProgressCallback): Integer;
var LHash: String; LSlot, LValue, I, LSize: Integer; LSame: Boolean;
begin
  AWork.Charge(0, 1);
  LHash := AKnownHash;
  if LHash = '' then
  begin
    AWork.Charge(Length(ABytes), 1);
    LHash := Sha256Bytes(ABytes, AProgress);
  end;
  if (Length(FSlots) = 0) or (Length(FPayloads) * 2 >= Length(FSlots)) then
  begin
    LSize := Length(FSlots) * 2;
    if LSize = 0 then LSize := 16;
    SetLength(FSlots, LSize);
    for I := 0 to High(FSlots) do FSlots[I] := 0;
    for I := 0 to High(FHashes) do
    begin
      LSlot := PayloadSlot(FHashes[I], LSize);
      while FSlots[LSlot] <> 0 do LSlot := (LSlot + 1) and (LSize - 1);
      FSlots[LSlot] := I + 1;
    end;
  end;
  LSlot := PayloadSlot(LHash, Length(FSlots));
  while FSlots[LSlot] <> 0 do
  begin
    AWork.Charge(0, 1); LValue := FSlots[LSlot] - 1;
    if FHashes[LValue] = LHash then
    begin
      AWork.Charge(Length(ABytes), 0);
      LSame := Length(FPayloads[LValue]) = Length(ABytes);
      if LSame then for I := 0 to High(ABytes) do
        begin
        if I mod 65536 = 0 then
          ReportWork(AProgress, 'semantic_archive_compare_payload', wuBytes, I, Length(ABytes));
        if FPayloads[LValue][I] <> ABytes[I] then begin LSame := False; Break end;
      end;
      Need(LSame, 'Semantic payload digest collision');
      Exit(LValue);
    end;
    LSlot := (LSlot + 1) and (Length(FSlots) - 1);
  end;
  Need(Length(FPayloads) < MaximumSemanticArchiveSections,
    'Style archive exceeds its unique payload budget');
  Need(Length(ABytes) <= MaximumSemanticArchiveBytes - FPayloadBytes,
    'Style archive exceeds 32 MiB of unique payloads; choose fewer independent models');
  Inc(FPayloadBytes, Length(ABytes));
  Result := Length(FPayloads);
  SetLength(FPayloads, Result + 1);
  if ADetach then FPayloads[Result] := Copy(ABytes) else FPayloads[Result] := ABytes;
  SetLength(FHashes, Result + 1); FHashes[Result] := LHash;
  FSlots[LSlot] := Result + 1;
end;

procedure TSemanticArchive.Import(const AParent: TSemanticArchive;
  const AWork: TSemanticArchiveWork; const AProgress: TWorkProgressCallback);
var LMap: TSemanticArchiveRefs; I, J, K, N: Integer; LFound: Boolean;
  function Payload(const ARef: Integer): Integer;
  begin
    Result := LMap[ARef];
    if Result >= 0 then Exit;
    Result := Intern(AParent.FPayloads[ARef], AParent.FHashes[ARef], False, AWork, AProgress);
    LMap[ARef] := Result;
  end;
begin
  if AParent = nil then Exit;
  SetLength(LMap, Length(AParent.FPayloads));
  for I := 0 to High(LMap) do LMap[I] := -1;
  for I := 0 to High(AParent.FNodes) do
  begin
    Need(AParent.FNodes[I].Identity <> '', 'Only sealed ancestry may be imported');
    LFound := False;
    for J := 0 to High(FNodes) do LFound := LFound or
      (FNodes[J].Identity = AParent.FNodes[I].Identity);
    if LFound then Continue;
    Need(Length(FNodes) < MaximumSemanticArchiveNodes,
      'Style ancestry exceeds 64 unique nodes; choose fewer parent histories');
    N := Length(FNodes); SetLength(FNodes, N + 1);
    FNodes[N] := AParent.FNodes[I];
    SetLength(FRecipeRefs, N + 1);
    K := Payload(AParent.FRecipeRefs[I]);
    FRecipeRefs[N] := K; FNodes[N].Recipe := FPayloads[K];
    SetLength(FDefinitionRefs, N + 1);
    SetLength(FDefinitionRefs[N], Length(AParent.FDefinitionRefs[I]));
    FNodes[N].Definition := Copy(AParent.FNodes[I].Definition);
    for J := 0 to High(FDefinitionRefs[N]) do
    begin
      K := Payload(AParent.FDefinitionRefs[I][J]);
      FDefinitionRefs[N][J] := K; FNodes[N].Definition[J] := FPayloads[K];
    end;
  end;
end;

procedure TSemanticArchive.Append(const ANode: TSemanticArchiveNode;
  const AWork: TSemanticArchiveWork; const AProgress: TWorkProgressCallback);
var N, I, K: Integer;
begin
  N := Length(FNodes);
  Need(N < MaximumSemanticArchiveNodes,
    'Style ancestry exceeds 64 unique nodes; choose fewer parent histories');
  Need((Length(ANode.Definition) > 0) and
    (Length(ANode.Definition) <= MaximumSemanticArchiveSections),
    'Invalid semantic definition section inventory');
  SetLength(FNodes, N + 1); FNodes[N] := ANode;
  SetLength(FRecipeRefs, N + 1);
  K := Intern(ANode.Recipe, '', True, AWork, AProgress);
  FRecipeRefs[N] := K; FNodes[N].Recipe := FPayloads[K];
  SetLength(FDefinitionRefs, N + 1);
  SetLength(FDefinitionRefs[N], Length(ANode.Definition));
  FNodes[N].Definition := Copy(ANode.Definition);
  for I := 0 to High(ANode.Definition) do
  begin
    ReportWork(AProgress, 'semantic_archive_intern_sections', wuItems, I, Length(ANode.Definition));
    K := Intern(ANode.Definition[I], '', True, AWork, AProgress);
    FDefinitionRefs[N][I] := K; FNodes[N].Definition[I] := FPayloads[K];
  end;
end;

constructor TSemanticArchive.Create(const ALeft, ARight: TSemanticArchive;
  const ANode: TSemanticArchiveNode; const AWork: TSemanticArchiveWork;
  const AProgress: TWorkProgressCallback);
begin
  inherited Create;
  Import(ALeft, AWork, AProgress); Import(ARight, AWork, AProgress);
  Append(ANode, AWork, AProgress);
end;

function TSemanticArchive.GetCount: Integer;
begin Result := Length(FNodes) end;

function TSemanticArchive.Identity(const AIndex: Integer): String;
begin
  Need((AIndex >= 0) and (AIndex < Count), 'Invalid semantic node reference');
  Result := FNodes[AIndex].Identity;
end;

function TSemanticArchive.ParentIdentity(const ASide: Integer): String;
begin
  Need((Count > 0) and (ASide in [0, 1]), 'Invalid semantic parent side');
  if ASide = 0 then Result := FNodes[High(FNodes)].Parent
  else Result := FNodes[High(FNodes)].OtherParent;
end;

procedure TSemanticArchive.SetRootFormat(const AFormat: Integer);
begin
  Need((Count > 0) and (AFormat in [4, 5, 6]), 'Invalid imported root format');
  FNodes[High(FNodes)].Format := AFormat;
end;

procedure TSemanticArchive.SealRoot(const AIdentity: String);
begin
  Need((Count > 0) and (Length(AIdentity) = 64), 'Invalid semantic root identity');
  FNodes[High(FNodes)].Identity := AIdentity;
end;

function TSemanticArchive.Encode(const ARoot: Integer;
  const AWork: TSemanticArchiveWork; const AProgress: TWorkProgressCallback): TAudioBytes;
type TRefs = array of Integer;
var LStates, LOrder, LLeft, LRight: TRefs;
  LPayloads: TSemanticByteSections; LPayloadOrder: TRefs;
  LRecipeRefs: TRefs; LDefinitionRefs: array of TRefs;
  LIO: TStyleIO; LBody: TAudioBytes; I, J, K: Integer;
  function Find(const AIdentity: String): Integer;
  var N: Integer;
  begin
    Result := -1;
    if AIdentity = '' then Exit;
    for N := 0 to High(FNodes) do
      if FNodes[N].Identity = AIdentity then Exit(N);
    raise EAudio.Create('Style ancestry has a dangling parent reference');
  end;
  function Ordered(const AIndex: Integer): Integer;
  var N: Integer;
  begin
    for N := 0 to High(LOrder) do if LOrder[N] = AIndex then Exit(N);
    Result := -1;
  end;
  procedure Visit(const AIndex, ADepth: Integer);
  var LNode: TSemanticArchiveNode; LParent, LOther, N: Integer;
  begin
    Need((AIndex >= 0) and (AIndex < Length(FNodes)), 'Invalid semantic root reference');
    Need(ADepth <= MaximumSemanticArchiveNodes, 'Style ancestry exceeds its depth budget');
    Need(LStates[AIndex] <> 1, 'Style ancestry contains a cycle');
    if LStates[AIndex] = 2 then Exit;
    AWork.Charge(0, 1);
    LStates[AIndex] := 1; LNode := FNodes[AIndex];
    Need((LNode.Format >= 4) and (LNode.Format <= 7) and (LNode.Kind >= 0) and (LNode.Kind <= 4),
      'Unsupported semantic node format or kind');
    LParent := Find(LNode.Parent); LOther := Find(LNode.OtherParent);
    Need(((LNode.Kind = 0) and (LParent < 0) and (LOther < 0)) or
      ((LNode.Kind in [1, 4]) and (LParent >= 0) and (LOther < 0)) or
      ((LNode.Kind in [2, 3]) and (LParent >= 0) and (LOther >= 0)),
      'Semantic node kind differs from its parent inventory');
    if LParent >= 0 then Visit(LParent, ADepth + 1);
    if LOther >= 0 then Visit(LOther, ADepth + 1);
    N := Length(LOrder); SetLength(LOrder, N + 1); LOrder[N] := AIndex;
    SetLength(LLeft, N + 1); SetLength(LRight, N + 1);
    LLeft[N] := Ordered(LParent); LRight[N] := Ordered(LOther);
    LStates[AIndex] := 2;
  end;
  function InternRef(const ARef: Integer): Integer;
  begin
    AWork.Charge(0, 1);
    Result := LPayloadOrder[ARef];
    if Result >= 0 then Exit;
    Result := Length(LPayloads);
    SetLength(LPayloads, Result + 1);
    LPayloads[Result] := FPayloads[ARef];
    LPayloadOrder[ARef] := Result;
  end;
  function Legacy(const AIndex, ADepth: Integer; var ACount: Integer): TAudioBytes;
  var LNode: TSemanticArchiveNode; LWriter: TStyleIO; LFirst, LSecond, LDef, LBody: TAudioBytes;
  begin
    Inc(ACount);
    Need((ADepth <= 8) and (ACount <= 8), 'Imported legacy ancestry exceeds its original eight-node budget');
    LNode := FNodes[AIndex];
    Need(LNode.Format in [4, 5, 6], 'Legacy semantic node cannot contain a newer parent format');
    LFirst := nil; LSecond := nil;
    if LNode.Parent <> '' then LFirst := Legacy(Find(LNode.Parent), ADepth + 1, ACount);
    if LNode.OtherParent <> '' then LSecond := Legacy(Find(LNode.OtherParent), ADepth + 1, ACount);
    LDef := SemanticArchiveJoin(LNode.Definition, AProgress);
    AWork.Charge(Length(LFirst) + Int64(Length(LSecond)) + Length(LDef), 1);
    LWriter := TStyleIO.Create(nil, False, AProgress);
    try
      LWriter.Text('pythian.semantic.style.v' + IntToStr(LNode.Format)); LWriter.N(LNode.Kind);
      LWriter.Blob(LFirst); LWriter.Blob(LSecond); LWriter.Raw(LNode.Recipe); LWriter.Blob(LDef);
      LBody := LWriter.Bytes; LWriter.Text(Sha256Bytes(LBody, AProgress)); Result := LWriter.Bytes;
    finally LWriter.Free end;
  end;
begin
  Result := nil;
  Need(AWork <> nil, 'Semantic archive requires its aggregate work owner');
  Need((Length(FNodes) > 0) and (Length(FNodes) <= MaximumSemanticArchiveNodes),
    'Style archive requires 1..64 unique ancestry nodes');
  SetLength(LStates, Length(FNodes)); Visit(ARoot, 1);
  if FNodes[ARoot].Format <> 7 then
  begin I := 0; Exit(Legacy(ARoot, 1, I)) end;
  SetLength(LPayloadOrder, Length(FPayloads));
  for I := 0 to High(LPayloadOrder) do LPayloadOrder[I] := -1;
  SetLength(LRecipeRefs, Length(LOrder)); SetLength(LDefinitionRefs, Length(LOrder));
  for I := 0 to High(LOrder) do
  begin
    ReportWork(AProgress, 'semantic_archive_nodes', wuItems, I, Length(LOrder));
    K := LOrder[I]; LRecipeRefs[I] := InternRef(FRecipeRefs[K]);
    Need((Length(FNodes[K].Definition) > 0) and
      (Length(FNodes[K].Definition) <= MaximumSemanticArchiveSections), 'Invalid semantic definition section inventory');
    SetLength(LDefinitionRefs[I], Length(FNodes[K].Definition));
    for J := 0 to High(LDefinitionRefs[I]) do LDefinitionRefs[I][J] := InternRef(FDefinitionRefs[K][J]);
  end;
  LIO := TStyleIO.Create(nil, False, AProgress);
  try
    LIO.Text('pythian.semantic.style.v7');
    LIO.Count(Length(LPayloads), MaximumSemanticArchiveSections);
    for I := 0 to High(LPayloads) do LIO.Blob(LPayloads[I]);
    LIO.Count(Length(LOrder), MaximumSemanticArchiveNodes);
    for I := 0 to High(LOrder) do
    begin
      K := LOrder[I];
      if K = ARoot then LIO.Text('') else LIO.Text(FNodes[K].Identity);
      LIO.N(FNodes[K].Format); LIO.N(FNodes[K].Kind); LIO.N(LLeft[I]); LIO.N(LRight[I]);
      LIO.N(LRecipeRefs[I]); LIO.Count(Length(LDefinitionRefs[I]), MaximumSemanticArchiveSections);
      for J := 0 to High(LDefinitionRefs[I]) do LIO.N(LDefinitionRefs[I][J]);
    end;
    LBody := LIO.Bytes; LIO.Text(Sha256Bytes(LBody, AProgress)); Result := LIO.Bytes;
    AWork.Charge(Length(Result), Length(LOrder));
  finally LIO.Free end;
end;

constructor TSemanticArchive.CreateEncoded(const ABytes: TAudioBytes; const AWork: TSemanticArchiveWork;
  const AProgress: TWorkProgressCallback);
var LIO: TStyleIO; LPayloads: TSemanticArchiveRefs; I, J, N, P, LBody: Integer;
  LHash: String; LCanonical: TAudioBytes;
begin
  inherited Create;
  Need(AWork <> nil, 'Semantic archive requires its aggregate work owner');
  AWork.Charge(Length(ABytes), 1);
  LIO := TStyleIO.Create(ABytes, True, AProgress);
  try
    Need(LIO.Text = 'pythian.semantic.style.v7', 'Expected shared semantic archive format');
    SetLength(LPayloads, LIO.Count(0, MaximumSemanticArchiveSections));
    Need(Length(LPayloads) > 0, 'Semantic archive has no payload inventory');
    for I := 0 to High(LPayloads) do
    begin
      ReportWork(AProgress, 'semantic_archive_read_payloads', wuItems, I, Length(LPayloads));
      LPayloads[I] := Intern(LIO.Blob(nil), '', False, AWork, AProgress);
    end;
    N := LIO.Count(0, MaximumSemanticArchiveNodes);
    Need(N > 0, 'Semantic archive has no root'); SetLength(FNodes, N); SetLength(FRecipeRefs, N); SetLength(FDefinitionRefs, N);
    for I := 0 to High(FNodes) do
    begin
      ReportWork(AProgress, 'semantic_archive_read_nodes', wuItems, I, N);
      FNodes[I].Identity := LIO.Text('', 64);
      Need((I = N - 1) = (FNodes[I].Identity = ''), 'Semantic root/ancestor identity inventory differs');
      for J := 0 to I - 1 do Need(FNodes[I].Identity <> FNodes[J].Identity, 'Duplicate semantic ancestor identity');
      FNodes[I].Format := LIO.N; FNodes[I].Kind := LIO.N;
      P := LIO.N; Need((P >= -1) and (P < I), 'Semantic parent is dangling, forward or cyclic');
      if P >= 0 then FNodes[I].Parent := FNodes[P].Identity;
      P := LIO.N; Need((P >= -1) and (P < I), 'Other semantic parent is dangling, forward or cyclic');
      if P >= 0 then FNodes[I].OtherParent := FNodes[P].Identity;
      P := LPayloads[LIO.Count(0, Length(LPayloads) - 1)];
      FRecipeRefs[I] := P; FNodes[I].Recipe := FPayloads[P];
      SetLength(FNodes[I].Definition, LIO.Count(0, MaximumSemanticArchiveSections));
      SetLength(FDefinitionRefs[I], Length(FNodes[I].Definition));
      for J := 0 to High(FNodes[I].Definition) do
      begin
        P := LPayloads[LIO.Count(0, Length(LPayloads) - 1)];
        FDefinitionRefs[I][J] := P; FNodes[I].Definition[J] := FPayloads[P];
      end;
    end;
    Need(FNodes[High(FNodes)].Format = 7, 'Shared archive requires a current-format root');
    LBody := LIO.Position; LHash := LIO.Text; LIO.EndOfInput;
    Need(LHash = Sha256Bytes(Copy(ABytes, 0, LBody), AProgress), 'Shared semantic payload digest mismatch');
    LCanonical := Encode(High(FNodes), AWork, AProgress);
    Need(Sha256Bytes(LCanonical, AProgress) = Sha256Bytes(ABytes, AProgress),
      'Noncanonical shared semantic ancestry or payload inventory');
    FNodes[High(FNodes)].Identity := Sha256Bytes(ABytes, AProgress);
  finally LIO.Free end;
end;

function TSemanticArchive.NodeHeader(const AIndex: Integer): TSemanticArchiveNode;
begin
  Need((AIndex >= 0) and (AIndex < Count), 'Invalid semantic node reference');
  Result := Default(TSemanticArchiveNode);
  Result.Identity := FNodes[AIndex].Identity;
  Result.Format := FNodes[AIndex].Format;
  Result.Kind := FNodes[AIndex].Kind;
  Result.Parent := FNodes[AIndex].Parent;
  Result.OtherParent := FNodes[AIndex].OtherParent;
end;

function TSemanticArchive.DefinitionBytes(const AIndex: Integer;
  const AProgress: TWorkProgressCallback): TAudioBytes;
begin
  Need((AIndex >= 0) and (AIndex < Count), 'Invalid semantic node reference');
  Result := SemanticArchiveJoin(FNodes[AIndex].Definition, AProgress);
end;

function TSemanticArchive.RecipeBytes(const AIndex: Integer): TAudioBytes;
begin
  Need((AIndex >= 0) and (AIndex < Count), 'Invalid semantic node reference');
  Result := Copy(FNodes[AIndex].Recipe);
end;

end.
