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
unit pythian.wfc.provider.codecs;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  MaximumProviderCodecEntries = 64;
  MaximumProviderCodecIdentityBytes = 128;
  MaximumProviderCodecConfigurationBytes = 64 * 1024;
  MaximumProviderCodecChoiceBytes = 4096;
  MaximumProviderCodecDispatches = 262144;
  MaximumProviderCodecDeclaredWork = 16777216;
  MaximumProviderCodecProcessedBytes = 32 * 1024 * 1024;
  MaximumProviderCodecPayloadBytes = 8 * 1024 * 1024;

type
  { Meaning is source-independent. Configuration occurs once per provider,
    not in every choice. The source, PPQ/grid and dependencies live in the
    surrounding provider contract. Empty binding denotes a built-in codec. }
  TProviderCodecBinding = record
    Identity: String;
    Version: Integer;
    Configuration: TAudioBytes;
    Units: String;
    UnknownMeaning: String;
    ClockMeaning: String;
  end;
  { Bytes contain a bounded canonical UTF-8 value owned by the snapshot.
    IsUnknown is explicit, never inferred from an empty token or zero value. }
  TProviderCodecChoice = record
    Bytes: TAudioBytes;
    IsUnknown: Boolean;
  end;
  TProviderCodecDeclaration = record
    Identity: String;
    Version: Integer;
    Units: String;
    UnknownMeaning: String;
    ClockMeaning: String;
    ConfigurationWork: UInt64;
    DecodeWork: UInt64;
    EncodeWork: UInt64;
    MaximumPayloadBytes: Integer;
    MaximumTokenBytes: Integer;
  end;
  { Caller-owned, pure and deterministic for its immutable declaration and
    configuration. These declarations do not isolate arbitrary caller code or
    bound allocations/execution within a callback. No executable is persisted. }
  TProviderCodec = class
  public
    function CanonicalConfiguration(const AConfiguration: TAudioBytes): TAudioBytes; virtual; abstract;
    function Decode(const AConfiguration: TAudioBytes;
      const AToken: String): TProviderCodecChoice; virtual; abstract;
    function Encode(const AConfiguration: TAudioBytes;
      const AChoice: TProviderCodecChoice): String; virtual; abstract;
  end;
  TProviderCodecEntry = record
    Declaration: TProviderCodecDeclaration;
    Codec: TProviderCodec;
  end;
  { Register then Seal. Both registry and codecs are borrowed only for the
    synchronous admission call; destroying a registry does not free codecs. }
  TProviderCodecRegistry = class
  private
    FEntries: array of TProviderCodecEntry;
    FSealed: Boolean;
    function IndexOf(const AIdentity: String; const AVersion: Integer): Integer;
    function Entry(const ABinding: TProviderCodecBinding): TProviderCodecEntry;
  public
    procedure RegisterCodec(const ADeclaration: TProviderCodecDeclaration;
      const ACodec: TProviderCodec);
    procedure Seal;
    function Count: Integer;
  end;
  { One context spans an entire admission, including nested parents and
    constructor/session validation. Spent work/dispatch/I/O is never reset;
    only unused output reservation is released after checking actual bytes.
    Processed bytes count callback configuration/token/payload I/O, not internal
    comparisons/copies or total CPU/memory. Accepted objects never retain this
    context or its borrowed registry. }
  TProviderCodecAdmission = class
  private
    FRegistry: TProviderCodecRegistry;
    FBindings: array of TProviderCodecBinding;
    FDispatches: UInt64;
    FWork: UInt64;
    FProcessedBytes: UInt64;
    FPayloadBytes: UInt64;
    procedure Reserve(const AWork, ABytes: UInt64);
    procedure ProcessOutput(const ABytes: UInt64);
    function ValidatedEntry(const ABinding: TProviderCodecBinding): TProviderCodecEntry;
  public
    constructor Create(const ARegistry: TProviderCodecRegistry);
    procedure ValidateBinding(const ABinding: TProviderCodecBinding);
    function DecodeChoice(const ABinding: TProviderCodecBinding;
      const AToken: String): TProviderCodecChoice;
    property RemainingDispatches: UInt64 read FDispatches;
    property RemainingDeclaredWork: UInt64 read FWork;
    property RemainingProcessedBytes: UInt64 read FProcessedBytes;
    property RemainingPayloadBytes: UInt64 read FPayloadBytes;
  end;

