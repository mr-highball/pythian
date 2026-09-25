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
unit pythian.tools.annotations.proposal;

{$mode delphi}
{$H+}

interface

uses
  fpjson;

{ Native pulse hypotheses over one bounded source window. A packet is always
  unreviewed, even when its analysis has a strong periodic score. }
function PublishCatalogBeatProposals(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64): TJSONObject;
function CatalogProposalExists(const ACatalogRoot, AHash,
  AProposalId: String): Boolean;

implementation

uses
  Classes,
  SysUtils,
  jsonparser,
  pythian.audio,
  pythian.wave.read,
  pythian.beat,
  pythian.beat.wave,
  pythian.tools.annotations.catalog;

const
  CMaximumProposalFrames: Int64 = 2000000;
  CMaximumProposalSeconds = 30;
  CMaximumPacketBytes = 1048576;
  CReadFrames = 4096;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function SafeIdentifier(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := (Length(AValue) > 0) and (Length(AValue) <= 128);
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.']) then
    begin
      Exit(False);
    end;
  end;
end;

function ProposalBase(const AStartFrame, AEndFrame: Int64): String;
begin
  Result := 'beat-' + BeatGridMeasurementPolicy + '-' +
    IntToStr(AStartFrame) + '-' + IntToStr(AEndFrame);
end;

function ProposalDirectory(const ACatalogRoot, AHash: String): String;
begin
  Need((Length(AHash) = 64) and SafeIdentifier(AHash),
    'Invalid proposal source SHA256');
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'proposals' + PathDelim + AHash;
end;

function BoundedSourceClip(const ACatalogRoot, AHash: String;
  const ATrack: TJSONObject; const AStartFrame, AEndFrame: Int64): TAudioClip;
var
  LPath: String;
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LSamples: TAudioSamples;
  LBatch: TAudioSamples;
  LRemaining: Int64;
  LOffset: Integer;
  LCount: Integer;
  LSpan: Int64;
begin
  LSpan := AEndFrame - AStartFrame;
  Need((AStartFrame >= 0) and (AEndFrame > AStartFrame) and
    (AEndFrame <= ATrack.Int64s['frame_count']) and
    (LSpan <= CMaximumProposalFrames) and
    (LSpan <= Int64(ATrack.Integers['sample_rate']) * CMaximumProposalSeconds),
    'Beat proposal window exceeds source or analysis bound');
  LPath := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'sources' + PathDelim + AHash + '.wav';
  LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    Need(LStream.Size = ATrack.Int64s['source_bytes'],
      'Proposal source byte count differs from catalog');
    LReader := TWaveFrameReader.Create(LStream);
    try
      Need((LReader.SampleRate = ATrack.Integers['sample_rate']) and
        (LReader.Channels = ATrack.Integers['channels']) and
        (LReader.FrameCount = ATrack.Int64s['frame_count']),
        'Proposal source geometry differs from catalog');
      SetLength(LSamples, Integer(LSpan) * LReader.Channels);
      LReader.SeekFrame(AStartFrame);
      LRemaining := LSpan;
      LOffset := 0;
      while LRemaining > 0 do
      begin
        LCount := CReadFrames;
        if LRemaining < LCount then
        begin
          LCount := Integer(LRemaining);
        end;
        LBatch := LReader.ReadFrames(LCount);
        Need(Length(LBatch) = LCount * LReader.Channels,
          'Short proposal source read');
        Move(LBatch[0], LSamples[LOffset], Length(LBatch) * SizeOf(Single));
        Inc(LOffset, Length(LBatch));
        Dec(LRemaining, LCount);
      end;
      Result := TAudioClip.Create(LReader.SampleRate, LReader.Channels, LSamples);
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

function GeneratePacket(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64): TJSONObject;
var
  LTrack: TJSONObject;
  LClip: TAudioClip;
  LEvidence: TWaveBeatEvidence;
  LOptions: TBeatGridOptions;
  LObservations: TJSONArray;
  LCandidates: TJSONArray;
  LFrames: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
  LPoint: Integer;
  LGridFrames: TBeatFrames;
  LLastEvidence: Integer;
begin
  LTrack := ReadCatalogTrack(ACatalogRoot, AHash);
  try
    LClip := BoundedSourceClip(ACatalogRoot, AHash, LTrack,
      AStartFrame, AEndFrame);
    try
      LOptions := DefaultBeatGridOptions;
      LEvidence := MeasureWaveBeats(LClip, LOptions);
      Result := TJSONObject.Create;
      try
        Result.Add('version', 1);
        Result.Add('source_sha256', AHash);
        Result.Add('sample_rate', LClip.SampleRate);
        Result.Add('source_group', LTrack.Strings['source_group']);
        Result.Add('region_start_frame', AStartFrame);
        Result.Add('region_end_frame', AEndFrame);
        Result.Add('status', 'unreviewed');
        Result.Add('analyzer', 'pythian.beat.wave');
        Result.Add('analyzer_version', BeatGridVersion);
        Result.Add('model', 'none-native-heuristic');
        Result.Add('policy', BeatGridMeasurementPolicy);
        Result.Add('interpretation',
          'Pulse hypotheses from source onsets; no meter, downbeat or calibrated confidence');
        Result.Add('analysis_window_frames', LEvidence.AnalysisOptions.WindowFrames);
        Result.Add('analysis_hop_frames', LEvidence.AnalysisOptions.HopFrames);
        LObservations := TJSONArray.Create;
        Result.Add('observations', LObservations);
        for LIndex := 0 to High(LEvidence.Observations) do
        begin
          LRow := TJSONObject.Create;
          LObservations.Add(LRow);
          LRow.Add('frame', AStartFrame + LEvidence.Observations[LIndex].Frame);
          LRow.Add('weight', LEvidence.Observations[LIndex].Weight);
        end;
        LCandidates := TJSONArray.Create;
        Result.Add('candidates', LCandidates);
        LLastEvidence := LEvidence.Grid.LastObservationFrame;
        for LIndex := 0 to High(LEvidence.Grid.Candidates) do
        begin
          LRow := TJSONObject.Create;
          LCandidates.Add(LRow);
          LRow.Add('proposal_id', ProposalBase(AStartFrame, AEndFrame) +
            '-' + IntToStr(LIndex));
          LRow.Add('type', 'beat_grid');
          LRow.Add('bpm', LEvidence.Grid.Candidates[LIndex].Bpm);
          LRow.Add('score', LEvidence.Grid.Candidates[LIndex].Score);
          LRow.Add('phase_concentration',
            LEvidence.Grid.Candidates[LIndex].PhaseConcentration);
          LRow.Add('matched_weight_fraction',
            LEvidence.Grid.Candidates[LIndex].MatchedWeightFraction);
          LRow.Add('supported_onsets',
            LEvidence.Grid.Candidates[LIndex].SupportedOnsets);
          LRow.Add('grid_beats', LEvidence.Grid.Candidates[LIndex].GridBeats);
          LFrames := TJSONArray.Create;
          LRow.Add('frames', LFrames);
          if LLastEvidence < LEvidence.Grid.FirstObservationFrame then
          begin
            Continue;
          end;
          LGridFrames := BeatGridFrames(LEvidence.Grid.Candidates[LIndex],
            LEvidence.Grid.FirstObservationFrame, LLastEvidence + 1);
          for LPoint := 0 to High(LGridFrames) do
          begin
            LFrames.Add(AStartFrame + LGridFrames[LPoint]);
          end;
        end;
      except
        Result.Free;
        raise;
      end;
    finally
      LClip.Free;
    end;
  finally
    LTrack.Free;
  end;
end;

function ReadPacket(const APath: String): TJSONObject;
var
  LStream: TFileStream;
  LText: String;
  LData: TJSONData;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size > 0) and (LStream.Size <= CMaximumPacketBytes),
      'Proposal packet exceeds size bound');
    SetLength(LText, Integer(LStream.Size));
    LStream.ReadBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
  LData := GetJSON(LText);
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Proposal packet must be an object');
  end;
  Result := TJSONObject(LData);
