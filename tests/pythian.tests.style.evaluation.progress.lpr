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
program pythian_tests_style_evaluation_progress;

{$mode delphi}{$H+}

uses
  SysUtils, pythian.audio, pythian.text, pythian.progress,
  pythian.evaluation, pythian.evaluation.style, pythian.evaluation.style.card
  {$ifndef pas2js}, fpjson, pythian.tools.json,
  pythian.hash, pythian.wave, pythian.tools.files,
  pythian.tools.style.card{$endif};

const
  CBins = 257;
  CGroups = 17;
  {$ifdef pas2js}
  CBmp: TScalarText = #$E000;
  CAstral: TScalarText = #$D800#$DC00;
  CBad: TScalarText = #$D800;
  {$else}
  CBmp: TScalarText = #$EE#$80#$80;
  CAstral: TScalarText = #$F0#$90#$80#$80;
  CBad: TScalarText = #$FF;
  {$endif}

type
  TProgressRecords = array of TWorkProgress;
  TAbortSite = record
    Stage: String;
    Pass: Integer;
    Final: Boolean;
  end;
  TAbortSites = array of TAbortSite;
  TObserver = class
  public
    Records: TProgressRecords;
    Calls: Integer;
    Collect: Boolean;
    Armed: Boolean;
    Site: TAbortSite;
    Marker: Exception;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GObserver: TObserver;
  GReference: TStyleCard;
  GCandidate: TStyleCard;
  GAssigned: TStyleCard;
  GResult: TStyleCardResult;
  GDistribution: TStyleDistributionComparison;
  GText: String;
  {$ifndef pas2js}
  GRoot: String;
  GFile: String;
  {$endif}

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure RequirePhase(const AStage: String; const APass: Integer;
  const AExpected: Int64);
var
  LWork: TWorkProgress;
  LFound: Boolean;
