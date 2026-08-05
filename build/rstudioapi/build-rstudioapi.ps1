# This file is part of ShareR
# build/rstudioapi/build-rstudioapi.ps1
# Author(s): Gabriel Mongefranco.
# Created: 2026-07-30
# Summary: Compiles the rstudioapi WASM surrogate R package into webR repository format.
# Notes: See README file for documentation and full license information.
#
# Copyright © 2026 The Regents of the University of Michigan
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along
# with this program. If not, see https://www.gnu.org/licenses.

param(
    [string]$OutputDir
)

if (-not $OutputDir) {
    Write-Error "Error: OutputDir parameter is required."
    exit 1
}

$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)

$PkgPath = Join-Path $PSScriptRoot "../../pkgs/rstudioapi"
if (-not (Test-Path $PkgPath)) {
    $PkgPath = Join-Path $PSScriptRoot "rstudioapi"
}

if (-not (Test-Path $PkgPath)) {
    Write-Error "Error: Package source directory not found at $PkgPath"
    exit 1
}

$PkgPath = [System.IO.Path]::GetFullPath($PkgPath)

Write-Host "==> Building rstudioapi WASM surrogate package from $PkgPath..." -ForegroundColor Green

$BashScript = @'
set -e
echo '=> Installing required system tools...'
apt-get update && apt-get install -y git sed make dos2unix

echo '=> Staging rstudioapi source files...'
mkdir -p /work/rstudioapi
cp -r /pkg_source/. /work/rstudioapi/

echo '=> Normalizing Windows CRLF line endings to Linux LF...'
find /work/rstudioapi -type f -exec dos2unix -q {} +

echo '=> Building source tarball via R CMD build...'
cd /work
R CMD build rstudioapi

echo '=> Building WASM surrogate from tarball...'
Rscript -e "
  options(warn = 2)
  tarball <- Sys.glob('rstudioapi_*.tar.gz')
  if (length(tarball) == 0) stop('Source tarball not found! R CMD build likely failed.')
  cat('Found tarball:', tarball, '\n')
  rwasm::add_pkg(paste0('local::', tarball))
"

echo '=> Copying built repository to staging area...'
cp -r /work/repo/* /output/
echo '=> Build complete for rstudioapi!'
'@

# Convert CRLF to LF for bash compatibility in Docker
$BashScript = $BashScript.Replace("`r`n", "`n")

$BashScript | docker run -i --rm -v "${OutputDir}:/output" -v "${PkgPath}:/pkg_source" ghcr.io/r-wasm/webr:main /bin/bash