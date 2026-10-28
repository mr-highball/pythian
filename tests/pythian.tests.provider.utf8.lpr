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
program pythian_tests_provider_utf8;

{$mode delphi}{$H+}

uses SysUtils, pythian.audio, pythian.progress, pythian.text,
  pythian.wfc.provider.codecs;

type
  TCodec = class(TProviderCodec)
  public
    Payload: TAudioBytes;
    Decodes, Encodes, Configurations: Integer;
    function CanonicalConfiguration(const AConfiguration: TAudioBytes): TAudioBytes; override;
    function Decode(const AConfiguration: TAudioBytes; const AToken: String): TProviderCodecChoice; override;
    function Encode(const AConfiguration: TAudioBytes; const AChoice: TProviderCodecChoice): String; override;
  end;
  TObserver = class
  public
    Codec: TCodec;
    Point: Integer;
    Enabled: Boolean;
    Marker: Exception;
    Calls: Integer;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks, GAborts: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise Exception.Create(AMessage);
end;

function TCodec.CanonicalConfiguration(const AConfiguration: TAudioBytes): TAudioBytes;
begin
  Inc(Configurations);
  Result := Copy(AConfiguration);
end;

function TCodec.Decode(const AConfiguration: TAudioBytes; const AToken: String): TProviderCodecChoice;
begin
  Inc(Decodes);
  Result.Bytes := Payload;
  Result.IsUnknown := True;
end;

function TCodec.Encode(const AConfiguration: TAudioBytes; const AChoice: TProviderCodecChoice): String;
begin
  Inc(Encodes);
  Result := 'test';
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LMatch: Boolean;
begin
  Inc(Calls);
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Invalid callback count');
  if AWork.Stage <> 'text_validate_bytes' then Exit;
  Check(AWork.Units = wuBytes, 'UTF-8 validation lost byte units');
  LMatch := ((Point = 0) and (AWork.Done = 0)) or
    ((Point = 1) and (AWork.Done > 0) and (AWork.Total = 0)) or
    ((Point = 2) and (AWork.Total > 0) and (AWork.Done = AWork.Total));
  if Enabled and (Codec.Decodes > 0) and (Codec.Encodes = 0) and LMatch then
    raise Marker;
end;

procedure RequireBytes(const ABytes: array of Byte; const AValid: Boolean;
  const AMaximum: Integer; const AAllowEmpty: Boolean = True;
  const AAllowNul: Boolean = True);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ValidateUTF8Bytes(ABytes, AMaximum, AAllowEmpty, AAllowNul);
  except
    on E: ETextValidation do LRejected := True;
  end;
  Check(LRejected <> AValid, 'Canonical UTF-8 byte policy differs');
end;

procedure DirectBytes;
begin
  RequireBytes([], True, 0);
  RequireBytes([], False, 0, False);
  RequireBytes([0], True, 1);
  RequireBytes([0], False, 1, True, False);
  RequireBytes([65], False, 0);
  RequireBytes([], False, -1);
  RequireBytes([$7F], True, 1);
  RequireBytes([$C2, $80], True, 2);
  RequireBytes([$DF, $BF], True, 2);
  RequireBytes([$E0, $A0, $80], True, 3);
  RequireBytes([$ED, $9F, $BF], True, 3);
  RequireBytes([$EE, $80, $80], True, 3);
  RequireBytes([$EF, $BF, $BF], True, 3);
  RequireBytes([$F0, $90, $80, $80], True, 4);
  RequireBytes([$F4, $8F, $BF, $BF], True, 4);
  RequireBytes([$F4, $8F, $BF, $BF], False, 3);
  RequireBytes([$80], False, 1);
  RequireBytes([$FF], False, 1);
  RequireBytes([$C0, $80], False, 2);
  RequireBytes([$C1, $BF], False, 2);
  RequireBytes([$E0, $80, $80], False, 3);
  RequireBytes([$ED, $A0, $80], False, 3);
  RequireBytes([$F0, $80, $80, $80], False, 4);
  RequireBytes([$F4, $90, $80, $80], False, 4);
  RequireBytes([$F5, $80, $80, $80], False, 4);
  RequireBytes([$C2], False, 1);
  RequireBytes([$E2, $82], False, 2);
  RequireBytes([$F0, $90, $80], False, 3);
  RequireBytes([$C2, 32], False, 2);
end;

procedure Admission;
var
  LCodec: TCodec;
  LRegistry: TProviderCodecRegistry;
  LAdmission: TProviderCodecAdmission;
  LDeclaration: TProviderCodecDeclaration;
  LBinding: TProviderCodecBinding;
  LChoice: TProviderCodecChoice;
  LObserver: TObserver;
  LPoint, I: Integer;
  LRejected: Boolean;
  LDispatches: UInt64;
