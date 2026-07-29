<!--
This file is part of ShareR™
README.md
Author(s): Gabriel Mongefranco.
Created: 2026-07-27
Last Modified: 2026-07-27
Summary: ShareR™ runs R and R Markdown scripts entirely inside a web browser. This file provides an overview of the project, in Markdown format.
Notes: See README file for documentation and full license information.

Copyright © 2026 The Regents of the University of Michigan

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.

-->
![Eisenberg Family Depression Center](https://code.depressioncenter.org/images/EFDCLogo_375w.png "depressioncenter.org")

# ShareR™
### _Share your science. R in the browser, nothing to install._

## Description
ShareR™ runs R and R Markdown scripts entirely inside a web browser. There is no server, no R installation, and no setup. Point it at a GitHub repository, add your own data files, and press Run.

![Preview Image](./images/ShareR-Preview.png "ShareR Preview")

ShareR™ lets you run an R analysis right in your web browser, no installation required. Share a link to your R script or R Markdown file on GitHub, and anyone can open it, add their own data, and run it instantly, even on a locked-down work laptop where they can't install software.

Everything happens on your computer. Your files are never uploaded anywhere, and there's no server behind ShareR that could receive them. When you run an analysis, you'll see the results build in real time: charts, tables, and any files the script creates, all wrapped up into a report you can view right away or download as a package to keep.

For research teams, that means anyone on the project can run the same analysis the same way, without needing R installed or any technical setup, just a link and a browser.


## Quick Start Guide
**Run someone else's analysis**

1. Open ShareR with the repository in the URL:
   `https://code.depressioncenter.org/ShareR/?repo=DepressionCenter/EMA-CleanR`
2. Wait for the one-time download of the R engine and packages. The script will run automatically using the sample data file(s) included in the repository.
3. You can also replace the data files with your own in the Workspace panel, then click the yellow Run button. ShareR will use your files instead of the sample data, and regenerate the report tab.
4. Read the report, then press **Download all outputs** to get a ZIP with the report, the generated files, the console log, and a run manifest.

**Run your own script without a repository**

1. Open `https://code.depressioncenter.org/ShareR/` with no parameters.
2. Drop in your `.R` or `.Rmd` file together with its data files, or drop a whole folder.
3. Press **Run analysis**.

**Run it locally**

1. Clone or download this repository.
2. Run `.\run-windows.ps1` (Windows), `./run-linux.sh` (Linux), or double-click `run-mac.command` (macOS). These wrap the bundled [ZippyServe](https://github.com/DepressionCenter/ZippyServe) binary, so nothing has to be installed.
3. Your browser opens to `http://localhost:8010`.

**Share your script with others**

1. Publish your repository on GitHub, then share the link to ShareR with the `?repo=Owner/RepoName` parameter. For example, `https://code.depressioncenter.org/ShareR/?repo=DepressionCenter/EMA-CleanR` runs the reference workflow in the `DepressionCenter/EMA-CleanR` repository.
2. If your repository contains multiple scripts, ShareR will list them and let the user choose which one to run. If you want to be explicit about which script is the entry point, add a `&script=` parameter to the URL, followed by the path to the script (relative to the repository root). Example: `https://code.depressioncenter.org/ShareR/?repo=DepressionCenter/EMA-CleanR&script=EMA-CleanR.rmd`.
3. If your script references sample data files, and you have those in your repo, it will run with the sample data. You can also specify which data files to use by adding a `&data=` parameter to the URL, followed by a comma-separated list of file names (relative to the repository root). Example: `https://code.depressioncenter.org/ShareR/?repo=DepressionCenter/EMA-CleanR&script=EMA-CleanR.rmd&data=EMA-Data.csv`.
4. Share the link with your colleagues, and they can run the analysis in their own browser, with their own data files, without installing anything!


## Documentation
+ The full documentation is available at: https://michmed.org/efdc-kb
+ Technical specification: [`docs/ShareR-Technical-Specification.md`](docs/ShareR-Technical-Specification.md)


### Setting Up and Using ShareR

#### Putting Up Your Own Copy

1. Fork or copy this repository.
2. In your repository's **Settings > Pages**, choose to publish from the `main` branch, root folder. Make sure **Enforce HTTPS** is turned on.
3. Add your organization's name to `CONFIG.TRUSTED_OWNERS` in `index.html`, so that repositories you publish don't show visitors an "unknown author" warning.
4. That's it. There's no build step, no software to install, nothing to compile. Whatever is in the repository is exactly what gets published.

#### Try It Yourself, with Sample Data

`DepressionCenter/EMA-CleanR` is a ready-made example: an R Markdown workflow that cleans up and charts Ecological Momentary Assessment survey data. It comes with a made-up sample file, `EMA-Data.csv`, so you can try it without using anyone's real data.

1. Open `?repo=DepressionCenter/EMA-CleanR`.
2. ShareR finds the script automatically and lists which R packages it will need.
3. Press Run. You'll see the analysis progress step by step, with a live log.
4. The script creates a folder of results, six summary spreadsheets, and ShareR offers each one for download.
5. Want to use your own data instead? Just drag a file named `EMA-Data.csv` onto the page before you run it, and ShareR will use yours in place of the sample.

#### Keeping Your Results Reproducible

Every time you run an analysis, ShareR saves a small summary file alongside your results. It records exactly what was run: the version of ShareR and of R, which exact version of the script ran, a fingerprint of each input file, which package versions were used, and how long each step took. Keep this file if you plan to report or publish your results, since it is your record of exactly how they were produced.


### What Goes In and What Comes Out

**What you can bring in**

| Source | What it accepts | Notes |
| --- | --- | --- |
| A public GitHub repository | any file in the project | ShareR reads files directly from GitHub. Very large files, over 25 MB, are skipped with a warning. |
| Files from your computer, dragged, dropped, or pasted | any file, including whole folders | Files up to 250 MB each, depending on how much space your browser has available. |

Everything you add is placed into a private workspace inside your browser, in the same folder the script expects, so scripts behave the way they normally would. One thing to note: any dates or times the script generates use your computer's local time zone.

**What you get out**

| Output | Where to find it |
| --- | --- |
| A readable report | Shown right on the page, and available as a standalone file you can save |
| Charts and plots | Shown in the report |
| Any files the script creates | Listed individually, each with its own download button |
| A live log of what happened | Shown on the page as it runs, and available to save afterward |
| A record of exactly how the analysis was run | Saved as a small summary file |
| Everything together | One download containing all of the above |


### Requirements and Configuration

**For users:** a current version of Chrome, Edge, Firefox, or Safari with WebAssembly enabled. Roughly 300 MB of free browser storage for the cached R engine and packages. No account, no login, no API key.

**URL parameters**

| Parameter | Meaning | Default |
| --- | --- | --- |
| `repo` | `Owner/RepoName` of a public GitHub repository | none, which starts ShareR in upload mode |
| `ref` | Branch, tag, or commit SHA. `branch` is accepted as an alias. | the repository's default branch |
| `entry` | Path to the script to run | auto-detected |
| `autorun` | `1` to run automatically once preflight passes | `0` |

**For repository authors:** nothing is required. Optionally, include sample data for your script in your repo (preferably in a `data/` folder). Any files referenced by your script and hosted on the same GitHub repo will be loaded automatically.

**For maintainers:** all configuration lives in a single frozen `CONFIG` object at the top of `index.html`, including the pinned webR version, the package repository URL, size limits, and the trusted-owner allowlist. There are no secrets, no environment variables, and no build step. Editing `WEBR_VERSION` is the only supported way to upgrade the R engine, and doing so automatically invalidates the old cache.



### Privacy, Security, and Accessibility

**Where your data goes:** nowhere but your own computer. Files you open in ShareR are only ever processed inside your browser. They are never uploaded, and there is no server on the other end that could receive them, even if it wanted to. ShareR is built so that it technically cannot send your files out, and it doesn't use analytics or tracking cookies either.

**What ShareR does reach out for:** when you point it at a GitHub repository, it does contact GitHub to fetch that repository's files, which means GitHub can see which project you're running, the same as it would if you visited that page in your browser. ShareR also downloads the R software itself the first time you use it. None of this ever includes your own data. If you'd rather ShareR make no outside requests at all, you can use it with files from your computer once the R software is already cached.

**On compliance:** ShareR hasn't been formally reviewed or certified for any specific type of sensitive or regulated data. Please check with your IRB and with Michigan Medicine Information Assurance before using it with participant data, rather than relying on this page alone.

**A note on running other people's code:** ShareR can open and run any public GitHub repository, not just ones from this Center. The code always runs safely inside your browser and can't reach the rest of your computer, but it can read any file you personally add to the page. If you point ShareR at a repository from an unfamiliar source, it will warn you first and ask you to confirm.

**Accessibility:** ShareR is built to work well with screen readers, keyboard-only navigation, and other assistive technology, aiming to meet the WCAG 2.2 AA accessibility standard.

**A few things ShareR can't do yet:**

+ Because of how it's hosted, a running analysis can't be interrupted partway through. Stopping it restarts the R engine instead. It's clearly labeled as such.
+ ShareR can't produce a PDF or Word document, or recreate a report exactly pixel-for-pixel. It builds an equivalent, readable report instead.
+ A few advanced R Markdown features aren't supported yet.
+ Only R packages that have a browser-compatible version available can be used. If a script needs one that isn't available, ShareR will tell you before running anything.
+ Your browser has a limited amount of memory, so very large datasets combined with many packages may not fit.
+ Private (non-public) GitHub repositories aren't supported directly. Use the drag-and-drop upload option instead. ShareR never asks for, and never stores, any GitHub login or access credentials.


## Additional Resources
+ [Eisenberg Family Depression Center](https://depressioncenter.org)
+ [EFDC open source projects](https://code.depressioncenter.org)
+ [EMA-CleanR](https://github.com/DepressionCenter/EMA-CleanR), the reference workflow
+ [ZippyServe](https://github.com/DepressionCenter/ZippyServe), the bundled local web server
+ [webR documentation](https://docs.r-wasm.org/webr/latest/)



## About the Team
The [Mobile Technologies Core](https://depressioncenter.org/mobiletech) provides investigators across the University of Michigan the support and guidance needed to utilize mobile technologies and digital mental health measures in their studies. Experienced faculty and staff offer hands-on consultative services to researchers throughout the University – regardless of specialty or research focus.

Learn more at: [https://depressioncenter.org/mobiletech](https://depressioncenter.org/mobiletech).




## Contact
To get in touch, contact the individual developers in the check-in history.

If you need assistance identifying a contact person, email the EFDC's Mobile Technologies Core at: efdc-mobiletech@umich.edu.




## Credits
#### Authors:
+ [Gabriel Mongefranco](https://gabriel.mongefranco.com) [(@gabrielmongefranco)](https://github.com/gabrielmongefranco)

#### Contributors:
+ [Eisenberg Family Depression Center](https://depressioncenter.org) [(@DepressionCenter)](https://github.com/DepressionCenter)


#### This work is based in part on the following projects, libraries and/or studies:
+ [webR](https://github.com/r-wasm/webr) - "The statistical language R compiled to WebAssembly via Emscripten, for use in web browsers and Node," by George Stagg and Lionel Henry. Runs the R and R Markdown scripts entirely inside the browser; it is ShareR's execution engine. License: GPL-3.
+ [fflate](https://github.com/101arrowz/fflate) - "High performance (de)compression in an 8kB package." Builds the downloadable ZIP archive of a run's output files, rendered report, execution log, manifest, and source script. License: MIT.
+ [js-yaml](https://github.com/nodeca/js-yaml) - "JavaScript YAML parser and dumper. Very fast." Parses an `.Rmd` file's YAML front matter (title, `params`, output options). License: MIT.
+ [marked](https://github.com/markedjs/marked) - "A markdown parser and compiler. Built for speed." Renders the Markdown prose in `.Rmd` chunks to HTML for the Report tab. License: MIT.
+ [DOMPurify](https://github.com/cure53/DOMPurify) - "A DOM-only, super-fast, uber-tolerant XSS sanitizer for HTML, MathML and SVG." Sanitizes that rendered HTML before it is ever inserted into the page - the app's one deliberate `innerHTML` assignment. License: Apache-2.0 or MPL-2.0 (dual-licensed).
+ [ZippyServe](https://github.com/DepressionCenter/ZippyServe) - A zero-dependency local web server. It lets you test single-page apps quickly. It serves directories, zips, HTML, and Markdown. It powers ShareR's `run-windows.ps1`/`run-linux.sh`/`run-mac.command` scripts so the app can be served locally without installing a full web server. License: GPL-3.0 or later. DOI: [10.5281/zenodo.21613944](https://doi.org/10.5281/zenodo.21613944).

#### Library and Package Repositories
The following public repositories are used to download JavaScript, R and WebAssembly libraries and packages:
+ [jsDelivr](https://www.jsdelivr.com/) - "A free CDN for open source projects." Serves webR and most JavaScript libraries listed previously at pinned versions.
+ [webr.r-wasm.org](https://webr.r-wasm.org/) - Hosts the compiled webR WebAssembly runtime binaries that the browser downloads on first run.
+ [repo.r-wasm.org](https://repo.r-wasm.org/) - "A CRAN-like repository hosted via CDN that provides pre-compiled R packages for WebAssembly." The primary repository webR's `install()` uses to fetch R packages a script requests.
+ [tidyverse.r-universe.dev](https://tidyverse.r-universe.dev/) - An [R-universe](https://github.com/r-universe-org) package-distribution repository, consulted as a fallback source for WebAssembly package binaries not found on repo.r-wasm.org.
+ [fstpackage.r-universe.dev](https://fstpackage.r-universe.dev/) - Another R-universe repository, consulted as the same kind of fallback source.



## License
### Copyright Notice
Copyright © 2026 The Regents of the University of Michigan


### Software and Library License Notice
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.


### Documentation License Notice
Permission is granted to copy, distribute and/or modify this document 
under the terms of the GNU Free Documentation License, Version 1.3 
or any later version published by the Free Software Foundation; 
with no Invariant Sections, no Front-Cover Texts, and no Back-Cover Texts. 
You should have received a copy of the license included in the section entitled "GNU 
Free Documentation License". If not, see <https://www.gnu.org/licenses/fdl-1.3-standalone.html>



## Citation
If you find this repository, code or paper useful for your research, please cite it.

#### Citation Example:
>_Mongefranco, Gabriel (2026). ShareR. University of Michigan. Software. https://github.com/DepressionCenter/ShareR_  
​​​​​​​     _DOI: [Pending](https://doi.org/)_


----

Copyright © 2026 The Regents of the University of Michigan
