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
unit pythian.tools.studio.style.candidate;

{$mode delphi}{$H+}

interface

uses fpjson, pythian.progress, pythian.wfc.musical.corpus,
  pythian.wfc.semantic.style, pythian.tools.studio.instrumental.publication;

{ Native I/O only. Capture actual admitted corpus models/evidence and the exact
  performed sound recipe through the shared semantic archive. No PCM is read.
  Optional snapshot failure returns an explicit unavailable receipt; callback
  failure/cancellation propagates unchanged. Existing content is never replaced. }
function RetainStudioStyleCandidate(const ACatalogRoot: String;
  const ACorpus: TMusicalCorpus; const AAudioSources: TJSONArray;
  const ARecipe: TSemanticInstrumentalRecipe; const ACheck: TInstrumentalWorkCheck;
  const AProgress: TWorkProgressCallback): TJSONObject;

implementation

uses Classes, SysUtils, pythian.audio, pythian.text, pythian.hash,
  pythian.wfc.semantic.corpus, pythian.tools.json,
  pythian.tools.path,
  pythian.tools.studio.jobs, pythian.tools.listen.assets;

type
  TCandidateProgress = class
  public
    Check: TInstrumentalWorkCheck;
    Callback: TWorkProgressCallback;
    CallbackFailed: Boolean;
    procedure Observe(const AWork: TWorkProgress);
  end;

procedure TCandidateProgress.Observe(const AWork: TWorkProgress);
begin
  try
    if Assigned(Check) then Check;
    if Assigned(Callback) then Callback(AWork);
  except
    CallbackFailed := True;
    raise;
  end;
end;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create(AMessage);
end;

function CorpusSources(const ACorpus: TMusicalCorpus;
  const AAudioSources: TJSONArray): TSemanticSources;
var
  LActual: TMusicalCorpusSources;
  LRow: TJSONObject;
  LParent: TJSONObject;
  LMetadata: TJSONObject;
  LEvidence: TJSONObject;
  LClip: TJSONObject;
  LRecipe: TJSONObject;
  I: Integer;
begin
  LActual := ACorpus.CopySources;
  Need((AAudioSources <> nil) and (AAudioSources.Count = Length(LActual)),
    'Style source context differs from the actual learned corpus');
  SetLength(Result, Length(LActual));
  for I := 0 to High(LActual) do
  begin
    LRow := AAudioSources.Objects[I];
    Need(LRow.Strings['source_sha256'] = LActual[I].Sha256,
      'Style source receipt changes its actual learned audio identity');
    Need(LRow.Find('source_metadata') <> nil, 'Style source license/provenance context is unavailable');
    LMetadata := LRow.Objects['source_metadata'];
    Need((LMetadata.Get('partition', '') <> 'evaluation') and
      (LMetadata.Get('partition', '') <> 'test') and
      (LMetadata.Get('partition', '') <> 'validation'), 'Reserved source cannot become a learned style');
    LParent := TJSONObject.Create;
    LEvidence := TJSONObject.Create;
    try
      Result[I].Sha256 := LActual[I].Sha256;
      Result[I].GroupId := LActual[I].GroupId;
      Result[I].SampleRate := LActual[I].SampleRate;
      Result[I].FrameCount := LActual[I].FrameCount;
      Result[I].Split := ssTraining;
      Result[I].Exposure := [seTraining, seVocabulary];
      Result[I].ExternalRequirement := 'Private source bytes required only to repeat measurement';
      LParent.Add('format', 'pythian.studio.parent-metadata-origin.v1');
      if LRow.Find('clip_receipt') <> nil then
      begin
        LClip := LRow.Objects['clip_receipt'];
        LRecipe := LClip.Objects['recipe'];
        LParent.Add('kind', LRecipe.Strings['parent_kind']);
        LParent.Add('id', LRecipe.Strings['parent_id']);
        LParent.Add('snapshot_sha256', LRecipe.Strings['parent_snapshot_sha256']);
        LParent.Add('discovery_revision', LRecipe.Integers['discovery_revision']);
        Result[I].OriginSampleRate := LRecipe.Integers['sample_rate'];
        Result[I].OriginFrameCount := LRecipe.Int64s['parent_frame_count'];
        Result[I].OriginStartFrame := LRecipe.Int64s['start_frame'];
        Result[I].OriginEndFrame := LRecipe.Int64s['end_frame'];
        if LRecipe.Strings['parent_kind'] = 'catalog' then
          Result[I].OriginSha256 := LRecipe.Strings['parent_id'];
        LEvidence.Add('clip_receipt', LClip.Clone);
      end
      else
      begin
        LRecipe := LRow.Objects['playlist_item'];
        LParent.Add('kind', LRecipe.Strings['kind']);
        LParent.Add('id', LRecipe.Strings['id']);
        LParent.Add('snapshot_sha256', LRecipe.Strings['snapshot_sha256']);
        LParent.Add('discovery_revision', LRecipe.Integers['discovery_revision']);
        Result[I].OriginSha256 := Result[I].Sha256;
        Result[I].OriginSampleRate := Result[I].SampleRate;
        Result[I].OriginFrameCount := Result[I].FrameCount;
        Result[I].OriginEndFrame := Result[I].FrameCount;
      end;
      LParent.Add('sample_rate', Result[I].OriginSampleRate);
      LParent.Add('frame_count', Result[I].OriginFrameCount);
      Result[I].OriginMetadataIdentity := HashNativeText(WriteNativeJSON(LParent, 65536));
      LEvidence.Add('format', 'pythian.studio.style-source.v1');
      LEvidence.Add('source_sha256', LActual[I].Sha256);
      LEvidence.Add('source_origin', LActual[I].OriginIdentity);
      LEvidence.Add('source_metadata', LMetadata.Clone);
      LEvidence.Add('parent_metadata_binding', LParent.Clone);
      Result[I].PreparationEvidence := EncodeUTF8Text(
        TScalarText(WriteNativeJSON(LEvidence, 65536)), 65536);
      Result[I].PreparationSha256 := SemanticPreparationIdentity(Result[I]);
    finally
      LEvidence.Free;
      LParent.Free;
    end;
  end;
