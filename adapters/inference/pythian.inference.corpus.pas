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
unit pythian.inference.corpus;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.inference.observation;

const
  InferenceCorpusMaximumEntries = 4096;

type
  TInferenceCorpusEntry = record
    GroupId: String;
    SourceId: String;
    ArtifactFile: String;
    Identity: TInferenceIdentity;
  end;
  TInferenceCorpusEntries = array of TInferenceCorpusEntry;

  { Streams one checksummed artifact at a time. Metadata is copied and
    validated up front; each returned batch belongs only to Entry(Index).
    Caller must retain the returned batch until finished with it. }
  TInferenceCorpusReader = class
  strict private
    FEntries: TInferenceCorpusEntries;
    FNextEntry: Integer;
    FActiveEntry: Integer;
    FFileReader: TInferenceFileReader;
    procedure ValidateEntries;
  public
    constructor Create(const AEntries: TInferenceCorpusEntries);
    destructor Destroy; override;
    function Entry(const AIndex: Integer): TInferenceCorpusEntry;
    { Returns at most the entry's declared batch size (max 32); false means
      all entries were consumed. A batch never crosses source/scope artifacts. }
    function ReadBatch(out AEntryIndex: Integer;
      out ABatch: TInferenceBatch): Boolean;
    function EntryCount: Integer;
  end;

implementation

uses
  pythian.resample.stream;

function SameRequestSettings(const ALeft, ARight: TInferenceIdentity): Boolean;
begin
  Result := (ALeft.Estimator = ARight.Estimator) and
    (ALeft.Request.SourceHash = ARight.Request.SourceHash) and
    (ALeft.Request.Policy = ARight.Request.Policy) and
    (ALeft.Request.Channel = ARight.Request.Channel) and
    (ALeft.Request.InputStart16k = ARight.Request.InputStart16k) and
    (ALeft.Request.InputEnd16k = ARight.Request.InputEnd16k) and
    (ALeft.Request.Hop16k = ARight.Request.Hop16k) and
    (ALeft.Request.BatchSize = ARight.Request.BatchSize) and
    (ALeft.SourceRate = ARight.SourceRate) and
    (ALeft.SourceChannels = ARight.SourceChannels) and
    (ALeft.SourceFrames = ARight.SourceFrames);
end;

procedure ValidateLabel(const ALabel, ADescription: String);
var
  LCharacter: Char;
begin
  if (Length(ALabel) < 1) or (Length(ALabel) > 128) then
    raise EAudio.Create(ADescription + ' must contain 1..128 characters');
  for LCharacter in ALabel do
    if (Ord(LCharacter) < 33) or (Ord(LCharacter) > 126) then
      raise EAudio.Create(ADescription + ' contains unsupported characters');
end;

constructor TInferenceCorpusReader.Create(
  const AEntries: TInferenceCorpusEntries);
begin
  inherited Create;
  if (Length(AEntries) < 1) or
    (Length(AEntries) > InferenceCorpusMaximumEntries) then
    raise EAudio.Create('Inference corpus entry count is outside 1..4096');
  FEntries := Copy(AEntries);
  FNextEntry := 0;
  FActiveEntry := -1;
  ValidateEntries;
end;

destructor TInferenceCorpusReader.Destroy;
begin
  FFileReader.Free;
  inherited Destroy;
end;

function TInferenceCorpusReader.Entry(const AIndex: Integer): TInferenceCorpusEntry;
begin
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
    raise EAudio.Create('Inference corpus entry index is out of range');
  Result := FEntries[AIndex];
end;

function TInferenceCorpusReader.EntryCount: Integer;
begin
  Result := Length(FEntries);
end;

procedure TInferenceCorpusReader.ValidateEntries;
var
  LIndex, LPrior: Integer;
  LEntry, LPriorEntry: TInferenceCorpusEntry;
  LSourceEnd: Int64;
  LSourceId: String;
  LGroupId: String;
  LGroupClosed, LSourceClosed: TStringList;
  LSeenPaths: TStringList;
  LExpectedSourceFrames: Int64;
