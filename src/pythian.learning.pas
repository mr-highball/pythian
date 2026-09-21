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
unit pythian.learning;

{$mode delphi}
{$H+}

interface

uses
  pythian.analysis;

const
  AcousticLearningVersion = 1;
  MaximumAcousticVocabulary = 32;

type
  TAcousticVector = array[0..14] of Double;
  TAcousticVectors = array of TAcousticVector;
  TAcousticIndices = array of Integer;

  { Repeatable immutable vectors in declared source order. Rewind starts the
    same evidence again. Multiplicity is a positive integer observation weight;
    it does not require replaying or retaining repeated input. }
  TAcousticVectorReader = class abstract
  public
    procedure Rewind; virtual; abstract;
    function ReadVector(var AVector: TAcousticVector;
      var AMultiplicity: Integer): Boolean; virtual; abstract;
  end;

  { Deterministic farthest-first initialization and bounded Lloyd iterations.
    Tokens represent joint timbre/harmony/energy frames, not MIDI notes.
    Keep the returned palette with the token sequences; indices are local. }
  TAcousticPalette = class
  strict private
    FCenters: TAcousticVectors;
    function GetCount: Integer;
    procedure TrainReader(const AReader: TAcousticVectorReader; const AMaximumTokens: Integer);
  public
    constructor Create(const AFeatures: TAudioFeatures; const AMaximumTokens: Integer = 16);
    constructor CreateFromCenters(const ACenters: TAcousticVectors);
    constructor CreateFromReader(const AReader: TAcousticVectorReader;
      const AMaximumTokens: Integer = 16);
    function CopyCenters: TAcousticVectors;
    function Encode(const AFeatures: TAudioFeatures): TAcousticIndices;
    function EncodeFeature(const AFeature: TAudioFeature): Integer;
    function FeatureDistance(const AFeature: TAudioFeature; const AToken: Integer): Double;
    { Returns a feature-array index per token, nearest to its center among
      frames assigned to that token. Empty clusters return -1. }
    function RepresentativeFrames(const AFeatures: TAudioFeatures): TAcousticIndices;
    function CenterAt(const AIndex: Integer): TAcousticVector;
    property Count: Integer read GetCount;
  end;

function AcousticVector(const AFeature: TAudioFeature): TAcousticVector;

implementation

uses
  Math,
  pythian.audio;

function AcousticVector(const AFeature: TAudioFeature): TAcousticVector;
var
  LIndex: Integer;
begin
  for LIndex := 0 to 11 do
  begin
    RequireFinite(AFeature.Chroma[LIndex], 'Chroma');
    if (AFeature.Chroma[LIndex] < 0) or (AFeature.Chroma[LIndex] > 1) then
    begin
      raise EAudio.Create('Chroma must be normalized to 0..1');
    end;
    Result[LIndex] := Sqrt(AFeature.Chroma[LIndex]);
  end;
  RequireFinite(AFeature.Rms, 'RMS');
  RequireFinite(AFeature.CentroidHz, 'Centroid');
  RequireFinite(AFeature.Flux, 'Flux');
  if (AFeature.Rms < 0) or (AFeature.CentroidHz < 0) or
    (AFeature.Flux < 0) or (AFeature.Flux > 1.000001) then
  begin
    raise EAudio.Create('Invalid acoustic features');
  end;
  Result[12] := Max(0, Min(1, (20 * Log10(Max(1E-6, AFeature.Rms)) + 60) / 60));
  Result[13] := Min(1, AFeature.CentroidHz / 8000);
  Result[14] := Min(1, AFeature.Flux);
end;

function Distance(const A, B: TAcousticVector): Double;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to High(A) do
  begin
    Result := Result + Sqr(A[LIndex] - B[LIndex]);
  end;
end;

function Closest(const AVector: TAcousticVector; const ACenters: TAcousticVectors;
  out ADistance: Double): Integer;
var
  LIndex: Integer;
  LDistance: Double;
begin
  Result := 0;
  ADistance := MaxDouble;
  for LIndex := 0 to High(ACenters) do
  begin
    LDistance := Distance(AVector, ACenters[LIndex]);
    if LDistance < ADistance then
    begin
      ADistance := LDistance;
      Result := LIndex;
    end;
  end;
end;

type
  TArrayVectorReader = class(TAcousticVectorReader)
  private
    FVectors: TAcousticVectors;
    FIndex: Integer;
  public
    constructor Create(const AFeatures: TAudioFeatures);
    procedure Rewind; override;
    function ReadVector(var AVector: TAcousticVector;
      var AMultiplicity: Integer): Boolean; override;
  end;

