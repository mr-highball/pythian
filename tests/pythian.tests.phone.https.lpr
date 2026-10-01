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
program PythianPhoneHttpsConformance;

{$mode delphi}
{$H+}
{$packrecords c}

uses
  Classes,
  SysUtils,
  Windows,
  WinHTTP,
  WinSock2,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.hash;

type
  { The Windows CERT_CONTEXT ABI; certificate ownership stays with crypt32. }
  PCertificateContext = ^TCertificateContext;
  TCertificateContext = record
    Encoding: DWORD;
    Encoded: PByte;
    EncodedBytes: DWORD;
    Information: Pointer;
    Store: Pointer;
  end;

  TResponse = record
    Status: DWORD;
    Headers: String;
    Body: TAudioBytes;
  end;

  TClient = class
  private
    FSession: HINTERNET;
    FConnection: HINTERNET;
    FSecure: Boolean;
    FCa: PCertificateContext;
    FToken: String;
  public
    constructor Create(const AHost: String; const APort: Word;
      const ASecure: Boolean; const ACa: PCertificateContext;
      const ATimeout: Integer = 10000);
    destructor Destroy; override;
    function Get(const APath: String; const AHeaders: String = ''): TResponse;
    procedure StartSession;
    function Api(const APath: String; const AHeaders: String = ''): TResponse;
  end;

function CertCreateCertificateContext(AEncoding: DWORD; ABytes: PByte;
  ACount: DWORD): PCertificateContext; stdcall; external 'crypt32.dll';
function CertFreeCertificateContext(AContext: PCertificateContext): BOOL;
  stdcall; external 'crypt32.dll';
function CryptVerifyCertificateSignatureEx(AProvider: ULONG_PTR;
  AEncoding: DWORD; ASubjectType: DWORD; ASubject: Pointer;
  AIssuerType: DWORD; AIssuer: Pointer; AFlags: DWORD;
  AExtra: Pointer): BOOL; stdcall; external 'crypt32.dll';
function WinHttpSetTimeouts(AHandle: HINTERNET; AResolve: Integer;
  AConnect: Integer; ASend: Integer; AReceive: Integer): BOOL;
  stdcall; external 'winhttp.dll';

var
  Checks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(Checks);
end;

procedure OsCheck(const ACondition: Boolean; const AOperation: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AOperation + ': Windows error ' +
      IntToStr(GetLastError));
  end;
end;

function BodyText(const AResponse: TResponse): String;
begin
  if Length(AResponse.Body) = 0 then
  begin
    Exit('');
  end;
  SetString(Result, PAnsiChar(@AResponse.Body[0]), Length(AResponse.Body));
end;

function SameBytes(const ALeft: TAudioBytes; const ARight: TAudioBytes): Boolean;
begin
  Result := Length(ALeft) = Length(ARight);
  if Result and (Length(ALeft) > 0) then
  begin
    Result := CompareMem(@ALeft[0], @ARight[0], Length(ALeft));
  end;
end;

function ReadCa(const APath: String): TAudioBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Check((LStream.Size > 0) and (LStream.Size <= 16384),
      'Public CA DER must contain 1..16384 bytes');
    SetLength(Result, LStream.Size);
    LStream.ReadBuffer(Result[0], Length(Result));
  finally
    LStream.Free;
  end;
end;

constructor TClient.Create(const AHost: String; const APort: Word;
  const ASecure: Boolean; const ACa: PCertificateContext;
  const ATimeout: Integer);
var
  LHost: UnicodeString;
  LProtocols: DWORD;
