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
unit pythian.tools.json;

{$mode delphi}{$H+}

interface

uses
  fpjson, pythian.text, pythian.progress;

{ Native fpjson bridge only; canonical scalar traversal/decoding is core-owned.
  No host conversion or normalization when crossing the native UTF8String API. }
function NativeJSONText(const AText: TScalarText): TJSONStringType;

{ Keep strict RTL structural/numeric parsing. Primary Pascal decodes quoted
  strings first; ASCII indices pass through the RTL scanner and are restored at
  its key/value extension points. All keys, duplicate checks and values therefore
  use the original decoded scalar bytes without host Unicode conversion.
  Caller byte/depth budgets remain explicit. Callbacks are borrowed, source-byte
  counts are actual, and the tree stays private until the last callback succeeds.
  Numeric syntax/values and object field order remain the RTL parser's policy. }
function ParseNativeJSON(const AText: TScalarText;
  const AMaximumBytes, AMaximumDepth: Integer;
  const AProgress: TWorkProgressCallback = nil;
  const AMaximumContainers: Integer = 0): TJSONData; overload;
{ For readers whose owner already bounds bytes and has no explicit depth cap.
  No guessed depth limit is introduced; strict JSON grammar still applies. }
function ParseNativeJSON(const AText: TScalarText): TJSONData; overload;

implementation

uses
  Classes, SysUtils, jsonparser, jsonscanner, pythian.audio, pythian.json.text;

type
  TScalarStrings = array of TScalarText;
  TScalarJSONParser = class(TJSONParser)
  private
    FStrings: TScalarStrings;
    function Original(const AValue: TJSONStringType): TJSONStringType;
  protected
    procedure StringValue(const AValue: TJSONStringType); override;
    procedure KeyValue(const AValue: TJSONStringType); override;
  public
    constructor Create(const AFrame: RawByteString; const AStrings: TScalarStrings);
  end;
  TJSONPreparation = class
  public
    Callback: TWorkProgressCallback;
    Offset: Integer;
    Total: Integer;
    procedure ObserveString(const AWork: TWorkProgress);
  end;

function NativeJSONText(const AText: TScalarText): TJSONStringType;
begin
  Result := '';
  if Length(AText) > 0 then
  begin
    SetString(Result, PAnsiChar(@AText[1]), Length(AText));
  end;
end;

constructor TScalarJSONParser.Create(const AFrame: RawByteString;
  const AStrings: TScalarStrings);
begin
  inherited Create(AFrame, [joStrict]);
  FStrings := AStrings;
end;

function TScalarJSONParser.Original(const AValue: TJSONStringType): TJSONStringType;
var
  LIndex: Integer;
begin
  if not TryStrToInt(AValue, LIndex) or (LIndex < 0) or (LIndex >= Length(FStrings)) then
  begin
    raise EAudio.Create('Internal JSON scalar token is invalid');
  end;
  Result := NativeJSONText(FStrings[LIndex]);
end;

procedure TScalarJSONParser.StringValue(const AValue: TJSONStringType);
begin
  inherited StringValue(Original(AValue));
end;

procedure TScalarJSONParser.KeyValue(const AValue: TJSONStringType);
begin
  inherited KeyValue(Original(AValue));
end;

procedure TJSONPreparation.ObserveString(const AWork: TWorkProgress);
begin
  ReportWork(Callback, 'native_json_prepare_bytes', wuBytes, Offset + AWork.Done, Total);
end;

function ParseNativeJSON(const AText: TScalarText;
  const AMaximumBytes, AMaximumDepth: Integer;
  const AProgress: TWorkProgressCallback;
  const AMaximumContainers: Integer): TJSONData;
var
  LFrame: TMemoryStream;
  LPrepared: RawByteString;
  LStrings: TScalarStrings;
  LCount: Integer;
  LCapacity: Integer;
  LPosition: Integer;
  LDepth: Integer;
  LContainers: Integer;
  LToken: TScalarText;
  LMarker: String;
  LByte: Char;
  LParser: TScalarJSONParser;
  LData: TJSONData;
  LWork: TJSONPreparation;

  procedure WriteFrame(const ABuffer; const ACount: Integer);
  begin
    { Even the shortest token contains two quotes. Its replacement has at most
      ten index digits and two quotes, so framing uses at most six source bytes
      per input byte. Check the native string ceiling before allocation. }
    if (LFrame.Size + ACount > Int64(Length(AText)) * 6) or
      (LFrame.Size + ACount > High(Integer)) then
    begin
      raise EAudio.Create('Prepared JSON exceeds the native string budget');
    end;
    LFrame.WriteBuffer(ABuffer, ACount);
  end;

begin
  if (AMaximumBytes < 1) or (AMaximumDepth < 0) or (AMaximumContainers < 0) or
    (Length(AText) < 1) or (Length(AText) > AMaximumBytes) then
  begin
    raise EAudio.Create('JSON document exceeds its byte/depth budget or is empty');
  end;
  LFrame := nil;
  LWork := nil;
  LParser := nil;
  LData := nil;
  try
    LFrame := TMemoryStream.Create;
    LWork := TJSONPreparation.Create;
    LWork.Callback := AProgress;
    LWork.Total := Length(AText);
    LCount := 0;
    LCapacity := 0;
    LPosition := 1;
    LDepth := 0;
    LContainers := 0;
    ReportWork(AProgress, 'native_json_prepare_bytes', wuBytes, 0, Length(AText));
    while LPosition <= Length(AText) do
    begin
      if AText[LPosition] = '"' then
      begin
        LWork.Offset := LPosition - 1;
        LToken := ReadJSONString(AText, LPosition, AMaximumBytes, LWork.ObserveString);
        if LCount = LCapacity then
        begin
          if LCapacity = 0 then
          begin
            LCapacity := 16;
          end
          else if LCapacity > High(Integer) div 2 then
          begin
            raise EAudio.Create('JSON string token capacity exceeded');
          end
          else
          begin
            LCapacity := LCapacity * 2;
          end;
          SetLength(LStrings, LCapacity);
        end;
        LStrings[LCount] := LToken;
        LMarker := '"' + IntToStr(LCount) + '"';
        WriteFrame(LMarker[1], Length(LMarker));
        Inc(LCount);
        Continue;
      end;
      LByte := AText[LPosition];
      if (Ord(LByte) > 127) or ((Ord(LByte) < 32) and not (LByte in [#9, #10, #13])) then
      begin
        raise EAudio.Create('JSON syntax outside strings requires ASCII tokens');
      end;
      if LByte in ['{', '['] then
      begin
        Inc(LDepth);
        Inc(LContainers);
        if ((AMaximumDepth > 0) and (LDepth > AMaximumDepth)) or
          ((AMaximumContainers > 0) and (LContainers > AMaximumContainers)) then
        begin
          raise EAudio.Create('JSON nesting budget exceeded');
        end;
      end
      else if LByte in ['}', ']'] then
      begin
        Dec(LDepth);
      end;
      WriteFrame(LByte, 1);
      Inc(LPosition);
      if LPosition mod 4096 = 0 then
      begin
        ReportWork(AProgress, 'native_json_prepare_bytes', wuBytes,
          LPosition - 1, Length(AText));
      end;
    end;
    SetLength(LStrings, LCount);
    if LFrame.Size > High(Integer) then
    begin
      raise EAudio.Create('Prepared JSON exceeds the native string budget');
    end;
    SetString(LPrepared, PAnsiChar(LFrame.Memory), Integer(LFrame.Size));
    ReportWork(AProgress, 'native_json_prepare_bytes', wuBytes, Length(AText), Length(AText));
    ReportWork(AProgress, 'native_json_parse', wuItems, 0, 1);
    LParser := TScalarJSONParser.Create(LPrepared, LStrings);
    LData := LParser.Parse;
    ReportWork(AProgress, 'native_json_parse', wuItems, 1, 1);
    ReportWork(AProgress, 'native_json_ready', wuItems, 1, 1);
    Result := LData;
    LData := nil;
  finally
    LData.Free;
    LParser.Free;
    LWork.Free;
    LFrame.Free;
  end;
end;

function ParseNativeJSON(const AText: TScalarText): TJSONData;
begin
  Result := ParseNativeJSON(AText, Length(AText), 0);
end;

end.
