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
program pythian_tests_provider_extension;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, pythian.audio, pythian.hash, pythian.wave,
  pythian.wfc.pitch, pythian.wfc.style,
  pythian.wfc.semantic.style, pythian.example.provider.extension.units,
  pythian.wfc.provider.codecs,
  pythian.wfc.providers, pythian.wfc.provider.contracts, pythian.wfc.layers,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_text,
  wfc_sequence_graph;

type
  TFixtureCodec = class(TProviderCodec)
  public
    Scratch: TAudioBytes;
    ConfigurationCalls: Integer;
    DecodeCalls: Integer;
    EncodeCalls: Integer;
    ChangeScratchOnEncode: Boolean;
    OversizedPayload: Boolean;
    InvalidUtf8: Boolean;
    NoncanonicalToken: Boolean;
    NoncanonicalConfiguration: Boolean;
    Echo: Boolean;
    ExplicitUnknown: Boolean;
    function CanonicalConfiguration(const AConfiguration: TAudioBytes): TAudioBytes; override;
    function Decode(const AConfiguration: TAudioBytes; const AToken: String): TProviderCodecChoice; override;
    function Encode(const AConfiguration: TAudioBytes; const AChoice: TProviderCodecChoice): String; override;
  end;

  TCountedHarmonicCodec = class(TCallerHarmonicCodec)
  public
    DecodeCalls: Integer;
    function Decode(const AConfiguration: TAudioBytes;
      const AToken: String): TProviderCodecChoice; override;
  end;

var
  Checks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function Bytes(const AText: String): TAudioBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(Result) > 0 then
  begin
    Move(AText[1], Result[0], Length(Result));
  end;
end;

function Text(const ABytes: TAudioBytes): String;
begin
  Result := '';
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
  begin
    Move(ABytes[0], Result[1], Length(ABytes));
  end;
end;

function Declaration: TProviderCodecDeclaration;
begin
  Result := Default(TProviderCodecDeclaration);
  Result.Identity := 'test.example/value';
  Result.Version := 1;
  Result.Units := 'authored-test-value';
  Result.UnknownMeaning := 'no-unknown-token';
  Result.ClockMeaning := 'explicit-ppq-grid';
  Result.ConfigurationWork := 1;
  Result.DecodeWork := 1;
  Result.EncodeWork := 1;
  Result.MaximumPayloadBytes := 1;
  Result.MaximumTokenBytes := 3;
end;

function Binding: TProviderCodecBinding;
var
  LDeclaration: TProviderCodecDeclaration;
begin
  Result := Default(TProviderCodecBinding);
  LDeclaration := Declaration;
  Result.Identity := LDeclaration.Identity;
  Result.Version := LDeclaration.Version;
  Result.Units := LDeclaration.Units;
  Result.UnknownMeaning := LDeclaration.UnknownMeaning;
  Result.ClockMeaning := LDeclaration.ClockMeaning;
end;

function Registry(const ACodec: TFixtureCodec;
  const ADeclaration: TProviderCodecDeclaration): TProviderCodecRegistry;
begin
  Result := TProviderCodecRegistry.Create;
  try
    Result.RegisterCodec(ADeclaration, ACodec);
    Result.Seal;
  except
    Result.Free;
    raise;
  end;
end;

function TFixtureCodec.CanonicalConfiguration(const AConfiguration: TAudioBytes): TAudioBytes;
begin
  Inc(ConfigurationCalls);
  Result := Copy(AConfiguration);
  if NoncanonicalConfiguration then
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := 1;
  end;
end;

function TFixtureCodec.Decode(const AConfiguration: TAudioBytes;
  const AToken: String): TProviderCodecChoice;
begin
  Inc(DecodeCalls);
  if Echo then
  begin
    Scratch := Bytes(AToken);
  end
  else
  begin
    Scratch := Bytes(Copy(AToken, 3, 1));
  end;
  if OversizedPayload then
  begin
    SetLength(Scratch, 2);
  end;
  if InvalidUtf8 then
  begin
    Scratch[0] := $FF;
  end;
  Result.Bytes := Scratch;
  Result.IsUnknown := ExplicitUnknown;
end;

function TFixtureCodec.Encode(const AConfiguration: TAudioBytes;
  const AChoice: TProviderCodecChoice): String;
begin
  Inc(EncodeCalls);
  if Echo then
  begin
    Result := Text(AChoice.Bytes);
  end
  else
  begin
    Result := 't:' + Text(AChoice.Bytes);
  end;
  if ChangeScratchOnEncode then
  begin
    Scratch[0] := Ord('9');
  end;
  if NoncanonicalToken then
  begin
    Result := 'bad';
  end;
end;

function TCountedHarmonicCodec.Decode(const AConfiguration: TAudioBytes;
  const AToken: String): TProviderCodecChoice;
begin
  Inc(DecodeCalls);
  Result := inherited Decode(AConfiguration, AToken);
end;

procedure RejectDecode(const AAdmission: TProviderCodecAdmission;
  const ABinding: TProviderCodecBinding; const AToken, AReason: String);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    AAdmission.DecodeChoice(ABinding, AToken);
  except
    on E: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, AReason);
end;

procedure TestCodecBoundary;
var
  LCodec: TFixtureCodec;
  LRegistry: TProviderCodecRegistry;
  LAdmission: TProviderCodecAdmission;
  LBinding: TProviderCodecBinding;
  LCopy: TProviderCodecBinding;
  LChoice: TProviderCodecChoice;
  LRejected: Boolean;