begin
  LFound := False;
  for LWork in GObserver.Records do
  begin
    LFound := LFound or ((LWork.Stage = AStage) and (LWork.Pass = APass) and
      (LWork.Done = AExpected) and (LWork.Total = AExpected));
  end;
  Check(LFound, 'Missing authored completed phase/count: ' + AStage);
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LFinal: Boolean;
begin
  Inc(Calls);
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and (AWork.Pass >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Invalid phase counts');
  Check((AWork.Units = wuItems) or (AWork.Units = wuBytes), 'Unexpected work unit');
  if Collect then
  begin
    SetLength(Records, Length(Records) + 1);
    Records[High(Records)] := AWork;
  end;
  LFinal := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  if Armed and (AWork.Stage = Site.Stage) and (AWork.Pass = Site.Pass) and
    (AWork.Done > 0) and (LFinal = Site.Final) then
  begin
    raise Marker;
  end;
end;

function Binding: TEvaluationBinding;
begin
  Result := Default(TEvaluationBinding);
  Result.SourceSha256 := StringOfChar('a', 64);
  Result.PreparationSha256 := Result.SourceSha256;
  Result.ReferenceSha256 := Result.SourceSha256;
  Result.AnnotationPolicySha256 := Result.SourceSha256;
  Result.ScoringPolicySha256 := Result.SourceSha256;
  Result.EstimatorSha256 := Result.SourceSha256;
  Result.GroupId := 'authored-development-family';
  Result.SampleRate := 8000;
  Result.SourceFrames := 80;
  Result.EndFrame := 80;
  Result.Partition := epDevelopment;
  Result.PreviouslyUsedForTuning := True;
  Result.EstimatorTrainingOverlap := etoNotApplicable;
end;

function Card: TStyleCard;
var
  LGroups: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Result := Default(TStyleCard);
  Result.Id := 'authored-style';
  SetLength(Result.Traits, 3);
  for I := 0 to 2 do
  begin
    Result.Traits[I].Id := 'trait-' + IntToStr(I);
    Result.Traits[I].Units := 'authored-bin';
    Result.Traits[I].Denominator := 'authored opportunities including unknown';
    Result.Traits[I].MinimumCoverage := 0.5;
    Result.Traits[I].MaximumDistance := 0.2;
    if I = 2 then
    begin
      Result.Traits[I].Support := stsUnsupported;
      Result.Traits[I].Requirement := strOptional;
      Continue;
    end;
    Result.Traits[I].Distribution.PolicySha256 := StringOfChar('a', 64);
    SetLength(Result.Traits[I].Distribution.Bins, CBins);
    for K := 0 to CBins - 1 do
    begin
      Result.Traits[I].Distribution.Bins[K] := Format('bin-%.4d', [K]);
    end;
    LGroups := CGroups;
    SetLength(Result.Traits[I].Groups, LGroups);
    SetLength(Result.Traits[I].Distribution.Groups, LGroups);
    for J := 0 to LGroups - 1 do
    begin
      Result.Traits[I].Groups[J].Id := Format('group-%.4d', [J]);
      Result.Traits[I].Groups[J].Binding := Binding;
      Result.Traits[I].Groups[J].Method := 'authored counts; no inference';
      Result.Traits[I].Groups[J].Uncertainty := 'not musical ground truth';
      for K := 0 to 5 do
      begin
        Result.Traits[I].Groups[J].Assets[K] := 'authored-asset';
      end;
      Result.Traits[I].Distribution.Groups[J].GroupId := Result.Traits[I].Groups[J].Id;
      SetLength(Result.Traits[I].Distribution.Groups[J].Counts, CBins);
      for K := 0 to CBins - 1 do
      begin
        Result.Traits[I].Distribution.Groups[J].Counts[K] := 1 + K mod 3;
      end;
      Result.Traits[I].Distribution.Groups[J].Unknown := 2;
      Result.Traits[I].Distribution.Groups[J].Ambiguous := 1;
      Result.Traits[I].Distribution.Groups[J].Unsupported := 1;
    end;
  end;
end;

procedure CheckPortableText;
var
  LCard: TStyleCard;
  LOther: TStyleCard;
  LBinding: TEvaluationBinding;
  LBad: TScalarText;
  I: Integer;
  LRejected: Boolean;
begin
  LCard := Card;
  LCard.Id := CBmp + CAstral;
  LCard.Traits[0].Id := CBmp;
  LCard.Traits[1].Id := CAstral;
  LCard.Traits[2].Id := CAstral + 'z';
  LCard.Traits[0].Units := 'units ' + CBmp;
  LCard.Traits[0].Denominator := 'opportunities ' + CAstral;
  SetLength(LCard.Traits[0].Distribution.Bins, 2);
  LCard.Traits[0].Distribution.Bins[0] := CBmp;
  LCard.Traits[0].Distribution.Bins[1] := CAstral;
  SetLength(LCard.Traits[0].Groups, 2);
  SetLength(LCard.Traits[0].Distribution.Groups, 2);
  for I := 0 to 1 do
  begin
    if I = 0 then
    begin
      LCard.Traits[0].Groups[I].Id := CBmp;
    end
    else
    begin
      LCard.Traits[0].Groups[I].Id := CAstral;
    end;
    LCard.Traits[0].Distribution.Groups[I].GroupId := LCard.Traits[0].Groups[I].Id;
    SetLength(LCard.Traits[0].Distribution.Groups[I].Counts, 2);
    LCard.Traits[0].Distribution.Groups[I].Counts[0] := 4;
    LCard.Traits[0].Distribution.Groups[I].Counts[1] := 4;
  end;
  LOther := CloneStyleCard(LCard);
  {$ifndef pas2js}
  { Only host tags change here; the canonical scalar bytes remain identical. }
  SetCodePage(LOther.Traits[0].Id, 65001, False);
  SetCodePage(LOther.Traits[0].Units, 65001, False);
  SetCodePage(LOther.Traits[0].Denominator, 65001, False);
  SetCodePage(LOther.Traits[0].Distribution.Bins[0], 65001, False);
  SetCodePage(LOther.Traits[0].Groups[0].Id, 65001, False);
  SetCodePage(LOther.Traits[0].Distribution.Groups[1].GroupId, 65001, False);
  {$endif}
  Check(CompareStyleCards(LCard, LOther).PassedRequiredDeclaredLimits,
    'Scalar order was replaced by UTF-16 code-unit order');
  LOther := CloneStyleCard(LCard);
  LOther.Traits[0].Id := CAstral;
  LOther.Traits[1].Id := CBmp;
  LRejected := False;
  try
    ValidateStyleCard(LOther);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Reverse scalar order admitted');
  LBinding := Binding;
  LBinding.GroupId := 'a' + #0 + 'b';
  ValidateEvaluationBinding(LBinding);
  LCard.Traits[0].Groups[0].Binding := LBinding;
  LCard.Traits[0].Groups[0].Binding.GroupId := CBmp + #0 + CAstral;
  LBinding := LCard.Traits[0].Groups[0].Binding;
  {$ifndef pas2js}
  SetCodePage(LBinding.GroupId, 65001, False);
  {$endif}
  RequireSameEvaluationBinding(LCard.Traits[0].Groups[0].Binding, LBinding);
  for I := 0 to 6 do
  begin
    LOther := CloneStyleCard(LCard);
    LBad := '';
    case I of
      0: LBad := CBad;
      1: LBad := #0;
      2: LBad := StringOfChar('a', 257);
      3: LBad := '';
      4:
        begin
          while Length(LBad) < Length(CAstral) * 64 do
          begin
            LBad := LBad + CAstral;
          end;
          LOther.Id := LBad;
          ValidateStyleCard(LOther);
          LBad := LBad + 'a';
        end;
      5: LBad := ' ';
      6: LBad := #9 + 'family';
    end;
    LRejected := False;
    try
      if I >= 5 then
      begin
        LBinding.GroupId := LBad;
        ValidateEvaluationBinding(LBinding);
      end
      else
      begin
        LOther.Id := LBad;
        ValidateStyleCard(LOther);
      end;
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Invalid text/byte boundary admitted');
  end;
  LBad := '';
  for I := 1 to 1024 do
  begin
    LBad := LBad + CAstral;
  end;
  LOther := CloneStyleCard(LCard);
  LOther.Traits[0].Groups[0].Method := LBad;
  ValidateStyleCard(LOther);
  LOther.Traits[0].Groups[0].Method := LBad + 'a';
  LRejected := False;
  try
    ValidateStyleCard(LOther);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, '4096-byte metadata policy counted UTF-16 units');
  for I := 0 to 3 do
  begin
    LOther := CloneStyleCard(LCard);
    case I of
      0: LOther.Traits[0].Distribution.Bins[0] := CBad;
      1: LOther.Traits[0].Groups[0].Binding.GroupId := CBad;
      2: LOther.Traits[0].Groups[0].Method := CBad;
      3: LOther.Traits[0].Units := CBad;
    end;
    LRejected := False;
    try
      ValidateStyleCard(LOther);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Malformed scalar reached a shared evaluation consumer');
  end;
