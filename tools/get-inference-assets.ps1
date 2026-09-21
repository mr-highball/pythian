<#
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
#>
param(
  [string]$OutputDirectory = 'build/inference-assets',
  [string]$ModelCacheDirectory = '',
  [string]$RuntimeArchive = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build'))
$buildPrefix = $buildDirectory + [IO.Path]::DirectorySeparatorChar
$requestedDirectory = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
  $OutputDirectory
} else {
  Join-Path $projectRoot $OutputDirectory
}
$assetDirectory = [IO.Path]::GetFullPath($requestedDirectory)
if (-not $assetDirectory.StartsWith($buildPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Inference assets must be acquired under the project build directory'
}
$assetLockPath = Join-Path $projectRoot 'adapters/inference/assets.lock.json'
$assetLock = Get-Content -LiteralPath $assetLockPath -Raw | ConvertFrom-Json

function Get-AssetPath([string]$Root, [string]$RelativePath) {
  if ([IO.Path]::IsPathRooted($RelativePath)) { throw 'Asset path must be relative' }
  $resolvedRoot = [IO.Path]::GetFullPath($Root)
  $resolvedAsset = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $RelativePath))
  if (-not $resolvedAsset.StartsWith($resolvedRoot + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw "Asset path leaves its directory: $RelativePath"
  }
  return $resolvedAsset
}

function Assert-Asset([string]$Path, $Entry) {
  $item = Get-Item -LiteralPath $Path -ErrorAction Stop
  if ($item.PSIsContainer -or $item.Length -ne $Entry.bytes) {
    throw "Asset length mismatch: $Path"
  }
  if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Entry.sha256) {
    throw "Asset SHA256 mismatch: $Path"
  }
}

function Assert-InstalledAssets([string]$Root) {
  foreach ($entry in $assetLock.model) {
    Assert-Asset (Get-AssetPath (Join-Path $Root 'model') $entry.file) $entry
  }
  foreach ($entry in $assetLock.runtime) {
    Assert-Asset (Get-AssetPath (Join-Path $Root 'runtime') $entry.file) $entry
  }
}

function Get-PinnedAsset([string]$Destination, $Entry, [string]$CachedPath) {
  New-Item -ItemType Directory -Force (Split-Path -Parent $Destination) | Out-Null
  if ($CachedPath) {
    Assert-Asset $CachedPath $Entry
    Copy-Item -LiteralPath $CachedPath -Destination $Destination
  } else {
    Invoke-WebRequest -Uri $Entry.url -OutFile $Destination -UseBasicParsing
  }
  Assert-Asset $Destination $Entry
}

if (Test-Path -LiteralPath $assetDirectory) {
  Assert-InstalledAssets $assetDirectory
  Write-Output "Pinned inference assets already verified: $assetDirectory"
  return
}

# Stage a new acquisition; never overwrite an existing installation or user cache.
# Failed stages remain under ignored build output for inspection.
$stageDirectory = Join-Path $buildDirectory ('inference-acquire-' + [Guid]::NewGuid().ToString('N'))
$stageDirectory = [IO.Path]::GetFullPath($stageDirectory)
if (-not $stageDirectory.StartsWith($buildPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Acquisition stage leaves the project build directory'
}
New-Item -ItemType Directory -Path $stageDirectory | Out-Null
try {
  foreach ($entry in $assetLock.model) {
    $cachedAsset = ''
    if ($ModelCacheDirectory) {
      $cachedAsset = Get-AssetPath $ModelCacheDirectory $entry.file
    }
    Get-PinnedAsset (Get-AssetPath (Join-Path $stageDirectory 'model') $entry.file) $entry $cachedAsset
  }
  $archivePath = Get-AssetPath $stageDirectory $assetLock.runtime_archive.file
  Get-PinnedAsset $archivePath $assetLock.runtime_archive $RuntimeArchive
  Expand-Archive -LiteralPath $archivePath -DestinationPath (Join-Path $stageDirectory 'runtime')
  Assert-InstalledAssets $stageDirectory
  Copy-Item -LiteralPath $assetLockPath -Destination (Join-Path $stageDirectory 'assets.lock.json')
  New-Item -ItemType Directory -Force (Split-Path -Parent $assetDirectory) | Out-Null
  if (Test-Path -LiteralPath $assetDirectory) { throw 'Asset destination appeared during acquisition' }
  # Both absolute directory paths were checked against buildPrefix before this move.
  [IO.Directory]::Move($stageDirectory, $assetDirectory)
  Write-Output "Pinned inference assets acquired: $assetDirectory"
  Write-Output "Model: $(Join-Path $assetDirectory 'model')"
  Write-Output "Runtime DLL directory: $(Join-Path $assetDirectory 'runtime/lib')"
} catch {
  Write-Warning "Acquisition failed; retained staging files at $stageDirectory"
  throw
}
