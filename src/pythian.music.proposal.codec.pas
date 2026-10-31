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

unit pythian.music.proposal.codec;

{$mode delphi}
{$H+}

interface

uses pythian.audio, pythian.music.proposal, pythian.progress;

const
  MaximumMusicalProposalBytes = 262144;

type
  TBoundMusicalProposal = record
    SourceSha256: String;
    StartFrame: Int64;
    Grid: TProposedMusicalGrid;
  end;

{ Big Boss: one portable cache/replay contract. Original identity and frame
  offset bind the complete measured/proposed window; the trailing SHA256 covers
  all payload bytes. No source PCM or filesystem lives here. A caller verifies
  original bytes and compares its expected binding before using cached evidence.
  Final callbacks precede managed result publication. }
function EncodeMusicalProposal(const AProposal: TBoundMusicalProposal;
  const AProgress: TWorkProgressCallback = nil): TAudioBytes;
function DecodeMusicalProposal(const ABytes: TAudioBytes;
  const AProgress: TWorkProgressCallback = nil): TBoundMusicalProposal;

implementation

uses Classes, SysUtils, pythian.binary, pythian.hash, pythian.text,
  pythian.time, pythian.chord, pythian.stream.bytes;

const CMagic = $3150474D;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckBinding(const AProposal: TBoundMusicalProposal);
var LHash: TAudioBytes;
begin
  SetLength(LHash, 64);
  WriteSha256Hex(LHash, 0, AProposal.SourceSha256);
  RequireExactTimingCounter(AProposal.StartFrame, 'Musical proposal source offset');
  Need(AProposal.StartFrame <= MaximumTimingInteger - AProposal.Grid.SourceFrames,
    'Bound musical proposal exceeds the portable original clock');
end;

function EncodeMusicalProposal(const AProposal: TBoundMusicalProposal;
  const AProgress: TWorkProgressCallback): TAudioBytes;
var
  LStream: TAudioBytesStream;
  LWord: TAudioBytes;
  LBytes: TAudioBytes;
  LText: TAudioBytes;
  LHash: String;
  I: Integer;
  J: Integer;
  K: Integer;
  procedure Number(const AValue: Integer);
  begin
    WriteInt32LE(LWord, 0, AValue);
    WriteStreamBytesExact(LStream, LWord, 0, 4);
  end;
  procedure Text(const AValue: String; const AMaximum: Integer);
  begin
    LText := EncodeUTF8Text(AValue, AMaximum, False);
    Number(Length(LText));
    WriteStreamBytesExact(LStream, LText, 0, Length(LText));
  end;
begin
  ValidateProposedMusicalGrid(AProposal.Grid, AProgress);
  CheckBinding(AProposal);
  LStream := TAudioBytesStream.Create(MaximumMusicalProposalBytes - 64);
  try
    SetLength(LWord, 4);
    Number(CMagic);
    SetLength(LText, 64);
    WriteSha256Hex(LText, 0, AProposal.SourceSha256);
    WriteStreamBytesExact(LStream, LText, 0, 64);
    SetLength(LText, 8);
    WriteInt64LE(LText, 0, AProposal.StartFrame);
    WriteStreamBytesExact(LStream, LText, 0, 8);
    Number(AProposal.Grid.Version);
    Text(AProposal.Grid.Policy, 256);
    Number(AProposal.Grid.SampleRate);
    Number(AProposal.Grid.SourceFrames);
    Number(AProposal.Grid.TempoMicroseconds);
    Number(Length(AProposal.Grid.RoleNames));
    for I := 0 to High(AProposal.Grid.RoleNames) do
    begin
      Text(AProposal.Grid.RoleNames[I], 128);
      Text(AProposal.Grid.RoleOrigins[I], 512);
    end;
    Number(Ord(AProposal.Grid.HasSound));
    if AProposal.Grid.HasSound then
    begin
      Number(AProposal.Grid.Sound.CutoffHz);
      Number(AProposal.Grid.Sound.SustainPercent);
    end;
    Number(Length(AProposal.Grid.Frames));
    for I := 0 to High(AProposal.Grid.Frames) do
    begin
      ReportWork(AProgress, 'musical_proposal_encode', wuItems, I, Length(AProposal.Grid.Frames));
      Number(Ord(AProposal.Grid.Known[I]));
      Number(Ord(AProposal.Grid.PitchOrigins[I]));
      for J := 0 to 2 do
      begin
        Number(AProposal.Grid.Drums[I][J]);
      end;
      if not AProposal.Grid.Known[I] then Continue;
      for J := 0 to High(AProposal.Grid.Frames[I]) do
      begin
        Number(Ord(AProposal.Grid.Frames[I][J].Action));
        Number(Length(AProposal.Grid.Frames[I][J].Tones));
        for K := 0 to High(AProposal.Grid.Frames[I][J].Tones) do
        begin
          Number(AProposal.Grid.Frames[I][J].Tones[K].Pitch);
          Number(AProposal.Grid.Frames[I][J].Tones[K].Velocity);
        end;
      end;
    end;
    LBytes := LStream.Snapshot;
  finally
    LStream.Free;
  end;
  LHash := Sha256Bytes(LBytes, AProgress);
  SetLength(LBytes, Length(LBytes) + 64);
  WriteSha256Hex(LBytes, Length(LBytes) - 64, LHash);
  ReportWork(AProgress, 'musical_proposal_encode', wuItems,
    Length(AProposal.Grid.Frames), Length(AProposal.Grid.Frames));
  Result := LBytes;
