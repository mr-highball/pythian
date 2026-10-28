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
program pythian_tests_context_profile_progress;
{$mode delphi}{$H+}

uses SysUtils, pythian.audio, pythian.hash, pythian.tonal, pythian.progress,
  pythian.music.context, pythian.wfc.context, pythian.wfc.context.archive,
  pythian.wfc.context.profile, wfc_sequence, wfc_sequence_text;

type
  TStage = record
    Name: String;
    Last: Int64;
    Pass: Integer;
    Interior: Boolean;
    Final: Boolean;
  end;
  TStages = array of TStage;
  TObserver = class
  public
    Calls: Integer;
    Stages: TStages;
    Target: String;
    FinalOnly: Boolean;
    Marker: Exception;
    procedure Reset;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GObserver: TObserver;
  GEvidence: TContextEvidenceArray;
  GBundle: TContextLearningBundle;
  GOther: TContextLearningBundle;
  GSource: TContextProfile;
  GOtherSource: TContextProfile;
  GSelected: TContextProfile;
  GBytes: TAudioBytes;
  GProfileBytes: TAudioBytes;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise Exception.Create(AMessage);
end;

procedure TObserver.Reset;
begin
  Stages := nil;
  Target := '';
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  I: Integer;
  LFinal: Boolean;
begin
  Inc(Calls);
  Check((AWork.Stage <> '') and (AWork.Pass >= 0) and (AWork.Done >= 0) and
    (AWork.Total >= 0) and ((AWork.Total = 0) or (AWork.Done <= AWork.Total)),
    'Invalid archive/profile progress');
  Check(AWork.Units in [wuItems, wuBytes], 'Unexpected archive/profile units');
  if Pos('_bytes', AWork.Stage) > 0 then
    Check(AWork.Units = wuBytes, 'Byte stage reported item units')
  else
    Check(AWork.Units = wuItems, 'Row/visit stage reported byte units');
  I := 0;
  while (I < Length(Stages)) and (Stages[I].Name <> AWork.Stage) do Inc(I);
  if I = Length(Stages) then
  begin
    SetLength(Stages, I + 1);
    Stages[I].Name := AWork.Stage;
  end;
  if (AWork.Done = 0) or (AWork.Pass <> Stages[I].Pass) then
    Stages[I].Last := 0;
  Check(AWork.Done >= Stages[I].Last, 'Count went backwards without a new invocation/pass');
  Stages[I].Last := AWork.Done;
  Stages[I].Pass := AWork.Pass;
  LFinal := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  if LFinal then Stages[I].Final := True
  else if AWork.Done > 0 then Stages[I].Interior := True;
  if (AWork.Stage = Target) and (AWork.Done > 0) and
    ((FinalOnly and LFinal) or ((not FinalOnly) and (not LFinal))) then
    raise Marker;
end;

function Fingerprint(const ABytes: TAudioBytes): String;
begin
  Result := Sha256Bytes(ABytes);
end;

function RunAPI(const AMode: Integer; const AProgress: TWorkProgressCallback): String;
var
  LBundle: TContextLearningBundle;
  LProfile: TContextProfile;
  LModel: TWfcSequenceModel;
  LEvidence: TContextEvidenceArray;
begin
  LBundle := nil;
  LProfile := nil;
  LModel := nil;
  try
    case AMode of
      0: LBundle := TContextLearningBundle.Create(GEvidence, 4, 4, AProgress);
      1:
        begin
          LEvidence := GBundle.CopyEvidence(AProgress);
          LBundle := TContextLearningBundle.Create(LEvidence, 4, 4);
          LEvidence[0].Grid.Keys[0].Root := 11;
          Check(GBundle.ModelText(cdKey) = LBundle.ModelText(cdKey), 'Evidence copy aliased source');
        end;
      2: LModel := GBundle.CopyModel(cdTempo, AProgress);
      3: Exit(Fingerprint(EncodeContextLearning(GBundle, AProgress)));
      4: LBundle := DecodeContextLearning(GBytes, AProgress);
      5: LProfile := TContextProfile.Create(GBundle, AProgress);
      6: LProfile := TContextProfile.CreateArchive(GProfileBytes, AProgress);
      7: LBundle := GSelected.CopyBundle(cdTempo, AProgress);
      8: LModel := GSelected.CopyModel(cdKey, AProgress);
      9: LProfile := GSelected.CopyParent(cdTempo, AProgress);
      10: Exit(GSelected.ParentIdentity(cdKey, AProgress));
      11: Exit(GSelected.ProviderIdentity(cdTempo, AProgress));
      12: LProfile := SelectContextProfile(GSelected, GSource, AProgress);
      13: Exit(Fingerprint(EncodeContextProfile(GSelected, AProgress)));
      14: LProfile := DecodeContextProfile(GProfileBytes, AProgress);
    else raise Exception.Create('Unknown fixture mode');
    end;
    if LModel <> nil then Result := EncodeWfcSequenceText(LModel)
    else if LBundle <> nil then Result := Fingerprint(EncodeContextLearning(LBundle))
    else Result := Fingerprint(EncodeContextProfile(LProfile));
  finally
    LModel.Free;
    LProfile.Free;
    LBundle.Free;
  end;
