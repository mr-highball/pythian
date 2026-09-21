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

program pythian_tests_voices_context;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.music.context,
  pythian.tonal,
  pythian.wfc.context.archive,
  pythian.wfc.context.profile,
  pythian.tools.files,
  wfc_music_ensemble;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure Fixtures(const APrefix: String);
const
  CNames: array[0..3] of String = ('minor', 'unknown', 'changing', 'grid');
var
  LEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LProfile: TContextProfile;
  LVariant: Integer;
  LCell: Integer;
begin
  for LVariant := 0 to 3 do
  begin
    SetLength(LEvidence, 1);
    LEvidence[0] := Default(TContextEvidence);
    LEvidence[0].Name := 'Authored voice context fixture ' + CNames[LVariant];
    LEvidence[0].SourceSha256 := HashText(LEvidence[0].Name);
    LEvidence[0].AdmissionPolicy := 'Explicit native test declaration; no recorded key or tempo inference';
    LEvidence[0].Grid.TicksPerQuarter := 480;
    LEvidence[0].Grid.StepTicks := 240;
    if LVariant = 3 then
    begin
      LEvidence[0].Grid.StepTicks := 120;
    end;
    SetLength(LEvidence[0].Grid.Keys, 64);
    SetLength(LEvidence[0].Grid.Tempos, 64);
    for LCell := 0 to 63 do
    begin
      LEvidence[0].Grid.Keys[LCell] := MakeKeyContext(2, dmNaturalMinor);
      if LVariant = 1 then
      begin
        LEvidence[0].Grid.Keys[LCell] := MakeKeyContext(-1, dmMajor);
      end;
      if (LVariant = 2) and (LCell >= 32) then
      begin
        LEvidence[0].Grid.Keys[LCell] := MakeKeyContext(0, dmMajor);
      end;
      LEvidence[0].Grid.Tempos[LCell] := 500001;
      if LCell >= 35 then
      begin
        LEvidence[0].Grid.Tempos[LCell] := 600001;
      end;
    end;
    LBundle := TContextLearningBundle.Create(LEvidence);
    LProfile := nil;
    try
      LProfile := TContextProfile.Create(LBundle);
      WriteFileBytes(APrefix + '.' + CNames[LVariant] + '.pcp', EncodeContextProfile(LProfile));
    finally
      LProfile.Free;
      LBundle.Free;
    end;
  end;
  WriteLn('Authored minor/tempo, unknown, changing-key and incompatible-grid profiles written');
end;

procedure CheckOutput(const AProfileName, AOutput: String);
var
  LProfile: TContextProfile;
  LBytes: TAudioBytes;
  LText: String;
  LJson: TJSONData;
  LDocument: TJSONObject;
  LFrames: TJSONArray;
  LTempos: TJSONArray;
  LFrame: TWfcMusicEnsembleFrame;
  LNumerator: Int64;
  LCell: Integer;
  LVoice: Integer;
  LTone: Integer;
  LCount: Integer;
begin
  LProfile := DecodeContextProfile(ReadFileBytes(AProfileName, MaximumContextProfileBytes));
  LJson := nil;
  try
    LBytes := ReadFileBytes(AOutput + '.json', 16 * 1024 * 1024);
    SetLength(LText, Length(LBytes));
    if Length(LBytes) > 0 then
    begin
      Move(LBytes[0], LText[1], Length(LBytes));
    end;
    LJson := GetJSON(LText);
    Check(LJson is TJSONObject, 'Voice output must be a JSON object');
    LDocument := TJSONObject(LJson);
    Check((LDocument.Get('contract', '') = 'pythian.voices.context.demo.v1') and
      (LDocument.Get('context_profile_sha256', '') = LProfile.Identity),
      'Voice result retains exact input profile identity');
    Check((LDocument.Get('context_key_root', -1) = 2) and
      (LDocument.Get('context_key_mode_ordinal', -1) = Ord(dmNaturalMinor)),
      'Selected D-natural-minor key reaches realization');
    Check(LDocument.Arrays['context_passes'].Count = 2, 'Two actual context passes retained');
    LFrames := LDocument.Arrays['frames'];
    LTempos := LDocument.Arrays['tempo_cells'];
    Check((LFrames.Count = 64) and (LTempos.Count = 64), 'Complete aligned voice/tempo extent');
    Check((LTempos.Integers[0] = 500001) and (LTempos.Integers[63] = 600001),
      'Whole context generation retains observed tempo boundaries');
    LNumerator := 0;
    LCount := 0;
    for LCell := 0 to 63 do
    begin
      Check((LTempos.Integers[LCell] = 500001) or (LTempos.Integers[LCell] = 600001),
        'Selected tempo vocabulary');
      Inc(LNumerator, Int64(240) * LTempos.Integers[LCell] * 44100);
      LFrame := DecodeWfcMusicEnsembleFrame(LFrames.Strings[LCell]);
      Check(Length(LFrame.Voices) = 3, 'Independent bass/chord/melody roles retained');
      for LVoice := 0 to 2 do
      begin
        for LTone := 0 to High(LFrame.Voices[LVoice].Tones) do
        begin
          Check(LFrame.Voices[LVoice].Tones[LTone].Pitch mod 12 in [0, 2, 4, 5, 7, 9, 10],
            'Every realized tone belongs to D natural minor');
          Inc(LCount);
        end;
      end;
    end;
    Check(LCount > 0, 'Context realization must be audible');
    Check(LDocument.Get('preview_frames', Int64(0)) = LNumerator div 480000000,
      'Independent rational tempo sum agrees with rendered extent');
    Check(LDocument.Get('preview_verified_against_wfc', False) and
      LDocument.Get('midi_verified_against_wfc', False) and
      LDocument.Get('midi_verified_by_round_trip', False), 'Actual preview/MIDI checks completed');
    Check(HashAudioBytes(ReadFileBytes(AOutput, 128 * 1024 * 1024)) =
      LDocument.Get('stereo_sha256', ''), 'Actual stereo artifact binding');
    WriteLn('Saved profile, D-minor voice membership, varying tempo clock and actual audio binding pass');
  finally
    LJson.Free;
    LProfile.Free;
  end;
end;

begin
  try
    if ParamCount = 1 then
    begin
      Fixtures(ParamStr(1));
    end
    else
    begin
      Check(ParamCount = 2, 'Usage: pythian.tests.voices.context PREFIX; or PROFILE.pcp OUTPUT.wav');
      CheckOutput(ParamStr(1), ParamStr(2));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
