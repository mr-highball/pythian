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
program pythian_tests_text_utf8;

{$mode delphi}{$H+}

uses SysUtils, pythian.audio, pythian.progress, pythian.text, pythian.hash;

type
  TObserver = class
  public
    Stage: String;
    Point: Integer;
    Enabled: Boolean;
    Marker: Exception;
    Calls: Integer;
    LastTotal: Int64;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GText: TScalarText;
  GBytes: TAudioBytes;
  GObserver: TObserver;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise Exception.Create(AMessage);
end;

function SameBytes(const ALeft, ARight: array of Byte): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then Exit(False);
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then Exit(False);
  Result := True;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LMatch: Boolean;
begin
  Inc(Calls);
  Check((AWork.Units = wuBytes) and (AWork.Pass = 0) and
    (AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Invalid text byte work');
  if AWork.Total > 0 then LastTotal := AWork.Total;
  LMatch := ((Point = 0) and (AWork.Done = 0)) or
    ((Point = 1) and (AWork.Done > 0) and
      ((AWork.Total = 0) or (AWork.Done < AWork.Total))) or
    ((Point = 2) and (AWork.Total > 0) and (AWork.Done = AWork.Total));
  if Enabled and (AWork.Stage = Stage) and LMatch then raise Marker;
end;

function ForwardEncode: TAudioBytes;
begin
  Result := EncodeUTF8Text(GText, Length(GBytes), True, True, GObserver.Observe);
end;

function ForwardDecode: TScalarText;
begin
  Result := DecodeUTF8Text(GBytes, Length(GBytes), True, True, GObserver.Observe);
end;

procedure LiteralCases;
const
  Expected: array[0..14] of Byte = (0, 65, $C2, $A2, $E2, $82, $AC,
    $F0, $9F, $99, $82, $F4, $8F, $BF, $BF);
var
  LText: TScalarText;
  LDecoded: TScalarText;
  LBytes: TAudioBytes;
  LRejected: Boolean;
begin
  LText := ScalarText(0) + ScalarText(65) + ScalarText($A2) + ScalarText($20AC) +
    ScalarText($1F642) + ScalarText($10FFFF);
  Check(ScalarTextByteCount(LText, 15, True, True) = 15, 'UTF-8 byte size differs from literal');
  LBytes := EncodeUTF8Text(LText, 15, True, True);
  Check(SameBytes(LBytes, Expected), 'Scalar emitter differs from literal canonical UTF-8');
  LDecoded := DecodeUTF8Text(Expected, 15, True, True);
  Check(LDecoded = LText, 'UTF-8 decoder changes scalars or embedded NUL');
  Check(CompareScalarText(LText, LDecoded, 15, True) = 0, 'Decoded scalar order changed');
  Check(Length(EncodeUTF8Text('', 0)) = 0, 'Empty UTF-8 encoding changed');
  Check(DecodeUTF8Text([], 0) = '', 'Empty UTF-8 decoding changed');
  LDecoded := 'prior text';
  LRejected := False;
  try LDecoded := DecodeUTF8Text([$ED, $A0, $80], 3);
  except on ETextValidation do LRejected := True; end;
  Check(LRejected and (LDecoded = 'prior text'), 'Malformed UTF-8 replaces old text');
  LRejected := False;
  try LDecoded := DecodeUTF8Text(Expected, 14, True, True);
  except on ETextValidation do LRejected := True; end;
  Check(LRejected and (LDecoded = 'prior text'), 'UTF-8 byte cap replaces old text');
  LRejected := False;
  try LBytes := EncodeUTF8Text(LText, 14, True, True);
  except on ETextValidation do LRejected := True; end;
  Check(LRejected and SameBytes(LBytes, Expected), 'Encoding byte cap changes prior bytes');
  LRejected := False;
  try EncodeUTF8Text(LText, 15);
  except on ETextValidation do LRejected := True; end;
  Check(LRejected, 'Encoding silently permits NUL');
  LRejected := False;
  try DecodeUTF8Text(Expected, 15);
  except on ETextValidation do LRejected := True; end;
  Check(LRejected, 'Decoding silently permits NUL');
  LRejected := False;
  try EncodeUTF8Text('', 0, False);
  except on ETextValidation do LRejected := True; end;
  Check(LRejected, 'Encoding ignores empty policy');
  LRejected := False;
  try DecodeUTF8Text([], 0, False);
  except on ETextValidation do LRejected := True; end;
  Check(LRejected, 'Decoding ignores empty policy');
end;

procedure DigestFields;
const
  EmptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
var
  LBytes: TAudioBytes;
  LBefore: TAudioBytes;
  LRejected: Boolean;
  I: Integer;
begin
  SetLength(LBytes, 66);
  for I := 0 to High(LBytes) do LBytes[I] := 255;
  WriteSha256Hex(LBytes, 1, EmptyHash);
  Check((LBytes[0] = 255) and (LBytes[65] = 255), 'Digest field overwrites neighbor bytes');
  for I := 1 to 64 do Check(LBytes[I] = Ord(EmptyHash[I]), 'Digest field literal bytes differ');
  Check(Sha256HexMatches(LBytes, 1, EmptyHash), 'Digest field exact match failed');
  LBytes[32] := 0;
  Check(not Sha256HexMatches(LBytes, 1, EmptyHash), 'Corrupt digest field accepted');
  LBefore := Copy(LBytes);
  LRejected := False;
  try WriteSha256Hex(LBytes, 1, UpperCase(EmptyHash));
  except on EAudio do LRejected := True; end;
  Check(LRejected and SameBytes(LBytes, LBefore), 'Noncanonical digest partially writes');
  LRejected := False;
  try WriteSha256Hex(LBytes, 3, EmptyHash);
  except on EAudio do LRejected := True; end;
  Check(LRejected and SameBytes(LBytes, LBefore), 'Short digest window partially writes');
  LRejected := False;
  try Sha256HexMatches(LBytes, -1, EmptyHash);
  except on EAudio do LRejected := True; end;
  Check(LRejected, 'Negative digest window accepted');
end;

procedure Cancellation;
const
  Atom: array[0..7] of Byte = (65, $E2, $82, $AC, $F0, $9F, $99, $82);
var
  LBytes: TAudioBytes;
  LText: TScalarText;
  LOperation: Integer;
  LPhase: Integer;
  LPoint: Integer;
  LRejected: Boolean;
  I: Integer;
begin
  SetLength(GBytes, 131072);
  for I := 0 to High(GBytes) do GBytes[I] := Atom[I mod 8];
  GText := DecodeUTF8Text(GBytes, Length(GBytes));
  for LOperation := 0 to 1 do
    for LPhase := 0 to 1 do
      for LPoint := 0 to 2 do
      begin
        GObserver.Stage := 'text_validate_bytes';
        if LPhase = 1 then
          if LOperation = 0 then GObserver.Stage := 'text_encode_bytes'
          else GObserver.Stage := 'text_decode_bytes';
        GObserver.Point := LPoint;
        GObserver.Enabled := True;
        GObserver.Marker := Exception.Create('original UTF-8 conversion abort');
        GObserver.LastTotal := 0;
        SetLength(LBytes, 1);
        LBytes[0] := 42;
        LText := 'prior text';
        LRejected := False;
        try
          try
            if LOperation = 0 then LBytes := ForwardEncode
            else LText := ForwardDecode;
          except
            on E: Exception do
            begin
              Check(E = GObserver.Marker, 'Conversion replaced original callback exception');
              GObserver.Marker := nil;
              LRejected := True;
            end;
          end;
          Check(LRejected, 'Conversion cancellation was not reached');
          Check((Length(LBytes) = 1) and (LBytes[0] = 42) and (LText = 'prior text'),
            'Forwarded conversion publishes before its last callback');
          Inc(GAborts);
        finally
          GObserver.Enabled := False;
          GObserver.Marker.Free;
          GObserver.Marker := nil;
        end;
        if LOperation = 0 then
        begin
          LBytes := ForwardEncode;
          Check(SameBytes(LBytes, GBytes), 'Exact encoding retry changed bytes');
          LBytes[0] := 0;
          Check(GBytes[0] = 65, 'Encoding result aliases borrowed input');
        end
        else
        begin
          LText := ForwardDecode;
          Check(LText = GText, 'Exact decoding retry changed text');
        end;
        Check(GObserver.LastTotal = Length(GBytes), 'Conversion reports UTF-16 units as bytes');
      end;
end;

begin
  GObserver := TObserver.Create;
  try
    LiteralCases;
    DigestFields;
    Cancellation;
    WriteLn('Canonical UTF-8 conversion: ', GChecks, ' checks; ', GAborts,
      ' original abort/retries; ', GObserver.Calls, ' actual callbacks');
  finally
    GObserver.Free;
  end;
end.