constructor TArrayVectorReader.Create(const AFeatures: TAudioFeatures);
var
  LIndex: Integer;
begin
  inherited Create;
  SetLength(FVectors, Length(AFeatures));
  for LIndex := 0 to High(AFeatures) do
  begin
    FVectors[LIndex] := AcousticVector(AFeatures[LIndex]);
  end;
end;

procedure TArrayVectorReader.Rewind;
begin
  FIndex := 0;
end;

function TArrayVectorReader.ReadVector(var AVector: TAcousticVector;
  var AMultiplicity: Integer): Boolean;
begin
  Result := FIndex < Length(FVectors);
  if Result then
  begin
    AVector := FVectors[FIndex];
    AMultiplicity := 1;
    Inc(FIndex);
  end;
end;

constructor TAcousticPalette.Create(const AFeatures: TAudioFeatures;
  const AMaximumTokens: Integer);
var
  LReader: TArrayVectorReader;
begin
  inherited Create;
  if (Length(AFeatures) = 0) or (Length(AFeatures) > MaximumAnalysisFrames) or
    (AMaximumTokens < 1) or (AMaximumTokens > MaximumAcousticVocabulary) then
  begin
    raise EAudio.Create('Invalid acoustic corpus size');
  end;
  LReader := TArrayVectorReader.Create(AFeatures);
  try
    TrainReader(LReader, AMaximumTokens);
  finally
    LReader.Free;
  end;
end;

constructor TAcousticPalette.CreateFromReader(const AReader: TAcousticVectorReader;
  const AMaximumTokens: Integer);
begin
  inherited Create;
  TrainReader(AReader, AMaximumTokens);
end;

procedure TAcousticPalette.TrainReader(const AReader: TAcousticVectorReader;
  const AMaximumTokens: Integer);
const
  CMaximumExactMass = Int64(9007199254740991);
var
  LSums: TAcousticVectors;
  LCounts: array of Int64;
  LVector: TAcousticVector;
  LBestVector: TAcousticVector;
  LMultiplicity: Integer;
  LComponent: Integer;
  LIteration: Integer;
  LCenter: Integer;
  LDistance: Double;
  LFarthest: Double;
  LFound: Boolean;
  LPassCount: Int64;
  LPassMass: Int64;
  LExpectedCount: Int64;
  LExpectedMass: Int64;

  procedure BeginPass;
  begin
    LPassCount := 0;
    LPassMass := 0;
    AReader.Rewind;
  end;

  function NextVector: Boolean;
  var
    LIndex: Integer;
  begin
    Result := AReader.ReadVector(LVector, LMultiplicity);
    if not Result then
    begin
      Exit;
    end;
    if (LMultiplicity < 1) or (LPassMass > CMaximumExactMass - LMultiplicity) then
    begin
      raise EAudio.Create('Acoustic multiplicity or exact weighted count exceeds its budget');
    end;
    for LIndex := 0 to High(LVector) do
    begin
      RequireFinite(LVector[LIndex], 'Acoustic reader vector');
      if (LVector[LIndex] < 0) or (LVector[LIndex] > 1) then
      begin
        raise EAudio.Create('Acoustic reader components must be in 0..1');
      end;
    end;
    Inc(LPassCount);
    Inc(LPassMass, LMultiplicity);
  end;

  procedure EndPass;
  begin
    if LExpectedCount = 0 then
    begin
      LExpectedCount := LPassCount;
      LExpectedMass := LPassMass;
    end
    else if (LPassCount <> LExpectedCount) or (LPassMass <> LExpectedMass) then
    begin
      raise EAudio.Create('Acoustic evidence count changed between training passes');
    end;
  end;