end;

procedure CheckSources;
begin
  Check(Fingerprint(EncodeContextLearning(GBundle)) = Fingerprint(GBytes), 'Bundle source changed');
  Check(Fingerprint(EncodeContextProfile(GSelected)) = Fingerprint(GProfileBytes), 'Profile source changed');
  Check((GEvidence[0].Grid.Keys[0].Root = 0) and
    (GEvidence[1].Grid.Tempos[512] = 500000 + (512 mod 73)), 'Caller evidence changed');
end;

procedure RequireStage(const AName: String; const ALast: Int64 = -1);
var
  LStage: TStage;
begin
  for LStage in GObserver.Stages do
  begin
    if LStage.Name = AName then
    begin
      Check(LStage.Final, 'Required stage never completed: ' + AName);
      if ALast >= 0 then
        Check(LStage.Last = ALast, 'Stage counted a capacity instead of work: ' + AName);
      Exit;
    end;
  end;
  Check(False, 'Required owned stage was not forwarded: ' + AName);
end;

procedure RequireAPIStages(const AMode: Integer);
begin
  case AMode of
    0:
      begin
        RequireStage('context_evidence_rows', 2);
        RequireStage('context_evidence_validate_cells', 513);
        RequireStage('context_evidence_copy_cells', 1026);
        RequireStage('context_wfc_observation_rows', 1026);
        RequireStage('context_bundle_ready', 1);
      end;
    1: RequireStage('context_evidence_copy_cells', 1026);
    2: RequireStage('context_copy_model_visits');
    3:
      begin
        RequireStage('context_evidence_copy_cells', 1026);
        RequireStage('context_archive_encode_bytes', Length(GBytes) - 64);
        RequireStage('verify_audio_bytes', Length(GBytes) - 64);
        RequireStage('context_archive_encode_ready', 1);
      end;
    4:
      begin
        RequireStage('context_archive_decode_bytes', Length(GBytes) - 64);
        RequireStage('context_wfc_observation_rows', 1026);
        RequireStage('context_archive_decode_ready', 1);
      end;
    5: RequireStage('context_profile_nodes', 1);
    6, 14: RequireStage('context_profile_nodes', 3);
    7: RequireStage('context_archive_decode_ready', 1);
    8: RequireStage('context_copy_model_visits');
    9: RequireStage('context_profile_ready', 1);
    10, 11: RequireStage('verify_audio_bytes');
    12:
      begin
        RequireStage('context_profile_encode_bytes');
        RequireStage('context_profile_nodes', 5);
      end;
    13: RequireStage('context_profile_copy_bytes', Length(GProfileBytes));
  end;
end;

procedure TestAPIs;
var
  LMode: Integer;
  LStages: TStages;
  LStage: TStage;
  LFinal: Boolean;
  LReference: String;
  LValue: String;
  LExact: Boolean;
begin
  for LMode := 0 to 14 do
  begin
    LReference := RunAPI(LMode, nil);
    GObserver.Reset;
    Check(RunAPI(LMode, GObserver.Observe) = LReference, 'Observed API identity differs');
    RequireAPIStages(LMode);
    LStages := Copy(GObserver.Stages);
    Check(Length(LStages) > 0, 'Public operation failed to forward progress');
    for LStage in LStages do
      for LFinal := False to True do
      begin
        if (LFinal and not LStage.Final) or ((not LFinal) and not LStage.Interior) then Continue;
        GObserver.Reset;
        GObserver.Target := LStage.Name;
        GObserver.FinalOnly := LFinal;
        GObserver.Marker := Exception.Create('Big Boss original context archive/profile abort');
        LValue := 'unpublished sentinel';
        LExact := False;
        try
          try
            LValue := RunAPI(LMode, GObserver.Observe);
          except
            on LException: Exception do
            begin
              if LException <> GObserver.Marker then raise;
              GObserver.Marker := nil;
              LExact := True;
              Inc(GAborts);
            end;
          end;
          Check(LExact and (LValue = 'unpublished sentinel'),
            'Original exception/publication changed: ' + IntToStr(LMode) + '/' + LStage.Name);
        finally
          GObserver.Target := '';
          GObserver.Marker.Free;
          GObserver.Marker := nil;
        end;
        CheckSources;
        GObserver.Reset;
        Check(RunAPI(LMode, GObserver.Observe) = LReference, 'Retry identity differs');
      end;
    WriteLn('API ', LMode, ': ', Length(LStages), ' observed stages, exact retry passed');
  end;
end;

