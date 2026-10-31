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
program pythian_tests_hash_portable;
{$mode delphi}
{$H+}
uses SysUtils, Classes, pythian.audio, pythian.progress, pythian.hash,
  pythian.stream.bytes, pythian.wave.stream;
type
  TRejectingSink = class(TAudioByteSink)
  public
    Calls: Integer;
    Fail: Boolean;
    Emitted: Integer;
    Reenter: THashedAudioByteSink;
    procedure WriteBytes(const ABytes: array of Byte); override;
  end;
  TFragmentStream = class(TMemoryStream)
  public
    FailRead: Boolean;
    {$ifdef pas2js}
    function Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    {$else}
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    {$endif}
  end;
  TObserver = class
    Calls: Integer;
    LastTotal: Int64;
    Abort: Boolean;
    PublicationPhase: Integer;
    Marker: Exception;
    procedure Progress(const AProgress: TWorkProgress);
  end;
var
  LChecks: Integer;
  LPublicationFailures: Integer;
  LPublicationAborts: Integer;

procedure TRejectingSink.WriteBytes(const ABytes: array of Byte);
begin
  Inc(Calls);
  if Fail then
  begin
    Inc(Emitted);
    raise EAudio.Create('Output failure after partial write');
  end;
  Inc(Emitted, Length(ABytes));
  if Reenter <> nil then Reenter.Finish;
end;

{$ifdef pas2js}
function TFragmentStream.Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
begin
  if FailRead then
  begin
    raise Exception.Create('Read marker');
  end;
  if ACount > 7 then
  begin
    ACount := 7;
  end;
  Result := inherited Read(ABuffer, AOffset, ACount);
end;
{$else}
function TFragmentStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  if FailRead then
  begin
    raise Exception.Create('Read marker');
  end;
  if ACount > 7 then
  begin
    ACount := 7;
  end;
  Result := inherited Read(ABuffer, ACount);
end;
{$endif}

procedure TObserver.Progress(const AProgress: TWorkProgress);
begin
  Inc(Calls);
  LastTotal := AProgress.Total;
  if (AProgress.Stage <> 'verify_audio_bytes') or (AProgress.Units <> wuBytes) then
    raise Exception.Create('Progress identity');
  if Abort then
  begin
    raise Exception.Create('Abort marker');
  end;
  if Assigned(Marker) and
    (((PublicationPhase = 1) and (AProgress.Done > 0) and
      (AProgress.Done < AProgress.Total)) or
    ((PublicationPhase = 2) and (Calls > 1) and
      (AProgress.Done = AProgress.Total))) then
  begin
    raise Marker;
  end;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(LChecks);
end;

procedure CheckIncremental;
var
  LBytes: TAudioBytes;
  LHasher, LOther: TSha256Hasher;
  LMemory: TMemoryStream;
  LSink: TStreamAudioSink;
  LHashSink: THashedAudioByteSink;
  LReject: TRejectingSink;
  LReference, LDigest: String;
  LPart, LAt, LTake, I: Integer;
  LRejected: Boolean;
