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
program StudioNativePaths;
{$mode delphi}{$H+}

uses Classes, SysUtils, fpjson, pythian.audio, pythian.text, pythian.hash,
  pythian.tools.files, pythian.tools.path, pythian.tools.json, pythian.tools.studio.jobs
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

var
  LRoot: String;
  LDirectory: String;
  LPath: String;
  LUnicode: TScalarText;
  LRawLeaf: RawByteString;
  LSmall: TAudioBytes;
  LLarge: TAudioBytes;
  LRead: TAudioBytes;
  LFile: TFileStream;
  LJSON: TJSONObject;
  LLoaded: TJSONObject;
  LRejected: Boolean;
  I: Integer;
  LChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(LChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

begin
  try
    Check(ParamCount = 1, 'Usage: native paths FRESH_ROOT');
    LRoot := ExpandFileName(ParamStr(1));
    Check(not DirectoryExists(NativeFilePath(LRoot)), 'Native path fixture root must be fresh');
    LDirectory := LRoot + PathDelim + StringOfChar('d', 120) +
      PathDelim + StringOfChar('e', 120);
    LUnicode := DecodeUTF8Text([$E2, $99, $AB], 3, False);
    { Logical filenames carry UTF-8 bytes. Avoid an implicit conversion to the
      native String code page while constructing the fixture input. }
    LRawLeaf := LUnicode;
    SetCodePage(LRawLeaf, 0, False);
    LPath := LDirectory + PathDelim + LRawLeaf + '.checkpoint';
    Check(Length(LPath) > 300, 'Native path fixture must exceed the legacy Windows limit');
    LSmall := [1, 2, 3];
    WriteStudioBinaryNew(LPath, LSmall);
    {$IFDEF MSWINDOWS}
    Check(GetFileAttributesW(PWideChar(UnicodeString('\\?\') + UTF8Decode(LPath))) <>
      INVALID_FILE_ATTRIBUTES, 'Native file boundary changes the actual Unicode filename');
    {$ENDIF}
    LRead := ReadFileBytes(LPath, 3);
    Check(Sha256Bytes(LRead) = Sha256Bytes(LSmall), 'Long Unicode native path changes content');
    LRejected := False;
    try
      WriteStudioBinaryNew(LPath, [9]);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected, 'Nonreplace publication overwrites an accepted long-path record');
    SetLength(LLarge, 1048577);
    for I := 0 to High(LLarge) do LLarge[I] := I mod 251;
    LRejected := False;
    try
      ReplaceStudioBinary(LPath, LLarge);
    except
      on EAudio do LRejected := True;
    end;
    LRead := ReadFileBytes(LPath, 3);
    Check(LRejected and (Sha256Bytes(LRead) = Sha256Bytes(LSmall)),
      'Default byte-budget rejection changes an accepted record');
    ReplaceStudioBinary(LPath, LLarge, 2 * 1024 * 1024);
    LFile := OpenStudioReadStream(LPath);
    try
      Check((LFile.Size = Length(LLarge)) and
        (Sha256Stream(LFile, LFile.Size) = Sha256Bytes(LLarge)),
        'Explicit large-artifact publication/read changes bytes');
    finally LFile.Free end;
    LJSON := TJSONObject.Create(['name', NativeJSONText(LUnicode)]);
    LLoaded := nil;
    try
      WriteStudioJSONNew(LDirectory + PathDelim + 'context.json', LJSON);
      LLoaded := ReadStudioJSON(LDirectory + PathDelim + 'context.json');
      Check(LLoaded.Strings['name'] = LJSON.Strings['name'],
        'Long-path JSON changes canonical Unicode scalar meaning');
    finally
      LLoaded.Free;
      LJSON.Free;
    end;
    WriteLn('PASS ', LChecks, ' native long-path/Unicode/atomic budget checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
