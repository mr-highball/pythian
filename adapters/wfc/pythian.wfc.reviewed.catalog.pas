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
unit pythian.wfc.reviewed.catalog;

{$mode delphi}
{$H+}

interface

uses
  pythian.wfc.admitted.pitch;

{ Reads one verified training-partition source and one exact part. Approved
  notes become pitch spans; approved part-specific rest/unknown reviews retain
  their meanings. Unreviewed proposals and other label types contribute
  nothing. Caller still decides whether the reviewed labels are acoustically
  trustworthy; this adapter only enforces source and schema boundaries. }
function ReadReviewedNoteSource(const APacketPath, ASourcePath,
  APart: String): TAdmittedNoteSource;

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.pitch.track,
  pythian.wave.read,
  pythian.tools.annotations.export;

const
  CMaximumSourceBytes: Int64 = 17179869184;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function HashText(const AText: UTF8String): String;
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], LBytes[0], Length(AText));
  end;
  Result := Sha256Bytes(LBytes);
end;

function SpanBefore(const ALeft, ARight: TAdmittedNoteSpan): Boolean;
begin
  if ALeft.StartFrame <> ARight.StartFrame then
  begin
    Exit(ALeft.StartFrame < ARight.StartFrame);
  end;
  if ALeft.EndFrame <> ARight.EndFrame then
  begin
    Exit(ALeft.EndFrame < ARight.EndFrame);
  end;
  if ALeft.Kind <> ARight.Kind then
  begin
    Exit(Ord(ALeft.Kind) < Ord(ARight.Kind));
  end;
  Result := ALeft.Note <= ARight.Note;
end;

procedure SortSpans(var ASpans, AWork: TAdmittedNoteSpans;
  const AFirst, AEnd: Integer);
var
  LMiddle: Integer;
  LLeft: Integer;
  LRight: Integer;
  LIndex: Integer;
  LTakeLeft: Boolean;
begin
  if AEnd - AFirst <= 1 then
  begin
    Exit;
  end;
  LMiddle := AFirst + (AEnd - AFirst) div 2;
  SortSpans(ASpans, AWork, AFirst, LMiddle);
  SortSpans(ASpans, AWork, LMiddle, AEnd);
  LLeft := AFirst;
  LRight := LMiddle;
  for LIndex := AFirst to AEnd - 1 do
  begin
    if LRight >= AEnd then
    begin
      LTakeLeft := True;
    end
    else if LLeft >= LMiddle then
    begin
      LTakeLeft := False;
    end
    else
    begin
      LTakeLeft := SpanBefore(ASpans[LLeft], ASpans[LRight]);
    end;
    if LTakeLeft then
    begin
      AWork[LIndex] := ASpans[LLeft];
      Inc(LLeft);
    end
    else
    begin
      AWork[LIndex] := ASpans[LRight];
      Inc(LRight);
    end;
  end;
  for LIndex := AFirst to AEnd - 1 do
  begin
    ASpans[LIndex] := AWork[LIndex];
  end;
end;

procedure AddSpan(var ASpans: TAdmittedNoteSpans; const ARow: TJSONObject;
  const AKind: TPitchSpanKind; const ANote: Integer);
var
  LIndex: Integer;
begin
  Need(Length(ASpans) < MaximumAdmittedInputSpans,
    'Reviewed note source exceeds admitted span capacity');
  LIndex := Length(ASpans);
  SetLength(ASpans, LIndex + 1);
  ASpans[LIndex].Kind := AKind;
  ASpans[LIndex].Note := ANote;
  ASpans[LIndex].StartFrame := ARow.Int64s['start_frame'];
  ASpans[LIndex].EndFrame := ARow.Int64s['end_frame'];
end;

function ReadReviewedNoteSource(const APacketPath, ASourcePath,
  APart: String): TAdmittedNoteSource;
var
  LPacket: TJSONObject;
  LTracks: TJSONArray;
  LTrack: TJSONObject;
  LSource: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LInput: TFileStream;
  LWave: TWaveFrameReader;
  LWork: TAdmittedNoteSpans;
  LSourceHash: String;
  LIndex: Integer;
  LTrackIndex: Integer;
  LPitchCount: Integer;