begin
  if (AReader = nil) or (AMaximumTokens < 1) or
    (AMaximumTokens > MaximumAcousticVocabulary) then
  begin
    raise EAudio.Create('Acoustic reader and valid vocabulary budget are required');
  end;
  LExpectedCount := 0;
  LExpectedMass := 0;
  BeginPass;
  if not NextVector then
  begin
    raise EAudio.Create('Acoustic reader contains no observations');
  end;
  SetLength(FCenters, 1);
  FCenters[0] := LVector;
  while NextVector do
  begin
    { Validate the entire first pass before beginning palette refinement. }
  end;
  EndPass;
  while Length(FCenters) < AMaximumTokens do
  begin
    LFarthest := 0;
    LFound := False;
    BeginPass;
    while NextVector do
    begin
      Closest(LVector, FCenters, LDistance);
      if LDistance > LFarthest then
      begin
        LFarthest := LDistance;
        LBestVector := LVector;
        LFound := True;
      end;
    end;
    EndPass;
    if not LFound or (LFarthest < 1E-12) then
    begin
      Break;
    end;
    SetLength(FCenters, Length(FCenters) + 1);
    FCenters[High(FCenters)] := LBestVector;
  end;
  SetLength(LSums, Length(FCenters));
  SetLength(LCounts, Length(FCenters));
  for LIteration := 1 to 8 do
  begin
    for LCenter := 0 to High(FCenters) do
    begin
      LSums[LCenter] := Default(TAcousticVector);
      LCounts[LCenter] := 0;
    end;
    BeginPass;
    while NextVector do
    begin
      LCenter := Closest(LVector, FCenters, LDistance);
      Inc(LCounts[LCenter], LMultiplicity);
      for LComponent := 0 to High(TAcousticVector) do
      begin
        LSums[LCenter][LComponent] := LSums[LCenter][LComponent] +
          LVector[LComponent] * LMultiplicity;
      end;
    end;
    EndPass;
    for LCenter := 0 to High(FCenters) do
    begin
      if LCounts[LCenter] > 0 then
      begin
        for LComponent := 0 to High(TAcousticVector) do
        begin
          FCenters[LCenter][LComponent] := LSums[LCenter][LComponent] / LCounts[LCenter];
        end;
      end;
    end;
  end;
end;

function TAcousticPalette.GetCount: Integer;
begin
  Result := Length(FCenters);
end;

constructor TAcousticPalette.CreateFromCenters(const ACenters: TAcousticVectors);
var
  LIndex: Integer;
  LComponent: Integer;
begin
  inherited Create;
  if (Length(ACenters) < 1) or (Length(ACenters) > MaximumAcousticVocabulary) then
  begin
    raise EAudio.Create('Invalid persisted palette size');
  end;
  for LIndex := 0 to High(ACenters) do
  begin
    for LComponent := 0 to High(TAcousticVector) do
    begin
      RequireFinite(ACenters[LIndex][LComponent], 'Palette center');
      if (ACenters[LIndex][LComponent] < 0) or (ACenters[LIndex][LComponent] > 1) then
      begin
        raise EAudio.Create('Palette components must be in 0..1');
      end;
    end;
  end;
  FCenters := Copy(ACenters);
end;

function TAcousticPalette.CopyCenters: TAcousticVectors;
begin
  Result := Copy(FCenters);
end;

function TAcousticPalette.CenterAt(const AIndex: Integer): TAcousticVector;
begin
  if (AIndex < 0) or (AIndex >= Count) then
  begin
    raise EAudio.Create('Acoustic center index out of bounds');
  end;
  Result := FCenters[AIndex];
end;

function TAcousticPalette.EncodeFeature(const AFeature: TAudioFeature): Integer;
var
  LDistance: Double;
begin
  Result := Closest(AcousticVector(AFeature), FCenters, LDistance);
end;

function TAcousticPalette.FeatureDistance(const AFeature: TAudioFeature;
  const AToken: Integer): Double;
begin
  Result := Distance(AcousticVector(AFeature), CenterAt(AToken));
end;

function TAcousticPalette.Encode(const AFeatures: TAudioFeatures): TAcousticIndices;
var
  LIndex: Integer;
  LDistance: Double;
begin
  if Length(AFeatures) > MaximumAnalysisFrames then
  begin
    raise EAudio.Create('Acoustic sequence exceeds frame budget');
  end;
  Result := nil;
  SetLength(Result, Length(AFeatures));
  for LIndex := 0 to High(AFeatures) do
  begin
    Result[LIndex] := Closest(AcousticVector(AFeatures[LIndex]), FCenters, LDistance);
  end;
end;

function TAcousticPalette.RepresentativeFrames(
  const AFeatures: TAudioFeatures): TAcousticIndices;
var
  LIndices: TAcousticIndices;
  LDistances: array of Double;
  LIndex: Integer;
  LToken: Integer;
  LDistance: Double;
begin
  LIndices := Encode(AFeatures);
  Result := nil;
  SetLength(Result, Count);
  SetLength(LDistances, Count);
  for LToken := 0 to Count - 1 do
  begin
    Result[LToken] := -1;
    LDistances[LToken] := MaxDouble;
  end;
  for LIndex := 0 to High(AFeatures) do
  begin
    LToken := LIndices[LIndex];
    LDistance := Distance(AcousticVector(AFeatures[LIndex]), FCenters[LToken]);
    if LDistance < LDistances[LToken] then
    begin
      Result[LToken] := LIndex;
      LDistances[LToken] := LDistance;
    end;
  end;
end;

end.
