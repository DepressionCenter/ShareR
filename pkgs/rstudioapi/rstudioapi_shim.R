# This file is part of ShareR
# pkgs/rstudioapi/R/rstudioapi_shim.R
# Author(s): Gabriel Mongefranco.
# Created: 2026-07-30
# Summary: Pure R WebAssembly surrogate for rstudioapi enabling seamless execution inside webR.
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
# with this program. If not, see https://www.gnu.org/licenses/.

#' Ask for password (WASM surrogate)
#'
#' @param prompt Prompt message string.
#' @return String password or empty string in non-interactive WASM mode.
#' @export
askForPassword <- function(prompt = "Password:") {
  if (interactive()) {
    readline(prompt = paste0(prompt, " "))
  } else {
    ""
  }
}

#' Check if RStudio API is available
#'
#' @return Logical TRUE to allow guard clauses to pass.
#' @export
isAvailable <- function() {
  TRUE
}

#' Get RStudio version
#'
#' @return Version object representing mock RStudio IDE version.
#' @export
getVersion <- function() {
  numeric_version("2026.04.0")
}