begin
  LCodec := TFixtureCodec.Create;
  LRegistry := nil;
  LAdmission := nil;
  try
    LRegistry := Registry(LCodec, Declaration);
    LAdmission := TProviderCodecAdmission.Create(LRegistry);
    LBinding := Binding;
    LBinding.Configuration := Bytes('x');
    LCopy := CopyProviderCodecBinding(LBinding);
    LCopy.Configuration[0] := Ord('y');
    Check(LBinding.Configuration[0] = Ord('x'), 'Binding array copy must detach');
    LCodec.ChangeScratchOnEncode := True;
    LChoice := LAdmission.DecodeChoice(LBinding, 't:1');
    Check(Text(LChoice.Bytes) = '1', 'Decode payload must detach BEFORE scratch reuse in Encode');
    Check(Text(LCodec.Scratch) = '9', 'Scratch-reuse fixture actually changed its buffer');
    LChoice.Bytes[0] := Ord('4');
    LCodec.ChangeScratchOnEncode := False;
    Check(Text(LAdmission.DecodeChoice(LBinding, 't:2').Bytes) = '2', 'Independent canonical payload');
    Check(LCodec.ConfigurationCalls = 1, 'Canonical config is checked once for an unchanged binding');
    LCopy := CopyProviderCodecBinding(LBinding);
    LCopy.Units := 'changed-meaning';
    RejectDecode(LAdmission, LCopy, 't:1', 'Registration must reject changed declared units');
    LCopy := CopyProviderCodecBinding(LBinding);
    LCopy.Version := 2;
    RejectDecode(LAdmission, LCopy, 't:1', 'Missing codec version rejects explicitly');
    LCodec.OversizedPayload := True;
    RejectDecode(LAdmission, LBinding, 't:1', 'Callback output must respect declared reservation');
    LCodec.OversizedPayload := False;
    LCodec.InvalidUtf8 := True;
    RejectDecode(LAdmission, LBinding, 't:1', 'Malformed decoded UTF-8 cannot enter accepted snapshots');
    LCodec.InvalidUtf8 := False;
    LCodec.NoncanonicalToken := True;
    RejectDecode(LAdmission, LBinding, 't:1', 'Noncanonical token roundtrip rejects');
    LCodec.NoncanonicalToken := False;
    LCopy := CopyProviderCodecBinding(LBinding);
    LCopy.Configuration := Bytes('other');
    LCodec.NoncanonicalConfiguration := True;
    RejectDecode(LAdmission, LCopy, 't:1', 'Noncanonical configuration rejects');
    LRejected := False;
    try
      DecodeStyleProviderChoice(spvCaller, 't:1');
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Token-only built-in API cannot reinterpret caller vocabulary');
  finally
    LAdmission.Free;
    LRegistry.Free;
    LCodec.Free;
  end;
  LAdmission := TProviderCodecAdmission.Create(nil);
  try
    RejectDecode(LAdmission, Binding, 't:1', 'Missing explicit registry rejects');
  finally
    LAdmission.Free;
  end;
end;

procedure TestRegistryBound;
var
  LCodec: TFixtureCodec;
  LRegistry: TProviderCodecRegistry;
  LDeclaration: TProviderCodecDeclaration;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LCodec := TFixtureCodec.Create;
  LRegistry := TProviderCodecRegistry.Create;
  try
    LDeclaration := Declaration;
    LRegistry.RegisterCodec(LDeclaration, LCodec);
    LRejected := False;
    try
      LRegistry.RegisterCodec(LDeclaration, LCodec);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LRegistry.Count = 1), 'Duplicate registry admission must preserve entries');
    for LIndex := 2 to MaximumProviderCodecEntries do
    begin
      LDeclaration.Identity := 'test.example/value-' + IntToStr(LIndex);
      LRegistry.RegisterCodec(LDeclaration, LCodec);
    end;
    LRejected := False;
    LDeclaration.Identity := 'test.example/overflow';
    try
      LRegistry.RegisterCodec(LDeclaration, LCodec);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LRegistry.Count = 64), 'Registry cap rejects before appending');
    LRegistry.Seal;
    LRejected := False;
    try
      LRegistry.RegisterCodec(LDeclaration, LCodec);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Sealed registry cannot change during synchronous admission');
  finally
    LRegistry.Free;
    LCodec.Free;
  end;
end;

procedure TestAggregateBudgets;
var
  LCodec: TFixtureCodec;
  LRegistry: TProviderCodecRegistry;
  LAdmission: TProviderCodecAdmission;
  LDeclaration: TProviderCodecDeclaration;
  LBinding: TProviderCodecBinding;
  LChoice: TProviderCodecChoice;
  LIndex: Integer;
  LRejected: Boolean;
  LToken: String;
begin
  LCodec := TFixtureCodec.Create;
  LRegistry := nil;
  LAdmission := nil;
  try
    LDeclaration := Declaration;
    LDeclaration.DecodeWork := High(UInt64);
    LRegistry := Registry(LCodec, LDeclaration);
    LAdmission := TProviderCodecAdmission.Create(LRegistry);
    RejectDecode(LAdmission, Binding, 't:1', 'UInt64 cost must reject without overflowing');
    Check(LCodec.DecodeCalls = 0, 'Over-budget decode cannot execute');
    FreeAndNil(LAdmission);
    FreeAndNil(LRegistry);
    LRegistry := Registry(LCodec, Declaration);
    LAdmission := TProviderCodecAdmission.Create(LRegistry);
    LBinding := Binding;
    SetLength(LBinding.Configuration, MaximumProviderCodecConfigurationBytes);
    LRejected := False;
    LChoice := Default(TProviderCodecChoice);
    for LIndex := 1 to 300 do
    begin
      try
        LChoice := LAdmission.DecodeChoice(LBinding, 't:1');
      except
        on E: EAudio do
        begin
          LRejected := True;
          Break;
        end;
      end;
    end;
    Check(LRejected and (LIndex > 200) and (LIndex < 300), 'Shared callback I/O byte budget must accumulate');
    Check(Text(LChoice.Bytes) = '1', 'Failed admission leaves prior assigned payload intact');
    FreeAndNil(LAdmission);
    FreeAndNil(LRegistry);
    LCodec.Echo := True;
    LDeclaration := Declaration;
    LDeclaration.MaximumPayloadBytes := 4096;
    LDeclaration.MaximumTokenBytes := 4096;
    LRegistry := Registry(LCodec, LDeclaration);
    LAdmission := TProviderCodecAdmission.Create(LRegistry);
    LToken := StringOfChar('a', 4096);
    for LIndex := 1 to 2048 do
    begin
      LAdmission.DecodeChoice(Binding, LToken);
    end;
    Check(LAdmission.RemainingPayloadBytes = 0, 'Eight MiB detached payload boundary reached exactly');
    LIndex := LCodec.DecodeCalls;
    RejectDecode(LAdmission, Binding, LToken, 'Payload cap rejects next reservation');
    Check(LCodec.DecodeCalls = LIndex, 'Payload reservation rejects before callback');
  finally
    LAdmission.Free;
    LRegistry.Free;
    LCodec.Free;
  end;
