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
unit pythian.tools.net.transport;

{$mode delphi}
{$H+}

interface

uses
  SysUtils;

type
  TTransportPrefixKind = (transportNeedMore, transportHttp, transportTls,
    transportInvalid);

function TransportPrefixKind(const ABytes: array of Byte): TTransportPrefixKind;

{ TLS is a Windows tool edge, independent of the portable audio library.
  The thumbprint is the SHA1 store identifier of a CurrentUser/My leaf.
  An empty value disables TLS. Configure/shutdown require quiescent clients. }
procedure ConfigureTransportTls(const AThumbprint: String);
procedure ShutdownTransportTls;
function TransportTlsConfigured: Boolean;
procedure ValidatePublicCaDer(const ABytes: TBytes);

{ Peek without consuming HTTP. EOF, deadline or rejected negotiation raises
  EAudio. A TLS-looking connection never falls back to HTTP. The caller owns
  the socket on every outcome and must close it. }
procedure AcceptTransport(const ASocket: Integer; const AAllowTls: Boolean;
  const AHandshakeMs: Integer = 5000);
function TransportRecv(const ASocket: Integer; ABuffer: Pointer;
  const ACount: Integer): Integer;
function TransportSend(const ASocket: Integer; ABuffer: Pointer;
  const ACount: Integer): Integer;
procedure TransportClose(const ASocket: Integer);
function TransportIsTls(const ASocket: Integer): Boolean;
function TransportOriginMatches(const ASocket: Integer;
  const AHost, AOrigin: String): Boolean;

implementation

uses
  Classes,
  Sockets,
  pythian.audio
  {$IFDEF MSWINDOWS}, Windows, WinSock2, JwaSspi, JwaWinCrypt, JwaWinError{$ENDIF};

const
  CMaximumConnections = 16;
  CMaximumBuffer = 262144;
  CMaximumCaBytes = 16384;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EAudio.Create(AMessage);
end;

function TransportPrefixKind(const ABytes: array of Byte): TTransportPrefixKind;
var
  LLength: Integer;
begin
  if Length(ABytes) = 0 then
    Exit(transportNeedMore);
  if ABytes[0] in [$14, $15, $17] then
    Exit(transportInvalid);
  if ABytes[0] <> $16 then
    Exit(transportHttp);
  if Length(ABytes) < 5 then
    Exit(transportNeedMore);
  LLength := Integer(ABytes[3]) * 256 + ABytes[4];
  if (ABytes[1] <> 3) or not (ABytes[2] in [1..3]) or
    (LLength = 0) or (LLength > 18432) then
    Exit(transportInvalid);
  Result := transportTls;
end;

{$IFDEF MSWINDOWS}
{$PACKRECORDS C}
type
  TSchannelCredentials = record
    Version: DWORD;
    CertificateCount: DWORD;
    Certificates: Pointer;
    RootStore: Pointer;
    MapperCount: DWORD;
    Mappers: Pointer;
    AlgorithmCount: DWORD;
    Algorithms: Pointer;
    EnabledProtocols: DWORD;
    MinimumCipherStrength: DWORD;
    MaximumCipherStrength: DWORD;
    SessionLifespan: DWORD;
    Flags: DWORD;
    CredentialFormat: DWORD;
  end;

  TTransportConnection = class
  public
    Socket: Integer;
    Context: CtxtHandle;
    ContextPresent: Boolean;
    Sizes: SecPkgContext_StreamSizes;
    Encrypted: TBytes;
    Plain: TBytes;
    PlainOffset: Integer;
    References: Integer;
    Closing: LongInt;
    SendLock: TRTLCriticalSection;
    ReceiveLock: TRTLCriticalSection;
    constructor Create(const ASocket: Integer);
    destructor Destroy; override;
  end;

var
  GConnections: array[0..CMaximumConnections - 1] of TTransportConnection;
  GRegistryLock: TRTLCriticalSection;
  GCredential: CredHandle;
  GCredentialPresent: Boolean = False;
  GCertificate: PCCERT_CONTEXT = nil;

