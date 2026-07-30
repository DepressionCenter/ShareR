# This file is part of ShareR
# build/fst/build-fst.ps1
# Author(s): Gabriel Mongefranco.
# Created: 2026-07-30
# Summary: Compiles the fst/fstcore/fstlib R packages into wasm since they are not available at the r-wasm CRAN-like repo yet.
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

Write-Host "==> Building fst & fstcore WASM packages..." -ForegroundColor Green

$BashScript = @'
set -e
echo '=> Installing required system tools...'
apt-get update && apt-get install -y git sed make

echo '=> Cloning repositories...'
mkdir -p /work && cd /work
git clone --recursive https://github.com/fstpackage/fstlib.git
git clone --recursive https://github.com/fstpackage/fstcore.git
git clone --recursive https://github.com/fstpackage/fst.git

echo '=> Ensuring fstlib source is placed inside fstcore/src/fstlib...'
mkdir -p fstcore/src/fstlib
cp -r fstlib/* fstcore/src/fstlib/

echo '=> Patching Makevars to disable OpenMP and allow duplicate linker symbols...'
for pkg in fstcore fst; do
    if [ -f "$pkg/src/Makevars.in" ]; then
        sed -i 's/\$(SHLIB_OPENMP_CXXFLAGS)//g' "$pkg/src/Makevars.in"
        echo 'PKG_LIBS += -Wl,--allow-multiple-definition' >> "$pkg/src/Makevars.in"
    fi
    if [ -f "$pkg/src/Makevars" ]; then
        sed -i 's/\$(SHLIB_OPENMP_CXXFLAGS)//g' "$pkg/src/Makevars"
        echo 'PKG_LIBS += -Wl,--allow-multiple-definition' >> "$pkg/src/Makevars"
    fi
done

echo '=> Patching C++ code for R 4.5+ compatibility...'
sed -i 's/SET_S4_OBJECT([^)]*);//g' fstcore/src/fst_column.h
echo '#define Rf_NonNullStringMatch(s, c) ((s) != NA_STRING && (s) == (c))' > shim.txt
cat fstcore/src/fst_compress.cpp >> shim.txt
mv shim.txt fstcore/src/fst_compress.cpp

echo '=> Building fstcore for WebAssembly...'
Rscript -e "options(warn = 2); rwasm::add_pkg('/work/fstcore')"

echo '=> Building fst for WebAssembly...'
Rscript -e "options(warn = 2); rwasm::add_pkg('/work/fst')"

echo '=> Copying built repository to staging area...'
cp -r /work/repo/* /output/
echo '=> Build complete for fst/fstcore!'
'@

# Convert CRLF to LF for bash compatibility in Docker
$BashScript = $BashScript.Replace("`r`n", "`n")

$BashScript | docker run -i --rm -v "${OutputDir}:/output" ghcr.io/r-wasm/webr:main /bin/bash