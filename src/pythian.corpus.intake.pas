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
unit pythian.corpus.intake;

{$mode delphi}
{$H+}

interface

const
  CorpusIntakeVersion = 1;
  MaximumIntakeSources = 32;
  MaximumIntakeRanges = 4096;
  MaximumIntakeFrame: Int64 = 9007199254740991;

type
  TCorpusPartition = (cpTraining, cpDevelopment, cpEvaluation);
  TCorpusExposures = set of TCorpusPartition;
  TCorpusFamily = record
    Id: UTF8String;
    WorkId: UTF8String;
    IdentityEvidence: UTF8String;
    Partition: TCorpusPartition;
    Verified: Boolean;
    PreviouslyUsed: Boolean;
    PriorExposure: TCorpusExposures;
  end;
  TCorpusFamilies = array of TCorpusFamily;
  TCorpusIntakeSource = record
    Id: UTF8String;
    Path: UTF8String;
    Sha256: String;
    RecordingId: UTF8String;
    Family: Integer;
    SampleRate: Integer;
    Channels: Integer;
    FrameCount: Int64;
    Acquisition: UTF8String;
    LicenseNotice: UTF8String;
    PreparationPolicy: UTF8String;
    PreparationSha256: String;
    PreparationAccepted: Boolean;
    PeakCeiling: Double;
    ParentGain: Double;
    { -1 is an original WAV. Otherwise the parent precedes this source, has
      the same frame clock/channel layout, and [first,end) maps exactly to
      this complete derivative. Rate changes/time warps are unsupported. }
    Parent: Integer;
    ParentFirstFrame: Int64;
    ParentEndFrame: Int64;
    { Empty means unknown song boundaries. A default whole-WAV range may be
      admitted only when the caller supplies this identity/evidence pair. }
    SingleSongId: UTF8String;
    SongEvidence: UTF8String;
  end;
  TCorpusIntakeSources = array of TCorpusIntakeSource;
  TCorpusIntakeRange = record
    Source: Integer;
    FirstFrame: Int64;
    EndFrame: Int64;
    SongId: UTF8String;
    BoundaryEvidence: UTF8String;
    Multiplicity: Integer;
  end;
  TCorpusIntakeRanges = array of TCorpusIntakeRange;
  TCorpusIntakeDefinition = record
    StyleId: UTF8String;
    Families: TCorpusFamilies;
    Sources: TCorpusIntakeSources;
    Ranges: TCorpusIntakeRanges;
  end;
  TCorpusIntakeCoverage = record
    UniqueSeconds: array[TCorpusPartition] of Double;
    UnknownBoundarySeconds: array[TCorpusPartition] of Double;
    DeclaredVerifiedGroups: array[TCorpusPartition] of Integer;
  end;

  { Detached immutable declarations. No file access, WFC, authentication or
    automatic recording-family recognition. Caller evidence must cover all
    related works/masters, parent mappings and exposure outside this plan. }
  TCorpusIntakePlan = class
  private
    FDefinition: TCorpusIntakeDefinition;
    procedure Validate;
  public
    constructor Create(const ADefinition: TCorpusIntakeDefinition);
    function CopyDefinition: TCorpusIntakeDefinition;
    procedure OriginalRange(const ARange: Integer; out AOriginal: Integer;
      out AFirstFrame, AEndFrame: Int64);
    function Coverage: TCorpusIntakeCoverage;
    { Unknown song spans are excluded from training. Exact duplicate ranges
      coalesce once; derivative/partial overlap rejects. Multiplicity is the
      explicit weight, never inferred from duplicate rows. }
    function TrainingRanges: TCorpusIntakeRanges;
  end;