end;

function RetainStudioStyleCandidate(const ACatalogRoot: String;
  const ACorpus: TMusicalCorpus; const AAudioSources: TJSONArray;
  const ARecipe: TSemanticInstrumentalRecipe; const ACheck: TInstrumentalWorkCheck;
  const AProgress: TWorkProgressCallback): TJSONObject;
var
  LStyle: TSemanticStyle;
  LDefinition: TSemanticStyleDefinition;
  LProgress: TCandidateProgress;
  LBytes: TAudioBytes;
  LFile: TFileStream;
  LPath: String;
begin
  Result := TJSONObject.Create(['format', 'pythian.studio.style-candidate.v1',
    'status', 'unavailable']);
  LStyle := nil;
  LProgress := nil;
  try
  try
    try
      Need(ACorpus <> nil, 'This generation has no learned musical corpus');
      LProgress := TCandidateProgress.Create;
      LProgress.Check := ACheck;
      LProgress.Callback := AProgress;
      ReportWork(LProgress.Observe, 'studio_style_snapshot', wuItems, 0, 1);
      LDefinition := MusicalCorpusStyleDefinition(ACorpus,
        CorpusSources(ACorpus, AAudioSources), ARecipe, LProgress.Observe);
      LStyle := TSemanticStyle.CreateSource(LDefinition, nil, nil, LProgress.Observe);
      LBytes := LStyle.Encode(LProgress.Observe);
      LPath := ListeningAssetDirectory(ACatalogRoot) + PathDelim + 'styles' +
        PathDelim + LStyle.Identity + '.pysg';
      if FileExists(NativeFilePath(LPath)) then
      begin
        LFile := OpenStudioReadStream(LPath);
        try
          Need((LFile.Size = Length(LBytes)) and
            (Sha256Stream(LFile, LFile.Size, LProgress.Observe) = LStyle.Identity),
            'Existing style content differs from its immutable identity');
        finally
          LFile.Free;
        end;
      end
      else WriteStudioBinaryNew(LPath, LBytes, MaximumSemanticStyleBytes);
      Result.Strings['status'] := 'ready';
      Result.Add('sha256', LStyle.Identity);
      Result.Add('bytes', Length(LBytes));
      Result.Add('artifact', 'styles/' + LStyle.Identity + '.pysg');
      Result.Add('corpus_revision', ACorpus.RevisionIdentity);
      Result.Add('provider_count', Length(LDefinition.Providers));
      Result.Add('source_count', Length(LDefinition.Sources));
      Result.Add('contribution_count', Length(LDefinition.Runs));
      ReportWork(LProgress.Observe, 'studio_style_snapshot', wuItems, 1, 1);
    except
      on E: Exception do
      begin
        if (LProgress <> nil) and LProgress.CallbackFailed then raise;
        Result.Strings['status'] := 'unavailable';
        Result.Add('reason', E.ClassName + ': ' + E.Message);
      end;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
  finally
    LStyle.Free;
    LProgress.Free;
  end;
end;

end.
