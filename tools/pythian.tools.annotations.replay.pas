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
unit pythian.tools.annotations.replay;

{$mode delphi}
{$H+}

interface

uses
  fpjson;

{ Replays a validated audio-free packet into a fresh catalog that already owns
  the exact original WAVs and source records. Existing matching replay is a
  duplicate; a differing review tree is never overwritten. }
function ReplayReviewedCatalogPacket(const ACatalogRoot,
  APacketPath: String): TJSONObject;
function ReplayReviewedCatalogText(const ACatalogRoot,
  APacketText: String): TJSONObject;

implementation

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.hash,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.export,
  pythian.tools.annotations.proposal;

const
  CMaximumEventBytes = 32768;
  CMaximumProposalBytes = 1048576;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function ProposalFileName(const APacket: TJSONObject): String;
var
  LCandidateId: String;
  LDash: Integer;
begin
  LCandidateId := APacket.Arrays['candidates'].Objects[0]
    .Strings['proposal_id'];
  LDash := LastDelimiter('-', LCandidateId);
  Need(LDash > 5, 'Invalid replay proposal identity');
  Result := Copy(LCandidateId, 1, LDash - 1) + '.json';
end;

function ReviewFileName(const ARevision: Integer): String;
begin
  Result := Format('%.8d.json', [ARevision]);
end;

procedure WriteNewJson(const APath: String; const AData: TJSONObject;
  const AMaximumBytes: Integer);
var
  LText: String;
  LOutput: TFileStream;
begin
  LText := AData.AsJSON + LineEnding;
  Need((Length(LText) > 0) and (Length(LText) <= AMaximumBytes),
    'Replay evidence exceeds file size bound');
  Need(not FileExists(APath), 'Replay stage file already exists');
  LOutput := TFileStream.Create(APath, fmCreate or fmShareExclusive);
  try
    LOutput.WriteBuffer(LText[1], Length(LText));
  finally
    LOutput.Free;
  end;
end;

procedure VerifyDestination(const ACatalogRoot: String;
  const APacket: TJSONObject);
var
  LCatalog: TJSONObject;
  LSources: TJSONArray;
  LTracks: TJSONArray;
  LSource: TJSONObject;
  LHash: String;
  LPath: String;
  LInput: TFileStream;
  LIndex: Integer;
begin
  LCatalog := ListLabelCatalog(ACatalogRoot);
  try
    LSources := LCatalog.Arrays['tracks'];
    LTracks := APacket.Arrays['tracks'];
    Need(LSources.Count = LTracks.Count,
      'Replay destination track count differs from packet');
    for LIndex := 0 to LTracks.Count - 1 do
    begin
      LSource := LTracks.Objects[LIndex].Objects['source'];
      Need(LSources.Objects[LIndex].AsJSON = LSource.AsJSON,
        'Replay destination source metadata differs from packet');
      LHash := LSource.Strings['source_sha256'];
      LPath := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
        'sources' + PathDelim + LHash + '.wav';
      LInput := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
      try
        Need((LInput.Size = LSource.Int64s['source_bytes']) and
          (Sha256Stream(LInput, LInput.Size) = LHash),
          'Replay destination source WAV differs from packet');
      finally
        LInput.Free;
      end;
    end;
  finally
    LCatalog.Free;
  end;
end;

procedure VerifyExistingProposals(const ACatalogRoot: String;
  const APacket: TJSONObject);
var
  LTracks: TJSONArray;
  LLinked: TJSONArray;
  LHash: String;
  LExpected: TJSONObject;
  LExisting: TJSONObject;
  LTrackIndex: Integer;
  LPacketIndex: Integer;