constructor TTransportConnection.Create(const ASocket: Integer);
begin
  inherited Create;
  Socket := ASocket;
  SecInvalidateHandle(Context);
  ContextPresent := False;
  FillChar(Sizes, SizeOf(Sizes), 0);
  PlainOffset := 0;
  References := 0;
  Closing := 0;
  InitCriticalSection(SendLock);
  InitCriticalSection(ReceiveLock);
end;

destructor TTransportConnection.Destroy;
begin
  if ContextPresent then
    DeleteSecurityContext(@Context);
  DoneCriticalSection(ReceiveLock);
  DoneCriticalSection(SendLock);
  inherited Destroy;
end;

function AcquireConnection(const ASocket: Integer): TTransportConnection;
var
  LIndex: Integer;
begin
  Result := nil;
  EnterCriticalSection(GRegistryLock);
  try
    for LIndex := 0 to High(GConnections) do
      if (GConnections[LIndex] <> nil) and
        (GConnections[LIndex].Socket = ASocket) then
      begin
        Result := GConnections[LIndex];
        Inc(Result.References);
        Break;
      end;
  finally
    LeaveCriticalSection(GRegistryLock);
  end;
end;

procedure ReleaseConnection(const AConnection: TTransportConnection);
var
  LFree: Boolean;
begin
  EnterCriticalSection(GRegistryLock);
  try
    Dec(AConnection.References);
    LFree := (AConnection.References = 0) and (AConnection.Closing <> 0);
  finally
    LeaveCriticalSection(GRegistryLock);
  end;
  if LFree then
    AConnection.Free;
end;

function RetrySocketError: Boolean;
var
  LError: Integer;
begin
  LError := WSAGetLastError;
  Result := (LError = WSAEWOULDBLOCK) or (LError = WSAETIMEDOUT) or
    (LError = WSAEINTR);
end;

function RawSendAll(const AConnection: TTransportConnection;
  const ABuffer: Pointer; const ACount: Integer; const ADeadline: QWord): Boolean;
var
  LOffset: Integer;
  LSent: Integer;
begin
  Result := False;
  LOffset := 0;
  while LOffset < ACount do
  begin
    if (AConnection.Closing <> 0) or (GetTickCount64 >= ADeadline) then
      Exit;
    LSent := fpSend(AConnection.Socket, PByte(ABuffer) + LOffset,
      ACount - LOffset, 0);
    if LSent = 0 then
      Exit;
    if LSent < 0 then
    begin
      if not RetrySocketError then
        Exit;
      Continue;
    end;
    Inc(LOffset, LSent);
  end;
  Result := True;
end;

function ReadEncrypted(const AConnection: TTransportConnection): Integer;
var
  LBuffer: array[0..16383] of Byte;
  LOldCount: Integer;
begin
  if AConnection.Closing <> 0 then
  begin
    WSASetLastError(WSAECONNRESET);
    Exit(-1);
  end;
  Result := fpRecv(AConnection.Socket, @LBuffer[0], SizeOf(LBuffer), 0);
  if Result > 0 then
  begin
    LOldCount := Length(AConnection.Encrypted);
    Need(LOldCount + Result <= CMaximumBuffer, 'TLS record buffer exceeds bound');
    SetLength(AConnection.Encrypted, LOldCount + Result);
    Move(LBuffer[0], AConnection.Encrypted[LOldCount], Result);
  end
  else if (Result < 0) and RetrySocketError then
    WSASetLastError(WSAEWOULDBLOCK);
end;

procedure RetainExtra(const AConnection: TTransportConnection;
  const AExtra: Integer);
var
  LLength: Integer;
begin
  LLength := Length(AConnection.Encrypted);
  Need((AExtra >= 0) and (AExtra <= LLength), 'Invalid TLS extra-byte count');
  if AExtra <> 0 then
    Move(AConnection.Encrypted[LLength - AExtra], AConnection.Encrypted[0], AExtra);
  SetLength(AConnection.Encrypted, AExtra);