end;

function SingleModel(const ARepeats: Integer): TWfcSequenceModel;
var
  LTokens: TWfcModelTokens;
  LIndex: Integer;
begin
  LTokens := nil;
  SetLength(LTokens, ARepeats);
  for LIndex := 0 to High(LTokens) do
  begin
    LTokens[LIndex] := 't:1';
  end;
  Result := LearnSequenceModelCorpus([MakeWfcSequenceSample(LTokens)], 1);
end;

function Contract(const AName: String): TProviderContract;
begin
  Result := Default(TProviderContract);
  Result.Name := AName;
  Result.Vocabulary := spvCaller;
  Result.CodecBinding := Binding;
  Result.CodecBinding.Configuration := Bytes('x');
  Result.UnknownPolicy := Result.CodecBinding.UnknownMeaning;
  Result.MusicalDomain := 'authored-codec-test';
  Result.TicksPerQuarter := 480;
  Result.Scope := MakeLayerScope(2, wseWhole);
  Result.TimeGrid := MakeLayerTimeGrid(0, 120);
end;

procedure TestOwnedSessionAndReplacement;
var
  LCodec: TFixtureCodec;
  LRegistry: TProviderCodecRegistry;
  LModel: TWfcSequenceModel;
  LReplacement: TWfcSequenceModel;
  LLayers: TLearnedLayers;
  LContracts: TProviderContracts;
  LSession: TCompatibleProviderSession;
  LSequences: TLayerSequences;
  LOld: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LReplacementReport: TLayerModelReplacementReport;
  LChoices: TStyleProviderChoices;
  LCopy: TProviderContract;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LCodec := TFixtureCodec.Create;
  LRegistry := nil;
  LModel := nil;
  LReplacement := nil;
  LSession := nil;
  try
    LRegistry := Registry(LCodec, Declaration);
    LModel := SingleModel(3);
    LReplacement := SingleModel(5);
    SetLength(LLayers, 2);
    SetLength(LContracts, 2);
    for LIndex := 0 to 1 do
    begin
      LLayers[LIndex].Model := LModel;
      LContracts[LIndex] := Contract('trait-' + IntToStr(LIndex));
    end;
    LSession := TCompatibleProviderSession.Create(LLayers, nil, LContracts,
      DefaultLayerGenerationOptions, LRegistry);
    FreeAndNil(LRegistry);
    FreeAndNil(LCodec);
    LContracts[0].CodecBinding.Configuration[0] := Ord('c');
    Check(Text(LSession.CopyContract('trait-0').CodecBinding.Configuration) = 'x', 'Contract snapshot detaches mutable input');
    Check(LSession.TryGenerate(LSequences, LReport), 'Actual WFC generation survives registry AND codec destruction');
    LChoices := LSession.CopyChoices('trait-0');
    LChoices[0].CallerValue.Bytes[0] := Ord('9');
    Check(Text(LSession.CopyChoices('trait-0')[0].CallerValue.Bytes) = '1', 'CopyChoices detaches accepted decoded arrays');
    LOld := LSession.CopyAccepted;
    LCodec := TFixtureCodec.Create;
    LRegistry := Registry(LCodec, Declaration);
    LCopy := LSession.CopyContract('trait-0');
    Check(LSession.TryReplaceProvider('trait-0', LReplacement, LCopy, 731,
      LSequences, LReplacementReport, LRegistry), 'Fresh explicit registry permits compatible model replacement');
    Check(LSequences[1].Tokens[0] = LOld[1].Tokens[0], 'Compatible replacement preserves unrelated accepted provider');
    LCopy.CodecBinding.Configuration[0] := Ord('y');
    LRejected := False;
    try
      LSession.TryReplaceProvider('trait-0', LReplacement, LCopy, 731,
        LSequences, LReplacementReport, LRegistry);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Text(LSession.CopyContract('trait-0').CodecBinding.Configuration) = 'x'),
      'Same token bytes under changed codec config reject without accepted-contract mutation');
    Check(LSession.CopyAccepted[1].Tokens[0] = LOld[1].Tokens[0], 'Incompatible replacement preserves unrelated state');
    LCopy := LSession.CopyContract('trait-0');
    LRejected := False;
    try
      LSession.TryReplaceProvider('trait-0', LReplacement, LCopy, 731,
        LSequences, LReplacementReport);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Later replacement cannot use a destroyed or implicit registry');
  finally
    LSession.Free;
    LReplacement.Free;
    LModel.Free;
    LRegistry.Free;
    LCodec.Free;
  end;
end;

procedure TestMultipleProviderBudget;
var
  LCodec: TFixtureCodec;
  LRegistry: TProviderCodecRegistry;
  LDeclaration: TProviderCodecDeclaration;
  LModel: TWfcSequenceModel;
  LLayers: TLearnedLayers;
  LContracts: TProviderContracts;
  LSession: TCompatibleProviderSession;
  LRejected: Boolean;