begin
  inherited Create;
  FSecure := ASecure;
  FCa := ACa;
  FSession := WinHttpOpen('Pythian HTTPS conformance',
    WINHTTP_ACCESS_TYPE_NO_PROXY, nil, nil, 0);
  OsCheck(FSession <> nil, 'WinHttpOpen');
  OsCheck(WinHttpSetTimeouts(FSession, ATimeout, ATimeout, ATimeout, ATimeout),
    'WinHttpSetTimeouts');
  if ASecure then
  begin
    { TLS 1.2 only proves the required lower bound without weakening trust.
      No certificate-ignore flags, custom trust override or redirects. }
    LProtocols := WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
    OsCheck(WinHttpSetOption(FSession, WINHTTP_OPTION_SECURE_PROTOCOLS,
      @LProtocols, SizeOf(LProtocols)), 'Set TLS protocol');
  end;
  LHost := UnicodeString(AHost);
  FConnection := WinHttpConnect(FSession, PWideChar(LHost), APort, 0);
  OsCheck(FConnection <> nil, 'WinHttpConnect');
end;

destructor TClient.Destroy;
begin
  if FConnection <> nil then
  begin
    WinHttpCloseHandle(FConnection);
  end;
  if FSession <> nil then
  begin
    WinHttpCloseHandle(FSession);
  end;
  inherited Destroy;
end;

function TClient.Get(const APath: String; const AHeaders: String): TResponse;
var
  LRequest: HINTERNET;
  LFlags: DWORD;
  LPolicy: DWORD;
  LSize: DWORD;
  LRead: DWORD;
  LSecurity: DWORD;
  LPeer: PCertificateContext;
  LPath: UnicodeString;
  LHeaders: UnicodeString;
  LRaw: UnicodeString;
  LBuffer: array[0..8191] of Byte;
  LOld: Integer;
begin
  Result := Default(TResponse);
  LFlags := 0;
  if FSecure then
  begin
    LFlags := WINHTTP_FLAG_SECURE;
  end;
  LPath := UnicodeString(APath);
  LRequest := WinHttpOpenRequest(FConnection, 'GET', PWideChar(LPath),
    nil, nil, nil, LFlags);
  OsCheck(LRequest <> nil, 'WinHttpOpenRequest');
  try
    LPolicy := WINHTTP_OPTION_REDIRECT_POLICY_NEVER;
    OsCheck(WinHttpSetOption(LRequest, WINHTTP_OPTION_REDIRECT_POLICY,
      @LPolicy, SizeOf(LPolicy)), 'Disable redirects');
    LHeaders := UnicodeString(AHeaders);
    if LHeaders <> '' then
    begin
      { Replace an automatic Host rather than relying on duplicate headers. }
      OsCheck(WinHttpAddRequestHeaders(LRequest, PWideChar(LHeaders),
        Length(LHeaders), WINHTTP_ADDREQ_FLAG_ADD or
        WINHTTP_ADDREQ_FLAG_REPLACE), 'Set request headers');
    end;
    OsCheck(WinHttpSendRequest(LRequest, nil, 0, nil, 0, 0, 0),
      'WinHttpSendRequest');
    OsCheck(WinHttpReceiveResponse(LRequest, nil), 'WinHttpReceiveResponse');
    LSize := SizeOf(Result.Status);
    OsCheck(WinHttpQueryHeaders(LRequest,
      WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER, nil,
      @Result.Status, @LSize, nil), 'Read status');
    if FSecure then
    begin
      LSecurity := 0;
      LSize := SizeOf(LSecurity);
      OsCheck(WinHttpQueryOption(LRequest, WINHTTP_OPTION_SECURITY_FLAGS,
        @LSecurity, @LSize), 'Read TLS security');
      Check((LSecurity and SECURITY_FLAG_SECURE) <> 0, 'Response is not TLS');
      LPeer := nil;
      LSize := SizeOf(LPeer);
      OsCheck(WinHttpQueryOption(LRequest, WINHTTP_OPTION_SERVER_CERT_CONTEXT,
        @LPeer, @LSize), 'Read peer certificate');
      try
        Check(LPeer <> nil, 'Missing peer certificate');
        Check(CryptVerifyCertificateSignatureEx(0, $10001, 2, LPeer,
          2, FCa, 0, nil), 'Peer certificate is not signed by supplied CA');
      finally
        if LPeer <> nil then
        begin
          CertFreeCertificateContext(LPeer);
        end;
      end;
    end;
    LSize := 0;
    WinHttpQueryHeaders(LRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF, nil,
      nil, @LSize, nil);
    Check((LSize > 0) and (LSize <= 65536), 'Response headers exceed bound');
    SetLength(LRaw, (LSize + 1) div 2);
    OsCheck(WinHttpQueryHeaders(LRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF,
      nil, PWideChar(LRaw), @LSize, nil), 'Read headers');
    Result.Headers := String(PWideChar(LRaw));
    repeat
      LRead := 0;
      OsCheck(WinHttpReadData(LRequest, @LBuffer[0], SizeOf(LBuffer),
        @LRead), 'Read response');
      Check(Length(Result.Body) + Int64(LRead) <= 1048576,
        'Response exceeds 1 MiB probe bound');
      LOld := Length(Result.Body);
      SetLength(Result.Body, LOld + LRead);
      if LRead > 0 then
      begin
        Move(LBuffer[0], Result.Body[LOld], LRead);
      end;
    until LRead = 0;
  finally
    WinHttpCloseHandle(LRequest);
  end;
