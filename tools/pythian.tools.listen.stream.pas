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
unit pythian.tools.listen.stream;

{$mode delphi}
{$H+}

interface

uses
  Classes;

{ A successful dispatch transfers the stream and socket to a bounded sender.
  On failure the caller still owns and must close both. The method returns
  False after sending a complete HEAD or error response. }
function DispatchListeningMedia(const ASocket: Integer;
  const AStream: TStream; const AMethod, ARange, AIfRange,
  AContentHash: String; const AVerifyPath: String = '';
  const AExpectedBytes: Int64 = 0; const AVerifyHash: String = ''): Boolean;

implementation

uses
  SysUtils,
  Sockets,
  {$IFDEF MSWINDOWS}WinSock2,{$ELSE}BaseUnix,{$ENDIF}
  pythian.tools.net.transport,
  pythian.tools.annotations.sourceguard;

const
  CBlockBytes = 65536;
  CMaximumSenders = 4;
  CBlockSendDeadlineMs = 15000;
  {$IFDEF MEDIA_QA_DEADLINE}
  CResponseDeadlineMs = 1000;
  {$ELSE}
  CResponseDeadlineMs = 3600000;
  {$ENDIF}

type
  TMediaSender = class(TThread)
  private
    FSocket: Integer;
    FStream: TStream;
    FHeader: String;
    FStart: Int64;
    FLength: Int64;
    FMethod: String;
    FVerifyPath: String;
    FHash: String;
    FExpectedBytes: Int64;
  protected
    procedure Execute; override;
  public
    constructor Create(const ASocket: Integer; const AStream: TStream;
      const AHeader: String; const AStart, ALength: Int64;
      const AMethod, AVerifyPath, AHash: String;
      const AExpectedBytes: Int64);
  end;

var
  GActiveSenders: LongInt = 0;

function SendBytes(const ASocket: Integer; const ABuffer;
  const ACount: Integer; const ADeadline: QWord = 0): Boolean;
var
  LSent: Integer;
  LOffset: Integer;
  LStart: QWord;
  LPointer: PByte;
  LError: Integer;
begin
  Result := False;
  LOffset := 0;
  LStart := GetTickCount64;
  LPointer := @ABuffer;
  while LOffset < ACount do
  begin
    if (GetTickCount64 - LStart >= CBlockSendDeadlineMs) or
      ((ADeadline <> 0) and (GetTickCount64 >= ADeadline)) then
      Exit;
    LSent := TransportSend(ASocket, LPointer + LOffset, ACount - LOffset);
    if LSent = 0 then
      Exit;
    if LSent < 0 then
    begin
      {$IFDEF MSWINDOWS}
      LError := WSAGetLastError;
      if (LError <> WSAEWOULDBLOCK) and (LError <> WSAEINTR) then
        Exit;
      {$ELSE}
      LError := fpGetErrNo;
      if (LError <> ESysEAGAIN) and (LError <> ESysEWOULDBLOCK) and
        (LError <> ESysEINTR) then
        Exit;
      {$ENDIF}
      Sleep(10);
      Continue;
    end;
    Inc(LOffset, LSent);
  end;
  Result := True;
end;

function SendText(const ASocket: Integer; const AText: String;
  const ADeadline: QWord = 0): Boolean;
begin
  Result := (AText = '') or
    SendBytes(ASocket, AText[1], Length(AText), ADeadline);
end;

function Decimal(const AValue: String; out ANumber: Int64): Boolean;
var
  LIndex: Integer;
begin
  Result := (AValue <> '') and (Length(AValue) <= 19);
  if not Result then
    Exit;
  for LIndex := 1 to Length(AValue) do
    if not (AValue[LIndex] in ['0'..'9']) then
      Exit(False);
  Result := TryStrToInt64(AValue, ANumber) and (ANumber >= 0);
end;

function RangeStatus(const ARange: String; const ASize: Int64;
  out AStart, AEnd: Int64): Integer;
var
  LDash: Integer;
  LLeft: String;
  LRight: String;
  LSuffix: Int64;
