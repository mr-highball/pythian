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
unit pythian.tools.annotations.sourceguard;

{$mode delphi}
{$H+}

interface

{ On Windows, a verified read handle is kept open with write and delete sharing
  denied. Every reuse checks the path's file identity and timestamp against that
  handle. The bounded media sender can verify concurrently with HTTP requests,
  so access to the shared guard table is serialized. Other hosts hash each edit. }
procedure VerifyGuardedSource(const APath, AExpectedHash: String;
  const AExpectedBytes: Int64);

implementation

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.hash
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

const
  CMaximumGuards = 32;

type
  TGuard = record
    Path: String;
    Hash: String;
    Bytes: Int64;
    Stream: TFileStream;
    LastUse: QWord;
    {$IFDEF MSWINDOWS}
    Info: TByHandleFileInformation;
    {$ENDIF}
  end;

var
  GGuards: array[0..CMaximumGuards - 1] of TGuard;
  GUseCount: QWord;
  GGuardLock: TRTLCriticalSection;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EAudio.Create(AMessage);
end;

{$IFDEF MSWINDOWS}
function FileInfo(const AStream: TFileStream): TByHandleFileInformation;
begin
  Need(GetFileInformationByHandle(THandle(AStream.Handle), Result),
    'Could not inspect catalog source identity');
end;

function SameFileInfo(const ALeft, ARight: TByHandleFileInformation): Boolean;
begin
  Result := (ALeft.dwVolumeSerialNumber = ARight.dwVolumeSerialNumber) and
    (ALeft.nFileIndexHigh = ARight.nFileIndexHigh) and
    (ALeft.nFileIndexLow = ARight.nFileIndexLow) and
    (ALeft.nFileSizeHigh = ARight.nFileSizeHigh) and
    (ALeft.nFileSizeLow = ARight.nFileSizeLow) and
    (ALeft.ftLastWriteTime.dwHighDateTime =
      ARight.ftLastWriteTime.dwHighDateTime) and
    (ALeft.ftLastWriteTime.dwLowDateTime =
      ARight.ftLastWriteTime.dwLowDateTime);
end;

function GuardSlot(const APath, AHash: String;
  const ABytes: Int64): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(GGuards) do
    if (GGuards[LIndex].Stream <> nil) and
      (GGuards[LIndex].Path = APath) and
      (GGuards[LIndex].Hash = AHash) and
      (GGuards[LIndex].Bytes = ABytes) then
      Exit(LIndex);
  Result := -1;
end;

function ReplacementSlot: Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(GGuards) do
    if GGuards[LIndex].Stream = nil then
      Exit(LIndex);
  Result := 0;
  for LIndex := 1 to High(GGuards) do
    if GGuards[LIndex].LastUse < GGuards[Result].LastUse then
      Result := LIndex;
end;
{$ENDIF}

procedure VerifyGuardedSourceLocked(const APath, AExpectedHash: String;
  const AExpectedBytes: Int64); forward;

procedure VerifyGuardedSource(const APath, AExpectedHash: String;
  const AExpectedBytes: Int64);
begin
  EnterCriticalSection(GGuardLock);
  try
    VerifyGuardedSourceLocked(APath, AExpectedHash, AExpectedBytes);
  finally
    LeaveCriticalSection(GGuardLock);
  end;
end;

procedure VerifyGuardedSourceLocked(const APath, AExpectedHash: String;
  const AExpectedBytes: Int64);
var
  LPath: String;
  LStream: TFileStream;
  {$IFDEF MSWINDOWS}
  LSlot: Integer;
  LBefore: TByHandleFileInformation;
  LAfter: TByHandleFileInformation;
  {$ENDIF}
begin
  Need(AExpectedBytes >= 0, 'Invalid catalog source byte count');
  LPath := ExpandFileName(APath);
  {$IFDEF MSWINDOWS}
  LSlot := GuardSlot(LPath, AExpectedHash, AExpectedBytes);
  if LSlot >= 0 then
  begin
    LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
    try
      Need((LStream.Size = AExpectedBytes) and
        SameFileInfo(GGuards[LSlot].Info, FileInfo(LStream)) and
        SameFileInfo(GGuards[LSlot].Info, FileInfo(GGuards[LSlot].Stream)),
        'Catalog source identity changed after verification');
    finally
      LStream.Free;
    end;
    Inc(GUseCount);
    GGuards[LSlot].LastUse := GUseCount;
    Exit;
  end;
  {$ENDIF}
  LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    Need(LStream.Size = AExpectedBytes,
      'Catalog source byte count changed');
    {$IFDEF MSWINDOWS}
    LBefore := FileInfo(LStream);
    {$ENDIF}
    Need(Sha256Stream(LStream, LStream.Size) = AExpectedHash,
      'Catalog source SHA256 changed');
    {$IFDEF MSWINDOWS}
    LAfter := FileInfo(LStream);
    Need(SameFileInfo(LBefore, LAfter),
      'Catalog source changed while being verified');
    LSlot := ReplacementSlot;
    GGuards[LSlot].Stream.Free;
    GGuards[LSlot].Path := LPath;
    GGuards[LSlot].Hash := AExpectedHash;
    GGuards[LSlot].Bytes := AExpectedBytes;
    GGuards[LSlot].Stream := LStream;
    GGuards[LSlot].Info := LAfter;
    Inc(GUseCount);
    GGuards[LSlot].LastUse := GUseCount;
    LStream := nil;
    {$ENDIF}
  finally
    LStream.Free;
  end;
end;

var
  LIndex: Integer;

initialization
  InitCriticalSection(GGuardLock);

finalization
  for LIndex := 0 to High(GGuards) do
    GGuards[LIndex].Stream.Free;
  DoneCriticalSection(GGuardLock);

end.