end;

procedure CheckMaximumAndUnknown;
var
  LDistribution: TStyleDistribution;
  LResult: TStyleDistributionComparison;
  LCard: TStyleCard;
  I: Integer;
  J: Integer;
begin
  LCard := Card;
  LDistribution := LCard.Traits[0].Distribution;
  SetLength(LDistribution.Bins, MaximumStyleBins);
  for I := 0 to High(LDistribution.Bins) do
  begin
    LDistribution.Bins[I] := Format('bin-%.4d', [I]);
  end;
  SetLength(LDistribution.Groups, MaximumStyleGroups);
  for I := 0 to High(LDistribution.Groups) do
  begin
    LDistribution.Groups[I].GroupId := Format('group-%.4d', [I]);
    SetLength(LDistribution.Groups[I].Counts, MaximumStyleBins);
    for J := 0 to MaximumStyleBins - 1 do
    begin
      LDistribution.Groups[I].Counts[J] := 1;
    end;
  end;
  GObserver.Records := nil;
  GObserver.Collect := True;
  LResult := CompareStyleDistributions(LDistribution, LDistribution, GObserver.Observe);
  GObserver.Collect := False;
  Check(LResult.Comparable and (LResult.Distance = 0) and
    (LResult.Reference.Known = Int64(MaximumStyleGroups) * MaximumStyleBins),
    'Maximum authored counts or exact arithmetic differ');
  RequirePhase('style_distribution_counts', 1, Int64(MaximumStyleGroups) * MaximumStyleBins);
  RequirePhase('style_distribution_normalize', 2, Int64(MaximumStyleGroups) * MaximumStyleBins);
  { All-unknown groups still count every bin, but perform zero normalization. }
  SetLength(LDistribution.Groups, 1);
  SetLength(LDistribution.Groups[0].Counts, 1);
  SetLength(LDistribution.Bins, 1);
  LDistribution.Groups[0].Counts[0] := 0;
  LDistribution.Groups[0].Unknown := 5;
  GObserver.Records := nil;
  GObserver.Collect := True;
  LResult := CompareStyleDistributions(LDistribution, LDistribution, GObserver.Observe);
  GObserver.Collect := False;
  Check(not LResult.Comparable and (LResult.Reference.GroupsWithValues = 0),
    'Unknown group promoted to a comparable style');
  RequirePhase('style_distribution_counts', 1, 1);
  RequirePhase('style_distribution_normalize', 1, 0);
  RequirePhase('style_distribution_ready', 0, 1);
