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
program pythian_tests_duration_stream;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.bus, pythian.effects, pythian.echo,
  pythian.synth, pythian.wave, pythian.time, pythian.music.context,
  pythian.pitch.track, pythian.tonal, pythian.wfc.context, pythian.wfc.pitch,
  pythian.wfc.instrument, pythian.wfc.duration.stream, pythian.progress,
  wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_graph, wfc_sequence_text,
  wfc_music, wfc_music_sequence, wfc_music_ensemble,
  wfc_music_ensemble_graph, wfc_music_voices_graph;

const CRate = 8000;
type
  TFixture = class
    LongMode: Boolean;
    Models: TDurationModels;
    Config: TWfcMusicVoicesGraphConfig;
    Instruments: TStyleInstruments;
    constructor Create;
    destructor Destroy; override;
    function NewStream(const ABus: TBusGraph; const AOptions: TDurationStreamOptions;
      const AProgress: TWorkProgressCallback = nil): TDurationStream;
  end;
  { Big Boss: address each actual retained model copy, including copies made
    after earlier ones succeed. The observer is borrowed only by construction. }
  TCloneObserver = class
    Target: Integer;
    Index: Integer;
    FinalPoint: Boolean;
    Raised: Boolean;
    Marker: Exception;
    procedure Observe(const AWork: TWorkProgress);
  end;
  { Big Boss: frozen observations from the actual duration callback stream;
    they select bounded first/interior/final stage/pass cancellation points. }
  TEditEvents = array of TWorkProgress;
  { Big Boss: callbacks may inspect accepted state but cannot edit/process it.
    The record stream is test evidence, never a second planning implementation. }
  TEditObserver = class
    Stream: TDurationStream;
    Edit: TDurationEdit;
    ExpectedRevision, ExpectedFrame: Int64;
    Calls, AbortAt, Reentry: Integer;
    Capture: Boolean;
    Events: TEditEvents;
    Marker: Exception;
    ProbeLeft, ProbeRight: Double;
    procedure Attach(const AStream: TDurationStream; const AEdit: TDurationEdit;
      const ACapture: Boolean);
    procedure Observe(const AWork: TWorkProgress);
  end;
  TFailEffect = class(TAudioEffect)
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
  end;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

function Voice(const AAction: TWfcMusicCellAction; const APitch: Integer;
  const AVelocity: Integer = 90): String;
var LFrame: TWfcMusicEnsembleFrame;
begin
  SetLength(LFrame.Voices, 1);
  LFrame.Voices[0].Action := AAction;
  if AAction <> wmcaRest then
  begin
    SetLength(LFrame.Voices[0].Tones, 1);
    LFrame.Voices[0].Tones[0] := MakeWfcMusicTone(APitch, AVelocity);
  end;
  Result := EncodeWfcMusicEnsembleFrame(LFrame);
end;

function Rhythm(const AAction: TWfcMusicCellAction): String;
begin
  Result := EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([AAction, AAction]));
end;

function Harmony(const APitchClass: Integer): String;
begin
  if APitchClass < 0 then Result := EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, []))
  else Result := EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, [APitchClass]));
end;

function Duration(const AKind: TPitchSpanKind; const APitch, ATicks: Integer): String;
var LCell: TPitchDurationCell;
begin
  LCell.Kind := AKind;
  LCell.Note := APitch;
  LCell.Duration := ATicks;
  Result := PitchDurationToken(LCell);
end;

function Learn(const ARuns: array of TWfcModelTokens; const AOrder: Integer = 2): TWfcSequenceModel;
var LSamples: TWfcSequenceSamples; LIndex: Integer;
begin
  SetLength(LSamples, Length(ARuns));
  for LIndex := 0 to High(ARuns) do LSamples[LIndex] := MakeWfcSequenceSample(ARuns[LIndex]);
  Result := LearnSequenceModelCorpus(LSamples, AOrder);
end;

constructor TFixture.Create;
var
  LRuns: array of TWfcModelTokens;
  LIndex, LRole, LPitch: Integer;
  LZones: TStyleInstrumentZones;
  LC, LM, LU, LT, LS: String;
begin
  inherited;
  LC := KeyContextToken(MakeKeyContext(0, dmMajor));
  LM := KeyContextToken(MakeKeyContext(0, dmNaturalMinor));
  LU := KeyContextToken(MakeKeyContext(-1, dmMajor));
  Models[dpKey] := Learn([[LC, LC, LC], [LC, LM, LM], [LU, LU, LU]], 1);
  LT := TempoContextToken(500000);
  LS := TempoContextToken(600000);
  Models[dpTempo] := Learn([[LT, LT, LT, LT, LT, LT],
    [LT, LS, LS, LS, LS, LS]], 1);
  SetLength(LRuns, 6);
  for LIndex := 0 to High(LRuns) do
  begin
    SetLength(LRuns[LIndex], 5);
    LRuns[LIndex][0] := Duration(pskPitch, 60, 240);
    LRuns[LIndex][1] := Duration(pskPitch, 60, 240);
    LRuns[LIndex][2] := Duration(pskUnknown, -1, 120);
    LRuns[LIndex][3] := Duration(pskPitch, 62, 240);
    LRuns[LIndex][4] := Duration(pskSilence, -1, 120);
  end;
  LRuns[1][1] := Duration(pskPitch, 60, 480);
  LRuns[2][3] := Duration(pskPitch, 64, 240);
  LRuns[3][3] := Duration(pskPitch, 62, 480);
  LRuns[4][3] := Duration(pskPitch, 62, 720);
  LRuns[5][3] := Duration(pskPitch, 62, 960);
  Models[dpDuration] := Learn(LRuns);
  Config.HarmonyModel := Learn([[Harmony(0), Harmony(0), Harmony(-1), Harmony(2), Harmony(-1)],
    [Harmony(0), Harmony(0), Harmony(-1), Harmony(4), Harmony(-1)]]);
  Config.RhythmModel := Learn([[Rhythm(wmcaAttack), Rhythm(wmcaHold), Rhythm(wmcaRest),
    Rhythm(wmcaAttack), Rhythm(wmcaRest)], [Rhythm(wmcaAttack), Rhythm(wmcaAttack),
    Rhythm(wmcaRest), Rhythm(wmcaAttack), Rhythm(wmcaRest)]]);
  SetLength(Config.Voices, 2);
  for LRole := 0 to 1 do
  begin
    LPitch := 48 + LRole * 12;
    Config.Voices[LRole].MinPitch := LPitch;
    Config.Voices[LRole].MaxPitch := LPitch + 4;
    Config.Voices[LRole].Model := Learn([
      [Voice(wmcaAttack, LPitch), Voice(wmcaHold, LPitch), Voice(wmcaRest, -1),
        Voice(wmcaAttack, LPitch + 2), Voice(wmcaRest, -1)],
      [Voice(wmcaAttack, LPitch), Voice(wmcaAttack, LPitch), Voice(wmcaRest, -1),
        Voice(wmcaAttack, LPitch + 2), Voice(wmcaRest, -1)],
      [Voice(wmcaAttack, LPitch), Voice(wmcaHold, LPitch), Voice(wmcaRest, -1),
        Voice(wmcaAttack, LPitch + 4), Voice(wmcaRest, -1)],
      [Voice(wmcaAttack, LPitch), Voice(wmcaHold, LPitch), Voice(wmcaRest, -1),
        Voice(wmcaAttack, LPitch + 2, 70), Voice(wmcaRest, -1)]]);
  end;
  Config.StepsPerOctave := 12;
  Config.HarmonyMode := wmehmExact;
  SetLength(Config.PairConstraints, 1);
  Config.PairConstraints[0].LowerVoice := 0;
  Config.PairConstraints[0].UpperVoice := 1;
  Config.PairConstraints[0].MinGap := 12;
  Config.PairConstraints[0].MaxGap := 12;
  Config.PairConstraints[0].RestPolicy := wmvprSuspend;
  SetLength(Instruments, 2);
  SetLength(LZones, 1);
  LZones[0].Zone.MinimumVelocity := 1;
  LZones[0].Zone.MaximumVelocity := 127;
  LZones[0].Zone.Voice := DefaultSynthVoice;
  for LRole := 0 to 1 do
  begin
    LZones[0].Zone.MinimumKey := Config.Voices[LRole].MinPitch;
    LZones[0].Zone.MaximumKey := Config.Voices[LRole].MaxPitch;
    Instruments[LRole] := TStyleInstrument.Create(LZones, CRate);
  end;
