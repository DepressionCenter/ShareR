<!--
This file is part of ShareR
docs/ShareR-Technical-Specification.md
Author(s): Gabriel Mongefranco.
Created: 2026-07-27
Last Modified: 2026-07-27
Summary: Technical specification for ShareR, a fully client-side WebAssembly runner
         for R and R Markdown scripts. Version 1 draft.
Notes: See README file for documentation and full license information.

Copyright (c) 2026 The Regents of the University of Michigan

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.

Permission is granted to copy, distribute and/or modify this document under the
terms of the GNU Free Documentation License, Version 1.3 or any later version
published by the Free Software Foundation. See <https://www.gnu.org/licenses/fdl-1.3.html>.

-->
![Eisenberg Family Depression Center](https://github.com/DepressionCenter/.github/blob/main/images/EFDCLogo_375w.png "depressioncenter.org")

# ShareR: Technical Specification

**Project name:** ShareR
**Slogan:** Share your science. R in the browser, nothing to install.
**Authors:** Gabriel Mongefranco (@gabrielmongefranco), Eisenberg Family Depression Center (@DepressionCenter)
**Reference test case:** `DepressionCenter/EMA-CleanR` (`EMA-CleanR.rmd`)

---

## 0. Prior Art and Scope Justification

Three mature tools already run R in the browser via WebAssembly. This section records why ShareR is built rather than adopting one of them, so that reviewers and future maintainers do not have to reconstruct the reasoning.

| Tool | What it does | Why it does not solve this problem |
| --- | --- | --- |
| **shinylive** (`posit-dev/shinylive`) | Exports a Shiny app to static files that run client-side via webR. | Requires a local R install and a build step (`shinylive::export()`). Requires the analysis to be rewritten as a Shiny app. Does not run an existing `.Rmd`. |
| **quarto-live / quarto-webr** | Embeds runnable R chunks in a rendered Quarto page. | Requires a Quarto build step per document, and the document must be authored for it. Reading a foreign repository at runtime is out of scope. |
| **webR REPL** (`webr.sh`) | Interactive R console in the browser. | No repository sync, no data upload workflow, no report output, no packaging of results. |

**ShareR's distinct claim:** point a URL at an *unmodified* GitHub repository, or at a single `.R`/`.Rmd` file hosted anywhere that allows cross-origin reads, and run it against data files that are either supplied by URL or opened locally by the visitor, with zero build step on either side. Nobody has to install R, Quarto, or Node, and the script author does not have to change a single line of their analysis. Notably, ShareR is and will remain open source under a GPLv3 or later license.

### 0.1 Design principle: keep it simple

**This is the highest-priority instruction in this document. Where any other section conflicts with it, simplicity wins and that section should be corrected.**

Version 1 of this specification over-engineered several areas, and building it that way cost real time without protecting anyone. The corrections are recorded here rather than quietly applied, so the reasoning is not lost and the mistakes are not reintroduced:

- **Do not treat the Content Security Policy as a privacy control.** An earlier draft claimed data locality was "enforced technically by a CSP `connect-src` allowlist, not by convention," and required a strict allowlist plus a SHA-256 hash pinning the inline script. In practice that policy silently broke webR twice, produced an error with no message, and consumed most of a working session. ShareR does not send user data anywhere because *the code does not contain any statement that sends user data anywhere*. That is the actual guarantee and it is a promise about the code, verifiable by reading it. Ship a permissive CSP as ordinary hygiene, not as a security boundary.
- **Prefer the browser's own machinery over hand-built machinery.** Version-pinned engine URLs are immutable, so the ordinary HTTP cache already handles caching correctly; a bespoke service worker with version-keyed buckets is not needed to get that. Similarly, `webR.installPackages()` already resolves dependencies; ShareR does not need to reimplement dependency-closure resolution in JavaScript.
- **Do not build defenses for threats this application does not face.** ShareR is a static page with no server, no accounts, no secrets, and no stored state. Subresource Integrity hashes, trust interstitials, and elaborate manifest bookkeeping add maintenance burden and failure modes disproportionate to that threat model.
- **Write the smallest thing that solves the researcher's problem.** The measure of success is a researcher running their analysis, not the number of controls implemented.

What is genuinely non-negotiable, and must not be simplified away, is short: **accessibility** (WCAG 2.2 AA, per `AGENTS.md` section 9), **not sending user data anywhere**, **sanitizing author-supplied HTML before rendering it** (a real and easily triggered cross-site scripting path, section 8.3), **rejecting path traversal in file paths** (cheap, section 5.2), and **never claiming compliance ShareR does not have** (section 2.3).


---

## 1. Agent Instructions and Repository Setup

**Before writing any code:**

1. Initialize from the `DepressionCenter/EFDC-Repo-Template` repository.
2. Read and strictly follow `AGENTS.md` at the root of that template
   (`https://github.com/DepressionCenter/EFDC-Repo-Template/blob/main/AGENTS.md`).
   Its architectural, stylistic, and structural rules take precedence over this document
   wherever the two conflict, with one exception: where this document states a *factual*
   constraint about webR or browser behavior, the fact wins.
3. Copy `AGENTS.md` forward into the ShareR repository root so future coding agents inherit the rules.

**Style rules stated explicitly because they are easy to violate in a project like this:**

- ASCII only in all source files and comments. No em dashes, no smart quotes, no non-ASCII characters, except Unicode glyphs used deliberately as UI icons.
- Every source file carries the EFDC header block: project, file, authors, created, summary, notes, copyright, license notice.
- Vanilla JavaScript. No framework, no bundler, no transpiler, no `npm install` required to run or to deploy.
- Configuration constants are grouped at the top of `index.html` in a single frozen `CONFIG` object. No magic values scattered through the code.

---

## 2. Overview and Constraints

### 2.1 Goal

A static single-page application that executes R and R Markdown entirely inside the visitor's browser via WebAssembly, so that EFDC researchers and their collaborators can run a shared analysis pipeline against their own data without installing anything.

### 2.2 Hard constraints

- **Data locality.** Files the user supplies never leave the browser. There are no outbound requests carrying user data of any kind: no POST, no PUT, no beacon, no query-string payload, no analytics. This holds because no such code is written: every network request ShareR makes is a GET that *fetches* a script, a data file, or an R package, and none of them carry the contents of anything the user opened. It is a property of the source, and a reviewer can confirm it by searching for `fetch`, `XMLHttpRequest`, and `sendBeacon`. Keep it that way, and keep the request surface small enough that this remains easy to check.
- **Static hosting only.** The deployed artifact is a folder of static files. It works on GitHub Pages, on a file share, or from ZippyServe on a laptop.
- **Zero pre-compilation of user content.** ShareR reads raw `.R` and `.Rmd` text at runtime. There is no per-script build step, no export command, and no manifest the script author has to write.
- **Single-page behavior.** All state transitions (setup, running, results, modals) happen in place through JavaScript. No full page navigation after load.

### 2.3 Privacy language

**Do not label this application "HIPAA compliant."** `AGENTS.md` section 8 forbids claiming compliance on the basis of code review, and the claim is not ours to make. The accurate statement, which should appear verbatim in the README and in the UI, is:

> Files you open in ShareR are processed only in your browser. They are never uploaded, and ShareR has no server that could receive them. ShareR itself has not been reviewed or approved for any specific regulated data type. Confirm with your IRB and with your institution's Cybersecurity or Information Assurance office before using it with participant data.


### 2.4 Reuse

- Reuse structure and CSS from `FieldStationAI`, `MiNap-Go`, `datalavista`, and `Sitenalyzer`. In particular reuse `styles/um-style.css`
- Ship the `run-*` scripts and `bin/` binaries from `DepressionCenter/ZippyServe` for local testing, matching how FieldStationAI does it.

---

## 3. Architecture

### 3.1 Stack

| Layer | Choice | Notes |
| --- | --- | --- |
| UI | Vanilla JS, semantic HTML, `styles/um-style.css` | No framework. |
| R engine | `@r-wasm/webr`, version-pinned | Sections 3.2 and 3.5. |
| R packages | `https://repo.r-wasm.org` binary repository, plus optional additional repositories | Section 9. |
| Filesystem | Emscripten VFS via `webR.FS` | Section 3.3. |
| YAML front matter | `js-yaml` | Needed for `.Rmd` params. Section 8. |
| Markdown rendering | `marked` plus `DOMPurify` | `.Rmd` prose contains author-supplied HTML. Sanitize it. |
| Archiving | `fflate` | Small, fast, streaming, actively maintained. |
| Repository listing | GitHub Git Trees API | One request per run. Section 6. |
| Caching | The browser's ordinary HTTP cache; no service worker | Section 4. |

### 3.2 The communication channel decision

This is the single most consequential constraint in the project and it shapes the Stop button, the progress UI, and the deployment story.

webR runs R in a Web Worker and talks to it over one of two channels:

| Channel | Requirement | Limitation |
| --- | --- | --- |
| `SharedArrayBuffer` (webR default) | Page must be cross-origin isolated, which requires `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` response headers | None |
| `PostMessage` | None | **R code cannot be interrupted.** `readline()`, `menu()`, and `browser()` do not work. |

**GitHub Pages cannot set response headers.** ShareR therefore runs on the `PostMessage` channel. webR selects it automatically when isolation is absent, but ShareR must set it explicitly so behavior is identical on GitHub Pages and on a developer's local server:

```js
const webR = new WebR({
  channelType: ChannelType.PostMessage,
  baseUrl: CONFIG.WEBR_BASE_URL,
  repoUrl: CONFIG.WEBR_REPO_URL,
});
```

The known workaround (`coi-serviceworker`, which synthesizes the COOP and COEP headers from a service worker) is **rejected** for three reasons:

1. Under `require-corp`, every cross-origin subresource must carry a `Cross-Origin-Resource-Policy` header. Neither `webr.r-wasm.org` nor `repo.r-wasm.org` guarantees one, so enabling isolation can break the very downloads it is meant to accelerate.
2. The `credentialless` COEP variant avoids that, but Safari does not support it, so the app would behave differently per browser. Institutionally managed browsers are a hard constraint for this audience.
3. It forces a page reload on first visit, and a service worker is otherwise unnecessary in this design (section 4).

**Consequence, and its mitigation.** Because `webR.interrupt()` does nothing on the `PostMessage` channel, the Stop button cannot interrupt R. Implement Stop as terminate and restart:

```
Stop pressed
  -> await webR.close()            // kills the worker thread
  -> discard the current run state
  -> re-initialise webR lazily on next Run
```

Engine assets are already cached, so the restart costs a WebAssembly instantiation rather than a fresh multi-megabyte download. The user-facing label must be honest: "Stop and reset R", with helper text "Stopping restarts the R engine. Anything already written to the output list is kept; in-memory objects are lost." Do not ship a Stop button that silently does nothing, which is what a naive `interrupt()` call would produce here.

If a future deployment target can set headers, for example an internal U-M web server, `CONFIG.CHANNEL_TYPE = 'auto'` lets it upgrade to `SharedArrayBuffer` and gain real interruption. Detect and display the active channel in the Diagnostics panel.

### 3.3 webR API surface

Verified against `webr@0.6.0` type definitions. Use these names exactly.

- The filesystem object is `webR.FS`, uppercase.
- `WebRFS` provides exactly six methods: `lookupPath`, `mkdir`, `readFile`, `rmdir`, `writeFile`, `unlink`. **There is no `readDir`.** Directory listing is a manual recursive walk: `lookupPath(path)` returns an `FSNode` with `isFolder: boolean` and `contents: { [name]: FSNode }`.
- `writeFile(path, data)` takes an `ArrayBufferView`, normally a `Uint8Array`.
- Plot capture uses `Shelter.captureR(code, { captureGraphics: true })`, which returns `{ result, output, images: ImageBitmap[] }`. Plots come back as `ImageBitmap` objects from webR's `canvas()` device, ready to draw into a `<canvas>`. Files written by explicit `ggsave()` or `png()` calls still appear in the VFS and are caught by the output diff in section 10. Implement both paths.
- Wrap every `webR.FS` call in `try/catch`. Emscripten path routing is strict and throws rather than returning null.

### 3.4 File layout and Content Security Policy

Target layout. Everything is optional except `index.html`, `styles/`, and the license files:

```
ShareR/
  index.html            # the whole application: markup, CONFIG, CSS, and JS
  .nojekyll
  AGENTS.md
  README.md
  LICENSE
  NOTICE
  .gitignore
  styles/
    um-style.css        # shared UM navy and maize styles
  images/
  docs/
    ShareR-Technical-Specification.md
    quick-start.md
  bin/                  # ZippyServe binaries, copied from DepressionCenter/ZippyServe
  run-windows.ps1
  run-linux.sh
  run-mac.command
```

**The Content Security Policy is hygiene, not a security boundary. Keep it permissive.** Per section 0.1, do not use it to enforce data locality; that guarantee comes from the code containing no upload path, not from the browser refusing one. A restrictive policy here has already cost more than it protected.

Ship exactly this as a `<meta http-equiv="Content-Security-Policy">` in `index.html`:

```
default-src 'self';
script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' https:;
worker-src 'self' blob:;
connect-src 'self' https: http://localhost:* http://127.0.0.1:*;
style-src 'self' 'unsafe-inline';
img-src 'self' data: blob: https:;
font-src 'self' data:;
```

Notes, each of which is a fact established by testing rather than a preference:

- **`'unsafe-eval'` is mandatory and is not negotiable.** `'wasm-unsafe-eval'` permits WebAssembly compilation but **not** `eval()`, and Emscripten's `EM_JS` support (`addEmJs()` inside webR's `R.js`) builds JavaScript functions from source strings embedded in the wasm binaries and runs them through a literal `eval()` while loading the side modules `libRblas.so` and `libRlapack.so`. Omit it and R aborts inside `loadDylibs` throwing a bare `WebAssembly.Exception`, which browsers render as `#<Exception>` with **no message, no file, and no line number**. If webR ever fails to start with an unreadable error, check this first.
- **`'unsafe-inline'` in `script-src` is deliberate.** It keeps the application script inline in `index.html` without pinning a SHA-256 hash that must be recomputed on every single edit. That hash was pure friction with no benefit at this threat model.
- **`connect-src https:`** lets ShareR load a script or data file from any HTTPS host that permits it, which is required by sections 5.1 and 7. Note that CORS, not CSP, is the real constraint here; see section 5.5.
- **`http://localhost:*` and `http://127.0.0.1:*`** are included so local testing against a ZippyServe instance works without editing the policy.
- **Do not add `frame-ancestors`.** Browsers ignore it in a `<meta>` tag and log a warning for every document that parses the policy, so it provides no protection and only adds console noise that hides real errors. It requires a real response header, which GitHub Pages cannot set.

