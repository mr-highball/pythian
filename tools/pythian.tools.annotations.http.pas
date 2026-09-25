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
  pinned WFC wfc_serve_http reference; this owner serves catalog APIs only. }
procedure RunCatalogHttp(const AInboxRoot, ACatalogRoot,
  ABindAddress: String; const APort, AMaximumRequests: Integer);

implementation

uses
  Classes,
  SysUtils,
  Math,
  Sockets,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.media,
  pythian.tools.annotations.proposal,
  pythian.tools.annotations.review
  {$IFDEF MSWINDOWS}, Windows{$ELSE}, BaseUnix{$ENDIF};

const
  CMaximumHeaderBytes = 16384;
  CMaximumBodyBytes = 16384;
  CMaximumTargetBytes = 2048;
  CMaximumJsonResponseBytes = 8388608;
  CReceiveDeadlineMs = 5000;
  CSendDeadlineMs = 15000;
  CSocketBlockBytes = 65536;

type
  TCatalogHttpRequest = record
    Method: String;
    Path: String;
    Query: String;
    Host: String;
    Origin: String;
    ContentType: String;
    Token: String;
    Body: String;
  end;

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
    400: Result := 'Bad Request';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    408: Result := 'Request Timeout';
    409: Result := 'Conflict';
    413: Result := 'Content Too Large';
    422: Result := 'Unprocessable Content';
    431: Result := 'Request Header Fields Too Large';
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
    LSent := fpSend(ASocket, LPointer + LOffset, ACount - LOffset,
      {$IFDEF LINUX}MSG_NOSIGNAL{$ELSE}0{$ENDIF});
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
  const AContentType, ABody: String);
var
  LHeader: String;
begin
  LHeader := 'HTTP/1.1 ' + IntToStr(AStatus) + ' ' +
    StatusReason(AStatus) + #13#10 +
    'Content-Type: ' + AContentType + #13#10 +
    'Content-Length: ' + IntToStr(Length(ABody)) + #13#10 +
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

