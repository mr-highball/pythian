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

uses JS, Web, SysUtils;

function AwaitStudioPromise(APromise: TJSPromise; ASeconds: Integer): JSValue; async;

implementation

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