begin
  Result := Default(TAdmittedNoteSource);
  Need(Length(APart) <= 128, 'Reviewed note part exceeds label bound');
  LPacket := ReadReviewedCatalogPacket(APacketPath);
  LInput := nil;
  LWave := nil;
  try
    LInput := TFileStream.Create(ASourcePath, fmOpenRead or fmShareDenyWrite);
    Need((LInput.Size >= 44) and (LInput.Size <= CMaximumSourceBytes),
      'Reviewed note WAV exceeds catalog byte bound');
    LSourceHash := Sha256Stream(LInput, LInput.Size);
    LTrack := nil;
    LTracks := LPacket.Arrays['tracks'];
    for LTrackIndex := 0 to LTracks.Count - 1 do
    begin
      if LTracks.Objects[LTrackIndex].Objects['source']
        .Strings['source_sha256'] = LSourceHash then
      begin
        LTrack := LTracks.Objects[LTrackIndex];
        Break;
      end;
    end;
    Need(LTrack <> nil, 'Reviewed note WAV is absent from catalog packet');
    LSource := LTrack.Objects['source'];
    Need(LSource.Strings['partition'] = 'training',
      'Reviewed note learning requires training partition');
    Need(LSource.Int64s['source_bytes'] = LInput.Size,
      'Reviewed note source byte count differs');
    LInput.Position := 0;
    LWave := TWaveFrameReader.Create(LInput);
    Need((LWave.SampleRate = LSource.Integers['sample_rate']) and
      (LWave.FrameCount = LSource.Int64s['frame_count']) and
      (LWave.FrameCount <= High(Integer)),
      'Reviewed note WAV clock or admitted frame capacity differs');
    Result.GroupId := 'group-' +
      HashText(UTF8String(LSource.Strings['source_group']));
    Result.RecordingId := 'wav-' + LSourceHash;
    Result.SourceSha256 := LSourceHash;
    Result.SourceAnnotationId := 'review-' + LSourceHash;
    Result.SourceAnnotationSha256 :=
      HashText(UTF8String(LTrack.AsJSON));
    Result.SourceAnnotationPublisher := 'pythian-catalog';
    Result.SourceAnnotationMethod := 'reviewed-approved-v1';
    Result.SampleRate := LWave.SampleRate;
    Result.SourceFrameCount := LWave.FrameCount;
    LPitchCount := 0;
    LRows := LTrack.Arrays['selected_labels'];
    for LIndex := 0 to LRows.Count - 1 do
    begin
      LRow := LRows.Objects[LIndex];
      if LRow.Strings['part'] <> APart then
      begin
        Continue;
      end;
      if LRow.Strings['type'] = 'note' then
      begin
        Need(LRow.Strings['status'] = 'approved',
          'Unapproved note entered selected catalog labels');
        AddSpan(Result.Spans, LRow, pskPitch,
          LRow.Integers['pitch_midi']);
        Inc(LPitchCount);
      end
      else if (LRow.Strings['type'] = 'presence') and
        (LRow.Strings['value'] = 'rest') then
      begin
        Need(LRow.Strings['status'] = 'approved',
          'Unapproved rest entered selected catalog labels');
        AddSpan(Result.Spans, LRow, pskSilence, -1);
      end;
    end;
    LRows := LTrack.Arrays['unknown_labels'];
    for LIndex := 0 to LRows.Count - 1 do
    begin
      LRow := LRows.Objects[LIndex];
      if (LRow.Strings['part'] = APart) and
        (LRow.Strings['type'] = 'presence') and
        (LRow.Strings['value'] = 'unknown') then
      begin
        Need(LRow.Strings['status'] = 'approved',
          'Unapproved unknown entered reviewed catalog labels');
        AddSpan(Result.Spans, LRow, pskUnknown, -1);
      end;
    end;
    Need(LPitchCount > 0,
      'Reviewed note source has no approved pitch span for selected part');
    SetLength(LWork, Length(Result.Spans));
    SortSpans(Result.Spans, LWork, 0, Length(Result.Spans));
    for LIndex := 1 to High(Result.Spans) do
    begin
      Need(Result.Spans[LIndex].StartFrame >=
        Result.Spans[LIndex - 1].EndFrame,
        'Reviewed note/rest/unknown spans overlap in selected part');
    end;
    LInput.Position := 0;
    Need(Sha256Stream(LInput, LInput.Size) = LSourceHash,
      'Reviewed note WAV changed during admission');
  finally
    LWave.Free;
    LInput.Free;
    LPacket.Free;
  end;
end;

end.
