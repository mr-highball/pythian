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
unit pythian.tools.annotations.reference;

{$mode delphi}
{$H+}

interface

{ Creates an evaluator-compatible presence reference from a reviewed catalog.
  Unlabeled centers stay unknown; this does not establish acoustic correctness,
  complete reference coverage, or independence from an estimator. }
function BuildReviewedPresenceReference(const APlanPath, APacketPath,
  ASourcePath: String): UTF8String;

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.wave.read,
  pythian.tools.annotations.export;

const
  CMaximumPlanBytes = 16384;
  CMaximumCenters = 32768;
  CMaximumLabelCenterWork = 50000000;
  CMaximumOutputBytes = 8388608;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function Field(const AObject: TJSONObject; const AName: String;
  const AType: TJSONType): TJSONData;
begin
  Result := AObject.Find(AName);
  Need((Result <> nil) and (Result.JSONType = AType),
    'Invalid presence reference plan field: ' + AName);
end;

function TextField(const AObject: TJSONObject; const AName: String): String;
begin
  Result := Field(AObject, AName, jtString).AsString;
end;

function IntField(const AObject: TJSONObject; const AName: String): Int64;
begin
  Need(TryStrToInt64(Field(AObject, AName, jtNumber).AsJSON, Result),
    'Presence reference plan requires integer ' + AName);
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

procedure CheckHash(const AObject: TJSONObject; const AName: String);
begin
  Need(ValidHash(TextField(AObject, AName)),
    'Invalid presence reference hash: ' + AName);
end;

function ReadPlan(const APath: String): TJSONObject;
var
  LInput: TFileStream;
  LText: String;
  LData: TJSONData;
begin
  LInput := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LInput.Size > 0) and (LInput.Size <= CMaximumPlanBytes),
      'Presence reference plan exceeds size bound');
    SetLength(LText, Integer(LInput.Size));
    LInput.ReadBuffer(LText[1], Length(LText));
  finally
    LInput.Free;
  end;
  try
    LData := GetJSON(LText);
  except
    on LError: Exception do
    begin
      raise EAudio.Create('Invalid presence reference plan JSON: ' +
        LError.Message);
    end;
  end;
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Presence reference plan must be an object');
  end;
  Result := TJSONObject(LData);
  try
    Need(Result.Count = 14, 'Unexpected presence reference plan fields');
    Need((TextField(Result, 'format') =
      'pythian-reviewed-presence-reference-plan') and
      (IntField(Result, 'version') = 1),
      'Unsupported presence reference plan');
    CheckHash(Result, 'packet_sha256');
    CheckHash(Result, 'source_sha256');
    CheckHash(Result, 'preparation_sha256');
    CheckHash(Result, 'scoring_policy_sha256');
    CheckHash(Result, 'annotation_policy_sha256');
    Need((Length(TextField(Result, 'source_group')) > 0) and
      (Length(TextField(Result, 'source_group')) <= 256) and
      (Length(TextField(Result, 'part')) <= 128),
      'Invalid presence reference group or part');
    Need((TextField(Result, 'partition') = 'training') or
      (TextField(Result, 'partition') = 'development') or
      (TextField(Result, 'partition') = 'evaluation'),
      'Invalid presence reference partition');
    IntField(Result, 'first_frame');
    IntField(Result, 'end_frame');
    IntField(Result, 'first_center');
    IntField(Result, 'hop_frames');
  except
    Result.Free;
    raise;
  end;
end;

function SourceTrack(const APacket: TJSONObject; const AHash: String): TJSONObject;
var
  LTracks: TJSONArray;
  LIndex: Integer;
begin
  Result := nil;
  LTracks := APacket.Arrays['tracks'];
  for LIndex := 0 to LTracks.Count - 1 do
  begin
    if LTracks.Objects[LIndex].Objects['source']
      .Strings['source_sha256'] = AHash then
    begin
      Result := LTracks.Objects[LIndex];
      Exit;
    end;
  end;
  Need(False, 'Presence reference source is absent from reviewed packet');
end;

function SelectedPresence(const ATrack: TJSONObject;
  const APart: String): TJSONArray;
var
  LSource: TJSONArray;
  LRow: TJSONObject;
  LPass: Integer;
  LIndex: Integer;
begin
  Result := TJSONArray.Create;
  try
    for LPass := 0 to 1 do
    begin
      if LPass = 0 then
      begin
        LSource := ATrack.Arrays['selected_labels'];
      end
      else
      begin
        LSource := ATrack.Arrays['unknown_labels'];
      end;
      for LIndex := 0 to LSource.Count - 1 do
      begin
        LRow := LSource.Objects[LIndex];
        if (LRow.Strings['type'] = 'presence') and
          (LRow.Strings['part'] = APart) then
        begin
          Result.Add(LRow.Clone);
        end;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function CenterState(const ARows: TJSONArray; const AFrame: Int64): String;
var
  LRow: TJSONObject;
  LIndex: Integer;
  LCount: Integer;
begin
  Result := 'unknown';
  LCount := 0;
  for LIndex := 0 to ARows.Count - 1 do
  begin
    LRow := ARows.Objects[LIndex];
    if (LRow.Int64s['start_frame'] <= AFrame) and
      (AFrame < LRow.Int64s['end_frame']) then
    begin
      Inc(LCount);
      if LCount > 1 then
      begin
        Exit('ambiguous');
      end;
      if LRow.Strings['value'] = 'audible' then
      begin
        Result := 'value';
      end
      else
      begin
        Result := LRow.Strings['value'];
      end;
    end;
  end;
end;

function BuildReviewedPresenceReference(const APlanPath, APacketPath,
  ASourcePath: String): UTF8String;
