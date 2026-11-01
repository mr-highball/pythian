# MIT License
#
# Copyright (c) 2026 mr-highball
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

function New-PythianNativeUnitContext([string] $Parent) {
  $path = Join-Path ([IO.Path]::GetFullPath($Parent)) ('unit-contexts-' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $path -ErrorAction Stop | Out-Null
  return $path
}

# Big Boss: positional automatic arguments preserve incoming FPC switches;
# PowerShell parameter abbreviation must not reinterpret flags such as -Co.
# Arguments: compiler executable, fresh invocation root, then native FPC args.
function Invoke-PythianNativeCompile {
  if ($args.Count -lt 3) { throw 'Native compilation needs a compiler, fresh unit root and input' }
  $nativeCompiler = [string]$args[0]
  $invocationRoot = [IO.Path]::GetFullPath([string]$args[1])
  if (-not (Test-Path -LiteralPath $invocationRoot -PathType Container)) {
    throw 'Native unit invocation root does not exist'
  }
  $nativeArguments = @()
  $contextOptions = @()
  $sourceDirectories = @()
  foreach ($argument in $args[2..($args.Count - 1)]) {
    $value = [string]$argument
    # FPC option case matters: -FU is output; -Fu is a source search path.
    if (($value -ceq '-B') -or $value.StartsWith('-FU', [StringComparison]::Ordinal)) { continue }
    $nativeArguments += $value
    if (-not $value.StartsWith('-') -and ([IO.Path]::GetExtension($value) -in @('.lpr', '.pas', '.pp'))) {
      $sourceDirectories += [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($value))
    } elseif (-not $value.StartsWith('-FE', [StringComparison]::Ordinal)) {
      $contextOptions += $value
    }
  }
  if ($sourceDirectories.Count -ne 1) { throw 'Native compilation needs one explicit Pascal input' }
  $compilerFile = Get-Item -LiteralPath $nativeCompiler -ErrorAction Stop
  $identity = [ordered]@{
    compiler = $compilerFile.FullName
    compiler_bytes = $compilerFile.Length
    compiler_modified = $compilerFile.LastWriteTimeUtc.Ticks
    directory = (Get-Location).ProviderPath
    source_directories = $sourceDirectories
    options = $contextOptions
  } | ConvertTo-Json -Depth 5 -Compress
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $digest = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
  $unitDirectory = Join-Path $invocationRoot ('ctx-' + $digest.Substring(0, 20))
  $identityPath = Join-Path $unitDirectory 'options.json'
  if (Test-Path -LiteralPath $unitDirectory) {
    if (-not (Test-Path -LiteralPath $identityPath -PathType Leaf) -or
        ([IO.File]::ReadAllText($identityPath) -cne $identity)) {
      throw 'Native compilation context identity differs; refusing unit reuse'
    }
  } else {
    # Project inputs are source-only. A legacy PPU beside a source would be
    # found before the fresh output context and could carry other defines.
    $sourceRoots = @($sourceDirectories) + @((Get-Location).ProviderPath)
    foreach ($option in $contextOptions) {
      if ($option.StartsWith('-Fu', [StringComparison]::Ordinal)) {
        $sourceRoots += [IO.Path]::GetFullPath($option.Substring(3))
      }
    }
    foreach ($sourceRoot in ($sourceRoots | Select-Object -Unique)) {
      if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
        if (Get-ChildItem -LiteralPath $sourceRoot -Filter '*.ppu' -File -ErrorAction Stop | Select-Object -First 1) {
          throw "Project source scope contains a compiled PPU: $sourceRoot"
        }
      }
    }
    New-Item -ItemType Directory -Path $unitDirectory -ErrorAction Stop | Out-Null
    [IO.File]::WriteAllText($identityPath, $identity)
  }
  $nativeArguments += '-FU' + $unitDirectory
  & $nativeCompiler @nativeArguments
  $nativeExit = $LASTEXITCODE
  $global:LASTEXITCODE = $nativeExit
  if ($nativeExit -ne 0) { throw "Native compilation failed with exit code $nativeExit" }
}