begin
  LCodec := TFixtureCodec.Create;
  LRegistry := nil;
  LModel := nil;
  LSession := nil;
  try
    LDeclaration := Declaration;
    LDeclaration.DecodeWork := MaximumProviderCodecDeclaredWork div 2;
    LRegistry := Registry(LCodec, LDeclaration);
    LModel := SingleModel(3);
    SetLength(LLayers, 2);
    SetLength(LContracts, 2);
    LLayers[0].Model := LModel;
    LLayers[1].Model := LModel;
    LContracts[0] := Contract('first');
    LContracts[1] := Contract('second');
    LContracts[1].CodecBinding.Configuration[0] := Ord('y');
    LRejected := False;
    try
      LSession := TCompatibleProviderSession.Create(LLayers, nil, LContracts,
        DefaultLayerGenerationOptions, LRegistry);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCodec.DecodeCalls = 1), 'Constructor shares declared-work budget across multiple providers');
  finally
    LSession.Free;
    LModel.Free;
    LRegistry.Free;
    LCodec.Free;
  end;
end;

procedure TestDispatchBindingAndUnknownBounds;
var
  LCodec: TFixtureCodec;
  LRegistry: TProviderCodecRegistry;
  LAdmission: TProviderCodecAdmission;
  LDeclaration: TProviderCodecDeclaration;
  LBinding: TProviderCodecBinding;
  LChoice: TProviderCodecChoice;
  LIndex: Integer;
  LCalls: Integer;
  LRejected: Boolean;
begin
  LCodec := TFixtureCodec.Create;
  LRegistry := nil;
  LAdmission := nil;
  try
    LRegistry := TProviderCodecRegistry.Create;
    LRegistry.RegisterCodec(Declaration, LCodec);
    LRejected := False;
    try
      LAdmission := TProviderCodecAdmission.Create(LRegistry);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LAdmission = nil), 'Unsealed registry cannot create an admission context');
    Check(LCodec.ConfigurationCalls = 0, 'Unsealed registration rejects before any callback');
    FreeAndNil(LAdmission);
    LRegistry.Seal;
    LAdmission := TProviderCodecAdmission.Create(LRegistry);
    LBinding := Binding;
    for LIndex := 0 to 63 do
    begin
      LBinding.Configuration := [Byte(LIndex)];
      LAdmission.ValidateBinding(LBinding);
    end;
    LCalls := LCodec.ConfigurationCalls;
    LBinding.Configuration := [64];
    RejectDecode(LAdmission, LBinding, 't:1', 'Distinct canonical configurations share the 64 binding cap');
    Check((LCalls = 64) and (LCodec.ConfigurationCalls = LCalls), 'Over-cap binding rejects before canonicalization');
    FreeAndNil(LAdmission);
    LAdmission := TProviderCodecAdmission.Create(LRegistry);
    for LIndex := 1 to (MaximumProviderCodecDispatches - 1) div 2 do
    begin
      LChoice := LAdmission.DecodeChoice(Binding, 't:1');
    end;
    Check(LAdmission.RemainingDispatches = 1, 'Canonicalization and every Decode/Encode count toward dispatch limit');
    RejectDecode(LAdmission, Binding, 't:1', 'Final Decode cannot publish without remaining Encode dispatch');
    Check((LAdmission.RemainingDispatches = 0) and (Text(LChoice.Bytes) = '1'),
      'Dispatch exhaustion preserves prior assigned canonical payload');
    LCalls := LCodec.DecodeCalls;
    RejectDecode(LAdmission, Binding, 't:1', 'Exhausted operation cannot dispatch further callbacks');
    Check(LCodec.DecodeCalls = LCalls, 'Exhausted callback limit rejects before dispatch');
    FreeAndNil(LAdmission);
    FreeAndNil(LRegistry);
    LDeclaration := Declaration;
    LDeclaration.UnknownMeaning := 't:1-is-explicitly-unknown';
    LRegistry := Registry(LCodec, LDeclaration);
    LAdmission := TProviderCodecAdmission.Create(LRegistry);
    LBinding := Binding;
    LBinding.UnknownMeaning := LDeclaration.UnknownMeaning;
    LCodec.ExplicitUnknown := True;
    LChoice := LAdmission.DecodeChoice(LBinding, 't:1');
    Check(LChoice.IsUnknown and (Text(LChoice.Bytes) = '1'), 'Unknown meaning is explicit independent of nonempty numeric payload');
    LCodec.ExplicitUnknown := False;
    Check(not LAdmission.DecodeChoice(LBinding, 't:0').IsUnknown, 'Numeric zero does not invent unknown status');
  finally
    LAdmission.Free;
    LRegistry.Free;
    LCodec.Free;
  end;
end;

function HarmonicRegistry(const ACodec: TCallerHarmonicCodec;
  const ADecodeWork: UInt64 = 48): TProviderCodecRegistry;
var
  LDeclaration: TProviderCodecDeclaration;
begin
  Result := TProviderCodecRegistry.Create;
  try
    LDeclaration := HarmonicCodecDeclaration;
    LDeclaration.DecodeWork := ADecodeWork;
    Result.RegisterCodec(LDeclaration, ACodec);
    Result.Seal;
  except
    Result.Free;
    raise;
  end;
end;

function RenderSession(const ASession: TCompatibleProviderSession): TAudioBytes;
var
  LClip: TAudioClip;
  LSequences: TLayerSequences;
  LReport: TGraphNegotiationReport;
begin
  LSequences := ASession.CopyAccepted;
  if Length(LSequences) = 0 then
    Check(ASession.TryGenerate(LSequences, LReport), 'Actual dependent WFC passes generate harmonic audio');
  Check((Length(LSequences) = 3) and (Length(LSequences[1].Tokens) = 8),
    'Native renderer consumes complete dependent custom sequence');
  LClip := RenderHarmonicSequences(LSequences,
    ASession.CopyContract('balance').CodecBinding, ASession.CopyChoices('balance'));
  try
    Check((LClip.SampleRate = 16000) and (LClip.Channels = 2) and
      (LClip.FrameCount = 16000), 'Actual native harmonic output geometry');
    Result := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
end;

function RenderStyle(const AStyle: TSemanticStyle;
  const ARegistry: TProviderCodecRegistry): TAudioBytes;
