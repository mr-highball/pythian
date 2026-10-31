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
program pythian_tests_music_decisions;

{$mode delphi}
{$H+}

uses SysUtils, Classes, pythian.audio, pythian.chord, pythian.text,
  pythian.progress, pythian.hash, pythian.binary, pythian.time, pythian.stream.bytes,
  pythian.music.decisions, pythian.music.replay;

type
  TObserver = class
    CancelStage: String;
    Reader: TMusicDecisionReader;
    ReentryRejected: Boolean;
    procedure Observe(const AWork: TWorkProgress);
  end;
var Checks: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not AValue then raise Exception.Create(AMessage);
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var LChunk: TMusicDecisionChunk;
begin
  if (Reader <> nil) and not ReentryRejected then
  begin
    try Reader.TryNext(LChunk);
    except on EAudio do ReentryRejected := True; end;
  end;
  if AWork.Stage = CancelStage then raise EAudio.Create('Deliberate cancellation');
end;

function Chunk: TMusicDecisionChunk;
var LChunk: TMusicDecisionChunk; I: Integer;
begin
  LChunk := Default(TMusicDecisionChunk);
  LChunk.Version := MusicDecisionVersion;
  SetLength(LChunk.Previous, 1);
  LChunk.Previous[0] := Default(TChordVoice);
  SetLength(LChunk.Cells, 2);
  for I := 0 to 1 do
  begin
    LChunk.Cells[I].FrameCount := 2000 + I;
    SetLength(LChunk.Cells[I].Parts, 1);
    LChunk.Cells[I].Parts[0] := Default(TChordVoice);
    if I = 0 then LChunk.Cells[I].Parts[0].Action := caAttack
    else LChunk.Cells[I].Parts[0].Action := caHold;
    SetLength(LChunk.Cells[I].Parts[0].Tones, 1);
    LChunk.Cells[I].Parts[0].Tones[0].Pitch := 60;
    LChunk.Cells[I].Parts[0].Tones[0].Velocity := 83;
  end;
  SetLength(LChunk.Providers, 1);
  LChunk.Providers[0].Key := ScalarText($1F3B5);
  SetLength(LChunk.Providers[0].Tokens, 2);
  SetLength(LChunk.Providers[0].States, 2);
  LChunk.Providers[0].Tokens[0] := 'attack:60:83';
  LChunk.Providers[0].Tokens[1] := 'hold:60:83';
  LChunk.Providers[0].States[0] := 7;
  LChunk.Providers[0].States[1] := 11;
  Result := LChunk;
end;

procedure RejectChunk(const AChunk: TMusicDecisionChunk);
var LRejected: Boolean;
begin
  LRejected := False;
  try ValidateMusicDecisionChunk(AChunk);
  except on EAudio do LRejected := True; end;
  Check(LRejected, 'Malformed musical decisions reject');
end;

procedure Run;
var
  A, B, C: TMusicDecisionChunk;
  LBytes, LBad, LExpected: TAudioBytes;
  LStorage, LTiny: TAudioBytesStream;
  LWriter, LFailed: TMusicDecisionWriter;
  LReader: TMusicDecisionReader;
  LObserver: TObserver;
  LRejected: Boolean;
  LHash: String;
  I: Integer;
