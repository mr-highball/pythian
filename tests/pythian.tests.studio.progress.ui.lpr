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
program StudioProgressPresentation;

{$mode delphi}
{$H+}

uses JS, Web, SysUtils, pythian.studio.progress;

var GChecks: Integer; LJob: TJSObject; LFirst: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

{$IFDEF STUDIO_PROGRESS_PREVIEW}
var LHost, LProgress, LButton: TJSElement;

function NextCallback(AEvent: TJSEvent): Boolean;
begin
  LJob['done'] := 838860800;
  LProgress.textContent := '';
  DrawStudioProgress(LProgress, LJob, True);
  Result := True;
end;

procedure Preview;
var LWorkflow: TJSObject;
begin
  { Big Boss: recorded real worker callback geometry; this is a component
    preview, not a running job, timer or fabricated learning percentage. }
  document.body.textContent := '';
  LHost := document.createElement('main');
  LHost.setAttribute('style', 'max-width:60rem;margin:1rem auto;padding:1rem');
  document.body.appendChild(LHost);
  LButton := document.createElement('h1');
  LButton.textContent := 'Recorded progress callbacks';
  LHost.appendChild(LButton);
  LJob := TJSObject.new;
  LJob['kind'] := 'instrumental_generate';
  LJob['status'] := 'running';
  LJob['stage'] := 'verifying_original_bytes';
  LJob['done'] := 738197504;
  LJob['total'] := 1966128086;
  LJob['progress_unit'] := 'bytes';
  LWorkflow := TJSObject.new;
  LWorkflow['phase'] := 1;
  LWorkflow['done'] := 0;
  LWorkflow['total'] := 17878;
  LWorkflow['unit'] := 'milliseconds';
  LJob['workflow'] := LWorkflow;
  LProgress := document.createElement('div');
  LHost.appendChild(LProgress);
  DrawStudioProgress(LProgress, LJob, True);
  LButton := document.createElement('button');
  LButton.textContent := 'Next recorded callback';
  LButton.addEventListener('click', @NextCallback);
  LHost.appendChild(LButton);
end;
{$ENDIF}

begin
  LJob := TJSObject.new;
  LJob['progress_unit'] := 'bytes';
  LJob['done'] := 738197504;
  LJob['total'] := 1966128086;
  LFirst := StudioOperationDetail(LJob);
  Check(Pos('704.0 MiB', LFirst) > 0, 'Live checked-byte count hidden');
  Check(Pos('1.83 GiB', LFirst) > 0, 'Original file extent hidden');
  Check(Pos('(37%)', LFirst) > 0, 'Operation fraction incorrect');
  LJob['done'] := 838860800;
  Check(StudioOperationDetail(LJob) <> LFirst, 'Advancing callback detail is static');
  Check(StudioStageText('verifying_original_bytes') = 'Check original file',
    'Original-file callback falls through to generic preparation');
  LJob['progress_unit'] := 'frames';
  LJob['done'] := 33792;
  LJob['total'] := 64000;
  Check(Pos('33792 / 64000 audio frames (52%)', StudioOperationDetail(LJob)) > 0,
    'Actual resampling frames hidden');
  Check(Pos('%', StudioOperationDetail(LJob, False)) = 0,
    'A nested render count duplicates the workflow percentage');
  LJob['progress_unit'] := 'visits';
  LJob['total'] := 0;
  Check(Pos('33792 work steps', StudioOperationDetail(LJob)) > 0, 'Unknown-total work hidden');
  Check(Pos('%', StudioOperationDetail(LJob)) = 0, 'Unknown total acquired false percentage');
  Check(Pos('total not yet known', StudioOperationDetail(LJob)) > 0, 'Unknown extent not explained');
  LJob['progress_unit'] := 'items';
  LJob['done'] := 3;
  LJob['total'] := 7;
  Check(Pos('3 / 7 items (42%)', StudioOperationDetail(LJob)) > 0, 'Known item work hidden');
  LJob['progress_unit'] := '';
  Check(StudioOperationDetail(LJob) = '', 'Missing unit acquired a misleading count');
  Writeln('PASS Studio progress presentation: ', GChecks, ' checks');
  {$IFDEF STUDIO_PROGRESS_PREVIEW}Preview;{$ENDIF}
end.
