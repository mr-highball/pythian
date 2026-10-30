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
unit pythian.studio.requests;

{$mode delphi}
{$H+}

interface

uses JS, Web, SysUtils, Types;

function AwaitStudioPromise(APromise: TJSPromise; ASeconds: Integer): JSValue; async;
function SameStudioJSON(const ALeft, ARight: JSValue): Boolean;

implementation

function SameStudioJSON(const ALeft, ARight: JSValue): Boolean;
var
  LKeys, RKeys: TStringDynArray;
  LKey: String;
  I: Integer;
begin
  if isArray(ALeft) or isArray(ARight) then
  begin
    if not isArray(ALeft) or not isArray(ARight) then Exit(False);
    if TJSArray(ALeft).length <> TJSArray(ARight).length then Exit(False);
    for I := 0 to TJSArray(ALeft).length - 1 do
      if not SameStudioJSON(TJSArray(ALeft)[I], TJSArray(ARight)[I]) then Exit(False);
    Exit(True);
  end;
  if isObject(ALeft) and (ALeft <> nil) and isObject(ARight) and (ARight <> nil) then
  begin
    LKeys := TJSObject.keys(TJSObject(ALeft));
    RKeys := TJSObject.keys(TJSObject(ARight));
    if Length(LKeys) <> Length(RKeys) then Exit(False);
    for LKey in LKeys do
      if not SameStudioJSON(TJSObject(ALeft)[LKey], TJSObject(ARight)[LKey]) then Exit(False);
    Exit(True);
  end;
  Result := TJSJSON.stringify(ALeft) = TJSJSON.stringify(ARight);
end;

function AwaitStudioPromise(APromise: TJSPromise; ASeconds: Integer): JSValue; async;
var
  LTimer: NativeInt;
  LTimeout: TJSPromise;
begin
  LTimeout := TJSPromise.new(
    procedure(AResolve, AReject: TJSPromiseResolver)
    begin
      LTimer := window.setTimeout(
        procedure()
        begin
          AReject(Exception.Create('Response timed out. Reconnect and retry.'));
        end, ASeconds * 1000);
    end);
  try
    try
      Result := await(JSValue, TJSPromise.race([APromise, LTimeout]));
    except
      on LException: Exception do
      begin
        raise;
      end;
    else
      raise Exception.Create('Connection or browser operation failed. Retry when ready.');
    end;
  finally
    window.clearTimeout(LTimer);
  end;
end;

end.