procedure TestMalformed;
var
  LBad: TAudioBytes;
  LBundle: TContextLearningBundle;
  LProfile: TContextProfile;
  LCase: Integer;
  LObserved: Boolean;
  LFirst: String;
  LText: String;
  LProgress: TWorkProgressCallback;
begin
  for LCase := 0 to 3 do
  begin
    if LCase = 0 then LBad := Copy(GBytes) else LBad := Copy(GProfileBytes);
    if LCase < 2 then LBad[High(LBad)] := LBad[High(LBad)] xor 1
    else SetLength(LBad, 79);
    LFirst := '';
    for LObserved := False to True do
    begin
      GObserver.Reset;
      LProgress := nil;
      if LObserved then LProgress := GObserver.Observe;
      LBundle := nil;
      LProfile := nil;
      LText := '';
      try
        try
          if LCase = 0 then LBundle := DecodeContextLearning(LBad, LProgress)
          else LProfile := DecodeContextProfile(LBad, LProgress);
        except
          on LException: Exception do LText := LException.ClassName + ':' + LException.Message;
        end;
        Check(LText <> '', 'Malformed archive/profile accepted');
        if LObserved then Check(LText = LFirst, 'Malformed-input precedence/message changed')
        else LFirst := LText;
      finally
        LProfile.Free;
        LBundle.Free;
      end;
    end;
  end;
end;

procedure TestManagedPublication;
var
  LRetained: TContextEvidenceArray;
  LFinal: Boolean;
  LExact: Boolean;
begin
  for LFinal := False to True do
  begin
    LRetained := GBundle.CopyEvidence;
    LRetained[0].Name := 'retained caller evidence';
    LRetained[0].Grid.Keys[0].Root := 11;
    LRetained[0].Grid.Tempos[0] := 700001;
    GObserver.Reset;
    GObserver.Target := 'context_evidence_copy_cells';
    GObserver.FinalOnly := LFinal;
    GObserver.Marker := Exception.Create('Big Boss managed evidence publication marker');
    LExact := False;
    try
      try
        LRetained := GBundle.CopyEvidence(GObserver.Observe);
      except
        on LException: Exception do
        begin
          if LException <> GObserver.Marker then raise;
          GObserver.Marker := nil;
          LExact := True;
          Inc(GAborts);
        end;
      end;
      Check(LExact, 'Managed evidence callback exception changed');
      Check((Length(LRetained) = 2) and (LRetained[0].Name = 'retained caller evidence') and
        (LRetained[0].Grid.Keys[0].Root = 11) and (LRetained[0].Grid.Tempos[0] = 700001),
        'Managed evidence result published before callback success');
    finally
      GObserver.Target := '';
      GObserver.Marker.Free;
      GObserver.Marker := nil;
    end;
    CheckSources;
  end;
end;

procedure Setup;
var
  I: Integer;
  J: Integer;
  LOtherEvidence: TContextEvidenceArray;
begin
  SetLength(GEvidence, 2);
  for I := 0 to 1 do
  begin
    GEvidence[I].Name := StringOfChar('n', 2048);
    GEvidence[I].SourceSha256 := StringOfChar('a', 64);
    GEvidence[I].AdmissionPolicy := StringOfChar('p', 4096);
    GEvidence[I].SourceFrameOffset := I * 973;
    GEvidence[I].Grid.TicksPerQuarter := 480;
    GEvidence[I].Grid.StepTicks := 120;
    SetLength(GEvidence[I].Grid.Keys, 513);
    SetLength(GEvidence[I].Grid.Tempos, 513);
    for J := 0 to 512 do
    begin
      GEvidence[I].Grid.Keys[J] := MakeKeyContext(J mod 12, dmMajor);
      GEvidence[I].Grid.Tempos[J] := 500000 + (J mod 73);
    end;
  end;
  GBundle := TContextLearningBundle.Create(GEvidence, 4, 4);
  LOtherEvidence := GBundle.CopyEvidence;
  for I := 0 to 1 do
    for J := 0 to 512 do
      LOtherEvidence[I].Grid.Tempos[J] := 600000 + (J mod 71);
  GOther := TContextLearningBundle.Create(LOtherEvidence, 4, 4);
  GSource := TContextProfile.Create(GBundle);
  GOtherSource := TContextProfile.Create(GOther);
  GSelected := SelectContextProfile(GSource, GOtherSource);
  GBytes := EncodeContextLearning(GBundle);
  GProfileBytes := EncodeContextProfile(GSelected);
end;

begin
  GObserver := TObserver.Create;
  try
    Setup;
    TestManagedPublication;
    TestMalformed;
    TestAPIs;
    WriteLn('Context archive/profile progress: ', GChecks, ' checks; ', GAborts,
      ' original abort/retries; ', GObserver.Calls, ' callbacks');
  finally
    GSelected.Free;
    GOtherSource.Free;
    GSource.Free;
    GOther.Free;
    GBundle.Free;
    GObserver.Free;
  end;
end.