function CopyProviderCodecBinding(const ABinding: TProviderCodecBinding): TProviderCodecBinding;
function CopyProviderCodecChoice(const AChoice: TProviderCodecChoice): TProviderCodecChoice;
function SameProviderCodecBinding(const ALeft, ARight: TProviderCodecBinding): Boolean;
procedure ValidateProviderCodecBindingData(const ABinding: TProviderCodecBinding);
function EmptyProviderCodecBinding(const ABinding: TProviderCodecBinding): Boolean;
{ Returns the supplied context unchanged or creates one owned by the caller.
  Internal admissions always pass the existing context, never a new budget. }
function BorrowProviderCodecAdmission(const ARegistry: TProviderCodecRegistry;
  const AAdmission: TProviderCodecAdmission; out AOwned: Boolean): TProviderCodecAdmission;

implementation

uses
  SysUtils;

function SameBytes(const ALeft, ARight: TAudioBytes): Boolean;
var
  LIndex: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
  begin
    Exit(False);
  end;
  for LIndex := 0 to High(ALeft) do
  begin
    if ALeft[LIndex] <> ARight[LIndex] then
    begin
      Exit(False);
    end;
  end;
  Result := True;
end;

procedure CheckText(const AText: String; const AMaximum: Integer;
  const AAllowEmpty: Boolean);
var
  LIndex: Integer;
  LCount: Integer;
  LOffset: Integer;
  LByte: Integer;
  LCode: Cardinal;
begin
  if (Length(AText) > AMaximum) or ((AText = '') and not AAllowEmpty) then
  begin
    raise EAudio.Create('Caller codec text exceeds its declared byte boundary');
  end;
  LIndex := 1;
  while LIndex <= Length(AText) do
  begin
    LByte := Ord(AText[LIndex]);
    if LByte < $80 then
    begin
      Inc(LIndex);
      Continue;
    end;
    if (LByte >= $C2) and (LByte <= $DF) then
    begin
      LCount := 1;
      LCode := LByte and $1F;
    end
    else if (LByte >= $E0) and (LByte <= $EF) then
    begin
      LCount := 2;
      LCode := LByte and $0F;
    end
    else if (LByte >= $F0) and (LByte <= $F4) then
    begin
      LCount := 3;
      LCode := LByte and $07;
    end
    else
    begin
      raise EAudio.Create('Caller codec text is not canonical UTF-8');
    end;
    if Length(AText) - LIndex < LCount then
    begin
      raise EAudio.Create('Truncated caller codec UTF-8');
    end;
    for LOffset := 1 to LCount do
    begin
      LByte := Ord(AText[LIndex + LOffset]);
      if (LByte < $80) or (LByte > $BF) then
      begin
        raise EAudio.Create('Invalid caller codec UTF-8 continuation');
      end;
      LCode := (LCode shl 6) or (LByte and $3F);
    end;
    if ((LCount = 1) and (LCode < $80)) or
      ((LCount = 2) and (LCode < $800)) or
      ((LCount = 3) and (LCode < $10000)) or
      ((LCode >= $D800) and (LCode <= $DFFF)) or (LCode > $10FFFF) then
    begin
      raise EAudio.Create('Noncanonical caller codec UTF-8 code point');
    end;
    Inc(LIndex, LCount + 1);
  end;
end;

procedure CheckIdentity(const AIdentity: String);
var
  LIndex: Integer;