end;

procedure ResetOutputs;
begin
  GAssigned := CloneStyleCard(GReference);
  GAssigned.Id := 'prior-card';
  GAssigned.Traits[0].Distribution.Groups[0].Counts[0] := 777;
  GResult := Default(TStyleCardResult);
  GResult.ReferenceId := 'prior-result';
  SetLength(GResult.Traits, 1);
  GResult.Traits[0].Id := 'prior-trait';
  GDistribution := Default(TStyleDistributionComparison);
  GDistribution.Distance := 123;
  GText := 'prior-text';
end;

procedure Operation(const AMode: Integer; const AProgress: TWorkProgressCallback);
begin
  case AMode of
    0: GDistribution := CompareStyleDistributions(GReference.Traits[0].Distribution,
      GCandidate.Traits[0].Distribution, AProgress);
    1: ValidateStyleCard(GReference, AProgress);
    2: GAssigned := CloneStyleCard(GReference, AProgress);
    3: GResult := CompareStyleCards(GReference, GCandidate, AProgress);
    {$ifndef pas2js}
    4: GAssigned := ReadStyleCardFile(GFile, AProgress);
    5: GText := WriteStyleCardJSON(GReference, AProgress);
    6: GText := WriteStyleCardResultJSON(CompareStyleCards(GReference, GCandidate), AProgress);
    7: GText := CompareStyleCardFiles(GFile, GFile, AProgress);
    {$endif}
  end;
end;

procedure Retained;
begin
  Check((GAssigned.Id = 'prior-card') and
    (GAssigned.Traits[0].Distribution.Groups[0].Counts[0] = 777), 'Card output changed on abort');
  Check((GResult.ReferenceId = 'prior-result') and
    (GResult.Traits[0].Id = 'prior-trait'), 'Comparison output changed on abort');
  Check(GDistribution.Distance = 123, 'Distribution output changed on abort');
  Check(GText = 'prior-text', 'Text output changed on abort');
  Check(GReference.Traits[0].Distribution.Groups[0].Counts[0] = 1, 'Source count changed');
end;

procedure RunOperation(const AMode: Integer);
var
  LSites: TAbortSites;
  LWork: TWorkProgress;
  LSite: TAbortSite;
  LExists: Boolean;
  LAborted: Boolean;
  LIndex: Integer;
  LExpectedText: String;