var
  LSession: TCompatibleProviderSession;
begin
  LSession := AStyle.CreateSession(731, ARegistry);
  try
    Result := RenderSession(LSession);
  finally
    LSession.Free;
  end;
end;

procedure SaveFixture(const ASuffix: String; const ABytes: TAudioBytes);
var
  LStream: TFileStream;
begin
  if ParamCount = 0 then
  begin
    Exit;
  end;
  LStream := TFileStream.Create(ParamStr(1) + ASuffix, fmCreate);
  try
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
  finally
    LStream.Free;
  end;
end;

function LoadFixture(const ASuffix: String): TAudioBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  LStream := TFileStream.Create(ParamStr(1) + ASuffix, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[0], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

procedure RejectStyle(const AArchive: TAudioBytes;
  const ARegistry: TProviderCodecRegistry; const AMessage: String);
var
  LRejected: Boolean;
  LStyle: TSemanticStyle;
begin
  LRejected := False;
  LStyle := nil;
  try
    try
      LStyle := DecodeSemanticStyle(AArchive, ARegistry);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, AMessage);
  finally
    LStyle.Free;
  end;
end;

procedure CheckOriginalContributions(const AOriginal, AOther,
  ABlend: TSemanticStyle; const ALeftWeight, ARightWeight: Integer);
var
  LLeft: TSemanticStyleDefinition;
  LRight: TSemanticStyleDefinition;
  LBlend: TSemanticStyleDefinition;
  LRun: Integer;
  LProvider: Integer;
  LLeftTotal: Integer;
  LRightTotal: Integer;
  LExpected: TSemanticRun;
  LFoundLeft: Boolean;
  LFoundRight: Boolean;
begin
  LLeft := AOriginal.CopyDefinition;
  LRight := AOther.CopyDefinition;
  LBlend := ABlend.CopyDefinition;
  LFoundLeft := False;
  LFoundRight := False;
  LLeftTotal := 0;
  LRightTotal := 0;
  Check(Length(LBlend.Sources) = 2, 'Distinct authored source rows retained without identity inflation');
  Check(Length(LBlend.Projections) = 1, 'Original pitch-to-custom dependency retained');
  for LRun := 0 to High(LBlend.Runs) do
  begin
    if LBlend.Sources[LBlend.Runs[LRun].SourceIndex].Sha256 = LLeft.Sources[0].Sha256 then
    begin
      LExpected := LLeft.Runs[0];
      LFoundLeft := True;
      Inc(LLeftTotal, LBlend.Runs[LRun].Weights[1]);
    end
    else
    begin
      Check(LBlend.Sources[LBlend.Runs[LRun].SourceIndex].Sha256 = LRight.Sources[0].Sha256,
        'Further blending does not invent source identities');
      LExpected := LRight.Runs[0];
      LFoundRight := True;
      Inc(LRightTotal, LBlend.Runs[LRun].Weights[1]);
    end;
    Check((LBlend.Runs[LRun].Identity = 'blend.run.' + IntToStr(LRun)) and
      (LBlend.Runs[LRun].StartFrame = LExpected.StartFrame) and
      (LBlend.Runs[LRun].EndFrame = LExpected.EndFrame) and
      (LBlend.Runs[LRun].GapBeforeFrames = LExpected.GapBeforeFrames),
      'Canonical contribution rows retain original recording/run boundaries');
    for LProvider := 0 to 2 do
    begin
      Check((LBlend.Runs[LRun].ProviderEvidence[LProvider] = LExpected.ProviderEvidence[LProvider]) and
        (LBlend.Runs[LRun].TimeGrids[LProvider].TicksPerCell = LExpected.TimeGrids[LProvider].TicksPerCell) and
        (LBlend.Runs[LRun].Tokens[LProvider][0] = LExpected.Tokens[LProvider][0]) and
        (LBlend.Runs[LRun].Tokens[LProvider][7] = LExpected.Tokens[LProvider][7]),
        'Original provider evidence, time grid and complete-run endpoints retained');
    end;
  end;
  Check(LFoundLeft and LFoundRight, 'Both original sources remain reusable contributions');
  Check((LLeftTotal = ALeftWeight) and (LRightTotal = ARightWeight),
    'Exact normalized custom contribution totals across selective canonical rows');
end;

procedure TestSemanticLifetimeBlendAndBounds;
var
  LCodec: TCountedHarmonicCodec;
  LRegistry: TProviderCodecRegistry;
  LCostRegistry: TProviderCodecRegistry;
  LCostCodec: TCountedHarmonicCodec;
  LLeft: TSemanticStyle;
  LRight: TSemanticStyle;
  LBlend: TSemanticStyle;
  LDerived: TSemanticStyle;
  LLoaded: TSemanticStyle;
  LFurther: TSemanticStyle;
  LParent: TSemanticStyle;
  LAncestor: TSemanticStyle;
  LDefinition: TSemanticStyleDefinition;
  LOriginal: TSemanticStyleDefinition;
  LRecipe: TSemanticBlendRecipe;
  LReferenceA: TAudioBytes;
  LReferenceB: TAudioBytes;
  LArchive: TAudioBytes;
  LRendered: TAudioBytes;
  LReplay: TAudioBytes;
  LContract: TProviderContract;
  LSession: TCompatibleProviderSession;
  LSequences: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LRejected: Boolean;
  LIndex: Integer;
  LDeclaration: TProviderCodecDeclaration;
  LClip: TAudioClip;