end;

procedure TClient.StartSession;
var
  LResponse: TResponse;
  LJson: TJSONData;
  LName: String;
  LHeaders: String;
begin
  LResponse := Get('/api/session');
  Check(LResponse.Status = 200, 'Session handshake failed');
  LJson := GetJSON(BodyText(LResponse));
  try
    Check(LJson.JSONType = jtObject, 'Session response is not an object');
    FToken := TJSONObject(LJson).Get('token', '');
    Check((Length(FToken) > 0) and (Pos(#13, FToken) = 0) and
      (Pos(#10, FToken) = 0), 'Invalid session token');
  finally
    LJson.Free;
  end;
  LName := 'pythianlisten';
  if FSecure then
  begin
    LName := LName + 'tls';
  end;
  LHeaders := LowerCase(LResponse.Headers);
  Check(Pos('set-cookie: ' + LName + '=', LHeaders) > 0,
    'Missing scheme-specific media cookie');
  Check(Pos('httponly', LHeaders) > 0, 'Cookie lacks HttpOnly');
  Check(Pos('samesite=strict', LHeaders) > 0, 'Cookie lacks SameSite Strict');
  if FSecure then
  begin
    Check(Pos('; secure', LHeaders) > 0, 'TLS cookie lacks Secure');
    Check(Pos('set-cookie: pythianlisten=', LHeaders) = 0,
      'TLS session issued the HTTP cookie');
  end
  else
  begin
    Check(Pos('set-cookie: pythianlistentls=', LHeaders) = 0,
      'HTTP session issued the TLS cookie');
    Check(Pos('; secure', LHeaders) = 0, 'HTTP cookie incorrectly Secure');
  end;
end;

function TClient.Api(const APath: String; const AHeaders: String): TResponse;
begin
  Result := Get(APath, 'X-Pythian-Token: ' + FToken + #13#10 + AHeaders);
end;

procedure ParseBase(const ABase: String; out AHost: String;
  out APort: Word; out AAuthority: String);
var
  LColon: Integer;
  LPort: Integer;
  I: Integer;
begin
  Check(Copy(ABase, 1, 7) = 'http://', 'Base URL must start http://');
  AAuthority := Copy(ABase, 8, MaxInt);
  if (Length(AAuthority) > 0) and
    (AAuthority[Length(AAuthority)] = '/') then
  begin
    Delete(AAuthority, Length(AAuthority), 1);
  end;
  LColon := Pos(':', AAuthority);
  Check(LColon > 1, 'Base URL requires explicit host:port');
  AHost := Copy(AAuthority, 1, LColon - 1);
  for I := 1 to Length(AHost) do
  begin
    Check(AHost[I] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '-'],
      'Probe requires a DNS or IPv4 host without credentials');
  end;
  for I := LColon + 1 to Length(AAuthority) do
  begin
    Check(AAuthority[I] in ['0'..'9'], 'Port must be decimal only');
  end;
  Check(TryStrToInt(Copy(AAuthority, LColon + 1, MaxInt), LPort),
    'Invalid URL port');
  Check((LPort >= 1) and (LPort <= 65535), 'URL port outside 1..65535');
  APort := LPort;
end;

procedure PublicRoutes(const AClient: TClient; const ACa: TAudioBytes);
var
  LResponse: TResponse;
  LText: String;
begin
  LResponse := AClient.Get('/phone-ca.cer');
  Check(LResponse.Status = 200, 'Public CA route failed');
  Check(SameBytes(LResponse.Body, ACa), 'Public CA bytes differ');
  Check(Sha256Bytes(LResponse.Body) = Sha256Bytes(ACa), 'CA digest differs');
  LResponse := AClient.Get('/phone-setup.html');
  Check(LResponse.Status = 200, 'Phone setup route failed');
  LText := BodyText(LResponse);
  Check(Pos('@@PYTHIAN_', LText) = 0, 'Phone setup placeholders remain');
  Check(Pos(Sha256Bytes(ACa), LowerCase(LText)) > 0,
    'Phone setup lacks actual CA fingerprint');
  Check(Pos('https://', LText) > 0, 'Phone setup lacks HTTPS URL');
  LResponse := AClient.Get('/studio.html');
  Check((LResponse.Status = 200) and (Length(LResponse.Body) > 0),
    'Studio static route failed');
end;

procedure CompareMedia(const AHttp: TClient; const AHttps: TClient;
  const APath: String);
var
  LHttp: TResponse;
  LHttps: TResponse;
begin
  { No token header: these requests must use their separate session cookies. }
  LHttp := AHttp.Get(APath, 'Range: bytes=0-63' + #13#10);
  LHttps := AHttps.Get(APath, 'Range: bytes=0-63' + #13#10);
  Check((LHttp.Status = 206) and (LHttps.Status = 206),
    'Media range did not return 206 on both transports');
  Check((Length(LHttp.Body) = 64) and SameBytes(LHttp.Body, LHttps.Body),
    'HTTP/TLS media range bytes differ');
  Check(Pos('content-range: bytes 0-63/', LowerCase(LHttps.Headers)) > 0,
    'TLS range lacks exact Content-Range');
  LHttps := AHttps.Get(APath, 'Range: bytes=invalid' + #13#10);
  Check(LHttps.Status = 416, 'Malformed TLS range was not rejected');
end;

function ListeningPath(const AClient: TClient; const AId: String): String;
var
  LResponse: TResponse;
  LJson: TJSONData;
  LRoot: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LAssets: TJSONArray;
  LGroup: String;
  I: Integer;
  J: Integer;
begin
  Result := '';
  LResponse := AClient.Api('/api/listen-queue');
  Check(LResponse.Status = 200, 'Listening queue failed');
  LJson := GetJSON(BodyText(LResponse));
  try
    Check(LJson.JSONType = jtObject, 'Listening queue is not an object');
    LRoot := TJSONObject(LJson);
    for J := 0 to 1 do
    begin
      LGroup := 'items';
      if J = 1 then
      begin
        LGroup := 'completed';
      end;
      LRows := LRoot.Arrays[LGroup];
      for I := 0 to LRows.Count - 1 do
      begin
        LRow := LRows.Objects[I];
        if LRow.Get('id', '') = AId then
        begin
          LAssets := LRow.Arrays['assets'];
          Check(LAssets.Count > 0, 'Selected listening item has no assets');
          Result := '/api/listen-audio?request=' + AId + '&asset=' +
            LAssets.Objects[0].Strings['id'] + '&packet=' +
            LRow.Strings['request_sha256'];
          Exit;
        end;
      end;
    end;
    Check(False, 'Supplied listening item is absent');
  finally
    LJson.Free;
  end;
end;

procedure SafeIdentity(const AValue: String; const AHash: Boolean);
var
  I: Integer;
begin
  Check((Length(AValue) > 0) and (Length(AValue) <= 128), 'Invalid fixture ID');
  if AHash then
  begin
    Check(Length(AValue) = 64, 'Source hash must have 64 characters');
  end;
  for I := 1 to Length(AValue) do
  begin
    if AHash then
    begin
      Check(AValue[I] in ['0'..'9', 'a'..'f'], 'Source hash is not lowercase hex');
    end
    else
    begin
      Check(AValue[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.', ':'],
        'Listening ID is not safe opaque text');
    end;
  end;
end;

function ReadySocket(const ASocket: TSocket; const AWrite: Boolean;
  const AMilliseconds: Integer): Boolean;
var
  LSet: TFDSet;
  LTimeout: TTimeVal;
  LResult: Integer;
begin
  FillChar(LSet, SizeOf(LSet), 0);
  LSet.fd_count := 1;
  LSet.fd_array[0] := ASocket;
  LTimeout.tv_sec := AMilliseconds div 1000;
  LTimeout.tv_usec := (AMilliseconds mod 1000) * 1000;
  if AWrite then
  begin
    LResult := WinSock2.select(0, nil, @LSet, nil, @LTimeout);
  end
  else
  begin
    LResult := WinSock2.select(0, @LSet, nil, nil, @LTimeout);
  end;
  Check(LResult <> SOCKET_ERROR, 'Raw socket select failed');
  Result := LResult > 0;
end;

procedure RawCase(const AHost: String; const APort: Word;
  const AKind: Integer);
const
  Names: array[0..2] of String =
    ('idle initial bytes', 'invalid TLS record length', 'incomplete ClientHello');
var
  LSocket: TSocket;
  LAddress: TSockAddrIn;
  LMode: u_long;
  LError: Integer;
  LSize: Integer;
  LPrefix: array[0..8] of Byte;
  LPrefixCount: Integer;
  LSent: Integer;
  LCount: Integer;
  LBuffer: array[0..511] of AnsiChar;
  LText: AnsiString;
  LPart: AnsiString;
  LStarted: QWord;
  LElapsed: QWord;
  LClosed: Boolean;
  LRemaining: Integer;
  LNumericHost: String;
begin
  LNumericHost := AHost;
  if SameText(LNumericHost, 'localhost') then
  begin
    LNumericHost := '127.0.0.1';
  end;
  FillChar(LAddress, SizeOf(LAddress), 0);
  LAddress.sin_family := AF_INET;
  LAddress.sin_port := htons(APort);
  LAddress.sin_addr.S_addr := inet_addr(PAnsiChar(LNumericHost));
  Check(LAddress.sin_addr.S_addr <> INADDR_NONE,
    'Raw mode requires a numeric IPv4 address or localhost');
  LStarted := GetTickCount64;
  LSocket := WinSock2.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSocket <> INVALID_SOCKET, 'Raw socket creation failed');
  try
    LMode := 1;
    Check(ioctlsocket(LSocket, LongInt(FIONBIO), LMode) = 0,
      'Raw nonblocking socket setup failed');
    LError := WinSock2.connect(LSocket, LAddress, SizeOf(LAddress));
    if LError = SOCKET_ERROR then
    begin
      Check(WSAGetLastError = WSAEWOULDBLOCK, 'Raw connect failed');
      Check(ReadySocket(LSocket, True, 1000), 'Raw connect exceeded one second');
      LError := 0;
      LSize := SizeOf(LError);
      Check(getsockopt(LSocket, SOL_SOCKET, SO_ERROR, @LError, LSize) = 0,
        'Raw connect error query failed');
      Check(LError = 0, 'Raw outbound connection rejected');
    end;
    LPrefixCount := 0;
    if AKind > 0 then
    begin
      { A TLS handshake record is deliberately invalid or incomplete.
        These are not plaintext HTTP requests and must never downgrade. }
      LPrefix[0] := 22;
      LPrefix[1] := 3;
      LPrefix[2] := 3;
      LPrefix[3] := 0;
      LPrefix[4] := 0;
      LPrefixCount := 5;
      if AKind = 2 then
      begin
        LPrefix[4] := 32;
        LPrefix[5] := 1;
        LPrefix[6] := 0;
        LPrefix[7] := 0;
        LPrefix[8] := 28;
        LPrefixCount := 9;
      end;
    end;
    LSent := 0;
    while LSent < LPrefixCount do
    begin
      Check(ReadySocket(LSocket, True, 1000), 'Raw send exceeded one second');
      LCount := WinSock2.send(LSocket, @LPrefix[LSent],
        LPrefixCount - LSent, 0);
      Check(LCount > 0, 'Raw prefix send failed');
      Inc(LSent, LCount);
    end;
    LClosed := False;
    LText := '';
    while not LClosed do
    begin
      LElapsed := GetTickCount64 - LStarted;
      Check(LElapsed < 8000, 'Raw rejection exceeded eight-second outer bound');
      LRemaining := 8000 - Integer(LElapsed);
      Check(ReadySocket(LSocket, False, LRemaining),
        'Raw connection did not terminate within eight seconds');
      LCount := WinSock2.recv(LSocket, @LBuffer[0], SizeOf(LBuffer), 0);
      if LCount = 0 then
      begin
        LClosed := True;
      end
      else if LCount = SOCKET_ERROR then
      begin
        LError := WSAGetLastError;
        Check((LError = WSAECONNRESET) or (LError = WSAECONNABORTED),
          'Unexpected raw receive failure');
        LClosed := True;
      end
      else
      begin
        Check(Length(LText) + LCount <= 4096, 'Raw failure response exceeds bound');
        SetString(LPart, @LBuffer[0], LCount);
        LText := LText + LPart;
        Check(Pos('HTTP/', UpperCase(String(LText))) = 0,
          'Invalid TLS input downgraded to an HTTP response');
      end;
    end;
    LElapsed := GetTickCount64 - LStarted;
    Check(LElapsed <= 8000, 'Raw terminal elapsed exceeds outer bound');
    if LElapsed < 1000 then
    begin
      WriteLn(Names[AKind], ': immediate rejection ', LElapsed, ' ms');
    end
    else
    begin
      WriteLn(Names[AKind], ': deadline closure ', LElapsed, ' ms');
    end;
  finally
    closesocket(LSocket);
  end;
end;

procedure RunRaw;
var
  LHost: String;
  LAuthority: String;
  LPort: Word;
  LData: TWSAData;
  LClient: TClient;
  LResponse: TResponse;
  LStarted: QWord;
  I: Integer;
begin
  Check(ParamCount = 2, 'Usage: EXE raw-failures BASE_HTTP_URL');
  ParseBase(ParamStr(2), LHost, LPort, LAuthority);
  Check(WSAStartup($0202, LData) = 0, 'Winsock initialization failed');
  try
    LStarted := GetTickCount64;
    LClient := TClient.Create(LHost, LPort, False, nil, 1000);
    try
      for I := 0 to 2 do
      begin
        RawCase(LHost, LPort, I);
        { Only outbound recovery reads, never a new listener or retry. }
        LResponse := LClient.Get('/phone-setup.html');
        Check(LResponse.Status = 200, 'HTTP setup unavailable after raw failure');
        Check(Pos('https://' + LAuthority + '/studio.html',
          BodyText(LResponse)) > 0, 'Recovery setup authority differs');
        LClient.StartSession;
        Check(GetTickCount64 - LStarted <= 30000,
          'Raw mode exceeded thirty-second total bound');
        WriteLn('HTTP setup/session recovery ', I + 1, ': PASS');
      end;
      WriteLn('PASS raw failures ', Checks, ' checks; elapsed ',
        GetTickCount64 - LStarted, ' ms');
    finally
      LClient.Free;
    end;
  finally
    WSACleanup;
  end;
end;

procedure Run;
var
  LHost: String;
  LAuthority: String;
  LPort: Word;
  LCaBytes: TAudioBytes;
  LCa: PCertificateContext;
  LHttp: TClient;
  LHttps: TClient;
  LResponse: TResponse;
  LPlainPage: TResponse;
  LPath: String;
begin
  Check(ParamCount in [2, 4],
    'Usage: EXE BASE_HTTP_URL PUBLIC_CA_DER_PATH [SOURCE_HASH LISTENING_ITEM_ID]');
  ParseBase(ParamStr(1), LHost, LPort, LAuthority);
  if ParamCount = 4 then
  begin
    SafeIdentity(ParamStr(3), True);
    SafeIdentity(ParamStr(4), False);
  end;
  LCaBytes := ReadCa(ParamStr(2));
  LCa := CertCreateCertificateContext($10001, @LCaBytes[0], Length(LCaBytes));
  OsCheck(LCa <> nil, 'Parse public CA DER');
  LHttp := nil;
  LHttps := nil;
  try
    LHttp := TClient.Create(LHost, LPort, False, LCa);
    LHttps := TClient.Create(LHost, LPort, True, LCa);
    LHttp.StartSession;
    LHttps.StartSession;
    PublicRoutes(LHttp, LCaBytes);
    PublicRoutes(LHttps, LCaBytes);
    LPlainPage := LHttp.Get('/phone-setup.html');
    LResponse := LHttps.Get('/phone-setup.html');
    Check(SameBytes(LPlainPage.Body, LResponse.Body),
      'HTTP/TLS public setup page bytes differ');
    Check(Pos('https://' + LAuthority + '/studio.html',
      BodyText(LResponse)) > 0, 'Setup page HTTPS authority differs');
    LResponse := LHttps.Api('/api/studio/sources',
      'Origin: https://' + LAuthority + #13#10);
    Check(LResponse.Status = 200, 'Same-origin HTTPS API rejected');
    LResponse := LHttps.Api('/api/studio/sources',
      'Origin: http://' + LAuthority + #13#10);
    Check(LResponse.Status = 403, 'HTTP origin accepted on TLS');
    LResponse := LHttps.Api('/api/studio/sources',
      'Host: wrong.invalid:' + IntToStr(LPort) + #13#10);
    Check(LResponse.Status = 403, 'Wrong Host accepted on TLS');
    LResponse := LHttp.Api('/api/studio/sources',
      'Origin: http://' + LAuthority + #13#10);
    Check(LResponse.Status = 200, 'Retained HTTP API rejected');
    if ParamCount = 4 then
    begin
      CompareMedia(LHttp, LHttps,
        '/api/studio/source-audio?hash=' + ParamStr(3));
      LPath := ListeningPath(LHttps, ParamStr(4));
      CompareMedia(LHttp, LHttps, LPath);
    end;
    WriteLn('PASS ', Checks, ' checks; OS-trusted TLS 1.2 and public routes');
    if ParamCount = 2 then
    begin
      WriteLn('Media checks NOT RUN: optional fixture arguments absent');
    end;
  finally
    LHttps.Free;
    LHttp.Free;
    CertFreeCertificateContext(LCa);
  end;
end;

begin
  try
    if ParamStr(1) = 'raw-failures' then
    begin
      RunRaw;
    end
    else
    begin
      Run;
    end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