begin
  LCodec := TCodec.Create;
  LRegistry := TProviderCodecRegistry.Create;
  LObserver := TObserver.Create;
  try
    LDeclaration := Default(TProviderCodecDeclaration);
    LDeclaration.Identity := 'test.example/utf8';
    LDeclaration.Version := 1;
    LDeclaration.Units := 'canonical-value';
    LDeclaration.UnknownMeaning := 'explicit-flag';
    LDeclaration.ClockMeaning := 'caller-grid';
    LDeclaration.ConfigurationWork := 1;
    LDeclaration.DecodeWork := 1;
    LDeclaration.EncodeWork := 1;
    LDeclaration.MaximumPayloadBytes := 4096;
    LDeclaration.MaximumTokenBytes := 4;
    LRegistry.RegisterCodec(LDeclaration, LCodec);
    LRegistry.Seal;
    LBinding := Default(TProviderCodecBinding);
    LBinding.Identity := LDeclaration.Identity;
    LBinding.Version := LDeclaration.Version;
    LBinding.Units := LDeclaration.Units;
    LBinding.UnknownMeaning := LDeclaration.UnknownMeaning;
    LBinding.ClockMeaning := LDeclaration.ClockMeaning;
    LObserver.Codec := LCodec;
    SetLength(LCodec.Payload, 8);
    LCodec.Payload[0] := $C2; LCodec.Payload[1] := $A2;
    LCodec.Payload[2] := $F4; LCodec.Payload[3] := $8F;
    LCodec.Payload[4] := $BF; LCodec.Payload[5] := $BF;
    LCodec.Payload[6] := 0; LCodec.Payload[7] := 65;
    LAdmission := TProviderCodecAdmission.Create(LRegistry);
    try
      LChoice := LAdmission.DecodeChoice(LBinding, 'test', LObserver.Observe);
      Check(LChoice.IsUnknown and (Length(LChoice.Bytes) = 8), 'Caller payload or unknown flag changed');
      for I := 0 to 7 do Check(LChoice.Bytes[I] = LCodec.Payload[I], 'Caller UTF-8 bytes changed');
      LChoice.Bytes[0] := 65;
      Check(LCodec.Payload[0] = $C2, 'Returned payload aliases caller scratch');
      Check((LCodec.Configurations = 1) and (LCodec.Decodes = 1) and (LCodec.Encodes = 1),
        'Admission changed caller dispatch');
      Check(LAdmission.RemainingPayloadBytes = MaximumProviderCodecPayloadBytes - 8,
        'Admission changed actual payload accounting');
      LCodec.Payload[0] := $C0;
      LRejected := False;
      try
        LAdmission.DecodeChoice(LBinding, 'test', LObserver.Observe);
      except
        on E: ETextValidation do LRejected := True;
      end;
      Check(LRejected, 'Malformed caller UTF-8 payload was admitted');
    finally
      LAdmission.Free;
    end;
    SetLength(LCodec.Payload, 4096);
    for I := 0 to High(LCodec.Payload) do LCodec.Payload[I] := 65;
    for LPoint := 0 to 2 do
    begin
      LCodec.Decodes := 0;
      LCodec.Encodes := 0;
      LObserver.Point := LPoint;
      LObserver.Marker := Exception.Create('original UTF-8 observer abort');
      LObserver.Enabled := True;
      LAdmission := TProviderCodecAdmission.Create(LRegistry);
      try
        SetLength(LChoice.Bytes, 1);
        LChoice.Bytes[0] := 42;
        LChoice.IsUnknown := False;
        LRejected := False;
        try
          LChoice := LAdmission.DecodeChoice(LBinding, 'test', LObserver.Observe);
        except
          on E: Exception do
          begin
            Check(E = LObserver.Marker, 'Admission replaced the original observer exception');
            LRejected := True;
          end;
        end;
        LObserver.Marker := nil;
        LObserver.Enabled := False;
        Check(LRejected, 'Payload cancellation was not reached');
        Check((Length(LChoice.Bytes) = 1) and (LChoice.Bytes[0] = 42) and
          not LChoice.IsUnknown, 'Cancelled admission replaced caller output');
        LDispatches := LAdmission.RemainingDispatches;
        Check(LDispatches < MaximumProviderCodecDispatches, 'Cancellation reset spent admission');
        LChoice := LAdmission.DecodeChoice(LBinding, 'test', LObserver.Observe);
        Check((Length(LChoice.Bytes) = 4096) and LChoice.IsUnknown,
          'Same-context retry failed after payload cancellation');
        Check(LAdmission.RemainingDispatches < LDispatches, 'Retry renewed admission budget');
        Inc(GAborts);
      finally
        LObserver.Enabled := False;
        LAdmission.Free;
      end;
    end;
    WriteLn('Provider UTF-8 bytes: ', GChecks, ' checks; ', GAborts,
      ' original abort/retries; ', LObserver.Calls, ' actual callbacks');
  finally
    LObserver.Free;
    LRegistry.Free;
    LCodec.Free;
  end;
end;

begin
  DirectBytes;
  Admission;
end.