begin
  LCodec := TCountedHarmonicCodec.Create;
  LRegistry := nil;
  LCostRegistry := nil;
  LCostCodec := nil;
  LLeft := nil;
  LRight := nil;
  LBlend := nil;
  LDerived := nil;
  LLoaded := nil;
  LFurther := nil;
  LParent := nil;
  LAncestor := nil;
  LSession := nil;
  LClip := nil;
  try
    LRegistry := HarmonicRegistry(LCodec);
    LLeft := CreateHarmonicSourceStyle(0, LRegistry, LReferenceA);
    LRight := CreateHarmonicSourceStyle(1, LRegistry, LReferenceB);
    Check(Sha256Bytes(LReferenceA) <> Sha256Bytes(LReferenceB), 'Authored controls have distinct actual WAV identities');
    LDefinition := LLeft.CopyDefinition;
    LOriginal := LRight.CopyDefinition;
    Check(LDefinition.Providers[1].VocabularySha256 = LOriginal.Providers[1].VocabularySha256,
      'Independent source identities do not enter shared vocabulary meaning digest');
    LContract := CopyProviderContract(LDefinition.Providers[1].Contract);
    LContract.Source.SourceSha256 := StringOfChar('a', 64);
    LContract.Source.OriginalFrames[1] := 1999;
    Check(SemanticVocabularyIdentity(LDefinition.Providers[1].ModelText, LContract) =
      LDefinition.Providers[1].VocabularySha256, 'Source hashes and source boundaries remain outside meaning identity');
    LContract.CodecBinding := MakeHarmonicCodecBinding(200);
    Check(SemanticVocabularyIdentity(LDefinition.Providers[1].ModelText, LContract) <>
      LDefinition.Providers[1].VocabularySha256, 'Identical token bytes under changed config have a different meaning identity');
    LContract.CodecBinding := MakeHarmonicCodecBinding(100);
    LContract.CodecBinding.Units := 'changed-units';
    Check(SemanticVocabularyIdentity(LDefinition.Providers[1].ModelText, LContract) <>
      LDefinition.Providers[1].VocabularySha256, 'Declared units join semantic vocabulary identity');
    LDefinition.Providers[1].Contract.CodecBinding.Configuration[0] := Ord('X');
    LDefinition.Runs[0].Tokens[1][0] := 'changed';
    LDefinition.Sources[0].PreparationEvidence[0] := Ord('X');
    Check((LLeft.CopyDefinition.Runs[0].Tokens[1][0] = 'mix:0') and
      (Text(LLeft.CopyDefinition.Providers[1].Contract.CodecBinding.Configuration) = 'denominator=100') and
      (LLeft.CopyDefinition.Sources[0].PreparationEvidence[0] = Ord('i')),
      'Style snapshots detach nested configuration, token and evidence arrays');

    LRecipe := Default(TSemanticBlendRecipe);
    SetLength(LRecipe.Providers, 3);
    LRecipe.Providers[0].LeftWeight := 1;
    LRecipe.Providers[1].LeftWeight := 1;
    LRecipe.Providers[1].RightWeight := 2;
    LRecipe.Providers[2].RightWeight := 1;
    LRecipe.Providers[2].ControlParent := 1;
    LBlend := TSemanticStyle.CreateBlend(LLeft, LRight, LRecipe, LRegistry);
    CheckOriginalContributions(LLeft, LRight, LBlend, 1, 2);
    LDefinition := LBlend.CopyDefinition;
    LDefinition.Providers[1].Preferences := [MakeLayerTokenPreference('mix:35', 7)];
    LDefinition.Providers[1].Constraints := [MakeWfcSequenceTokenConstraint(0, ['mix:0'])];
    LDerived := TSemanticStyle.CreateDerived(LBlend, LDefinition, LRegistry);
    LArchive := LDerived.Encode;
    LSession := LDerived.CreateSession(731, LRegistry);
    FreeAndNil(LRegistry);
    FreeAndNil(LCodec);
    Check(LSession.TryGenerate(LSequences, LReport), 'Style-derived session generates after borrowed objects are freed');
    Check(LSequences[1].Tokens[0] = 'mix:0', 'Typed custom hard lock is enforced in actual dependent generation');
    Check(LDerived.CopyDefinition.Providers[1].Preferences[0].Multiplier = 7,
      'Actual session is created from the typed custom preference definition');
    LRendered := RenderSession(LSession);
    FreeAndNil(LSession);
    RejectStyle(LLeft.Encode, nil, 'Missing explicit registration rejects source/root reload');
    RejectStyle(LArchive, nil, 'Missing registration rejects nested-parent style reload');
    LRejected := False;
    try
      LParent := LDerived.CopyParent(0);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LParent = nil), 'Parent reconstruction cannot reuse destroyed registry');
    Check(Sha256Bytes(LDerived.Encode) = Sha256Bytes(LArchive), 'Failed reconstruction leaves accepted style bytes intact');

    LCodec := TCountedHarmonicCodec.Create;

    LRegistry := HarmonicRegistry(LCodec);
    SaveFixture('-derived.pys', LArchive);
    if ParamCount > 0 then
    begin
      LLoaded := DecodeSemanticStyle(LoadFixture('-derived.pys'), LRegistry);
    end
    else
    begin
      LLoaded := DecodeSemanticStyle(LArchive, LRegistry);
    end;
    Check(LLoaded.Identity = LDerived.Identity, 'Current style file reload retains canonical identity');
    LReplay := RenderStyle(LLoaded, LRegistry);
    Check(Sha256Bytes(LReplay) = Sha256Bytes(LRendered), 'Saved/reloaded derived style replays actual native PCM exactly');
    SaveFixture('-derived.wav', LRendered);
    if ParamCount > 0 then
    begin
      LClip := LoadWave(ParamStr(1) + '-derived.wav');
      Check((LClip.FrameCount = 16000) and (Sha256Bytes(EncodeWavePcm16(LClip)) = Sha256Bytes(LRendered)),
        'Actual saved WAV reload retains its full PCM and geometry');
      FreeAndNil(LClip);
    end;
    Check((LLoaded.CopyDefinition.Providers[1].Preferences[0].Multiplier = 7) and
      (LLoaded.CopyDefinition.Providers[1].Constraints[0].AllowedTokens[0] = 'mix:0'),
      'Preference and lock survive nested current-format reload');
    LParent := LLoaded.CopyParent(0, LRegistry);
    Check(LParent.Identity = LBlend.Identity, 'Fresh explicit registry reconstructs exact retained blend parent');
    LAncestor := LParent.CopyParent(0, LRegistry);
    Check(LAncestor.CopyDefinition.Runs[0].Identity =
      LLeft.CopyDefinition.Runs[0].Identity, 'Exact retained source parent carries original run identity');
      FreeAndNil(LAncestor);
    FreeAndNil(LParent);
    for LIndex := 0 to 2 do
    begin
      LRecipe.Providers[LIndex].LeftWeight := 2;
      LRecipe.Providers[LIndex].RightWeight := 3;
      LRecipe.Providers[LIndex].ControlParent := 0;
    end;
    LRecipe.RepeatPolicy := srpAddExplicit;
    LFurther := TSemanticStyle.CreateBlend(LLoaded, LLeft, LRecipe, LRegistry);
    Check((LFurther.NodeCount = 6) and (LFurther.Depth = 4), 'Reloaded derived style is a usable further-blend parent');
    CheckOriginalContributions(LLeft, LRight, LFurther, 5, 4);
    FreeAndNil(LParent);
    LParent := DecodeSemanticStyle(LFurther.Encode, LRegistry);
    Check(Sha256Bytes(RenderStyle(LFurther, LRegistry)) = Sha256Bytes(RenderStyle(LParent, LRegistry)),
      'Further blend preserves deterministic custom native audio after recursive reload');
    SaveFixture('-further.pys', LFurther.Encode);
    SaveFixture('-further.wav', RenderStyle(LFurther, LRegistry));
    FreeAndNil(LParent);
    LCostCodec := TCountedHarmonicCodec.Create;
    LCostRegistry := HarmonicRegistry(LCostCodec, 1000000);
    LParent := DecodeSemanticStyle(LLeft.Encode, LCostRegistry);
    Check(LCostCodec.DecodeCalls = 6, 'One source admission includes validation AND its internal session in one operation');
    FreeAndNil(LParent);
    LIndex := LCostCodec.DecodeCalls;
    RejectStyle(LBlend.Encode, LCostRegistry, 'Recursive admission shares declared-work budget across all retained parents and root');
    Check((LCostCodec.DecodeCalls - LIndex = 16) and
      (Sha256Bytes(LBlend.Encode) = LBlend.Identity),
      'Nested over-budget callback is rejected before dispatch and accepted style is intact');
    FreeAndNil(LCostRegistry);
    LDeclaration := HarmonicCodecDeclaration;
    LDeclaration.Version := 2;
    LCostRegistry := TProviderCodecRegistry.Create;
    LCostRegistry.RegisterCodec(LDeclaration, LCostCodec);
    LCostRegistry.Seal;
    RejectStyle(LLeft.Encode, LCostRegistry, 'Incompatible registration rejects root style');
    RejectStyle(LArchive, LCostRegistry, 'Incompatible registration rejects nested style');
    Check(Sha256Bytes(LDerived.Encode) = Sha256Bytes(LArchive), 'Missing/incompatible nested registrations never mutate accepted ancestry');
  finally
    LClip.Free;
    LSession.Free;
    LAncestor.Free;
    LParent.Free;
    LFurther.Free;
    LLoaded.Free;
    LDerived.Free;
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
    LCostRegistry.Free;
    LCostCodec.Free;
    LRegistry.Free;
    LCodec.Free;
  end;