end;

destructor TFixture.Destroy;
var LProvider: TDurationProvider; LIndex: Integer;
begin
  for LProvider := Low(TDurationProvider) to High(TDurationProvider) do Models[LProvider].Free;
  Config.HarmonyModel.Free;
  Config.RhythmModel.Free;
  for LIndex := 0 to High(Config.Voices) do Config.Voices[LIndex].Model.Free;
  for LIndex := 0 to High(Instruments) do Instruments[LIndex].Free;
  inherited;
end;

function TFixture.NewStream(const ABus: TBusGraph; const AOptions: TDurationStreamOptions;
  const AProgress: TWorkProgressCallback): TDurationStream;
var LNames: TDurationRoleNames; LOptions: TDurationStreamOptions;
begin
  LNames := ['bass', 'lead'];
  LOptions := AOptions;
  LOptions.LeadRole := 1;
  if LongMode then
  begin
    Result := TDurationStream.Create(Models, [0, 256], [0, 256], Config,
      LNames, Instruments, ABus, LOptions, AProgress);
    Exit;
  end;
  Result := TDurationStream.Create(Models, [0, 480, 960, 1440],
    [0, 240, 480, 720, 960, 1200, 1440], Config, LNames, Instruments, ABus,
    LOptions, AProgress);
end;

procedure TCloneObserver.Observe(const AWork: TWorkProgress);
begin
  if AWork.Stage <> 'wfc_sequence_model_build_visits' then Exit;
  Check((AWork.Units = wuItems) and (AWork.Done >= 0), 'Duration clone mapping');
  if AWork.Done = 0 then Inc(Index);
  if (Index = Target) and
    (((not FinalPoint) and (AWork.Done = 0)) or
      (FinalPoint and (AWork.Total > 0) and (AWork.Done = AWork.Total))) then
  begin
    Raised := True;
    raise Marker;
  end;
end;

function NewBus: TBusGraph;
var LSettings: TEchoSettings;
begin
  Result := TBusGraph.Create(CRate, [DefaultBusSettings]);
  LSettings := DefaultEchoSettings(CRate);
  LSettings.DelayFrames := 317;
  Result.AddEffect(0, TEchoEffect.Create(CRate, LSettings));
end;

function Mask(const ATokens: array of String): TWfcSequenceTokenConstraints;
var LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ATokens));
  for LIndex := 0 to High(ATokens) do Result[LIndex] := MakeWfcSequenceTokenConstraint(LIndex, [ATokens[LIndex]]);
end;

function InitialEdit: TDurationEdit;
var LIndex, LPitch: Integer; LC, LT: String;
begin
  Result := Default(TDurationEdit);
  Result.SpanCount := 5;
  Result.Seed := 731;
  Result.Regenerate := [dpKey, dpTempo, dpDuration];
  Result.RegenerateMusic := True;
  Result.RequireObservedEnd := True;
  LC := KeyContextToken(MakeKeyContext(0, dmMajor));
  LT := TempoContextToken(500000);
  Result.Masks[dpKey] := Mask([LC, LC, LC]);
  Result.Masks[dpTempo] := Mask([LT, LT, LT, LT, LT, LT]);
  Result.Masks[dpDuration] := Mask([Duration(pskPitch, 60, 240), Duration(pskPitch, 60, 240),
    Duration(pskUnknown, -1, 120), Duration(pskPitch, 62, 240), Duration(pskSilence, -1, 120)]);
  SetLength(Result.MusicMasks, 4);
  Result.MusicMasks[0] := Mask([Harmony(0), Harmony(0), Harmony(-1), Harmony(2), Harmony(-1)]);
  Result.MusicMasks[1] := Mask([Rhythm(wmcaAttack), Rhythm(wmcaHold), Rhythm(wmcaRest), Rhythm(wmcaAttack), Rhythm(wmcaRest)]);
  for LIndex := 0 to 1 do
  begin
    LPitch := 48 + LIndex * 12;
    Result.MusicMasks[LIndex + 2] := Mask([Voice(wmcaAttack, LPitch), Voice(wmcaHold, LPitch),
      Voice(wmcaRest, -1), Voice(wmcaAttack, LPitch + 2), Voice(wmcaRest, -1)]);
  end;