begin
  if (Length(AIdentity) < 3) or
    (Length(AIdentity) > MaximumProviderCodecIdentityBytes) or
    (Pos('/', AIdentity) < 2) or (AIdentity[Length(AIdentity)] = '/') then
  begin
    raise EAudio.Create('Caller codec requires a namespaced 3..128-byte identity');
  end;
  for LIndex := 1 to Length(AIdentity) do
  begin
    if not (AIdentity[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '_', '-', '/', ':']) then
    begin
      raise EAudio.Create('Caller codec identity requires explicit ASCII characters');
    end;
  end;
end;

function CopyProviderCodecBinding(const ABinding: TProviderCodecBinding): TProviderCodecBinding;
begin
  Result := ABinding;
  Result.Configuration := Copy(ABinding.Configuration);
end;

function CopyProviderCodecChoice(const AChoice: TProviderCodecChoice): TProviderCodecChoice;
begin
  Result := AChoice;
  Result.Bytes := Copy(AChoice.Bytes);
end;

function SameProviderCodecBinding(const ALeft, ARight: TProviderCodecBinding): Boolean;
begin
  Result := (ALeft.Identity = ARight.Identity) and (ALeft.Version = ARight.Version) and
    (ALeft.Units = ARight.Units) and (ALeft.UnknownMeaning = ARight.UnknownMeaning) and
    (ALeft.ClockMeaning = ARight.ClockMeaning) and SameBytes(ALeft.Configuration, ARight.Configuration);
end;

function EmptyProviderCodecBinding(const ABinding: TProviderCodecBinding): Boolean;
begin
  Result := (ABinding.Identity = '') and (ABinding.Version = 0) and
    (Length(ABinding.Configuration) = 0) and (ABinding.Units = '') and
    (ABinding.UnknownMeaning = '') and (ABinding.ClockMeaning = '');
end;

procedure ValidateProviderCodecBindingData(const ABinding: TProviderCodecBinding);
begin
  CheckIdentity(ABinding.Identity);
  if (ABinding.Version < 1) or
    (Length(ABinding.Configuration) > MaximumProviderCodecConfigurationBytes) then
  begin
    raise EAudio.Create('Caller codec version/configuration exceeds its boundary');
  end;
  CheckText(ABinding.Units, MaximumProviderCodecIdentityBytes, False);
  CheckText(ABinding.UnknownMeaning, MaximumProviderCodecIdentityBytes, False);
  CheckText(ABinding.ClockMeaning, MaximumProviderCodecIdentityBytes, False);
end;

function TProviderCodecRegistry.IndexOf(const AIdentity: String; const AVersion: Integer): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FEntries) do
  begin
    if (FEntries[LIndex].Declaration.Identity = AIdentity) and
      (FEntries[LIndex].Declaration.Version = AVersion) then
    begin
      Exit(LIndex);
    end;
  end;
  Result := -1;
end;

procedure TProviderCodecRegistry.RegisterCodec(const ADeclaration: TProviderCodecDeclaration;
  const ACodec: TProviderCodec);
var
  LBinding: TProviderCodecBinding;
  LIndex: Integer;
begin
  if FSealed or (ACodec = nil) or (Length(FEntries) >= MaximumProviderCodecEntries) then
  begin
    raise EAudio.Create('Caller codec registry is sealed, full or missing its borrowed codec');
  end;
  LBinding := Default(TProviderCodecBinding);
  LBinding.Identity := ADeclaration.Identity;
  LBinding.Version := ADeclaration.Version;
  LBinding.Units := ADeclaration.Units;
  LBinding.UnknownMeaning := ADeclaration.UnknownMeaning;
  LBinding.ClockMeaning := ADeclaration.ClockMeaning;
  ValidateProviderCodecBindingData(LBinding);
  if (ADeclaration.ConfigurationWork < 1) or (ADeclaration.DecodeWork < 1) or
    (ADeclaration.EncodeWork < 1) or (ADeclaration.MaximumPayloadBytes < 1) or
    (ADeclaration.MaximumPayloadBytes > MaximumProviderCodecChoiceBytes) or
    (ADeclaration.MaximumTokenBytes < 1) or
    (ADeclaration.MaximumTokenBytes > MaximumProviderCodecChoiceBytes) then
  begin
    raise EAudio.Create('Caller codec requires positive costs and bounded output declarations');
  end;
  if IndexOf(ADeclaration.Identity, ADeclaration.Version) >= 0 then
  begin
    raise EAudio.Create('Duplicate caller codec registration');
  end;
  LIndex := Length(FEntries);
  SetLength(FEntries, LIndex + 1);
  FEntries[LIndex].Declaration := ADeclaration;
  FEntries[LIndex].Codec := ACodec;