end;

function DecodeMusicalProposal(const ABytes: TAudioBytes;
  const AProgress: TWorkProgressCallback): TBoundMusicalProposal;
var
  LResult: TBoundMusicalProposal;
  LPayload: TAudioBytes;
  LAt: Integer;
  LLength: Integer;
  LRoles: Integer;
  LCells: Integer;
  LTones: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
  function Number(const AMinimum, AMaximum: Integer): Integer;
  begin
    Need(LAt <= Length(LPayload) - 4, 'Truncated musical proposal');
    Result := ReadInt32LE(LPayload, LAt);
    Inc(LAt, 4);
    Need((Result >= AMinimum) and (Result <= AMaximum), 'Musical proposal field is out of range');
  end;
  function Text(const AMaximum: Integer): String;
  var LCount: Integer;
  begin
    LCount := Number(1, AMaximum);
    Need(LCount <= Length(LPayload) - LAt, 'Truncated musical proposal text');
    Result := DecodeUTF8Text(Copy(LPayload, LAt, LCount), AMaximum, False);
    Inc(LAt, LCount);
  end;
begin
  Need((Length(ABytes) > 64) and (Length(ABytes) <= MaximumMusicalProposalBytes),
    'Musical proposal bytes exceed their bounded format');
  LLength := Length(ABytes) - 64;
  LPayload := Copy(ABytes, 0, LLength);
  Need(Sha256HexMatches(ABytes, LLength, Sha256Bytes(LPayload, AProgress)),
    'Musical proposal checksum differs');
  LAt := 0;
  Number(CMagic, CMagic);
  Need(Length(LPayload) - LAt >= 72, 'Truncated source-bound musical proposal');
  LResult := Default(TBoundMusicalProposal);
  LResult.SourceSha256 := DecodeUTF8Text(Copy(LPayload, LAt, 64), 64, False);
  Inc(LAt, 64);
  LResult.StartFrame := ReadInt64LE(LPayload, LAt);
  Inc(LAt, 8);
  LResult.Grid.Version := Number(MusicalProposalVersion, MusicalProposalVersion);
  LResult.Grid.Policy := Text(256);
  LResult.Grid.SampleRate := Number(8000, 192000);
  LResult.Grid.SourceFrames := Number(1, 2000000);
  LResult.Grid.TempoMicroseconds := Number(250000, 1500000);
  LRoles := Number(1, 6);
  SetLength(LResult.Grid.RoleNames, LRoles);
  SetLength(LResult.Grid.RoleOrigins, LRoles);
  for I := 0 to LRoles - 1 do
  begin
    LResult.Grid.RoleNames[I] := Text(128);
    LResult.Grid.RoleOrigins[I] := Text(512);
  end;
  LResult.Grid.HasSound := Number(0, 1) = 1;
  if LResult.Grid.HasSound then
  begin
    LResult.Grid.Sound.CutoffHz := Number(100, 10000);
    LResult.Grid.Sound.SustainPercent := Number(0, 100);
  end;
  LCells := Number(1, 256);
  SetLength(LResult.Grid.Frames, LCells);
  SetLength(LResult.Grid.Known, LCells);
  SetLength(LResult.Grid.PitchOrigins, LCells);
  SetLength(LResult.Grid.Drums, LCells);
  for I := 0 to LCells - 1 do
  begin
    ReportWork(AProgress, 'musical_proposal_decode', wuItems, I, LCells);
    LResult.Grid.Known[I] := Number(0, 1) = 1;
    LResult.Grid.PitchOrigins[I] := TMusicalProposalPitchOrigin(Number(0, 3));
    for J := 0 to 2 do
    begin
      LResult.Grid.Drums[I][J] := Number(0, 127);
    end;
    if not LResult.Grid.Known[I] then Continue;
    SetLength(LResult.Grid.Frames[I], LRoles);
    for J := 0 to LRoles - 1 do
    begin
      LResult.Grid.Frames[I][J].Action := TChordAction(Number(0, 2));
      LTones := Number(0, 12);
      SetLength(LResult.Grid.Frames[I][J].Tones, LTones);
      for K := 0 to LTones - 1 do
      begin
        LResult.Grid.Frames[I][J].Tones[K].Pitch := Number(0, 127);
        LResult.Grid.Frames[I][J].Tones[K].Velocity := Number(1, 127);
      end;
    end;
  end;
  Need(LAt = Length(LPayload), 'Trailing musical proposal payload');
  ValidateProposedMusicalGrid(LResult.Grid, AProgress);
  CheckBinding(LResult);
  ReportWork(AProgress, 'musical_proposal_decode', wuItems, LCells, LCells);
  Result := LResult;
end;

end.