end;

procedure Negotiate(const AConnection: TTransportConnection;
  const ADeadline: QWord);
var
  LInputBuffers: array[0..1] of SecBuffer;
  LOutput: SecBuffer;
  LInputDesc: SecBufferDesc;
  LOutputDesc: SecBufferDesc;
  LStatus: SECURITY_STATUS;
  LAttributes: DWORD;
  LExpiry: TimeStamp;
  LRead: Integer;
  LExtra: Integer;
  LContext: PCtxtHandle;
begin
  repeat
    Need(GetTickCount64 < ADeadline, 'TLS handshake deadline expired');
    if Length(AConnection.Encrypted) = 0 then
    begin
      LRead := ReadEncrypted(AConnection);
      if (LRead < 0) and RetrySocketError then
        Continue;
      Need(LRead > 0, 'TLS peer closed during handshake');
    end;
    FillChar(LInputBuffers, SizeOf(LInputBuffers), 0);
    LInputBuffers[0].BufferType := SECBUFFER_TOKEN;
    LInputBuffers[0].cbBuffer := Length(AConnection.Encrypted);
    LInputBuffers[0].pvBuffer := @AConnection.Encrypted[0];
    LInputBuffers[1].BufferType := SECBUFFER_EMPTY;
    LInputDesc.ulVersion := SECBUFFER_VERSION;
    LInputDesc.cBuffers := 2;
    LInputDesc.pBuffers := @LInputBuffers[0];
    FillChar(LOutput, SizeOf(LOutput), 0);
    LOutput.BufferType := SECBUFFER_TOKEN;
    LOutputDesc.ulVersion := SECBUFFER_VERSION;
    LOutputDesc.cBuffers := 1;
    LOutputDesc.pBuffers := @LOutput;
    if AConnection.ContextPresent then
      LContext := @AConnection.Context
    else
      LContext := nil;
    LStatus := AcceptSecurityContext(@GCredential, LContext, @LInputDesc,
      ASC_REQ_SEQUENCE_DETECT or ASC_REQ_REPLAY_DETECT or ASC_REQ_CONFIDENTIALITY or
      ASC_REQ_EXTENDED_ERROR or ASC_REQ_ALLOCATE_MEMORY or ASC_REQ_STREAM,
      SECURITY_NATIVE_DREP, @AConnection.Context, @LOutputDesc, LAttributes, @LExpiry);
    AConnection.ContextPresent := SecIsValidHandle(AConnection.Context);
    try
      if LOutput.cbBuffer <> 0 then
        Need((LOutput.cbBuffer <= CMaximumBuffer) and
          RawSendAll(AConnection, LOutput.pvBuffer, LOutput.cbBuffer, ADeadline),
          'TLS handshake response could not be sent');
    finally
      if LOutput.pvBuffer <> nil then
        FreeContextBuffer(LOutput.pvBuffer);
    end;
    if LStatus = SEC_E_INCOMPLETE_MESSAGE then
    begin
      LRead := ReadEncrypted(AConnection);
      if (LRead < 0) and RetrySocketError then
        Continue;
      Need(LRead > 0, 'TLS peer closed during partial handshake');
      Continue;
    end;
    Need((LStatus = SEC_E_OK) or (LStatus = SEC_I_CONTINUE_NEEDED),
      'TLS handshake was rejected');
    LExtra := 0;
    if LInputBuffers[1].BufferType = SECBUFFER_EXTRA then
      LExtra := LInputBuffers[1].cbBuffer;
    RetainExtra(AConnection, LExtra);
    if LStatus = SEC_E_OK then
      Break;
  until False;
  Need(QueryContextAttributesW(@AConnection.Context, SECPKG_ATTR_STREAM_SIZES,
    @AConnection.Sizes) = SEC_E_OK, 'TLS stream sizes are unavailable');
  Need((AConnection.Sizes.cbMaximumMessage > 0) and
    (AConnection.Sizes.cbMaximumMessage <= 65536) and
    (AConnection.Sizes.cbHeader + AConnection.Sizes.cbMaximumMessage +
      AConnection.Sizes.cbTrailer <= CMaximumBuffer), 'TLS stream sizes exceed bound');