end;

function FutureEdit(const AStream: TDurationStream; const AFrom: Integer): TDurationEdit;
begin
  Result := InitialEdit;
  Result.Revision := AStream.Revision;
  Result.FromSpan := AFrom;
  Result.Regenerate := [];
  Result.RegenerateMusic := False;
end;

function Snapshot(const AStream: TDurationStream): String;
var LProvider: TDurationProvider; LIndex, LCell: Integer; LSequence: TWfcGeneratedSequenceSegment;
  LSpans: TTimedPitchSpans; LNotes: TDurationNotes;
begin
  Result := IntToStr(AStream.Revision) + '/' + IntToStr(AStream.NextFrame);
  for LProvider := Low(TDurationProvider) to High(TDurationProvider) do
  begin
    LSequence := AStream.CopySequence(LProvider);
    for LCell := 0 to High(LSequence.Tokens) do
      Result := Result + '|' + IntToStr(LSequence.StateIndices[LCell]) + ':' + LSequence.Tokens[LCell];
  end;
  for LIndex := 0 to 3 do
  begin
    LSequence := AStream.CopyMusic(LIndex);
    for LCell := 0 to High(LSequence.Tokens) do
      Result := Result + '|' + IntToStr(LSequence.StateIndices[LCell]) + ':' + LSequence.Tokens[LCell];
  end;
  LSpans := AStream.CopySpans;
  for LIndex := 0 to High(LSpans) do
    Result := Result + '/' + IntToStr(Ord(LSpans[LIndex].Kind)) + ':' + IntToStr(LSpans[LIndex].Note) + ':' +
      IntToStr(LSpans[LIndex].StartTick) + ':' + IntToStr(LSpans[LIndex].EndTick);
  LNotes := AStream.CopyNotes;
  for LIndex := 0 to High(LNotes) do
    Result := Result + '/' + IntToStr(LNotes[LIndex].Role) + ':' + IntToStr(LNotes[LIndex].Pitch) + ':' +
      IntToStr(LNotes[LIndex].Velocity) + ':' + IntToStr(LNotes[LIndex].StartFrame) + ':' + IntToStr(LNotes[LIndex].GateFrames);
end;

procedure Reject(const AStream: TDurationStream; const AEdit: TDurationEdit; const AExpected: TDurationEditResult);
var LBefore: String;
begin
  LBefore := Snapshot(AStream);
  Check(AStream.TryEdit(AEdit) = AExpected, 'Unexpected duration rejection kind');
  Check(Snapshot(AStream) = LBefore, 'Rejected duration edit changed accepted plan or cursor');
end;

procedure RejectException(const AStream: TDurationStream; const AEdit: TDurationEdit);
var LBefore: String; LRaised: Boolean;
begin
  LBefore := Snapshot(AStream);
  LRaised := False;
  try AStream.TryEdit(AEdit); except on E: Exception do LRaised := True; end;
  Check(LRaised, 'Invalid duration edit should raise');
  Check(Snapshot(AStream) = LBefore, 'Invalid duration edit changed accepted plan');
end;

procedure SameFrames(const ALeft, ARight: TDurationStream; const ACount: Integer);
var LIndex: Integer; LL, LR, RL, RR: Double;
begin
  for LIndex := 1 to ACount do
  begin
    ALeft.Process(LL, LR);
    ARight.Process(RL, RR);
    Check((LL = RL) and (LR = RR), 'Committed note/effect audio changed');
  end;
end;

procedure CheckRollbackAndEdits(const AFixture: TFixture);
var
  LBus, LControlBus: TBusGraph;
  LStream, LControl: TDurationStream;
  LEdit: TDurationEdit;
  LSpans: TTimedPitchSpans;
  LNotes: TDurationNotes;
  LCopy: TWfcGeneratedSequenceSegment;
  LBefore: String;
  LIndex, LChanged: Integer;
  LL, LR, RL, RR: Double;
  LSamples, LControlSamples: TAudioSamples;
  LClip: TAudioClip;