end;

procedure TProviderCodecRegistry.Seal;
begin
  FSealed := True;
end;

function TProviderCodecRegistry.Count: Integer;
begin
  Result := Length(FEntries);
end;

function TProviderCodecRegistry.Entry(const ABinding: TProviderCodecBinding): TProviderCodecEntry;
var
  LIndex: Integer;
begin
  if not FSealed then
  begin
    raise EAudio.Create('Caller codec registry must be sealed before admission');
  end;
  LIndex := IndexOf(ABinding.Identity, ABinding.Version);
  if LIndex < 0 then
  begin
    raise EAudio.Create('Missing or incompatible caller codec registration');
  end;
  Result := FEntries[LIndex];
  if (Result.Declaration.Units <> ABinding.Units) or
    (Result.Declaration.UnknownMeaning <> ABinding.UnknownMeaning) or
    (Result.Declaration.ClockMeaning <> ABinding.ClockMeaning) then
  begin
    raise EAudio.Create('Caller codec registration changes declared meaning');
  end;
end;

constructor TProviderCodecAdmission.Create(const ARegistry: TProviderCodecRegistry);
begin
  inherited Create;
  FRegistry := ARegistry;
  if (ARegistry <> nil) and not ARegistry.FSealed then
  begin
    raise EAudio.Create('Caller codec admission requires a sealed registry');
  end;
  FDispatches := MaximumProviderCodecDispatches;
  FWork := MaximumProviderCodecDeclaredWork;
  FProcessedBytes := MaximumProviderCodecProcessedBytes;
  FPayloadBytes := MaximumProviderCodecPayloadBytes;
end;

procedure TProviderCodecAdmission.Reserve(const AWork, ABytes: UInt64);
begin
  if (FDispatches < 1) or (AWork < 1) or (AWork > FWork) or (ABytes > FProcessedBytes) then
  begin
    raise EAudio.Create('Caller codec aggregate admission budget exhausted before callback');
  end;
  Dec(FDispatches);
  Dec(FWork, AWork);
  Dec(FProcessedBytes, ABytes);
end;

procedure TProviderCodecAdmission.ProcessOutput(const ABytes: UInt64);
begin
  if ABytes > FProcessedBytes then
  begin
    raise EAudio.Create('Caller codec output exceeds aggregate byte admission');
  end;
  Dec(FProcessedBytes, ABytes);
end;

function TProviderCodecAdmission.ValidatedEntry(const ABinding: TProviderCodecBinding): TProviderCodecEntry;
var
  LIndex: Integer;
  LCanonical: TAudioBytes;