end;

function PublishCatalogBeatProposals(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64): TJSONObject;
var
  LDirectory: String;
  LFinal: String;
  LStage: String;
  LGuid: TGUID;
  LText: String;
  LStream: TFileStream;
  LExisting: TJSONObject;
begin
  Result := GeneratePacket(ACatalogRoot, AHash, AStartFrame, AEndFrame);
  try
    LDirectory := ProposalDirectory(ACatalogRoot, AHash);
    Need(ForceDirectories(LDirectory), 'Could not create proposal directory');
    LFinal := IncludeTrailingPathDelimiter(LDirectory) +
      ProposalBase(AStartFrame, AEndFrame) + '.json';
    if FileExists(LFinal) then
    begin
      LExisting := ReadPacket(LFinal);
      try
        Need(LExisting.AsJSON = Result.AsJSON,
          'Existing proposal packet differs from analysis policy');
      finally
        LExisting.Free;
      end;
      Exit;
    end;
    LText := Result.AsJSON + LineEnding;
    Need(Length(LText) <= CMaximumPacketBytes,
      'Proposal packet exceeds size bound');
    Need(CreateGUID(LGuid) = 0, 'Could not create proposal stage identity');
    LStage := IncludeTrailingPathDelimiter(LDirectory) +
      GUIDToString(LGuid) + '.partial';
    try
      LStream := TFileStream.Create(LStage, fmCreate or fmShareExclusive);
      try
        LStream.WriteBuffer(LText[1], Length(LText));
      finally
        LStream.Free;
      end;
      Need(RenameFile(LStage, LFinal), 'Could not publish proposal packet');
    finally
      if FileExists(LStage) then
      begin
        DeleteFile(LStage);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function CatalogProposalExists(const ACatalogRoot, AHash,
  AProposalId: String): Boolean;
var
  LDash: Integer;
  LPath: String;
  LPacket: TJSONObject;
  LRows: TJSONArray;
  LIndex: Integer;
begin
  Result := False;
  if not SafeIdentifier(AProposalId) or
    (Copy(AProposalId, 1, 5) <> 'beat-') then
  begin
    Exit;
  end;
  LDash := LastDelimiter('-', AProposalId);
  if LDash <= 5 then
  begin
    Exit;
  end;
  LPath := IncludeTrailingPathDelimiter(ProposalDirectory(ACatalogRoot, AHash)) +
    Copy(AProposalId, 1, LDash - 1) + '.json';
  if not FileExists(LPath) then
  begin
    Exit;
  end;
  LPacket := ReadPacket(LPath);
  try
    Need((LPacket.Integers['version'] = 1) and
      (LPacket.Strings['source_sha256'] = AHash) and
      (LPacket.Strings['status'] = 'unreviewed') and
      (LPacket.Strings['analyzer'] = 'pythian.beat.wave'),
      'Stored proposal identity differs from source');
    LRows := LPacket.Arrays['candidates'];
    for LIndex := 0 to LRows.Count - 1 do
    begin
      if LRows.Objects[LIndex].Strings['proposal_id'] = AProposalId then
      begin
        Exit(True);
      end;
    end;
  finally
    LPacket.Free;
  end;
end;

end.
