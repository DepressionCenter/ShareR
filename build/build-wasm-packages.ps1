# This file is part of ShareR
# build/build-wasm-packages.ps1
# Author(s): Gabriel Mongefranco.
# Created: 2026-07-30
# Summary: Compiles specific R packages into wasm that are not available at the r-wasm CRAN-like repo yet.
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


# Ensure script is running inside '\build'
$ScriptDirName = Split-Path -Leaf $PSScriptRoot
if ($ScriptDirName -ne "build") {
    Write-Error "Error: 'build-wasm-packages.ps1' must reside inside the '\build' directory."
    exit 1
}

# Resolve Paths
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TmpBuildDir = Join-Path $PSScriptRoot "tmp"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Starting WebAssembly Package Orchestrator" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Project Root Target : $ProjectRoot"
Write-Host "Staging Directory   : $TmpBuildDir"
Write-Host "------------------------------------------"

# Check for valid build scripts
$SubDirectories = Get-ChildItem -Path $PSScriptRoot -Directory | Where-Object { $_.Name -ne "tmp" }
$ValidScripts = @()

foreach ($dir in $SubDirectories) {
    $folderName = $dir.Name
    $expectedScriptName = "build-$folderName.ps1"
    $expectedScriptPath = Join-Path $dir.FullName $expectedScriptName

    if (Test-Path -Path $expectedScriptPath -PathType Leaf) {
        $ValidScripts += Get-Item $expectedScriptPath
    }
}

if ($ValidScripts.Count -eq 0) {
    Write-Error "Error: No matching package scripts found in \build subdirectories."
    exit 1
}

# Ensure clean staging directory exists
if (Test-Path $TmpBuildDir) { Remove-Item $TmpBuildDir -Recurse -Force }
New-Item -ItemType Directory -Path $TmpBuildDir | Out-Null

try {
    foreach ($script in $ValidScripts) {
        Write-Host "==========================================" -ForegroundColor Yellow
        Write-Host "Building Package : $($script.Directory.Name)" -ForegroundColor Yellow
        Write-Host "==========================================" -ForegroundColor Yellow

        # Pass the temporary staging folder to child scripts
        & $script.FullName -OutputDir $TmpBuildDir

        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Error "Build failed for package '$($script.Directory.Name)' with exit code $LASTEXITCODE."
            exit $LASTEXITCODE
        }
    }

    # Move the 'bin' folder from staging to Project Root
    $StagedBin = Join-Path $TmpBuildDir "bin"
    if (Test-Path $StagedBin) {
        Write-Host "`n=> Deploying compiled 'bin' repository to project root..." -ForegroundColor Cyan
        Copy-Item -Path $StagedBin -Destination $ProjectRoot -Recurse -Force
    } else {
        Write-Warning "No 'bin' folder was generated during the build process."
    }

} finally {
    # Cleanup: Always remove \build\tmp folder when done
    if (Test-Path $TmpBuildDir) {
        Write-Host "=> Cleaning up temporary build directory ($TmpBuildDir)..." -ForegroundColor DarkGray
        Remove-Item $TmpBuildDir -Recurse -Force
    }
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host " Build Complete! Clean 'bin/' repository ready." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green