begin
  ResetOutputs;
  Operation(AMode, nil);
  LExpectedText := GText;
  GObserver.Records := nil;
  GObserver.Collect := True;
  ResetOutputs;
  Operation(AMode, GObserver.Observe);
  GObserver.Collect := False;
  Check(GText = LExpectedText, 'Observer changed canonical text');
  if AMode = 0 then
  begin
    Check(GDistribution.Comparable and (GDistribution.Distance = 0), 'Distribution score changed');
    Check((GDistribution.Reference.Known = CGroups * 513) and
      (GDistribution.Reference.Unknown = CGroups * 2), 'Authored distribution counts differ');
    RequirePhase('style_distribution_bins', 1, CBins);
    RequirePhase('style_distribution_counts', 1, CGroups * CBins);
    RequirePhase('style_distribution_normalize', 2, CGroups * CBins);
    RequirePhase('style_distribution_compare_bins', 2, CBins);
    RequirePhase('style_distribution_ready', 0, 1);
  end;
  if AMode in [1, 2, 3] then
  begin
    RequirePhase('style_card_validate_traits', 0, 3);
  end;
  if AMode = 2 then
  begin
    RequirePhase('style_card_clone_groups', 1, CGroups);
    RequirePhase('style_card_clone_ready', 0, 1);
  end;
  if AMode = 3 then
  begin
    Check(GResult.PassedRequiredDeclaredLimits and not GResult.GroundedAcceptance,
      'Callbacks promoted arithmetic to grounded acceptance');
    RequirePhase('style_card_compare_traits', 0, 3);
    RequirePhase('style_card_compare_ready', 0, 1);
  end;
  {$ifndef pas2js}
  if AMode in [4, 7] then
  begin
    RequirePhase('native_json_prepare_bytes', 0, Length(ReadFileBytes(GFile, MaximumStyleCardDocumentBytes)));
    RequirePhase('style_card_read_values', 0, 9289);
    RequirePhase('style_card_assets', 0, 204);
    RequirePhase('verify_audio_bytes', 0, 131116);
    RequirePhase('style_card_read_ready', 0, 1);
  end;
  if AMode = 5 then
  begin
    RequirePhase('style_card_write_values', 0, 9289);
  end;
  if AMode = 6 then
  begin
    RequirePhase('style_card_report_traits', 0, 3);
  end;
  if AMode in [5, 6, 7] then
  begin
    RequirePhase('style_card_json_encode', 0, 1);
  end;
  if AMode = 7 then
  begin
    RequirePhase('style_card_files_ready', 0, 1);
  end;
  {$endif}
  LSites := nil;
  for LWork in GObserver.Records do
  begin
    if LWork.Done = 0 then
    begin
      Continue;
    end;
    LSite.Stage := LWork.Stage;
    LSite.Pass := LWork.Pass;
    LSite.Final := (LWork.Total > 0) and (LWork.Done = LWork.Total);
    LExists := False;
    for LIndex := 0 to High(LSites) do
    begin
      LExists := LExists or ((LSites[LIndex].Stage = LSite.Stage) and
        (LSites[LIndex].Pass = LSite.Pass) and (LSites[LIndex].Final = LSite.Final));
    end;
    if not LExists then
    begin
      SetLength(LSites, Length(LSites) + 1);
      LSites[High(LSites)] := LSite;
    end;
  end;
  Check(Length(LSites) > 0, 'No actual callback phase reached');
  for LSite in LSites do
  begin
    ResetOutputs;
    GObserver.Site := LSite;
    GObserver.Armed := True;
    GObserver.Marker := Exception.Create('Big Boss original style observer marker');
    LAborted := False;
    try
      try
        Operation(AMode, GObserver.Observe);
      except
        on LException: Exception do
        begin
          if LException <> GObserver.Marker then
          begin
            raise;
          end;
          GObserver.Marker := nil;
          LAborted := True;
          Inc(GAborts);
        end;
      end;
    finally
      GObserver.Armed := False;
      GObserver.Marker.Free;
      GObserver.Marker := nil;
    end;
    Check(LAborted, 'Original abort not reached at ' + LSite.Stage);
    Retained;
    Operation(AMode, GObserver.Observe);
    Check(GText = LExpectedText, 'Retry changed canonical result');
  end;
  WriteLn('Style operation ', AMode, ': ', Length(LSites), ' original abort/retries');