begin
  LTracks := APacket.Arrays['tracks'];
  for LTrackIndex := 0 to LTracks.Count - 1 do
  begin
    LHash := LTracks.Objects[LTrackIndex].Objects['source']
      .Strings['source_sha256'];
    LLinked := LTracks.Objects[LTrackIndex].Arrays['linked_proposals'];
    for LPacketIndex := 0 to LLinked.Count - 1 do
    begin
      LExpected := LLinked.Objects[LPacketIndex];
      LExisting := ReadCatalogBeatProposals(ACatalogRoot, LHash,
        LExpected.Int64s['region_start_frame'],
        LExpected.Int64s['region_end_frame']);
      try
        Need(LExisting.AsJSON = LExpected.AsJSON,
          'Replay destination proposal evidence differs');
      finally
        LExisting.Free;
      end;
    end;
  end;
end;

procedure WriteStage(const APacket: TJSONObject;
  const AProposalStage, AReviewStage: String;
  const AWriteProposals: Boolean);
var
  LTracks: TJSONArray;
  LLinked: TJSONArray;
  LHistory: TJSONArray;
  LHash: String;
  LDirectory: String;
  LTrackIndex: Integer;
  LItemIndex: Integer;
begin
  Need(ForceDirectories(AReviewStage),
    'Could not create replay review stage');
  if AWriteProposals then
  begin
    Need(ForceDirectories(AProposalStage),
      'Could not create replay proposal stage');
  end;
  LTracks := APacket.Arrays['tracks'];
  for LTrackIndex := 0 to LTracks.Count - 1 do
  begin
    LHash := LTracks.Objects[LTrackIndex].Objects['source']
      .Strings['source_sha256'];
    LHistory := LTracks.Objects[LTrackIndex].Arrays['history'];
    if LHistory.Count > 0 then
    begin
      LDirectory := IncludeTrailingPathDelimiter(AReviewStage) + LHash;
      Need(ForceDirectories(LDirectory),
        'Could not create replay source review stage');
      for LItemIndex := 0 to LHistory.Count - 1 do
      begin
        WriteNewJson(IncludeTrailingPathDelimiter(LDirectory) +
          ReviewFileName(LItemIndex + 1), LHistory.Objects[LItemIndex],
          CMaximumEventBytes);
      end;
    end;
    if AWriteProposals then
    begin
      LLinked := LTracks.Objects[LTrackIndex].Arrays['linked_proposals'];
      if LLinked.Count > 0 then
      begin
        LDirectory := IncludeTrailingPathDelimiter(AProposalStage) + LHash;
        Need(ForceDirectories(LDirectory),
          'Could not create replay source proposal stage');
        for LItemIndex := 0 to LLinked.Count - 1 do
        begin
          WriteNewJson(IncludeTrailingPathDelimiter(LDirectory) +
            ProposalFileName(LLinked.Objects[LItemIndex]),
            LLinked.Objects[LItemIndex], CMaximumProposalBytes);
        end;
      end;
    end;
  end;
end;

procedure CleanupStage(const APacket: TJSONObject;
  const AProposalStage, AReviewStage: String);
var
  LTracks: TJSONArray;
  LLinked: TJSONArray;
  LHistory: TJSONArray;
  LHash: String;
  LDirectory: String;
  LTrackIndex: Integer;
  LItemIndex: Integer;
begin
  LTracks := APacket.Arrays['tracks'];
  for LTrackIndex := 0 to LTracks.Count - 1 do
  begin
    LHash := LTracks.Objects[LTrackIndex].Objects['source']
      .Strings['source_sha256'];
    LDirectory := IncludeTrailingPathDelimiter(AReviewStage) + LHash;
    LHistory := LTracks.Objects[LTrackIndex].Arrays['history'];
    for LItemIndex := 0 to LHistory.Count - 1 do
    begin
      DeleteFile(IncludeTrailingPathDelimiter(LDirectory) +
        ReviewFileName(LItemIndex + 1));
    end;
    RemoveDir(LDirectory);
    LDirectory := IncludeTrailingPathDelimiter(AProposalStage) + LHash;
    LLinked := LTracks.Objects[LTrackIndex].Arrays['linked_proposals'];
    for LItemIndex := 0 to LLinked.Count - 1 do
    begin
      DeleteFile(IncludeTrailingPathDelimiter(LDirectory) +
        ProposalFileName(LLinked.Objects[LItemIndex]));
    end;
    RemoveDir(LDirectory);
  end;
  RemoveDir(AReviewStage);
  RemoveDir(AProposalStage);