var
  LPlan: TJSONObject;
  LPacket: TJSONObject;
  LTrack: TJSONObject;
  LSource: TJSONObject;
  LRows: TJSONArray;
  LOutput: TJSONObject;
  LClock: TJSONObject;
  LCells: TJSONArray;
  LCell: TJSONObject;
  LPacketStream: TFileStream;
  LSourceStream: TFileStream;
  LWave: TWaveFrameReader;
  LFirst: Int64;
  LEnd: Int64;
  LCenter: Int64;
  LHop: Int64;
  LCount: Int64;
  LFrame: Int64;
  LKnown: Integer;
  LIndex: Integer;
  LState: String;
begin
  LPlan := ReadPlan(APlanPath);
  LPacket := nil;
  LRows := nil;
  LOutput := nil;
  LPacketStream := nil;
  LSourceStream := nil;
  LWave := nil;
  try
    LPacketStream := TFileStream.Create(APacketPath,
      fmOpenRead or fmShareDenyWrite);
    Need(Sha256Stream(LPacketStream, LPacketStream.Size) =
      TextField(LPlan, 'packet_sha256'),
      'Presence reference packet SHA256 differs from plan');
    LPacket := ReadReviewedCatalogPacket(APacketPath);
    LTrack := SourceTrack(LPacket, TextField(LPlan, 'source_sha256'));
    LSource := LTrack.Objects['source'];
    Need((LSource.Strings['source_group'] =
      TextField(LPlan, 'source_group')) and
      (LSource.Strings['partition'] = TextField(LPlan, 'partition')),
      'Presence reference source group or partition differs');
    LFirst := IntField(LPlan, 'first_frame');
    LEnd := IntField(LPlan, 'end_frame');
    LCenter := IntField(LPlan, 'first_center');
    LHop := IntField(LPlan, 'hop_frames');
    Need((LFirst >= 0) and (LEnd > LFirst) and
      (LEnd <= LSource.Int64s['frame_count']) and
      (LHop > 0) and (LHop <= LEnd - LFirst) and
      (LCenter >= LFirst) and (LCenter < LEnd) and
      (LCenter - LFirst < LHop),
      'Invalid presence reference scope or center grid');
    LCount := 1 + (LEnd - 1 - LCenter) div LHop;
    Need(LCount <= CMaximumCenters,
      'Presence reference center count exceeds bound');
    LSourceStream := TFileStream.Create(ASourcePath,
      fmOpenRead or fmShareDenyWrite);
    Need((LSourceStream.Size = LSource.Int64s['source_bytes']) and
      (Sha256Stream(LSourceStream, LSourceStream.Size) =
      LSource.Strings['source_sha256']),
      'Presence reference WAV identity differs');
    LSourceStream.Position := 0;
    LWave := TWaveFrameReader.Create(LSourceStream);
    Need((LWave.SampleRate = LSource.Integers['sample_rate']) and
      (LWave.FrameCount = LSource.Int64s['frame_count']),
      'Presence reference WAV clock differs');
    LRows := SelectedPresence(LTrack, TextField(LPlan, 'part'));
    Need(Int64(LRows.Count) * LCount <= CMaximumLabelCenterWork,
      'Presence reference label-center work exceeds bound');
    for LIndex := 0 to LRows.Count - 1 do
    begin
      Need(LRows.Objects[LIndex].Strings['proposal_id'] = '',
        'Proposal-linked presence cannot form an independent reference');
    end;
    LKnown := 0;
    LOutput := TJSONObject.Create;
    LOutput.Add('format', 'pythian-evaluation-reference');
    LClock := TJSONObject.Create;
    LOutput.Add('clock', LClock);
    LClock.Add('source_sha256', LSource.Strings['source_sha256']);
    LClock.Add('preparation_sha256',
      TextField(LPlan, 'preparation_sha256'));
    LClock.Add('scoring_policy_sha256',
      TextField(LPlan, 'scoring_policy_sha256'));
    LClock.Add('sample_rate', LSource.Integers['sample_rate']);
    LClock.Add('source_frames', LSource.Int64s['frame_count']);
    LClock.Add('first_frame', LFirst);
    LClock.Add('end_frame', LEnd);
    LOutput.Add('annotation_policy_sha256',
      TextField(LPlan, 'annotation_policy_sha256'));
    LCells := TJSONArray.Create;
    LOutput.Add('observations', LCells);
    for LIndex := 0 to LCount - 1 do
    begin
      LFrame := LCenter + Int64(LIndex) * LHop;
      LState := CenterState(LRows, LFrame);
      LCell := TJSONObject.Create;
      LCells.Add(LCell);
      LCell.Add('frame', LFrame);
      LCell.Add('state', LState);
      if LState = 'value' then
      begin
        LCell.Add('value', 0);
      end;
      if (LState = 'value') or (LState = 'rest') then
      begin
        Inc(LKnown);
      end;
    end;
    Need(LKnown > 0, 'Presence reference has no reviewed audible/rest center');
    LSourceStream.Position := 0;
    Need(Sha256Stream(LSourceStream, LSourceStream.Size) =
      LSource.Strings['source_sha256'],
      'Presence reference WAV changed during build');
    LPacketStream.Position := 0;
    Need(Sha256Stream(LPacketStream, LPacketStream.Size) =
      TextField(LPlan, 'packet_sha256'),
      'Presence reference packet changed during build');
    Result := LOutput.AsJSON;
    Need(Length(Result) <= CMaximumOutputBytes,
      'Presence reference exceeds evaluator document bound');
  finally
    LWave.Free;
    LSourceStream.Free;
    LPacketStream.Free;
    LOutput.Free;
    LRows.Free;
    LPacket.Free;
    LPlan.Free;
  end;
end;

end.