begin
  AStart := 0;
  AEnd := ASize - 1;
  if ARange = '' then
    Exit(200);
  Result := 400;
  if (Copy(LowerCase(ARange), 1, 6) <> 'bytes=') or
    (Pos(',', ARange) <> 0) then
    Exit;
  LDash := Pos('-', Copy(ARange, 7, MaxInt));
  if LDash = 0 then
    Exit;
  Inc(LDash, 6);
  LLeft := Copy(ARange, 7, LDash - 7);
  LRight := Copy(ARange, LDash + 1, MaxInt);
  if (LLeft = '') and (LRight = '') then
    Exit;
  if LLeft = '' then
  begin
    if not Decimal(LRight, LSuffix) then
      Exit;
    if LSuffix = 0 then
      Exit(416);
    if LSuffix < ASize then
      AStart := ASize - LSuffix;
    Exit(206);
  end;
  if not Decimal(LLeft, AStart) then
    Exit;
  if AStart >= ASize then
    Exit(416);
  if LRight <> '' then
  begin
    if not Decimal(LRight, AEnd) then
      Exit;
    if AEnd < AStart then
      Exit(416);
    if AEnd >= ASize then
      AEnd := ASize - 1;
  end;
  Result := 206;
end;

function Header(const AStatus: Integer; const AHash: String;
  const ASize, AStart, AEnd: Int64): String;
var
  LReason: String;
  LLength: Int64;
begin
  case AStatus of
    200: LReason := 'OK';
    206: LReason := 'Partial Content';
    400: LReason := 'Bad Request';
    416: LReason := 'Range Not Satisfiable';
    503: LReason := 'Service Unavailable';
  else
    LReason := 'Internal Server Error';
  end;
  LLength := 0;
  if AStatus in [200, 206] then
    LLength := AEnd - AStart + 1;
  Result := 'HTTP/1.1 ' + IntToStr(AStatus) + ' ' + LReason + #13#10 +
    'Content-Type: audio/wav'#13#10 +
    'Content-Length: ' + IntToStr(LLength) + #13#10 +
    'Accept-Ranges: bytes'#13#10 +
    'ETag: "' + AHash + '"'#13#10 +
    'Connection: close'#13#10 +
    'Cache-Control: no-store'#13#10 +
    'X-Content-Type-Options: nosniff'#13#10 +
    'Cross-Origin-Resource-Policy: same-origin'#13#10 +
    'Referrer-Policy: no-referrer'#13#10;
  if AStatus = 206 then
    Result := Result + 'Content-Range: bytes ' + IntToStr(AStart) +
      '-' + IntToStr(AEnd) + '/' + IntToStr(ASize) + #13#10
  else if AStatus = 416 then
    Result := Result + 'Content-Range: bytes */' + IntToStr(ASize) + #13#10;
  Result := Result + #13#10;
end;

constructor TMediaSender.Create(const ASocket: Integer;
  const AStream: TStream; const AHeader: String;
  const AStart, ALength: Int64;
  const AMethod, AVerifyPath, AHash: String;
  const AExpectedBytes: Int64);
begin
  inherited Create(True);
  FSocket := ASocket;
  FStream := AStream;
  FHeader := AHeader;
  FStart := AStart;
  FLength := ALength;
  FMethod := AMethod;
  FVerifyPath := AVerifyPath;
  FHash := AHash;
  FExpectedBytes := AExpectedBytes;
end;

procedure TMediaSender.Execute;
var
  LBuffer: array[0..CBlockBytes - 1] of Byte;
  LRemaining: Int64;
  LWant: Integer;
  LRead: Integer;
  LDeadline: QWord;
