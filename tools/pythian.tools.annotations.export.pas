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
unit pythian.tools.annotations.export;

{$mode delphi}
{$H+}

interface

uses
  fpjson;

{ Writes one deterministic, bounded, audio-free packet. The packet retains
  history, while selected labels contain only current approved decisions. }
function BuildReviewedCatalogPacket(const ACatalogRoot: String): TJSONObject;
function ExportReviewedCatalog(const ACatalogRoot, AOutputPath: String): TJSONObject;
function ReadReviewedCatalogPacket(const APath: String): TJSONObject;
function ReadReviewedCatalogPacketText(const AText: String): TJSONObject;
function InspectReviewedCatalogPacket(const APath: String): TJSONObject;

implementation

uses
  Classes,
  SysUtils,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.proposal,
  pythian.tools.annotations.review;

const
  CMaximumPacketBytes = 67108864;
  CMaximumCurrentLabels = 100000;
  CMaximumLinkedProposalPackets = 4096;
  CHistoryPage = 256;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function CloneObject(const ASource: TJSONObject): TJSONObject;
begin
  Result := TJSONObject(GetJSON(ASource.AsJSON));
end;

function ValidHash(const AHash: String): Boolean;
var
  LIndex: Integer;
begin
  Result := Length(AHash) = 64;
  for LIndex := 1 to Length(AHash) do
  begin
    if not (AHash[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      Exit(False);
    end;
  end;
end;

procedure VerifySource(const ACatalogRoot: String; const ATrack: TJSONObject);
var
  LHash: String;
  LPath: String;
  LInput: TFileStream;
begin
  LHash := ATrack.Strings['source_sha256'];
  LPath := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'sources' + PathDelim + LHash + '.wav';
  LInput := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    Need(LInput.Size = ATrack.Int64s['source_bytes'],
      'Export source byte count differs from catalog');
    Need(Sha256Stream(LInput, LInput.Size) = LHash,
      'Export source SHA256 differs from catalog');
  finally
    LInput.Free;
  end;
end;

procedure CheckGroups(const ATracks: TJSONArray);
var
  LGroups: TStringList;
  LPartitions: TStringList;
  LIndex: Integer;
  LPosition: Integer;
  LTrack: TJSONObject;
  LGroup: String;
  LPartition: String;
begin
  LGroups := TStringList.Create;
  LPartitions := TStringList.Create;
  try
    LGroups.Sorted := True;
    LGroups.CaseSensitive := True;
    for LIndex := 0 to ATracks.Count - 1 do
    begin
      LTrack := ATracks.Objects[LIndex];
      LGroup := LTrack.Strings['source_group'];
      LPartition := LTrack.Strings['partition'];
      Need((LGroup <> '') and
        ((LPartition = 'training') or (LPartition = 'development') or
        (LPartition = 'evaluation') or (LPartition = 'unassigned')),
        'Invalid export group or partition');
      LPosition := LGroups.IndexOf(LGroup);
      if LPosition >= 0 then
      begin
        Need(LPartitions[LPosition] = LPartition,
          'Source group crosses catalog partitions');
      end
      else
      begin
        LPosition := LGroups.Add(LGroup);
        LPartitions.Insert(LPosition, LPartition);
      end;
    end;
  finally
    LPartitions.Free;
    LGroups.Free;
  end;
end;

procedure RememberCurrent(const AStates: TStringList;
  const AEvent: TJSONObject);
var
  LChange: TJSONObject;
  LRow: TJSONObject;
  LId: String;
  LPosition: Integer;
begin
  LChange := AEvent.Objects['change'];
  LId := LChange.Strings['label_id'];
  Need((LId <> '') and (Length(LId) <= 128),
    'Invalid export label identity');
  LRow := CloneObject(LChange);
  try
    LRow.Add('reviewer', AEvent.Strings['reviewer']);
    LRow.Add('revision', AEvent.Integers['revision']);
    LPosition := AStates.IndexOf(LId);
    if LPosition >= 0 then
    begin
      AStates.Objects[LPosition].Free;
      AStates.Objects[LPosition] := LRow;
    end
    else
    begin
      Need(AStates.Count < CMaximumCurrentLabels,
        'Export current-label count exceeds bound');
      AStates.AddObject(LId, LRow);
    end;
    LRow := nil;
  finally
    LRow.Free;
  end;
end;

function PacketHasCandidate(const APacket: TJSONObject;
  const AProposalId: String): Boolean;
var
  LRows: TJSONArray;
  LIndex: Integer;
begin
  Result := False;
  LRows := APacket.Arrays['candidates'];
  for LIndex := 0 to LRows.Count - 1 do
  begin
    if LRows.Objects[LIndex].Strings['proposal_id'] = AProposalId then
    begin
      Exit(True);
    end;
  end;
end;

procedure RememberLinkedProposal(const ACatalogRoot, AHash,
  AProposalId: String; const APackets: TStringList;
  var AApproximateBytes: Int64);
var
  LDash: Integer;
  LKey: String;
  LPosition: Integer;
  LPacket: TJSONObject;
begin
  if AProposalId = '' then
  begin
    Exit;
  end;
  LDash := LastDelimiter('-', AProposalId);
  Need(LDash > 5, 'Invalid linked proposal identity');
  LKey := Copy(AProposalId, 1, LDash - 1);
  LPosition := APackets.IndexOf(LKey);
  if LPosition >= 0 then
  begin
    Need(PacketHasCandidate(TJSONObject(APackets.Objects[LPosition]),
      AProposalId), 'Review refers to an unknown proposal');
    Exit;
  end;
  Need(APackets.Count < CMaximumLinkedProposalPackets,
    'Too many linked proposal packets for reviewed export');
  LPacket := ReadCatalogProposalForId(ACatalogRoot, AHash, AProposalId);
  try
    Inc(AApproximateBytes, Length(LPacket.AsJSON));
    Need(AApproximateBytes <= CMaximumPacketBytes,
      'Reviewed export exceeds packet size bound');
    APackets.AddObject(LKey, LPacket);
    LPacket := nil;
  finally
    LPacket.Free;
  end;
end;

function ExportOneSource(const ACatalogRoot: String;
  const ATrack: TJSONObject; var AApproximateBytes: Int64): TJSONObject;
var
  LHash: String;
  LPartition: String;
  LHistory: TJSONArray;
  LSelected: TJSONArray;
  LUnknown: TJSONArray;
  LLinked: TJSONArray;
  LStates: TStringList;
  LProposalPackets: TStringList;
  LPage: TJSONObject;
  LEvents: TJSONArray;
  LEvent: TJSONObject;
  LRow: TJSONObject;
  LExpectedRevision: Integer;
  LLatestRevision: Integer;
  LIndex: Integer;
begin
  LHash := ATrack.Strings['source_sha256'];
  LPartition := ATrack.Strings['partition'];
  VerifySource(ACatalogRoot, ATrack);
  LStates := TStringList.Create;
  LProposalPackets := TStringList.Create;
  try
    LProposalPackets.Sorted := True;
    LProposalPackets.CaseSensitive := True;
    Result := TJSONObject.Create;
    try
      LStates.Sorted := True;
      LStates.CaseSensitive := True;
      Result.Add('source', CloneObject(ATrack));
      LHistory := TJSONArray.Create;
      Result.Add('history', LHistory);
      LSelected := TJSONArray.Create;
      Result.Add('selected_labels', LSelected);
      LUnknown := TJSONArray.Create;
      Result.Add('unknown_labels', LUnknown);
      LLinked := TJSONArray.Create;
      Result.Add('linked_proposals', LLinked);
      LExpectedRevision := 1;
      repeat
        LPage := ReadCatalogReviewHistory(ACatalogRoot, LHash,
          LExpectedRevision, CHistoryPage);
        try
          LLatestRevision := LPage.Integers['revision'];
          LEvents := LPage.Arrays['events'];
          for LIndex := 0 to LEvents.Count - 1 do
          begin
            LEvent := LEvents.Objects[LIndex];
            Need((LEvent.Integers['revision'] = LExpectedRevision) and
              (LEvent.Strings['source_sha256'] = LHash) and
              (LEvent.Strings['partition'] = LPartition) and
              (LEvent.Strings['source_group'] =
                ATrack.Strings['source_group']),
              'Export history differs from source identity or revision');
            Inc(AApproximateBytes, Length(LEvent.AsJSON));
            Need(AApproximateBytes <= CMaximumPacketBytes,
              'Reviewed export exceeds packet size bound');
            RememberCurrent(LStates, LEvent);
            RememberLinkedProposal(ACatalogRoot, LHash,
              LEvent.Objects['change'].Strings['proposal_id'],
              LProposalPackets, AApproximateBytes);
            LHistory.Add(CloneObject(LEvent));
            Inc(LExpectedRevision);
          end;
          Need((LEvents.Count > 0) or (LExpectedRevision > LLatestRevision),
            'Review history page made no progress');
        finally
          LPage.Free;
        end;
      until LExpectedRevision > LLatestRevision;
      for LIndex := 0 to LProposalPackets.Count - 1 do
      begin
        LLinked.Add(TJSONObject(LProposalPackets.Objects[LIndex]));
        LProposalPackets.Objects[LIndex] := nil;
      end;
      for LIndex := 0 to LStates.Count - 1 do
      begin
        LRow := TJSONObject(LStates.Objects[LIndex]);
        if LRow.Strings['status'] <> 'approved' then
        begin
          Continue;
        end;
        if (LRow.Strings['type'] = 'presence') and
          (LRow.Strings['value'] = 'unknown') then
        begin
          LUnknown.Add(CloneObject(LRow));
        end
        else if LPartition <> 'unassigned' then
        begin
          LSelected.Add(CloneObject(LRow));
        end;
      end;
      Result.Add('review_revision', LLatestRevision);
      Result.Add('selected_count', LSelected.Count);
      Result.Add('unknown_count', LUnknown.Count);
    except
      Result.Free;
      raise;
    end;
  finally
    for LIndex := 0 to LProposalPackets.Count - 1 do
    begin
      LProposalPackets.Objects[LIndex].Free;
    end;
    LProposalPackets.Free;
    for LIndex := 0 to LStates.Count - 1 do
    begin
      LStates.Objects[LIndex].Free;
    end;
    LStates.Free;
  end;
end;

function BuildReviewedCatalogPacket(const ACatalogRoot: String): TJSONObject;
var
  LCatalog: TJSONObject;
  LTracks: TJSONArray;
  LRows: TJSONArray;
  LIndex: Integer;
  LApproximateBytes: Int64;
begin
  LCatalog := ListLabelCatalog(ACatalogRoot);
  try
    LTracks := LCatalog.Arrays['tracks'];
    CheckGroups(LTracks);
    Result := TJSONObject.Create;
    try
      Result.Add('version', 1);
      Result.Add('policy', 'pythian.reviewed-catalog.v1');
      Result.Add('source_audio_included', False);
      LRows := TJSONArray.Create;
      Result.Add('tracks', LRows);
      LApproximateBytes := 0;
      for LIndex := 0 to LTracks.Count - 1 do
      begin
        LRows.Add(ExportOneSource(ACatalogRoot,
          LTracks.Objects[LIndex], LApproximateBytes));
      end;
      Result.Add('track_count', LRows.Count);
      Need(Length(Result.AsJSON) <= CMaximumPacketBytes,
        'Reviewed export exceeds packet size bound');
    except
      Result.Free;
      raise;
    end;
  finally
    LCatalog.Free;
  end;
end;

function ExportReviewedCatalog(const ACatalogRoot, AOutputPath: String): TJSONObject;
var
  LPacket: TJSONObject;
  LText: String;
  LGuid: TGUID;
  LStage: String;
  LStream: TFileStream;
  LStageRead: TFileStream;
  LPacketHash: String;
begin
  Need(not FileExists(AOutputPath), 'Reviewed export output already exists');
  LPacket := BuildReviewedCatalogPacket(ACatalogRoot);
  try
    LText := LPacket.AsJSON + LineEnding;
    Need(Length(LText) <= CMaximumPacketBytes,
      'Reviewed export exceeds packet size bound');
    Need(CreateGUID(LGuid) = 0, 'Could not create export stage identity');
    LStage := AOutputPath + '.' + GUIDToString(LGuid) + '.partial';
    try
      LStream := TFileStream.Create(LStage, fmCreate or fmShareExclusive);
      try
        LStream.WriteBuffer(LText[1], Length(LText));
      finally
        LStream.Free;
      end;
      LStageRead := TFileStream.Create(LStage,
        fmOpenRead or fmShareDenyWrite);
      try
        Need(LStageRead.Size = Length(LText),
          'Staged export byte count differs');
        LPacketHash := Sha256Stream(LStageRead, LStageRead.Size);
      finally
        LStageRead.Free;
      end;
      Need(not FileExists(AOutputPath) and RenameFile(LStage, AOutputPath),
        'Could not publish reviewed export');
    finally
      if FileExists(LStage) then
      begin
        DeleteFile(LStage);
      end;
    end;
    Result := TJSONObject.Create;
    try
      Result.Add('version', 1);
      Result.Add('policy', 'pythian.reviewed-catalog.v1');
      Result.Add('source_audio_included', False);
      Result.Add('track_count', LPacket.Integers['track_count']);
      Result.Add('packet_bytes', Length(LText));
      Result.Add('packet_sha256', LPacketHash);
      Result.Add('output', ExpandFileName(AOutputPath));
    except
      Result.Free;
      raise;
    end;
  finally
    LPacket.Free;
  end;
end;

procedure ValidatePacket(const APacket: TJSONObject);
var
  LTracks: TJSONArray;
  LSources: TJSONArray;
  LTrack: TJSONObject;
  LSource: TJSONObject;
  LHistory: TJSONArray;
  LSelected: TJSONArray;
  LUnknown: TJSONArray;
  LLinked: TJSONArray;
  LExpectedSelected: TJSONArray;
  LExpectedUnknown: TJSONArray;
  LStates: TStringList;
  LReferencedIds: TStringList;
  LReferencedBases: TStringList;
  LPacketCandidates: TStringList;
  LEvent: TJSONObject;
  LChange: TJSONObject;
  LRow: TJSONObject;
  LProposalPacket: TJSONObject;
  LProposalRows: TJSONArray;
  LHash: String;
  LLastHash: String;
  LPartition: String;
  LProposalId: String;
  LProposalBase: String;
  LLastProposalBase: String;
  LDash: Integer;
  LIndex: Integer;
  LEventIndex: Integer;
  LStateIndex: Integer;
  LProposalIndex: Integer;
  LCandidatesIndex: Integer;
begin
  Need((APacket.Integers['version'] = 1) and
    (APacket.Strings['policy'] = 'pythian.reviewed-catalog.v1') and
    (APacket.Booleans['source_audio_included'] = False),
    'Unsupported reviewed catalog packet');
  Need((APacket.Find('tracks') <> nil) and
    (APacket.Find('tracks').JSONType = jtArray),
    'Reviewed catalog packet requires tracks');
  LTracks := APacket.Arrays['tracks'];
  Need((LTracks.Count <= 4096) and
    (APacket.Integers['track_count'] = LTracks.Count),
    'Reviewed catalog track count differs');
  LSources := TJSONArray.Create;
  try
    LLastHash := '';
    for LIndex := 0 to LTracks.Count - 1 do
    begin
      Need(LTracks[LIndex].JSONType = jtObject,
        'Reviewed catalog track must be an object');
      LTrack := LTracks.Objects[LIndex];
      Need((LTrack.Find('source') <> nil) and
        (LTrack.Find('source').JSONType = jtObject),
        'Reviewed catalog track requires source');
      LSource := LTrack.Objects['source'];
      LHash := LSource.Strings['source_sha256'];
      Need(ValidHash(LHash) and
        ((LLastHash = '') or (LHash > LLastHash)) and
        (LSource.Integers['version'] = 1) and
        (LSource.Strings['asset'] = 'sources/' + LHash + '.wav') and
        (LSource.Int64s['source_bytes'] >= 44) and
        (LSource.Int64s['frame_count'] > 0) and
        (LSource.Integers['sample_rate'] > 0) and
        (LSource.Strings['provenance'] <> '') and
        (LSource.Strings['license'] <> ''),
        'Reviewed catalog source identity differs');
      LLastHash := LHash;
      LSources.Add(CloneObject(LSource));
    end;
    CheckGroups(LSources);
    for LIndex := 0 to LTracks.Count - 1 do
    begin
      LTrack := LTracks.Objects[LIndex];
      LSource := LTrack.Objects['source'];
      LHash := LSource.Strings['source_sha256'];
      LPartition := LSource.Strings['partition'];
      LHistory := LTrack.Arrays['history'];
      LSelected := LTrack.Arrays['selected_labels'];
      LUnknown := LTrack.Arrays['unknown_labels'];
      Need((LTrack.Find('linked_proposals') <> nil) and
        (LTrack.Find('linked_proposals').JSONType = jtArray),
        'Reviewed catalog requires linked proposals');
      LLinked := LTrack.Arrays['linked_proposals'];
      Need((LHistory.Count <= 100000) and
        (LLinked.Count <= CMaximumLinkedProposalPackets) and
        (LTrack.Integers['review_revision'] = LHistory.Count) and
        (LTrack.Integers['selected_count'] = LSelected.Count) and
        (LTrack.Integers['unknown_count'] = LUnknown.Count),
        'Reviewed catalog source counts differ');
      LStates := TStringList.Create;
      LReferencedIds := TStringList.Create;
      LReferencedBases := TStringList.Create;
      LPacketCandidates := TStringList.Create;
      try
        LStates.Sorted := True;
        LStates.CaseSensitive := True;
        LReferencedIds.Sorted := True;
        LReferencedIds.CaseSensitive := True;
        LReferencedIds.Duplicates := dupIgnore;
        LReferencedBases.Sorted := True;
        LReferencedBases.CaseSensitive := True;
        LReferencedBases.Duplicates := dupIgnore;
        LPacketCandidates.Sorted := True;
        LPacketCandidates.CaseSensitive := True;
        for LEventIndex := 0 to LHistory.Count - 1 do
        begin
          Need(LHistory[LEventIndex].JSONType = jtObject,
            'Reviewed catalog history event must be an object');
          LEvent := LHistory.Objects[LEventIndex];
          Need((LEvent.Integers['version'] = 1) and
            (LEvent.Integers['revision'] = LEventIndex + 1) and
            (LEvent.Strings['source_sha256'] = LHash) and
            (LEvent.Integers['sample_rate'] =
              LSource.Integers['sample_rate']) and
            (LEvent.Strings['source_group'] =
              LSource.Strings['source_group']) and
            (LEvent.Strings['partition'] = LPartition) and
            (LEvent.Strings['provenance'] =
              LSource.Strings['provenance']) and
            (LEvent.Strings['license'] = LSource.Strings['license']) and
            (LEvent.Strings['reviewer'] <> ''),
            'Reviewed catalog event identity differs');
          Need((LEvent.Find('change') <> nil) and
            (LEvent.Find('change').JSONType = jtObject),
            'Reviewed catalog event requires change');
          LChange := LEvent.Objects['change'];
          LProposalId := LChange.Strings['proposal_id'];
          if LProposalId <> '' then
          begin
            LDash := LastDelimiter('-', LProposalId);
            Need(LDash > 5, 'Invalid reviewed proposal identity');
            LReferencedIds.Add(LProposalId);
            LReferencedBases.Add(Copy(LProposalId, 1, LDash - 1));
          end;
          Need((LChange.Int64s['start_frame'] >= 0) and
            (LChange.Int64s['end_frame'] >
              LChange.Int64s['start_frame']) and
            (LChange.Int64s['end_frame'] <=
              LSource.Int64s['frame_count']) and
            ((LChange.Strings['status'] = 'approved') or
              (LChange.Strings['status'] = 'uncertain') or
              (LChange.Strings['status'] = 'rejected') or
              (LChange.Strings['status'] = 'withdrawn')),
            'Reviewed catalog event span or status differs');
          RememberCurrent(LStates, LEvent);
        end;
        Need(LLinked.Count = LReferencedBases.Count,
          'Reviewed proposal packet count differs from history');
        LLastProposalBase := '';
        for LProposalIndex := 0 to LLinked.Count - 1 do
        begin
          Need(LLinked[LProposalIndex].JSONType = jtObject,
            'Reviewed linked proposal must be an object');
          LProposalPacket := LLinked.Objects[LProposalIndex];
          ValidateCatalogProposalPacket(LProposalPacket, LSource);
          LProposalRows := LProposalPacket.Arrays['candidates'];
          Need(LProposalRows.Count > 0,
            'Reviewed linked proposal has no candidate');
          LProposalId := LProposalRows.Objects[0].Strings['proposal_id'];
          LDash := LastDelimiter('-', LProposalId);
          Need(LDash > 5, 'Invalid linked candidate identity');
          LProposalBase := Copy(LProposalId, 1, LDash - 1);
          Need((LProposalBase > LLastProposalBase) and
            (LProposalBase = LReferencedBases[LProposalIndex]),
            'Reviewed proposal order or identity differs');
          LLastProposalBase := LProposalBase;
          for LCandidatesIndex := 0 to LProposalRows.Count - 1 do
          begin
            LProposalId := LProposalRows.Objects[LCandidatesIndex]
              .Strings['proposal_id'];
            Need(LPacketCandidates.IndexOf(LProposalId) < 0,
              'Duplicate linked proposal candidate');
            LPacketCandidates.Add(LProposalId);
          end;
        end;
        for LProposalIndex := 0 to LReferencedIds.Count - 1 do
        begin
          Need(LPacketCandidates.IndexOf(LReferencedIds[LProposalIndex]) >= 0,
            'Reviewed history refers to a missing proposal');
        end;
        LExpectedSelected := TJSONArray.Create;
        LExpectedUnknown := TJSONArray.Create;
        try
          for LStateIndex := 0 to LStates.Count - 1 do
          begin
            LRow := TJSONObject(LStates.Objects[LStateIndex]);
            if LRow.Strings['status'] <> 'approved' then
            begin
              Continue;
            end;
            if (LRow.Strings['type'] = 'presence') and
              (LRow.Strings['value'] = 'unknown') then
            begin
              LExpectedUnknown.Add(CloneObject(LRow));
            end
            else if LPartition <> 'unassigned' then
            begin
              LExpectedSelected.Add(CloneObject(LRow));
            end;
          end;
          Need((LSelected.AsJSON = LExpectedSelected.AsJSON) and
            (LUnknown.AsJSON = LExpectedUnknown.AsJSON),
            'Reviewed catalog selected labels differ from history');
        finally
          LExpectedUnknown.Free;
          LExpectedSelected.Free;
        end;
      finally
        LPacketCandidates.Free;
        LReferencedBases.Free;
        LReferencedIds.Free;
        for LStateIndex := 0 to LStates.Count - 1 do
        begin
          LStates.Objects[LStateIndex].Free;
        end;
        LStates.Free;
      end;
    end;
  finally
    LSources.Free;
  end;
end;

function ReadReviewedCatalogPacket(const APath: String): TJSONObject;
var
  LInput: TFileStream;
  LText: String;
begin
  LInput := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LInput.Size > 0) and (LInput.Size <= CMaximumPacketBytes),
      'Reviewed catalog packet exceeds size bound');
    SetLength(LText, Integer(LInput.Size));
    LInput.ReadBuffer(LText[1], Length(LText));
  finally
    LInput.Free;
  end;
  Result := ReadReviewedCatalogPacketText(LText);