**Two webR console messages are expected and benign.** Recorded here so they are not investigated again: `Refused to get unsafe header "Content-Encoding"` (Emscripten's lazy-file loader probing for gzip; verified harmless because those files are served uncompressed with an accurate `Content-Length`), and ``WebR is using `PostMessage` communication channel, nested R REPLs are not available.`` (the intended tradeoff from section 3.2).

**Two console messages are expected and benign.** Record them here so future maintainers do not re-investigate what has already been chased down:

- `Refused to get unsafe header "Content-Encoding"`, emitted by `R.js`. Emscripten's lazy-file loader probes that header to detect gzip, and CORS does not expose it cross-origin. Verified harmless: the lazily loaded files are served uncompressed and their `Content-Length` equals their true byte length, so the size arithmetic the loader actually depends on is correct.
- ``WebR is using `PostMessage` communication channel, nested R REPLs are not available.`` This is the documented and intended tradeoff from section 3.2.

An earlier draft required pinning `script-src` to a single CDN and warned against wildcards. That instruction is withdrawn: it is inconsistent with `connect-src https:`, which sections 5.1 and 5.5 require so that a script or data file can be loaded from an arbitrary host, and it was premised on treating the policy as a security boundary, which section 0.1 rejects.

### 3.5 Reproducibility: pin everything

Research code that produces different numbers on different days is a defect. Pin, in `CONFIG`:

- `WEBR_VERSION`, for example `'0.6.0'`, and derive `WEBR_BASE_URL = 'https://webr.r-wasm.org/v' + WEBR_VERSION + '/'`. **Never point at `latest/`.**
- `WEBR_REPO_URL`, and the R minor version its package index is built for.
- Every JavaScript library version, as an exact version in the URL. Never `@latest`, never a range.

Every run emits a small `run-manifest.json` into the results ZIP (section 10.4). Keep it to what a methods section actually needs: the ShareR version, the webR version, the R version from `R.version.string`, the resolved commit SHA when a repository was used, the entry file and where it came from, the list of staged input files with their sources, the installed packages, the wall-clock duration, and per-chunk status. Computing a SHA-256 of every input file was specified in an earlier draft and is dropped per section 0.1.

### 3.6 JavaScript dependencies: pinned CDN

Load `js-yaml`, `marked`, `DOMPurify`, and `fflate` from a single pinned CDN:

```html
<script src="https://cdn.jsdelivr.net/npm/js-yaml@4.1.0/dist/js-yaml.min.js"></script>
```

Rules, now just two:

- **Exact versions only.** `@4.1.0`, never `@4`, never `@latest`. A floating version silently changes the code running against participant data, which is a reproducibility problem, and it costs nothing to avoid.
- **Fail loudly.** If a library does not load, show an error naming that specific library and disable Run, rather than letting the page break in a confusing way later. Detect it by checking for the expected global (`jsyaml`, `marked`, `DOMPurify`, `fflate`) after load, which is more reliable than an `onerror` handler.

**Subresource Integrity hashes were specified in an earlier draft and are deliberately dropped**, per section 0.1. They require regenerating a hash on every version bump, a stale one breaks the whole page at load time, and they defend against a compromised jsDelivr, which is not a threat this static research tool meaningfully faces. Pin the versions and move on.

The webR core also loads from its own pinned CDN URL, using webR's own multi-file loader rather than a single script tag.

**Which webR artifact to import, verified against the live registry and CDN during Stage 1.** Two easy mistakes here each cost a debugging cycle:

- **The npm package is `webr`, not `@r-wasm/webr`.** The scoped package was renamed and is now deprecated upstream; it is frozen at `0.2.0` and will never carry a current release. Resolve versions against `webr`.
- **Import `dist/webr.js`, not `dist/webr.mjs`.** The `.mjs` file is the bundler-target ESM build and carries a static top-level `import { createRequire } from 'module'`. A browser cannot resolve the bare Node builtin `module`, so importing it fails immediately with `Failed to resolve module specifier "module"`. `dist/webr.js` is the package's `browser` exports-condition build and has no Node-only bare specifiers. Note that `dist/webr.js` was introduced in `0.6.0`; earlier releases such as `0.5.4` ship only `.mjs`/`.cjs` and therefore cannot be loaded directly in a browser from a CDN. This is an additional reason the pin cannot drift backwards.

At the pinned `WEBR_VERSION` of `0.6.0`, webR reports R **4.6.0**, and its own built-in default `baseUrl` is already `https://webr.r-wasm.org/v0.6.0/`. Set `WEBR_BASE_URL` explicitly anyway, per section 3.5, so a webR upgrade cannot silently move the engine URL.

Licensing note, which is the main reason for the CDN approach: linking to a CDN-hosted library is not redistribution, so ShareR does not take on the notice-preservation and file-level obligations that shipping copies of Apache-2.0, MPL-2.0, and MIT files in a GPLv3 repository would create. Attribution in the README remains appropriate and is done regardless. If a future requirement forces genuinely offline operation and the libraries must be served from the repository, revisit those obligations deliberately at that point. webR itself is GPL-3, which composes cleanly with ShareR's own GPLv3 licensing should self-hosting ever be enabled.

---

## 4. Caching

**There is no service worker and no Cache Storage bookkeeping.** An earlier draft specified a custom caching worker with version-keyed buckets and an invalidation lifecycle. Per section 0.1 that is dropped, because the browser already does the job:

- Every engine URL is immutable, since `WEBR_VERSION` is pinned (section 3.5) and package binaries live under versioned `repo.r-wasm.org` paths. Those hosts serve long `Cache-Control` lifetimes, so the ordinary HTTP cache makes the second run fast without any code from us.
- Bumping `WEBR_VERSION` changes every URL, so cache invalidation is automatic and needs no `activate` handler deleting stale buckets.
- Removing the service worker also removes a class of bug that is genuinely nasty to diagnose: a worker updating mid-run while R is streaming output.

Tell the user what to expect instead of managing it for them: state in the UI that the first run downloads roughly N MB and later runs reuse the browser cache. If a researcher on a managed laptop needs to reclaim that space, the browser's own "clear site data" is the correct tool and it already exists.

Provide a small **Diagnostics** panel, because it makes support tickets answerable:

- The pinned webR version and the R version reported by `R.version.string`.
- The active communication channel and whether `crossOriginIsolated` is true.
- Approximate storage in use via `navigator.storage.estimate()`, displayed for information only.

Offline operation is explicitly not a goal (section 16).

---

## 5. URL Parameters, Routing, and Input Validation

### 5.1 Parameters

| Parameter | Example | Default |
| --- | --- | --- |
| `entry` | `EMA-CleanR.rmd`, or a full `https://` URL to a single `.R`/`.Rmd` file | auto-detected, section 5.3 |
| `script` | alias for `entry` | |
| `data` | one or more files **or directories**, as URLs or repo-relative paths, comma separated or repeated | none |
| `repo` | `DepressionCenter/EMA-CleanR` | none |
| `ref` | `main`, `v1.2.0`, or a 40-character SHA | repository default branch |
| `branch` | alias for `ref` | |
| `packages` | `dplyr,ggplot2,table1` | added to the packages detected by scanning, section 9.1 |
| `repos` | `https://myorg.r-universe.dev` | additional package repositories, comma separated |

**ShareR always runs immediately once a script resolves and files are staged** -- researchers open a link to see results, not to find a Run button. There is no opt-out parameter; a `run` button remains available in the UI for a manual re-run.

**Every configurable thing is a URL parameter.** ShareR never reads a config file from the researcher's repository; see section 5.3 for why that rule is absolute.

**`entry` accepts three forms**, and which one is in use is decided by inspecting the value, not by a separate mode flag:

1. A **full `http://` or `https://` URL** to a single `.R` or `.Rmd` file, hosted anywhere that permits cross-origin reads: GitHub Pages, an institutional web server, a localhost test server, or any similar host. This is the "one file, no repository" path and it must work without `repo` being present at all.
2. A **repo-relative path** such as `analysis/clean.Rmd`, resolved against `repo` (section 6).
3. **Absent**, in which case it is auto-detected per section 5.3, or the user opens files locally (section 7).

**`data` supplies input files so that uploading is optional.** This is what makes a ShareR link runnable end to end by someone who has never seen the analysis: the author shares a link carrying both the script and its sample data, and the recipient presses Run. Accept both a repeated parameter and a comma-separated list:

```
?entry=https://example.org/analysis/EMA-CleanR.rmd&data=https://example.org/analysis/EMA-Data.csv
?repo=DepressionCenter/EMA-CleanR&data=EMA-Data.csv&data=lookup.csv
?repo=DepressionCenter/EMA-CleanR&data=data/
```

Each file is written into the working directory (section 6.4) under its **basename**, so `https://example.org/x/y/EMA-Data.csv` lands at `EMA-Data.csv` and a script calling `read.csv("EMA-Data.csv")` finds it. An optional rename may be given as `data=<url>|<filename>` for when the URL basename is wrong or absent, which is common for share links ending in an opaque identifier.

**A value ending in `/` means a directory**, and every file directly inside it is staged. This avoids listing a dozen CSVs by hand. Directory listing is not universally possible, so resolve it in this order and be explicit when it cannot be done:

1. **Repo-relative directory** such as `data=data/` together with `repo=`. Filter the tree listing already fetched in section 6.1. This costs **no extra request** and is the reliable path. Prefer it, and say so in the documentation.
2. **A GitHub URL naming a directory**, such as `https://github.com/OWNER/REPO/tree/main/data/`. Convert it to a Git Trees or Contents API call for that path. Subject to the same unauthenticated rate limit as section 6.2.
3. **Any other URL ending in `/`.** Fetch it and, if the response is HTML, treat it as a server-generated directory index: parse anchor `href` values, keep entries that resolve to a file directly beneath that directory, and discard parent links (`../`) and column-sort links (`?C=N;O=D`). This works for the common Apache and nginx autoindex formats.

   Be candid that this is best-effort. Most web servers do not enable directory listing at all, and those that do have no standard format. If the response is not HTML, or no file links are found, report it plainly rather than silently staging nothing:

   > `example.org/data/` did not return a file listing. Many web servers do not publish one. List the files individually instead, for example `data=a.csv,b.csv`, or open them from your computer.

   Note for local testing: ZippyServe does not generate directory indexes, so use the explicit comma-separated form or a repository when testing locally.

Recurse only one level deep, take only files, and apply `CONFIG.MAX_REPO_FILE_BYTES` and the traversal check in section 5.2 to every entry discovered this way. A directory listing is untrusted input exactly like a repository tree is.

**Files supplied by `data` are defaults, not fixtures.** The UI must list every staged file and let the user replace any of them with a local file of their own, or add files that were not listed. A user-supplied file always wins over a URL-supplied file of the same name, and the substitution is announced. This is the primary workflow: run the shared analysis against *my* data.

**`repo` accepts** a full GitHub URL (`https://github.com/DepressionCenter/ShareR`, trailing slash optional), an `@owner/repo` form (ignore the `@`), plain `owner/repo` (GitHub, for backward compatibility), a full `bitbucket.org` repository URL, or any GitLab URL (`gitlab.com` or self-hosted) that names a file or directory via its `/-/blob/`, `/-/raw/`, or `/-/tree/` marker segment (section 6.6). A bare self-hosted GitLab *project home* URL cannot be told apart from a group page by shape alone and is rejected with an actionable message; paste a link to a file into `entry=`/`data=` instead.

**`script`** is an alias for `entry`. Normalize it to `entry` internally; if both are present and non-empty, `entry` wins.

### 5.2 Validation

Every parameter is untrusted input that ends up in a fetch URL and in a virtual filesystem path. Two checks matter, and they are cheap:

**Validate URLs by parsing them, not by pattern matching.** Use the `URL` constructor, reject anything that throws, and allow only the `http:` and `https:` protocols. This rejects `javascript:`, `data:`, and `file:` cleanly without hand-written regular expressions:

```js
function parseFileUrl(value) {
  let u;
  try { u = new URL(value, window.location.href); }
  catch { throw new Error('Not a valid URL: ' + value); }
  if (u.protocol !== 'https:' && u.protocol !== 'http:') {
    throw new Error('Only http and https URLs are supported, not ' + u.protocol);
  }
  return u;
}
```

**Never let a supplied path escape the working directory.** This is the one traversal control worth keeping, because repository tree listings and URL basenames are both attacker-influenceable. Normalize every write path and assert it still begins with `CONFIG.VFS_PROJECT_DIR` before calling `writeFile`. Reject any path segment equal to `..`, any leading `/`, and any backslash.

For repo-relative values, keep the simple allowlists:

```js
const RE_REPO = /^[A-Za-z0-9][A-Za-z0-9._-]{0,99}\/[A-Za-z0-9][A-Za-z0-9._-]{0,99}$/;
const RE_REF  = /^[A-Za-z0-9._\/-]{1,255}$/;
const RE_PATH = /^[A-Za-z0-9._\/-]{1,255}$/;
```

Report every rejection with a visible, specific message naming the offending value. Do not fail silently. A rejection that leaves no valid entry script at all (see below) is fatal: it aborts staging and is shown in the same designed error dialog a fatal run failure uses (`showErrorModal`), not as a soft entry in the Workspace panel's staging-messages list alongside recoverable warnings like a missing data file.

**`entry`/`script`/`file` must resolve to actual R or R Markdown source, not merely a filename that looks like one.** A URL is untrusted content, not just an untrusted path: the researcher who shares a link controls what the URL string looks like, but not necessarily what bytes the far end of that URL serves on a given day, and a misconfigured or compromised host could return an HTML error page, a redirect-to-login page, or arbitrary script under a `.R`-looking name. Reject the target, without staging it, unless it passes every one of:

1. **Extension.** The resolved file name ends in `.R` or `.Rmd` (case-insensitive). Checked before the fetch when the name is already known (a repo-relative path), and immediately after when it is not (a URL's basename).
2. **Content-Type.** If the HTTP response's `Content-Type` header contains "html", "javascript", or "ecmascript", reject regardless of extension.
3. **Content sniff.** Decode only the first ~1&nbsp;KB of the fetched body (not the whole file — a valid `.Rmd` legitimately embeds raw HTML/JS chunks later in the document, e.g. htmlwidgets output, so only the very start is diagnostic). Reject if, after trimming a byte-order mark and leading whitespace, it starts with `<` (an HTML/XML tag), or if its first line is a `#!` shebang naming a non-R interpreter (`node`, `python`, `bash`, `sh`, `perl`, `ruby`) rather than `Rscript`.

Gate 3 runs even when gates 1–2 already passed: a spoofed `.R` file must still fail on content. This applies to a URL-based `entry=`; a repository-relative `entry=` (fetched through a provider's own raw-content API, a materially different trust boundary from an arbitrary attacker-controlled host) gets gate 1 only.

**`.git`/`.github` are never valid `entry=`/`data=` targets, at any path depth.** These hold version-control/CI metadata, never legitimate source or research data, and `.git` in particular can contain credentials in its config or in a hook script. This is a widening of the existing GitHub whole-repository tree filter (section 6.1), which only ever checked a root-level prefix, to a single shared check (`isVcsMetadataPath`) applied everywhere a repository path or a URL's pathname is accepted: the tree listing itself, an explicit `data=`/`entry=` repository-relative path, an explicit `data=`/`entry=` URL, and a `data=<dir>/` listing (repository-relative, provider directory API, or generic autoindex scrape).

### 5.3 Entry point auto-detection

**ShareR never asks the researcher to add a file to their repository.** There is no `sharer.json`, no `.sharerignore`, and no manifest of any kind. This is not a simplification detail; it is the entire premise stated in section 0: point ShareR at an *unmodified* repository. A tool that requires the author to commit a config file has broken its own promise, and it is worse than that in practice, because the author must then maintain that file forever for the benefit of one tool. **Everything configurable is passed in the URL**, where it costs the author nothing and stays under the control of whoever is sharing the link.

When `repo` is given and `entry` is not:

1. Look in the repository root, case-insensitively, for `main.R`, `run.R`, `main.Rmd`, `run.Rmd`, in that order.
2. Otherwise collect all `.R` and `.Rmd` files, excluding conventional non-entry directories: `tests/`, `test/`, `man/`, `R/`, `inst/`, `vignettes/`, `renv/`, `packrat/`. If exactly one remains, use it.
3. Otherwise show the candidates in the page, sorted with root-level files first and `.Rmd` before `.R`, and ask the user to choose. Keyboard operable, per section 11.2.

Choosing a file updates the URL via `history.replaceState()` so the resulting link is shareable and reproducible. This matters: shareability is the product.

### 5.4 Running code from elsewhere

ShareR runs R code the visitor did not write. That code executes inside the WebAssembly sandbox and cannot reach the host machine, but it can read any file the visitor adds to the page and it can render author-supplied markdown.

Keep this proportionate. **Show the source, do not gate it.** Display the resolved origin of the script prominently in the setup view, for example `Running EMA-CleanR.rmd from raw.githubusercontent.com/DepressionCenter/EMA-CleanR`, so the visitor can see where the code came from before pressing Run. Nothing runs until they press Run, which is the meaningful consent step. A blocking interstitial keyed to an owner allowlist was specified in an earlier draft and is dropped per section 0.1: it trains people to click through, and it does not stop anything the Run button does not already stop.

The control that does matter is sanitizing author-supplied HTML before it is rendered, since `.Rmd` prose routinely contains raw HTML. That is required in section 8.3 and is not optional.

### 5.5 CORS: the real constraint on "any URL"

**This is the limitation that will surprise users, so surface it in the UI and the README rather than letting them discover it as a broken page.** A browser can only fetch a file from another origin if that server sends an `Access-Control-Allow-Origin` header. ShareR cannot change this; it is the host's decision. ShareR retries a CORS-blocked fetch through a public CORS proxy relay before giving up (`fetchWithRetryAndCorsProxyFallback` in `index.html`), which can succeed even for a host that itself sends no CORS header — but the proxy is a best-effort third-party service outside EFDC's control, not a guarantee, and it is never used for a `localhost`/private-network address (see below).

Verified by direct request during specification of this feature (rows below the divider reflect each vendor's own published/observed CORS behavior as of writing, not a direct request made in this specification pass — reverify before relying on them for a support decision):

| Host | Works? |
| --- | --- |
| `raw.githubusercontent.com` | Yes, sends `access-control-allow-origin: *` |
| `gist.githubusercontent.com` | Yes |
| GitHub Pages, `*.github.io` | Yes, confirmed against a real asset |
| `cdn.jsdelivr.net/gh/<owner>/<repo>@<ref>/<path>` | Yes, and it serves any file from any public GitHub repository |
| A web server you control, configured to send the header | Yes |
| `http://localhost:PORT` during local testing | Yes, when ShareR itself is served over `http://localhost` |
| Dropbox share links | No CORS header on the raw download host. ShareR retries through a public CORS proxy relay; this may or may not succeed depending on that relay and Dropbox's own request handling. |
| Google Drive | No CORS header. Same proxy retry as above; Google Drive's own anti-abuse checks make success less likely than for a plain static file host. |
| Google Sites | No CORS header, and requests redirect to a login page — a proxy relay cannot complete a login, so this one reliably still fails. |
| GitLab `/-/raw/` (gitlab.com or self-hosted) | No CORS header (a long-standing open GitLab feature request). Relies on the proxy fallback more than GitHub does. |
| Bitbucket `/raw/` (`bitbucket.org`, Cloud) | No native CORS support. Same proxy-fallback reliance as GitLab. |
| Bitbucket Server `/raw/` (self-hosted) | No native CORS support. Same proxy-fallback reliance; an internal/institutional instance may also require being on the relevant network, which a public proxy relay cannot help with. |
| `dl.dropboxusercontent.com` (the host a Dropbox share link is rewritten to, section 5.6) | Sends `access-control-allow-origin: *`; typically works without the proxy fallback. |
| `drive.google.com/uc?export=download` (the rewritten Google Drive form) | No CORS header; relies on the proxy fallback, with a large-file virus-scan interstitial the proxy cannot resolve either. |
| OneDrive/SharePoint raw hosts (`?download=1` trick) | No CORS header; relies on the proxy fallback. Only "anyone with the link" shares can work at all — an auth-required share cannot, proxy or not. |

When a fetch fails in a way consistent with CORS and the proxy fallback was also attempted, do not report a generic network error. Say what actually happened and what to do about it:

> `example.com` did not allow this page to read that file. ShareR also tried reaching it through a public CORS proxy relay, without success. This is a setting on that server, not something ShareR can change. Files hosted on GitHub, on GitHub Pages, or on a server configured to allow cross-origin reads will work. You can also open the file from your computer using the button below.

Then fall back to local file selection (section 7). **`cdn.jsdelivr.net/gh/` is the recommended escape hatch** for anyone whose file lives in a public GitHub repository but who wants a direct file URL: it works, it sends CORS headers, and it is already the CDN used for the JavaScript dependencies. Document it in the quick start.

**Proxy fallback is skipped entirely for `localhost` and private/link-local addresses** (`isPrivateOrLocalHost` in `index.html`, ported from datalavista's URL-validation guard). A public proxy relay is a third party outside EFDC's control; forwarding a request meant for an internal address through one would leak that address's existence — and any response — to that third party. A direct fetch to such an address is unaffected by this guard; only the proxy retry is skipped.

### 5.6 Cloud storage share-link conversion (Dropbox, Google Drive, OneDrive, SharePoint)

None of these four expose a public, key-free API the way GitHub/GitLab/Bitbucket do, so support is limited to a best-effort, single-file share-link rewrite (`rewriteCloudStorageUrl` in `index.html`), tried before the generic fetch for both `entry=` and a `data=` single file:

- **Dropbox** (`dropbox.com`/`www.dropbox.com`): force the `dl` query parameter to `1`, which redirects to `dl.dropboxusercontent.com` (sends CORS headers, so this one typically does not need the proxy fallback).
- **Google Drive** (`drive.google.com`): rewrite `/file/d/<id>/...` to `/uc?export=download&id=<id>`. Large files hit an interstitial virus-scan confirmation page this app cannot bypass client-side — a known limitation, not a bug to chase.
- **OneDrive/SharePoint** (`onedrive.live.com`, `1drv.ms`, `*.sharepoint.com`): append `download=1` to the existing query string, a documented unofficial direct-download trick. Only works for "anyone with the link" shares; an auth-required ("specific people") share can never work without a Microsoft Graph OAuth app registration, which this static, backend-less page has no way to hold securely (`AGENTS.md` section 7 forbids hardcoding credentials, and there is no server here to hold one even if that were acceptable).

**Whole-folder loading for any of these four is out of scope.** All four render folder views client-side via JavaScript; a plain fetch-and-scrape (the same technique that works for an Apache/nginx autoindex page, section 5.1) sees nothing meaningful. A real listing (Microsoft Graph's `/shares` endpoint, Google Drive API v3) requires an OAuth app registration or an API key this project does not have. The existing generic-URL directory branch already degrades gracefully for these hosts with no additional code — it reports "did not return a file listing" exactly as it would for any other JavaScript-rendered page.

---

## 6. Repository Synchronization

### 6.1 Listing

```
GET https://api.github.com/repos/{owner}/{repo}/git/trees/{ref}?recursive=1
```

Send `Accept: application/vnd.github+json`. Do **not** send credentials. Never accept a token via URL parameter and never store one; that would put a secret in a shareable link, which `AGENTS.md` section 7 forbids outright. Private repositories are supported only by opening the files locally (section 7), and the README must say so.

Handle `tree.truncated === true`: the API caps large trees. If truncated, fall back to listing the entry file's directory via the Contents API and warn the user that helper files elsewhere in the repository may be missing.

### 6.2 Rate limits

Only `api.github.com` requests count against GitHub's 60-per-hour unauthenticated limit. File contents are fetched from `raw.githubusercontent.com`, which is a separate service and is not subject to that quota. ShareR therefore uses **one** rate-limited request per run.

Read `X-RateLimit-Remaining` and `X-RateLimit-Reset` from the tree response and surface them in Diagnostics. On HTTP 403 with `X-RateLimit-Remaining: 0`, show: "GitHub's anonymous request limit is reached for your network. It resets at HH:MM. You can still run your analysis now by opening the script and your data files from your computer." Then show the local file controls (section 7). A graceful error state is not the same as a dead end.

Do not build an IndexedDB cache for tree listings. An earlier draft required one; per section 0.1 it is dropped. One API call per run against a 60-per-hour limit is not a problem worth a storage layer.

### 6.3 Fetching contents

- Resolve `ref` to a commit SHA first, then fetch everything at that SHA. This makes a run reproducible and immune to a mid-run push.
- Fetch each blob from `https://raw.githubusercontent.com/{owner}/{repo}/{sha}/{path}`.
- **Always fetch as `arrayBuffer()`, never as `text()`.** Formats such as `.rds` and `.xlsx` are binary and would be silently corrupted by UTF-8 decoding. Write bytes and let R decide the encoding.
- Concurrency capped at `CONFIG.FETCH_CONCURRENCY`, default 6. Retry each blob twice with exponential backoff and jitter. Report per-file failures individually rather than failing the whole sync.
- Skip files larger than `CONFIG.MAX_REPO_FILE_BYTES`, default 25 MB, with a visible warning naming the file. Skip `.git/` and `.github/`.
- Total sync budget `CONFIG.MAX_REPO_TOTAL_BYTES`, default 100 MB. Stop and report if exceeded.

### 6.4 Writing to the VFS

```
/home/web_user/project/            <- repository files, mirrored
/home/web_user/project/<entry>     <- the script
```

Create directories depth-first before writing files. `webR.FS.mkdir` throws if the directory exists, so either pre-sort the unique directory set or catch and ignore `EEXIST` explicitly rather than swallowing all errors.

Set the R working directory before the run and confirm it:

```r
setwd("/home/web_user/project")
```

`EMA-CleanR.rmd` calls `read.csv(input_file)` with a relative path and `dir.create(output_dir)` with a relative path. Both depend on this being correct.

### 6.5 Skipping files that are not needed

Skip `.git/`, `.github/` (at any path depth, not just the root — `isVcsMetadataPath`), and files above `CONFIG.MAX_REPO_FILE_BYTES`. That is sufficient.

A `.sharerignore` file with gitignore-style pattern matching was specified in an earlier draft and is dropped, both because pattern semantics are easy to get subtly wrong and, more importantly, because it would require the researcher to add a file to their repository for ShareR's benefit. See section 5.3: ShareR never asks for that. The problem it was meant to solve, a repository shipping a large rendered HTML report, is already handled by the size cap.

### 6.6 GitLab and Bitbucket synchronization

GitLab (gitlab.com and self-hosted), Bitbucket Cloud (`bitbucket.org`), and Bitbucket Server/Data Center (self-hosted, formerly "Stash" — a different product from Bitbucket Cloud with a different URL shape and REST API) all get the same treatment as GitHub where the provider's own API makes it feasible, sharing every other stage of the pipeline (the dependency walk, auto-data-detection, and size budgets in sections 6.3–6.5 run unmodified regardless of provider).

**Recognizing a link, without a hostname allowlist.** GitLab's web UI always inserts a literal `/-/` marker segment immediately before `blob`, `raw`, or `tree` (`https://HOST/<project-path>/-/blob/<ref>/<path>`), regardless of how deep the project path is (arbitrary-depth subgroups) or which host serves it. Bitbucket Server is recognized the same way, via its own distinctive `/projects/<KEY>/repos/<repo>/browse` or `/raw` marker — its ref, when given, travels in an `?at=<ref>` query parameter rather than a path segment. Keying recognition off these structural markers instead of a hostname list is what lets a self-hosted instance of either product work with no per-host code. Bitbucket Cloud is hostname-gated to `bitbucket.org` (a single fixed cloud service) and uses `/src/<ref>/<path>` for both a file and a directory view (a trailing `/` disambiguates, the same convention `data=` already uses).

**Raw-content URL, single file:**

- GitLab: rewrite `/-/blob/` or `/-/raw/` to `/-/raw/` on the same host — `https://HOST/<project-path>/-/raw/<ref>/<path>`.
- Bitbucket Cloud: rewrite `/src/` to `/raw/` — `https://bitbucket.org/<workspace>/<repo>/raw/<ref>/<path>`.
- Bitbucket Server: rewrite `/browse/` to `/raw/` on the same host, carrying the ref (if any) in `?at=` — `https://HOST/projects/<KEY>/repos/<repo>/raw/<path>[?at=<ref>]`.

**Whole-project tree listing.** Bounded by two safety caps, `CONFIG.MAX_REPO_TREE_ENTRIES` and `CONFIG.MAX_REPO_TREE_REQUESTS`, and sets the same `truncated: true` flag GitHub's own listing uses on hitting either (none of the three self-hosted/Cloud non-GitHub providers exposes GitHub's single self-limiting `git/trees?recursive=1` call):

- GitLab: `GET {host}/api/v4/projects/{url-encoded-project-path}/repository/tree?ref=X&recursive=true&per_page=100`, paginating via the `x-next-page` response header (empty on the last page).
- Bitbucket Cloud: no recursive endpoint exists — Atlassian's own documentation warns that a large `max_depth` value on `/src/` can time out (HTTP 555) — so this walks one directory at a time via `GET https://api.bitbucket.org/2.0/repositories/{workspace}/{repo}/src/{ref}/{path}?pagelen=100`, following each response's own `next` URL and skipping (not recursing into) any `.git`/`.github` folder.
- Bitbucket Server: unlike Bitbucket Cloud, its REST API 1.0 *does* expose a genuine recursive flat-file listing — `GET {host}/rest/api/1.0/projects/{KEY}/repos/{repo}/files?limit=1000&at=X`, paginated the classic Atlassian way (`values`/`isLastPage`/`nextPageStart`).

**Default branch**, when `ref=` is omitted: GitLab via `GET {host}/api/v4/projects/{id}` → `default_branch`; Bitbucket Cloud via `GET /2.0/repositories/{workspace}/{repo}` → `mainbranch.name`; Bitbucket Server via `GET {host}/rest/api/1.0/projects/{KEY}/repos/{repo}/branches/default` → `displayId`. None of the three gets GitHub's `main`/`master` silent-retry heuristic (section 6.3's ref resolution) — that heuristic exists because of GitHub's specific 2020 default-branch rename, not a demonstrated need elsewhere.

**`repo=` accepts a ref embedded in the URL itself** for GitLab and Bitbucket Server (a `.../-/tree/<ref>/` path segment or a `?at=<ref>` query parameter, respectively) when no separate `ref=`/`branch=` is also given — pasting a branch-specific link directly into `repo=` resolves that branch rather than silently falling back to the repository's default one. An explicit `ref=`/`branch=` always takes precedence when both are present.

**Not supported:** a bare self-hosted GitLab *project home* URL in `repo=` (no `/-/` marker to disambiguate a project from a group page by shape alone — paste a file link into `entry=`/`data=` instead, which is unambiguous). Bitbucket Server has no equivalent gap: its `/projects/<KEY>/repos/<repo>/browse` marker is unambiguous even with no file path, so a bare repository-root URL works directly in `repo=`.

---

## 7. Staging Files: One List, Three Sources

There are not separate "repository mode" and "upload mode". There is **one staged file list**, and entries arrive from three sources that compose freely:

1. **Repository sync** (section 6), when `repo` is given.
2. **URLs** from `entry` and `data` (section 5.1).
3. **Local files** the visitor opens from their own computer.

Later sources overwrite earlier ones by filename, so precedence is **local files > URL files > repository files**. Announce every overwrite visibly, for example `Using your EMA-Data.csv instead of the one from the repository`. This ordering is the product: the shared link brings the analysis and its sample data, and the researcher swaps in their own data.

**The staged file list is a required UI element, not a nicety.** Show every file with its name, size, and source, with a control to remove it and a control to replace it with a local file. This list is the honest answer to "what does this thing have access to," and it is how a researcher confirms their data is the data being used.

Local file selection requirements:

- A drag-and-drop zone that is **also a real `<button>`** opening a file picker, and that accepts paste. A drop-only zone is an accessibility failure and is not acceptable (`AGENTS.md` section 9).
- Accept a whole folder via `webkitdirectory` where supported, since analyses usually have helper files.
- Read each file with `File.arrayBuffer()` and write bytes with `webR.FS.writeFile`. **Never `FileReader.readAsText`**, for the reason in section 6.3: `.rds` and `.xlsx` are binary and UTF-8 decoding silently corrupts them.
- Enforce `CONFIG.MAX_UPLOAD_FILE_BYTES` per file with a clear message naming the file.
- Files land in `CONFIG.VFS_PROJECT_DIR`, preserving relative paths from a folder drop, subject to the traversal check in section 5.2.

ShareR must be fully usable with **no URL parameters at all**: open the page, add an `.R` or `.Rmd` file and its data from your computer, press Run. That path requires no network access beyond the R engine itself and is the fallback whenever a fetch fails for any reason, including CORS (section 5.5).

---

## 8. Execution Engine

### 8.1 Plain `.R` files

Read the file as text, then execute inside a `Shelter` so R objects are freed deterministically:

```js
const shelter = await new webR.Shelter();
try {
  const cap = await shelter.captureR(code, {
    withAutoprint: true,
    captureStreams: true,
    captureConditions: true,
    captureGraphics: { width: CONFIG.FIG_WIDTH_PX, height: CONFIG.FIG_HEIGHT_PX },
  });
  // cap.output: [{ type: 'stdout' | 'stderr' | 'message' | 'warning' | 'error', data }]
  // cap.images: ImageBitmap[]
} finally {
  await shelter.purge();
}
```

Long-running scripts must not appear frozen. Because the `PostMessage` channel gives no interrupt, streaming output is the only progress signal available, so consume `webR.stream()` on a parallel loop and append to the log live rather than waiting for `captureR` to resolve.

### 8.2 Why `.Rmd` cannot be handled by concatenating chunks

The obvious approach, extracting all fenced R blocks and running them as one string, fails on the reference case and on most real R Markdown in this organization.

`EMA-CleanR.rmd` declares YAML parameters and then immediately does:

```r
for (nm in names(params)) { ... assign(nm, params[[nm]], envir = .GlobalEnv) }
```

`params` is created by `rmarkdown::render()` from the YAML front matter. Concatenated chunk text has no `params`, so this errors on the second chunk, and every downstream variable (`input_file`, `output_dir`, `ema_item_prefix`, `plot_colors`, and the rest) is undefined.

Three further problems with concatenation: chunk options are ignored, so `eval=FALSE` chunks execute and `include=FALSE` chunks pollute the report; a failure anywhere reports as one large error with a meaningless line number; and no output can be shown until the whole document finishes.

### 8.3 Required `.Rmd` handling

**Step 1: parse front matter.** Split on the leading `---` fence. Parse with `js-yaml` using `load()` in the default safe schema. Guard against a document with no front matter.

**Step 2: build `params`.** Follow the knitr convention: for each entry under `params:`, if the value is a mapping containing a `value` key, the parameter's value is the content of `value`, because the surrounding mapping carries authoring metadata such as `label` and `input`. Otherwise the value is used as is. `EMA-CleanR.rmd` relies on this for `ema_item_labels`, `participant_group_map`, and `plot_colors`.

Serialize the resulting object to JSON and materialize it in R before the first chunk runs:

```js
const paramsJson = JSON.stringify(resolvedParams);
await webR.objs.globalEnv.bind('.sharer_params_json', paramsJson);
await webR.evalRVoid(
  'params <- jsonlite::fromJSON(.sharer_params_json, simplifyVector = TRUE); ' +
  'rm(.sharer_params_json)'
);
```

Binding through `globalEnv.bind` rather than string-interpolating JSON into R source removes an injection class entirely: a repository whose YAML contains a quote or a backslash cannot break out into arbitrary R.

Verify the round trip on the reference case. Expected results: `input_file_has_headers` is logical `TRUE`, `ignore_surveys` is a length-7 character vector, `late_survey_cutoff_hour` is numeric `9`, and `unlist(params$ema_item_labels)` is a named character vector of length 13. `jsonlite` must therefore be in the preflight package set (section 9), and ShareR must fall back to a generated `list(...)` literal builder if it is unavailable.

**Step 3: parse chunks properly.** A regex over the whole document is not sufficient. Scan line by line, tracking fence state:

- A chunk opens on `^\s*```+\s*\{([a-zA-Z0-9_]+)[,\s]?(.*)\}\s*$` and closes on a fence of at least the same backtick count with nothing after it.
- Capture the engine name. Engines other than `r`, such as `python`, `bash`, `sql`, and `css`, are **skipped with a visible notice**: neither silently dropped nor executed.
- Parse chunk options into a small object: `eval`, `echo`, `include`, `warning`, `message`, `error`, `results`, `fig.width`, `fig.height`, `label`. Accept `TRUE`, `FALSE`, `T`, `F`, and numbers. Options that are R expressions rather than literals are not evaluated; treat them as their default and note that in the log.
- Honor `knitr::opts_chunk$set(...)` in a setup chunk by letting that chunk run and then reading the resulting defaults back out of R, which is more robust than pattern-matching the call.
- Text between chunks is prose. `EMA-CleanR.rmd` contains raw HTML `<div>` and `<pre>` blocks in its prose, so prose must be rendered with `marked` and then passed through `DOMPurify.sanitize()` before insertion. Never assign unsanitized author content to `innerHTML`.

**Step 4: run chunks sequentially**, each in its own `Shelter`, in the shared global environment so state carries forward. For each chunk record: label, source, elapsed milliseconds, stdout, stderr, messages, warnings, error if any, and captured `ImageBitmap` plots. Append to the report as each chunk completes, so the user sees progress on a script that takes minutes.

On error, stop by default and mark the chunk as failed, unless `error=TRUE`, in which case record the condition and continue. Offer a "Continue anyway" action, because a researcher often wants the plots from the first ten chunks even when chunk eleven fails.

**Step 5: assemble the report** in page, with prose and chunk blocks interleaved, collapsible source matching `code_folding: show` in the reference document, plots as `<canvas>` elements, and a downloadable self-contained HTML version.

**Explicitly out of scope for this version, and stated as such in the README:** inline R (`` `r expr` ``), child documents, `rmarkdown::render()` itself, pandoc, and non-HTML output formats. Pandoc is not available in webR, so full `rmarkdown` rendering is impossible. `EMA-CleanR.rmd` uses zero inline R and 24 chunks, so it is fully covered, but a general claim of R Markdown support would be false.

### 8.4 Report fidelity

Do not attempt to reproduce the YAML `output:` block (`toc_float`, `theme`, `code_folding`, `df_print: paged`, custom `css`). Implement a single clean ShareR report layout using `um-style.css` and state clearly in the README that ShareR renders an equivalent report, not a byte-identical knitr render. Overclaiming here is how this project would lose researcher trust.

---

## 9. Package Preflight

The reference script loads `dplyr`, `psych`, `tidyverse`, `lubridate`, `table1`, `corrplot`, `ggplot2`, `patchwork`, and `rlang`. `tidyverse` alone pulls dozens of dependencies. Without a preflight, a user waits several minutes and then hits a bare "there is no package called X" error.

**webR cannot compile from source.** Only precompiled WebAssembly binaries can be installed. If a package has no wasm build in the configured repositories, that run is impossible, and the only remedies are changing the analysis or building the binary with `rwasm` and hosting it. Design the failure to arrive in seconds rather than minutes.

### 9.1 Detection

Statically scan all chunk source and any sourced `.R` files for `library(x)`, `require(x)`, `requireNamespace("x")`, and `x::`. Deduplicate. Exclude base and recommended packages already present in the webR image. Always include `jsonlite`, which ShareR itself needs to materialize `params` (section 8.3).

Scanning is a heuristic and will occasionally miss a package loaded indirectly. The override for that is a **URL parameter, never a file in the researcher's repository** (section 5.3):

| Parameter | Example | Effect |
| --- | --- | --- |
| `packages` | `packages=dplyr,ggplot2,table1` | Install these in addition to whatever was detected |
| `repos` | `repos=https://myorg.r-universe.dev` | Additional package repositories, comma separated |

Both are additive to the scan rather than replacing it, so a partial list still helps rather than breaking the run.

### 9.2 Installation

**Let webR resolve dependencies. Do not reimplement it.** An earlier draft required fetching the `PACKAGES` index and computing the transitive `Depends`/`Imports` closure in JavaScript. Per section 0.1 that is dropped: `webR.installPackages()` already does exactly this, correctly, and a second implementation would be a large amount of code whose only possible outcome is to disagree with the first one.

Pass the detected list to a single `webR.installPackages(list)` call and stream progress to the log:

- Before starting, show the list of packages about to be installed and warn that the first run downloads a substantial amount, while later runs reuse the browser cache.
- Guard the wall clock with `CONFIG.INSTALL_TIMEOUT_MS`, default 600000. On timeout, stop and offer a retry instead of hanging.
- On failure, **name the specific package that failed** and keep whatever installed successfully. Then state the likely cause plainly, because it is usually the same one:

  > `table1` could not be installed. It may not have a WebAssembly build available. Packages must be precompiled for WebAssembly; webR cannot build them from source. Ask the script author whether a different package would work.

**Do not assert anywhere in the code or documentation that a particular package is available.** Availability changes over time and is not ours to promise. Find out at runtime and report what actually happened. This applies to every package in the reference script, `table1` and `psych` included.

Optionally allow extra repository URLs, such as an R-universe repository like `https://<owner>.r-universe.dev`, passed to `installPackages`. This is worth supporting because it is what makes ShareR usable beyond whatever `repo.r-wasm.org` happens to carry, but it is a plain text input, not a managed repository list.

---

## 10. Outputs

### 10.1 Recursive VFS diff

`EMA-CleanR.rmd` writes six CSVs into `output/`, a directory it creates itself, so a one-level listing of `/home/web_user` would find none of them. Also, `webR.FS` has no `readDir` at all (section 3.3).

Implement:

```js
async function walkVfs(webR, root, out = new Map(), depth = 0) {
  if (depth > CONFIG.MAX_VFS_DEPTH) return out;
  let node;
  try { node = await webR.FS.lookupPath(root); } catch { return out; }
  if (!node.isFolder) { out.set(root, node.id); return out; }
  for (const name of Object.keys(node.contents || {})) {
    if (name === '.' || name === '..') continue;
    await walkVfs(webR, root + '/' + name, out, depth + 1);
  }
  return out;
}
```

Snapshot before the run, snapshot after, and treat paths present only in the second snapshot as generated outputs.

**Known limitation, disclosed rather than hidden:** `FSNode` exposes no size and no mtime, so a script that *overwrites* an existing file produces no detectable diff. Two mitigations are enough:

1. Additionally treat everything under the resolved `output_dir` parameter, when the script declares one, as an output regardless of the diff.
2. Provide a file browser over the working directory so the user can download any file, generated or not. This also covers every case the diff misses, which is why the third mitigation in an earlier draft, recording a SHA-256 of every input file to detect changes, is dropped per section 0.1.

### 10.2 Rendering

- Plots captured as `ImageBitmap` via `captureR`: draw into a `<canvas>` sized to the chunk's `fig.width` and `fig.height`. Provide `role="img"` and an `aria-label` derived from the chunk label, for example "Plot from chunk `compliance-by-group`". A canvas with no accessible name is a WCAG failure and this project has a hard accessibility requirement.
- Image files found in the VFS (`.png`, `.svg`, `.jpg`): read bytes, wrap in a `Blob` with the correct MIME type, render via `URL.createObjectURL`. **Revoke every object URL** when the results view is cleared; a long session with many plots otherwise leaks memory steadily.
- `.csv` and other data outputs: a list with name, size, and a download button, plus a preview of the first 20 rows for CSVs.
- Text outputs: monospace preview using `textContent`, never `innerHTML`. R output can contain anything.

### 10.3 Execution log

A live, monospace, scrollable region fed by `webR.stream()`. Mark it `role="log"` with `aria-live="polite"` and `aria-atomic="false"`. Distinguish stdout, stderr, warnings, and errors by both color and a text prefix, because color alone fails WCAG 1.4.1. Include a "Copy log" button; researchers paste these into support tickets.

### 10.4 Download all

Use `fflate` to build the ZIP:

```
results.zip
  outputs/...            # every detected output, original paths preserved
  report.html            # self-contained rendered report
  execution-log.txt
  run-manifest.json      # section 3.5
  source/<entry>         # the exact script that ran
```

Use `fflate`'s streaming API so a large output set does not have to be held in memory twice.

---

## 11. UI, UX, and Accessibility

### 11.1 States

Three primary states in one page, plus modals:

1. **Setup.** Source (GitHub repository or local files), staged file list, data drop zone, package preflight summary, Run button.
2. **Running.** Live log, per-chunk progress such as "Chunk 7 of 24: `compliance-by-group`", elapsed time, and the Stop and reset button with the honest label from section 3.2.
3. **Results.** Rendered report, plot gallery, output file list, Download all, Run again.

The header carries the title and a badge reading "Runs entirely in your browser. Your data is never uploaded." The badge links to the security documentation. Do not put a lock icon and the word "secure" on it; that is a compliance claim by implication.

### 11.2 Accessibility, targeting WCAG 2.2 AA

`AGENTS.md` section 9 makes these non-negotiable.

- Semantic landmarks: `<header>`, `<nav>`, `<main>`, `<footer>`. One `<h1>`; heading levels never skip.
- Full keyboard operation with no traps. Modals trap focus while open, restore focus to the trigger on close, and close on Escape.
- On state change, move focus to the new region's heading and announce the transition via a polite live region. A visual-only SPA transition is invisible to a screen reader user.
- The drop zone is a labelled `<button>` that also accepts drop and paste. Never drop-only.
- All controls have visible focus indicators meeting 2.2 AA focus-appearance requirements.
- Text contrast at least 4.5:1 against the UM navy and maize palette. Verify, do not assume.
- Status is never conveyed by color alone.
- Every canvas plot has an accessible name, per section 10.2.
- Honor `prefers-reduced-motion` for any spinner or transition.
- Long-running work is announced at intervals rather than continuously, to avoid flooding assistive technology.
- Verification: an automated axe-core pass plus a documented manual checklist covering a keyboard-only walkthrough, a screen reader walkthrough on at least one of NVDA or VoiceOver, 200 percent zoom, and forced-colors mode. Record results in `docs/security-privacy-accessibility.md`. Per `AGENTS.md` section 11, do not claim tests pass without running them.

---

## 12. Error Handling

Every failure mode gets a specific, actionable message. No stack traces in the UI; full detail goes to the console and to the copyable log.

| Failure | User-facing behavior |
| --- | --- |
| GitHub API rate limited | Message with reset time, fall back to local file selection (section 6.2) |
| Repository or ref not found (404) | Name what was not found; offer local file selection |
| Tree truncated | Warn that some files may be missing; continue |
| Individual blob fetch fails | Name the file, continue, list skipped files before Run |
| JavaScript library fails to load | Name the library, disable Run, state which component is missing (section 3.6) |
| Package has no wasm build | Preflight blocks the run and names the packages (section 9.2) |
| Package install fails mid-way | Name the package, offer retry, keep already-installed packages |
| webR fails to initialize | Detect WebAssembly support; if missing, state the browser requirement. Otherwise show the diagnostic and a "Clear cache and retry" action |
| Chunk error | Mark the chunk, show the condition message and chunk label, offer "Continue anyway" |
| Out of memory | Emscripten OOM appears as an abort. Catch it, state plainly that the dataset or package set exceeded the browser's memory, and suggest fewer packages or a smaller input |
| Storage quota exceeded | Report the estimate, offer "Clear cached R engine and packages" |
| Service worker unavailable | Continue without caching; note the slower repeat loads in Diagnostics |

Add a global watchdog: if no output arrives for `CONFIG.STALL_WARNING_MS`, default 120000, show a non-blocking notice that the run may be stalled and remind the user that Stop resets the engine. Do not auto-kill.

---

## 13. Configuration

A single frozen object at the top of `index.html`. No hard-coded values anywhere else.

```js
const CONFIG = Object.freeze({
  // Engine, pinned for reproducibility. See sections 3.5 and 3.6.
  // Import dist/webr.js, NOT dist/webr.mjs. Package is 'webr', not '@r-wasm/webr'.
  WEBR_VERSION:            '0.6.0',
  WEBR_BASE_URL:           'https://webr.r-wasm.org/v0.6.0/',
  WEBR_CDN_URL:            'https://cdn.jsdelivr.net/npm/webr@0.6.0/dist/webr.js',
  WEBR_REPO_URL:           'https://repo.r-wasm.org',
  CHANNEL_TYPE:            'postmessage',   // 'postmessage' | 'auto'

  // JavaScript libraries. Exact versions only. No SRI hashes; see section 3.6.
  CDN_ORIGIN:              'https://cdn.jsdelivr.net',
  LIB_VERSIONS:            Object.freeze({
    jsYaml:   '4.1.0',
    marked:   '15.0.7',
    domPurify:'3.2.4',
    fflate:   '0.8.2',
  }),

  // Repository sync
  GITHUB_API:              'https://api.github.com',
  GITHUB_RAW:              'https://raw.githubusercontent.com',
  FETCH_CONCURRENCY:       6,
  MAX_REPO_FILE_BYTES:     25 * 1024 * 1024,
  MAX_REPO_TOTAL_BYTES:    100 * 1024 * 1024,

  // Files supplied by URL or opened locally
  MAX_UPLOAD_FILE_BYTES:   250 * 1024 * 1024,

  // Virtual filesystem
  VFS_PROJECT_DIR:         '/home/web_user/project',
  MAX_VFS_DEPTH:           12,

  // Execution
  FIG_WIDTH_PX:            1008,
  FIG_HEIGHT_PX:           720,
  INSTALL_TIMEOUT_MS:      600000,
  STALL_WARNING_MS:        120000,
});
```

`TRUSTED_OWNERS`, `CACHEABLE_ORIGINS`, `CACHE_PREFIX`, and `SELF_HOST_WEBR` appeared in an earlier draft and are gone: the trust interstitial is dropped (section 5.4), there is no service worker to configure (section 4), and self-hosting is not a version 1 goal.

The library version numbers in `LIB_VERSIONS` are illustrative. Resolve the actual current versions at implementation time, pin them exactly, and keep `CONFIG` and the script tags in agreement.

---

## 14. Implementation Guidance

- Wrap every `webR.FS` call in `try/catch`. Emscripten path routing is strict and throws.
- Do not use Node built-ins such as `fs` or `path`. All file work goes through `webR.FS`.
- Never string-interpolate untrusted values into R source. Bind them as R objects (section 8.3) or pass them through `jsonlite`.
- Never assign anything derived from a repository, from R output, or from a filename to `innerHTML`. Prose goes through `DOMPurify`; everything else uses `textContent`.
- Revoke every `URL.createObjectURL` you create.
- Keep the R engine warm across runs within a session unless Stop was pressed. Re-initializing costs seconds.
- Instrument timings: engine init, package install, per chunk. Put them in the manifest. Performance complaints are otherwise unfalsifiable.
- Before adding any mechanism not named in this document, re-read section 0.1. The default answer is no.

---

## 15. Acceptance Criteria

The build is not done until all of the following pass on current versions of Chrome, Firefox, and Safari, on a normal, non cross-origin isolated GitHub Pages deployment.

**Single file by URL, the primary new capability:**

1. `?entry=<https URL to a .R file>` fetches and runs that file with no `repo` parameter present.
2. `?entry=<https URL to an .Rmd file>&data=<https URL to a CSV>` stages both, and the script reads the CSV by its basename with no user action beyond pressing Run.
3. `data=` accepts a repeated parameter and a comma-separated list, and honors the `<url>|<filename>` rename form.
3a. `data=data/` with `repo=` stages every file in that repository directory using the already-fetched tree, with no extra API call.
3b. A directory URL on a host with no directory index produces the specific message from section 5.1, not a silent no-op.
4. A URL on a host that does not send CORS headers produces the specific explanation from section 5.5 and an offer to open the file locally, not a generic network error.
5. Every staged file is listed with its source, and replacing any of them with a local file works and is announced.

**Reference case, `EMA-CleanR`:**

6. `?repo=DepressionCenter/EMA-CleanR` auto-detects `EMA-CleanR.rmd` as the entry point.
7. The nine `library()` packages plus `jsonlite` are detected by scanning and installed by a single `installPackages` call, with a specific named error if any is unavailable.
8. `params` exists in R before chunk one, with `input_file_has_headers` as logical `TRUE`, `ignore_surveys` as a 7-element character vector, and `unlist(params$ema_item_labels)` as a 13-element named character vector.
9. The user supplies their own `EMA-Data.csv`, it takes precedence over the repository copy, and the substitution is announced.
10. All 24 chunks execute in order, and `include=FALSE` on the setup chunk suppresses it from the report.
11. `dir.create("output")` succeeds and the six correlation CSVs are detected as outputs.
12. ggplot output appears as plots in the report.
13. Download all produces a ZIP containing outputs, report, log, manifest, and source.

**General:**

14. Reload after a successful run reuses the browser's HTTP cache rather than re-downloading the engine, verified in DevTools.
15. Stop and reset terminates the worker, and the app remains usable without a page reload.
16. Path traversal attempts in `entry`, in `data`, and in repository tree paths are rejected.
17. A `javascript:` or `data:` URL in `entry` or `data` is rejected with a specific message.
18. A repository with no `.R` or `.Rmd` produces a clear message, not a silent failure.
19. GitHub rate-limit exhaustion degrades to local file selection with the reset time shown.
20. `.Rmd` prose containing a `<script>` tag renders as inert text, confirming DOMPurify is applied.
21. The application is fully usable with no URL parameters at all, using only local files.
22. axe-core reports zero violations, and the manual accessibility checklist is completed and recorded.

**No longer acceptance criteria**, because the mechanisms they tested are deliberately gone per section 0.1: service worker cache-bucket invalidation, SRI hash tampering, and the owner trust interstitial.

---

## 16. Known Limitations, to be Documented in the README

1. No interruption of running R code on statically hosted deployments (section 3.2). Stop restarts the engine.
2. No pandoc, therefore no `rmarkdown::render()`, no PDF or Word output, and no byte-identical knitr report (sections 8.3 and 8.4).
3. No inline R (`` `r expr` ``) and no child documents in this version.
4. Only packages with precompiled WebAssembly binaries can be used. Source installation is impossible in webR.
5. Browser memory is finite and 32-bit. Very large datasets combined with heavy package sets will fail. `tidyverse` is expensive; scripts that import specific packages instead will run faster and use less memory.
6. Private repositories require opening the files locally.
7. File overwrites by the script are not detected by the output diff (section 10.1); use the file browser.
8. First run downloads a substantial amount of WebAssembly. Subsequent runs reuse the browser cache.
9. The application requires a network connection on first load, and thereafter for any package not already cached. It is not an offline-first application, and there is no service worker (section 4).
10. **A file can only be loaded from a URL if that host allows cross-origin reads.** Google Sites does not, and no change on ShareR's side can make that one work at all (it redirects to a login page). GitHub, GitLab, Bitbucket, Dropbox, Google Drive, OneDrive, and SharePoint all lack native CORS support on at least one of their hosts, but ShareR's CORS proxy fallback (section 5.5) can succeed for those, with no guarantee. GitHub Pages, `cdn.jsdelivr.net/gh/`, and any server you configure send the header directly and need no fallback. See section 5.5, which lists what was actually tested versus what is each vendor's documented behavior.
11. Directory listing by URL is best-effort outside of GitHub/GitLab/Bitbucket, because most web servers publish no index and there is no standard format for the ones that do (section 5.1). Dropbox, Google Drive, OneDrive, and SharePoint cannot be listed by URL at all — their folder views are rendered client-side and there is no key-free API to ask instead (section 5.6).
12. The Content Security Policy is deliberately permissive and is **not** a security boundary (sections 0.1 and 3.4). `'unsafe-eval'` is required by webR's Emscripten runtime and cannot be removed. The guarantee that user data is never transmitted rests on the source code containing no upload path, which is verifiable by reading it, not on the browser refusing one.
13. Clickjacking protection cannot be enforced from the page itself, because `frame-ancestors` is ignored in a `<meta>` policy. On a deployment target that cannot set response headers, such as GitHub Pages, ShareR can be framed by another site.
14. GitLab support requires the URL to expose its `/-/blob/`, `/-/raw/`, or `/-/tree/` marker (any host, including self-hosted); a bare self-hosted GitLab project-home URL cannot be recognized (section 5.1). Bitbucket support covers both `bitbucket.org` (Cloud) and self-hosted Bitbucket Server/Data Center (section 6.6).


## Contact

Mobile Technologies Core: efdc-mobiletech@umich.edu

[⬅ Back to README](https://github.com/DepressionCenter/ShareR/)

---

Copyright © 2026 The Regents of the University of Michigan