begin
  LBus := NewBus;
  LControlBus := NewBus;
  LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
  LControl := AFixture.NewStream(LControlBus, DefaultDurationStreamOptions);
  try
    Check(LStream.RoleModelIndex('lead') = 3, 'Named role identity');
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Initial duration plan');
    Check(LControl.TryEdit(InitialEdit) = derAccepted, 'Control duration plan');
    Check(Snapshot(LStream) = Snapshot(LControl), 'Deterministic initial state');
    LSpans := LStream.CopySpans;
    Check((LSpans[2].Kind = pskUnknown) and (LSpans[2].StartTick = 480) and
      (LSpans[2].EndTick = 600) and (LSpans[4].EndTick = 960), 'Unknown and cumulative timing');
    LNotes := LStream.CopyNotes;
    Check((Length(LNotes) = 4) and (LNotes[0].GateFrames = 4000) and
      (LNotes[2].StartFrame = 5000), 'Hold gate and independent context timing');
    LBefore := Snapshot(LStream);
    LCopy := LStream.CopySequence(dpDuration);
    LCopy.StateIndices[0] := -1;
    LCopy.Tokens[0] := 'mutated';
    LSpans[0].EndTick := -1;
    LNotes[0].GateFrames := -1;
    Check(Snapshot(LStream) = LBefore, 'Detached snapshots');
    SameFrames(LStream, LControl, 1000);

    LEdit := FutureEdit(LStream, 1);
    LEdit.Regenerate := [dpTempo];
    for LIndex := 1 to 5 do LEdit.Masks[dpTempo][LIndex].AllowedTokens := [TempoContextToken(600000)];
    Reject(LStream, LEdit, derCommittedNote); { Sounding hold would change its gate. }
    LEdit := FutureEdit(LStream, 1);
    LEdit.Regenerate := [dpDuration];
    LEdit.Masks[dpDuration][1].AllowedTokens := [Duration(pskPitch, 60, 480)];
    Reject(LStream, LEdit, derCommittedNote);
    LEdit := FutureEdit(LStream, 1);
    LEdit.RegenerateMusic := True;
    LEdit.MusicMasks[1][1].AllowedTokens := [Rhythm(wmcaAttack)];
    LEdit.MusicMasks[2][1].AllowedTokens := [Voice(wmcaAttack, 48)];
    LEdit.MusicMasks[3][1].AllowedTokens := [Voice(wmcaAttack, 60)];
    Reject(LStream, LEdit, derCommittedNote);
    LEdit := FutureEdit(LStream, 2);
    LEdit.Regenerate := [dpDuration];
    LEdit.Masks[dpDuration][3].AllowedTokens := [Duration(pskPitch, 62, 960)];
    Reject(LStream, LEdit, derCoverage);
    LEdit := FutureEdit(LStream, 2);
    LEdit.Regenerate := [dpKey, dpDuration];
    LEdit.Masks[dpKey][1].AllowedTokens := [KeyContextToken(MakeKeyContext(0, dmNaturalMinor))];
    LEdit.Masks[dpKey][2].AllowedTokens := [KeyContextToken(MakeKeyContext(0, dmNaturalMinor))];
    LEdit.Masks[dpDuration][3].AllowedTokens := [Duration(pskPitch, 64, 240)];
    LEdit.MusicMasks[0][3].AllowedTokens := [Harmony(4)];
    LEdit.MusicMasks[2][3].AllowedTokens := [Voice(wmcaAttack, 52)];
    LEdit.MusicMasks[3][3].AllowedTokens := [Voice(wmcaAttack, 64)];
    Reject(LStream, LEdit, derConflict);
    LEdit := FutureEdit(LStream, 3); { Tick600 is inside key cell [480,960). }
    LEdit.Regenerate := [dpKey];
    LEdit.Masks[dpKey][1].AllowedTokens := [KeyContextToken(MakeKeyContext(0, dmNaturalMinor))];
    RejectException(LStream, LEdit);
    LEdit := FutureEdit(LStream, 2);
    Dec(LEdit.Revision);
    RejectException(LStream, LEdit);
    LEdit := FutureEdit(LStream, 0);
    RejectException(LStream, LEdit);
    SameFrames(LStream, LControl, 500); { All failures retained live echo/source history. }

    LEdit := FutureEdit(LStream, 2);
    LEdit.Regenerate := [dpKey, dpTempo, dpDuration];
    LEdit.Masks[dpKey][1].AllowedTokens := [KeyContextToken(MakeKeyContext(0, dmNaturalMinor))];
    LEdit.Masks[dpKey][2].AllowedTokens := [KeyContextToken(MakeKeyContext(0, dmNaturalMinor))];
    for LIndex := 2 to 5 do LEdit.Masks[dpTempo][LIndex].AllowedTokens := [TempoContextToken(600000)];
    LEdit.Masks[dpDuration][3].AllowedTokens := [Duration(pskPitch, 62, 480)];
    LEdit.MusicMasks[LStream.RoleModelIndex('lead')][3].AllowedTokens := [Voice(wmcaAttack, 62, 70)];
    Check(LStream.TryEdit(LEdit) = derAccepted, 'Future key/tempo/duration/named voice transaction');
    LSpans := LStream.CopySpans;
    LNotes := LStream.CopyNotes;
    Check((LSpans[4].EndTick = 1200) and (LNotes[0].GateFrames = 4000) and
      (LNotes[2].StartFrame = 5200) and (LNotes[2].GateFrames = 4800) and
      (LNotes[3].Velocity = 70), 'Recalculated future gates and preserved sounding hold');
    SameFrames(LStream, LControl, 2500); { Through pivot frame4000. }
    LChanged := 0;
    SetLength(LSamples, 18000);
    SetLength(LControlSamples, 18000);
    for LIndex := 0 to 8999 do
    begin
      LStream.Process(LL, LR);
      LControl.Process(RL, RR);
      LSamples[LIndex * 2] := LL;
      LSamples[LIndex * 2 + 1] := LR;
      LControlSamples[LIndex * 2] := RL;
      LControlSamples[LIndex * 2 + 1] := RR;
      if (LL <> RL) or (LR <> RR) then Inc(LChanged);
    end;
    Check(LChanged > 0, 'Future musical edit must be audible');
    if ParamCount > 0 then
    begin
      LClip := TAudioClip.Create(CRate, 2, LSamples);
      try SaveWavePcm16(ParamStr(1) + '-future.wav', LClip); finally LClip.Free; end;
      LClip := TAudioClip.Create(CRate, 2, LControlSamples);
      try SaveWavePcm16(ParamStr(1) + '-baseline.wav', LClip); finally LClip.Free; end;
    end;
  finally
    LStream.Free;
    LControl.Free;
    LBus.Free;
    LControlBus.Free;
  end;
end;

procedure CheckBoundaries(const AFixture: TFixture);
var LBus: TBusGraph; LStream: TDurationStream; LEdit: TDurationEdit;
  LOptions: TDurationStreamOptions; LNotes: TDurationNotes; LIndex: Integer;
  LBefore: TWfcGeneratedSequenceSegment; LAfter: TWfcGeneratedSequenceSegment;
