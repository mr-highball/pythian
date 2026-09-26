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
program pythian_layers_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.synth,
  pythian.music,
  pythian.music.render,
  pythian.time,
  pythian.wfc.layers,
  pythian.tools.files,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_sequence_graph,
  wfc_sequence_text;

procedure Run(const AOutput: String; const ASeed: TGraphSeed;
  const APreferredLayer, APreferredToken: String; const AMultiplier: Integer);
const
  CLayerNames: array[0..3] of String = ('pairs', 'bass', 'melody', 'intervals');
  CHarmony: array[0..15] of Integer =
    (48, 48, 48, 48, 45, 45, 45, 45, 53, 53, 55, 55, 48, 55, 48, 48);
  CMelody: array[0..1, 0..15] of Integer =
    ((64, 67, 72, 67, 64, 69, 72, 69, 65, 69, 67, 71, 72, 71, 64, 60),
     (67, 64, 60, 64, 69, 64, 60, 64, 69, 65, 71, 67, 64, 67, 72, 60));
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LSamples: array[0..3] of TWfcSequenceSamples;
  LTokens: array[0..3] of TWfcModelTokens;
  LGenerated: TLayerSequences;
  LOptions: TLayerGenerationOptions;
  LReport: TGraphNegotiationReport;
  LTones: TFrameTones;
  LNotes: TNoteGates;
  LVoices: TNoteVoices;
  LTempos: TTempoChanges;
  LSequence: TNoteSequence;
  LRenderReport: TNoteRenderReport;
  LClip: TAudioClip;
  LDocument: TJSONObject;
  LEvents: TJSONArray;
  LEvent: TJSONObject;
  LModels: TJSONArray;
  LRows: TJSONArray;
  LModel: TJSONObject;
  LPreference: TLayerTokenPreference;
  LPreferenceRow: TJSONObject;
  LPreferredIndex: Integer;
  LAllowed: TWfcModelTokens;
  LToken: String;
  LPair: String;
  LSeparator: Integer;
  LSample: Integer;
  LLane: Integer;
  LIndex: Integer;
  LOther: Integer;
  LPitch: Integer;
  LInterval: Integer;
  LBytes: TAudioBytes;