end;

procedure ConfigureTransportTls(const AThumbprint: String);
var
  LStore: HCERTSTORE;
  LHash: array[0..19] of Byte;
  LBlob: CRYPT_HASH_BLOB;
  LIndex: Integer;
  LNumber: Integer;
  LCredentials: TSchannelCredentials;
  LExpiry: TimeStamp;
  LPackage: UnicodeString;
  LStatus: SECURITY_STATUS;
begin
  ShutdownTransportTls;
  if AThumbprint = '' then
    Exit;
  Need(Length(AThumbprint) = 40, 'TLS leaf thumbprint must have 40 hexadecimal digits');
  for LIndex := 0 to High(LHash) do
  begin
    Need(TryStrToInt('$' + Copy(AThumbprint, LIndex * 2 + 1, 2), LNumber),
      'TLS leaf thumbprint is not hexadecimal');
    LHash[LIndex] := LNumber;
  end;
  LStore := CertOpenStore(PAnsiChar(CERT_STORE_PROV_SYSTEM_A), 0, 0,
    CERT_SYSTEM_STORE_CURRENT_USER or CERT_STORE_OPEN_EXISTING_FLAG or
    CERT_STORE_READONLY_FLAG, PAnsiChar('MY'));
  Need(LStore <> nil, 'CurrentUser certificate store could not be opened');
  try
    try
      LBlob.cbData := SizeOf(LHash);
      LBlob.pbData := @LHash[0];
      GCertificate := CertFindCertificateInStore(LStore, X509_ASN_ENCODING,
        0, CERT_FIND_SHA1_HASH, @LBlob, nil);
      Need(GCertificate <> nil, 'Configured TLS leaf is absent from CurrentUser/My');
      Need(CertVerifyTimeValidity(nil, GCertificate.pCertInfo) = 0,
        'Configured TLS leaf is outside its validity period');
      FillChar(LCredentials, SizeOf(LCredentials), 0);
      LCredentials.Version := 4; { SCHANNEL_CRED_VERSION }
      LCredentials.CertificateCount := 1;
      LCredentials.Certificates := @GCertificate;
      LCredentials.EnabledProtocols := $00000400; { SP_PROT_TLS1_2_SERVER }
      LPackage := 'Microsoft Unified Security Protocol Provider';
      LStatus := AcquireCredentialsHandleW(nil, PWideChar(LPackage), SECPKG_CRED_INBOUND,
        nil, @LCredentials, nil, nil, @GCredential, LExpiry);
      Need(LStatus = SEC_E_OK,
        'Schannel credential acquisition failed (0x' + IntToHex(Cardinal(LStatus), 8) + ')');
      GCredentialPresent := True;
    except
      if GCertificate <> nil then
      begin
        CertFreeCertificateContext(GCertificate);
        GCertificate := nil;
      end;
      raise;
    end;
  finally
    CertCloseStore(LStore, 0);
  end;
end;

procedure ShutdownTransportTls;
var
  LIndex: Integer;
begin
  EnterCriticalSection(GRegistryLock);
  try
    for LIndex := 0 to High(GConnections) do
      Need(GConnections[LIndex] = nil, 'TLS shutdown requires closed clients');
    if GCredentialPresent then
    begin
      FreeCredentialsHandle(@GCredential);
      GCredentialPresent := False;
    end;
    if GCertificate <> nil then
    begin
      CertFreeCertificateContext(GCertificate);
      GCertificate := nil;
    end;
  finally
    LeaveCriticalSection(GRegistryLock);
  end;
end;