begin
  LBus := NewBus;
  LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
  try
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Boundary initial');
    LEdit := FutureEdit(LStream, 0);
    LEdit.RegenerateMusic := True;
    LEdit.MusicMasks[1][1].AllowedTokens := [Rhythm(wmcaAttack)];
    LEdit.MusicMasks[2][1].AllowedTokens := [Voice(wmcaAttack, 48)];
    LEdit.MusicMasks[3][1].AllowedTokens := [Voice(wmcaAttack, 60)];
    Check(LStream.TryEdit(LEdit) = derAccepted, 'Pending rhythm may rearticulate before commitment');
    LNotes := LStream.CopyNotes;
    Check((Length(LNotes) = 6) and (LNotes[0].GateFrames = 2000), 'Rearticulation gates');
  finally LStream.Free; LBus.Free; end;

  LBus := NewBus;
  LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
  try
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Tempo initial');
    LBefore := LStream.CopyMusic(3);
    LEdit := FutureEdit(LStream, 2);
    LEdit.Regenerate := [dpTempo];
    for LIndex := 2 to 5 do LEdit.Masks[dpTempo][LIndex].AllowedTokens := [TempoContextToken(600000)];
    Check(LStream.TryEdit(LEdit) = derAccepted, 'Tempo-only future edit');
    LAfter := LStream.CopyMusic(3);
    for LIndex := 0 to High(LBefore.Tokens) do
      Check((LBefore.Tokens[LIndex] = LAfter.Tokens[LIndex]) and
        (LBefore.StateIndices[LIndex] = LAfter.StateIndices[LIndex]), 'Tempo preserves exact music states');
  finally LStream.Free; LBus.Free; end;

  LBus := NewBus;
  LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
  try
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Finite endpoint initial');
    LEdit := FutureEdit(LStream, 2);
    LEdit.Regenerate := [dpDuration];
    LEdit.Masks[dpDuration][3].AllowedTokens := [Duration(pskPitch, 62, 720)];
    Check(LStream.TryEdit(LEdit) = derAccepted, 'Exact finite context endpoint is covered');
    Check(LStream.CopySpans[4].EndTick = 1440, 'Exact endpoint');
  finally LStream.Free; LBus.Free; end;

  LBus := NewBus;
  LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
  try
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Named voice initial');
    LBefore := LStream.CopyMusic(LStream.RoleModelIndex('bass'));
    LEdit := FutureEdit(LStream, 2);
    LEdit.RegenerateMusic := True; { Explicit complete future replacement. }
    LEdit.MusicMasks[LStream.RoleModelIndex('lead')][3].AllowedTokens := [Voice(wmcaAttack, 62, 70)];
    Check(LStream.TryEdit(LEdit) = derAccepted, 'Same-duration named voice change');
    LAfter := LStream.CopyMusic(LStream.RoleModelIndex('bass'));
    for LIndex := 0 to High(LBefore.Tokens) do
      Check(LBefore.Tokens[LIndex] = LAfter.Tokens[LIndex], 'Explicitly retained unrelated voice choice');
    LNotes := LStream.CopyNotes;
    Check((LNotes[2].Velocity = 90) and (LNotes[3].Velocity = 70) and
      (LNotes[2].StartFrame = 5000) and (LNotes[3].StartFrame = 5000), 'Only named future voice control changes');
  finally LStream.Free; LBus.Free; end;

  LBus := NewBus;
  LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
  try
    LEdit := InitialEdit;
    LEdit.SpanCount := 4;
    LEdit.RequireObservedEnd := False;
    SetLength(LEdit.Masks[dpDuration], 4);
    for LIndex := 0 to 3 do SetLength(LEdit.MusicMasks[LIndex], 4);
    Check(LStream.TryEdit(LEdit) = derAccepted, 'Explicit finite prefix without observed end');
    LEdit.Revision := LStream.Revision;
    LEdit.FromSpan := 2;
    LEdit.RequireObservedEnd := True;
    LEdit.Regenerate := [];
    LEdit.RegenerateMusic := False;
    Reject(LStream, LEdit, derConflict); { Retention cannot forge an observed end. }
  finally LStream.Free; LBus.Free; end;

  LOptions := DefaultDurationStreamOptions;
  LOptions.WorkLimit := 4 * (SynthFrameCost(DefaultSynthVoice, CRate) + 16);
  LBus := NewBus;
  LStream := AFixture.NewStream(LBus, LOptions);
  try
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Work bound initial');
    LEdit := FutureEdit(LStream, 0);
    LEdit.RegenerateMusic := True;
    LEdit.MusicMasks[1][1].AllowedTokens := [Rhythm(wmcaAttack)];
    LEdit.MusicMasks[2][1].AllowedTokens := [Voice(wmcaAttack, 48)];
    LEdit.MusicMasks[3][1].AllowedTokens := [Voice(wmcaAttack, 60)];
    Reject(LStream, LEdit, derWorkLimit);
  finally LStream.Free; LBus.Free; end;

  LOptions := DefaultDurationStreamOptions;
  LOptions.VoiceLimit := 4;
  LBus := NewBus;
  LStream := AFixture.NewStream(LBus, LOptions);
  try
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Capacity initial');
    LEdit := FutureEdit(LStream, 0);
    LEdit.RegenerateMusic := True;
    LEdit.MusicMasks[1][1].AllowedTokens := [Rhythm(wmcaAttack)];
    LEdit.MusicMasks[2][1].AllowedTokens := [Voice(wmcaAttack, 48)];
    LEdit.MusicMasks[3][1].AllowedTokens := [Voice(wmcaAttack, 60)];
    Reject(LStream, LEdit, derVoiceLimit);
  finally LStream.Free; LBus.Free; end;

  LOptions := DefaultDurationStreamOptions;
  LOptions.MaxPlanFrames := 9000;
  LBus := NewBus;
  LStream := AFixture.NewStream(LBus, LOptions);
  try
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Frame bound initial');
    LEdit := FutureEdit(LStream, 2);
    LEdit.Regenerate := [dpDuration];
    LEdit.Masks[dpDuration][3].AllowedTokens := [Duration(pskPitch, 62, 480)];
    Reject(LStream, LEdit, derFrameLimit);
  finally LStream.Free; LBus.Free; end;
end;

procedure TFailEffect.Reset;
begin end;
procedure TFailEffect.Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double);
begin
  raise EAudio.Create('Fixture processing failure');
end;
function TFailEffect.FrameCost: Integer;
begin Result := 1; end;

procedure CheckModelOwnership;
var LFixture: TFixture; LBus: TBusGraph; LStream: TDurationStream;
  LProvider: TDurationProvider; LIndex: Integer; LIdentity: String;
begin
  LFixture := TFixture.Create;
  LBus := NewBus;
  LStream := LFixture.NewStream(LBus, DefaultDurationStreamOptions);
  try
    LIdentity := LStream.ModelText(dpDuration);
    for LProvider := Low(TDurationProvider) to High(TDurationProvider) do
      FreeAndNil(LFixture.Models[LProvider]);
    FreeAndNil(LFixture.Config.HarmonyModel);
    FreeAndNil(LFixture.Config.RhythmModel);
    for LIndex := 0 to High(LFixture.Config.Voices) do
      FreeAndNil(LFixture.Config.Voices[LIndex].Model);
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Private models survive source owner disposal');
    Check(LStream.ModelText(dpDuration) = LIdentity, 'Exact model encoding identity retained');
  finally
    LStream.Free;
    LBus.Free;
    LFixture.Free;
  end;
end;

