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
program pythian_tests_musical_composition;
{$mode delphi}{$H+}
uses SysUtils, pythian.audio, pythian.progress,
  pythian.wfc.musical.context, pythian.wfc.providers,
  wfc, wfc_model, wfc_sequence, wfc_sequence_graph, wfc_sequence_learn,
  wfc_music, wfc_music_sequence, wfc_music_ensemble, wfc_music_ensemble_graph,
  wfc_music_voices_graph, wfc_music_voices_stream, wfc_music_arrangement;

type
  TProbe = class
    Stage: String;
    procedure Observe(const P: TWorkProgress);
  end;
var Checks: Integer;

procedure Check(const B: Boolean; const S: String);
begin
  Inc(Checks);
  if not B then raise EAudio.Create(S);
end;

procedure TProbe.Observe(const P: TWorkProgress);
begin
  if P.Stage = Stage then raise EAbort.Create('composition cancelled');
end;

function Model(const A, B: String): TWfcSequenceModel;
var Samples: TWfcSequenceSamples;
begin
  SetLength(Samples, 2);
  Samples[0] := MakeWfcSequenceSample([A, A, A, A]);
  Samples[1] := MakeWfcSequenceSample([B, B, B, B]);
  Result := LearnSequenceModelCorpus(Samples, 2);
end;

procedure Run;
var
  Base, Composed, Prior: TWfcMusicVoicesGraphConfig;
  Config: TWfcMusicVoicesStreamConfig;
  Context: TWfcSequenceModel;
  ContextCell: TMusicalContextCell;
  Frame: TWfcMusicEnsembleFrame;
  H, R: String;
  VoiceTokens, ContextTokens: array[0..1] of String;
  Stream: TWfcMusicVoicesStream;
  Segment: TWfcMusicVoicesSegment;
  Report: TGraphNegotiationReport;
  Proof: TWfcMusicVoicesValidationReport;
  Generated: TWfcMusicVoicesGenerated;
  Boundaries: TWfcMusicVoicesBoundaries;
  Graph: TGraph;
  Probe: TProbe;
  I, J, Mode, Role: Integer;
  Rejected: Boolean;
begin
  Base := Default(TWfcMusicVoicesGraphConfig);
  Context := nil;
  Probe := TProbe.Create;
  try
    SetLength(Frame.Voices, 1);
    for I := 0 to 1 do
    begin
      Frame.Voices[0] := MakeWfcMusicVoiceCell(wmcaAttack, [MakeWfcMusicTone(60 + 12 * I, 80)]);
      VoiceTokens[I] := EncodeWfcMusicEnsembleFrame(Frame);
    end;
    H := EncodeWfcMusicPitchClassSet(ProjectWfcMusicEnsembleFrameToPitchClassSet(Frame, 12));
    R := EncodeWfcMusicRhythmFrame(ProjectWfcMusicEnsembleFrameToRhythm(Frame));
    Base.HarmonyModel := Model(H, H);
    Base.RhythmModel := Model(R, R);
    SetLength(Base.Voices, 1);
    Base.Voices[0].Model := Model(VoiceTokens[0], VoiceTokens[1]);
    Base.Voices[0].MinPitch := 60;
    Base.Voices[0].MaxPitch := 72;
    Base.StepsPerOctave := 12;
    Base.HarmonyMode := wmehmExact;
    for Role := -1 to 0 do
    begin
      for I := 0 to 1 do
      begin
        ContextCell := Default(TMusicalContextCell);
        ContextCell.Frame := DecodeWfcMusicEnsembleFrame(VoiceTokens[I]);
        ContextCell.DrivenRole := Role;
        ContextTokens[I] := EncodeMusicalContextToken(ContextCell);
      end;
      Context := Model(ContextTokens[0], ContextTokens[1]);
      try
        for Mode := 0 to 1 do
        begin
          Composed := ComposeMusicalContextGraph(Base, Context, Mode = 1);
          Check((Length(Base.Auxiliary) = 0) and (Length(Base.Projections) = 0),
            'composition preserves caller configuration');
          Check((WfcMusicVoicesModelCount(Composed) = 4) and
            (Composed.Auxiliary[0].Name = MusicalContextPassName), 'actual primary context pass');
          if (Role < 0) and (Mode = 0) then
            Check(Length(Composed.Projections) = 2, 'free context binds H/R without pinning pitch')
          else Check(Length(Composed.Projections) = 3, 'explicit driven/all-role relation retained');
          Config := DefaultWfcMusicVoicesStreamConfig(Composed, 1, 8, 731);
          Config.SegmentCellCount := 2;
          Config.LookaheadCellCount := 4;
          Stream := TWfcMusicVoicesStream.Create(Config);
          try
            Stream.IntersectAllowedTokens(3, 0, [ContextTokens[0]]);
            Stream.IntersectAllowedTokens(2, 0, [VoiceTokens[1]]);
            if (Role < 0) and (Mode = 0) then
            begin
              for I := 0 to 3 do
              begin
                Check(Stream.Next(Segment, Report) = wmaspProduced, 'shared musical context prefix');
                try
                  Check(Segment.CopyGenerated(3).Tokens[0] = ContextTokens[0], 'source context remains inspectable');
                  Check(Segment.CopyGenerated(2).Tokens[0] = VoiceTokens[1], 'independent octave is genuinely free');
                  Check(Stream.CopyFrontier.EndTick = 2 * (I + 1), 'one shared musical clock');
                finally Segment.Free; end;
              end;
              Check(Stream.Next(Segment, Report) = wmaspCompleted, 'complete declared consumer');
            end
            else Check((Stream.Next(Segment, Report) = wmaspFailed) and (Segment = nil) and
              (Stream.ProducedTicks = 0), 'explicit voice binding rejects contradictory octave');
          finally Stream.Free; end;
          Boundaries := nil;
          SetLength(Boundaries, WfcMusicVoicesModelCount(Composed));
          for J := 0 to High(Boundaries) do Boundaries[J] := MakeWfcSequenceInitialSegmentBoundary(False);
          Graph := BuildWfcMusicVoicesSegmentGraph(Composed, 4, 731, Boundaries);
          try
            Check(Graph.TrySolveNegotiated(DefaultGraphNegotiationOptions, Report), 'finite musical composition solves');
            Check(CaptureSolvedWfcMusicVoices(Composed, Graph, Boundaries, Generated, Proof),
              'primary proof validates actual ctx2 source codec projection');
          finally Graph.Free; end;
        end;
        Prior := Composed;
        Probe.Stage := 'context_compose_projection';
        Rejected := False;
        try Composed := ComposeMusicalContextGraph(Base, Context, False, Probe.Observe);
        except on E: EAbort do Rejected := True; end;
        Check(Rejected and (Length(Composed.Projections) = Length(Prior.Projections)),
          'cancelled adaptation preserves prior caller result');
        Probe.Stage := 'context_project_tokens';
        Rejected := False;
        try Composed := ComposeMusicalContextGraph(Base, Context, False, Probe.Observe);
        except on E: EAbort do Rejected := True; end;
        Check(Rejected, 'context decoding forwards cancellation');
      finally FreeAndNil(Context); end;
    end;
  finally
    Probe.Free;
    Context.Free;
    Base.HarmonyModel.Free;
    Base.RhythmModel.Free;
    if Length(Base.Voices) > 0 then Base.Voices[0].Model.Free;
  end;
end;

begin
  Run;
  WriteLn('PASS musical composition: ', Checks, ' checks');
end.