function TransportTlsConfigured: Boolean;
begin
  Result := GCredentialPresent;
end;

procedure ValidatePublicCaDer(const ABytes: TBytes);
var
  LCertificate: PCCERT_CONTEXT;
  LExtension: PCERT_EXTENSION;
  LConstraints: PCERT_BASIC_CONSTRAINTS2_INFO;
  LSize: DWORD;
  LIndex: Integer;
  LLength: Integer;
  LLengthBytes: Integer;
begin
  Need((Length(ABytes) >= 4) and (Length(ABytes) <= CMaximumCaBytes) and
    (ABytes[0] = $30), 'Public CA must be one bounded DER certificate');
  LLength := ABytes[1];
  LIndex := 2;
  if (LLength and $80) <> 0 then
  begin
    LLengthBytes := LLength and $7F;
    Need((LLengthBytes >= 1) and (LLengthBytes <= 2) and
      (Length(ABytes) > 2 + LLengthBytes) and (ABytes[2] <> 0),
      'Public CA DER length is invalid');
    LLength := 0;
    while LLengthBytes > 0 do
    begin
      LLength := LLength * 256 + ABytes[LIndex];
      Inc(LIndex);
      Dec(LLengthBytes);
    end;
    Need(LLength >= 128, 'Public CA DER length is not canonical');
  end;
  Need(LIndex + LLength = Length(ABytes), 'Public CA DER has trailing or missing bytes');
  LCertificate := CertCreateCertificateContext(X509_ASN_ENCODING,
    @ABytes[0], Length(ABytes));
  Need(LCertificate <> nil, 'Public CA DER certificate is malformed');
  try
    Need(CertVerifyTimeValidity(nil, LCertificate.pCertInfo) = 0,
      'Public CA is outside its validity period');
    Need(CertCompareCertificateName(X509_ASN_ENCODING,
      @LCertificate.pCertInfo.Issuer, @LCertificate.pCertInfo.Subject) and
      CryptVerifyCertificateSignatureEx(0, X509_ASN_ENCODING,
        CRYPT_VERIFY_CERT_SIGN_SUBJECT_CERT, LCertificate,
        CRYPT_VERIFY_CERT_SIGN_ISSUER_CERT, LCertificate, 0, nil),
      'Public CA is not a valid self-signed local authority');
    LExtension := CertFindExtension(PAnsiChar('2.5.29.19'),
      LCertificate.pCertInfo.cExtension, LCertificate.pCertInfo.rgExtension);
    Need(LExtension <> nil, 'Public CA lacks CA basic constraints');
    LConstraints := nil;
    LSize := 0;
    Need(CryptDecodeObjectEx(X509_ASN_ENCODING, X509_BASIC_CONSTRAINTS2,
      LExtension.Value.pbData, LExtension.Value.cbData, CRYPT_DECODE_ALLOC_FLAG,
      nil, @LConstraints, LSize), 'Public CA constraints are malformed');
    try
      Need((LConstraints <> nil) and LConstraints.fCA,
        'Public certificate is not a certificate authority');
    finally
      if LConstraints <> nil then
        LocalFree(HLOCAL(LConstraints));
    end;
    if GCertificate <> nil then
    begin
      Need(CertCompareCertificateName(X509_ASN_ENCODING,
        @GCertificate.pCertInfo.Issuer, @LCertificate.pCertInfo.Subject),
        'Public CA is not the configured TLS leaf issuer');
      Need(CryptVerifyCertificateSignatureEx(0, X509_ASN_ENCODING,
        CRYPT_VERIFY_CERT_SIGN_SUBJECT_CERT, GCertificate,
        CRYPT_VERIFY_CERT_SIGN_ISSUER_CERT, LCertificate, 0, nil),
        'Public CA does not verify the configured TLS leaf signature');
    end;
  finally
    CertFreeCertificateContext(LCertificate);
  end;
end;

procedure AcceptTransport(const ASocket: Integer; const AAllowTls: Boolean;
  const AHandshakeMs: Integer);