end;

{$ifndef pas2js}
procedure CheckNativeJSONUnicode;
const
  CJSON: RawByteString = '{"\uE000\uD800\uDC00":"\uE000\uD800\uDC00\u0000\u0001"}';
var
  LData: TJSONData;
  LExpected: TScalarText;
begin
  LData := ParseNativeJSON(CJSON, 256, 4);
  try
    Check(LData.JSONType = jtObject, 'Native escaped Unicode root differs');
    LExpected := CBmp + CAstral;
    Check(CompareScalarText(TJSONObject(LData).Names[0], LExpected, 256) = 0,
      'Native escaped Unicode key changed');
    LExpected := LExpected + #0 + #1;
    Check(CompareScalarText(TJSONObject(LData).Items[0].AsString,
      LExpected, 256, True) = 0, 'Native escaped Unicode value changed');
  finally
    LData.Free;
  end;
end;
procedure PrepareFiles;
var
  LTemplate: TStyleCard;
  LClip: TAudioClip;
  LSamples: TAudioSamples;
  LBytes: TAudioBytes;
  I: Integer;
  J: Integer;
begin
  CheckNativeJSONUnicode;
  Check(ParamCount = 1, 'Expected existing authored style-card fixture root');
  GRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  LTemplate := ReadStyleCardFile(GRoot + 'reference.json');
  SetLength(LSamples, 65536);
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LBytes := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
  WriteFileBytes(GRoot + 'progress-source.wav', LBytes);
  for I := 0 to 1 do
  begin
    GReference.Traits[I].Distribution.PolicySha256 :=
      LTemplate.Traits[0].Distribution.PolicySha256;
    for J := 0 to CGroups - 1 do
    begin
      GReference.Traits[I].Groups[J].Binding := LTemplate.Traits[0].Groups[0].Binding;
      GReference.Traits[I].Groups[J].Binding.SourceSha256 := Sha256Bytes(LBytes);
      GReference.Traits[I].Groups[J].Binding.SourceFrames := 65536;
      GReference.Traits[I].Groups[J].Assets := LTemplate.Traits[0].Groups[0].Assets;
      GReference.Traits[I].Groups[J].Assets[0] := 'progress-source.wav';
    end;
  end;
  GReference.Id := CBmp + CAstral;
  GReference.Traits[0].Groups[0].Method := 'authored ' + CBmp + CAstral;
  GCandidate := CloneStyleCard(GReference);
  GFile := GRoot + 'progress-card.json';
  WriteTextFile(GFile, WriteStyleCardJSON(GReference));
  LTemplate := ReadStyleCardFile(GFile);
  Check((CompareScalarText(LTemplate.Id, GReference.Id, 256) = 0) and
    (CompareScalarText(LTemplate.Traits[0].Groups[0].Method,
      GReference.Traits[0].Groups[0].Method, MaximumStyleCardTextBytes) = 0),
    'Native file adapter transcoded scalar identities');
  Check(CompareScalarText(WriteStyleCardJSON(LTemplate), WriteStyleCardJSON(GReference),
    MaximumStyleCardDocumentBytes) = 0,
    'Native scalar-text JSON round-trip differs');
end;
{$endif}

var
  LMode: Integer;
begin
  GObserver := TObserver.Create;
  try
    CheckPortableText;
    CheckMaximumAndUnknown;
    GReference := Card;
    GCandidate := CloneStyleCard(GReference);
    for LMode := 0 to 3 do
    begin
      RunOperation(LMode);
    end;
    {$ifndef pas2js}
    PrepareFiles;
    for LMode := 4 to 7 do
    begin
      RunOperation(LMode);
    end;
    {$endif}
    WriteLn('Style evaluation progress: ', GChecks, ' checks, ', GAborts,
      ' original abort/retries, ', GObserver.Calls, ' callbacks.');
  finally
    GObserver.Free;
  end;
end.
