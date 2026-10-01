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
program pythian_tests_net_transport;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.tools.net.transport;

var
  GChecks: Integer = 0;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
    raise EAudio.Create('Conformance: ' + AMessage);
  Inc(GChecks);
end;

procedure RejectDer(const ABytes: TBytes);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ValidatePublicCaDer(ABytes);
  except
    on LError: EAudio do
      LRejected := True;
  end;
  Check(LRejected, 'invalid public certificate must reject');
end;

procedure TestPortablePolicy;
var
  LByte: Byte;
  LBytes: TBytes;
  LRejected: Boolean;
begin
  ConfigureTransportTls('');
  Check(not TransportTlsConfigured, 'empty configuration preserves plain HTTP');
  Check(TransportPrefixKind([]) = transportNeedMore, 'empty prefix awaits input');
  Check(TransportPrefixKind([$47]) = transportHttp, 'GET is HTTP without consuming input');
  Check(TransportPrefixKind([$50, $4F, $53, $54]) = transportHttp, 'POST is HTTP');
  Check(TransportPrefixKind([$48, $45, $41, $44]) = transportHttp, 'HEAD is HTTP');
  Check(TransportPrefixKind([$16]) = transportNeedMore, 'partial TLS record header');
  Check(TransportPrefixKind([$16, 3, 1, 0]) = transportNeedMore, 'four-byte TLS prefix');
  Check(TransportPrefixKind([$16, 3, 1, 0, 1]) = transportTls, 'ClientHello legacy version');
  Check(TransportPrefixKind([$16, 3, 3, $48, 0]) = transportTls, 'bounded TLS record');
  Check(TransportPrefixKind([$16, 3, 3, $48, 1]) = transportInvalid, 'oversized TLS record');
  Check(TransportPrefixKind([$16, 3, 3, 0, 0]) = transportInvalid, 'zero-length TLS record');
  Check(TransportPrefixKind([$16, 2, 3, 0, 1]) = transportInvalid, 'invalid record major');
  Check(TransportPrefixKind([$16, 3, 0, 0, 1]) = transportInvalid, 'SSL3 initial record');
  Check(TransportPrefixKind([$16, 3, 4, 0, 1]) = transportInvalid, 'unsupported record version');
  Check(TransportPrefixKind([$14]) = transportInvalid, 'initial change-cipher is not HTTP');
  Check(TransportPrefixKind([$15]) = transportInvalid, 'initial alert is not HTTP');
  Check(TransportPrefixKind([$17]) = transportInvalid, 'initial encrypted data is not HTTP');
  Check(not TransportIsTls(-1), 'unknown socket has no TLS ownership');
  Check(TransportOriginMatches(-1, 'example:123', ''), 'optional origin retained');
  Check(TransportOriginMatches(-1, 'example:123', 'http://example:123'),
    'plain origin remains exact');
  Check(not TransportOriginMatches(-1, 'example:123', 'https://example:123'),
    'TLS origin cannot be claimed on plain socket');
  Check(not TransportOriginMatches(-1, 'example:123', 'http://different:123'),
    'different authority rejects');
  Check(not TransportOriginMatches(-1, 'example:123', 'http://example:123/'),
    'path is not an origin');
  Check(not TransportOriginMatches(-1, 'example:123', 'null'), 'opaque origin rejects');
  LByte := 0;
  Check(TransportSend(-1, @LByte, 0) = 0, 'zero-byte send does no socket work');
  Check(TransportRecv(-1, @LByte, 0) = 0, 'zero-byte receive does no socket work');
  LRejected := False;
  try
    ConfigureTransportTls('not-a-thumbprint');
  except
    on LError: EAudio do
      LRejected := True;
  end;
  Check(LRejected and not TransportTlsConfigured, 'malformed configuration fails closed');
  SetLength(LBytes, 0);
  RejectDer(LBytes);
  SetLength(LBytes, 4);
  LBytes[0] := $30;
  LBytes[1] := $80;
  LBytes[2] := 0;
  LBytes[3] := 0;
  RejectDer(LBytes);
  SetLength(LBytes, 16385);
  RejectDer(LBytes);
  {$IFNDEF MSWINDOWS}
  LRejected := False;
  try
    AcceptTransport(-1, True);
  except
    on LError: EAudio do
      LRejected := True;
  end;
  Check(LRejected, 'non-Windows TLS is explicit unsupported');
  {$ENDIF}
  ShutdownTransportTls;
  Check(not TransportTlsConfigured, 'shutdown is repeatable without clients');
end;

procedure TestWindowsCertificate(const AThumbprint, AFileName: String);
var
  LInput: TFileStream;
  LBytes: TBytes;
  LCorrupt: TBytes;
  LLong: TBytes;
begin
  {$IFNDEF MSWINDOWS}
  raise EAudio.Create('Certificate validation mode is Windows-only');
  {$ENDIF}
  LInput := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Check((LInput.Size >= 4) and (LInput.Size <= 16384), 'bounded certificate fixture');
    SetLength(LBytes, LInput.Size);
    LInput.ReadBuffer(LBytes[0], Length(LBytes));
  finally
    LInput.Free;
  end;
  ConfigureTransportTls(AThumbprint);
  try
    Check(TransportTlsConfigured, 'prepared leaf acquires native credentials');
    ValidatePublicCaDer(LBytes);
    Check(True, 'public CA validates actual configured leaf signature');
    LCorrupt := Copy(LBytes, 0, Length(LBytes));
    LCorrupt[High(LCorrupt)] := LCorrupt[High(LCorrupt)] xor 1;
    RejectDer(LCorrupt);
    LLong := Copy(LBytes, 0, Length(LBytes));
    SetLength(LLong, Length(LLong) + 1);
    LLong[High(LLong)] := 0;
    RejectDer(LLong);
    LLong := Copy(LBytes, 0, Length(LBytes) - 1);
    RejectDer(LLong);
  finally
    ShutdownTransportTls;
  end;
  Check(not TransportTlsConfigured, 'native credential cleanup completes');
end;

begin
  try
    if not (ParamCount in [0, 2]) then
      raise EAudio.Create('Usage: transport-test [LEAF_THUMBPRINT PUBLIC_CA_DER]');
    TestPortablePolicy;
    if ParamCount = 2 then
      TestWindowsCertificate(ParamStr(1), ParamStr(2));
    WriteLn('PASS ', GChecks, ' transport assertions; no listener or network opened');
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