end;

procedure SameSequences(const ABefore, AAfter: TLayerSequences;
  const AProvider: Integer; const AMessage: String);
var
  LCell: Integer;
begin
  Check(Length(ABefore[AProvider].Tokens) = Length(AAfter[AProvider].Tokens), AMessage);
  for LCell := 0 to High(ABefore[AProvider].Tokens) do
  begin
    Check((ABefore[AProvider].Tokens[LCell] = AAfter[AProvider].Tokens[LCell]) and
      (ABefore[AProvider].StateIndices[LCell] = AAfter[AProvider].StateIndices[LCell]), AMessage);
  end;
end;

procedure TestDependentReplacementAndNativeTrait;
var
  LCodec: TCallerHarmonicCodec;
  LRegistry: TProviderCodecRegistry;
  LStyle: TSemanticStyle;
  LDefinition: TSemanticStyleDefinition;
  LSession: TCompatibleProviderSession;
  LCompatible: TWfcSequenceModel;
  LContradictory: TWfcSequenceModel;
  LContract: TProviderContract;
  LSequences: TLayerSequences;
  LOld: TLayerSequences;
  LPlain: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LReplacement: TLayerModelReplacementReport;
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LMask: TWfcSequenceTokenConstraints;
  LChoices: TStyleProviderChoices;
  LReference: TAudioBytes;
  LZeroBytes: TAudioBytes;
  LOneBytes: TAudioBytes;
  LZero: TAudioClip;
  LOne: TAudioClip;
  LCell: Integer;
  LProvider: Integer;
  LFrame: Integer;
  LRejected: Boolean;
  LCross: Double;
  LZeroEnergy: Double;
  LOneEnergy: Double;
  LSquaredCorrelation: Double;
  LZeroSample: Double;
  LOneSample: Double;
