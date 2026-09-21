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
program pythian.tonal.inspect;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.analysis,
  pythian.music,
  pythian.midi.smf,
  pythian.midi.notes,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.tonal,
  pythian.tools.files;

function DescribeWeights(const AWeights: TPitchClassWeights): TJSONObject;
var
  LReport: TTonalReport;
  LWeights: TJSONArray;
  LFits: TJSONArray;
  LFit: TJSONObject;
  LIndex: Integer;
begin
  LReport := RankDiatonicFits(AWeights);
  Result := TJSONObject.Create;
  try
    Result.Add('profile_version', TonalProfileVersion);
    Result.Add('fit_version', DiatonicFitVersion);
    Result.Add('has_evidence', LReport.CandidateCount > 0);
    Result.Add('total_weight', LReport.TotalWeight);
    Result.Add('score_gap', LReport.ScoreGap);
    Result.Add('score_is_probability', False);
    LWeights := TJSONArray.Create;
    Result.Add('pitch_class_weights', LWeights);
    for LIndex := 0 to 11 do
    begin
      LWeights.Add(AWeights[LIndex]);
    end;
    LFits := TJSONArray.Create;
    Result.Add('ranked_fits', LFits);
    for LIndex := 0 to LReport.CandidateCount - 1 do
    begin
      LFit := TJSONObject.Create;
      LFits.Add(LFit);
      LFit.Add('root_pitch_class', LReport.Fits[LIndex].Root);
      if LReport.Fits[LIndex].Mode = dmMajor then
      begin
        LFit.Add('mode', 'major');
      end
      else
      begin
        LFit.Add('mode', 'natural_minor');
      end;
      LFit.Add('raw_score', LReport.Fits[LIndex].RawScore);
      LFit.Add('score', LReport.Fits[LIndex].Score);
      LFit.Add('coverage', LReport.Fits[LIndex].Coverage);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure Run;
var
  LBytes: TAudioBytes;
  LMidi: TMidiBytes;
  LImport: TMidiNoteReport;
  LSequence: TNoteSequence;
  LClip: TAudioClip;
  LCorpus: TAcousticCorpusData;
  LRecording: TAcousticRecording;
  LContract: UTF8String;
  LAttachment: TAudioBytes;
  LFeatures: TAudioFeatures;
  LOptions: TAnalysisOptions;
  LDocument: TJSONObject;
  LProfiles: TJSONArray;
  LItem: TJSONObject;
  LWeights: TPitchClassWeights;
  LCap: Int64;
  LEnergy: Boolean;
  LIndex: Integer;
begin
  if (ParamCount < 2) or (ParamCount > 3) or
    not ((ParamStr(1) = 'midi') or (ParamStr(1) = 'wav') or (ParamStr(1) = 'corpus')) then
  begin
    raise EAudio.Create('Usage: pythian.tonal.inspect midi INPUT.mid [MAX_NOTE_TICKS] ' +
      'or wav INPUT.wav [duration|energy] or corpus INPUT.pyac [duration|energy]');
  end;
  LEnergy := False;
  if (ParamStr(1) <> 'midi') and (ParamCount = 3) then
  begin
    if not ((ParamStr(3) = 'duration') or (ParamStr(3) = 'energy')) then
    begin
      raise EAudio.Create('WAV profile weighting must be duration or energy');
    end;
    LEnergy := ParamStr(3) = 'energy';
  end;
  LDocument := TJSONObject.Create;
  try
    LDocument.Add('input_kind', ParamStr(1));
    LDocument.Add('file', ExtractFileName(ParamStr(2)));
    if ParamStr(1) = 'midi' then
    begin
      LBytes := ReadFileBytes(ParamStr(2), DefaultMidiReadLimits.MaxFileBytes);
      LDocument.Add('source_sha256', HashAudioBytes(LBytes));
      LMidi := nil;
      SetLength(LMidi, Length(LBytes));
      if Length(LBytes) > 0 then
      begin
        Move(LBytes[0], LMidi[0], Length(LBytes));
      end;
      LSequence := DecodeMidiNotes(LMidi, DefaultMidiNoteOptions, LImport);
      try
        LCap := Int64(4) * LSequence.TicksPerQuarter;
        if ParamCount = 3 then
        begin
          LCap := StrToInt64(ParamStr(3));
        end;
        LWeights := NotePitchClassWeights(LSequence, LCap);
        LDocument.Add('ticks_per_quarter', LSequence.TicksPerQuarter);
        LDocument.Add('maximum_note_ticks', LCap);
        LDocument.Add('weighting', 'note_ticks');
        LDocument.Add('velocity_weighted', False);
        LDocument.Add('source_notes', LSequence.NoteCount);
        LDocument.Add('ignored_metadata_events', LImport.IgnoredMetadataEvents);
        LDocument.Add('discarded_release_velocities', LImport.DiscardedReleaseVelocities);
        LDocument.Add('zero_length_notes', LImport.ZeroLengthNotes);
        LDocument.Add('profile', DescribeWeights(LWeights));
      finally
        LSequence.Free;
      end;
    end
    else
    begin
      if LEnergy then
      begin
        LDocument.Add('weighting', 'rms_squared_sample_frames');
      end
      else
      begin
        LDocument.Add('weighting', 'sample_frames');
      end;
      LDocument.Add('analysis_version', AnalysisVersion);
      if ParamStr(1) = 'wav' then
      begin
        LBytes := ReadFileBytes(ParamStr(2), MaximumWaveBytes);
        LDocument.Add('source_sha256', HashAudioBytes(LBytes));
        LClip := DecodeWave(LBytes);
        try
          LOptions := DefaultAnalysisOptions;
          LFeatures := AnalyzeAudio(LClip, LOptions);
          LDocument.Add('window_frames', LOptions.WindowFrames);
          LDocument.Add('hop_frames', LOptions.HopFrames);
          LDocument.Add('sample_rate', LClip.SampleRate);
          LDocument.Add('source_frames', LClip.FrameCount);
          LDocument.Add('profile', DescribeWeights(FeaturePitchClassWeights(
            LFeatures, LOptions, LClip.FrameCount, LEnergy)));
        finally
          LClip.Free;
        end;
      end
      else
      begin
        LBytes := ReadFileBytes(ParamStr(2), MaximumCorpusArchiveBytes);
        LDocument.Add('archive_sha256', HashAudioBytes(LBytes));
        LCorpus := DecodeAcousticArchive(LBytes, LContract, LAttachment);
        try
          LDocument.Add('opaque_attachment_contract', String(LContract));
          LDocument.Add('window_frames', LCorpus.Options.WindowFrames);
          LDocument.Add('hop_frames', LCorpus.Options.HopFrames);
          LDocument.Add('used_stored_features', True);
          LProfiles := TJSONArray.Create;
          LDocument.Add('sources', LProfiles);
          for LIndex := 0 to LCorpus.SourceCount - 1 do
          begin
            LRecording := LCorpus.RecordingAt(LIndex);
            LWeights := FeaturePitchClassWeights(LRecording.Features, LCorpus.Options,
              LRecording.Info.FrameCount, LEnergy);
            LItem := DescribeWeights(LWeights);
            LProfiles.Add(LItem);
            LItem.Add('name', String(LRecording.Info.Name));
            LItem.Add('source_sha256', LRecording.Info.Sha256);
            LItem.Add('provenance', String(LRecording.Info.Provenance));
          end;
        finally
          LCorpus.Free;
        end;
      end;
    end;
    WriteLn(LDocument.FormatJSON);
  finally
    LDocument.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
