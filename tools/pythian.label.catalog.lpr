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
  jsonparser,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.export,
  pythian.tools.annotations.http,
  pythian.tools.annotations.media,
  pythian.tools.annotations.proposal,
  pythian.tools.annotations.replay,
  pythian.tools.annotations.review;

procedure RequireProposalAccess(const ACatalogRoot, AHash: String);
var
  LTrack: TJSONObject;
begin
  LTrack := ReadCatalogTrack(ACatalogRoot, AHash);
  try
    if not CatalogProposalsUnlocked(ACatalogRoot, LTrack) then
    begin
      raise Exception.Create('Evaluation proposals require blind review');
    end;
  finally
    LTrack.Free;
  end;
end;

var
  LReport: TJSONObject;
  LStartFrame: Int64;
  LEndFrame: Int64;
  LBins: Integer;
  LOutput: TFileStream;
  LOutputPath: String;
  LStagePath: String;
  LGuid: TGUID;
  LInput: TFileStream;
  LText: String;
  LData: TJSONData;
  LFirstRevision: Integer;
  LMaximumCount: Integer;
  LPort: Integer;
  LMaximumRequests: Integer;
  LBindAddress: String;
  LStaticRoot: String;
  LFirstServerArgument: Integer;
begin
  try
    if ((ParamCount in [4, 5, 6]) and
      (ParamStr(1) = 'serve')) or
      ((ParamCount in [5, 6, 7]) and
      (ParamStr(1) = 'serve-app')) then
    begin
      LBindAddress := '127.0.0.1';
      LMaximumRequests := 0;
      LStaticRoot := '';
      LFirstServerArgument := 4;
      if ParamStr(1) = 'serve-app' then
      begin
        LStaticRoot := ParamStr(4);
        LFirstServerArgument := 5;
      end;
      if TryStrToInt(ParamStr(LFirstServerArgument), LPort) then
      begin
        if (ParamCount > LFirstServerArgument + 1) or
          ((ParamCount = LFirstServerArgument + 1) and
          not TryStrToInt(ParamStr(LFirstServerArgument + 1),
            LMaximumRequests)) then
        begin
          raise Exception.Create('Invalid loopback HTTP request limit');
        end;
      end
      else
      begin
        LBindAddress := ParamStr(LFirstServerArgument);
        if (ParamCount < LFirstServerArgument + 1) or
          not TryStrToInt(ParamStr(LFirstServerArgument + 1), LPort) then
        begin
          raise Exception.Create('Invalid HTTP port');
        end;
        if (ParamCount = LFirstServerArgument + 2) and
          not TryStrToInt(ParamStr(LFirstServerArgument + 2),
            LMaximumRequests) then
        begin
          raise Exception.Create('Invalid HTTP request limit');
        end;
      end;
      RunCatalogHttp(ParamStr(2), ParamStr(3), LBindAddress, LPort,
        LMaximumRequests, LStaticRoot);
      Exit;
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'import') then
    begin
      LReport := ImportLabelInbox(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 2) and (ParamStr(1) = 'list') then
    begin
      LReport := ListLabelCatalog(ParamStr(2));
    end
    else if (ParamCount = 2) and (ParamStr(1) = 'inbox') then
    begin
      LReport := ReadPreparedLabelInbox(ParamStr(2));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'export') then
    begin
      LReport := ExportReviewedCatalog(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 2) and (ParamStr(1) = 'inspect-export') then
    begin
      LReport := InspectReviewedCatalogPacket(ParamStr(2));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'import-reviewed') then
    begin
      LReport := ReplayReviewedCatalogPacket(ParamStr(2), ParamStr(3));
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
    else if (ParamCount = 3) and (ParamStr(1) = 'review') then
    begin
      LInput := TFileStream.Create(ParamStr(3),
        fmOpenRead or fmShareDenyWrite);
      try
        if (LInput.Size <= 0) or (LInput.Size > 16384) then
        begin
          raise Exception.Create('Review transaction file exceeds size bound');
        end;
        SetLength(LText, Integer(LInput.Size));
        LInput.ReadBuffer(LText[1], Length(LText));
      finally
        LInput.Free;
      end;
      LData := GetJSON(LText);
      try
        if LData.JSONType <> jtObject then
        begin
          raise Exception.Create('Review transaction must be an object');
        end;
        LReport := CommitCatalogReview(ParamStr(2), TJSONObject(LData));
      finally
        LData.Free;
      end;
    end
    else if (ParamCount = 5) and (ParamStr(1) = 'history') then
    begin
      if not TryStrToInt(ParamStr(4), LFirstRevision) or
        not TryStrToInt(ParamStr(5), LMaximumCount) then
      begin
        raise Exception.Create('Invalid review history page argument');
      end;
      LReport := ReadCatalogReviewHistory(ParamStr(2), ParamStr(3),
        LFirstRevision, LMaximumCount);
    end
    else if (ParamCount = 5) and (ParamStr(1) = 'propose-beats') then
    begin
      if not TryStrToInt64(ParamStr(4), LStartFrame) or
        not TryStrToInt64(ParamStr(5), LEndFrame) then
      begin
        raise Exception.Create('Invalid beat-proposal frame argument');
      end;
      RequireProposalAccess(ParamStr(2), ParamStr(3));
      LReport := PublishCatalogBeatProposals(ParamStr(2), ParamStr(3),
        LStartFrame, LEndFrame);
    end
    else if (ParamCount = 5) and (ParamStr(1) = 'proposals') then
    begin
      if not TryStrToInt64(ParamStr(4), LStartFrame) or
        not TryStrToInt64(ParamStr(5), LEndFrame) then
      begin
        raise Exception.Create('Invalid proposal read frame argument');
      end;
      RequireProposalAccess(ParamStr(2), ParamStr(3));
      LReport := ReadCatalogBeatProposals(ParamStr(2), ParamStr(3),
        LStartFrame, LEndFrame);
    end
    else if (ParamCount = 6) and (ParamStr(1) = 'current') then
    begin
      if not TryStrToInt64(ParamStr(4), LStartFrame) or
        not TryStrToInt64(ParamStr(5), LEndFrame) or
        not TryStrToInt(ParamStr(6), LMaximumCount) then
      begin
        raise Exception.Create('Invalid current-label page argument');
      end;
      LReport := ReadCatalogCurrentLabels(ParamStr(2), ParamStr(3),
        LStartFrame, LEndFrame, LMaximumCount);
    end
    else
    begin
      WriteLn(StdErr, 'Usage: pythian.label.catalog import INBOX_DIR CATALOG_DIR');
      WriteLn(StdErr, '       pythian.label.catalog list CATALOG_DIR');
      WriteLn(StdErr, '       pythian.label.catalog inbox INBOX_DIR');
      WriteLn(StdErr, '       pythian.label.catalog export CATALOG_DIR OUTPUT.json');
      WriteLn(StdErr, '       pythian.label.catalog inspect-export PACKET.json');
      WriteLn(StdErr, '       pythian.label.catalog import-reviewed CATALOG_DIR PACKET.json');
      WriteLn(StdErr, '       pythian.label.catalog waveform CATALOG_DIR HASH START END BINS');
      WriteLn(StdErr, '       pythian.label.catalog audio CATALOG_DIR HASH START END OUTPUT.wav');
      WriteLn(StdErr, '       pythian.label.catalog review CATALOG_DIR TRANSACTION.json');
      WriteLn(StdErr, '       pythian.label.catalog history CATALOG_DIR HASH FIRST COUNT');
      WriteLn(StdErr, '       pythian.label.catalog current CATALOG_DIR HASH START END COUNT');
      WriteLn(StdErr, '       pythian.label.catalog propose-beats CATALOG_DIR HASH START END');
      WriteLn(StdErr, '       pythian.label.catalog proposals CATALOG_DIR HASH START END');
      WriteLn(StdErr, '       pythian.label.catalog serve INBOX_DIR CATALOG_DIR PORT [MAX_REQUESTS]');
      WriteLn(StdErr, '       pythian.label.catalog serve INBOX_DIR CATALOG_DIR BIND_IP PORT [MAX_REQUESTS]');
      WriteLn(StdErr, '       pythian.label.catalog serve-app INBOX_DIR CATALOG_DIR WEBROOT PORT [MAX_REQUESTS]');
      WriteLn(StdErr, '       pythian.label.catalog serve-app INBOX_DIR CATALOG_DIR WEBROOT BIND_IP PORT [MAX_REQUESTS]');
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