procedure CheckTerminal(const AFixture: TFixture);
var LBus: TBusGraph; LStream: TDurationStream; LL, LR: Double; LRaised: Boolean;
begin
  LBus := TBusGraph.Create(CRate, [DefaultBusSettings]);
  LBus.AddEffect(0, TFailEffect.Create(CRate));
  LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
  try
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Terminal initial');
    LL := 17; LR := 19; LRaised := False;
    try LStream.Process(LL, LR); except on E: EAudio do LRaised := True; end;
    Check(LRaised and LStream.Failed and (LL = 17) and (LR = 19) and
      (LStream.NextFrame = 0), 'Terminal processing preserves caller outputs and poisons epoch');
    RejectException(LStream, FutureEdit(LStream, 0));
  finally LStream.Free; LBus.Free; end;
  LBus := NewBus;
  LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
  try
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Explicit fresh epoch recovery');
    LStream.Process(LL, LR);
    Check(not LStream.Failed and (LStream.NextFrame = 1), 'Fresh recovery advances');
  finally LStream.Free; LBus.Free; end;
end;

function ModelEvidence(const AFixture: TFixture): String;
var
  LProvider: TDurationProvider;
  LIndex: Integer;
begin
  Result := '';
  for LProvider := Low(TDurationProvider) to High(TDurationProvider) do
    Result := Result + EncodeWfcSequenceText(AFixture.Models[LProvider]);
  for LIndex := 0 to WfcMusicVoicesModelCount(AFixture.Config) - 1 do
    Result := Result + EncodeWfcSequenceText(WfcMusicVoicesModelAt(AFixture.Config, LIndex));
end;

procedure TEditObserver.Attach(const AStream: TDurationStream;
  const AEdit: TDurationEdit; const ACapture: Boolean);
begin
  Stream := AStream;
  Edit := AEdit;
  ExpectedRevision := Stream.Revision;
  ExpectedFrame := Stream.NextFrame;
  Capture := ACapture;
  Events := nil;
  Calls := 0;
  AbortAt := 0;
  Reentry := 0;
  Marker := nil;
end;

procedure TEditObserver.Observe(const AWork: TWorkProgress);
var
  LIndex: Integer;
begin
  Inc(Calls);
  Check((Stream.Revision = ExpectedRevision) and
    (Stream.NextFrame = ExpectedFrame) and not Stream.Failed,
    'Duration callback observes unchanged accepted revision/clock/health');
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Honest nested work counts');

  if Capture then
  begin
    LIndex := Length(Events);
    Check(LIndex < 4096, 'Duration fixture event budget exceeded; reassess');
    SetLength(Events, LIndex + 1);
    Events[LIndex] := AWork;
  end;

  if Reentry = 1 then
  begin
    Stream.TryEdit(Edit);
  end;

  if Reentry = 2 then
  begin
    ProbeLeft := 17;
    ProbeRight := 19;
    Stream.Process(ProbeLeft, ProbeRight);
  end;

  if Calls = AbortAt then
  begin
    Marker := Exception.Create('Original duration edit callback abort');
    raise Marker;
  end;
end;

function NewLongEditFixture: TFixture;
var
  LContext, LTempo, LDuration, LToken: String;
  I: Integer;
begin
  Result := TFixture.Create;
  try
    Result.LongMode := True;
    LContext := KeyContextToken(MakeKeyContext(0, dmMajor));
    LTempo := TempoContextToken(500000);
    LDuration := Duration(pskPitch, 60, 4);
    Result.Models[dpKey].Free;
    Result.Models[dpKey] := nil;
    Result.Models[dpKey] := Learn([[LContext, LContext]], 1);
    Result.Models[dpTempo].Free;
    Result.Models[dpTempo] := nil;
    Result.Models[dpTempo] := Learn([[LTempo, LTempo]], 1);
    Result.Models[dpDuration].Free;
    Result.Models[dpDuration] := nil;
    Result.Models[dpDuration] := Learn([[LDuration, LDuration]], 1);
    Result.Config.HarmonyModel.Free;
    Result.Config.HarmonyModel := nil;
    LToken := Harmony(0);
    Result.Config.HarmonyModel := Learn([[LToken, LToken]], 1);
    Result.Config.RhythmModel.Free;
    Result.Config.RhythmModel := nil;
    LToken := Rhythm(wmcaAttack);
    Result.Config.RhythmModel := Learn([[LToken, LToken]], 1);

    for I := 0 to 1 do
    begin
      Result.Config.Voices[I].Model.Free;
      Result.Config.Voices[I].Model := nil;
      LToken := Voice(wmcaAttack, 48 + I * 12);
      Result.Config.Voices[I].Model := Learn([[LToken, LToken]], 1);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function LongEdit(const AStream: TDurationStream; const AScenario: Integer): TDurationEdit;
var
  I: Integer;