begin
  LGroupClosed := TStringList.Create;
  LSourceClosed := TStringList.Create;
  LSeenPaths := TStringList.Create;
  try
    LGroupClosed.CaseSensitive := True;
    LSourceClosed.CaseSensitive := True;
    LSeenPaths.CaseSensitive := False;
    LSourceId := '';
    LGroupId := '';
    LSourceEnd := -1;
    for LIndex := 0 to High(FEntries) do
    begin
      LEntry := FEntries[LIndex];
      ValidateLabel(LEntry.GroupId, 'Inference group ID');
      ValidateLabel(LEntry.SourceId, 'Inference source ID');
      if LEntry.ArtifactFile = '' then
        raise EAudio.Create('Inference artifact path is empty');
      if LSeenPaths.IndexOf(ExpandFileName(LEntry.ArtifactFile)) >= 0 then
        raise EAudio.Create('Inference corpus repeats an artifact path');
      LSeenPaths.Add(ExpandFileName(LEntry.ArtifactFile));
      { This validates estimator, fixed policy, source geometry, expected count,
        supported native rate and the exact 16-kHz source-clock extent. }
      InferenceIdentityText(LEntry.Identity);
      if LEntry.Identity.Estimator <> InferenceEstimator then
        raise EAudio.Create('Inference corpus estimator differs from the accepted backend');
      if LEntry.Identity.Request.FirstCenter16k <
        LEntry.Identity.Request.ScopeStart16k then
        raise EAudio.Create('Inference corpus first center precedes its scope');
      if LEntry.Identity.Request.FirstCenter16k < 0 then
        raise EAudio.Create('Inference corpus center is negative');

      if LIndex = 0 then
      begin
        LGroupId := LEntry.GroupId;
        LSourceId := LEntry.SourceId;
        LSourceEnd := LEntry.Identity.Request.ScopeStart16k;
      end
      else
      begin
        LPriorEntry := FEntries[LIndex - 1];
        if (LEntry.GroupId <> LGroupId) then
        begin
          LGroupClosed.Add(LGroupId);
          if LGroupClosed.IndexOf(LEntry.GroupId) >= 0 then
            raise EAudio.Create('Inference group rows are not contiguous');
          LGroupId := LEntry.GroupId;
          LSourceClosed.Add(LSourceId);
          if LSourceClosed.IndexOf(LEntry.SourceId) >= 0 then
            raise EAudio.Create('Inference source rows are not contiguous');
          LSourceId := LEntry.SourceId;
          LSourceEnd := LEntry.Identity.Request.ScopeStart16k;
        end
        else if LEntry.SourceId <> LSourceId then
        begin
          LSourceClosed.Add(LSourceId);
          if LSourceClosed.IndexOf(LEntry.SourceId) >= 0 then
            raise EAudio.Create('Inference source rows are not contiguous');
          LSourceId := LEntry.SourceId;
          LSourceEnd := LEntry.Identity.Request.ScopeStart16k;
        end;

        if (LEntry.GroupId = LPriorEntry.GroupId) and
          (LEntry.SourceId = LPriorEntry.SourceId) then
        begin
          if not SameRequestSettings(LPriorEntry.Identity, LEntry.Identity) then
            raise EAudio.Create('Adjacent inference scopes change source or policy identity');
          if LPriorEntry.Identity.Request.ScopeEnd16k <
            LEntry.Identity.Request.ScopeStart16k then
            raise EAudio.Create('Inference corpus is missing an adjacent source scope');
          if LPriorEntry.Identity.Request.ScopeEnd16k >
            LEntry.Identity.Request.ScopeStart16k then
            raise EAudio.Create('Inference source scopes overlap');
          if ((LPriorEntry.Identity.Request.ScopeEnd16k -
              LPriorEntry.Identity.Request.ScopeStart16k) mod
              LPriorEntry.Identity.Request.Hop16k <> 0) then
            raise EAudio.Create('Non-final scope does not align to the source hop');
          if (LEntry.Identity.Request.FirstCenter16k <>
            LEntry.Identity.Request.ScopeStart16k) then
            raise EAudio.Create('Inference scope center must begin at its scope start');
          LSourceEnd := LEntry.Identity.Request.ScopeStart16k;
        end;
      end;

      if LEntry.Identity.Request.ScopeStart16k <> LSourceEnd then
        raise EAudio.Create('Inference source has a gap or reordered scope');
      if LEntry.Identity.Request.FirstCenter16k <>
        LEntry.Identity.Request.ScopeStart16k then
        raise EAudio.Create('Inference scope center must begin at its scope start');

      { A source ID and SHA are a one-to-one identity; group membership cannot
        change while traversing the caller-provided source-order manifest. }
      for LPrior := 0 to LIndex - 1 do
      begin
        LPriorEntry := FEntries[LPrior];
        if (LPriorEntry.SourceId = LEntry.SourceId) and
          ((LPriorEntry.GroupId <> LEntry.GroupId) or
            (LPriorEntry.Identity.Request.SourceHash <>
              LEntry.Identity.Request.SourceHash)) then
          raise EAudio.Create('Inference source ID changes group or source hash');
        if (LPriorEntry.Identity.Request.SourceHash =
          LEntry.Identity.Request.SourceHash) and
          (LPriorEntry.SourceId <> LEntry.SourceId) then
          raise EAudio.Create('One source hash is assigned to multiple source IDs');
      end;
      LSourceEnd := LEntry.Identity.Request.ScopeEnd16k;
      LExpectedSourceFrames := StreamResampleFrameCount(
        LEntry.Identity.SourceFrames, LEntry.Identity.SourceRate, InferenceRate);
      if LEntry.Identity.Request.ScopeEnd16k > LExpectedSourceFrames then
        raise EAudio.Create('Inference scope exceeds source extent');
      if (LEntry.Identity.Request.InputStart16k <> 0) or
        (LEntry.Identity.Request.InputEnd16k <> LExpectedSourceFrames) then
        raise EAudio.Create('Inference scope must retain full-source waveform support');
    end;

    { Complete per-source coverage is checked after local adjacency. This
      catches a missing leading or trailing scope even for a single artifact. }
    LIndex := 0;
    while LIndex < Length(FEntries) do
    begin
      LEntry := FEntries[LIndex];
      LPrior := LIndex;
      while (LPrior + 1 < Length(FEntries)) and
        (FEntries[LPrior + 1].GroupId = LEntry.GroupId) and
        (FEntries[LPrior + 1].SourceId = LEntry.SourceId) do
        Inc(LPrior);
      LExpectedSourceFrames := StreamResampleFrameCount(
        LEntry.Identity.SourceFrames, LEntry.Identity.SourceRate, InferenceRate);
      if (FEntries[LIndex].Identity.Request.ScopeStart16k <> 0) or
        (FEntries[LPrior].Identity.Request.ScopeEnd16k <> LExpectedSourceFrames) then
        raise EAudio.Create('Inference source scopes do not cover the exact source extent');
      Inc(LIndex, LPrior - LIndex + 1);
    end;
  finally
    LSeenPaths.Free;
    LSourceClosed.Free;
    LGroupClosed.Free;
  end;
end;

function TInferenceCorpusReader.ReadBatch(out AEntryIndex: Integer;
  out ABatch: TInferenceBatch): Boolean;
var
  LRequested: Integer;
begin
  ABatch := nil;
  AEntryIndex := -1;
  while True do
  begin
    if FFileReader = nil then
    begin
      if FNextEntry >= Length(FEntries) then
        Exit(False);
      FActiveEntry := FNextEntry;
      Inc(FNextEntry);
      FFileReader := TInferenceFileReader.Create(
        FEntries[FActiveEntry].ArtifactFile, FEntries[FActiveEntry].Identity);
    end;
    LRequested := FEntries[FActiveEntry].Identity.Request.BatchSize;
    ABatch := FFileReader.ReadBatch(LRequested);
    if Length(ABatch) > 0 then
    begin
      AEntryIndex := FActiveEntry;
      Exit(True);
    end;
    FreeAndNil(FFileReader);
    FActiveEntry := -1;
  end;
end;

end.