begin
  ValidateProviderCodecBindingData(ABinding);
  if FRegistry = nil then
  begin
    raise EAudio.Create('Caller provider requires an explicit codec registry');
  end;
  Result := FRegistry.Entry(ABinding);
  for LIndex := 0 to High(FBindings) do
  begin
    if SameProviderCodecBinding(FBindings[LIndex], ABinding) then
    begin
      Exit;
    end;
  end;
  if Length(FBindings) >= MaximumProviderCodecEntries then
  begin
    raise EAudio.Create('Caller admission exceeds 64 distinct provider bindings');
  end;
  Reserve(Result.Declaration.ConfigurationWork, Length(ABinding.Configuration));
  LCanonical := Result.Codec.CanonicalConfiguration(Copy(ABinding.Configuration));
  if Length(LCanonical) > MaximumProviderCodecConfigurationBytes then
  begin
    raise EAudio.Create('Caller canonical configuration exceeds its output bound');
  end;
  ProcessOutput(Length(LCanonical));
  if not SameBytes(LCanonical, ABinding.Configuration) then
  begin
    raise EAudio.Create('Caller provider configuration is not canonical');
  end;
  LIndex := Length(FBindings);
  SetLength(FBindings, LIndex + 1);
  FBindings[LIndex] := CopyProviderCodecBinding(ABinding);
end;

procedure TProviderCodecAdmission.ValidateBinding(const ABinding: TProviderCodecBinding);
begin
  ValidatedEntry(ABinding);
end;

function TProviderCodecAdmission.DecodeChoice(const ABinding: TProviderCodecBinding;
  const AToken: String): TProviderCodecChoice;
var
  LEntry: TProviderCodecEntry;
  LChoice: TProviderCodecChoice;
  LToken: String;
  LText: String;
begin
  LEntry := ValidatedEntry(ABinding);
  CheckText(AToken, LEntry.Declaration.MaximumTokenBytes, False);
  if UInt64(LEntry.Declaration.MaximumPayloadBytes) > FPayloadBytes then
  begin
    raise EAudio.Create('Caller codec payload reservation exceeds aggregate admission');
  end;
  Reserve(LEntry.Declaration.DecodeWork,
    UInt64(Length(ABinding.Configuration)) + UInt64(Length(AToken)));
  Dec(FPayloadBytes, LEntry.Declaration.MaximumPayloadBytes);
  LChoice := LEntry.Codec.Decode(Copy(ABinding.Configuration), AToken);
  if Length(LChoice.Bytes) > LEntry.Declaration.MaximumPayloadBytes then
  begin
    raise EAudio.Create('Caller decoded value exceeds its reserved output bound');
  end;
  ProcessOutput(Length(LChoice.Bytes));
  LText := '';
  SetLength(LText, Length(LChoice.Bytes));
  if Length(LChoice.Bytes) > 0 then
  begin
    Move(LChoice.Bytes[0], LText[1], Length(LChoice.Bytes));
  end;
  CheckText(LText, LEntry.Declaration.MaximumPayloadBytes, True);
  Inc(FPayloadBytes, LEntry.Declaration.MaximumPayloadBytes - Length(LChoice.Bytes));
  { Detach before another callback: Encode may reuse its own Decode scratch
    buffer even while producing the correct canonical token. }
  LChoice := CopyProviderCodecChoice(LChoice);
  Reserve(LEntry.Declaration.EncodeWork,
    UInt64(Length(ABinding.Configuration)) + UInt64(Length(LChoice.Bytes)));
  LToken := LEntry.Codec.Encode(Copy(ABinding.Configuration), CopyProviderCodecChoice(LChoice));
  CheckText(LToken, LEntry.Declaration.MaximumTokenBytes, False);
  ProcessOutput(Length(LToken));
  if LToken <> AToken then
  begin
    raise EAudio.Create('Caller token does not round-trip canonically');
  end;
  Result := CopyProviderCodecChoice(LChoice);
end;

function BorrowProviderCodecAdmission(const ARegistry: TProviderCodecRegistry;
  const AAdmission: TProviderCodecAdmission; out AOwned: Boolean): TProviderCodecAdmission;
begin
  AOwned := AAdmission = nil;
  if AOwned then
  begin
    Result := TProviderCodecAdmission.Create(ARegistry);
  end
  else
  begin
    if AAdmission.FRegistry <> ARegistry then
    begin
      raise EAudio.Create('Nested codec admission changes its borrowed registry');
    end;
    Result := AAdmission;
  end;
end;

end.
