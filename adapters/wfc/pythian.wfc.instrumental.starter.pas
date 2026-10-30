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
unit pythian.wfc.instrumental.starter;

{$mode delphi}
{$H+}

interface

uses
  pythian.instrument,
  pythian.wfc.instrumental,
  pythian.wfc.voices,
  pythian.percussion,
  pythian.wfc.percussion,
  wfc_sequence,
  wfc_music_voices_graph;

type
  { Big Boss: reusable authored material for the first experiment, not a learned
    recording style. Owns three source-free instruments and all training models.
    No genre name, media file, external runtime or second synthesis engine. }
  TInstrumentalStarter = class
  private
    FConfig: TWfcMusicVoicesGraphConfig;
    FRoles: TInstrumentalRoles;
    FTonic: Integer;
    FDrumModels: array[TPercussionKind] of TWfcSequenceModel;
  public
    constructor Create(const ATonic: Integer = 0);
    destructor Destroy; override;
    function CopyRoles: TInstrumentalRoles;
    { Authored harmony/rhythm guide only; pitched voice choices remain WFC.
      Arbitrary free graph solving is available through the runtime's nil masks. }
    function GuideMasks(const ACellCount: Integer): TVoiceMasks;
    function CopyPercussion(const ASampleRate: Integer): TPercussionDefinitions;
    { Models are borrowed immutable; the runtime clones them before solving. }
    function Config: TWfcMusicVoicesGraphConfig;
    property Tonic: Integer read FTonic;
  end;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.synth,
  pythian.oscillator,
  wfc_model,
  wfc_sequence_graph,
  wfc_sequence_learn,
  wfc_music,
  wfc_music_sequence,
  wfc_music_ensemble,
  wfc_music_ensemble_graph;

function StarterFrame(const APhrase, ACell, ATonic: Integer): TWfcMusicEnsembleFrame;
const
  CRoots: array[0..1, 0..7] of Integer =
    ((0, 5, 7, 0, 0, 9, 5, 7), (0, 9, 5, 7, 0, 5, 7, 0));
var
  LRoot: Integer;
  LThird: Integer;
  LChord: array[0..2] of Integer;
  LLead: Integer;
  LAction: TWfcMusicCellAction;
begin
  Result := Default(TWfcMusicEnsembleFrame);
  LRoot := CRoots[APhrase, ACell div 8] + ATonic;
  LThird := 4;
  if CRoots[APhrase, ACell div 8] = 9 then
  begin
    LThird := 3;
  end;
  LChord[0] := LRoot;
  LChord[1] := LRoot + LThird;
  LChord[2] := LRoot + 7;
  SetLength(Result.Voices, 3);
  LAction := wmcaHold;
  if ACell mod 4 = 0 then
  begin
    LAction := wmcaAttack;
  end;
  Result.Voices[0] := MakeWfcMusicVoiceCell(LAction,
    [MakeWfcMusicTone(36 + LRoot, 100)]);
  LAction := wmcaHold;
  if ACell mod 8 = 0 then
  begin
    LAction := wmcaAttack;
  end;
  Result.Voices[1] := MakeWfcMusicVoiceCell(LAction,
    [MakeWfcMusicTone(60 + LChord[0], 70),
     MakeWfcMusicTone(60 + LChord[1], 70),
     MakeWfcMusicTone(60 + LChord[2], 70)]);
  LLead := 72 + LChord[((ACell mod 8) div 2 + APhrase) mod 3];
  LAction := wmcaHold;
  if ACell mod 2 = 0 then
  begin
    LAction := wmcaAttack;
  end;
  Result.Voices[2] := MakeWfcMusicVoiceCell(LAction,
    [MakeWfcMusicTone(LLead, 84)]);
end;

constructor TInstrumentalStarter.Create(const ATonic: Integer);
const
  CNames: array[0..2] of String = ('bass', 'harmony-voice', 'lead');
  CShapes: array[0..2] of TWaveShape = (wsSaw, wsTriangle, wsSquare);
var
  LSamples: array[0..4] of TWfcSequenceSamples;
  LFrame: TWfcMusicEnsembleFrame;
  LSingle: TWfcMusicEnsembleFrame;
  LPass: Integer;
  LPhrase: Integer;
  LCell: Integer;
  LRole: Integer;
  LZone: TInstrumentZones;
  LModel: TWfcSequenceModel;
begin
  inherited Create;
  if (ATonic < 0) or (ATonic > 11) then
  begin
    raise EAudio.Create('Starter tonic requires pitch class 0..11');
  end;
  FTonic := ATonic;
  SetLength(FConfig.Voices, 3);
  SetLength(FRoles, 3);
  FConfig.StepsPerOctave := 12;
  FConfig.HarmonyMode := wmehmExact;
  for LPass := 0 to 4 do
  begin
    SetLength(LSamples[LPass], 2);
    for LPhrase := 0 to 1 do
    begin
      SetLength(LSamples[LPass][LPhrase].Tokens, 64);
    end;
  end;
  for LPhrase := 0 to 1 do
  begin
    for LCell := 0 to 63 do
    begin
      LFrame := StarterFrame(LPhrase, LCell, ATonic);
      LSamples[0][LPhrase].Tokens[LCell] :=
        EncodeWfcMusicPitchClassSet(ProjectWfcMusicEnsembleFrameToPitchClassSet(LFrame, 12));
      LSamples[1][LPhrase].Tokens[LCell] :=
        EncodeWfcMusicRhythmFrame(ProjectWfcMusicEnsembleFrameToRhythm(LFrame));
      SetLength(LSingle.Voices, 1);
      for LRole := 0 to 2 do
      begin
        LSingle.Voices[0] := LFrame.Voices[LRole];
        LSamples[LRole + 2][LPhrase].Tokens[LCell] := EncodeWfcMusicEnsembleFrame(LSingle);
      end;
    end;
  end;
  for LPass := 0 to 4 do
  begin
    LModel := LearnSequenceModelCorpus(LSamples[LPass], 2);
    case LPass of
      0: FConfig.HarmonyModel := LModel;
      1: FConfig.RhythmModel := LModel;
    else
      FConfig.Voices[LPass - 2].Model := LModel;
    end;
  end;
  for LRole := 0 to 2 do
  begin
    FConfig.Voices[LRole].MinPitch := 36 + LRole * 24;
    if LRole = 2 then
    begin
      FConfig.Voices[LRole].MinPitch := 72;
    end;
    FConfig.Voices[LRole].MaxPitch := FConfig.Voices[LRole].MinPitch + 35;
    FRoles[LRole].Name := CNames[LRole];
    FRoles[LRole].InstrumentId := 'authored-' + CNames[LRole] + '-v1';
    FRoles[LRole].OutputBus := LRole;
    SetLength(LZone, 1);
    LZone[0] := Default(TInstrumentZone);
    LZone[0].MinimumKey := 0;
    LZone[0].MaximumKey := 127;
    LZone[0].MinimumVelocity := 1;
    LZone[0].MaximumVelocity := 127;
    LZone[0].Voice := DefaultSynthVoice;
    LZone[0].Voice.Shape := CShapes[LRole];
    LZone[0].Voice.OscillatorQuality := oqPolynomial;
    LZone[0].Voice.Gain := 0.10;
    LZone[0].Voice.Pan := (LRole - 1) * 0.18;
    LZone[0].Voice.CutoffHz := 1800 + LRole * 500;
    LZone[0].Voice.Envelope.AttackSeconds := 0.008 + LRole * 0.008;
    LZone[0].Voice.Envelope.DecaySeconds := 0.12;
    LZone[0].Voice.Envelope.SustainLevel := 0.65;
    LZone[0].Voice.Envelope.ReleaseSeconds := 0.18 + LRole * 0.08;
    FRoles[LRole].Instrument := TInstrument.Create(LZone);
  end;
end;

destructor TInstrumentalStarter.Destroy;
var
  LRole: Integer;
  LKind: TPercussionKind;
begin
  for LKind := Low(TPercussionKind) to High(TPercussionKind) do
  begin
    FDrumModels[LKind].Free;
  end;
  for LRole := 0 to High(FRoles) do
  begin
    FRoles[LRole].Instrument.Free;
  end;
  for LRole := 0 to High(FConfig.Voices) do
  begin
    FConfig.Voices[LRole].Model.Free;
  end;
  FConfig.HarmonyModel.Free;
  FConfig.RhythmModel.Free;
  inherited Destroy;
end;

function TInstrumentalStarter.CopyRoles: TInstrumentalRoles;
begin
  Result := Copy(FRoles);
end;

function TInstrumentalStarter.Config: TWfcMusicVoicesGraphConfig;
begin
  Result := FConfig;
  Result.Voices := Copy(FConfig.Voices);
  Result.PairConstraints := Copy(FConfig.PairConstraints);
end;

function TInstrumentalStarter.GuideMasks(const ACellCount: Integer): TVoiceMasks;
var
  LCell: Integer;
  LFrame: TWfcMusicEnsembleFrame;
begin
  if (ACellCount < 1) or (ACellCount > 1024) then
  begin
    raise EAudio.Create('Authored starter guide requires 1..1024 cells');
  end;
  Result := nil;
  SetLength(Result, 5);
  SetLength(Result[0], ACellCount);
  SetLength(Result[1], ACellCount);
  for LCell := 0 to ACellCount - 1 do
  begin
    LFrame := StarterFrame((LCell div 64) mod 2, LCell mod 64, FTonic);
    Result[0][LCell] := MakeWfcSequenceTokenConstraint(LCell,
      [EncodeWfcMusicPitchClassSet(ProjectWfcMusicEnsembleFrameToPitchClassSet(LFrame, 12))]);
    Result[1][LCell] := MakeWfcSequenceTokenConstraint(LCell,
      [EncodeWfcMusicRhythmFrame(ProjectWfcMusicEnsembleFrameToRhythm(LFrame))]);
  end;
end;

function TInstrumentalStarter.CopyPercussion(const ASampleRate: Integer): TPercussionDefinitions;
const
  CNames: array[TPercussionKind] of String = ('kick', 'snare', 'hat');
var
  LKind: TPercussionKind;
  LIndex: Integer;
  LVelocity: Integer;
  LCount: Integer;
  LSamples: TWfcSequenceSamples;
  LRhythm: TWfcMusicRhythmFrame;
  LAllowed: Boolean;
begin
  Result := nil;
  SetLength(Result, 3);
  for LKind := Low(TPercussionKind) to High(TPercussionKind) do
  begin
    LIndex := Ord(LKind);
    Result[LIndex].Settings := DefaultPercussionSettings(LKind, ASampleRate);
    if FDrumModels[LKind] = nil then
    begin
      SetLength(LSamples, 2);
      SetLength(LSamples[0].Tokens, 64);
      SetLength(LSamples[1].Tokens, 64);
      for LCount := 0 to 63 do
      begin
        LVelocity := 0;
        case LKind of
          pkKick:
          begin
            if LCount mod 8 = 0 then
            begin
              LVelocity := 110;
            end
            else if LCount mod 8 = 4 then
            begin
              LVelocity := 96;
            end;
          end;
          pkSnare:
          begin
            if (LCount mod 8 = 2) or (LCount mod 8 = 6) then
            begin
              LVelocity := 110;
            end;
          end;
          pkClosedHat:
          begin
            LVelocity := 64;
            if LCount mod 2 = 0 then
            begin
              LVelocity := 80;
            end;
            if LCount mod 8 = 0 then
            begin
              LVelocity := 100;
            end;
            if LCount mod 16 >= 14 then
            begin
              LVelocity := 0;
            end;
          end;
        end;
        LSamples[0].Tokens[LCount] := PercussionToken(LVelocity);
        LSamples[1].Tokens[LCount] := PercussionToken(0);
      end;
      FDrumModels[LKind] := LearnSequenceModelCorpus(LSamples, 2);
    end;
    Result[LIndex].Name := CNames[LKind];
    Result[LIndex].Origin := 'Authored percussion pattern and explicit silence alternative';
    Result[LIndex].Model := FDrumModels[LKind];
    Result[LIndex].OutputBus := 3 + LIndex;
    Result[LIndex].Enabled := True;
    Result[LIndex].HitWeight := 64;
    for LCount := 0 to FConfig.RhythmModel.PublicTokenCount - 1 do
    begin
      LRhythm := DecodeWfcMusicRhythmFrame(FConfig.RhythmModel.PublicTokenAt(LCount));
      LAllowed := LKind = pkClosedHat;
      if LKind = pkKick then
      begin
        LAllowed := LRhythm.Actions[0] = wmcaAttack;
      end
      else if LKind = pkSnare then
      begin
        LAllowed := (LRhythm.Actions[2] = wmcaAttack) and
          (LRhythm.Actions[0] <> wmcaAttack);
      end;
      if LAllowed then
      begin
        LVelocity := Length(Result[LIndex].AllowedHitRhythms);
        SetLength(Result[LIndex].AllowedHitRhythms, LVelocity + 1);
        Result[LIndex].AllowedHitRhythms[LVelocity] := FConfig.RhythmModel.PublicTokenAt(LCount);
      end;
    end;
  end;
end;

end.