var
  LBytes: array[0..4] of Byte;
  LPrefix: TBytes;
  LKind: TTransportPrefixKind;
  LRead: Integer;
  LDeadline: QWord;
  LConnection: TTransportConnection;
  LIndex: Integer;
  LSlot: Integer;
begin
  Need((AHandshakeMs >= 1) and (AHandshakeMs <= 5000),
    'Transport initial/handshake deadline exceeds bound');
  LDeadline := GetTickCount64 + QWord(AHandshakeMs);
  repeat
    Need(GetTickCount64 < LDeadline, 'Transport initial-byte deadline expired');
    LRead := fpRecv(ASocket, @LBytes[0], SizeOf(LBytes), MSG_PEEK);
    Need(LRead <> 0, 'Transport peer closed before request');
    if LRead < 0 then
    begin
      Need(RetrySocketError, 'Transport initial-byte read failed');
      Continue;
    end;
    SetLength(LPrefix, LRead);
    Move(LBytes[0], LPrefix[0], LRead);
    LKind := TransportPrefixKind(LPrefix);
    if LKind = transportNeedMore then
    begin
      Sleep(1);
      Continue;
    end;
    Need(LKind <> transportInvalid, 'Invalid initial TLS record');
    Break;
  until False;
  if LKind = transportHttp then
    Exit;
  Need(AAllowTls and GCredentialPresent, 'TLS is not configured for this listener');
  LConnection := TTransportConnection.Create(ASocket);
  try
    Negotiate(LConnection, LDeadline);
    LSlot := -1;
    EnterCriticalSection(GRegistryLock);
    try
      for LIndex := 0 to High(GConnections) do
      begin
        Need((GConnections[LIndex] = nil) or
          (GConnections[LIndex].Socket <> ASocket), 'Socket is already TLS-owned');
        if (LSlot < 0) and (GConnections[LIndex] = nil) then
          LSlot := LIndex;
      end;
      Need(LSlot >= 0, 'TLS connection limit reached');
      GConnections[LSlot] := LConnection;
    finally
      LeaveCriticalSection(GRegistryLock);
    end;
    LConnection := nil;
  finally
    LConnection.Free;
  end;
end;

function TransportRecv(const ASocket: Integer; ABuffer: Pointer;
  const ACount: Integer): Integer;
var
  LConnection: TTransportConnection;
  LBuffers: array[0..3] of SecBuffer;
  LDesc: SecBufferDesc;
  LStatus: SECURITY_STATUS;
  LQuality: DWORD;
  LIndex: Integer;
  LExtra: Integer;
  LRead: Integer;
  LDeadline: QWord;
