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
program pythian_tests_corpus;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.analysis,
  pythian.learning,
  pythian.granular,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.hash,
  pythian.tests.corpus.fixture;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Rehash(var ABytes: TAudioBytes);
var
  LHash: String;
begin
  LHash := Sha256Bytes(Copy(ABytes, 0, Length(ABytes) - 64));
  Move(LHash[1], ABytes[Length(ABytes) - 64], 64);
end;

procedure RejectArchive(const ABytes: TAudioBytes);
var
  LCorpus: TAcousticCorpusData;
  LContract: UTF8String;
  LAttachment: TAudioBytes;
  LRejected: Boolean;
begin
  LRejected := False;
  LContract := 'previous';
  SetLength(LAttachment, 1);
  try
    LCorpus := DecodeAcousticArchive(ABytes, LContract, LAttachment);
    LCorpus.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LContract = '') and (Length(LAttachment) = 0),
    'Invalid archive rejects and clears attachment output');
end;

procedure Run;
var
  LCorpus: TAcousticCorpusData;
  LLoaded: TAcousticCorpusData;
  LSources: TAudioSources;
  LBytes: TAudioBytes;
  LReplay: TAudioBytes;
  LChanged: TAudioBytes;
  LAttachment: TAudioBytes;
  LContract: UTF8String;
  LPalette: TAcousticPalette;
  LCopy: TAcousticVectors;
  LRecords: TAcousticRecordings;
  LTokens: TAcousticIndices;
  LGrains: TAudioGrains;
  LReloadedGrains: TAudioGrains;
  LIndex: Integer;
  LSource: Integer;
  LSeen: array[0..1] of Boolean;
  LRejected: Boolean;
begin
  LCorpus := CreateCorpusFixture(LSources);
  try
    Check((LCorpus.SourceCount = 2) and (LCorpus.FeatureCount = 16),
      'Shared training retains both complete recordings');
    LPalette := LCorpus.CopyPalette;
    try
      LCopy := LPalette.CopyCenters;
      LCopy[0][0] := 0.123456789;
      Check(LPalette.CenterAt(0)[0] <> LCopy[0][0], 'Palette center copy is detached');
    finally
      LPalette.Free;
    end;
    SetLength(LAttachment, 3);
    LAttachment[0] := 1;
    LAttachment[1] := 2;
    LAttachment[2] := 255;
    LBytes := EncodeAcousticArchive(LCorpus, 'fixture.v1', LAttachment);
    Check((LBytes[0] = $50) and (LBytes[1] = $59) and
      (LBytes[4] = 1) and (LBytes[5] = 0) and (LBytes[16] = 64),
      'Independent magic, little-endian version and window offsets');
    LLoaded := DecodeAcousticArchive(LBytes, LContract, LAttachment);
    try
      Check((LContract = 'fixture.v1') and (Length(LAttachment) = 3) and
        (LAttachment[2] = 255), 'Opaque companion attachment preserved');
      LReplay := EncodeAcousticArchive(LLoaded, LContract, LAttachment);
      Check((Length(LBytes) = Length(LReplay)) and
        (CompareByte(LBytes[0], LReplay[0], Length(LBytes)) = 0),
        'Complete archive bytes and binary64 measurements round-trip exactly');
      LSeen[0] := False;
      LSeen[1] := False;
      for LSource := 0 to 1 do
      begin
        LTokens := LCorpus.RecordingAt(LSource).Tokens;
        LGrains := LCorpus.PlanGrains(LTokens);
        LReloadedGrains := LLoaded.PlanGrains(LTokens);
        for LIndex := 0 to High(LGrains) do
        begin
          Check((LGrains[LIndex].SourceIndex = LReloadedGrains[LIndex].SourceIndex) and
            (LGrains[LIndex].SourceStartFrame = LReloadedGrains[LIndex].SourceStartFrame) and
            (LGrains[LIndex].FrameCount = LReloadedGrains[LIndex].FrameCount),
            'Persisted reconstruction keeps source identity and exact frame coordinates');
          LSeen[LGrains[LIndex].SourceIndex] := True;
        end;
      end;
      Check(LSeen[0] and LSeen[1], 'Shared representatives can select both source recordings');
    finally
      LLoaded.Free;
    end;
    for LIndex := 0 to High(LBytes) do
    begin
      RejectArchive(Copy(LBytes, 0, LIndex));
    end;
    LChanged := Copy(LBytes);
    LChanged[100] := LChanged[100] xor 1;
    RejectArchive(LChanged);
    LChanged := Copy(LBytes);
    LChanged[4] := 99;
    Rehash(LChanged);
    RejectArchive(LChanged);
    LChanged := Copy(LBytes);
    LChanged[34] := 255;
    Rehash(LChanged);
    RejectArchive(LChanged);
    LChanged := Copy(LBytes);
    LChanged[42] := $F8;
    LChanged[43] := $7F;
    Rehash(LChanged);
    RejectArchive(LChanged);

    SetLength(LRecords, 2);
    LRecords[0] := LCorpus.RecordingAt(0);
    LRecords[1] := LCorpus.RecordingAt(1);
    Inc(LRecords[0].Features[0].ValidFrames);
    LPalette := LCorpus.CopyPalette;
    try
      LRejected := False;
      try
        LLoaded := TAcousticCorpusData.Create(LCorpus.Options, LPalette.CopyCenters, LRecords);
        LLoaded.Free;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'False persisted source coordinates reject');
      LRecords[0] := LCorpus.RecordingAt(0);
      LRecords[0].Tokens[0] := LCorpus.PaletteCount;
      LRejected := False;
      try
        LLoaded := TAcousticCorpusData.Create(LCorpus.Options, LPalette.CopyCenters, LRecords);
        LLoaded.Free;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Tokens must agree with persisted centers and measurements');
      Check(LCorpus.RecordingAt(0).Tokens[0] <> LCorpus.PaletteCount,
        'Rejected caller mutations preserve corpus');
    finally
      LPalette.Free;
    end;
  finally
    LCorpus.Free;
    ReleaseFixtureSources(LSources);
  end;
end;

begin
  try
    Run;
    WriteLn('Shared corpus, archive integrity and reconstruction checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
