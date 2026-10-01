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
unit pythian.tools.studio.effects.worker;

{$mode delphi}
{$H+}

interface

uses fpjson, pythian.tools.studio.worker;

function RunStudioEffectJob(const ACatalogRoot, AJobId, ALibraryRoot: String;
  const ARequest: TJSONObject; const ACheck: TStudioWorkerCheck): TJSONObject;

implementation

uses pythian.audio, pythian.tools.studio.jobs, pythian.tools.studio.effects,
  pythian.tools.studio.capture, pythian.tools.studio.pitch;

function RunStudioEffectJob(const ACatalogRoot, AJobId, ALibraryRoot: String;
  const ARequest: TJSONObject; const ACheck: TStudioWorkerCheck): TJSONObject;
begin
  if ARequest.Strings['kind'] = 'capture_pitch' then
  begin
    AdvanceStudioJob(ACatalogRoot, AJobId, 'running', 'preview_pitch', 0, 0);
    Exit(PreviewStudioPitch(ACatalogRoot, AJobId, ARequest, TStudioEffectCheck(ACheck)));
  end;
  if ARequest.Strings['kind'] = 'capture_inspect' then
  begin
    AdvanceStudioJob(ACatalogRoot, AJobId, 'running', 'inspect_temporary_audio', 0, 0);
    Exit(InspectStudioCapture(ACatalogRoot, ARequest.Strings['capture_id'],
      TStudioEffectCheck(ACheck)));
  end;
  if ARequest.Strings['kind'] = 'capture_save' then
  begin
    AdvanceStudioJob(ACatalogRoot, AJobId, 'running', 'save_capture', 0, 0);
    Exit(SaveStudioCapture(ACatalogRoot, AJobId, ALibraryRoot, ARequest,
      TStudioEffectCheck(ACheck)));
  end;
  ValidateStudioEffectRequest(ARequest);
  if ARequest.Strings['kind'] = 'effect_preview' then
  begin
    AdvanceStudioJob(ACatalogRoot, AJobId, 'running', 'render_effects', 0, 0);
    Result := RenderStudioEffectPreview(ACatalogRoot, AJobId, ARequest, TStudioEffectCheck(ACheck));
  end
  else if ARequest.Strings['kind'] = 'effect_save' then
  begin
    AdvanceStudioJob(ACatalogRoot, AJobId, 'running', 'save_derived_clip', 0, 0);
    Result := SaveStudioEffectPreview(ACatalogRoot, AJobId, ALibraryRoot, ARequest,
      TStudioEffectCheck(ACheck));
  end
  else
  begin
    raise EAudio.Create('Unsupported Studio effects job');
  end;
end;

end.
