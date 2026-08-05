# This file is part of ShareR
# pkgs/XLConnect/R/xlconnect_shim.R
# Author(s): Gabriel Mongefranco.
# Created: 2026-07-30
# Summary: Pure R WebAssembly surrogate for XLConnect delegating excel parsing to readxl.
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

#' Load an Excel workbook (WASM surrogate)
#'
#' @param filename Path to the Excel file.
#' @param create Logical; creation not supported in browser WASM.
#' @param password Optional password string.
#' @return S3 object of class mockWorkbook.
#' @export
loadWorkbook <- function(filename, create = FALSE, password = NULL) {
  ### Validate Inputs ###
  if (missing(filename) || !is.character(filename) || length(filename) == 0) {
    stop("filename parameter must be a non-empty character string.")
  }
  if (!file.exists(filename)) {
    stop(sprintf("File does not exist: %s", filename))
  }
  if (isTRUE(create)) {
    warning("Creating workbooks is not supported in browser WASM mode.")
  }

  structure(
    list(
      filename = filename,
      password = password
    ),
    class = "mockWorkbook"
  )
}

#' Retrieve sheet names from workbook
#'
#' @param object A mockWorkbook object.
#' @return Character vector of sheet names.
#' @export
getSheets <- function(object) {
  ### Validate Inputs ###
  if (!inherits(object, "mockWorkbook")) {
    stop("object must be a mockWorkbook created via loadWorkbook().")
  }
  readxl::excel_sheets(path = object$filename)
}

#' Read data from worksheet
#'
#' @param object A mockWorkbook object.
#' @param sheet Sheet name or index.
#' @param startRow Optional starting row.
#' @param startCol Optional starting column.
#' @param ... Additional arguments passed to readxl::read_excel.
#' @return Data frame containing worksheet contents.
#' @export
readWorksheet <- function(object, sheet, startRow = 1, startCol = 1, ...) {
  ### Validate Inputs ###
  if (!inherits(object, "mockWorkbook")) {
    stop("object must be a mockWorkbook created via loadWorkbook().")
  }
  if (missing(sheet)) {
    stop("sheet parameter is required.")
  }

  res <- readxl::read_excel(
    path = object$filename,
    sheet = sheet,
    skip = max(0, startRow - 1),
    ...
  )
  as.data.frame(res)
}

#' Read worksheet directly from file
#'
#' @param file Path to Excel file.
#' @param sheet Sheet name or index.
#' @param ... Additional arguments passed to readxl::read_excel.
#' @return Data frame containing worksheet contents.
#' @export
readWorksheetFromFile <- function(file, sheet, ...) {
  wb <- loadWorkbook(filename = file)
  readWorksheet(object = wb, sheet = sheet, ...)
}

#' Stub writeWorksheet
#' @export
writeWorksheet <- function(...) {
  warning("writeWorksheet is a no-op in browser WASM mode.")
  invisible(FALSE)
}

#' Stub saveWorkbook
#' @export
saveWorkbook <- function(...) {
  warning("saveWorkbook is a no-op in browser WASM mode.")
  invisible(FALSE)
}