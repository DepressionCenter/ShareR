<!--
This file is part of ShareR
walkthrough.md
Author(s): ub3dqy (AI-assisted contribution).
Created: 2026-10-23
Summary: A first ShareR run using invented plant measurements and base R only.
Notes: See the repository README for full license information.

Copyright © 2026 The Regents of the University of Michigan

GNU Free Documentation License version 1.3 or later, with no Invariant Sections,
no Front-Cover Texts, and no Back-Cover Texts:
https://www.gnu.org/licenses/fdl-1.3-standalone.html
-->

# Your first ShareR run: invented plant growth

Load two files, run a short R script, inspect one chart, and download one summary
table. Every measurement in this example is invented. These are not research
observations or advice about growing plants.

## Before you start

Use a current browser with WebAssembly enabled and an Internet connection for
ShareR's initial R-engine download. You do not need an account, an R installation,
or extra R packages. The script uses only R's built-in functions.

1. Download [plant-growth.R](https://raw.githubusercontent.com/DepressionCenter/ShareR/refs/heads/main/examples/plant-growth/plant-growth.R) and
   [plant-growth.csv](https://raw.githubusercontent.com/DepressionCenter/ShareR/refs/heads/main/examples/plant-growth/plant-growth.csv).
   These links open the files directly. If your browser displays the text, use
   **Save Page As** to save each file. Keep both names unchanged, including the
   `.R` and `.csv` extensions.
2. Open [ShareR without URL parameters](https://code.depressioncenter.org/ShareR/).
   The Report tab should show **Start a ShareR workspace** and the Files area
   should say **Drop files or folders here**. For this first run, use an empty
   workspace so older scripts or results cannot be confused with this example.

## Add the files and run

1. Click **Choose files** in the empty workspace. Select **both** downloaded
   files together and open them. You can also drag both files into that area.
   Select the files themselves, rather than **Choose folder**, so they appear
   directly in the workspace root.
2. Check the Files area for `plant-growth.R` and `plant-growth.csv`. Select
   `plant-growth.R` if it is not already the active script. **Current Script
   Inputs** should identify `plant-growth.csv`.
3. Click the yellow **Run** button if the example has not already started.
   Wait for the first R-engine download to finish. Later runs can use the
   browser's cached engine.
4. Open **Report** to see the printed summary and chart. **Plots** also shows
   the chart, and **Files** lists the generated summary CSV.

The script reads `plant-growth.csv` from the workspace root. No path editing is
needed. If the script reports that file is missing, check the spelling and make
sure the two files are at the same top level of the workspace.

## Check the expected results

The input contains four observations:

| Day | Height (cm) |
| --- | --- |
| 0 | 2 |
| 7 | 4 |
| 14 | 7 |
| 21 | 11 |

The chart is titled **Invented plant growth**. Its horizontal axis is **Day**,
its vertical axis is **Height (cm)**, and four dots joined by lines pass through
the pairs in the table. You should see one chart.

`plant-growth-summary.csv` contains a header row and one result row:

| Column | Expected value |
| --- | --- |
| `observation_count` | 4 |
| `first_day` | 0 |
| `last_day` | 21 |
| `initial_height_cm` | 2 |
| `final_height_cm` | 11 |
| `total_growth_cm` | 9 |

The growth is `11 - 2 = 9` centimetres. It is a simple difference between the
last and first invented measurements, not a prediction or statistical test.

## Download and rerun

1. Use the **Download** menu and **Download all (.zip)** to save the run's
   results together. The archive also includes the source script, console log,
   and run manifest.
2. To save only the table, open **Files** and use the download action for
   `plant-growth-summary.csv`. To save only the chart, use its PNG download
   button in **Plots**.
3. To save the script, select `plant-growth.R` and click **Download script**
   above the Workspace editor. The example download link above also remains
   available.
4. Click **Run** again to repeat the calculation. With the unchanged input,
   the values and four plotted points should be the same.

## Data and privacy

`day` is elapsed days and `height_cm` is height in centimetres. The CSV uses
commas as separators and has no names, dates, identifiers, or participant data.
The script checks for its two required columns, at least two rows, unique days,
and finite, non-negative numbers before calculating. It preserves the supplied
CSV and writes the summary to a separate file.

Use these invented values for learning. See the repository's
[privacy, security, and accessibility guidance](../../README.md#privacy-security-and-accessibility)
before considering any confidential data.
