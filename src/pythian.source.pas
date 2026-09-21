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
unit pythian.source;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  SourceContractVersion = 1;

type
  { Mutable playback instance, owned by its caller. Keep its factory alive.
    Frequency is the played pitch in Hz. Mono returns equal left/right values.
    Exhaustion returns False and zeros; Reset restores initial playback state.
    NoteOff is independent of amplitude release and must be idempotent. }
  TAudioSource = class abstract
  public
    procedure Reset; virtual; abstract;
    procedure NoteOff; virtual;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean;
      virtual; abstract;
  end;

  { Immutable reusable definition. CreateSource returns a distinct caller-owned
    instance. A factory must outlive its instances. Range/cost checks do not
    allocate playback state; cost is conservative scalar work per frame. }
  TAudioSourceFactory = class abstract
  public
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource;
      virtual; abstract;
    procedure ValidateRange(const AMinimumHz, AMaximumHz: Double;
      const ASampleRate: Integer); virtual;
    function FrameCost(const ASampleRate: Integer): Integer; virtual; abstract;
    function Channels: Integer; virtual; abstract;
  end;

implementation

procedure TAudioSource.NoteOff;
begin
end;

procedure TAudioSourceFactory.ValidateRange(const AMinimumHz, AMaximumHz: Double;
  const ASampleRate: Integer);
begin
  ValidateAudioFormat(ASampleRate, Channels);
  RequireFinite(AMinimumHz, 'Minimum source frequency');
  RequireFinite(AMaximumHz, 'Maximum source frequency');
  if (AMinimumHz < 0) or (AMaximumHz < AMinimumHz) or (AMaximumHz >= ASampleRate * 0.5) then
  begin
    raise EAudio.Create('Source frequency range must be nonnegative and below Nyquist');
  end;
end;

end.