begin
  Result := Default(TDurationEdit);
  Result.Revision := AStream.Revision;
  { Big Boss: 40 attacks retain real interior sort visits without duplicating
    the companion's exhaustive capture/proof qualification. }
  Result.SpanCount := 20;
  Result.Seed := 731;
  Result.RequireObservedEnd := True;
  SetLength(Result.MusicMasks, 4);
  SetLength(Result.Masks[dpDuration], 260);

  for I := 0 to High(Result.Masks[dpDuration]) do
  begin
    Result.Masks[dpDuration][I] := MakeWfcSequenceTokenConstraint(0,
      [Duration(pskPitch, 60, 4)]);
  end;

  if AScenario = 0 then
  begin
    Result.Regenerate := [dpKey, dpTempo, dpDuration];
    Result.RegenerateMusic := True;
  end
  else
  begin
    Result.FromSpan := 10;

    if AScenario = 1 then
    begin
      Result.Regenerate := [dpDuration];
      Result.RegenerateMusic := True;
    end;
  end;
end;

function ExerciseObservedEdit(const AFixture: TFixture;
  const AScenario, APoint, AReentry: Integer; const ARetry, ACapture: Boolean;
  out AEvents: TEditEvents): Integer;
var
  LBus, LControlBus: TBusGraph;
  LStream, LControl: TDurationStream;
  LObserver: TEditObserver;
  LEdit, LInitial: TDurationEdit;
  LBefore, LModels: String;
  LLeft, LRight, LExpectedLeft, LExpectedRight: Double;
  LRejected: Boolean;
  LCalls, I: Integer;
begin
  AEvents := nil;
  LBus := NewBus;
  LControlBus := nil;
  LStream := nil;
  LControl := nil;
  LObserver := nil;
  try
    LControlBus := NewBus;
    LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
    LControl := AFixture.NewStream(LControlBus, DefaultDurationStreamOptions);
    LModels := ModelEvidence(AFixture);

    if AScenario > 0 then
    begin
      LInitial := LongEdit(LStream, 0);
      Check(LStream.TryEdit(LInitial) = derAccepted, 'Long initial plan');
      Check(LControl.TryEdit(LInitial) = derAccepted, 'Long initial reference');

      for I := 1 to 128 do
      begin
        LStream.Process(LLeft, LRight);
        LControl.Process(LExpectedLeft, LExpectedRight);
        Check((LLeft = LExpectedLeft) and (LRight = LExpectedRight),
          'Original committed prefix agrees before edit');
      end;
    end;
    LEdit := LongEdit(LStream, AScenario);
    LBefore := Snapshot(LStream);
    LObserver := TEditObserver.Create;
    LObserver.Attach(LStream, LEdit, ACapture);
    LObserver.AbortAt := APoint;
    LObserver.Reentry := AReentry;
    LRejected := False;
    try
      Check(LStream.TryEdit(LEdit, LObserver.Observe) = derAccepted,
        'Observed duration edit accepted');
    except
      on E: Exception do
      begin
        if (APoint = 0) and (AReentry = 0) then raise;
        LRejected := True;

        if AReentry > 0 then
        begin
          Check(E is EAudio, 'Duration reentry rejects through original guard');

          if AReentry = 2 then
          begin
            Check((LObserver.ProbeLeft = 17) and (LObserver.ProbeRight = 19),
              'Rejected process reentry preserves output arguments');
          end;
        end
        else
        begin
          Check(E = LObserver.Marker, 'Duration preserves original callback exception');
        end;
      end;
    end;
    Result := LObserver.Calls;
    AEvents := LObserver.Events;
    Check(LRejected = ((APoint > 0) or (AReentry > 0)), 'Duration cancellation disposition');

    if LRejected then
    begin
      Check((Snapshot(LStream) = LBefore) and not LStream.Failed,
        'Aborted duration edit preserves complete accepted state');
    end;
    Check(ModelEvidence(AFixture) = LModels, 'Duration observer preserves borrowed models');
    Check((LEdit.SpanCount = 20) and (LEdit.Seed = 731) and
      (Length(LEdit.MusicMasks) = 4) and (Length(LEdit.Masks[dpDuration]) = 260),
      'Duration observer preserves borrowed edit shape');

    for I := 0 to High(LEdit.Masks[dpDuration]) do
    begin
      Check((LEdit.Masks[dpDuration][I].Position = 0) and
        (Length(LEdit.Masks[dpDuration][I].AllowedTokens) = 1) and
        (LEdit.Masks[dpDuration][I].AllowedTokens[0] = Duration(pskPitch, 60, 4)),
        'Duration observer preserves original mask rows/tokens');
    end;

    if not LRejected or ARetry then
    begin
      if ARetry then
      begin
        LObserver.Attach(LStream, LEdit, False);
        Check(LStream.TryEdit(LEdit, LObserver.Observe) = derAccepted,
          'Same-instance duration retry');
      end;
      Check(LControl.TryEdit(LEdit) = derAccepted, 'Original nil-observer duration reference');
      Check(Snapshot(LStream) = Snapshot(LControl), 'Exact observed/nil accepted plan');
    end;
    LCalls := LObserver.Calls;

    for I := 1 to 4096 do
    begin
      LStream.Process(LLeft, LRight);
      LControl.Process(LExpectedLeft, LExpectedRight);
      Check((LLeft = LExpectedLeft) and (LRight = LExpectedRight),
        'Cancelled/retried duration preserves complete future stereo and bus history');
    end;
    Check(LObserver.Calls = LCalls, 'Duration stream retains no edit observer');
  finally
    LObserver.Free;
    LStream.Free;
    LControl.Free;
    LBus.Free;
    LControlBus.Free;
  end;
end;

procedure CheckEditProgress;
type
  { Big Boss: one bounded set of actual event positions for each stage/pass.
    These indices select probes without implementing another progress policy. }
  TPoint = record
    Key: String;
    First, Interior, Last: Integer;
  end;
var
  LFixture: TFixture;
  LEvents, LIgnored: TEditEvents;
  LPoints: array of TPoint;
  LSelected: array of Integer;
  LKey: String;
  LScenario, I, J, N, LSelectedTotal, LAborts: Integer;
  LSawMasks, LSawNotes, LSawReady, LSawSolve, LSawBuild, LSawProof: Boolean;

  procedure SelectPoint(const AIndex: Integer);
  var
    LIndex: Integer;
  begin
    if AIndex = 0 then Exit;

    for LIndex := 0 to High(LSelected) do
    begin
      if LSelected[LIndex] = AIndex then Exit;
    end;
    Inc(LSelectedTotal);
    Check(LSelectedTotal <= 512, 'Duration cancellation budget exceeded; reassess');
    LIndex := Length(LSelected);
    SetLength(LSelected, LIndex + 1);
    LSelected[LIndex] := AIndex;
  end;

begin
  LFixture := NewLongEditFixture;
  LSelectedTotal := 0;
  LAborts := 0;
  try
    for LScenario := 0 to 2 do
    begin
      ExerciseObservedEdit(LFixture, LScenario, 0, 0, False, True, LEvents);
      LPoints := nil;
      LSelected := nil;
      LSawMasks := False;
      LSawNotes := False;
      LSawReady := False;
      LSawSolve := False;
      LSawBuild := False;
      LSawProof := False;

      for I := 0 to High(LEvents) do
      begin
        LKey := LEvents[I].Stage + ':' + IntToStr(LEvents[I].Pass);
        J := 0;

        while (J < Length(LPoints)) and (LPoints[J].Key <> LKey) do Inc(J);

        if J = Length(LPoints) then
        begin
          SetLength(LPoints, J + 1);
          LPoints[J].Key := LKey;
          LPoints[J].First := I + 1;
        end;
        LPoints[J].Last := I + 1;

        if (LPoints[J].Interior = 0) and (LEvents[I].Done > 0) and
          ((LEvents[I].Total = 0) or (LEvents[I].Done < LEvents[I].Total)) then
        begin
          LPoints[J].Interior := I + 1;
        end;
        LSawMasks := LSawMasks or ((LEvents[I].Stage = 'duration_mask_visits') and
          (LEvents[I].Done >= 256) and (LEvents[I].Total = 0));
        LSawNotes := LSawNotes or ((LEvents[I].Stage = 'duration_note_visits') and
          (LEvents[I].Done >= 256) and (LEvents[I].Total = 0));
        LSawReady := LSawReady or (LEvents[I].Stage = 'schedule_replace_ready');
        LSawSolve := LSawSolve or (Pos('wfc_solve_', LEvents[I].Stage) = 1);
        LSawBuild := LSawBuild or (LEvents[I].Stage = 'wfc_voice_build_visits');
        LSawProof := LSawProof or (LEvents[I].Stage = 'wfc_voice_validate_visits');
      end;
      Check(LSawMasks and LSawNotes and LSawReady, 'Actual bulk mask/note and scheduler forwarding');

      if LScenario <> 2 then
      begin
        Check(LSawSolve and LSawBuild and LSawProof, 'Actual generic build/solve/proof forwarding');
      end;

      for J := 0 to High(LPoints) do
      begin
        SelectPoint(LPoints[J].First);
        SelectPoint(LPoints[J].Interior);
        SelectPoint(LPoints[J].Last);
      end;
      WriteLn('Duration scenario ', LScenario, ': ', Length(LEvents),
        ' callbacks / ', Length(LPoints), ' stage-pass keys / ', Length(LSelected), ' abort points');

      for J := 0 to High(LSelected) do
      begin
        N := LSelected[J];
        ExerciseObservedEdit(LFixture, LScenario, N, 0, False, False, LIgnored);
        ExerciseObservedEdit(LFixture, LScenario, N, 0, True, False, LIgnored);
        Inc(LAborts, 2);
      end;

      for J := 1 to 2 do
      begin
        ExerciseObservedEdit(LFixture, LScenario, 0, J, False, False, LIgnored);
        ExerciseObservedEdit(LFixture, LScenario, 0, J, True, False, LIgnored);
        Inc(LAborts, 2);
      end;
    end;
    WriteLn('Duration edit progress: ', LSelectedTotal,
      ' selected phase/pass points; ', LAborts, ' abort/reentry and retry/audio cases passed');
  finally
    LFixture.Free;
  end;
end;

procedure CheckCloneCancellation(const AFixture: TFixture);
var
  LBus: TBusGraph;
  LStream: TDurationStream;
  LObserver: TCloneObserver;
  LOriginal: String;
  LExpected: String;
  LCopy: Integer;
  LPoint: Integer;
begin
  LOriginal := ModelEvidence(AFixture);
  LBus := NewBus;
  LStream := nil;
  LObserver := TCloneObserver.Create;
  try
    LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions, LObserver.Observe);
    Check(LObserver.Index = 7, 'Duration must observe all three context and four musical copies');
    Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Observed stream accepts initial plan');
    LExpected := Snapshot(LStream);
    FreeAndNil(LStream);
    for LCopy := 1 to 7 do
      for LPoint := 0 to 1 do
      begin
        LObserver.Target := LCopy;
        LObserver.Index := 0;
        LObserver.FinalPoint := LPoint = 1;
        LObserver.Raised := False;
        LObserver.Marker := Exception.Create('Original duration clone abort');
        try
          LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions, LObserver.Observe);
        except
          on E: Exception do Check(E = LObserver.Marker, 'Duration replaced clone exception');
        end;
        Check(LObserver.Raised and (LStream = nil), 'Cancelled duration constructor published a stream');
        LObserver.Marker := nil;
        Check(ModelEvidence(AFixture) = LOriginal, 'Duration cancellation changed borrowed models');
        LObserver.Target := 0;
        LObserver.Index := 0;
        LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions, LObserver.Observe);
        Check(LObserver.Index = 7, 'Duration retry omitted model observation');
        Check(LStream.TryEdit(InitialEdit) = derAccepted, 'Same-bus duration retry failed');
        Check(Snapshot(LStream) = LExpected, 'Duration retry changed exact accepted plan');
        FreeAndNil(LStream);
      end;
    WriteLn('Duration model copies: 14 original start/final aborts and same-bus retries pass');
  finally
    LStream.Free;
    LObserver.Free;
    LBus.Free;
  end;