{ Compare a retained complete identity/exposure ledger before later reuse.
  Known source/original/recording/work matches cannot change family/split,
  lose verified identity or erase previous exposure. Unrelated additions are
  allowed. This cannot discover a caller's concealed alias or omitted ledger. }
procedure RequireIntakeHistory(const APrevious, ACurrent: TCorpusIntakePlan);
function CorpusPartitionName(const APartition: TCorpusPartition): String;

implementation

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.corpus;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure Text(const AValue: UTF8String; const ARequired: Boolean = True);
begin
  ValidateCorpusText(AValue);
  Require((not ARequired or (Length(AValue) > 0)) and (Trim(AValue) = AValue),
    'Intake requires exact bounded text without surrounding whitespace');
end;

procedure Digest(const AValue: String);
var
  LIndex: Integer;
begin
  Require(Length(AValue) = 64, 'Intake requires a SHA256 identity');
  for LIndex := 1 to Length(AValue) do
  begin
    Require(AValue[LIndex] in ['0'..'9', 'a'..'f'], 'Intake SHA256 must be lowercase');
  end;
end;

function CorpusPartitionName(const APartition: TCorpusPartition): String;
begin
  case APartition of
    cpTraining: Result := 'training';
    cpDevelopment: Result := 'development';
    cpEvaluation: Result := 'evaluation';
  else
    raise EAudio.Create('Unknown corpus partition');
  end;
end;

constructor TCorpusIntakePlan.Create(const ADefinition: TCorpusIntakeDefinition);
var
  LIndex: Integer;
begin
  inherited Create;
  FDefinition := ADefinition;
  FDefinition.Families := Copy(ADefinition.Families);
  FDefinition.Sources := Copy(ADefinition.Sources);
  FDefinition.Ranges := Copy(ADefinition.Ranges);
  if Length(FDefinition.Ranges) = 0 then
  begin
    SetLength(FDefinition.Ranges, Length(FDefinition.Sources));
    for LIndex := 0 to High(FDefinition.Sources) do
    begin
      FDefinition.Ranges[LIndex].Source := LIndex;
      FDefinition.Ranges[LIndex].EndFrame := FDefinition.Sources[LIndex].FrameCount;
      FDefinition.Ranges[LIndex].SongId := FDefinition.Sources[LIndex].SingleSongId;
      FDefinition.Ranges[LIndex].BoundaryEvidence := FDefinition.Sources[LIndex].SongEvidence;
      FDefinition.Ranges[LIndex].Multiplicity := 1;
    end;
  end;
  Validate;
end;

function TCorpusIntakePlan.CopyDefinition: TCorpusIntakeDefinition;
begin
  Result := FDefinition;
  Result.Families := Copy(FDefinition.Families);
  Result.Sources := Copy(FDefinition.Sources);
  Result.Ranges := Copy(FDefinition.Ranges);
end;

procedure TCorpusIntakePlan.Validate;
var
  LIndex: Integer;
  LOther: Integer;
  LFamily: TCorpusFamily;
  LSource: TCorpusIntakeSource;
  LParent: TCorpusIntakeSource;
  LRange: TCorpusIntakeRange;
begin
  Text(FDefinition.StyleId, False);
  Require((Length(FDefinition.Families) >= 1) and
    (Length(FDefinition.Families) <= MaximumIntakeSources) and
    (Length(FDefinition.Sources) >= 1) and
    (Length(FDefinition.Sources) <= MaximumIntakeSources) and
    (Length(FDefinition.Ranges) >= 1) and
    (Length(FDefinition.Ranges) <= MaximumIntakeRanges), 'Intake count exceeds its bounds');
  for LIndex := 0 to High(FDefinition.Families) do
  begin
    LFamily := FDefinition.Families[LIndex];
    Text(LFamily.Id);
    Text(LFamily.WorkId);
    Text(LFamily.IdentityEvidence);
    Require((Ord(LFamily.Partition) >= Ord(Low(TCorpusPartition))) and
      (Ord(LFamily.Partition) <= Ord(High(TCorpusPartition))), 'Unknown intake partition');
    Require(LFamily.Verified or (LFamily.Partition = cpDevelopment),
      'Unknown family identity is development only');
    Require((LFamily.Partition <> cpEvaluation) or
      (not LFamily.PreviouslyUsed and
      (LFamily.PriorExposure * [cpTraining, cpDevelopment] = [])),
      'Exposed recording family cannot become untouched evaluation');
    for LOther := 0 to LIndex - 1 do
    begin
      Require((LFamily.Id <> FDefinition.Families[LOther].Id) and
        (LFamily.WorkId <> FDefinition.Families[LOther].WorkId),
        'A declared work/master family has contradictory or duplicate registration');
    end;
  end;
  for LIndex := 0 to High(FDefinition.Sources) do
  begin
    LSource := FDefinition.Sources[LIndex];
    Text(LSource.Id);
    Text(LSource.Path);
    Text(LSource.RecordingId);
    Text(LSource.Acquisition);
    Text(LSource.LicenseNotice);
    Text(LSource.PreparationPolicy);
    Text(LSource.SingleSongId, False);
    Text(LSource.SongEvidence, False);
    Digest(LSource.Sha256);
    Digest(LSource.PreparationSha256);
    ValidateAudioFormat(LSource.SampleRate, LSource.Channels);
    Require((LSource.Family >= 0) and (LSource.Family < Length(FDefinition.Families)) and
      (LSource.FrameCount > 0) and (LSource.FrameCount <= MaximumIntakeFrame),
      'Intake source family or frame geometry is invalid');
    RequireFinite(LSource.PeakCeiling, 'Intake preparation peak ceiling');
    Require((LSource.PeakCeiling > 0) and (LSource.PeakCeiling < 1),
      'Intake preparation requires declared unclipped headroom below unity');
    RequireFinite(LSource.ParentGain, 'Intake parent gain');
    Require((LSource.ParentGain > 0) and (LSource.ParentGain <= 16),
      'Intake supports only positive uniform parent gain at most sixteen');
    Require((LSource.SingleSongId = '') = (LSource.SongEvidence = ''),
      'Known whole-recording song requires its boundary evidence');
    Require((LSource.Parent >= -1) and (LSource.Parent < LIndex),
      'Intake parents must be original or earlier registered WAVs');
    if LSource.Parent = -1 then
    begin
      Require((LSource.ParentFirstFrame = 0) and
        (LSource.ParentEndFrame = LSource.FrameCount) and (LSource.ParentGain = 1),
        'Original source owns its complete zero-based frame clock');
    end
    else
    begin
      LParent := FDefinition.Sources[LSource.Parent];
      Require((LSource.SampleRate = LParent.SampleRate) and
        (LSource.Channels = LParent.Channels) and
        (LSource.ParentFirstFrame >= 0) and
        (LSource.ParentEndFrame <= LParent.FrameCount) and
        (LSource.ParentEndFrame - LSource.ParentFirstFrame = LSource.FrameCount) and
        (LSource.Family = LParent.Family) and
        (LSource.RecordingId = LParent.RecordingId),
        'Unsupported or contradictory prepared-source frame/parent mapping');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      LParent := FDefinition.Sources[LOther];
      Require(LSource.Id <> LParent.Id, 'Duplicate intake source ID');
      if (LSource.SingleSongId <> '') and (LSource.SingleSongId = LParent.SingleSongId) then
        Require(LSource.Family = LParent.Family,
          'Same declared whole song cannot acquire independent work families');
      if (LSource.Sha256 = LParent.Sha256) or
        (LSource.RecordingId = LParent.RecordingId) then
      begin
        Require(LSource.Family = LParent.Family,
          'Recording/byte aliases cannot acquire another family or partition');
      end;
      if LSource.Sha256 = LParent.Sha256 then
      begin
        Require((LSource.SampleRate = LParent.SampleRate) and
          (LSource.RecordingId = LParent.RecordingId) and
          (LSource.Channels = LParent.Channels) and
          (LSource.FrameCount = LParent.FrameCount) and
          (LSource.Parent = LParent.Parent) and
          (LSource.ParentFirstFrame = LParent.ParentFirstFrame) and
          (LSource.ParentGain = LParent.ParentGain) and
          (LSource.PreparationSha256 = LParent.PreparationSha256),
          'Same bytes have contradictory geometry/preparation/coordinates');
      end;
      if (LSource.Parent = -1) and (LParent.Parent = -1) and
        (LSource.RecordingId = LParent.RecordingId) then
      begin
        Require((LSource.SampleRate = LParent.SampleRate) and
          (LSource.FrameCount = LParent.FrameCount),
          'Alternate masters require a supported common original frame clock');
      end;
    end;
  end;
  for LIndex := 0 to High(FDefinition.Ranges) do
  begin
    LRange := FDefinition.Ranges[LIndex];
    Require((LRange.Source >= 0) and (LRange.Source < Length(FDefinition.Sources)),
      'Intake range references an unregistered source');
    LSource := FDefinition.Sources[LRange.Source];
    Require((LRange.FirstFrame >= 0) and (LRange.EndFrame > LRange.FirstFrame) and
      (LRange.EndFrame <= LSource.FrameCount) and
      (LRange.Multiplicity >= 1) and (LRange.Multiplicity <= 64),
      'Intake range or explicit training weight is outside its bounds');
    Text(LRange.SongId, False);
    Text(LRange.BoundaryEvidence, False);
    Require((LRange.SongId = '') = (LRange.BoundaryEvidence = ''),
      'Song ranges require explicit evidence; unknowns have no invented labels');
    Require((LSource.SingleSongId = '') or (LRange.SongId = LSource.SingleSongId),
      'Explicit song range contradicts the declared whole-recording song');
    for LOther := 0 to LIndex - 1 do
    begin
      if (LRange.SongId <> '') and
        (LRange.SongId = FDefinition.Ranges[LOther].SongId) then
      begin
        Require(LSource.Family =
          FDefinition.Sources[FDefinition.Ranges[LOther].Source].Family,
          'Same declared song cannot span independent families or partitions');
      end;
    end;
  end;
end;

procedure TCorpusIntakePlan.OriginalRange(const ARange: Integer;
  out AOriginal: Integer; out AFirstFrame, AEndFrame: Int64);
var
  LRange: TCorpusIntakeRange;
begin
  Require((ARange >= 0) and (ARange < Length(FDefinition.Ranges)),
    'Intake range index is outside the plan');
  LRange := FDefinition.Ranges[ARange];
  AOriginal := LRange.Source;
  AFirstFrame := LRange.FirstFrame;
  AEndFrame := LRange.EndFrame;
  while FDefinition.Sources[AOriginal].Parent >= 0 do
  begin
    Inc(AFirstFrame, FDefinition.Sources[AOriginal].ParentFirstFrame);
    Inc(AEndFrame, FDefinition.Sources[AOriginal].ParentFirstFrame);
    AOriginal := FDefinition.Sources[AOriginal].Parent;
  end;
end;

function TCorpusIntakePlan.Coverage: TCorpusIntakeCoverage;
type
  TInterval = record
    Recording: UTF8String;
    Rate: Integer;
    Partition: TCorpusPartition;
    FirstFrame: Int64;
    EndFrame: Int64;
    Unknown: Boolean;
  end;
var
  LIntervals: array of TInterval;
  LSwap: TInterval;
  LIndex: Integer;
  LOther: Integer;
  LOriginal: Integer;
  LFirst: Int64;
  LEnd: Int64;
  LCursor: Int64;
  LSeconds: Double;
  LFamily: TCorpusFamily;
  LUnknownPass: Integer;
begin
  Result := Default(TCorpusIntakeCoverage);
  SetLength(LIntervals, Length(FDefinition.Ranges));
  for LIndex := 0 to High(LIntervals) do
  begin
    OriginalRange(LIndex, LOriginal, LFirst, LEnd);
    LIntervals[LIndex].Recording := FDefinition.Sources[LOriginal].RecordingId;
    LIntervals[LIndex].Rate := FDefinition.Sources[LOriginal].SampleRate;
    LIntervals[LIndex].Partition :=
      FDefinition.Families[FDefinition.Sources[LOriginal].Family].Partition;
    LIntervals[LIndex].FirstFrame := LFirst;
    LIntervals[LIndex].EndFrame := LEnd;
    LIntervals[LIndex].Unknown := FDefinition.Ranges[LIndex].SongId = '';
  end;
  for LIndex := 1 to High(LIntervals) do
  begin
    LOther := LIndex;
    while (LOther > 0) and
      ((LIntervals[LOther].Recording < LIntervals[LOther - 1].Recording) or
      ((LIntervals[LOther].Recording = LIntervals[LOther - 1].Recording) and
      (LIntervals[LOther].FirstFrame < LIntervals[LOther - 1].FirstFrame))) do
    begin
      LSwap := LIntervals[LOther];
      LIntervals[LOther] := LIntervals[LOther - 1];
      LIntervals[LOther - 1] := LSwap;
      Dec(LOther);
    end;
  end;
  for LUnknownPass := 0 to 1 do
  begin
    LCursor := 0;
    for LIndex := 0 to High(LIntervals) do
    begin
      if (LIndex = 0) or
        (LIntervals[LIndex].Recording <> LIntervals[LIndex - 1].Recording) then
      begin
        LCursor := 0;
      end;
      if (LUnknownPass = 1) and not LIntervals[LIndex].Unknown then
      begin
        Continue;
      end;
      LFirst := Max(LIntervals[LIndex].FirstFrame, LCursor);
      LEnd := LIntervals[LIndex].EndFrame;
      if LEnd > LFirst then
      begin
        LSeconds := (LEnd - LFirst) / LIntervals[LIndex].Rate;
        if LUnknownPass = 0 then
        begin
          Result.UniqueSeconds[LIntervals[LIndex].Partition] :=
            Result.UniqueSeconds[LIntervals[LIndex].Partition] + LSeconds;
        end
        else
        begin
          Result.UnknownBoundarySeconds[LIntervals[LIndex].Partition] :=
            Result.UnknownBoundarySeconds[LIntervals[LIndex].Partition] + LSeconds;
        end;
      end;
      LCursor := Max(LCursor, LEnd);
    end;
  end;
  for LIndex := 0 to High(FDefinition.Families) do
  begin
    LFamily := FDefinition.Families[LIndex];
    if not LFamily.Verified then
    begin
      Continue;
    end;
    for LOther := 0 to High(FDefinition.Ranges) do
    begin
      if FDefinition.Sources[FDefinition.Ranges[LOther].Source].Family = LIndex then
      begin
        Inc(Result.DeclaredVerifiedGroups[LFamily.Partition]);
        Break;
      end;
    end;
  end;
end;

function TCorpusIntakePlan.TrainingRanges: TCorpusIntakeRanges;
var
  LIndex: Integer;
  LOther: Integer;
  LOriginal: Integer;
  LPreviousOriginal: Integer;
  LFirst: Int64;
  LEnd: Int64;
  LPreviousFirst: Int64;
  LPreviousEnd: Int64;
  LDuplicate: Boolean;
  LRange: TCorpusIntakeRange;
begin
  Result := nil;
  for LIndex := 0 to High(FDefinition.Ranges) do
  begin
    LRange := FDefinition.Ranges[LIndex];
    if FDefinition.Families[FDefinition.Sources[LRange.Source].Family].Partition <>
      cpTraining then
    begin
      Continue;
    end;
    if LRange.SongId = '' then
    begin
      Continue;
    end;
    Require(FDefinition.Sources[LRange.Source].PreparationAccepted,
      'Training requires admitted preparation and known song boundaries');
    OriginalRange(LIndex, LOriginal, LFirst, LEnd);
    for LOther := 0 to High(FDefinition.Ranges) do
    begin
      if FDefinition.Ranges[LOther].SongId <> '' then Continue;
      OriginalRange(LOther, LPreviousOriginal, LPreviousFirst, LPreviousEnd);
      Require((FDefinition.Sources[LOriginal].RecordingId <>
        FDefinition.Sources[LPreviousOriginal].RecordingId) or
        (LFirst >= LPreviousEnd) or (LPreviousFirst >= LEnd),
        'Known training song overlaps a declared unknown boundary span');
    end;
    LDuplicate := False;
    for LOther := 0 to LIndex - 1 do
    begin
      if FDefinition.Families[FDefinition.Sources[FDefinition.Ranges[LOther].Source].Family].Partition <>
        cpTraining then
      begin
        Continue;
      end;
      if FDefinition.Ranges[LOther].SongId = '' then Continue;
      OriginalRange(LOther, LPreviousOriginal, LPreviousFirst, LPreviousEnd);
      if (FDefinition.Sources[LOriginal].RecordingId =
        FDefinition.Sources[LPreviousOriginal].RecordingId) and
        (LFirst < LPreviousEnd) and (LPreviousFirst < LEnd) then
      begin
        Require((FDefinition.Sources[LRange.Source].Sha256 =
          FDefinition.Sources[FDefinition.Ranges[LOther].Source].Sha256) and
          (LFirst = LPreviousFirst) and (LEnd = LPreviousEnd) and
          (LRange.SongId = FDefinition.Ranges[LOther].SongId) and
          (LRange.Multiplicity = FDefinition.Ranges[LOther].Multiplicity),
          'Overlapping training originals require one range with an explicit weight');
        LDuplicate := True;
      end;
    end;
    if not LDuplicate then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := LRange;
    end;
  end;
  Require(Length(Result) > 0, 'Intake training partition is empty');
end;

procedure RequireIntakeHistory(const APrevious, ACurrent: TCorpusIntakePlan);
var
  LOld: TCorpusIntakeDefinition;
  LNew: TCorpusIntakeDefinition;
  LIndex: Integer;
  LOther: Integer;
  LSource: Integer;
  LOldSource: Integer;
  LMatches: Boolean;
  LOldOriginal, LNewOriginal: Integer;
  LOldFirst, LNewFirst: Int64;
begin
  Require((APrevious <> nil) and (ACurrent <> nil), 'Intake history requires both ledgers');
  LOld := APrevious.CopyDefinition;
  LNew := ACurrent.CopyDefinition;
  for LIndex := 0 to High(LNew.Families) do
  begin
    for LOther := 0 to High(LOld.Families) do
    begin
      LMatches := (LNew.Families[LIndex].Id = LOld.Families[LOther].Id) or
        (LNew.Families[LIndex].WorkId = LOld.Families[LOther].WorkId);
      for LSource := 0 to High(LNew.Sources) do
      begin
        if LNew.Sources[LSource].Family <> LIndex then
        begin
          Continue;
        end;
        for LOldSource := 0 to High(LOld.Sources) do
        begin
          if LNew.Sources[LSource].Sha256 = LOld.Sources[LOldSource].Sha256 then
          begin
            LOldOriginal := LOldSource; LOldFirst := 0;
            while LOld.Sources[LOldOriginal].Parent >= 0 do
            begin
              Inc(LOldFirst, LOld.Sources[LOldOriginal].ParentFirstFrame);
              LOldOriginal := LOld.Sources[LOldOriginal].Parent;
            end;
            LNewOriginal := LSource; LNewFirst := 0;
            while LNew.Sources[LNewOriginal].Parent >= 0 do
            begin
              Inc(LNewFirst, LNew.Sources[LNewOriginal].ParentFirstFrame);
              LNewOriginal := LNew.Sources[LNewOriginal].Parent;
            end;
            Require((LNew.Sources[LSource].RecordingId = LOld.Sources[LOldSource].RecordingId) and
              (LNew.Sources[LSource].SampleRate = LOld.Sources[LOldSource].SampleRate) and
              (LNew.Sources[LSource].Channels = LOld.Sources[LOldSource].Channels) and
              (LNew.Sources[LSource].FrameCount = LOld.Sources[LOldSource].FrameCount) and
              (LNew.Sources[LSource].PreparationSha256 = LOld.Sources[LOldSource].PreparationSha256) and
              (LNew.Sources[LSource].ParentGain = LOld.Sources[LOldSource].ParentGain) and
              (LOldFirst = LNewFirst) and
              (LNew.Sources[LNewOriginal].FrameCount = LOld.Sources[LOldOriginal].FrameCount),
              'Retained exact source bytes cannot change original coordinates or preparation');
          end;
          if (LOld.Sources[LOldSource].Family = LOther) and
            ((LNew.Sources[LSource].Sha256 = LOld.Sources[LOldSource].Sha256) or
            (LNew.Sources[LSource].RecordingId = LOld.Sources[LOldSource].RecordingId)) then
          begin
            LMatches := True;
          end;
        end;
      end;
      if LMatches then
      begin
        Require((LNew.Families[LIndex].Id = LOld.Families[LOther].Id) and
          (LNew.Families[LIndex].WorkId = LOld.Families[LOther].WorkId) and
          (LNew.Families[LIndex].Partition = LOld.Families[LOther].Partition) and
          (not LOld.Families[LOther].PreviouslyUsed or LNew.Families[LIndex].PreviouslyUsed) and
          (LOld.Families[LOther].PriorExposure <= LNew.Families[LIndex].PriorExposure) and
          (not LOld.Families[LOther].Verified or LNew.Families[LIndex].Verified),
          'Intake reuse changes a known family/split or erases identity/exposure');
      end;
    end;
  end;
end;

end.