begin
  SetLength(LBytes, 8193);
  for I := 0 to High(LBytes) do LBytes[I] := I mod 256;
  LReference := Sha256Bytes(LBytes);
  for LPart := 1 to 129 do
  begin
    LHasher := TSha256Hasher.Create;
    LOther := TSha256Hasher.Create;
    try
      LOther.Update(LBytes, 0, 55);
      LAt := 0;
      while LAt < Length(LBytes) do
      begin
        LTake := LPart;
        if Length(LBytes) - LAt < LTake then LTake := Length(LBytes) - LAt;
        LHasher.Update(LBytes, LAt, LTake);
        Inc(LAt, LTake);
      end;
      Check(LHasher.ByteCount = Length(LBytes), 'Incremental byte count');
      Check(LHasher.Finish = LReference, 'Incremental partition digest');
      Check(LHasher.Finish = LReference, 'Repeatable digest');
      Check(LOther.Finish =
        '463eb28e72f82e0a96c0a4cc53690c571281131f672aa229e0d45ae59b598b59',
        'Independent accumulator state');
      LRejected := False;
      try LHasher.Update(LBytes, 0, 0);
      except on E: EAudio do LRejected := True; end;
      Check(LRejected, 'Sealed accumulator accepted update');
    finally
      LOther.Free;
      LHasher.Free;
    end;
  end;
  LHasher := TSha256Hasher.Create;
  try
    LHasher.Update(LBytes, 0, 55);
    for I := 0 to 3 do
    begin
      LRejected := False;
      try
        case I of
          0: LHasher.Update(LBytes, -1, 1);
          1: LHasher.Update(LBytes, 0, -1);
          2: LHasher.Update(LBytes, Length(LBytes), 1);
          3: LHasher.Update(LBytes, High(SizeInt), High(SizeInt));
        end;
      except on E: EAudio do LRejected := True; end;
      Check(LRejected and (LHasher.ByteCount = 55), 'Rejected update mutated extent');
    end;
    LHasher.Update(LBytes, 55, Length(LBytes) - 55);
    Check(LHasher.Finish = LReference, 'Rejected update mutated digest');
  finally
    LHasher.Free;
  end;
  LMemory := TMemoryStream.Create;
  LSink := TStreamAudioSink.Create(LMemory);
  LHashSink := THashedAudioByteSink.Create(LSink);
  try
    LHashSink.WriteBytes(LBytes);
    LDigest := LHashSink.Finish;
    LMemory.Position := 0;
    Check((LHashSink.ByteCount = LMemory.Size) and
      (LDigest = Sha256Stream(LMemory, LMemory.Size)), 'Output digest differs from actual bytes');
    Check(LHashSink.Finish = LDigest, 'Repeatable output digest');
    LRejected := False;
    try LHashSink.WriteBytes(LBytes);
    except on E: EAudio do LRejected := True; end;
    Check(LRejected and (LMemory.Size = Length(LBytes)), 'Sealed sink emitted bytes');
  finally
    LHashSink.Free;
    LSink.Free;
    LMemory.Free;
  end;
  LReject := TRejectingSink.Create;
  try
    for I := 0 to 1 do
    begin
      LHashSink := THashedAudioByteSink.Create(LReject);
      try
        LReject.Fail := False;
        LReject.Reenter := nil;
        LReject.Emitted := 0;
        LHashSink.WriteBytes(LBytes);
        if I = 0 then LReject.Fail := True else LReject.Reenter := LHashSink;
        LRejected := False;
        try LHashSink.WriteBytes(LBytes);
        except on E: EAudio do LRejected := True; end;
        Check(LRejected and LHashSink.Failed and
          (LHashSink.ByteCount = Length(LBytes)) and
          (LReject.Emitted > LHashSink.ByteCount), 'Failed/partial block entered digest');
        LAt := LReject.Calls;
        LRejected := False;
        try LHashSink.WriteBytes(LBytes);
        except on E: EAudio do LRejected := True; end;
        Check(LRejected and (LReject.Calls = LAt), 'Failed sink emitted more bytes');
        LRejected := False;
        try LHashSink.Finish;
        except on E: EAudio do LRejected := True; end;
        Check(LRejected, 'Failed sink published digest');
      finally
        LHashSink.Free;
      end;
    end;
  finally
    LReject.Free;
  end;
end;

procedure Vector(const ASize: Integer; const AExpected: String);
var
  LBytes: TAudioBytes;
  LStream: TFragmentStream;
  LIndex: Integer;
  LObserver: TObserver;
begin
  SetLength(LBytes, ASize);
  for LIndex := 0 to ASize - 1 do
  begin
    LBytes[LIndex] := LIndex mod 256;
  end;
  LObserver := TObserver.Create;
  LStream := TFragmentStream.Create;
  try
    Check(Sha256Bytes(LBytes, LObserver.Progress) = AExpected, 'Bytes vector');
    Check(LObserver.Calls >= 2, 'Progress endpoints');
    if ASize > 0 then
    begin
      Check(WriteStreamBytes(LStream, LBytes, 0, ASize) = ASize, 'Stream preparation');
    end;
    LStream.Position := 0;
    Check(Sha256Stream(LStream, ASize) = AExpected, 'Fragmented stream vector');
    for LIndex := 0 to ASize - 1 do
    begin
      Check(LBytes[LIndex] = LIndex mod 256, 'Input mutation');
    end;
  finally
    LObserver.Free;
    LStream.Free;
  end;
end;
procedure Publication(const ASize: Integer; const AStreamMode, AForward,
  AFinal: Boolean);
var
  LData: TAudioBytes;
  LInput: TFragmentStream;
  LWork: TObserver;
  LValue: String;
  LReference: String;
  LExact: Boolean;
  I: Integer;
  function ForwardBytesHash: String;
  begin
    Result := Sha256Bytes(LData, LWork.Progress);
  end;
  function ForwardStreamHash: String;
  begin
    Result := Sha256Stream(LInput, ASize, LWork.Progress);
  end;