begin
  SetLength(LLayers, 4);
  LClip := nil;
  LSequence := nil;
  LDocument := nil;
  try
    for LLane := 0 to 3 do
    begin
      SetLength(LSamples[LLane], 2);
      SetLength(LTokens[LLane], 16);
    end;
    for LSample := 0 to 1 do
    begin
      for LIndex := 0 to 15 do
      begin
        LTokens[0][LIndex] := IntToStr(CHarmony[LIndex]);
        LTokens[1][LIndex] := IntToStr(CMelody[LSample, LIndex]);
        LTokens[2][LIndex] := LTokens[0][LIndex] + ':' + LTokens[1][LIndex];
        LTokens[3][LIndex] := IntToStr(CMelody[LSample, LIndex] - CHarmony[LIndex]);
      end;
      for LLane := 0 to 3 do
      begin
        LSamples[LLane][LSample] := MakeWfcSequenceSample(LTokens[LLane]);
      end;
    end;
    LLayers[0].Model := LearnSequenceModelCorpus(LSamples[2], 2);
    LLayers[1].Model := LearnSequenceModelCorpus(LSamples[0], 2);
    LLayers[2].Model := LearnSequenceModelCorpus(LSamples[1], 2);
    LLayers[3].Model := LearnSequenceModelCorpus(LSamples[3], 2);
    if APreferredLayer <> '' then
    begin
      LPreferredIndex := -1;
      for LLane := 0 to 3 do
      begin
        if CLayerNames[LLane] = APreferredLayer then
        begin
          LPreferredIndex := LLane;
        end;
      end;
      if LPreferredIndex < 0 then
      begin
        raise EAudio.Create('Preference layer must be pairs, bass, melody or intervals');
      end;
      LLayers[LPreferredIndex].Preferences :=
        [MakeLayerTokenPreference(APreferredToken, AMultiplier)];
    end;
    SetLength(LMaps, 3);
    for LLane := 0 to 1 do
    begin
      LMaps[LLane].Consumer := LLane + 1;
      LMaps[LLane].Provider := 0;
      SetLength(LMaps[LLane].Rules, LLayers[LLane + 1].Model.PublicTokenCount);
      for LIndex := 0 to LLayers[LLane + 1].Model.PublicTokenCount - 1 do
      begin
        LToken := LLayers[LLane + 1].Model.PublicTokenAt(LIndex);
        LAllowed := nil;
        for LOther := 0 to LLayers[0].Model.PublicTokenCount - 1 do
        begin
          LPair := LLayers[0].Model.PublicTokenAt(LOther);
          LSeparator := Pos(':', LPair);
          if ((LLane = 0) and (Copy(LPair, 1, LSeparator - 1) = LToken)) or
            ((LLane = 1) and (Copy(LPair, LSeparator + 1, MaxInt) = LToken)) then
          begin
            SetLength(LAllowed, Length(LAllowed) + 1);
            LAllowed[High(LAllowed)] := LPair;
          end;
        end;
        LMaps[LLane].Rules[LIndex] := MakeWfcSequenceProjectionRule(LToken, LAllowed);
      end;
    end;
    LMaps[2].Consumer := 3;
    LMaps[2].Provider := 0;
    SetLength(LMaps[2].Rules, LLayers[3].Model.PublicTokenCount);
    for LIndex := 0 to LLayers[3].Model.PublicTokenCount - 1 do
    begin
      LToken := LLayers[3].Model.PublicTokenAt(LIndex);
      LInterval := StrToInt(LToken);
      LAllowed := nil;
      for LOther := 0 to LLayers[0].Model.PublicTokenCount - 1 do
      begin
        LPair := LLayers[0].Model.PublicTokenAt(LOther);
        LSeparator := Pos(':', LPair);
        if StrToInt(Copy(LPair, LSeparator + 1, MaxInt)) -
          StrToInt(Copy(LPair, 1, LSeparator - 1)) = LInterval then
        begin
          SetLength(LAllowed, Length(LAllowed) + 1);
          LAllowed[High(LAllowed)] := LPair;
        end;
      end;
      LMaps[2].Rules[LIndex] := MakeWfcSequenceProjectionRule(LToken, LAllowed);
    end;
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := 32;
    LOptions.Seed := ASeed;
    LOptions.Extent := wseWhole;
    LOptions.MaxPassBacktracks := 256;
    if not TryGenerateLayers(LLayers, LMaps, LOptions, LGenerated, LReport) then
    begin
      raise EAudio.CreateFmt('Layer generation rejected with status %d', [Ord(LReport.Status)]);
    end;
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.layers.demo.v1');
    LDocument.Add('training', 'Two authored 16-beat bass/melody motifs in this demo source');
    LDocument.Add('method', 'Order-2 observed pairs provide bass, melody and interval sequences');
    LDocument.Add('seed', Int64(ASeed));
    LDocument.Add('bpm', 120);
    LDocument.Add('cells', LOptions.CellCount);
    LDocument.Add('extent', 'whole');
    LDocument.Add('layers_version', LearnedLayersVersion);
    LDocument.Add('negotiation_version', LReport.NegotiationAlgorithmVersion);
    LDocument.Add('pass_backtracks', LReport.PassBacktracks);
    LDocument.Add('max_pass_backtracks', LOptions.MaxPassBacktracks);
    LDocument.Add('max_backtracks', LOptions.MaxBacktracks);
    LModels := TJSONArray.Create;
    LDocument.Add('models', LModels);
    for LLane := 0 to 3 do
    begin
      LModel := TJSONObject.Create;
      LModels.Add(LModel);
      LModel.Add('name', CLayerNames[LLane]);
      LToken := EncodeWfcSequenceText(LLayers[LLane].Model);
      LModel.Add('text', LToken);
      LModel.Add('sha256', HashText(LToken));
      LRows := TJSONArray.Create;
      LModel.Add('preferences', LRows);
      for LPreference in LLayers[LLane].Preferences do
      begin
        LPreferenceRow := TJSONObject.Create;
        LRows.Add(LPreferenceRow);
        LPreferenceRow.Add('token', LPreference.Token);
        LPreferenceRow.Add('multiplier', LPreference.Multiplier);
      end;
      LRows := TJSONArray.Create;
      LModel.Add('latent_states', LRows);
      for LIndex := 0 to High(LGenerated[LLane].StateIndices) do
      begin
        LRows.Add(LGenerated[LLane].StateIndices[LIndex]);
      end;
    end;
    LEvents := TJSONArray.Create;
    LDocument.Add('events', LEvents);
    SetLength(LNotes, LOptions.CellCount * 2);
    for LIndex := 0 to LOptions.CellCount - 1 do
    begin
      for LLane := 0 to 1 do
      begin
        LOther := LIndex * 2 + LLane;
        LPitch := StrToInt(LGenerated[LLane + 1].Tokens[LIndex]);
        LNotes[LOther].StartTick := LIndex * 480;
        LNotes[LOther].EndTick := LNotes[LOther].StartTick + 384;
        LNotes[LOther].Pitch := LPitch;
        LNotes[LOther].Velocity := 127;
        LNotes[LOther].Voice := LLane;
        LNotes[LOther].Track := LLane;
        LNotes[LOther].Channel := -1;
      end;
    end;
    SetLength(LTempos, 1);
    LTempos[0] := MakeTempoChange(0, 500000);
    LSequence := TNoteSequence.Create(480, LOptions.CellCount * 480, LTempos, LNotes);
    SetLength(LVoices, 2);
    for LLane := 0 to 1 do
    begin
      LVoices[LLane] := DefaultSynthVoice;
      LVoices[LLane].Pan := -0.35 + LLane * 0.7;
      LVoices[LLane].Gain := 0.24;
    end;
    LTones := PlanNoteTones(LSequence, 44100, LVoices, LRenderReport);
    for LIndex := 0 to LOptions.CellCount - 1 do
    begin
      for LLane := 0 to 1 do
      begin
        LOther := LIndex * 2 + LLane;
        { Preserve the example's continuous performance amplitude after gate planning. }
        LTones[LOther].Velocity := 0.65;
        LEvent := TJSONObject.Create;
        LEvents.Add(LEvent);
        LEvent.Add('cell', LIndex);
        LEvent.Add('lane', LLane);
        LEvent.Add('pitch', LNotes[LOther].Pitch);
        LEvent.Add('start_frame', LTones[LOther].StartFrame);
        LEvent.Add('gate_frames', LTones[LOther].GateFrames);
        LEvent.Add('pair', LGenerated[0].Tokens[LIndex]);
        LEvent.Add('interval', LGenerated[3].Tokens[LIndex]);
      end;
    end;
    LClip := RenderFrameTones(LTones, 44100, Int64(LOptions.CellCount) * 22050);
    LBytes := EncodeWavePcm16(LClip);
    LDocument.Add('output_sha256', HashAudioBytes(LBytes));
    LDocument.Add('frames', LClip.FrameCount);
    WriteFileBytes(AOutput, LBytes);
    WriteTextFile(AOutput + '.json', LDocument.FormatJSON);
    WriteLn('Rendered ', Length(LTones), ' notes from four negotiated layers; ',
      LReport.PassBacktracks, ' provider retries; ', LClip.FrameCount, ' stereo frames');
  finally
    LSequence.Free;
    LDocument.Free;
    LClip.Free;
    for LLane := 0 to High(LLayers) do
    begin
      LLayers[LLane].Model.Free;
    end;
  end;
end;

var
  LSeed: QWord;
  LPreferredLayer: String;
  LPreferredToken: String;
  LMultiplier: Integer;
begin
  try
    if not (ParamCount in [1, 2, 5]) then
    begin
      WriteLn('Usage: pythian.layers.demo OUTPUT.wav [SEED [LAYER TOKEN MULTIPLIER]]');
      Halt(2);
    end;
    LSeed := 731;
    if ParamCount >= 2 then
    begin
      if not TryStrToQWord(ParamStr(2), LSeed) or (LSeed > High(TGraphSeed)) then
      begin
        raise EAudio.Create('Seed must fit the WFC seed type');
      end;
    end;
    LPreferredLayer := '';
    LPreferredToken := '';
    LMultiplier := 1;
    if ParamCount = 5 then
    begin
      LPreferredLayer := ParamStr(3);
      LPreferredToken := ParamStr(4);
      if not TryStrToInt(ParamStr(5), LMultiplier) then
      begin
        raise EAudio.Create('Preference multiplier must be an integer in 1..1024');
      end;
    end;
    Run(ParamStr(1), LSeed, LPreferredLayer, LPreferredToken, LMultiplier);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
