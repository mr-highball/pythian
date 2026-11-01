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
program PythianHttpAdmissionChecks;
{$mode delphi}
{$H+}
uses Classes, SysUtils, Sockets, fphttpclient
  {$IFDEF MSWINDOWS}, WinSock2{$ELSE}, BaseUnix{$ENDIF};
var GChecks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin Inc(GChecks); if not AValue then raise Exception.Create(AMessage) end;
procedure Run(const APort: Integer);
var LClient: TFPHTTPClient; LIdle: array[0..39] of Integer; LAddress: TInetSockAddr;
  LSet: TFDSet; LWait: TTimeVal; LReady, I, N, LBatch: Integer;
  LBase, LText: String; LStarted: QWord; LByte: Byte;
begin
  Check((APort > 0) and (APort <= 65535), 'Use an explicit isolated QA port');
  LBase := 'http://127.0.0.1:' + IntToStr(APort);
  LClient := TFPHTTPClient.Create(nil);
  for I := 0 to High(LIdle) do LIdle[I] := -1;
  try
    LClient.ConnectTimeout := 3000; LClient.IOTimeout := 3000;
    LClient.Get(LBase + '/api/session');
    Check(LClient.ResponseStatusCode = 200, 'Actual isolated service is ready');
    FillChar(LAddress, SizeOf(LAddress), 0);
    LAddress.sin_family := AF_INET; LAddress.sin_port := htons(APort);
    LAddress.sin_addr := StrToNetAddr('127.0.0.1');
    for LBatch := 0 to 1 do
    begin
      N := 4; if LBatch = 1 then N := Length(LIdle);
      for I := 0 to N - 1 do
      begin
        LIdle[I] := fpSocket(AF_INET, SOCK_STREAM, 0);
        Check(LIdle[I] >= 0, 'Create browser-like reserved socket');
        Check(fpConnect(LIdle[I], @LAddress, SizeOf(LAddress)) = 0, 'Connect without sending a request');
      end;
      LStarted := GetTickCount64;
      LText := LClient.Get(LBase + '/api/session');
      Check((LClient.ResponseStatusCode = 200) and (Pos('token', LText) > 0),
        'Ready API request survives multiple idle preconnections');
      Check(GetTickCount64 - LStarted < 3000, 'Idle sockets do not consume first-byte deadlines serially');
      WriteLn('Ready request with ', N, ' idle sockets: ', GetTickCount64 - LStarted, ' ms');
      if LBatch = 0 then
      begin
        Sleep(5500);
        for I := 0 to N - 1 do
        begin
          {$IFDEF MSWINDOWS}FD_ZERO(LSet); FD_SET(LIdle[I], LSet);
          {$ELSE}fpFD_ZERO(LSet); fpFD_SET(LIdle[I], LSet);{$ENDIF}
          LWait.tv_sec := 0; LWait.tv_usec := 200000;
          {$IFDEF MSWINDOWS}LReady := WinSock2.select(0, @LSet, nil, nil, @LWait);
          {$ELSE}LReady := fpSelect(LIdle[I] + 1, @LSet, nil, nil, @LWait);{$ENDIF}
          Check(LReady > 0, 'Idle admission expires without another request');
          Check(fpRecv(LIdle[I], @LByte, 1, 0) <= 0, 'Expired idle socket is closed');
        end;
      end;
      for I := 0 to N - 1 do begin CloseSocket(LIdle[I]); LIdle[I] := -1 end;
    end;
    LClient.Get(LBase + '/studio.html');
    Check(LClient.ResponseStatusCode = 200, 'Studio still loads after admission pressure');
  finally
    for I := 0 to High(LIdle) do if LIdle[I] >= 0 then CloseSocket(LIdle[I]);
    LClient.Free;
  end;
end;
begin
  try
    if ParamCount <> 1 then raise Exception.Create('Usage: HTTP admission checks QA_PORT');
    Run(StrToInt(ParamStr(1)));
    WriteLn('PASS ', GChecks, ' native HTTP admission checks');
  except on E: Exception do begin WriteLn(StdErr, 'FAIL: ', E.ClassName, ': ', E.Message); ExitCode := 1 end end;
end.