begin
  try
    try
      if FVerifyPath <> '' then
      begin
        try
          VerifyGuardedSource(FVerifyPath, FHash, FExpectedBytes);
          if FStream.Size <> FExpectedBytes then
            raise Exception.Create('Listening asset changed after verification');
        except
          on E: Exception do
          begin
            WriteLn(StdErr, 'Listening media verification failed: ', E.Message);
            SendText(FSocket, 'HTTP/1.1 422 Unprocessable Content'#13#10 +
              'Content-Type: text/plain; charset=utf-8'#13#10 +
              'Content-Length: 37'#13#10 +
              'Connection: close'#13#10 +
              'Cache-Control: no-store'#13#10 +
              'X-Content-Type-Options: nosniff'#13#10 +
              'Cross-Origin-Resource-Policy: same-origin'#13#10#13#10 +
              'Listening asset verification failed.'#10);
            Exit;
          end;
        end;
      end;
      LDeadline := GetTickCount64 + CResponseDeadlineMs;
      if not SendText(FSocket, FHeader, LDeadline) then
        Exit;
      if FMethod = 'HEAD' then
        Exit;
      FStream.Position := FStart;
      LRemaining := FLength;
      while LRemaining > 0 do
      begin
        LWant := CBlockBytes;
        if LRemaining < LWant then
          LWant := Integer(LRemaining);
        LRead := FStream.Read(LBuffer[0], LWant);
        if (LRead <> LWant) or
          not SendBytes(FSocket, LBuffer[0], LRead, LDeadline) then
          Exit;
        Dec(LRemaining, LRead);
      end;
    except
      on E: Exception do
        WriteLn(StdErr, 'Listening media sender failed: ', E.Message);
    end;
  finally
    FStream.Free;
    TransportClose(FSocket);
    InterlockedDecrement(GActiveSenders);
  end;
end;

function DispatchListeningMedia(const ASocket: Integer;
  const AStream: TStream; const AMethod, ARange, AIfRange,
  AContentHash: String; const AVerifyPath: String;
  const AExpectedBytes: Int64; const AVerifyHash: String): Boolean;
var
  LStatus: Integer;
  LStart: Int64;
  LEnd: Int64;
  LSize: Int64;
  LHeader: String;
  LVerifyHash: String;
  LSender: TMediaSender;
begin
  Result := False;
  LSize := AStream.Size;
  if LSize <= 0 then
    raise Exception.Create('Empty listening asset');
  LStatus := 200;
  LStart := 0;
  LEnd := LSize - 1;
  if (ARange <> '') and
    ((AIfRange = '') or (AIfRange = '"' + AContentHash + '"')) then
    LStatus := RangeStatus(ARange, LSize, LStart, LEnd);
  if not (LStatus in [200, 206]) then
  begin
    SendText(ASocket, Header(LStatus, AContentHash, LSize, LStart, LEnd));
    Exit;
  end;
  if (AMethod = 'HEAD') and (AVerifyPath = '') then
  begin
    SendText(ASocket, Header(LStatus, AContentHash, LSize, LStart, LEnd));
    Exit;
  end;
  if InterlockedIncrement(GActiveSenders) > CMaximumSenders then
  begin
    InterlockedDecrement(GActiveSenders);
    SendText(ASocket, Header(503, AContentHash, LSize, 0, 0));
    Exit;
  end;
  LHeader := Header(LStatus, AContentHash, LSize, LStart, LEnd);
  LVerifyHash := AVerifyHash;
  if LVerifyHash = '' then
  begin
    LVerifyHash := AContentHash;
  end;
  LSender := nil;
  try
    LSender := TMediaSender.Create(ASocket, AStream, LHeader,
      LStart, LEnd - LStart + 1, AMethod, AVerifyPath,
      LVerifyHash, AExpectedBytes);
    LSender.FreeOnTerminate := True;
    LSender.Start;
    Result := True;
  except
    if LSender <> nil then
    begin
      LSender.FreeOnTerminate := False;
      LSender.Free;
    end;
    InterlockedDecrement(GActiveSenders);
    SendText(ASocket, Header(503, AContentHash, LSize, 0, 0));
  end;
end;

finalization
  { A finite-request service must not finalize the shared source guard while a
    handed-off verification or sender is still using it. }
  while InterlockedCompareExchange(GActiveSenders, 0, 0) <> 0 do
    Sleep(10);

end.