begin
  A := Chunk;
  ValidateMusicDecisionChunk(A);
  LBytes := EncodeMusicDecisions(A);
  B := DecodeMusicDecisions(LBytes);
  Check((B.Version = 1) and (B.Cells[1].Parts[0].Action = caHold) and
    (B.Cells[1].Parts[0].Tones[0].Velocity = 83) and
    (B.Providers[0].States[1] = 11) and
    (B.Providers[0].Key = A.Providers[0].Key), 'Clocks, Unicode, actions and latent states roundtrip');
  Check(MusicDecisionFrameCount(B) = 4001, 'Exact cell frame counts survive');
  LExpected := EncodeMusicDecisions(B);
  Check(Sha256Bytes(LBytes) = Sha256Bytes(LExpected), 'Canonical byte replay');
  WriteLn('Canonical decision digest: ', Sha256Bytes(LBytes));
  B := CopyMusicDecisionChunk(A);
  B.Previous[0].Action := caAttack;
  B.Cells[0].Parts[0].Tones[0].Pitch := 72;
  B.Providers[0].Tokens[0] := 'other';
  B.Providers[0].States[0] := 99;
  Check((A.Previous[0].Action = caRest) and
    (A.Cells[0].Parts[0].Tones[0].Pitch = 60) and
    (A.Providers[0].Tokens[0] = 'attack:60:83') and
    (A.Providers[0].States[0] = 7), 'Nested chunk copies are detached');
  B := CopyMusicDecisionChunk(A);
  B.Cells[1].Parts[0].Tones[0].Pitch := 61;
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  B.Cells[0].FrameCount := 0;
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  B.Cells[0].FrameCount := -1;
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  B.StartFrame := 1;
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  B.Providers[0].States[0] := -1;
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  SetLength(B.Cells, MaximumMusicDecisionCells + 1);
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  SetLength(B.Providers, MaximumMusicDecisionProviders + 1);
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  SetLength(B.Providers, 2);
  B.Providers[1] := B.Providers[0];
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  B.Previous[0] := B.Cells[0].Parts[0];
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  SetLength(B.Cells[0].Parts, 2);
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  B.Cells[0].Parts[0].Action := caHold;
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  B.Providers[0].Tokens[0] := StringOfChar('a', 32769);
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  B.FirstCell := -1;
  RejectChunk(B);
  B := CopyMusicDecisionChunk(A);
  B.FirstCell := 1;
  B.StartFrame := MaximumTimingInteger - 1;
  RejectChunk(B);
  for I := 0 to 2 do
  begin
    LBad := Copy(LBytes);
    case I of
      0: LBad[0] := LBad[0] xor 1;
      1: SetLength(LBad, Length(LBad) - 1);
      2: begin SetLength(LBad, Length(LBad) + 1); LBad[High(LBad)] := 0 end;
    end;
    LRejected := False;
    try B := DecodeMusicDecisions(LBad);
    except on EAudio do LRejected := True; end;
    Check(LRejected, 'Corruption, truncation and trailing bytes reject');
  end;
  LBad := Copy(LBytes, 0, Length(LBytes) - 64);
  WriteInt32LE(LBad, 4, 2);
  LHash := Sha256Bytes(LBad);
  SetLength(LBad, Length(LBad) + 64);
  WriteSha256Hex(LBad, Length(LBad) - 64, LHash);
  LRejected := False;
  try B := DecodeMusicDecisions(LBad);
  except on EAudio do LRejected := True; end;
  Check(LRejected, 'A checksum-valid unsupported version still rejects');
  LObserver := TObserver.Create;
  LStorage := TAudioBytesStream.Create(1048576);
  LWriter := TMusicDecisionWriter.Create(LStorage);
  LReader := nil;
  try
    LObserver.CancelStage := 'music_decision_decode';
    B := Default(TMusicDecisionChunk);
    B.Version := 99;
    LRejected := False;
    try B := DecodeMusicDecisions(LBytes, LObserver.Observe);
    except on EAudio do LRejected := True; end;
    Check(LRejected and (B.Version = 99), 'Final decode cancellation preserves the caller');
    LObserver.CancelStage := '';
    LWriter.Append(A);
    C := CopyMusicDecisionChunk(A);
    C.FirstCell := 2;
    C.StartFrame := 4001;
    C.Previous := CopyChordFrame(A.Cells[1].Parts);
    C.Cells[0].Parts[0].Action := caHold;
    LWriter.Append(C);
    Check((LWriter.CellCount = 4) and (LWriter.FrameCount = 8002), 'Sequential journal clocks accumulate');
    B := CopyMusicDecisionChunk(C);
    B.FirstCell := 4;
    B.StartFrame := 8003;
    LRejected := False;
    try LWriter.Append(B);
    except on EAudio do LRejected := True; end;
    Check(LRejected and (LWriter.CellCount = 4), 'Clock gaps reject before writing');
    LHash := LWriter.Seal;
    LExpected := LStorage.Snapshot;
    Check((LWriter.ByteCount = Length(LExpected)) and
      (LHash = Sha256Bytes(LExpected)), 'Completed digest binds every framed byte');
    LRejected := False;
    try LWriter.Append(C);
    except on EAudio do LRejected := True; end;
    Check(LRejected, 'Sealed journals cannot change');
    LStorage.Position := 0;
    LReader := TMusicDecisionReader.Create(LStorage);
    LObserver.Reader := LReader;
    Check(LReader.TryNext(B, LObserver.Observe) and LObserver.ReentryRejected,
      'Reader guards observer reentry while publishing one chunk');
    LObserver.Reader := nil;
    Check(LReader.TryNext(B) and (B.FirstCell = 2) and
      (B.Previous[0].Action = caHold), 'Continued holds retain their original predecessor');
    Check(not LReader.TryNext(B) and LReader.AtEnd and
      (LReader.FrameCount = 8002), 'Journal ends on an exact frame/cell boundary');
    FreeAndNil(LReader);
    LStorage.Position := 0;
    LReader := TMusicDecisionReader.Create(LStorage);
    LObserver.CancelStage := 'music_decision_read';
    B.Version := 99;
    LRejected := False;
    try LReader.TryNext(B, LObserver.Observe);
    except on EAudio do LRejected := True; end;
    Check(LRejected and (LReader.CellCount = 0) and (B.Version = 99),
      'Cancelled journal publication preserves cursor and caller value');
    LRejected := False;
    try LReader.TryNext(B);
    except on EAudio do LRejected := True; end;
    Check(LRejected, 'A failed journal reader cannot silently resume after consuming bytes');
  finally
    LReader.Free;
    LWriter.Free;
    LStorage.Free;
    LObserver.Free;
  end;
  LTiny := TAudioBytesStream.Create(4);
  LFailed := TMusicDecisionWriter.Create(LTiny);
  LReader := nil;
  try
    LRejected := False;
    try LFailed.Append(A);
    except on EAudio do LRejected := True; end;
    Check(LRejected and (LTiny.Size = 4) and (LFailed.CellCount = 0),
      'A failed bounded sink may retain a partial record but no accepted cursor');
    LRejected := False;
    try LFailed.Seal;
    except on EAudio do LRejected := True; end;
    Check(LRejected, 'Partial decision writes cannot be sealed as complete');
    LTiny.Position := 0;
    LReader := TMusicDecisionReader.Create(LTiny);
    LRejected := False;
    try LReader.TryNext(B);
    except on EReadError do LRejected := True; end;
    Check(LRejected, 'A truncated framed record never becomes a chunk');
  finally
    LReader.Free;
    LFailed.Free;
    LTiny.Free;
  end;
  WriteLn('PASS music decisions: ', Checks, ' checks');
end;

begin
  Run;
end.
