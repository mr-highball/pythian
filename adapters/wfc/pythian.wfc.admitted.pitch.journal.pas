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
unit pythian.wfc.admitted.pitch.journal;

{$mode delphi}
{$H+}

interface

uses
  pythian.wfc.admitted.pitch;

const
  AdmittedPitchJournalVersion = 1;
  MaximumAdmittedPitchJournalBytes = 8 * 1024 * 1024;

type
  TAdmittedPitchJournal = class
  private
    FPolicyIdentity: String;
    FOrder: Integer;
    FSources: TAdmittedNoteSources;
    FSpanCount: Integer;
    FTrainingRunCount: Integer;
    function GetSourceCount: Integer;
    procedure ValidateAndCount(const ASources: TAdmittedNoteSources;
      out ASpanCount, ATrainingRunCount: Integer);
  public
    constructor Create(const AOrder: Integer = 2;
      const APolicyIdentity: String = AdmittedPitchPolicyIdentity);
    procedure AppendSource(const ASource: TAdmittedNoteSource;
      const APolicyIdentity: String);
    function EncodeText: UTF8String;
    procedure ReplaceFromText(const AText: UTF8String);
    function CopySources: TAdmittedNoteSources;
    function Rebuild: TAdmittedPitchDurationModel;
    function JournalSha256: String;
    property PolicyIdentity: String read FPolicyIdentity;
    property Order: Integer read FOrder;
    property SourceCount: Integer read GetSourceCount;
    property SpanCount: Integer read FSpanCount;
    property TrainingRunCount: Integer read FTrainingRunCount;
  end;

implementation

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.pitch.track,
  pythian.hash;

function HashText(const AValue: UTF8String): String;
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, Length(AValue));
  if Length(AValue) > 0 then
  begin
    Move(AValue[1], LBytes[0], Length(AValue));
  end;
  Result := Sha256Bytes(LBytes);
end;