begin
  if ACount <= 0 then
    Exit(0);
  LConnection := AcquireConnection(ASocket);
  if LConnection = nil then
    Exit(fpRecv(ASocket, ABuffer, ACount, 0));
  try
    EnterCriticalSection(LConnection.ReceiveLock);
    try
      LDeadline := GetTickCount64 + 1000;
      while Length(LConnection.Plain) = LConnection.PlainOffset do
      begin
        if GetTickCount64 >= LDeadline then
        begin
          WSASetLastError(WSAEWOULDBLOCK);
          Exit(-1);
        end;
        if Length(LConnection.Encrypted) = 0 then
        begin
          LRead := ReadEncrypted(LConnection);
          if LRead <= 0 then
            Exit(LRead);
        end;
        FillChar(LBuffers, SizeOf(LBuffers), 0);
        LBuffers[0].BufferType := SECBUFFER_DATA;
        LBuffers[0].pvBuffer := @LConnection.Encrypted[0];
        LBuffers[0].cbBuffer := Length(LConnection.Encrypted);
        LDesc.ulVersion := SECBUFFER_VERSION;
        LDesc.cBuffers := 4;
        LDesc.pBuffers := @LBuffers[0];
        LQuality := 0;
        LStatus := DecryptMessage(@LConnection.Context, @LDesc, 0, LQuality);
        if LStatus = SEC_E_INCOMPLETE_MESSAGE then
        begin
          LRead := ReadEncrypted(LConnection);
          if LRead <= 0 then
            Exit(LRead);
          Continue;
        end;
        if LStatus = SEC_I_CONTEXT_EXPIRED then
          Exit(0);
        if LStatus <> SEC_E_OK then
        begin
          WSASetLastError(WSAECONNRESET);
          Exit(-1); { renegotiation/protocol errors never downgrade to plaintext }
        end;
        LExtra := 0;
        SetLength(LConnection.Plain, 0);
        LConnection.PlainOffset := 0;
        for LIndex := 0 to High(LBuffers) do
          if LBuffers[LIndex].BufferType = SECBUFFER_DATA then
          begin
            Need(LBuffers[LIndex].cbBuffer <= CMaximumBuffer,
              'TLS plaintext buffer exceeds bound');
            SetLength(LConnection.Plain, LBuffers[LIndex].cbBuffer);
            if Length(LConnection.Plain) <> 0 then
              Move(LBuffers[LIndex].pvBuffer^, LConnection.Plain[0],
                Length(LConnection.Plain));
          end
          else if LBuffers[LIndex].BufferType = SECBUFFER_EXTRA then
            LExtra := LBuffers[LIndex].cbBuffer;
        RetainExtra(LConnection, LExtra);
      end;
      Result := Length(LConnection.Plain) - LConnection.PlainOffset;
      if Result > ACount then
        Result := ACount;
      Move(LConnection.Plain[LConnection.PlainOffset], ABuffer^, Result);
      Inc(LConnection.PlainOffset, Result);
    finally
      LeaveCriticalSection(LConnection.ReceiveLock);
    end;
  finally
    ReleaseConnection(LConnection);
  end;
end;

function TransportSend(const ASocket: Integer; ABuffer: Pointer;
  const ACount: Integer): Integer;
var
  LConnection: TTransportConnection;
  LBuffers: array[0..3] of SecBuffer;
  LDesc: SecBufferDesc;
  LRecord: TBytes;
  LSize: Integer;
  LTotal: Integer;
begin
  if ACount <= 0 then
    Exit(0);
  LConnection := AcquireConnection(ASocket);
  if LConnection = nil then
    Exit(fpSend(ASocket, ABuffer, ACount,
      {$IFDEF LINUX}MSG_NOSIGNAL{$ELSE}0{$ENDIF}));
  try
    EnterCriticalSection(LConnection.SendLock);
    try
      LSize := ACount;
      if LSize > Integer(LConnection.Sizes.cbMaximumMessage) then
        LSize := LConnection.Sizes.cbMaximumMessage;
      SetLength(LRecord, LConnection.Sizes.cbHeader + LSize + LConnection.Sizes.cbTrailer);
      FillChar(LBuffers, SizeOf(LBuffers), 0);
      LBuffers[0].BufferType := SECBUFFER_STREAM_HEADER;
      LBuffers[0].cbBuffer := LConnection.Sizes.cbHeader;
      LBuffers[0].pvBuffer := @LRecord[0];
      LBuffers[1].BufferType := SECBUFFER_DATA;
      LBuffers[1].cbBuffer := LSize;
      LBuffers[1].pvBuffer := @LRecord[LBuffers[0].cbBuffer];
      Move(ABuffer^, LBuffers[1].pvBuffer^, LSize);
      LBuffers[2].BufferType := SECBUFFER_STREAM_TRAILER;
      LBuffers[2].cbBuffer := LConnection.Sizes.cbTrailer;
      LBuffers[2].pvBuffer := @LRecord[LBuffers[0].cbBuffer + LSize];
      LDesc.ulVersion := SECBUFFER_VERSION;
      LDesc.cBuffers := 4;
      LDesc.pBuffers := @LBuffers[0];
      if EncryptMessage(@LConnection.Context, 0, @LDesc, 0) <> SEC_E_OK then
      begin
        WSASetLastError(WSAECONNRESET);
        Exit(-1);
      end;
      LTotal := LBuffers[0].cbBuffer + LBuffers[1].cbBuffer + LBuffers[2].cbBuffer;
      if not RawSendAll(LConnection, @LRecord[0], LTotal, GetTickCount64 + 15000) then
      begin
        WSASetLastError(WSAECONNRESET);
        Exit(-1); { an incomplete encrypted record cannot be retried as plaintext }
      end;
      Result := LSize;
    finally
      LeaveCriticalSection(LConnection.SendLock);
    end;
  finally
    ReleaseConnection(LConnection);
  end;
