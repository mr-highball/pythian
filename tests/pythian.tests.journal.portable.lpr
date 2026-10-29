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
program pythian_tests_journal_portable;
{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math,
  pythian.audio, pythian.analysis, pythian.analysis.wave, pythian.analysis.journal,
  pythian.learning, pythian.learning.journal, pythian.learning.binding,
  pythian.binary, pythian.hash, pythian.text, pythian.stream.bytes, pythian.corpus.text;

type
  { Short positive I/O and explicit flush failure exercise the real journal
    through the shared transfer boundary on both native and pas2js targets. }
  TStorage = class(TMemoryStream)
    FailFlush: Boolean;
    Raised: Exception;
    procedure Commit;
    {$ifdef pas2js}
    function Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    function Write(const ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    {$else}
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
    {$endif}
  end;

var
  GChecks: Integer;
  GPlanCase: Integer;

procedure Check(const ACondition: Boolean; const AWhy: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AWhy);
  end;
  Inc(GChecks);
end;

procedure TStorage.Commit;
begin
  if FailFlush then
  begin
    Raised := Exception.Create('Original journal flush failure');
    raise Raised;
  end;
end;

{$ifdef pas2js}
function TStorage.Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
begin
  Result := inherited Read(ABuffer, AOffset, Min(13, ACount));
end;
function TStorage.Write(const ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
begin
  Result := inherited Write(ABuffer, AOffset, Min(13, ACount));
end;
{$else}
function TStorage.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  Result := inherited Read(ABuffer, Min(13, ACount));
end;
function TStorage.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  Result := inherited Write(ABuffer, Min(13, ACount));
end;
{$endif}

function NegativeZero: Double;
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, 8);
  LBytes[7] := 128;
  Result := ReadFloat64LE(LBytes, 0);
end;

function Binding(const ACase: Integer): TFeatureJournalBinding;
begin
  Result := Default(TFeatureJournalBinding);
  Result.SourceSha256 := StringOfChar(Chr(Ord('a') + ACase), 64);
  Result.SampleRate := 8000;
  Result.Channels := 1;
  Result.FrameCount := 128;
  Result.Options := DefaultAnalysisOptions;
  Result.Options.WindowFrames := 64;
  Result.Options.HopFrames := 16;
  Result.Options.SilenceRms := 0;
  if ACase = 1 then
  begin
    Result.Options.SilenceRms := NegativeZero;
  end;
end;

function Feature(const AToken, ACase: Integer): TAudioFeature;
begin
  Result := Default(TAudioFeature);
  Result.Rms := 0.125 + AToken * 0.125;
  Result.Peak := Result.Rms * 2;
  Result.CentroidHz := 220 + AToken * 110;
  Result.Flux := AToken * 0.125;
  Result.Chroma[(AToken + ACase) mod 12] := 1;
  if ACase = 1 then
  begin
    Result.Chroma[11] := NegativeZero;
  end;
  Result.ValidFrames := 64;
end;

function Batch(const ACase, AFirst: Integer): TWaveFeatureBatch;
var
  LIndex: Integer;
begin
  Result := Default(TWaveFeatureBatch);
  Result.SourceStartFrame := AFirst * 16;
  Result.FirstFeature := AFirst;
  Result.NextFeature := AFirst + 4;
  Result.Completed := Result.NextFeature = 8;
  SetLength(Result.Features, 4);
  for LIndex := 0 to 3 do
  begin
    Result.Features[LIndex] := Feature((AFirst + LIndex) mod 4, ACase);
    Result.Features[LIndex].StartFrame := LIndex * 16;
    Result.Features[LIndex].ValidFrames := Min(64, 128 - (AFirst + LIndex) * 16);
  end;
end;

function Bytes(const AStorage: TStorage): TAudioBytes;
begin
  Result := nil;
  SetLength(Result, AStorage.Size);
  AStorage.Position := 0;
  ReadStreamBytesExact(AStorage, Result, 0, Length(Result));
end;

procedure CheckSnapshot(const AStorage: TStorage; var AJournal: TFeatureJournal;
  const ACase: Integer);
const
  Journals: array[0..2] of String = (
    '1cc241b38c41457fe3d4489ee3eae528c72cb7b939f6377e0f5915a9f2bf97fe',
    '0c2d81d02a344883206a6aac43b793402135b363f0e74f4cc7a5e03ecfbd666d',
    'cb1466298430646ad099bf8e07fb36aec686cc22530cd417314bea97ef07dc73');
  Vocabularies: array[0..2] of String = (
    '62bbbdd6a795f9ccdb1dbc158fd3fffbba1d60907215b7c0afb2e1a5cb7288cc',
    'ff68c8ca51b13f7ae49ae62fee33ac9425855a303a9cd3d7cb9d44fc4784a0c2',
    '7b6b97b56ea2f8056e1432b2faaa8ecbf5d943a19b93a095049e66c1c0dffb34');
  Models: array[0..2] of String = (
    '435f81361c5ab2664a682e349686a8a3757dce3e7e16f6be4e2f1a3e737d56bd',
    '9f5b56f7d063fac2545b87caa02e179ea0638c7fc49096df4ace7a4a4a9962f4',
    'a51c9f17e8230e79419b753e25cc48dbd09cd6d2ba3b7cb21990c17dac0056a9');
  { Exact pre-change native palette inputs. The feature transform's native
    clamp precision differs from pas2js; format conformance must bind the SAME
    values, rather than compare digests of different numerical parameters.
    These fixed bytes retain the original digest expectations unchanged. }
  CenterScalars: array[0..63] of Byte = (
    0,0,0,96,246,93,230,63, 0,0,0,192,245,40,156,63,
    0,0,0,128,249,147,233,63, 0,0,0,96,184,30,165,63,
    0,0,0,64,210,116,235,63, 0,0,0,192,245,40,172,63,
    0,0,0,192,252,201,236,63, 0,0,0,160,153,153,177,63);
var
  LBytes: TAudioBytes;
  LBinding: TFeatureJournalBinding;
  LPalette: TAcousticPalette;
  LCenters: TAcousticVectors;
  LVocabulary: String;
  LActual: TWaveFeatureBatch;
  LExpected: TWaveFeatureBatch;
  LFirst: Integer;
  LIndex: Integer;
  LPitch: Integer;
begin
  LBinding := AJournal.Binding;
  FreeAndNil(AJournal);
  LBytes := Bytes(AStorage);
  Check((Length(LBytes) = 1668) and (Sha256Bytes(LBytes) = Journals[ACase]),
    'Native frozen header/record/chain bytes changed');
  AJournal := TFeatureJournal.Create(AStorage, LBinding, AStorage.Commit, False);
  Check(AJournal.Completed and (AJournal.NextFeature = 8), 'Complete journal reopen differs');
  LFirst := 0;
  while AJournal.ReadNext(LActual) do
  begin
    LExpected := Batch(ACase, LFirst);
    Check((LActual.FirstFeature = LExpected.FirstFeature) and
      (LActual.NextFeature = LExpected.NextFeature) and
      (LActual.SourceStartFrame = LExpected.SourceStartFrame) and
      (LActual.Completed = LExpected.Completed), 'Journal frame/batch clock differs');
    Check(Length(LActual.Features) = 4, 'Journal record feature count differs');
    for LIndex := 0 to 3 do
    begin
      Check((LActual.Features[LIndex].StartFrame = LExpected.Features[LIndex].StartFrame) and
        (LActual.Features[LIndex].ValidFrames = LExpected.Features[LIndex].ValidFrames) and
        (LActual.Features[LIndex].Rms = LExpected.Features[LIndex].Rms) and
        (LActual.Features[LIndex].Peak = LExpected.Features[LIndex].Peak) and
        (LActual.Features[LIndex].CentroidHz = LExpected.Features[LIndex].CentroidHz) and
        (LActual.Features[LIndex].Flux = LExpected.Features[LIndex].Flux) and
        (LActual.Features[LIndex].Silent = LExpected.Features[LIndex].Silent), 'Journal scalar differs');
      for LPitch := 0 to 11 do
      begin
        Check(LActual.Features[LIndex].Chroma[LPitch] = LExpected.Features[LIndex].Chroma[LPitch],
          'Journal chroma differs');
      end;
    end;
    Inc(LFirst, 4);
  end;
  Check(LFirst = 8, 'Journal lost or repeated observations');
  SetLength(LCenters, 4);
  for LIndex := 0 to 3 do
  begin
    LCenters[LIndex] := AcousticVector(Feature(LIndex, ACase));
    LCenters[LIndex][12] := ReadFloat64LE(CenterScalars, LIndex * 16);
    LCenters[LIndex][13] := ReadFloat64LE(CenterScalars, LIndex * 16 + 8);
  end;
  LPalette := TAcousticPalette.CreateFromCenters(LCenters);
  try
    LVocabulary := AcousticVocabularySha256(LPalette, LBinding.Options, 8000, 1);
    Check(LVocabulary = Vocabularies[ACase], 'Native frozen vocabulary digest differs at case' +
      IntToStr(ACase) + ': ' + LVocabulary);
    Check(AcousticModelBindingSha256(LVocabulary, StringOfChar('f', 64)) = Models[ACase],
      'Native frozen model binding digest differs');
    LBinding.Options.SilenceRms := NegativeZero;
    Check(AcousticVocabularySha256(LPalette, LBinding.Options, 8000, 1) = LVocabulary,
      'Vocabulary does not normalize signed zero');
  finally
    LPalette.Free;
  end;
end;

procedure CheckPlan(const APlan: TJournalPartitionPlan; const AReject: Boolean);
var
  LActual: TJournalTrainingSegments;
  LBefore: TJournalTrainingSegments;
  LCaught: Boolean;
  LReason: String;
begin
  Inc(GPlanCase);
  SetLength(LActual, 1);
  LActual[0] := APlan[2].Segment;
  LBefore := Copy(LActual);
  LCaught := False;
  try
    LActual := SelectJournalPartition(APlan, jpTraining);
  except
    on LException: EAudio do
    begin
      LReason := LException.Message;
      LCaught := True;
    end;
  end;
  Check(LCaught = AReject, 'Journal group/partition admission differs at case' +
    IntToStr(GPlanCase) + ', expected reject=' + BoolToStr(AReject, True) + ': ' + LReason);
  if AReject then
    Check((Length(LActual) = 1) and (LActual[0].Journal = LBefore[0].Journal) and
      (LActual[0].FirstFeature = LBefore[0].FirstFeature) and
      (LActual[0].FeatureCount = LBefore[0].FeatureCount), 'Rejected plan replaced caller output')
  else
    Check((Length(LActual) = 1) and (LActual[0].Journal = APlan[0].Segment.Journal),
      'Accepted plan lost source identity/order');
end;

procedure CheckGroups(const APlan: TJournalPartitionPlan);
var
  LPlan: TJournalPartitionPlan;
  LIdentity: TCorpusText;
  LBad: TCorpusText;
  LIndex: Integer;
begin
  LPlan := Copy(APlan);
  LIdentity := '';
  for LIndex := 1 to 64 do
  begin
    LIdentity := LIdentity + ScalarText($1F3B5);
  end;
  LPlan[0].GroupId := LIdentity;
  Check(ScalarTextByteCount(LPlan[0].GroupId, 1024) = 256, 'Fixture lost UTF-8 identity bytes');
  CheckPlan(LPlan, False);
  LPlan[0].GroupId := LIdentity + ScalarText($1F3B5);
  Check(ScalarTextByteCount(LPlan[0].GroupId, 1024) = 260, 'Fixture lost supplementary bytes');
  CheckPlan(LPlan, True);
  LPlan[0].GroupId := ScalarText($00E9);
  LPlan[1].GroupId := 'e' + ScalarText($0301);
  CheckPlan(LPlan, False);
  LPlan[1].GroupId := LPlan[0].GroupId;
  CheckPlan(LPlan, True);
  LPlan := Copy(APlan);
  LPlan[0].GroupId := ScalarText($00A0) + 'id';
  CheckPlan(LPlan, False);
  LPlan[0].GroupId := ScalarText($2003) + 'id';
  CheckPlan(LPlan, False);
  LPlan[0].GroupId := ' id';
  CheckPlan(LPlan, True);
  LPlan[0].GroupId := 'id' + #9;
  CheckPlan(LPlan, True);
  LPlan[0].GroupId := 'id' + #0 + 'inside';
  CheckPlan(LPlan, True);
  LPlan[0].GroupId := '';
  CheckPlan(LPlan, True);
  {$ifdef pas2js}
  LBad := #$D800;
  {$else}
  LBad := 'xx';
  LBad[1] := AnsiChar($C0);
  LBad[2] := AnsiChar($80);
  {$endif}
  LPlan[0].GroupId := LBad;
  CheckPlan(LPlan, True);
  LPlan := Copy(APlan);
  LPlan[0].Segment.FeatureCount := 4;
  LPlan[1].Segment := LPlan[0].Segment;
  LPlan[1].Segment.FirstFeature := 4;
  CheckPlan(LPlan, True);
  LPlan := Copy(APlan);
  LPlan[0].GroupVerified := False;
  CheckPlan(LPlan, True);
  LPlan := Copy(APlan);
  LPlan[2].PreviouslyUsed := True;
  CheckPlan(LPlan, True);
end;

procedure CheckRecoveryAndFailure;
var
  LStorage: TStorage;
  LJournal: TFeatureJournal;
  LSource: TStorage;
  LOriginal: TAudioBytes;
  LChanged: TAudioBytes;
  LCase: Integer;
  LIndex: Integer;
  LCaught: Boolean;
  LHash: TAudioBytes;
begin
  LSource := TStorage.Create;
  LJournal := nil;
  try
    LJournal := TFeatureJournal.Create(LSource, Binding(0), LSource.Commit, True);
    LJournal.Append(Batch(0, 0));
    LJournal.Append(Batch(0, 4));
    FreeAndNil(LJournal);
    LOriginal := Bytes(LSource);
    for LCase := 0 to 3 do
    begin
      LStorage := TStorage.Create;
      try
        LChanged := Copy(LOriginal);
        case LCase of
          0: LChanged[0] := LChanged[0] xor 1;
          1: LChanged[High(LChanged)] := LChanged[High(LChanged)] xor 1;
          2: begin
            LChanged[320 + 6] := 240;
            LChanged[320 + 7] := 127;
            LHash := EncodeUTF8Text(Sha256Bytes(Copy(LChanged, 172, 684)), 64, False, False);
          end;
          3: SetLength(LChanged, 171);
        end;
        if LCase = 2 then
        begin
          for LIndex := 0 to 63 do
          begin
            LChanged[856 + LIndex] := LHash[LIndex];
          end;
        end;
        WriteStreamBytesExact(LStorage, LChanged, 0, Length(LChanged));
        LCaught := False;
        try
          LJournal := TFeatureJournal.Create(LStorage, Binding(0), LStorage.Commit, False);
        except
          on EAudio do
          begin
            LCaught := True;
          end;
        end;
        Check(LCaught, 'Complete corrupt/nonfinite/header input accepted');
      finally
        FreeAndNil(LJournal);
        LStorage.Free;
      end;
    end;
    LSource.Size := Length(LOriginal) - 1;
    LJournal := TFeatureJournal.Create(LSource, Binding(0), LSource.Commit, False);
    Check((LJournal.NextFeature = 4) and (LJournal.TailBytes > 0) and not LJournal.Completed,
      'Incomplete final record did not retain accepted prefix');
    LJournal.RecoverTail;
    LJournal.Append(Batch(0, 4));
    Check(LJournal.Completed and (LJournal.TailBytes = 0), 'Recovered journal cannot complete');
    FreeAndNil(LJournal);
    Check(Sha256Bytes(Bytes(LSource)) = Sha256Bytes(LOriginal), 'Recovered journal bytes drift');
    LStorage := TStorage.Create;
    try
      LJournal := TFeatureJournal.Create(LStorage, Binding(0), LStorage.Commit, True);
      LStorage.FailFlush := True;
      LCaught := False;
      try
        LJournal.Append(Batch(0, 0));
      except
        on LException: Exception do
        begin
          Check(LException = LStorage.Raised, 'Journal replaced original flush failure');
          LStorage.Raised := nil;
          LCaught := True;
        end;
      end;
      Check(LCaught and LJournal.Failed and (LJournal.NextFeature = 0),
        'Failed journal commit published progress');
    finally
      FreeAndNil(LJournal);
      LStorage.Free;
    end;
  finally
    LJournal.Free;
    LSource.Free;
  end;
end;

procedure CheckWideGeometry;
var
  LStorage: TStorage;
  LJournal: TFeatureJournal;
  LBinding: TFeatureJournalBinding;
  LCaught: Boolean;
begin
  LStorage := TStorage.Create;
  LJournal := nil;
  try
    LBinding := Binding(0);
    {$ifdef pas2js}
    LBinding.FrameCount := Trunc(9007199254740992.0);
    {$else}
    LBinding.FrameCount := High(Int64);
    {$endif}
    LCaught := False;
    try
      LJournal := TFeatureJournal.Create(LStorage, LBinding, LStorage.Commit, True);
    except
      on EAudio do
      begin
        LCaught := True;
      end;
    end;
    {$ifdef pas2js}
    Check(LCaught and (LStorage.Size = 0), 'Unsafe JavaScript integer geometry reached storage');
    {$else}
    Check(not LCaught and (LJournal.Binding.FrameCount = High(Int64)) and
      (LStorage.Size = 172), 'Native wide journal metadata range narrowed');
    {$endif}
  finally
    LJournal.Free;
    LStorage.Free;
  end;
end;

procedure Run;
var
  LStorage: array[0..2] of TStorage;
  LJournal: array[0..2] of TFeatureJournal;
  LPlan: TJournalPartitionPlan;
  LCase: Integer;
begin
  for LCase := 0 to 2 do
  begin
    LStorage[LCase] := nil;
    LJournal[LCase] := nil;
  end;
  try
    SetLength(LPlan, 3);
    for LCase := 0 to 2 do
    begin
      LStorage[LCase] := TStorage.Create;
      LJournal[LCase] := TFeatureJournal.Create(LStorage[LCase], Binding(LCase), LStorage[LCase].Commit, True);
      LJournal[LCase].Append(Batch(LCase, 0));
      LJournal[LCase].Append(Batch(LCase, 4));
      CheckSnapshot(LStorage[LCase], LJournal[LCase], LCase);
      LPlan[LCase].Segment := WholeJournalSegment(LJournal[LCase]);
      LPlan[LCase].GroupId := 'group-' + IntToStr(LCase);
      LPlan[LCase].Partition := TJournalPartition(LCase);
      LPlan[LCase].GroupVerified := True;
    end;
    CheckPlan(LPlan, False);
    CheckGroups(LPlan);
    CheckRecoveryAndFailure;
    CheckWideGeometry;
  finally
    for LCase := 0 to 2 do
    begin
      LJournal[LCase].Free;
      LStorage[LCase].Free;
    end;
  end;
end;

begin
  try
    Run;
    WriteLn('PASS ', GChecks, ' portable journal/identity/binding checks');
  except
    on LException: Exception do
    begin
      WriteLn(LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