function ValidIdentity(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := (Length(AValue) >= 1) and (Length(AValue) <= 128);
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '_', ':', '-']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidSha256(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := Length(AValue) = 64;
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      Exit(False);
    end;
  end;
end;

function CanonicalNumber(const AValue: String; out ANumber: Int64): Boolean;
var
  LCode: Integer;
begin
  ANumber := 0;
  Result := (AValue <> '') and (AValue = Trim(AValue));
  if not Result then
  begin
    Exit;
  end;
  Val(AValue, ANumber, LCode);
  Result := (LCode = 0) and (IntToStr(ANumber) = AValue);
end;

function SourceKeyLess(const ALeft, ARight: TAdmittedNoteSource): Boolean;
begin
  if ALeft.GroupId <> ARight.GroupId then
  begin
    Exit(ALeft.GroupId < ARight.GroupId);
  end;
  if ALeft.RecordingId <> ARight.RecordingId then
  begin
    Exit(ALeft.RecordingId < ARight.RecordingId);
  end;
  Result := ALeft.SourceSha256 < ARight.SourceSha256;
end;

function SameSpan(const ALeft, ARight: TAdmittedNoteSpan): Boolean;
begin
  Result := (ALeft.Kind = ARight.Kind) and (ALeft.Note = ARight.Note) and
    (ALeft.StartFrame = ARight.StartFrame) and (ALeft.EndFrame = ARight.EndFrame);
end;

function SameSource(const ALeft, ARight: TAdmittedNoteSource): Boolean;
var
  LIndex: Integer;
begin
  Result := (ALeft.GroupId = ARight.GroupId) and
    (ALeft.RecordingId = ARight.RecordingId) and
    (ALeft.SourceSha256 = ARight.SourceSha256) and
    (ALeft.SourceAnnotationId = ARight.SourceAnnotationId) and
    (ALeft.SourceAnnotationSha256 = ARight.SourceAnnotationSha256) and
    (ALeft.SourceAnnotationPublisher = ARight.SourceAnnotationPublisher) and
    (ALeft.SourceAnnotationMethod = ARight.SourceAnnotationMethod) and
    (ALeft.SampleRate = ARight.SampleRate) and
    (ALeft.SourceFrameCount = ARight.SourceFrameCount) and
    (Length(ALeft.Spans) = Length(ARight.Spans));
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 0 to High(ALeft.Spans) do
  begin
    if not SameSpan(ALeft.Spans[LIndex], ARight.Spans[LIndex]) then
    begin
      Exit(False);
    end;
  end;
end;

function CopySource(const ASource: TAdmittedNoteSource): TAdmittedNoteSource;
var
  LIndex: Integer;
begin
  Result := ASource;
  SetLength(Result.Spans, Length(ASource.Spans));
  for LIndex := 0 to High(ASource.Spans) do
  begin
    Result.Spans[LIndex] := ASource.Spans[LIndex];
  end;
end;

procedure WriteLine(const AStream: TMemoryStream; const ALine: UTF8String);
const
  CLineFeed: AnsiChar = #10;
begin
  if Length(ALine) > 0 then
  begin
    AStream.WriteBuffer(ALine[1], Length(ALine));
  end;
  AStream.WriteBuffer(CLineFeed, SizeOf(CLineFeed));
end;

function SourceLine(const ASource: TAdmittedNoteSource): UTF8String;
begin
  Result := 'source'#9 + UTF8String(ASource.GroupId) + #9 +
    UTF8String(ASource.RecordingId) + #9 + UTF8String(ASource.SourceSha256) + #9 +
    UTF8String(ASource.SourceAnnotationId) + #9 +
    UTF8String(ASource.SourceAnnotationSha256) + #9 +
    UTF8String(ASource.SourceAnnotationPublisher) + #9 +
    UTF8String(ASource.SourceAnnotationMethod) + #9 +
    UTF8String(IntToStr(ASource.SampleRate)) + #9 +
    UTF8String(IntToStr(ASource.SourceFrameCount)) + #9 +
    UTF8String(IntToStr(Length(ASource.Spans)));
end;

function SplitTabs(const ALine: UTF8String): TStringArray;
var
  LStart: SizeInt;
  LIndex: SizeInt;
begin
  Result := nil;
  SetLength(Result, 0);
  LStart := 1;
  for LIndex := 1 to Length(ALine) do
  begin
    if ALine[LIndex] = #9 then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Copy(ALine, LStart, LIndex - LStart);
      LStart := LIndex + 1;
    end;
  end;
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := Copy(ALine, LStart, Length(ALine) - LStart + 1);
end;

function ParseInt64(const AValue: UTF8String; const AField: String): Int64;
begin
  if not CanonicalNumber(String(AValue), Result) then
  begin
    raise EAudio.Create('Journal has a noncanonical integer in ' + AField);
  end;
end;

procedure RequireFieldCount(const AFields: TStringArray; const AExpected: Integer);
begin
  if Length(AFields) <> AExpected then
  begin
    raise EAudio.Create('Journal row has an unexpected number of fields');
  end;
end;

function ParseText(const AText: UTF8String; out APolicy: String;
  out AOrder: Integer): TAdmittedNoteSources;
var
  LLines: TStringArray;
  LFields: TStringArray;
  LStart: SizeInt;
  LIndex: Integer;
  LLineCount: Integer;
  LLineIndex: Integer;
  LDeclaredSources: Int64;
  LDeclaredSpans: Int64;
  LDeclaredTotalSpans: Int64;
  LParsedSpanCount: Int64;
  LDeclaredSourceSpans: Int64;
  LKind: Int64;
  LNote: Int64;
  LStartFrame: Int64;
  LEndFrame: Int64;
  LSource: TAdmittedNoteSource;
begin
  if Length(AText) > MaximumAdmittedPitchJournalBytes then
  begin
    raise EAudio.Create('Journal encoded text exceeds byte bound');
  end;
  if (Length(AText) = 0) or (AText[Length(AText)] <> #10) or
    (Pos(#13, String(AText)) > 0) or (Pos(#0, String(AText)) > 0) then
  begin
    raise EAudio.Create('Journal text must be nonempty canonical LF UTF-8');
  end;
  LLineCount := 0;
  for LIndex := 1 to Length(AText) do
  begin
    if AText[LIndex] = #10 then
    begin
      Inc(LLineCount);
      if LLineCount > 5 + MaximumAdmittedSources + MaximumAdmittedInputSpans then
      begin
        raise EAudio.Create('Journal row count exceeds source/span bound');
      end;
    end;
  end;
  SetLength(LLines, LLineCount);
  LStart := 1;
  LLineIndex := 0;
  for LIndex := 1 to Length(AText) do
  begin
    if AText[LIndex] = #10 then
    begin
      LLines[LLineIndex] := Copy(AText, LStart, LIndex - LStart);
      Inc(LLineIndex);
      LStart := LIndex + 1;
    end;
  end;
  if Length(LLines) < 5 then
  begin
    raise EAudio.Create('Journal header is incomplete');
  end;
  LFields := SplitTabs(LLines[0]);
  RequireFieldCount(LFields, 2);
  if (LFields[0] <> 'pythian-admitted-pitch-journal') or (LFields[1] <> '1') then
  begin
    raise EAudio.Create('Journal format identity or version is unsupported');
  end;
  LFields := SplitTabs(LLines[1]);
  RequireFieldCount(LFields, 2);
  if LFields[0] <> 'policy' then
  begin
    raise EAudio.Create('Journal policy header is missing');
  end;
  APolicy := String(LFields[1]);
  LFields := SplitTabs(LLines[2]);
  RequireFieldCount(LFields, 2);
  if LFields[0] <> 'order' then
  begin
    raise EAudio.Create('Journal order header is missing');
  end;
  LDeclaredSpans := ParseInt64(LFields[1], 'order');
  if (LDeclaredSpans < 1) or (LDeclaredSpans > 4) then
  begin
    raise EAudio.Create('Journal model order is outside 1..4');
  end;
  AOrder := Integer(LDeclaredSpans);
  LFields := SplitTabs(LLines[3]);
  RequireFieldCount(LFields, 2);
  if LFields[0] <> 'source_count' then
  begin
    raise EAudio.Create('Journal source count header is missing');
  end;
  LDeclaredSources := ParseInt64(LFields[1], 'source_count');
  if (LDeclaredSources < 0) or (LDeclaredSources > MaximumAdmittedSources) then
  begin
    raise EAudio.Create('Journal source count exceeds bound');
  end;
  LFields := SplitTabs(LLines[4]);
  RequireFieldCount(LFields, 2);
  if LFields[0] <> 'span_count' then
  begin
    raise EAudio.Create('Journal span count header is missing');
  end;
  LDeclaredTotalSpans := ParseInt64(LFields[1], 'span_count');
  if (LDeclaredTotalSpans < 0) or (LDeclaredTotalSpans > MaximumAdmittedInputSpans) then
  begin
    raise EAudio.Create('Journal span count exceeds bound');
  end;
  LIndex := 5;
  LParsedSpanCount := 0;
  Result := nil;
  SetLength(Result, 0);
  while LIndex < Length(LLines) do
  begin
    LFields := SplitTabs(LLines[LIndex]);
    RequireFieldCount(LFields, 11);
    if LFields[0] <> 'source' then
    begin
      raise EAudio.Create('Journal expected source record');
    end;
    LSource.GroupId := String(LFields[1]);
    LSource.RecordingId := String(LFields[2]);
    LSource.SourceSha256 := String(LFields[3]);
    LSource.SourceAnnotationId := String(LFields[4]);
    LSource.SourceAnnotationSha256 := String(LFields[5]);
    LSource.SourceAnnotationPublisher := String(LFields[6]);
    LSource.SourceAnnotationMethod := String(LFields[7]);
    LSource.SampleRate := Integer(ParseInt64(LFields[8], 'sample_rate'));
    LSource.SourceFrameCount := ParseInt64(LFields[9], 'source_frames');
    LDeclaredSourceSpans := ParseInt64(LFields[10], 'source_span_count');
    if (LDeclaredSourceSpans < 0) or
      (LDeclaredSourceSpans > MaximumAdmittedInputSpans) or
      (LDeclaredSourceSpans > MaximumAdmittedInputSpans - LParsedSpanCount) then
    begin
      raise EAudio.Create('Journal source span count is outside bounds');
    end;
    Inc(LParsedSpanCount, LDeclaredSourceSpans);
    SetLength(LSource.Spans, Integer(LDeclaredSourceSpans));
    Inc(LIndex);
    for LStart := 0 to LDeclaredSourceSpans - 1 do
    begin
      if LIndex >= Length(LLines) then
      begin
        raise EAudio.Create('Journal source span rows are truncated');
      end;
      LFields := SplitTabs(LLines[LIndex]);
      RequireFieldCount(LFields, 5);
      if LFields[0] <> 'span' then
      begin
        raise EAudio.Create('Journal expected span record');
      end;
      LKind := ParseInt64(LFields[1], 'span_kind');
      LNote := ParseInt64(LFields[2], 'note');
      LStartFrame := ParseInt64(LFields[3], 'start_frame');
      LEndFrame := ParseInt64(LFields[4], 'end_frame');
      if (LKind < 0) or (LKind > 2) or (LNote < Low(Integer)) or
        (LNote > High(Integer)) then
      begin
        raise EAudio.Create('Journal span kind or note is out of bounds');
      end;
      LSource.Spans[LStart] := Default(TAdmittedNoteSpan);
      LSource.Spans[LStart].Kind := TPitchSpanKind(LKind);
      LSource.Spans[LStart].Note := Integer(LNote);
      LSource.Spans[LStart].StartFrame := LStartFrame;
      LSource.Spans[LStart].EndFrame := LEndFrame;
      Inc(LIndex);
    end;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LSource;
    LSource := Default(TAdmittedNoteSource);
  end;
  if Length(Result) <> LDeclaredSources then
  begin
    raise EAudio.Create('Journal declared source count does not match records');
  end;
  if LParsedSpanCount <> LDeclaredTotalSpans then
  begin
    raise EAudio.Create('Journal declared span count does not match records');
  end;
end;

function TAdmittedPitchJournal.GetSourceCount: Integer;
begin
  Result := Length(FSources);
end;

constructor TAdmittedPitchJournal.Create(const AOrder: Integer;
  const APolicyIdentity: String);
begin
  inherited Create;
  if (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Journal order must be 1..4');
  end;
  if APolicyIdentity <> AdmittedPitchPolicyIdentity then
  begin
    raise EAudio.Create('Journal policy identity is unsupported');
  end;
  FPolicyIdentity := APolicyIdentity;
  FOrder := AOrder;
end;

procedure TAdmittedPitchJournal.ValidateAndCount(const ASources: TAdmittedNoteSources;
  out ASpanCount, ATrainingRunCount: Integer);
var
  LIndex: Integer;
  LOther: Integer;
  LSpanIndex: Integer;
  LSource: TAdmittedNoteSource;
  LSpan: TAdmittedNoteSpan;
  LPriorEnd: Int64;
  LStartMs: Integer;
  LEndMs: Integer;
begin
  ASpanCount := 0;
  ATrainingRunCount := 0;
  if Length(ASources) > MaximumAdmittedSources then
  begin
    raise EAudio.Create('Journal source count exceeds 32-source bound');
  end;
  for LIndex := 0 to High(ASources) do
  begin
    LSource := ASources[LIndex];
    if not ValidIdentity(LSource.GroupId) or not ValidIdentity(LSource.RecordingId) or
      not ValidIdentity(LSource.SourceAnnotationId) or
      not ValidIdentity(LSource.SourceAnnotationPublisher) or
      not ValidIdentity(LSource.SourceAnnotationMethod) or
      not ValidSha256(LSource.SourceSha256) or
      not ValidSha256(LSource.SourceAnnotationSha256) then
    begin
      raise EAudio.Create('Journal contribution has invalid source or evidence identity');
    end;
    if (LSource.SampleRate < 1000) or (LSource.SampleRate > 384000) or
      (LSource.SourceFrameCount < 1) or (LSource.SourceFrameCount > High(Integer)) then
    begin
      raise EAudio.Create('Journal contribution has invalid source geometry');
    end;
    if (LIndex > 0) and not SourceKeyLess(ASources[LIndex - 1], LSource) then
    begin
      raise EAudio.Create('Journal sources are not in strict canonical order');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      if SameSource(ASources[LOther], LSource) then
      begin
        raise EAudio.Create('Journal contains duplicate contribution');
      end;
      if (ASources[LOther].RecordingId = LSource.RecordingId) or
        (ASources[LOther].SourceSha256 = LSource.SourceSha256) or
        (ASources[LOther].SourceAnnotationId = LSource.SourceAnnotationId) or
        (ASources[LOther].SourceAnnotationSha256 = LSource.SourceAnnotationSha256) then
      begin
        raise EAudio.Create('Journal contribution conflicts with a bound source identity');
      end;
    end;
    if Length(LSource.Spans) > MaximumAdmittedInputSpans - ASpanCount then
    begin
      raise EAudio.Create('Journal spans exceed 65536-span bound');
    end;
    Inc(ASpanCount, Length(LSource.Spans));
    LPriorEnd := -1;
    for LSpanIndex := 0 to High(LSource.Spans) do
    begin
      LSpan := LSource.Spans[LSpanIndex];
      if not (LSpan.Kind in [pskPitch, pskSilence, pskUnknown]) or
        (LSpan.StartFrame < 0) or (LSpan.EndFrame <= LSpan.StartFrame) or
        (LSpan.EndFrame > LSource.SourceFrameCount) or
        ((LSpanIndex > 0) and (LSpan.StartFrame < LPriorEnd)) then
      begin
        raise EAudio.Create('Journal spans must be ordered positive ranges inside source geometry');
      end;
      if LSpan.Kind = pskPitch then
      begin
        if (LSpan.Note < 0) or (LSpan.Note > 127) then
        begin
          raise EAudio.Create('Journal pitch note must be MIDI 0..127');
        end;
        LStartMs := RoundAdmittedFrameToMilliseconds(LSpan.StartFrame, LSource.SampleRate);
        LEndMs := RoundAdmittedFrameToMilliseconds(LSpan.EndFrame, LSource.SampleRate);
        if (LEndMs <= LStartMs) or (LEndMs - LStartMs > 1048576) then
        begin
          raise EAudio.Create('Journal pitch collapses or exceeds duration bound');
        end;
      end
      else
      begin
        if LSpan.Note <> -1 then
        begin
          raise EAudio.Create('Journal silence and unknown spans require note -1');
        end;
        if LSpan.Kind = pskSilence then
        begin
          LStartMs := RoundAdmittedFrameToMilliseconds(LSpan.StartFrame, LSource.SampleRate);
          LEndMs := RoundAdmittedFrameToMilliseconds(LSpan.EndFrame, LSource.SampleRate);
          if (LEndMs <= LStartMs) or (LEndMs - LStartMs > 1048576) then
          begin
            raise EAudio.Create('Journal silence collapses or exceeds duration bound');
          end;
        end;
      end;
      LPriorEnd := LSpan.EndFrame;
    end;
    LSpanIndex := 0;
    while LSpanIndex < Length(LSource.Spans) do
    begin
      if LSource.Spans[LSpanIndex].Kind = pskUnknown then
      begin
        Inc(LSpanIndex);
        Continue;
      end;
      Inc(ATrainingRunCount);
      Inc(LSpanIndex);
      while (LSpanIndex < Length(LSource.Spans)) and
        (LSource.Spans[LSpanIndex].Kind <> pskUnknown) and
        (LSource.Spans[LSpanIndex].StartFrame = LSource.Spans[LSpanIndex - 1].EndFrame) do
      begin
        Inc(LSpanIndex);
      end;
    end;
  end;
  if ATrainingRunCount > MaximumAdmittedTrainingRuns then
  begin
    raise EAudio.Create('Journal exceeds 32 independent training-run bound');
  end;
end;

procedure TAdmittedPitchJournal.AppendSource(const ASource: TAdmittedNoteSource;
  const APolicyIdentity: String);
var
  LCandidate: TAdmittedNoteSources;
  LIndex: Integer;
  LInsertAt: Integer;
  LSpanCount: Integer;
  LRunCount: Integer;
  LCopy: TAdmittedNoteSource;
begin
  if APolicyIdentity <> FPolicyIdentity then
  begin
    raise EAudio.Create('Append policy does not match journal policy identity');
  end;
  LCopy := CopySource(ASource);
  LCandidate := CopySources;
  for LIndex := 0 to High(LCandidate) do
  begin
    if SameSource(LCandidate[LIndex], LCopy) then
    begin
      Exit;
    end;
  end;
  SetLength(LCandidate, Length(LCandidate) + 1);
  LInsertAt := High(LCandidate);
  while (LInsertAt > 0) and SourceKeyLess(LCopy, LCandidate[LInsertAt - 1]) do
  begin
    LCandidate[LInsertAt] := LCandidate[LInsertAt - 1];
    Dec(LInsertAt);
  end;
  LCandidate[LInsertAt] := LCopy;
  ValidateAndCount(LCandidate, LSpanCount, LRunCount);
  FSources := LCandidate;
  FSpanCount := LSpanCount;
  FTrainingRunCount := LRunCount;
end;

function TAdmittedPitchJournal.EncodeText: UTF8String;
var
  LIndex: Integer;
  LSpanIndex: Integer;
  LSource: TAdmittedNoteSource;
  LSpan: TAdmittedNoteSpan;
  LBuilder: TMemoryStream;
begin
  LBuilder := TMemoryStream.Create;
  try
    WriteLine(LBuilder, 'pythian-admitted-pitch-journal'#9 + '1');
    WriteLine(LBuilder, 'policy'#9 + UTF8String(FPolicyIdentity));
    WriteLine(LBuilder, 'order'#9 + UTF8String(IntToStr(FOrder)));
    WriteLine(LBuilder, 'source_count'#9 + UTF8String(IntToStr(Length(FSources))));
    WriteLine(LBuilder, 'span_count'#9 + UTF8String(IntToStr(FSpanCount)));
    for LIndex := 0 to High(FSources) do
    begin
      LSource := FSources[LIndex];
      WriteLine(LBuilder, SourceLine(LSource));
      for LSpanIndex := 0 to High(LSource.Spans) do
      begin
        LSpan := LSource.Spans[LSpanIndex];
        WriteLine(LBuilder, 'span'#9 + UTF8String(IntToStr(Ord(LSpan.Kind))) + #9 +
          UTF8String(IntToStr(LSpan.Note)) + #9 +
          UTF8String(IntToStr(LSpan.StartFrame)) + #9 +
          UTF8String(IntToStr(LSpan.EndFrame)));
      end;
    end;
    SetLength(Result, LBuilder.Size);
    if Length(Result) > 0 then
    begin
      LBuilder.Position := 0;
      LBuilder.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LBuilder.Free;
  end;
end;

procedure TAdmittedPitchJournal.ReplaceFromText(const AText: UTF8String);
var
  LPolicy: String;
  LOrder: Integer;
  LSources: TAdmittedNoteSources;
  LSpanCount: Integer;
  LRunCount: Integer;
  LCandidate: TAdmittedPitchJournal;
  LCanonical: UTF8String;
  LDiffIndex: Integer;
begin
  LSources := ParseText(AText, LPolicy, LOrder);
  if (LPolicy <> FPolicyIdentity) or (LOrder <> FOrder) then
  begin
    raise EAudio.Create('Journal policy or model order conflicts with receiver');
  end;
  LCandidate := TAdmittedPitchJournal.Create(FOrder, FPolicyIdentity);
  try
    LCandidate.FSources := LSources;
    LCandidate.ValidateAndCount(LCandidate.FSources, LSpanCount, LRunCount);
    LCandidate.FSpanCount := LSpanCount;
    LCandidate.FTrainingRunCount := LRunCount;
    LCanonical := LCandidate.EncodeText;
    if LCanonical <> AText then
    begin
      LDiffIndex := 1;
      while (LDiffIndex <= Length(LCanonical)) and (LDiffIndex <= Length(AText)) and
        (LCanonical[LDiffIndex] = AText[LDiffIndex]) do
      begin
        Inc(LDiffIndex);
      end;
      raise EAudio.CreateFmt('Journal text is not canonical at byte %d (canonical=%d bytes, input=%d bytes)',
        [LDiffIndex, Length(LCanonical), Length(AText)]);
    end;
    FSources := LCandidate.FSources;
    FSpanCount := LSpanCount;
    FTrainingRunCount := LRunCount;
  finally
    LCandidate.Free;
  end;
end;

function TAdmittedPitchJournal.CopySources: TAdmittedNoteSources;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(FSources));
  for LIndex := 0 to High(FSources) do
  begin
    Result[LIndex] := CopySource(FSources[LIndex]);
  end;
end;

function TAdmittedPitchJournal.Rebuild: TAdmittedPitchDurationModel;
var
  LSources: TAdmittedNoteSources;
begin
  LSources := CopySources;
  Result := LearnAdmittedPitchDurationModel(LSources, FOrder);
end;

function TAdmittedPitchJournal.JournalSha256: String;
begin
  Result := HashText(EncodeText);
end;

end.