end;

function ReadReviewedCatalogPacketText(const AText: String): TJSONObject;
var
  LData: TJSONData;
begin
  Need((Length(AText) > 0) and (Length(AText) <= CMaximumPacketBytes),
    'Reviewed catalog packet exceeds size bound');
  try
    LData := GetJSON(AText);
  except
    on LError: Exception do
    begin
      raise EAudio.Create('Invalid reviewed catalog JSON: ' + LError.Message);
    end;
  end;
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Reviewed catalog packet must be an object');
  end;
  Result := TJSONObject(LData);
  try
    ValidatePacket(Result);
  except
    on LError: Exception do
    begin
      Result.Free;
      raise EAudio.Create('Invalid reviewed catalog packet: ' +
        LError.Message);
    end;
  end;
end;

function InspectReviewedCatalogPacket(const APath: String): TJSONObject;
var
  LPacket: TJSONObject;
  LTracks: TJSONArray;
  LInput: TFileStream;
  LIndex: Integer;
  LSelected: Integer;
  LUnknown: Integer;
  LHistory: Integer;
begin
  LPacket := ReadReviewedCatalogPacket(APath);
  try
    LTracks := LPacket.Arrays['tracks'];
    LSelected := 0;
    LUnknown := 0;
    LHistory := 0;
    for LIndex := 0 to LTracks.Count - 1 do
    begin
      Inc(LSelected, LTracks.Objects[LIndex].Integers['selected_count']);
      Inc(LUnknown, LTracks.Objects[LIndex].Integers['unknown_count']);
      Inc(LHistory, LTracks.Objects[LIndex].Integers['review_revision']);
    end;
    LInput := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
    try
      Result := TJSONObject.Create;
      Result.Add('version', 1);
      Result.Add('policy', 'pythian.reviewed-catalog.v1');
      Result.Add('packet_sha256', Sha256Stream(LInput, LInput.Size));
      Result.Add('track_count', LTracks.Count);
      Result.Add('selected_count', LSelected);
      Result.Add('unknown_count', LUnknown);
      Result.Add('history_count', LHistory);
    finally
      LInput.Free;
    end;
  finally
    LPacket.Free;
  end;
end;

end.
