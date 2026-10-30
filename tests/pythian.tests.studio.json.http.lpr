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

program pythian_tests_studio_json_http;
{$mode delphi}
{$H+}
{$codepage utf8}

uses Classes, SysUtils, fpjson, fphttpclient, pythian.tools.json;

var
  Checks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function JSON(const AText: RawByteString): TJSONObject;
var
  LData: TJSONData;
begin
  LData := ParseNativeJSON(AText, 1048576, 12);
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise Exception.Create('Expected native HTTP object');
  end;
  Result := TJSONObject(LData);
end;

procedure Run(const ABase, AInputPath: String);
var
  LClient: TFPHTTPClient;
  LInput: TFileStream;
  LText: RawByteString;
  LExpected, LBefore, LResponse, LReload, LRetry, LAfter, LProposal, LSession: TJSONObject;
  LName: TJSONStringType;
begin
  LClient := TFPHTTPClient.Create(nil);
  LInput := nil;
  LExpected := nil;
  LBefore := nil;
  LResponse := nil;
  LReload := nil;
  LRetry := nil;
  LAfter := nil;
  LProposal := nil;
  LSession := nil;
  try
    Check(Pos('http://127.0.0.1:', ABase) = 1, 'Use the isolated loopback service');
    LInput := TFileStream.Create(AInputPath, fmOpenRead or fmShareDenyWrite);
    Check((LInput.Size > 0) and (LInput.Size <= 32768), 'HTTP fixture uses the ordinary request bound');
    SetLength(LText, LInput.Size);
    LInput.ReadBuffer(LText[1], Length(LText));
    LExpected := JSON(LText);
    LName := LExpected.Strings['name'];
    Check((Ord(LName[2]) = $E2) and (Ord(LName[3]) = $99) and
      (Ord(LName[4]) = $AF), 'Wire input contains the actual UTF-8 sharp sign');
    LText := LClient.Get(ABase + '/studio.html');
    Check((LClient.ResponseStatusCode = 200) and (Pos('Pythian', LText) > 0),
      'Actual Studio shell loads from the fixed QA service');
    LSession := JSON(LClient.Get(ABase + '/api/session'));
    Check(LSession.Strings['token'] <> '', 'Normal loopback session acquired');
    LClient.AddHeader('X-Pythian-Token', LSession.Strings['token']);
    LClient.AddHeader('Origin', ABase);
    LBefore := JSON(LClient.Get(ABase + '/api/studio/jobs'));
    LClient.AddHeader('Content-Type', 'application/json; charset=utf-8');
    LInput.Position := 0;
    LClient.RequestBody := LInput;
    try
      LResponse := JSON(LClient.Post(ABase + '/api/studio/project'));
    finally
      LClient.RequestBody := nil;
    end;
    Check(LClient.ResponseStatusCode = 200, 'Native HTTP project save succeeds');
    Check(LResponse.Strings['name'] = LExpected.Strings['name'], 'JSON response retains Unicode project name');
    Check(LResponse.Objects['musical_material'].Strings['notes'] =
      LExpected.Objects['musical_material'].Strings['notes'], 'JSON response retains Unicode musical notes');
    LReload := JSON(LClient.Get(ABase + '/api/studio/project?id=' +
      LExpected.Strings['project_id']));
    Check((LReload.Strings['name'] = LExpected.Strings['name']) and
      (LReload.Objects['musical_material'].Strings['notes'] =
      LExpected.Objects['musical_material'].Strings['notes']), 'HTTP reload retains the exact saved scalars');
    Check(LReload.Strings['snapshot_sha256'] = LResponse.Strings['snapshot_sha256'],
      'Actual HTTP reload preserves immutable snapshot identity');
    Check(not LReload.Booleans['model_available'] and
      (LReload.Strings['training_status'] = 'not_started'), 'HTTP Save does not claim a learned model');
    LInput.Position := 0;
    LClient.RequestBody := LInput;
    try
      LRetry := JSON(LClient.Post(ABase + '/api/studio/project'));
    finally
      LClient.RequestBody := nil;
    end;
    Check(LRetry.Booleans['already_saved'] and (LRetry.Integers['revision'] = 1),
      'Actual HTTP retry reconciles without replacing evidence');
    LProposal := JSON(LClient.Get(ABase + '/api/studio/musical-material?id=' +
      LExpected.Objects['musical_material'].Strings['analysis_job_id'] + '&tempo=120&channel=0'));
    Check(LProposal.Strings['analysis_result_sha256'] =
      LExpected.Objects['musical_material'].Strings['analysis_result_sha256'],
      'Actual proposal endpoint retains its native analysis receipt');
    LAfter := JSON(LClient.Get(ABase + '/api/studio/jobs'));
    Check(LAfter.Arrays['jobs'].Count = LBefore.Arrays['jobs'].Count,
      'HTTP preparing/saving/reloading choices creates no hidden work');
    Check(LReload.Objects['musical_material'].Objects['source'].AsJSON =
      LExpected.Objects['musical_material'].Objects['source'].AsJSON,
      'Source clock, identity, license and provenance survive actual HTTP');
  finally
    LSession.Free;
    LProposal.Free;
    LAfter.Free;
    LRetry.Free;
    LReload.Free;
    LResponse.Free;
    LBefore.Free;
    LExpected.Free;
    LClient.Free;
    LInput.Free;
  end;
end;

begin
  try
    Check(ParamCount = 2, 'Usage: studio JSON HTTP test LOOPBACK_BASE INPUT_JSON');
    Run(ParamStr(1), ParamStr(2));
    WriteLn('PASS native Studio JSON HTTP: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