function ParseHeaders(const AHeaderText, ABindAddress: String;
  const APort: Integer;
  out ARequest: TCatalogHttpRequest; out AContentLength: Integer): Integer;
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
begin
  ARequest := Default(TCatalogHttpRequest);
  AContentLength := 0;
  Result := 400;
  for LIndex := 1 to Length(AHeaderText) do
  begin
    if not (AHeaderText[LIndex] in [#13, #10, #32..#126]) then
    begin
      Exit;
    end;
  end;
  LBreak := Pos(#13#10, AHeaderText);
  if LBreak < 1 then
  begin
    Exit;
  end;
  LLine := Copy(AHeaderText, 1, LBreak - 1);
  LFirstSpace := Pos(' ', LLine);
  if LFirstSpace < 2 then
  begin
    Exit;
  end;
  LSecondSpace := Pos(' ', Copy(LLine, LFirstSpace + 1, MaxInt));
  if LSecondSpace < 2 then
  begin
    Exit;
  end;
  Inc(LSecondSpace, LFirstSpace);
  ARequest.Method := Copy(LLine, 1, LFirstSpace - 1);
  LTarget := Copy(LLine, LFirstSpace + 1,
    LSecondSpace - LFirstSpace - 1);
  if (Copy(LLine, LSecondSpace + 1, MaxInt) <> 'HTTP/1.1') or
    (Length(LTarget) < 1) or (Length(LTarget) > CMaximumTargetBytes) or
    (LTarget[1] <> '/') or (Pos('%', LTarget) > 0) or
    (Pos('\', LTarget) > 0) or (Pos('#', LTarget) > 0) then
  begin
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
  LStart := LBreak + 2;
  LContentLengthText := '';
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
    Exit;
  end;
  if (ARequest.Origin <> '') and
    (ARequest.Origin <> 'http://' + ARequest.Host) then
  begin
    Result := 403;
    Exit;
  end;
  if (ARequest.Method <> 'GET') and (ARequest.Method <> 'POST') then
  begin
    Result := 405;
    Exit;
  end;
  if ARequest.Method = 'POST' then
  begin
    if (LContentLengthText = '') or
      not TryStrToInt(LContentLengthText, AContentLength) or
      (AContentLength < 1) or (AContentLength > CMaximumBodyBytes) then
    begin
      Result := 413;
      Exit;
    end;
    if (ARequest.ContentType <> 'application/json') and
      (ARequest.ContentType <> 'application/json; charset=utf-8') then
    begin
      Exit;
    end;
  end
  else if LContentLengthText <> '' then
  begin
    if not TryStrToInt(LContentLengthText, AContentLength) or
      (AContentLength <> 0) then
    begin
      Exit;
    end;
  end;
  Result := 200;
end;

function ReadRequest(const ASocket, APort: Integer;
  const ABindAddress: String;
  out ARequest: TCatalogHttpRequest): Integer;
var
  LRaw: String;
  LHeader: String;
  LBuffer: array[0..1023] of Char;
  LReceived: Integer;
  LSeparator: Integer;
  LContentLength: Integer;
  LBodyStart: Integer;
  LStart: QWord;
begin
  LRaw := '';
  LStart := GetTickCount64;
  repeat
    if GetTickCount64 - LStart >= CReceiveDeadlineMs then
    begin
      Exit(408);
    end;
    LReceived := fpRecv(ASocket, @LBuffer[0], SizeOf(LBuffer), 0);
    if LReceived < 0 then
    begin
      Continue;
    end;
    if LReceived = 0 then
    begin
      Exit(400);
    end;
    if LReceived > CMaximumHeaderBytes + CMaximumBodyBytes - Length(LRaw) then
    begin
      Exit(413);
    end;
    SetLength(LRaw, Length(LRaw) + LReceived);
    Move(LBuffer[0], LRaw[Length(LRaw) - LReceived + 1], LReceived);
    LSeparator := Pos(#13#10#13#10, LRaw);
    if (LSeparator = 0) and (Length(LRaw) > CMaximumHeaderBytes) then
    begin
      Exit(431);
    end;
  until LSeparator > 0;
  if LSeparator - 1 > CMaximumHeaderBytes then
  begin
    Exit(431);
  end;
  LHeader := Copy(LRaw, 1, LSeparator - 1);
  Result := ParseHeaders(LHeader, ABindAddress, APort,
    ARequest, LContentLength);
  if Result <> 200 then
  begin
    Exit;
  end;
  LBodyStart := LSeparator + 4;
  ARequest.Body := Copy(LRaw, LBodyStart, MaxInt);
  if Length(ARequest.Body) > LContentLength then
  begin
    SetLength(ARequest.Body, LContentLength);
  end;
  while Length(ARequest.Body) < LContentLength do
  begin
    if GetTickCount64 - LStart >= CReceiveDeadlineMs then
    begin
      Exit(408);
    end;
    LReceived := fpRecv(ASocket, @LBuffer[0],
      Min(SizeOf(LBuffer), LContentLength - Length(ARequest.Body)), 0);
    if LReceived < 0 then
    begin
      Continue;
    end;
    if LReceived = 0 then
    begin
      Exit(400);
    end;
    SetLength(ARequest.Body, Length(ARequest.Body) + LReceived);
    Move(LBuffer[0], ARequest.Body[Length(ARequest.Body) - LReceived + 1],
      LReceived);
  end;
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
    Need(AQuery[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '=', '&', '-', '_'],
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

procedure SendJson(const ASocket: Integer; const AJson: TJSONObject);
var
  LText: String;
begin
  LText := AJson.AsJSON + LineEnding;
  Need(Length(LText) <= CMaximumJsonResponseBytes,
    'JSON response exceeds bound');
  SendResponse(ASocket, 200, 'application/json; charset=utf-8', LText);
end;

function ParseBodyObject(const ABody: String): TJSONObject;
var
  LData: TJSONData;
begin
  LData := GetJSON(ABody);
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Expected JSON request object');
  end;
  Result := TJSONObject(LData);
end;

procedure HandleRoute(const ASocket: Integer;
  const ARequest: TCatalogHttpRequest;
  const AInboxRoot, ACatalogRoot, AToken, AAccessKey: String);
var
  LReport: TJSONObject;
  LBody: TJSONObject;
  LAudio: TMemoryStream;
  LHash: String;
begin
  if not ((ARequest.Path = '/api/session') and
    (ARequest.Method = 'POST')) and (AAccessKey <> '') then
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
    end
    else if (ARequest.Method = 'GET') and
      (ARequest.Path = '/api/catalog') then
    begin
      LReport := ListLabelCatalog(ACatalogRoot);
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
      (ARequest.Path = '/api/audio') then
    begin
      LAudio := TMemoryStream.Create;
      try
        LHash := QueryValue(ARequest.Query, 'hash');
        WriteCatalogAudioRegion(ACatalogRoot, LHash,
          QueryInt64(ARequest.Query, 'start'),
          QueryInt64(ARequest.Query, 'end'), LAudio);
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
      (ARequest.Path = '/api/review') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      LReport := CommitCatalogReview(ACatalogRoot, LBody);
    end
    else if (ARequest.Method = 'POST') and
      (ARequest.Path = '/api/propose-beats') then
    begin
      LBody := ParseBodyObject(ARequest.Body);
      LHash := LBody.Strings['source_sha256'];
      LReport := PublishCatalogBeatProposals(ACatalogRoot, LHash,
        LBody.Int64s['start_frame'], LBody.Int64s['end_frame']);
    end
    else
    begin
      SendResponse(ASocket, 404, 'text/plain; charset=utf-8',
        'Not Found'#10);
      Exit;
    end;
    SendJson(ASocket, LReport);
  finally
    LBody.Free;
    LReport.Free;
  end;
end;

procedure HandleClient(const ASocket, APort: Integer;
  const AInboxRoot, ACatalogRoot, ABindAddress, AToken,
    AAccessKey: String);
var
  LRequest: TCatalogHttpRequest;
  LStatus: Integer;
begin
  SetClientTimeouts(ASocket);
  LStatus := ReadRequest(ASocket, APort, ABindAddress, LRequest);
  if LStatus <> 200 then
  begin
    SendResponse(ASocket, LStatus, 'text/plain; charset=utf-8',
      StatusReason(LStatus) + #10);
    Exit;
  end;
  try
    HandleRoute(ASocket, LRequest, AInboxRoot, ACatalogRoot,
      AToken, AAccessKey);
  except
    on LError: Exception do
    begin
      if Pos('revision conflict', LowerCase(LError.Message)) > 0 then
      begin
        LStatus := 409;
      end
      else if (Pos('session token', LowerCase(LError.Message)) > 0) or
        (Pos('access key', LowerCase(LError.Message)) > 0) then
      begin
        LStatus := 403;
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

procedure RunCatalogHttp(const AInboxRoot, ACatalogRoot,
  ABindAddress: String; const APort, AMaximumRequests: Integer);
var
  LListener: Integer;
  LClient: Integer;
  LAddress: TInetSockAddr;
  LCount: Integer;
  LGuid: TGUID;
  LToken: String;
  LAccessKey: String;
begin
  Need(ValidBindAddress(ABindAddress),
    'Bind address must be loopback or a private LAN IPv4 address');
  Need((APort > 0) and (APort <= 65535), 'Invalid HTTP port');
  Need(AMaximumRequests >= 0, 'Invalid maximum HTTP request count');
  Need(DirectoryExists(AInboxRoot) and
    FileExists(IncludeTrailingPathDelimiter(AInboxRoot) + 'manifest.json'),
    'Configured inbox manifest does not exist');
  Need(DirectoryExists(IncludeTrailingPathDelimiter(ACatalogRoot) + 'tracks'),
    'Configured catalog does not exist');
  LAccessKey := '';
  if ABindAddress <> '127.0.0.1' then
  begin
    LAccessKey := SysUtils.GetEnvironmentVariable(
      'PYTHIAN_CATALOG_ACCESS_KEY');
    Need(Length(LAccessKey) >= 16,
      'LAN mode requires PYTHIAN_CATALOG_ACCESS_KEY of at least 16 characters');
  end;
  Need(CreateGUID(LGuid) = 0, 'Could not create HTTP session token');
  LToken := GUIDToString(LGuid);
  LListener := fpSocket(AF_INET, SOCK_STREAM, 0);
  Need(LListener >= 0, 'Could not create HTTP listener');
  try
    FillChar(LAddress, SizeOf(LAddress), 0);
    LAddress.sin_family := AF_INET;
    LAddress.sin_port := htons(Word(APort));
    LAddress.sin_addr := StrToNetAddr(ABindAddress);
    Need(fpBind(LListener, @LAddress, SizeOf(LAddress)) = 0,
      'Could not bind catalog HTTP listener');
    Need(fpListen(LListener, 8) = 0, 'Could not listen on catalog address');
    WriteLn('Pythian catalog API: http://', ABindAddress, ':',
      APort, '/api/session');
    Flush(Output);
    LCount := 0;
    while (AMaximumRequests = 0) or (LCount < AMaximumRequests) do
    begin
      LClient := fpAccept(LListener, nil, nil);
      Need(LClient >= 0, 'HTTP listener accept failed');
      try
        try
          HandleClient(LClient, APort, AInboxRoot, ACatalogRoot,
            ABindAddress, LToken, LAccessKey);
        except
          on LError: Exception do
          begin
            WriteLn(StdErr, 'HTTP connection closed: ', LError.Message);
          end;
        end;
      finally
        CloseSocket(LClient);
      end;
      Inc(LCount);
    end;
  finally
    CloseSocket(LListener);
  end;
end;

end.