begin
  LCodec := TCallerHarmonicCodec.Create;
  LRegistry := nil;
  LStyle := nil;
  LSession := nil;
  LCompatible := nil;
  LContradictory := nil;
  LZero := nil;
  LOne := nil;
  try
    LRegistry := HarmonicRegistry(LCodec);
    LStyle := CreateHarmonicSourceStyle(0, LRegistry, LReference);
    LDefinition := LStyle.CopyDefinition;
    LSession := LStyle.CreateSession(731, LRegistry);
    SetLength(LMask, 8);
    for LCell := 0 to 7 do
    begin
      LMask[LCell] := MakeWfcSequenceTokenConstraint(LCell, [LDefinition.Runs[0].Tokens[0][LCell]]);
    end;
    LSession.SetConstraints('pitch', LMask);
    Check(LSession.TryGenerate(LSequences, LReport), 'Exact authored pitch locks execute across dependent custom pass');
    LOld := LSession.CopyAccepted;
    SetLength(LSamples, 2);
    LSamples[0] := MakeWfcSequenceSample(LDefinition.Runs[0].Tokens[1]);
    LSamples[1] := MakeWfcSequenceSample(LDefinition.Runs[0].Tokens[1]);
    LCompatible := LearnSequenceModelCorpus(LSamples, 1);
    LContract := LSession.CopyContract('balance');
    Check(LSession.TryReplaceProvider('balance', LCompatible, LContract, 731,
      LSequences, LReplacement, LRegistry), 'Compatible authored custom model replacement succeeds in actual dependent WFC');
    SameSequences(LOld, LSession.CopyAccepted, 0, 'Replacement preserves unrelated accepted pitch tokens AND states');
    SameSequences(LOld, LSession.CopyAccepted, 2, 'Replacement preserves unrelated accepted intensity tokens AND states');
    Check((Length(LReplacement.AffectedLayerIndices) = 1) and
      (LReplacement.AffectedLayerIndices[0] = 1) and (Length(LReplacement.PreservedLayerIndices) = 2),
      'Replacement report names exactly the custom pass and preserved independent passes');
    LOld := LSession.CopyAccepted;
    LContract.CodecBinding := MakeHarmonicCodecBinding(200);
    LRejected := False;
    try
      LSession.TryReplaceProvider('balance', LCompatible, LContract, 731,
        LSequences, LReplacement, LRegistry);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and SameProviderCodecBinding(LSession.CopyContract('balance').CodecBinding,
      MakeHarmonicCodecBinding(100)), 'Canonical identical tokens under changed harmonic meaning reject before publication');
    for LProvider := 0 to 2 do
    begin
      SameSequences(LOld, LSession.CopyAccepted, LProvider,
        'Incompatible meaning replacement preserves every accepted token/state');
    end;
    LTokens := ['mix:0', 'mix:35', 'mix:100', 'mix:100', 'mix:100', 'mix:100', 'mix:100', 'mix:100'];
    LContradictory := LearnSequenceModelCorpus([MakeWfcSequenceSample(LTokens)], 2);
    LContract := LSession.CopyContract('balance');
    LContract.Source := Default(TProviderSourceEvidence);
    Check(not LSession.TryReplaceProvider('balance', LContradictory, LContract, 731,
      LSequences, LReplacement, LRegistry), 'Compatible declared vocabulary with contradictory transitions fails actual dependency solve');
    for LProvider := 0 to 2 do
    begin
      SameSequences(LOld, LSession.CopyAccepted, LProvider, 'Contradictory replacement preserves accepted state');
      SameSequences(LOld, LSequences, LProvider, 'Contradictory replacement preserves caller output');
    end;
    Check(LSession.CopyContract('balance').Source.SourceSha256 = LDefinition.Sources[0].Sha256,
      'Failed replacement cannot publish changed evidence declarations');

    LChoices := LSession.CopyChoices('balance');
    SetLength(LPlain, 3);
    for LProvider := 0 to 2 do
    begin
      SetLength(LPlain[LProvider].Tokens, 8);
    end;
    for LCell := 0 to 7 do
    begin
      LPlain[0].Tokens[LCell] := String(PitchNoteToken(60));
      LPlain[1].Tokens[LCell] := 'mix:0';
      LPlain[2].Tokens[LCell] := String(StyleIntensityToken(3));
    end;
    LZero := RenderHarmonicSequences(LPlain, LSession.CopyContract('balance').CodecBinding, LChoices);
    for LCell := 0 to 7 do
    begin
      LPlain[1].Tokens[LCell] := 'mix:100';
    end;
    LOne := RenderHarmonicSequences(LPlain, LSession.CopyContract('balance').CodecBinding, LChoices);
    LZeroBytes := EncodeWavePcm16(LZero);
    LOneBytes := EncodeWavePcm16(LOne);
    Check(Sha256Bytes(LZeroBytes) <> Sha256Bytes(LOneBytes), 'Same pitch/intensity/seed with new custom trait changes actual PCM');
    LCross := 0;
    LZeroEnergy := 0;
    LOneEnergy := 0;
    for LFrame := 0 to LZero.FrameCount - 1 do
    begin
      LZeroSample := LZero.SampleAt(LFrame, 0);
      LOneSample := LOne.SampleAt(LFrame, 0);
      LCross := LCross + LZeroSample * LOneSample;
      LZeroEnergy := LZeroEnergy + LZeroSample * LZeroSample;
      LOneEnergy := LOneEnergy + LOneSample * LOneSample;
    end;
    LSquaredCorrelation := LCross * LCross / (LZeroEnergy * LOneEnergy);
    Check(LSquaredCorrelation < 0.9, 'Harmonic trait changes timbre rather than just scalar gain');
    Writeln('Same-pitch/intensity harmonic control squared correlation: ', LSquaredCorrelation:0:8);
    SaveFixture('-harmonic-zero.wav', LZeroBytes);
    SaveFixture('-harmonic-one.wav', LOneBytes);
  finally
    LOne.Free;
    LZero.Free;
    LContradictory.Free;
    LCompatible.Free;
    LSession.Free;
    LStyle.Free;
    LRegistry.Free;
    LCodec.Free;
  end;
end;

begin
  try
    TestCodecBoundary;
    TestRegistryBound;
    TestAggregateBudgets;
    TestOwnedSessionAndReplacement;
    TestMultipleProviderBudget;
    TestDispatchBindingAndUnknownBounds;
    TestSemanticLifetimeBlendAndBounds;
    TestDependentReplacementAndNativeTrait;
    Writeln('Caller codec conformance passed: ', Checks, ' checks');
    Writeln('Mechanical contracts only; authored values are not inferred acoustic truth or human adoption.');
  except
    on E: Exception do
    begin
      Writeln(StdErr, E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