end;

procedure TransportClose(const ASocket: Integer);
var
  LConnection: TTransportConnection;
  LIndex: Integer;
  LFree: Boolean;
begin
  LConnection := nil;
  LFree := False;
  EnterCriticalSection(GRegistryLock);
  try
    for LIndex := 0 to High(GConnections) do
      if (GConnections[LIndex] <> nil) and
        (GConnections[LIndex].Socket = ASocket) then
      begin
        LConnection := GConnections[LIndex];
        GConnections[LIndex] := nil;
        InterlockedExchange(LConnection.Closing, 1);
        LFree := LConnection.References = 0;
        Break;
      end;
  finally
    LeaveCriticalSection(GRegistryLock);
  end;
  CloseSocket(ASocket);
  if LFree then
    LConnection.Free;
end;

function TransportIsTls(const ASocket: Integer): Boolean;
var
  LConnection: TTransportConnection;
begin
  LConnection := AcquireConnection(ASocket);
  Result := LConnection <> nil;
  if LConnection <> nil then
    ReleaseConnection(LConnection);
end;

{$ELSE}

procedure ConfigureTransportTls(const AThumbprint: String);
begin
  Need(AThumbprint = '', 'Schannel TLS is supported only by the Windows service');
end;

procedure ShutdownTransportTls;
begin
end;

function TransportTlsConfigured: Boolean;
begin
  Result := False;
end;

procedure ValidatePublicCaDer(const ABytes: TBytes);
begin
  raise EAudio.Create('Phone certificate setup is supported only by the Windows service');
end;

procedure AcceptTransport(const ASocket: Integer; const AAllowTls: Boolean;
  const AHandshakeMs: Integer);
begin
  Need(not AAllowTls, 'Schannel TLS is supported only by the Windows service');
end;

function TransportRecv(const ASocket: Integer; ABuffer: Pointer;
  const ACount: Integer): Integer;
begin
  if ACount <= 0 then
    Exit(0);
  Result := fpRecv(ASocket, ABuffer, ACount, 0);
end;

function TransportSend(const ASocket: Integer; ABuffer: Pointer;
  const ACount: Integer): Integer;
begin
  if ACount <= 0 then
    Exit(0);
  Result := fpSend(ASocket, ABuffer, ACount,
    {$IFDEF LINUX}MSG_NOSIGNAL{$ELSE}0{$ENDIF});
end;

procedure TransportClose(const ASocket: Integer);
begin
  CloseSocket(ASocket);
end;

function TransportIsTls(const ASocket: Integer): Boolean;
begin
  Result := False;
end;
{$ENDIF}

function TransportOriginMatches(const ASocket: Integer;
  const AHost, AOrigin: String): Boolean;
var
  LScheme: String;
begin
  if TransportIsTls(ASocket) then
    LScheme := 'https://'
  else
    LScheme := 'http://';
  Result := (AOrigin = '') or (AOrigin = LScheme + AHost);
end;

initialization
  {$IFDEF MSWINDOWS}
  InitCriticalSection(GRegistryLock);
  {$ENDIF}
finalization
  {$IFDEF MSWINDOWS}
  ShutdownTransportTls;
  DoneCriticalSection(GRegistryLock);
  {$ENDIF}
end.
