(*
MIT License

Copyright (c) 2021 mr-highball
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
unit pythian.tools.annotations.http;

{$mode delphi}
{$H+}

interface

{ Fixed-route catalog host. The bounded socket/header pattern derives from the
  pinned WFC wfc_serve_http reference. Optional static assets use exact names. }
procedure RunCatalogHttp(const AInboxRoot, ACatalogRoot,
  ABindAddress: String; const APort, AMaximumRequests: Integer;
  const AStaticRoot: String = ''; const AOpenLan: Boolean = False);

implementation

uses
  Classes,
  SysUtils,
  Math,
  Sockets,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.tools.net.transport,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.export,
  pythian.tools.annotations.media,
  pythian.tools.annotations.proposal,
  pythian.tools.annotations.queue,
  pythian.tools.annotations.replay,
  pythian.tools.annotations.review,
  pythian.tools.annotations.sourceguard,
  pythian.tools.listen.catalog,
  pythian.tools.listen.stream,
  pythian.tools.studio.projects,
  pythian.tools.studio.effects,
  pythian.tools.studio.capture,
  pythian.tools.studio.pitch,
  pythian.tools.studio.reviews,
  pythian.tools.studio.&library,
  pythian.tools.studio.jobs,
  pythian.tools.studio.supervisor
  {$IFDEF MSWINDOWS}, Windows, WinSock2{$ELSE}, BaseUnix{$ENDIF};

{$IFDEF MSWINDOWS}
function DecodeKeyFileDacl(ASddl: PWideChar; ARevision: DWORD;
  out ADescriptor: Pointer; ASize: PDWORD): BOOL; stdcall;
  external 'advapi32.dll' name 'ConvertStringSecurityDescriptorToSecurityDescriptorW';

function ApplyKeyFileDacl(APath: PWideChar; AInformation: DWORD;
  ADescriptor: Pointer): BOOL; stdcall;
  external 'advapi32.dll' name 'SetFileSecurityW';
{$ENDIF}

const
  CMaximumHeaderBytes = 262144;
  CMaximumBodyBytes = 32768;
  CMaximumReviewedImportBytes = 67108864;
  CMaximumTargetBytes = 2048;
  CMaximumJsonResponseBytes = 8388608;
  CMaximumReviewedExportBytes = 67108864;
  CMaximumStaticBytes = 8388608;
  CReceiveDeadlineMs = 5000;
  CReviewedImportDeadlineMs = 60000;
  CSendDeadlineMs = 15000;
  CSocketBlockBytes = 65536;
  CListeningLists: array[0..1] of String = ('items', 'completed');

type
  TCatalogHttpRequest = record
    Method: String;
    Path: String;
    Query: String;
    Host: String;
    Origin: String;
    ContentType: String;
    Token: String;
    Cookie: String;
    Range: String;
    IfRange: String;
    Body: String;
  end;

  TListeningReviewWorker = class(TThread)
  private
    FSocket: Integer;
    FCatalogRoot: String;
    FBody: String;
  protected
    procedure Execute; override;
  public
    constructor Create(const ASocket: Integer;
      const ACatalogRoot, ABody: String);
  end;

var
  GActiveReviewWorkers: LongInt = 0;
  GStudioSupervisor: TStudioJobSupervisor = nil;
  GPhoneCaBytes: String = '';
  GPhoneCaSha256: String = '';
  GPhoneHttpsOrigin: String = '';

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function StatusReason(const AStatus: Integer): String;
begin
  case AStatus of
    200: Result := 'OK';
    206: Result := 'Partial Content';
    400: Result := 'Bad Request';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    408: Result := 'Request Timeout';
    409: Result := 'Conflict';
    416: Result := 'Range Not Satisfiable';
    413: Result := 'Content Too Large';
    422: Result := 'Unprocessable Content';
    431: Result := 'Request Header Fields Too Large';
    503: Result := 'Service Unavailable';
  else
    Result := 'Internal Server Error';
  end;
end;

procedure SetClientTimeouts(const ASocket: Integer);
{$IFDEF MSWINDOWS}
var
  LTimeout: DWORD;
begin
  LTimeout := 1000;
{$ELSE}
var
  LTimeout: TTimeVal;
begin
  LTimeout.tv_sec := 1;
  LTimeout.tv_usec := 0;
{$ENDIF}
  Need((fpSetSockOpt(ASocket, SOL_SOCKET, SO_RCVTIMEO,
    @LTimeout, SizeOf(LTimeout)) = 0) and
    (fpSetSockOpt(ASocket, SOL_SOCKET, SO_SNDTIMEO,
    @LTimeout, SizeOf(LTimeout)) = 0),
    'Could not set client socket timeouts');
end;

function SendBytes(const ASocket: Integer; const ABuffer;
  const ACount: Integer): Boolean;
var
  LSent: Integer;
  LOffset: Integer;
  LStart: QWord;
  LPointer: PByte;
begin
  Result := False;
  LOffset := 0;
  LStart := GetTickCount64;
  LPointer := @ABuffer;
  while LOffset < ACount do
  begin
    if GetTickCount64 - LStart >= CSendDeadlineMs then
    begin
      Exit;
    end;
    LSent := TransportSend(ASocket, LPointer + LOffset, ACount - LOffset);
    if LSent <= 0 then
    begin
      Exit;
    end;
    Inc(LOffset, LSent);
  end;
  Result := True;
end;

function SendText(const ASocket: Integer; const AText: String): Boolean;
begin
  Result := (AText = '') or SendBytes(ASocket, AText[1], Length(AText));
end;

procedure SendResponse(const ASocket, AStatus: Integer;
  const AContentType, ABody: String;
  const AExtraHeaders: String = '');
var
  LHeader: String;
begin
  LHeader := 'HTTP/1.1 ' + IntToStr(AStatus) + ' ' +
    StatusReason(AStatus) + #13#10 +
    'Content-Type: ' + AContentType + #13#10 +
    'Content-Length: ' + IntToStr(Length(ABody)) + #13#10 +
    AExtraHeaders +
    'Connection: close' + #13#10 +
    'Cache-Control: no-store' + #13#10 +
    'X-Content-Type-Options: nosniff' + #13#10 +
    'Cross-Origin-Resource-Policy: same-origin' + #13#10 +
    'Referrer-Policy: no-referrer' + #13#10#13#10;
  if SendText(ASocket, LHeader) and (ABody <> '') then
  begin
    SendText(ASocket, ABody);
  end;
end;

procedure SendStreamResponse(const ASocket: Integer; const AStream: TStream;
  const AContentType: String);
var
  LHeader: String;
  LBuffer: array[0..CSocketBlockBytes - 1] of Byte;
  LRemaining: Int64;
  LWant: Integer;
  LRead: Integer;
begin
  Need((AStream.Size >= 0) and (AStream.Size <= 16777260),
    'Audio response exceeds bound');
  LHeader := 'HTTP/1.1 200 OK'#13#10 +
    'Content-Type: ' + AContentType + #13#10 +
    'Content-Length: ' + IntToStr(AStream.Size) + #13#10 +
    'Connection: close'#13#10 +
    'Cache-Control: no-store'#13#10 +
    'X-Content-Type-Options: nosniff'#13#10 +
    'Cross-Origin-Resource-Policy: same-origin'#13#10 +
    'Referrer-Policy: no-referrer'#13#10#13#10;
  Need(SendText(ASocket, LHeader), 'Client closed before audio response');
  AStream.Position := 0;
  LRemaining := AStream.Size;
  while LRemaining > 0 do
  begin
    LWant := CSocketBlockBytes;
    if LRemaining < LWant then
    begin
      LWant := Integer(LRemaining);
    end;
    LRead := AStream.Read(LBuffer[0], LWant);
    Need(LRead = LWant, 'Short prepared audio response');
    Need(SendBytes(ASocket, LBuffer[0], LRead),
      'Client closed during audio response');
    Dec(LRemaining, LRead);
  end;
end;

function HeaderValue(var ATarget: String; const AValue: String): Boolean;
begin
  Result := ATarget = '';
  if Result then
  begin
    ATarget := AValue;
  end;
end;

function ValidHeaderName(const AName: String): Boolean;
var
  LIndex: Integer;
begin
  Result := AName <> '';
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 1 to Length(AName) do
  begin
    if not (AName[LIndex] in ['A'..'Z', 'a'..'z', '0'..'9',
      '!', '#', '$', '%', '&', #39, '*', '+', '-', '.', '^', '_',
      '`', '|', '~']) then
    begin
      Exit(False);
    end;
  end;
end;

function ParseHeaders(const AHeaderText, ABindAddress: String;
  const APort, ASocket: Integer;
  out ARequest: TCatalogHttpRequest; out AContentLength: Integer;
  out AFailure: String): Integer;
var
  LStart: Integer;
  LBreak: Integer;
  LLine: String;
  LFirstSpace: Integer;
  LSecondSpace: Integer;
  LColon: Integer;
  LName: String;
  LValue: String;
  LTarget: String;
  LQuestion: Integer;
  LContentLengthText: String;
  LIndex: Integer;
  LRequestStart: Integer;
  LRangeSeen: Boolean;
  LCookieSeen: Boolean;
  LIfRangeSeen: Boolean;
begin
  ARequest := Default(TCatalogHttpRequest);
  AContentLength := 0;
  Result := 400;
  AFailure := 'header contains a control byte or malformed line ending';
  for LIndex := 1 to Length(AHeaderText) do
  begin
    if AHeaderText[LIndex] = #13 then
    begin
      if LIndex = Length(AHeaderText) then
      begin
        Exit;
      end;
      if AHeaderText[LIndex + 1] <> #10 then
      begin
        Exit;
      end;
    end
    else if AHeaderText[LIndex] = #10 then
    begin
      if LIndex = 1 then
      begin
        Exit;
      end;
      if AHeaderText[LIndex - 1] <> #13 then
      begin
        Exit;
      end;
    end
    else if not (AHeaderText[LIndex] in [#9, #32..#126, #128..#255]) then
    begin
      Exit;
    end;
  end;
  AFailure := 'request line terminator missing';
  LRequestStart := 1;
  while Copy(AHeaderText, LRequestStart, 2) = #13#10 do
  begin
    Inc(LRequestStart, 2);
    if LRequestStart > 9 then
    begin
      AFailure := 'too many leading empty request lines';
      Exit;
    end;
  end;
  LBreak := Pos(#13#10, Copy(AHeaderText, LRequestStart, MaxInt));
  if LBreak < 1 then
  begin
    Exit;
  end;
  LLine := Copy(AHeaderText, LRequestStart, LBreak - 1);
  AFailure := 'request line contains a control or non-ASCII byte';
  for LIndex := 1 to Length(LLine) do
  begin
    if not (LLine[LIndex] in [#32..#126]) then
    begin
      AFailure := 'request line byte ' + IntToStr(LIndex) +
        ' is 0x' + IntToHex(Ord(LLine[LIndex]), 2);
      Exit;
    end;
  end;
  LFirstSpace := Pos(' ', LLine);
  AFailure := 'request method separator missing (line bytes=' +
    IntToStr(Length(LLine)) + ')';
  if LFirstSpace < 2 then
  begin
    Exit;
  end;
  LSecondSpace := Pos(' ', Copy(LLine, LFirstSpace + 1, MaxInt));
  AFailure := 'request target separator missing (line bytes=' +
    IntToStr(Length(LLine)) + ')';
  if LSecondSpace < 2 then
  begin
    Exit;
  end;
  Inc(LSecondSpace, LFirstSpace);
  ARequest.Method := Copy(LLine, 1, LFirstSpace - 1);
  LTarget := Copy(LLine, LFirstSpace + 1,
    LSecondSpace - LFirstSpace - 1);
  if Copy(LLine, LSecondSpace + 1, MaxInt) <> 'HTTP/1.1' then
  begin
    AFailure := 'unsupported HTTP request version';
    Exit;
  end;
  if (Length(LTarget) < 1) or (Length(LTarget) > CMaximumTargetBytes) or
    (LTarget[1] <> '/') then
  begin
    AFailure := 'invalid request target form or length';
    Exit;
  end;
  if Pos('%', LTarget) > 0 then
  begin
    AFailure := 'encoded request target is unsupported';
    Exit;
  end;
  if (Pos('\', LTarget) > 0) or (Pos('#', LTarget) > 0) then
  begin
    AFailure := 'invalid request target character';
    Exit;
  end;
  LQuestion := Pos('?', LTarget);
  if LQuestion > 0 then
  begin
    ARequest.Path := Copy(LTarget, 1, LQuestion - 1);
    ARequest.Query := Copy(LTarget, LQuestion + 1, MaxInt);
  end
  else
  begin
    ARequest.Path := LTarget;
  end;
  LStart := LRequestStart + LBreak + 1;
  LContentLengthText := '';
  LRangeSeen := False;
  LCookieSeen := False;
  LIfRangeSeen := False;
  AFailure := 'malformed or duplicate request header';
  while LStart <= Length(AHeaderText) do
  begin
    LBreak := Pos(#13#10, Copy(AHeaderText, LStart, MaxInt));
    if LBreak = 0 then
    begin
      LLine := Copy(AHeaderText, LStart, MaxInt);
      LStart := Length(AHeaderText) + 1;
    end
    else
    begin
      LLine := Copy(AHeaderText, LStart, LBreak - 1);
      Inc(LStart, LBreak + 1);
    end;
    if LLine = '' then
    begin
      Continue;
    end;
    LColon := Pos(':', LLine);
    if LColon < 2 then
    begin
      Exit;
    end;
    if not ValidHeaderName(Copy(LLine, 1, LColon - 1)) then
    begin
      AFailure := 'invalid request header name';
      Exit;
    end;
    LName := LowerCase(Copy(LLine, 1, LColon - 1));
    LValue := Trim(Copy(LLine, LColon + 1, MaxInt));
    if LName = 'host' then
    begin
      if not HeaderValue(ARequest.Host, LValue) then
      begin
        Exit;
      end;
    end
    else if LName = 'origin' then
    begin
      if not HeaderValue(ARequest.Origin, LValue) then
      begin
        Exit;
      end;
    end
    else if LName = 'content-type' then
    begin
      if not HeaderValue(ARequest.ContentType, LowerCase(LValue)) then
      begin
        Exit;
      end;
    end
    else if LName = 'content-length' then
    begin
      if not HeaderValue(LContentLengthText, LValue) then
      begin
        Exit;
      end;
    end
    else if LName = 'x-pythian-token' then
    begin
      if not HeaderValue(ARequest.Token, LValue) then
      begin
        Exit;
      end;
    end
    else if LName = 'cookie' then
    begin
      if LCookieSeen then Exit;
      LCookieSeen := True;
      ARequest.Cookie := LValue;
    end
    else if LName = 'range' then
    begin
      if LRangeSeen then Exit;
      LRangeSeen := True;
      ARequest.Range := LValue;
    end
    else if LName = 'if-range' then
    begin
      if LIfRangeSeen then Exit;
      LIfRangeSeen := True;
      ARequest.IfRange := LValue;
    end
    else if (LName = 'transfer-encoding') or (LName = 'expect') then
    begin
      Exit;
    end;
  end;
  if (ARequest.Host <> ABindAddress + ':' + IntToStr(APort)) and
    ((ABindAddress <> '127.0.0.1') or
    (ARequest.Host <> 'localhost:' + IntToStr(APort))) then
  begin
    Result := 403;
    AFailure := 'host does not match bound address';
    Exit;
  end;
  if not TransportOriginMatches(ASocket, ARequest.Host, ARequest.Origin) then
  begin
    Result := 403;
    AFailure := 'origin does not match host';
    Exit;
  end;
  if (ARequest.Method <> 'GET') and (ARequest.Method <> 'POST') and
    not ((ARequest.Method = 'HEAD') and
      (ARequest.Path = '/api/listen-audio')) then
  begin
    Result := 405;
    AFailure := 'unsupported request method';
    Exit;
  end;
  if ARequest.Method = 'POST' then
  begin
    if (LContentLengthText = '') or
      not TryStrToInt(LContentLengthText, AContentLength) or
      (AContentLength < 1) or
      ((ARequest.Path = '/api/import-reviewed') and
        (AContentLength > CMaximumReviewedImportBytes)) or
      ((ARequest.Path <> '/api/import-reviewed') and
        (AContentLength > CMaximumBodyBytes)) then
    begin
      Result := 413;
      AFailure := 'POST content length is missing or exceeds bound';
      Exit;
    end;
    if (ARequest.ContentType <> 'application/json') and
      (ARequest.ContentType <> 'application/json; charset=utf-8') then
    begin
      AFailure := 'POST content type must be application/json';
      Exit;
    end;
  end
  else if LContentLengthText <> '' then
  begin
    if not TryStrToInt(LContentLengthText, AContentLength) or
      (AContentLength <> 0) then
    begin
      AFailure := 'GET/HEAD content length must be zero';
      Exit;
    end;
  end;
  Result := 200;
  AFailure := '';
end;

function ReadRequest(const ASocket, APort: Integer;
  const ABindAddress, AToken: String;
  out ARequest: TCatalogHttpRequest; out AFailure: String): Integer;
var
  LRaw: String;
  LHeader: String;
  LBuffer: array[0..1023] of Char;
  LReceived: Integer;
  LSeparator: Integer;
  LRequestStart: Integer;
  LContentLength: Integer;
  LBodyStart: Integer;
  LBodyBytes: Integer;
  LDeadline: Integer;
  LStart: QWord;
begin
  LRaw := '';
  LSeparator := 0;
  ARequest := Default(TCatalogHttpRequest);
  AFailure := 'request header timed out';
  LStart := GetTickCount64;
  repeat
    if GetTickCount64 - LStart >= CReceiveDeadlineMs then
    begin
      Exit(408);
    end;
    LReceived := TransportRecv(ASocket, @LBuffer[0], SizeOf(LBuffer));
    if LReceived < 0 then
    begin
      Continue;
    end;
    if LReceived = 0 then
    begin
      AFailure := 'connection closed before request header';
      Exit(400);
    end;
    if LReceived > CMaximumHeaderBytes +
      CMaximumReviewedImportBytes - Length(LRaw) then
    begin
      AFailure := 'request exceeds size bound';
      Exit(413);
    end;
    SetLength(LRaw, Length(LRaw) + LReceived);
    Move(LBuffer[0], LRaw[Length(LRaw) - LReceived + 1], LReceived);
    LRequestStart := 1;
    while Copy(LRaw, LRequestStart, 2) = #13#10 do
    begin
      Inc(LRequestStart, 2);
      if LRequestStart > 9 then
      begin
        AFailure := 'too many leading empty request lines';
        Exit(400);
      end;
    end;
    LSeparator := Pos(#13#10#13#10,
      Copy(LRaw, LRequestStart, MaxInt));
    if LSeparator > 0 then
      Inc(LSeparator, LRequestStart - 1);
    if (LSeparator = 0) and (Length(LRaw) > CMaximumHeaderBytes) then
    begin
      AFailure := 'request header exceeds size bound (bytes=' +
        IntToStr(Length(LRaw)) + ')';
      Exit(431);
    end;
  until LSeparator > 0;
  if LSeparator - 1 > CMaximumHeaderBytes then
  begin
    AFailure := 'request header exceeds size bound (bytes=' +
      IntToStr(LSeparator - 1) + ')';
    Exit(431);
  end;
  LHeader := Copy(LRaw, 1, LSeparator - 1);
  Result := ParseHeaders(LHeader, ABindAddress, APort, ASocket,
    ARequest, LContentLength, AFailure);
  if Result <> 200 then
  begin
    Exit;
  end;
  if (ARequest.Path = '/api/import-reviewed') and
    (ARequest.Token <> AToken) then
  begin
    AFailure := 'reviewed import session token is invalid';
    Exit(403);
  end;
  LBodyStart := LSeparator + 4;
  LBodyBytes := Min(Length(LRaw) - LBodyStart + 1, LContentLength);
  SetLength(ARequest.Body, LContentLength);
  if LBodyBytes > 0 then
  begin
    Move(LRaw[LBodyStart], ARequest.Body[1], LBodyBytes);
  end;
  LDeadline := CReceiveDeadlineMs;
  if ARequest.Path = '/api/import-reviewed' then
  begin
    LDeadline := CReviewedImportDeadlineMs;
  end;
  while LBodyBytes < LContentLength do
  begin
    if GetTickCount64 - LStart >= LDeadline then
    begin
      AFailure := 'request body timed out';
      Exit(408);
    end;
    LReceived := TransportRecv(ASocket, @LBuffer[0],
      Min(SizeOf(LBuffer), LContentLength - LBodyBytes));
    if LReceived < 0 then
    begin
      Continue;
    end;
    if LReceived = 0 then
    begin
      AFailure := 'connection closed before complete request body';
      Exit(400);
    end;
    Move(LBuffer[0], ARequest.Body[LBodyBytes + 1], LReceived);
    Inc(LBodyBytes, LReceived);
  end;
  AFailure := '';
end;

function QueryValue(const AQuery, AName: String): String;
var
  LStart: Integer;
  LEnd: Integer;
  LPair: String;
  LEqual: Integer;
  LIndex: Integer;
begin
  Result := '';
  Need(Length(AQuery) <= CMaximumTargetBytes, 'Query exceeds bound');
  for LIndex := 1 to Length(AQuery) do
  begin
    Need(AQuery[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '=', '&', '-', '_', '.'],
      'Invalid query character');
  end;
  LStart := 1;
  while LStart <= Length(AQuery) do
  begin
    LEnd := Pos('&', Copy(AQuery, LStart, MaxInt));
    if LEnd = 0 then
    begin
      LEnd := Length(AQuery) + 1;
    end
    else
    begin
      Inc(LEnd, LStart - 1);
    end;
    LPair := Copy(AQuery, LStart, LEnd - LStart);
    LEqual := Pos('=', LPair);
    Need(LEqual > 1, 'Invalid query pair');
    if Copy(LPair, 1, LEqual - 1) = AName then
    begin
      Need(Result = '', 'Duplicate query key');
      Result := Copy(LPair, LEqual + 1, MaxInt);
      Need(Result <> '', 'Empty query value');
    end;
    LStart := LEnd + 1;
  end;
end;

function QueryInt64(const AQuery, AName: String): Int64;
begin
  Need(TryStrToInt64(QueryValue(AQuery, AName), Result),
    'Invalid integer query ' + AName);
end;

function QueryInteger(const AQuery, AName: String): Integer;
begin
  Need(TryStrToInt(QueryValue(AQuery, AName), Result),
    'Invalid integer query ' + AName);
end;

function MediaCookieName(const ASocket: Integer): String;
begin
  if TransportIsTls(ASocket) then
    Result := 'PythianListenTls'
  else
    Result := 'PythianListen';
end;

function MediaSessionCookie(const ASocket: Integer; const AToken: String): String;
begin
  Result := 'Set-Cookie: ' + MediaCookieName(ASocket) + '=' + AToken +
    '; Path=/api/; HttpOnly; SameSite=Strict';
  if TransportIsTls(ASocket) then
    Result := Result + '; Secure';
  Result := Result + #13#10;
end;

function MediaCookieValid(const ACookie, AToken: String;
  const ASocket: Integer): Boolean;
var
  LStart: Integer;
  LEnd: Integer;
  LPair: String;
  LEqual: Integer;
  LFound: Boolean;
begin
  Result := False;
  LFound := False;
  LStart := 1;
  while LStart <= Length(ACookie) do
  begin
    LEnd := Pos(';', Copy(ACookie, LStart, MaxInt));
    if LEnd = 0 then
      LEnd := Length(ACookie) + 1
    else
      Inc(LEnd, LStart - 1);
    LPair := Trim(Copy(ACookie, LStart, LEnd - LStart));
    LEqual := Pos('=', LPair);
    if (LEqual > 1) and
      (Copy(LPair, 1, LEqual - 1) = MediaCookieName(ASocket)) then
    begin
      if LFound then Exit(False);
      LFound := True;
      Result := Copy(LPair, LEqual + 1, MaxInt) = AToken;
    end;
    LStart := LEnd + 1;
  end;
  Result := Result and LFound;
end;

procedure SendJson(const ASocket: Integer; const AJson: TJSONObject;
  const AExtraHeaders: String = '');
var
  LText: String;
begin
  LText := AJson.AsJSON + LineEnding;
  Need(Length(LText) <= CMaximumJsonResponseBytes,
    'JSON response exceeds bound');
  SendResponse(ASocket, 200, 'application/json; charset=utf-8', LText,
    AExtraHeaders);
end;

function ParseBodyObject(const ABody: String): TJSONObject;
var
  LData: TJSONData;
begin
  try
    LData := GetJSON(ABody);
  except
    on E: Exception do
      raise EAudio.Create('Invalid JSON request body');
  end;
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Expected JSON request object');
  end;
  Result := TJSONObject(LData);
end;

constructor TListeningReviewWorker.Create(const ASocket: Integer;
  const ACatalogRoot, ABody: String);
begin
  inherited Create(True);
  FSocket := ASocket;
  FCatalogRoot := ACatalogRoot;
  FBody := ABody;
end;

procedure TListeningReviewWorker.Execute;
var
  LBody: TJSONObject;
  LReport: TJSONObject;
  LStatus: Integer;
  LMessage: String;
begin
  LBody := nil;
  LReport := nil;
  try
    try
      LBody := ParseBodyObject(FBody);
      LReport := CommitListeningReview(FCatalogRoot, LBody);
      SendJson(FSocket, LReport);
    except
      on LError: Exception do
      begin
        if Pos('revision conflict', LowerCase(LError.Message)) > 0 then
          LStatus := 409
        else if (LError is EAudio) or (LError is EReviewQueue) then
          LStatus := 422
        else
        begin
          LStatus := 500;
          WriteLn(StdErr, 'Listening review worker failed: ',
            LError.ClassName, ': ', LError.Message);
        end;
        LMessage := Copy(StringReplace(StringReplace(LError.Message,
          #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]), 1, 240);
        SendResponse(FSocket, LStatus, 'text/plain; charset=utf-8',
          StatusReason(LStatus) + ': ' + LMessage + #10);
      end;
    end;
  finally
    LReport.Free;
    LBody.Free;
    TransportClose(FSocket);
    InterlockedDecrement(GActiveReviewWorkers);
  end;
end;

function DispatchListeningReview(const ASocket: Integer;
  const ACatalogRoot, ABody: String): Boolean;
var
  LWorker: TListeningReviewWorker;
begin
  Result := False;
  if InterlockedIncrement(GActiveReviewWorkers) > 4 then
  begin
    InterlockedDecrement(GActiveReviewWorkers);
    SendResponse(ASocket, 503, 'text/plain; charset=utf-8',
      'Listening review workers are busy.'#10);
    Exit;
  end;
  LWorker := nil;
  try
    LWorker := TListeningReviewWorker.Create(ASocket, ACatalogRoot, ABody);
    LWorker.FreeOnTerminate := True;
    LWorker.Start;
    Result := True;
  except
    if LWorker <> nil then
    begin
      LWorker.FreeOnTerminate := False;
      LWorker.Free;
    end;
    InterlockedDecrement(GActiveReviewWorkers);
    SendResponse(ASocket, 503, 'text/plain; charset=utf-8',
      'Listening review worker could not start.'#10);
  end;
end;

function StaticAssetName(const APath: String): String;
begin
  if (APath = '/') or (APath = '/index.html') then
  begin
    Exit('index.html');
  end;
  if APath = '/app.js' then
  begin
    Exit('app.js');
  end;
  if APath = '/style.css' then
  begin
    Exit('style.css');
  end;
  if APath = '/listen.html' then
    Exit('listen.html');
  if APath = '/listen.js' then
    Exit('listen.js');
  if APath = '/listen.css' then
    Exit('listen.css');
  if APath = '/studio.html' then
    Exit('studio.html');
  if APath = '/studio.js' then
    Exit('studio.js');
  if APath = '/studio.css' then
    Exit('studio.css');
  if APath = '/capture-worklet.js' then
    Exit('capture-worklet.js');
  if APath = '/workspace-nav.css' then
    Exit('workspace-nav.css');
  Result := '';
end;

procedure SendStaticAsset(const ASocket: Integer;
  const AStaticRoot, AName: String);
var
  LPath: String;
  LContentType: String;
  LInput: TFileStream;
begin
  LPath := IncludeTrailingPathDelimiter(ExpandFileName(AStaticRoot)) + AName;
  LInput := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LInput.Size > 0) and (LInput.Size <= CMaximumStaticBytes),
      'Static asset exceeds size bound');
    if (AName = 'app.js') or (AName = 'listen.js') or
      (AName = 'studio.js') or (AName = 'capture-worklet.js') then
    begin
      LContentType := 'text/javascript; charset=utf-8';
    end
    else if (AName = 'style.css') or (AName = 'listen.css') or
      (AName = 'studio.css') or (AName = 'workspace-nav.css') then
    begin
      LContentType := 'text/css; charset=utf-8';
    end
    else
    begin
      LContentType := 'text/html; charset=utf-8';
    end;
    SendStreamResponse(ASocket, LInput, LContentType);
  finally
    LInput.Free;
  end;
end;

procedure ConfigurePhoneSetup(const AThumbprint, ABindAddress: String;
  const APort: Integer);
var
  LPath: String;
  LInput: TFileStream;
  LBytes: TBytes;
begin
  GPhoneCaBytes := '';
  GPhoneCaSha256 := '';
  GPhoneHttpsOrigin := '';
  LPath := SysUtils.GetEnvironmentVariable('PYTHIAN_TLS_CA_FILE');
  if AThumbprint = '' then
  begin
    Need(LPath = '', 'A public TLS certificate requires a configured server certificate');
    Exit;
  end;
  Need(LPath <> '', 'Configure PYTHIAN_TLS_CA_FILE for phone certificate setup');
  LInput := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LInput.Size > 0) and (LInput.Size <= 16384),
      'Phone certificate must be a public DER certificate within 16 KiB');
    SetLength(LBytes, Integer(LInput.Size));
    LInput.ReadBuffer(LBytes[0], Length(LBytes));
    ValidatePublicCaDer(LBytes);
    LInput.Position := 0;
    GPhoneCaSha256 := Sha256Stream(LInput, LInput.Size);
    SetLength(GPhoneCaBytes, Length(LBytes));
    Move(LBytes[0], GPhoneCaBytes[1], Length(LBytes));
  finally
    LInput.Free;
  end;
  GPhoneHttpsOrigin := 'https://' + ABindAddress + ':' + IntToStr(APort);
end;

procedure SendPhoneSetup(const ASocket: Integer;
  const AStaticRoot, APath: String);
var
  LInput: TFileStream;
  LPage: String;
begin
  if GPhoneHttpsOrigin = '' then
  begin
    SendResponse(ASocket, 503, 'text/html; charset=utf-8',
      '<!doctype html><html lang="en"><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<title>Phone recording setup</title><h1>Phone recording needs HTTPS setup</h1>' +
      '<p>Configure the local certificate on the host computer using the LAN review guide.</p>' +
      '<p><a href="/studio.html">Return to Studio</a></p></html>');
    Exit;
  end;
  if APath = '/phone-ca.cer' then
  begin
    SendResponse(ASocket, 200, 'application/x-x509-ca-cert', GPhoneCaBytes,
      'Content-Disposition: attachment; filename="pythian-studio-ca.cer"'#13#10);
    Exit;
  end;
  LInput := TFileStream.Create(IncludeTrailingPathDelimiter(AStaticRoot) +
    'phone-setup.html', fmOpenRead or fmShareDenyWrite);
  try
    Need((LInput.Size > 0) and (LInput.Size <= 65536), 'Phone setup page exceeds bound');
    SetLength(LPage, Integer(LInput.Size));
    LInput.ReadBuffer(LPage[1], Length(LPage));
  finally
    LInput.Free;
  end;
  // Only the validated bind address/port and a hexadecimal public hash enter HTML.
  LPage := StringReplace(LPage, '@@PYTHIAN_HTTPS_URL@@',
    GPhoneHttpsOrigin + '/studio.html', [rfReplaceAll]);
  LPage := StringReplace(LPage, '@@PYTHIAN_CERT_SHA256@@', GPhoneCaSha256, [rfReplaceAll]);
  SendResponse(ASocket, 200, 'text/html; charset=utf-8', LPage);
end;

procedure HandleRoute(const ASocket: Integer;
  const ARequest: TCatalogHttpRequest;
  const AInboxRoot, ACatalogRoot, AStaticRoot, AToken,
    AAccessKey: String; const AOpenLan: Boolean;
  out AHandedOff: Boolean);
var
  LReport: TJSONObject;
  LBody: TJSONObject;
  LAudio: TMemoryStream;
  LTrack: TJSONObject;
  LHash: String;
  LStaticName: String;
  LText: String;
  LExtraHeaders: String;
  LAsset: TJSONObject;
  LMediaStream: TFileStream;
  LRows: TJSONArray;
  LIndex: Integer;
  LRowName: String;
begin
  AHandedOff := False;
  LExtraHeaders := '';
  LStaticName := '';
  if (ARequest.Method = 'GET') and (AStaticRoot <> '') and
    ((ARequest.Path = '/phone-setup.html') or
     (ARequest.Path = '/phone-ca.cer')) then
  begin
    SendPhoneSetup(ASocket, AStaticRoot, ARequest.Path);
    Exit;
  end;
  if (AStaticRoot <> '') and (ARequest.Method = 'GET') then
  begin
    LStaticName := StaticAssetName(ARequest.Path);
  end;
  if LStaticName <> '' then
  begin
    SendStaticAsset(ASocket, AStaticRoot, LStaticName);
    Exit;
  end;
  if (ARequest.Path = '/api/listen-audio') or
    (ARequest.Path = '/api/studio/source-audio') or
    (ARequest.Path = '/api/studio/effect-audio') or
    (ARequest.Path = '/api/studio/capture-audio') or
    (ARequest.Path = '/api/studio/pitch-audio') or
    (ARequest.Path = '/api/studio/pitch-midi') or
    (ARequest.Path = '/api/studio/review-audio') then
  begin
    Need((ARequest.Token = AToken) or
      MediaCookieValid(ARequest.Cookie, AToken, ASocket),
      'Missing or invalid media session');
  end
  else if not ((ARequest.Path = '/api/session') and
    (((ARequest.Method = 'POST') and (AAccessKey <> '')) or
    ((ARequest.Method = 'GET') and (AAccessKey = '')))) and
    ((AAccessKey <> '') or AOpenLan) then
  begin
    Need(ARequest.Token = AToken, 'Missing or invalid session token');
  end
  else if (ARequest.Method = 'POST') and
    (ARequest.Path <> '/api/session') then
  begin
    Need(ARequest.Token = AToken, 'Missing or invalid session token');
  end;
  LReport := nil;
  LBody := nil;
  try
    if (ARequest.Method = 'GET') and (ARequest.Path = '/api/session') and
      (AAccessKey = '') then
    begin
      LReport := TJSONObject.Create;
      LReport.Add('version', 1);
      LReport.Add('token', AToken);
      LExtraHeaders := MediaSessionCookie(ASocket, AToken);
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/session') and (AAccessKey <> '') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      Need((LBody.Find('access_key') <> nil) and
        (LBody.Strings['access_key'] = AAccessKey),
        'Missing or invalid access key');
      LReport := TJSONObject.Create;
      LReport.Add('version', 1);
      LReport.Add('token', AToken);
      LExtraHeaders := MediaSessionCookie(ASocket, AToken);
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/catalog') then
    begin
      LReport := ListLabelCatalog(ACatalogRoot);
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/studio/sources') then
    begin
      LReport := ListStudioSources(ACatalogRoot);
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/studio/library') then
    begin
      LReport := ListStudioLibrary(ACatalogRoot);
    end
    else if ((ARequest.Method = 'GET') or (ARequest.Method = 'HEAD')) and
      (ARequest.Path = '/api/studio/source-audio') then
    begin
      LHash := QueryValue(ARequest.Query, 'hash');
      LMediaStream := OpenStudioSourceAudio(ACatalogRoot, LHash);
      try
        LText := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
          'sources' + PathDelim + LHash + '.wav';
        AHandedOff := DispatchListeningMedia(ASocket, LMediaStream,
          ARequest.Method, ARequest.Range, ARequest.IfRange, LHash,
          LText, LMediaStream.Size);
        if AHandedOff then
        begin
          LMediaStream := nil;
        end;
      finally
        LMediaStream.Free;
      end;
      Exit;
    end
    else if ((ARequest.Method = 'GET') or (ARequest.Method = 'HEAD')) and
      (ARequest.Path = '/api/studio/effect-audio') then
    begin
      LText := QueryValue(ARequest.Query, 'job');
      LMediaStream := OpenStudioEffectPreview(ACatalogRoot, LText, LHash);
      try
        LText := StudioJobDirectory(ACatalogRoot, LText) + PathDelim + 'effect.wav';
        AHandedOff := DispatchListeningMedia(ASocket, LMediaStream,
          ARequest.Method, ARequest.Range, ARequest.IfRange, LHash,
          LText, LMediaStream.Size);
        if AHandedOff then
        begin
          LMediaStream := nil;
        end;
      finally
        LMediaStream.Free;
      end;
      Exit;
    end
    else if ((ARequest.Method = 'GET') or (ARequest.Method = 'HEAD')) and
      (ARequest.Path = '/api/studio/capture-audio') then
    begin
      LMediaStream := OpenStudioCapture(ACatalogRoot, QueryValue(ARequest.Query, 'id'),
        LHash, LText);
      try
        AHandedOff := DispatchListeningMedia(ASocket, LMediaStream,
          ARequest.Method, ARequest.Range, ARequest.IfRange, LHash);
        if AHandedOff then
        begin
          LMediaStream := nil;
        end;
      finally
        LMediaStream.Free;
      end;
      Exit;
    end
    else if (ARequest.Method = 'GET') and (ARequest.Path = '/api/studio/pitch-midi') then
    begin
      LMediaStream := OpenStudioPitchArtifact(ACatalogRoot, QueryValue(ARequest.Query, 'job'),
        'midi', LHash);
      try
        SendStreamResponse(ASocket, LMediaStream, 'audio/midi');
      finally
        LMediaStream.Free;
      end;
      Exit;
    end
    else if ((ARequest.Method = 'GET') or (ARequest.Method = 'HEAD')) and
      (ARequest.Path = '/api/studio/pitch-audio') then
    begin
      LMediaStream := OpenStudioPitchArtifact(ACatalogRoot, QueryValue(ARequest.Query, 'job'),
        'audio', LHash);
      try
        AHandedOff := DispatchListeningMedia(ASocket, LMediaStream,
          ARequest.Method, ARequest.Range, ARequest.IfRange, LHash);
        if AHandedOff then
        begin
          LMediaStream := nil;
        end;
      finally
        LMediaStream.Free;
      end;
      Exit;
    end
    else if (ARequest.Method = 'POST') and (ARequest.Path = '/api/studio/exploration-feedback') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      LReport := SaveStudioExplorationFeedback(ACatalogRoot, LBody);
    end
    else if (ARequest.Method = 'GET') and (ARequest.Path = '/api/studio/captures') then
    begin
      LReport := ListStudioCaptures(ACatalogRoot);
    end
    else if (ARequest.Method = 'GET') and (ARequest.Path = '/api/studio/capture') then
    begin
      LReport := ReadStudioCapture(ACatalogRoot, QueryValue(ARequest.Query, 'id'));
    end
    else if (ARequest.Method = 'POST') and (ARequest.Path = '/api/studio/capture/start') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      LReport := StartStudioCapture(ACatalogRoot, LBody);
    end
    else if (ARequest.Method = 'POST') and (ARequest.Path = '/api/studio/capture/chunk') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      LReport := AppendStudioCapture(ACatalogRoot, LBody);
    end
    else if (ARequest.Method = 'POST') and (ARequest.Path = '/api/studio/capture/discard') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      Need((LBody.Count = 1) and (LBody.Find('capture_id') <> nil), 'Choose one temporary input');
      LReport := DiscardStudioCapture(ACatalogRoot, LBody.Strings['capture_id']);
    end
    else if (ARequest.Method = 'GET') and (ARequest.Path = '/api/studio/reviews') then
    begin
      LReport := ListStudioReviews(ACatalogRoot);
    end
    else if (ARequest.Method = 'GET') and (ARequest.Path = '/api/studio/review') then
    begin
      LReport := ReadStudioReview(ACatalogRoot, QueryValue(ARequest.Query, 'id'));
    end
    else if (ARequest.Method = 'POST') and (ARequest.Path = '/api/studio/review') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      LReport := CreateStudioReview(ACatalogRoot, LBody);
    end
    else if (ARequest.Method = 'POST') and (ARequest.Path = '/api/studio/review/response') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      LReport := CommitStudioReview(ACatalogRoot, LBody);
    end
    else if (ARequest.Method = 'POST') and (ARequest.Path = '/api/studio/review/pin') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      Need((LBody.Count = 3) and (LBody.Find('review_id') <> nil) and
        (LBody.Find('expected_revision') <> nil) and (LBody.Find('pinned') <> nil) and
        (LBody.Find('pinned').JSONType = jtBoolean), 'Choose a review and explicit pin state');
      LReport := PinStudioReview(ACatalogRoot, LBody.Strings['review_id'],
        LBody.Int64s['expected_revision'], LBody.Booleans['pinned']);
    end
    else if (ARequest.Method = 'GET') and (ARequest.Path = '/api/studio/review/next-batch') then
    begin
      LReport := PrepareStudioNextBatch(ACatalogRoot, QueryValue(ARequest.Query, 'id'),
        QueryValue(ARequest.Query, 'sample'));
    end
    else if ((ARequest.Method = 'GET') or (ARequest.Method = 'HEAD')) and
      (ARequest.Path = '/api/studio/review-audio') then
    begin
      LAsset := ResolveStudioReviewAsset(ACatalogRoot, QueryValue(ARequest.Query, 'id'),
        QueryValue(ARequest.Query, 'sample'));
      try
        LMediaStream := TFileStream.Create(LAsset.Strings['path'], fmOpenRead or fmShareDenyWrite);
        try
          Need(LMediaStream.Size = LAsset.Int64s['bytes'], 'Review audio size changed');
          LHash := StudioTextHash('review-media:' + QueryValue(ARequest.Query, 'id') + ':' +
            QueryValue(ARequest.Query, 'sample'));
          AHandedOff := DispatchListeningMedia(ASocket, LMediaStream,
            ARequest.Method, ARequest.Range, ARequest.IfRange, LHash,
            LAsset.Strings['path'], LAsset.Int64s['bytes'], LAsset.Strings['sha256']);
          if AHandedOff then
          begin
            LMediaStream := nil;
          end;
        finally
          LMediaStream.Free;
        end;
      finally
        LAsset.Free;
      end;
      Exit;
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/studio/projects') then
    begin
      LReport := ListStudioProjects(ACatalogRoot);
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/studio/project-revision') then
    begin
      LReport := ReadStudioProjectRevision(ACatalogRoot,
        QueryValue(ARequest.Query, 'id'), QueryInteger(ARequest.Query, 'revision'));
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/studio/project') then
    begin
      LReport := ReadStudioProject(ACatalogRoot,
        QueryValue(ARequest.Query, 'id'));
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/studio/project') then
    begin
      LBody := ParseStudioProjectWrite(ARequest.Body);
      LReport := SaveStudioProject(ACatalogRoot, LBody);
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/studio/jobs') then
    begin
      LReport := ListStudioJobs(ACatalogRoot);
      LReport.Add('worker_available', GStudioSupervisor <> nil);
      if GStudioSupervisor <> nil then
      begin
        LReport.Add('worker_error', GStudioSupervisor.LastError);
      end;
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/studio/job') then
    begin
      LReport := ReadStudioJob(ACatalogRoot, QueryValue(ARequest.Query, 'id'));
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/studio/preflight') then
    begin
      LBody := ParseStudioJobWrite(ARequest.Body);
      LReport := PrepareStudioJob(ACatalogRoot, LBody);
      LReport.Add('worker_available', GStudioSupervisor <> nil);
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/studio/job') then
    begin
      Need(GStudioSupervisor <> nil, 'Studio worker is not installed. Stage the worker beside the service.');
      LBody := ParseStudioJobWrite(ARequest.Body);
      LReport := EnqueueStudioJob(ACatalogRoot, LBody);
      GStudioSupervisor.Notify;
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/studio/cancel') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      Need((LBody.Count = 1) and (LBody.Find('job_id') <> nil) and
        (LBody.Find('job_id').JSONType = jtString), 'Cancel requires a job identity');
      LReport := CancelStudioJob(ACatalogRoot, LBody.Strings['job_id']);
      if GStudioSupervisor <> nil then
      begin
        GStudioSupervisor.Notify;
      end;
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/inbox') then
    begin
      LReport := ReadPreparedLabelInbox(AInboxRoot);
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/review-queue') then
    begin
      LReport := ReadReviewQueue(ACatalogRoot);
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/listen-queue') then
    begin
      LReport := ReadListeningQueue(ACatalogRoot);
      for LRowName in CListeningLists do
      begin
        LRows := LReport.Arrays[LRowName];
        for LIndex := LRows.Count - 1 downto 0 do
        begin
          if IsStudioReviewListeningItem(ACatalogRoot, LRows.Objects[LIndex].Strings['id']) then
          begin
            LRows.Delete(LIndex);
          end;
        end;
      end;
      LReport.Integers['waiting_count'] := LReport.Arrays['items'].Count;
      LReport.Integers['completed_count'] := LReport.Arrays['completed'].Count;
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/proposals') then
    begin
      LHash := QueryValue(ARequest.Query, 'hash');
      LTrack := ReadCatalogTrack(ACatalogRoot, LHash);
      try
        Need(CatalogProposalsUnlocked(ACatalogRoot, LTrack),
          'Evaluation proposals require blind review');
      finally
        LTrack.Free;
      end;
      LReport := ReadCatalogBeatProposals(ACatalogRoot, LHash,
        QueryInt64(ARequest.Query, 'start'),
        QueryInt64(ARequest.Query, 'end'));
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/waveform') then
    begin
      LReport := CatalogWaveformRegion(ACatalogRoot,
        QueryValue(ARequest.Query, 'hash'),
        QueryInt64(ARequest.Query, 'start'),
        QueryInt64(ARequest.Query, 'end'),
        QueryInteger(ARequest.Query, 'bins'));
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/current') then
    begin
      LReport := ReadCatalogCurrentLabels(ACatalogRoot,
        QueryValue(ARequest.Query, 'hash'),
        QueryInt64(ARequest.Query, 'start'),
        QueryInt64(ARequest.Query, 'end'),
        QueryInteger(ARequest.Query, 'count'));
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/history') then
    begin
      LReport := ReadCatalogReviewHistory(ACatalogRoot,
        QueryValue(ARequest.Query, 'hash'),
        QueryInteger(ARequest.Query, 'first'),
        QueryInteger(ARequest.Query, 'count'));
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/export') then
    begin
      LReport := BuildReviewedCatalogPacket(ACatalogRoot);
      LText := LReport.AsJSON + LineEnding;
      Need(Length(LText) <= CMaximumReviewedExportBytes,
        'Reviewed export exceeds HTTP packet bound');
      SendResponse(ASocket, 200, 'application/json; charset=utf-8', LText);
      Exit;
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/audio') then
    begin
      LAudio := TMemoryStream.Create;
      try
        LHash := QueryValue(ARequest.Query, 'hash');
        WriteCatalogAudioRegion(ACatalogRoot, LHash,
          QueryInt64(ARequest.Query, 'start'),
          QueryInt64(ARequest.Query, 'end'), LAudio);
        SendStreamResponse(ASocket, LAudio, 'audio/wav');
        WriteLn(StdErr, 'HTTP audio served bytes=', LAudio.Size);
        Flush(StdErr);
      finally
        LAudio.Free;
      end;
      Exit;
    end
    else if ((ARequest.Method = 'GET') or
      (ARequest.Method = 'HEAD')) and
      (ARequest.Path = '/api/listen-audio') then
    begin
      Need(not IsStudioReviewListeningItemHidden(ACatalogRoot,
        QueryValue(ARequest.Query, 'request')), 'Use the masked review player for this sample');
      LAsset := ResolveListeningAsset(ACatalogRoot,
        QueryValue(ARequest.Query, 'request'),
        QueryValue(ARequest.Query, 'asset'));
      try
        if LAsset.Strings['request_sha256'] <>
          QueryValue(ARequest.Query, 'packet') then
        begin
          SendResponse(ASocket, 409, 'text/plain; charset=utf-8',
            'Listening request changed'#10);
          Exit;
        end;
        LMediaStream := TFileStream.Create(LAsset.Strings['path'],
          fmOpenRead or fmShareDenyWrite);
        try
          Need(LMediaStream.Size = LAsset.Int64s['bytes'],
            'Listening asset changed after verification');
          AHandedOff := DispatchListeningMedia(ASocket, LMediaStream,
            ARequest.Method, ARequest.Range, ARequest.IfRange,
            LAsset.Strings['sha256'], LAsset.Strings['path'],
            LAsset.Int64s['bytes']);
          if AHandedOff then
            LMediaStream := nil;
        finally
          LMediaStream.Free;
        end;
      finally
        LAsset.Free;
      end;
      Exit;
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/cue') then
    begin
      LAudio := TMemoryStream.Create;
      try
        WriteCatalogBeatCueRegion(ACatalogRoot,
          QueryValue(ARequest.Query, 'hash'),
          QueryInt64(ARequest.Query, 'start'),
          QueryInt64(ARequest.Query, 'end'),
          QueryInteger(ARequest.Query, 'candidate'), LAudio);
        SendStreamResponse(ASocket, LAudio, 'audio/wav');
      finally
        LAudio.Free;
      end;
      Exit;
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/import') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      Need(LBody.Count = 0, 'Import request body must be empty object');
      LReport := ImportLabelInbox(AInboxRoot, ACatalogRoot);
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/import-reviewed') then
    begin
      LReport := ReplayReviewedCatalogText(ACatalogRoot, ARequest.Body);
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/review') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      LReport := CommitCatalogReview(ACatalogRoot, LBody);
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/listen-review') then
    begin
      AHandedOff := DispatchListeningReview(ASocket, ACatalogRoot,
        ARequest.Body);
      Exit;
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/propose-beats') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      LHash := LBody.Strings['source_sha256'];
      LTrack := ReadCatalogTrack(ACatalogRoot, LHash);
      try
        Need(CatalogProposalsUnlocked(ACatalogRoot, LTrack),
          'Evaluation proposals require blind review');
      finally
        LTrack.Free;
      end;
      LReport := PublishCatalogBeatProposals(ACatalogRoot, LHash,
        LBody.Int64s['start_frame'], LBody.Int64s['end_frame']);
    end
    else
    begin
      SendResponse(ASocket, 404, 'text/plain; charset=utf-8',
        'Not Found'#10);
      Exit;
    end;
    SendJson(ASocket, LReport, LExtraHeaders);
  finally
    LBody.Free;
    LReport.Free;
  end;
end;

procedure HandleClient(const ASocket, APort: Integer;
  const AInboxRoot, ACatalogRoot, AStaticRoot, ABindAddress, AToken,
    AAccessKey: String; const AOpenLan: Boolean;
  out AHandedOff: Boolean);
var
  LRequest: TCatalogHttpRequest;
  LStatus: Integer;
  LFailure: String;
begin
  AHandedOff := False;
  SetClientTimeouts(ASocket);
  AcceptTransport(ASocket, GPhoneHttpsOrigin <> '', CReceiveDeadlineMs);
  LStatus := ReadRequest(ASocket, APort, ABindAddress, AToken,
    LRequest, LFailure);
  if LStatus <> 200 then
  begin
    WriteLn(StdErr, 'HTTP request rejected status=', LStatus,
      ' path=', LRequest.Path, ' reason=', LFailure);
    Flush(StdErr);
    if LStatus = 400 then
    begin
      SendResponse(ASocket, LStatus, 'text/plain; charset=utf-8',
        StatusReason(LStatus) + ': ' + LFailure + #10);
    end
    else
    begin
      SendResponse(ASocket, LStatus, 'text/plain; charset=utf-8',
        StatusReason(LStatus) + #10);
    end;
    Exit;
  end;
  try
    HandleRoute(ASocket, LRequest, AInboxRoot, ACatalogRoot,
      AStaticRoot, AToken, AAccessKey, AOpenLan, AHandedOff);
  except
    on LError: Exception do
    begin
      if (LError is EStudioConflict) or
        (Pos('revision conflict', LowerCase(LError.Message)) > 0) then
      begin
        LStatus := 409;
      end
      else if (Pos('session token', LowerCase(LError.Message)) > 0) or
        (Pos('media session', LowerCase(LError.Message)) > 0) or
        (Pos('access key', LowerCase(LError.Message)) > 0) then
      begin
        LStatus := 403;
      end
      else if Pos('evaluation proposals',
        LowerCase(LError.Message)) > 0 then
      begin
        LStatus := 403;
      end
      else if Pos('stored proposal packet does not exist',
        LowerCase(LError.Message)) > 0 then
      begin
        LStatus := 404;
      end
      else if (Pos('listening request is not published',
        LowerCase(LError.Message)) > 0) or
        (Pos('asset is not declared', LowerCase(LError.Message)) > 0) then
      begin
        LStatus := 404;
      end
      else if LError is EReviewQueue then
      begin
        SendResponse(ASocket, 422, 'text/plain; charset=utf-8',
          LError.Message + #10);
        Exit;
      end
      else if LError is EAudio then
      begin
        LStatus := 422;
      end
      else
      begin
        LStatus := 500;
        WriteLn(StdErr, 'HTTP request failure: ', LError.ClassName,
          ': ', LError.Message);
      end;
      if (LRequest.Path = '/api/listen-review') or
        (LRequest.Path = '/api/listen-audio') or
        ((Pos('/api/studio/', LRequest.Path) = 1) and
         (LError is EAudio)) then
        SendResponse(ASocket, LStatus, 'text/plain; charset=utf-8',
          StatusReason(LStatus) + ': ' +
          Copy(StringReplace(StringReplace(LError.Message, #13, ' ',
            [rfReplaceAll]), #10, ' ', [rfReplaceAll]), 1, 240) + #10)
      else
        SendResponse(ASocket, LStatus, 'text/plain; charset=utf-8',
          StatusReason(LStatus) + #10);
    end;
  end;
end;

function ValidBindAddress(const AAddress: String): Boolean;
var
  LParts: TStringList;
  LValues: array[0..3] of Integer;
  LIndex: Integer;
begin
  Result := False;
  LParts := TStringList.Create;
  try
    LParts.StrictDelimiter := True;
    LParts.Delimiter := '.';
    LParts.DelimitedText := AAddress;
    if LParts.Count <> 4 then
    begin
      Exit;
    end;
    for LIndex := 0 to 3 do
    begin
      if (LParts[LIndex] = '') or
        not TryStrToInt(LParts[LIndex], LValues[LIndex]) or
        (LValues[LIndex] < 0) or (LValues[LIndex] > 255) or
        (IntToStr(LValues[LIndex]) <> LParts[LIndex]) then
      begin
        Exit;
      end;
    end;
    Result := ((LValues[0] = 127) and (LValues[1] = 0) and
      (LValues[2] = 0) and (LValues[3] = 1)) or
      (LValues[0] = 10) or
      ((LValues[0] = 172) and (LValues[1] >= 16) and
      (LValues[1] <= 31)) or
      ((LValues[0] = 192) and (LValues[1] = 168));
  finally
    LParts.Free;
  end;
end;

procedure RestrictLanKeyFile(const APath: String);
{$IFDEF MSWINDOWS}
var
  LDescriptor: Pointer;
  LPath: WideString;
  LSddl: WideString;
begin
  LDescriptor := nil;
  LSddl := 'D:P(A;;FA;;;SY)(A;;FA;;;OW)';
  Need(DecodeKeyFileDacl(PWideChar(LSddl), 1, LDescriptor, nil),
    'Could not build LAN key file permissions');
  try
    LPath := UTF8Decode(APath);
    Need(ApplyKeyFileDacl(PWideChar(LPath), DACL_SECURITY_INFORMATION,
      LDescriptor), 'Could not restrict LAN key file permissions');
  finally
    LocalFree(HLOCAL(LDescriptor));
  end;
end;
{$ELSE}
begin
  Need(fpChmod(PChar(APath), &600) = 0,
    'Could not restrict LAN key file permissions');
end;
{$ENDIF}

function PersistentLanAccessKey(const ACatalogRoot: String): String;
var
  LPath: String;
  LStream: TFileStream;
  LGuid: TGUID;
begin
  LPath := IncludeTrailingPathDelimiter(ACatalogRoot) + '.access-key';
  if FileExists(LPath) then
  begin
    RestrictLanKeyFile(LPath);
    LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
    try
      Need((LStream.Size >= 16) and (LStream.Size <= 256),
        'Invalid saved LAN access key length');
      SetLength(Result, Integer(LStream.Size));
      LStream.ReadBuffer(Result[1], Length(Result));
    finally
      LStream.Free;
    end;
    while (Result <> '') and (Result[Length(Result)] in [#10, #13]) do
    begin
      SetLength(Result, Length(Result) - 1);
    end;
    Need(Length(Result) >= 16, 'Invalid saved LAN access key length');
    Exit;
  end;

  Result := SysUtils.GetEnvironmentVariable('PYTHIAN_CATALOG_ACCESS_KEY');
  if Result = '' then
  begin
    Need(CreateGUID(LGuid) = 0, 'Could not create LAN access key');
    Result := GUIDToString(LGuid);
    Need(CreateGUID(LGuid) = 0, 'Could not create LAN access key');
    Result := Result + GUIDToString(LGuid);
  end;
  Need((Length(Result) >= 16) and (Length(Result) <= 256),
    'LAN access key must have 16..256 characters');
  LStream := TFileStream.Create(LPath, fmCreate or fmShareExclusive);
  try
    // Restrict the empty file before any secret bytes reach disk.
  finally
    LStream.Free;
  end;
  try
    RestrictLanKeyFile(LPath);
  except
    SysUtils.DeleteFile(LPath);
    raise;
  end;
  LStream := TFileStream.Create(LPath, fmOpenWrite or fmShareExclusive);
  try
    LStream.WriteBuffer(Result[1], Length(Result));
  finally
    LStream.Free;
  end;
  WriteLn('LAN access key saved in ', LPath,
    '; enter it once per trusted browser origin.');
end;

function ReadyCatalogListener(const APrimary, ALoopback: Integer): Integer;
var
  LSet: TFDSet;
  LReady: Integer;
begin
  if ALoopback < 0 then
  begin
    Exit(APrimary);
  end;
  {$IFDEF MSWINDOWS}
  FD_ZERO(LSet);
  FD_SET(APrimary, LSet);
  FD_SET(ALoopback, LSet);
  LReady := WinSock2.select(0, @LSet, nil, nil, nil);
  Need(LReady > 0, 'Catalog listener readiness failed');
  if FD_ISSET(ALoopback, LSet) then
  {$ELSE}
  fpFD_ZERO(LSet);
  fpFD_SET(APrimary, LSet);
  fpFD_SET(ALoopback, LSet);
  LReady := fpSelect(Math.Max(APrimary, ALoopback) + 1, @LSet, nil, nil, nil);
  Need(LReady > 0, 'Catalog listener readiness failed');
  if fpFD_ISSET(ALoopback, LSet) <> 0 then
  {$ENDIF}
  begin
    Result := ALoopback;
  end
  else
  begin
    Result := APrimary;
  end;
end;

procedure RunCatalogHttp(const AInboxRoot, ACatalogRoot,
  ABindAddress: String; const APort, AMaximumRequests: Integer;
  const AStaticRoot: String; const AOpenLan: Boolean);
var
  LListener: Integer;
  LLoopback: Integer;
  LReadyListener: Integer;
  LClient: Integer;
  LAddress: TInetSockAddr;
  LCount: Integer;
  LGuid: TGUID;
  LToken: String;
  LAccessKey: String;
  LHandedOff: Boolean;
  LWorkerPath: String;
  LLibraryRoot: String;
  LTlsThumbprint: String;
begin
  Need(ValidBindAddress(ABindAddress),
    'Bind address must be loopback or a private LAN IPv4 address');
  Need((not AOpenLan) or (ABindAddress <> '127.0.0.1'),
    'Open LAN mode requires an explicit private LAN IPv4 bind address');
  Need((APort > 0) and (APort <= 65535), 'Invalid HTTP port');
  Need(AMaximumRequests >= 0, 'Invalid maximum HTTP request count');
  Need(DirectoryExists(AInboxRoot) and
    FileExists(IncludeTrailingPathDelimiter(AInboxRoot) + 'manifest.json'),
    'Configured inbox manifest does not exist');
  Need(DirectoryExists(IncludeTrailingPathDelimiter(ACatalogRoot) + 'tracks'),
    'Configured catalog does not exist');
  if AStaticRoot <> '' then
  begin
    Need(DirectoryExists(AStaticRoot) and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'index.html') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'app.js') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'style.css') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'listen.html') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'listen.js') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'listen.css') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'studio.html') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'studio.js') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'studio.css') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'capture-worklet.js') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'workspace-nav.css') and
      FileExists(IncludeTrailingPathDelimiter(AStaticRoot) + 'phone-setup.html'),
      'Configured browser assets are incomplete');
  end;
  Need(CreateGUID(LGuid) = 0, 'Could not create HTTP session token');
  LToken := GUIDToString(LGuid);
  LListener := fpSocket(AF_INET, SOCK_STREAM, 0);
  LLoopback := -1;
  Need(LListener >= 0, 'Could not create HTTP listener');
  try
    LTlsThumbprint := SysUtils.GetEnvironmentVariable('PYTHIAN_TLS_THUMBPRINT');
    ConfigureTransportTls(LTlsThumbprint);
    ConfigurePhoneSetup(LTlsThumbprint, ABindAddress, APort);
    FillChar(LAddress, SizeOf(LAddress), 0);
    LAddress.sin_family := AF_INET;
    LAddress.sin_port := htons(Word(APort));
    LAddress.sin_addr := StrToNetAddr(ABindAddress);
    Need(fpBind(LListener, @LAddress, SizeOf(LAddress)) = 0,
      'Could not bind catalog HTTP listener');
    LAccessKey := '';
    if (ABindAddress <> '127.0.0.1') and not AOpenLan then
    begin
      LAccessKey := PersistentLanAccessKey(ACatalogRoot);
    end;
    Need(fpListen(LListener, 8) = 0, 'Could not listen on catalog address');
    if (ABindAddress <> '127.0.0.1') and (AStaticRoot <> '') then
    begin
      LLoopback := fpSocket(AF_INET, SOCK_STREAM, 0);
      Need(LLoopback >= 0, 'Could not create local Studio listener');
      LAddress.sin_addr := StrToNetAddr('127.0.0.1');
      Need(fpBind(LLoopback, @LAddress, SizeOf(LAddress)) = 0,
        'Could not bind local Studio address');
      Need(fpListen(LLoopback, 8) = 0, 'Could not listen on local Studio address');
      WriteLn('Pythian local Studio: http://127.0.0.1:', APort, '/studio.html');
    end;
    LWorkerPath := SysUtils.GetEnvironmentVariable('PYTHIAN_STUDIO_WORKER');
    if LWorkerPath = '' then
    begin
      LWorkerPath := IncludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(ParamStr(0)))) +
        'pythian.studio.worker' {$IFDEF MSWINDOWS} + '.exe' {$ENDIF};
    end;
    LLibraryRoot := SysUtils.GetEnvironmentVariable('PYTHIAN_AUDIO_LIBRARY');
    if LLibraryRoot = '' then
    begin
      LLibraryRoot := ExpandFileName('local-audio');
    end;
    if FileExists(LWorkerPath) then
    begin
      GStudioSupervisor := TStudioJobSupervisor.Create(ACatalogRoot, LLibraryRoot, LWorkerPath);
    end;
    WriteLn('Pythian catalog API: http://', ABindAddress, ':',
      APort, '/api/session');
    if GPhoneHttpsOrigin <> '' then
      WriteLn('Pythian phone microphone: ', GPhoneHttpsOrigin, '/phone-setup.html');
    Flush(Output);
    LCount := 0;
    while (AMaximumRequests = 0) or (LCount < AMaximumRequests) do
    begin
      LReadyListener := ReadyCatalogListener(LListener, LLoopback);
      LClient := fpAccept(LReadyListener, nil, nil);
      Need(LClient >= 0, 'HTTP listener accept failed');
      LHandedOff := False;
      try
        try
          if LReadyListener = LLoopback then
          begin
            HandleClient(LClient, APort, AInboxRoot, ACatalogRoot,
              AStaticRoot, '127.0.0.1', LToken, '', False, LHandedOff);
          end
          else
          begin
            HandleClient(LClient, APort, AInboxRoot, ACatalogRoot,
              AStaticRoot, ABindAddress, LToken, LAccessKey, AOpenLan, LHandedOff);
          end;
        except
          on LError: Exception do
          begin
            WriteLn(StdErr, 'HTTP connection closed: ', LError.Message);
          end;
        end;
      finally
        if not LHandedOff then
          TransportClose(LClient);
      end;
      Inc(LCount);
    end;
  finally
    FreeAndNil(GStudioSupervisor);
    CloseSocket(LListener);
    if LLoopback >= 0 then
    begin
      CloseSocket(LLoopback);
    end;
  end;
end;

finalization
  while InterlockedCompareExchange(GActiveReviewWorkers, 0, 0) <> 0 do
    Sleep(10);

end.