end;

{$IFDEF DURATION_PCM_REPLAY}
{ The exact same authored plan/future edit emits every Double channel value.
  Scoring uses the separately declared1e-9 absolute sample tolerance and exact
  snapshot/count identity; this export never changes the synthesis algorithm. }
procedure EmitPcmReplay(const AFixture: TFixture);
var
  LBus: TBusGraph;
  LStream: TDurationStream;
  LEdit: TDurationEdit;
  LLeft: Double;
  LRight: Double;
  LIndex: Integer;
begin
  LBus := NewBus;
  LStream := nil;
  try
    LStream := AFixture.NewStream(LBus, DefaultDurationStreamOptions);
    LEdit := InitialEdit;
    Check(LStream.TryEdit(LEdit) = derAccepted, 'Shared PCM initial edit');
    WriteLn('S:initial:', Snapshot(LStream));
    for LIndex := 0 to 69999 do
    begin
      if LIndex = 4096 then
      begin
        LEdit := FutureEdit(LStream, 3);
        LEdit.Regenerate := [dpDuration];
        LEdit.RegenerateMusic := True;
        Check(LStream.TryEdit(LEdit) = derAccepted, 'Shared PCM future edit');
        WriteLn('S:future:', Snapshot(LStream));
      end;
      LStream.Process(LLeft, LRight);
      WriteLn('P:', LIndex, ':', LLeft:0:15, ':', LRight:0:15);
    end;
    WriteLn('C:', LStream.NextFrame);
  finally
    LStream.Free;
    LBus.Free;
  end;
end;
{$ENDIF}

var LFixture: TFixture;
begin
  LFixture := TFixture.Create;
  try
    {$IFDEF DURATION_PCM_REPLAY}
    EmitPcmReplay(LFixture);
    {$ENDIF}
    CheckRollbackAndEdits(LFixture);
    CheckBoundaries(LFixture);
    CheckTerminal(LFixture);
    CheckModelOwnership;
    CheckCloneCancellation(LFixture);
    CheckEditProgress;
    WriteLn('duration stream: staged timing, continuation, future edits, immutable audio and rollback passed');
  finally LFixture.Free; end;
end.
