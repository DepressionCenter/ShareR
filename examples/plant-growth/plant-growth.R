# This file is part of ShareR
# plant-growth.R
# Author(s): ub3dqy (AI-assisted contribution).
# Created: 2026-10-23
# Summary: Read invented plant measurements, draw one chart, and save a summary.
# Notes: See walkthrough.md and the repository README for documentation and licensing.
#
# Copyright © 2026 The Regents of the University of Michigan
#
# GNU GPL version 3 or later: https://www.gnu.org/licenses/gpl-3.0-standalone.html

### Load and validate the invented measurements ###
# Add both example files to the workspace root so this relative path needs no edits.
if (!file.exists("plant-growth.csv")) {
  stop("Add plant-growth.csv alongside plant-growth.R in the workspace root.")
}
measurements <- read.csv("plant-growth.csv", stringsAsFactors = FALSE)
if (!identical(names(measurements), c("day", "height_cm")) ||
    nrow(measurements) < 2L) {
  stop("Expected day and height_cm columns with at least two measurement rows.")
}
if (!is.numeric(measurements$day) || !is.numeric(measurements$height_cm) ||
    any(!is.finite(measurements$day)) ||
    any(!is.finite(measurements$height_cm)) ||
    any(measurements$day < 0) || any(measurements$height_cm < 0) ||
    anyDuplicated(measurements$day) > 0L) {
  stop("Days must be unique; days and heights must be finite, non-negative numbers.")
}
measurements <- measurements[order(measurements$day), ]

### Draw the chart ###
par(bg = "white")
plot(measurements$day, measurements$height_cm,
     type = "b", pch = 19,
     xlab = "Day", ylab = "Height (cm)",
     main = "Invented plant growth")

### Save one result file ###
first <- 1L
last <- nrow(measurements)
growth_summary <- data.frame(
  observation_count = last,
  first_day = measurements$day[first],
  last_day = measurements$day[last],
  initial_height_cm = measurements$height_cm[first],
  final_height_cm = measurements$height_cm[last],
  total_growth_cm = measurements$height_cm[last] - measurements$height_cm[first]
)
write.csv(growth_summary, "plant-growth-summary.csv", row.names = FALSE)
print(growth_summary)