begin
  SetLength(LData, ASize);
  for I := 0 to ASize - 1 do LData[I] := I mod 256;
  LReference := Sha256Bytes(LData);
  LInput := TFragmentStream.Create;
  LWork := TObserver.Create;
  try
    if ASize > 0 then
      Check(WriteStreamBytes(LInput, LData, 0, ASize) = ASize, 'Publication source preparation');
    LInput.Position := 0;
    LWork.PublicationPhase := 1;
    if AFinal then LWork.PublicationPhase := 2;
    LWork.Marker := Exception.Create('Original hash publication marker');
    LValue := 'retained digest sentinel';
    LExact := False;
    try
      try
        if AForward and AStreamMode then LValue := ForwardStreamHash
        else if AForward then LValue := ForwardBytesHash
        else if AStreamMode then LValue := Sha256Stream(LInput, ASize, LWork.Progress)
        else LValue := Sha256Bytes(LData, LWork.Progress);
      except
        on LException: Exception do
        begin
          if LException <> LWork.Marker then raise;
          LWork.Marker := nil;
          LExact := True;
          Inc(LPublicationAborts);
        end;
      end;
      Check(LExact, 'Original publication callback exception changed');
      if LValue <> 'retained digest sentinel' then
      begin
        Inc(LPublicationFailures);
        WriteLn('Publication failure: size=', ASize, ' stream=', AStreamMode,
          ' forwarded=', AForward, ' final=', AFinal, ' original=', LExact,
          ' result=', LValue);
      end;
    finally
      LWork.Marker.Free;
      LWork.Marker := nil;
    end;
    if AStreamMode then
    begin
      if AFinal then Check(LInput.Position = ASize, 'Final abort rewound stream')
      else Check(LInput.Position = 8192, 'Interior consumed stream position changed');
    end;
    for I := 0 to ASize - 1 do Check(LData[I] = I mod 256, 'Publication mutated input');
    LWork.PublicationPhase := 0;
    LInput.Position := 0; { Caller deliberately rewinds; the hash API never does. }
    if AStreamMode then
      Check(ForwardStreamHash = LReference, 'Stream publication retry digest differs')
    else
      Check(ForwardBytesHash = LReference, 'Byte publication retry digest differs');
  finally
    LWork.Free;
    LInput.Free;
  end;
end;

procedure CheckPublication;
const
  CSizes: array[0..3] of Integer = (0, 65, 8193, 32769);
var
  LSize: Integer;
  LStreamMode: Boolean;
  LForward: Boolean;
begin
  for LSize in CSizes do
    for LStreamMode := False to True do
      for LForward := False to True do
      begin
        Publication(LSize, LStreamMode, LForward, True);
        if LSize > 8192 then Publication(LSize, LStreamMode, LForward, False);
      end;
  Check(LPublicationFailures = 0, 'Hash callback published a caller digest before success');
end;

var
  LBytes: TAudioBytes;
  LStream: TFragmentStream;
  LObserver: TObserver;
  LRejected: Boolean;
  {$ifdef pas2js}
  LUnsafeCount: Int64;
  {$endif}
begin
  CheckIncremental;
  CheckPublication;
  Vector(0, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  Vector(55, '463eb28e72f82e0a96c0a4cc53690c571281131f672aa229e0d45ae59b598b59');
  Vector(56, 'da2ae4d6b36748f2a318f23e7ab1dfdf45acdc9d049bd80e59de82a60895f562');
  Vector(63, '29af2686fd53374a36b0846694cc342177e428d1647515f078784d69cdb9e488');
  Vector(64, 'fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108');
  Vector(65, '4bfd2c8b6f1eec7a2afeb48b934ee4b2694182027e6d0fc075074f2fabb31781');
  Vector(8193, 'db8e82fcacaeceb336ecb8be90fad31da698c72a6c10fd1ea68a2e5874b78b17');
  SetLength(LBytes, 3);
  LBytes[0] := 97;
  LBytes[1] := 98;
  LBytes[2] := 99;
  Check(Sha256Bytes(LBytes) = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'abc');
  LStream := TFragmentStream.Create;
  LObserver := TObserver.Create;
  try
    LRejected := False;
    try
      Sha256Stream(LStream, 1);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Early EOF');
    LStream.FailRead := True;
    LRejected := False;
    try
      Sha256Stream(LStream, 1);
    except
      on E: Exception do
      begin
        LRejected := E.Message = 'Read marker';
      end;
    end;
    Check(LRejected, 'Stream error propagation');
    LStream.FailRead := False;
    LObserver.Abort := True;
    LRejected := False;
    try
      Sha256Stream(LStream, 1, LObserver.Progress);
    except
      on E: Exception do
      begin
        LRejected := E.Message = 'Abort marker';
      end;
    end;
    Check(LRejected and (LStream.Position = 0), 'Callback abort');
    LRejected := False;
    try
      Sha256Stream(LStream, 4294967297, LObserver.Progress);
    except
      on E: Exception do
      begin
        LRejected := E.Message = 'Abort marker';
      end;
    end;
    Check(LRejected and (LObserver.LastTotal = 4294967297), 'Large progress count');
    {$ifdef pas2js}
    LRejected := False;
    LUnsafeCount := 9007199254740991;
    Inc(LUnsafeCount);
    try
      Sha256Stream(LStream, LUnsafeCount);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unsafe byte count');
    {$endif}
  finally
    LObserver.Free;
    LStream.Free;
  end;
  WriteLn('Portable SHA256: ', LChecks, ' checks passed; ', LPublicationAborts,
    ' original publication abort/retries');
end.
