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
program pythian_label_catalog;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.media;

var
  LReport: TJSONObject;
  LStartFrame: Int64;
  LEndFrame: Int64;
  LBins: Integer;
  LOutput: TFileStream;
  LOutputPath: String;
  LStagePath: String;
  LGuid: TGUID;
begin
  try
    if (ParamCount = 3) and (ParamStr(1) = 'import') then
    begin
      LReport := ImportLabelInbox(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 2) and (ParamStr(1) = 'list') then
    begin
      LReport := ListLabelCatalog(ParamStr(2));
    end
    else if (ParamCount = 6) and (ParamStr(1) = 'waveform') then
    begin
      if not TryStrToInt64(ParamStr(4), LStartFrame) or
        not TryStrToInt64(ParamStr(5), LEndFrame) or
        not TryStrToInt(ParamStr(6), LBins) then
      begin
        raise Exception.Create('Invalid waveform frame or bin argument');
      end;
      LReport := CatalogWaveformRegion(ParamStr(2), ParamStr(3),
        LStartFrame, LEndFrame, LBins);
    end
    else if (ParamCount = 6) and (ParamStr(1) = 'audio') then
    begin
      if not TryStrToInt64(ParamStr(4), LStartFrame) or
        not TryStrToInt64(ParamStr(5), LEndFrame) then
      begin
        raise Exception.Create('Invalid audio frame argument');
      end;
      LOutputPath := ParamStr(6);
      if FileExists(LOutputPath) then
      begin
        raise Exception.Create('Audio output already exists');
      end;
      if CreateGUID(LGuid) <> 0 then
      begin
        raise Exception.Create('Could not create audio stage identity');
      end;
      LStagePath := LOutputPath + '.' + GUIDToString(LGuid) + '.partial';
      try
        LOutput := TFileStream.Create(LStagePath,
          fmCreate or fmShareExclusive);
        try
          WriteCatalogAudioRegion(ParamStr(2), ParamStr(3),
            LStartFrame, LEndFrame, LOutput);
        finally
          LOutput.Free;
        end;
        if FileExists(LOutputPath) or
          not RenameFile(LStagePath, LOutputPath) then
        begin
          raise Exception.Create('Could not publish audio region');
        end;
      finally
        if FileExists(LStagePath) then
        begin
          DeleteFile(LStagePath);
        end;
      end;
      Exit;
    end
    else
    begin
      WriteLn(StdErr, 'Usage: pythian.label.catalog import INBOX_DIR CATALOG_DIR');
      WriteLn(StdErr, '       pythian.label.catalog list CATALOG_DIR');
      WriteLn(StdErr, '       pythian.label.catalog waveform CATALOG_DIR HASH START END BINS');
      WriteLn(StdErr, '       pythian.label.catalog audio CATALOG_DIR HASH START END OUTPUT.wav');
      ExitCode := 2;
      Exit;
    end;
    try
      WriteLn(LReport.AsJSON);
      if (LReport.Find('failed') <> nil) and (LReport.Integers['failed'] > 0) then
      begin
        ExitCode := 1;
      end;
    finally
      LReport.Free;
    end;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