end;

function ReplayReviewedCatalogData(const ACatalogRoot: String;
  const APacket: TJSONObject): TJSONObject; forward;

function ReplayReviewedCatalogPacket(const ACatalogRoot,
  APacketPath: String): TJSONObject;
var
  LPacket: TJSONObject;
begin
  LPacket := ReadReviewedCatalogPacket(APacketPath);
  try
    Result := ReplayReviewedCatalogData(ACatalogRoot, LPacket);
  finally
    LPacket.Free;
  end;
end;

function ReplayReviewedCatalogText(const ACatalogRoot,
  APacketText: String): TJSONObject;
var
  LPacket: TJSONObject;
begin
  LPacket := ReadReviewedCatalogPacketText(APacketText);
  try
    Result := ReplayReviewedCatalogData(ACatalogRoot, LPacket);
  finally
    LPacket.Free;
  end;
end;

function ReplayReviewedCatalogData(const ACatalogRoot: String;
  const APacket: TJSONObject): TJSONObject;
var
  LRebuilt: TJSONObject;
  LCatalog: String;
  LReviews: String;
  LProposals: String;
  LReviewStage: String;
  LProposalStage: String;
  LGuid: TGUID;
  LNeedProposals: Boolean;
  LPublishedProposals: Boolean;
  LStatus: String;
begin
  VerifyDestination(ACatalogRoot, APacket);
  LCatalog := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot));
  LReviews := LCatalog + 'reviews';
  LProposals := LCatalog + 'proposals';
  if DirectoryExists(LReviews) then
  begin
    LRebuilt := BuildReviewedCatalogPacket(ACatalogRoot);
    try
      Need(LRebuilt.AsJSON = APacket.AsJSON,
        'Replay destination review history differs');
    finally
      LRebuilt.Free;
    end;
    LStatus := 'duplicate';
  end
  else
  begin
    Need(not FileExists(LReviews) and not FileExists(LProposals),
      'Replay destination evidence path is a file');
    LNeedProposals := not DirectoryExists(LProposals);
    if not LNeedProposals then
    begin
      VerifyExistingProposals(ACatalogRoot, APacket);
    end;
    Need(CreateGUID(LGuid) = 0,
      'Could not create replay stage identity');
    LReviewStage := LCatalog + 'reviews.' +
      GUIDToString(LGuid) + '.partial';
    LProposalStage := LCatalog + 'proposals.' +
      GUIDToString(LGuid) + '.partial';
    Need(not DirectoryExists(LReviewStage) and
      not DirectoryExists(LProposalStage),
      'Replay stage path already exists');
    LPublishedProposals := False;
    try
      try
        WriteStage(APacket, LProposalStage, LReviewStage, LNeedProposals);
        if LNeedProposals then
        begin
          Need(not DirectoryExists(LProposals) and
            RenameFile(LProposalStage, LProposals),
            'Could not publish replay proposal evidence');
          LPublishedProposals := True;
        end;
        Need(not DirectoryExists(LReviews) and
          RenameFile(LReviewStage, LReviews),
          'Could not publish replay review history');
      except
        on LError: Exception do
        begin
          if LPublishedProposals and not DirectoryExists(LReviews) and
            not RenameFile(LProposals, LProposalStage) then
          begin
            raise EAudio.Create(LError.Message +
              '; proposal rollback failed');
          end;
          raise;
        end;
      end;
    finally
      CleanupStage(APacket, LProposalStage, LReviewStage);
    end;
    LRebuilt := BuildReviewedCatalogPacket(ACatalogRoot);
    try
      Need(LRebuilt.AsJSON = APacket.AsJSON,
        'Replayed reviewed catalog differs from packet');
    finally
      LRebuilt.Free;
    end;
    LStatus := 'imported';
  end;
  Result := TJSONObject.Create;
  Result.Add('version', 1);
  Result.Add('status', LStatus);
  Result.Add('track_count', APacket.Integers['track_count']);
end;

end.
