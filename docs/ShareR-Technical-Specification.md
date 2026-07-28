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

**ShareR's distinct claim:** point a URL at an *unmodified* GitHub repository containing plain `.R` or `.Rmd` files and run it against the visitor's own local data files, with zero build step on either side. Nobody has to install R, Quarto, or Node, and the script author does not have to change a single line of their analysis. Notably, ShareR is and will remain open source under a GPLv3 or later license.


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

- **Data locality.** Files the user supplies never leave the browser. There are no outbound requests carrying user data of any kind: no POST, no PUT, no beacon, no query-string payload, no analytics. This is enforced technically by a Content Security Policy `connect-src` allowlist (section 3.4), not by convention.
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
| Caching | Service Worker plus Cache Storage, version-keyed | Section 4. |

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
3. It forces a page reload on first visit and it collides with the caching service worker in section 4.

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

A service worker must be a separate same-origin file at or above the scope it controls, so the application cannot be a literally single file. Target layout:

```
ShareR/
  index.html            # the SPA: markup, CONFIG, all application JS and inline CSS hooks
  sw.js                 # caching service worker (separate file; scope = ./)
  .nojekyll
  AGENTS.md
  README.md
  LICENSE
  NOTICE
  .gitignore
  styles/
    um-style.css        # shared UM navy and maize styles
  images/
    ShareR-logo-wide.png
    ShareR-preview.png
  docs/
    ShareR-Technical-Specification-v1.md
    quick-start.md
    architecture.md
    dependencies.md     # pinned versions and SRI hashes, section 3.6
    security-privacy-accessibility.md
  bin/                  # ZippyServe binaries, copied from DepressionCenter/ZippyServe
  run-windows.ps1
  run-linux.sh
  run-mac.command
```

Ship this CSP as a `<meta http-equiv="Content-Security-Policy">` in `index.html`. This is the technical enforcement of section 2.2:

```
default-src 'none';
script-src 'self' 'wasm-unsafe-eval' 'unsafe-eval'
           https://cdn.jsdelivr.net https://webr.r-wasm.org;
worker-src 'self' blob: https://webr.r-wasm.org;
connect-src 'self' https://webr.r-wasm.org https://repo.r-wasm.org
            https://cdn.jsdelivr.net
            https://api.github.com https://raw.githubusercontent.com;
style-src 'self' 'unsafe-inline';
img-src 'self' data: blob:;
font-src 'self';
form-action 'none';
base-uri 'none';
```

`connect-src` is an allowlist of five origins that receive only GET requests. Any code path, including a future dependency, that attempts to send data anywhere else fails at the browser level. Say so explicitly in the security documentation, because it is the strongest privacy claim ShareR can honestly make.

**Three corrections to an earlier draft of this policy, all established empirically during the Stage 1 proof of concept by bisecting the policy against a working no-CSP control page.** A CSP that omits any of them does not merely warn; the first two prevent R from starting at all, and the failure is silent and extremely hard to read.

1. **`script-src` must list `https://webr.r-wasm.org`.** The webR worker loads its Emscripten glue (`R.js`) with `importScripts()`, which CSP evaluates against `script-src` (falling back from an unset `script-src-elem`), **not** `worker-src`. Without it the console reports a blocked script load and engine startup hangs forever.

2. **`script-src` must include `'unsafe-eval'`.** This is the non-obvious one. `'wasm-unsafe-eval'` permits WebAssembly compilation but **not** `eval()`, and Emscripten's `EM_JS` support (`addEmJs()` inside `R.js`) constructs JavaScript functions from source strings embedded in the wasm binaries and instantiates them with a literal `eval()`. That code path runs while loading the side modules `libRblas.so` and `libRlapack.so`, so without `'unsafe-eval'` R aborts inside `loadDylibs` and throws a bare `WebAssembly.Exception`, which browsers render as `#<Exception>` with **no message, no file, and no line number**. Budget for this: the symptom is indistinguishable from a network failure and is easy to misdiagnose as one.

   State the tradeoff honestly in the security documentation rather than burying it. `'unsafe-eval'` weakens the cross-site-scripting posture, because script that already executes can call `eval()`. It does **not** weaken the data-locality guarantee in section 2.2, which is enforced by `connect-src` and is unchanged: no code, evaled or otherwise, can transmit bytes to an origin outside the allowlist. Keep the inline application script pinned by SHA-256 hash so injected inline script is still refused, and revisit this if webR ever ships a `DYNAMIC_EXECUTION=0` build.

3. **Do not put `frame-ancestors` in the `<meta>` policy.** Browsers ignore it when delivered that way and log a warning for every document that parses the policy, so it provides zero clickjacking protection while adding console noise that masks real errors. Clickjacking protection must come from a real response header (`Content-Security-Policy: frame-ancestors` or `X-Frame-Options`) set by whatever serves ShareR. GitHub Pages cannot set it, which is the same limitation that forces the `PostMessage` channel in section 3.2. Document the residual risk instead of pretending the directive is active.

**Two console messages are expected and benign.** Record them here so future maintainers do not re-investigate what has already been chased down:

- `Refused to get unsafe header "Content-Encoding"`, emitted by `R.js`. Emscripten's lazy-file loader probes that header to detect gzip, and CORS does not expose it cross-origin. Verified harmless: the lazily loaded files are served uncompressed and their `Content-Length` equals their true byte length, so the size arithmetic the loader actually depends on is correct.
- ``WebR is using `PostMessage` communication channel, nested R REPLs are not available.`` This is the documented and intended tradeoff from section 3.2.

Pin `script-src` to the single CDN actually used. Do not use a wildcard and do not list several CDNs "just in case"; each additional origin is an additional origin that could serve executable code into the page.

If `CONFIG.SELF_HOST_WEBR` is enabled, drop `webr.r-wasm.org` from the policy.

### 3.5 Reproducibility: pin everything

Research code that produces different numbers on different days is a defect. Pin, in `CONFIG`:

- `WEBR_VERSION`, for example `'0.6.0'`, and derive `WEBR_BASE_URL = 'https://webr.r-wasm.org/v' + WEBR_VERSION + '/'`. **Never point at `latest/`.**
- `WEBR_REPO_URL`, and the R minor version its package index is built for.
- Every JavaScript library version, as an exact version in the URL. Never `@latest`, never a range.

Every run emits `run-manifest.json` into the results ZIP (section 10.4) recording the ShareR version, webR version, R version from `R.version.string`, the resolved repository commit SHA, the entry file path, the SHA-256 of every input file, the installed package name and version list, wall-clock duration, and per-chunk status. This is what makes an in-browser run defensible in a methods section.

### 3.6 JavaScript dependencies: pinned CDN with Subresource Integrity

Load `js-yaml`, `marked`, `DOMPurify`, and `fflate` from a single pinned CDN. Every tag carries an exact version, an `integrity` attribute, and `crossorigin="anonymous"`:

```html
<script src="https://cdn.jsdelivr.net/npm/js-yaml@4.1.0/dist/js-yaml.min.js"
        integrity="sha384-REPLACE_WITH_ACTUAL_HASH"
        crossorigin="anonymous"></script>
```

Rules:

- **Exact versions only.** `@4.1.0`, never `@4`, never `@latest`. A floating version silently changes the code running against participant data.
- **`integrity` is mandatory.** Without it, CDN sourcing is a real integrity gap. With it, the browser refuses to execute any file whose hash does not match, so a compromised or swapped CDN asset fails closed instead of running. This is what makes the CDN approach equivalent in integrity to a local copy.
- **`crossorigin="anonymous"` is mandatory**, because SRI validation requires a CORS-enabled response.
- **Generate the hashes; do not copy them from a web page.** For each pinned URL:

  ```
  curl -sL <url> | openssl dgst -sha384 -binary | openssl base64 -A
  ```

  Prefix the result with `sha384-`.
- **Record every pin in `docs/dependencies.md`**: library name, exact version, full URL, SRI hash, license, and upstream project URL. Regenerate and update that file in the same commit as any version bump. A version bump with a stale hash is a hard failure at load time, which is the intended behavior.
- **Fail loudly.** If a library fails to load, whether from an outage or an integrity mismatch, show a specific error naming the library rather than a generic broken page, and disable Run. Detect this by checking for the expected global (`jsyaml`, `marked`, `DOMPurify`, `fflate`) after load rather than relying on `onerror` alone.

The webR core also loads from its own pinned CDN URL. It is a large multi-file WebAssembly distribution loaded by webR's own loader rather than a single script tag, so SRI does not apply to it; version pinning plus the service worker cache is the integrity and stability story there.

**Which webR artifact to import, verified against the live registry and CDN during Stage 1.** Two easy mistakes here each cost a debugging cycle:

- **The npm package is `webr`, not `@r-wasm/webr`.** The scoped package was renamed and is now deprecated upstream; it is frozen at `0.2.0` and will never carry a current release. Resolve versions against `webr`.
- **Import `dist/webr.js`, not `dist/webr.mjs`.** The `.mjs` file is the bundler-target ESM build and carries a static top-level `import { createRequire } from 'module'`. A browser cannot resolve the bare Node builtin `module`, so importing it fails immediately with `Failed to resolve module specifier "module"`. `dist/webr.js` is the package's `browser` exports-condition build and has no Node-only bare specifiers. Note that `dist/webr.js` was introduced in `0.6.0`; earlier releases such as `0.5.4` ship only `.mjs`/`.cjs` and therefore cannot be loaded directly in a browser from a CDN. This is an additional reason the pin cannot drift backwards.

At the pinned `WEBR_VERSION` of `0.6.0`, webR reports R **4.6.0**, and its own built-in default `baseUrl` is already `https://webr.r-wasm.org/v0.6.0/`. Set `WEBR_BASE_URL` explicitly anyway, per section 3.5, so a webR upgrade cannot silently move the engine URL. Use the R version to key the package cache bucket described in section 4.2, and read it at runtime rather than hard-coding it.

Licensing note, which is the reason for this approach as much as integrity is: linking to a CDN-hosted library is not redistribution, so ShareR does not take on the notice-preservation and file-level obligations that shipping copies of Apache-2.0, MPL-2.0, and MIT files in a GPLv3 repository would create. Attribution in the README remains appropriate and is done regardless. If a future requirement forces genuinely offline operation and the libraries must be served from the repository, revisit those obligations deliberately at that point. webR itself is GPL-3, which composes cleanly with ShareR's own GPLv3 licensing should self-hosting ever be enabled.

---

## 4. Caching

### 4.1 No time-to-live

With `WEBR_VERSION` pinned per section 3.5, every engine URL is immutable, and package binary URLs under `repo.r-wasm.org/bin/emscripten/contrib/<Rver>/` are likewise versioned. A time-based cache expiry would therefore force a periodic multi-tens-of-megabyte re-download that can only ever return byte-identical content, and, worse, it would open the possibility that two runs a week apart use different engine builds. That defeats section 3.5. Cache by version, not by clock.

### 4.2 Design

- Cache Storage bucket names embed the pinned versions: `sharer-webr-v<WEBR_VERSION>` and `sharer-pkgs-v<R_MINOR>`.
- The service worker serves **cache-first with no revalidation** for any URL whose origin is in `CONFIG.CACHEABLE_ORIGINS`.
- Upgrading `WEBR_VERSION` in `CONFIG` changes the bucket name. On `activate`, the worker deletes every `sharer-*` bucket not in the current expected set. That is the whole invalidation story: no timestamps, no IndexedDB bookkeeping, no expiry logic.
- The app shell (`index.html`, `sw.js`, `styles/`) uses **network-first with cache fallback**, so a redeploy is picked up immediately and the app still opens when offline.
- CDN library URLs are cache-first as well, keyed by the exact pinned URL. Because SRI validates them on every load, a cached copy that has been tampered with still fails closed.

### 4.3 Cache transparency

Researchers on managed laptops with small disks need to see and control this. Provide a Diagnostics panel with:

- Estimated cache use via `navigator.storage.estimate()`, displayed as "ShareR has cached about N MB of the R engine and packages."
- A "Clear cached R engine and packages" button that deletes all `sharer-*` buckets.
- `navigator.storage.persist()` called at startup, so the browser is less likely to silently evict a large package cache mid-session, with the returned boolean shown.
- The active communication channel (`SharedArrayBuffer` or `PostMessage`) and whether `crossOriginIsolated` is true.
- The pinned webR version, R version, and the resolved library versions.

### 4.4 Service worker lifecycle

Register with a relative URL so GitHub Pages project sites, served from `/ShareR/`, get the correct scope:

```js
navigator.serviceWorker.register('./sw.js', { scope: './' });
```

Use `skipWaiting()` plus `clients.claim()` only on explicit user action ("Update available. Reload to apply."), never automatically mid-run. Swapping the worker while R is streaming output is a real way to corrupt a session. If registration fails, for example in private browsing, with workers disabled, or over `file://`, the app must still work with HTTP caching only. Log the degradation to Diagnostics; do not block startup.

---

## 5. URL Parameters, Routing, and Input Validation

### 5.1 Parameters

| Parameter | Example | Default |
| --- | --- | --- |
| `repo` | `DepressionCenter/EMA-CleanR` | none; absent means upload mode |
| `ref` | `main`, `v1.2.0`, or a 40-character SHA | repository default branch |
| `branch` | alias for `ref`, accepted for convenience | |
| `entry` | `EMA-CleanR.rmd` | auto-detected, section 5.3 |
| `autorun` | `1` | `0`. When `1`, run immediately after preflight passes. |
| `script` | `EMA-CleanR.rmd` | alias for `entry`, so also auto-detected, section 5.3 |

+ The `repo` parameter should support full github URLs (e.g. https://github.com/DepressionCenter/ShareR with or without trailing slash), @ name references plus repo name (@DepressionCenter/ShareR - simply ignore the `@` symbol), or simply the owner plus repo name (DepressionCenter/ShareR).
+ The `entry` paramter should support URLs to R and Rmd files hosted over plain HTTP/HTTPS, over a localhost web server, and simple file names or relative file path+file name to load from a repo.
+ The `script` parameter is an alias for the `entry` parameter, and users can use either one. The code will internally change `script` to `entry` (or use only `entry` if both are provided and both are non-empty).

### 5.2 Validation

Every parameter is untrusted input interpolated into a URL and, for `entry`, into a VFS path. Validate with allowlists and reject on failure with a visible, specific error:

```js
const RE_REPO  = /^[A-Za-z0-9][A-Za-z0-9._-]{0,99}\/[A-Za-z0-9][A-Za-z0-9._-]{0,99}$/;
const RE_REF   = /^[A-Za-z0-9._\/-]{1,255}$/;
const RE_ENTRY = /^[A-Za-z0-9._\/-]{1,255}$/;
```

Additionally reject any `ref` or `entry` that contains `..`, begins with `/`, contains a backslash, or contains a percent sign. Resolve every VFS write path through a normalizer and assert the result still begins with the run's working directory prefix before writing. A repository is untrusted content; a crafted path in a tree listing must not be able to write outside the sandbox root.

### 5.3 Entry point auto-detection

When `repo` is given and `entry` is not:

1. If the repository root contains `sharer.json`, honor its `entry` field. This is the escape hatch for repository authors and it costs nothing to support.
2. Otherwise look in the root, case-insensitively, for `main.R`, `run.R`, `main.Rmd`, `run.Rmd`, in that order (case insensitive).
3. Otherwise collect all `.R` and `.Rmd` files, excluding anything matched by `.sharerignore` (section 6.5) and excluding conventional non-entry directories: `tests/`, `test/`, `man/`, `R/`, `inst/`, `vignettes/`, `renv/`, `packrat/`. If exactly one remains, use it.
4. Otherwise open an in-app modal listing the candidates, sorted with root-level files first and `.Rmd` before `.R`, and ask the user to choose. The modal must be keyboard navigable and must trap focus.

Selecting from the modal updates the URL via `history.replaceState()` so the resulting link is shareable. This matters: shareability is the product.

### 5.4 Owner trust gate

Because `?repo=` accepts any repository, ShareR is a general-purpose runner for arbitrary third-party R code. That code runs inside the WebAssembly sandbox and cannot touch the host machine, but it can read anything the user drags in, and it can render author-controlled markdown.

Add `CONFIG.TRUSTED_OWNERS = ['DepressionCenter']`. When the requested owner is not on the list, show a blocking interstitial before any fetch:

> You are about to run code from `owner/repo`, which is not published by the Eisenberg Family Depression Center. The code runs in a sandbox in your browser and cannot access your computer, but it can read any file you add to this page. Only continue if you trust the author.

with Continue and Cancel. This is cheap, it is honest, and it is the difference between a tool and an open redirect for arbitrary code execution.

---

## 6. Repository Synchronization

### 6.1 Listing

```
GET https://api.github.com/repos/{owner}/{repo}/git/trees/{ref}?recursive=1
```

Send `Accept: application/vnd.github+json`. Do **not** send credentials. Never accept a token via URL parameter and never store one; that would put a secret in a shareable link, which `AGENTS.md` section 7 forbids outright. Private repositories are supported through upload mode only, and the README must say so.

Handle `tree.truncated === true`: the API caps large trees. If truncated, fall back to listing the entry file's directory via the Contents API and warn the user that helper files elsewhere in the repository may be missing.

### 6.2 Rate limits

Only `api.github.com` requests count against GitHub's 60-per-hour unauthenticated limit. File contents are fetched from `raw.githubusercontent.com`, which is a separate service and is not subject to that quota. ShareR therefore uses **one** rate-limited request per run.

Read `X-RateLimit-Remaining` and `X-RateLimit-Reset` from the tree response and surface them in Diagnostics. On HTTP 403 with `X-RateLimit-Remaining: 0`, show: "GitHub's anonymous request limit is reached for your network. It resets at HH:MM. You can still run your analysis now by uploading the script and your data files directly." Then switch the UI to upload mode. A graceful error state is not the same as a dead end.

Cache the resolved tree JSON in IndexedDB keyed by `owner/repo@sha`, so re-running the same pinned ref costs zero API calls.

### 6.3 Fetching contents

- Resolve `ref` to a commit SHA first, then fetch everything at that SHA. This makes a run reproducible and immune to a mid-run push.
- Fetch each blob from `https://raw.githubusercontent.com/{owner}/{repo}/{sha}/{path}`.
- **Always fetch as `arrayBuffer()`, never as `text()`.** Formats such as `.rds` and `.xlsx` are binary and would be silently corrupted by UTF-8 decoding. Write bytes and let R decide the encoding.
- Concurrency capped at `CONFIG.FETCH_CONCURRENCY`, default 6. Retry each blob twice with exponential backoff and jitter. Report per-file failures individually rather than failing the whole sync.
- Skip files larger than `CONFIG.MAX_REPO_FILE_BYTES`, default 25 MB, with a visible warning naming the file. Skip `.git/`, `.github/`, and anything matched by `.sharerignore`.
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

### 6.5 `.sharerignore`

Support an optional `.sharerignore` at the repository root using gitignore-style patterns. Repositories such as `EMA-CleanR` ship a large rendered `.html` output and screenshot images that nobody needs in the VFS. Honoring an ignore file makes ShareR polite about bandwidth and gives repository authors control without changing their analysis code.

---

## 7. Upload Mode

When no `repo` is present, or when repository sync fails, ShareR shows the local execution view.

- A drag-and-drop zone that is also a real `<button>` opening a file picker, and that accepts paste. A drop-only zone is an accessibility failure.
- Accept a whole folder via `webkitdirectory` where supported, since analyses usually have helper files.
- Accept `.R`, `.Rmd`, and any data files. Detect the entry using the same rules as section 5.3.
- Read each file with `File.arrayBuffer()` and write bytes with `webR.FS.writeFile`. Never `FileReader.readAsText`, for the reason in section 6.3.
- Enforce `CONFIG.MAX_UPLOAD_FILE_BYTES`, default 250 MB, per file, checked against `navigator.storage.estimate()` before accepting, with a clear message if the browser cannot hold it.
- Files land in `/home/web_user/project/`, preserving relative paths from a folder drop.
- Show every staged file in a removable list with name and size. Users need to see what they gave the app. This list is also the honest answer to "what does this thing have access to."

**Mixed mode is required, not optional.** The headline use case is "run `EMA-CleanR` from GitHub with *my own* data", so repository sync and local upload must compose: repository files first, then user files written on top, with a visible warning when a user file overwrites a repository file of the same name. `EMA-CleanR` ships a sample `EMA-Data.csv`, and a researcher dropping in their own `EMA-Data.csv` is the primary workflow.

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

Statically scan all chunk source and any sourced `.R` files for `library(x)`, `require(x)`, `requireNamespace("x")`, and `x::`. Deduplicate. Exclude base and recommended packages already present in the webR image.

Also honor an optional `sharer.json` in the repository root, which lets an author be explicit and skip the guesswork:

```json
{
  "entry": "EMA-CleanR.rmd",
  "packages": ["dplyr", "psych", "tidyverse", "lubridate", "table1",
               "corrplot", "ggplot2", "patchwork", "rlang", "jsonlite"],
  "repos": ["https://repo.r-wasm.org"],
  "dataFiles": ["EMA-Data.csv"]
}
```

### 9.2 Resolution

Fetch the repository's `PACKAGES` index once per session, cache it, and resolve the transitive `Depends` and `Imports` closure locally. Then show a preflight panel before the run starts:

- Packages already present.
- Packages to be downloaded, with a count and an approximate total size.
- **Packages not found in any configured repository**, listed by name, with a clear message: "These packages have no WebAssembly build available, so this script cannot run in the browser. Ask the script author to substitute them, or build wasm binaries with the `rwasm` package and add the repository URL below."

Allow the user to add extra repository URLs, for example an R-universe repository such as `https://<owner>.r-universe.dev`, persisted in `localStorage`. This is what makes ShareR usable beyond whatever packages `repo.r-wasm.org` happens to carry.

**Do not assert in code or documentation that any specific package is available.** Availability changes and is not ours to promise. Resolve it at runtime and report what is actually there. This applies to every package in the reference script, `table1` and `psych` included.

### 9.3 Installation

Install the whole resolved set in one `webR.installPackages(list)` call, streaming progress to the log. Service worker cache hits make the second run fast; state the expected first-run cost in the UI: "First run downloads roughly N MB of R packages. Later runs use the cached copy."

Guard the wall clock with `CONFIG.INSTALL_TIMEOUT_MS`, default 600000. On timeout, stop and offer to retry rather than hanging indefinitely.

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

**Known limitation, disclosed rather than hidden:** `FSNode` exposes no size and no mtime, so a script that *overwrites* an existing file produces no detectable diff. Ship all three mitigations:

1. Additionally treat everything under the resolved `output_dir` parameter, when the script declares one, as an output regardless of the diff.
2. Provide a full file browser over `/home/web_user/project` so the user can download any file, generated or not.
3. Record a SHA-256 of each input file at write time, so the run manifest can at least flag inputs that changed.

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
| GitHub API rate limited | Message with reset time, automatic switch to upload mode (section 6.2) |
| Repository or ref not found (404) | Name what was not found; offer upload mode |
| Tree truncated | Warn that some files may be missing; continue |
| Individual blob fetch fails | Name the file, continue, list skipped files before Run |
| JavaScript library fails to load or fails SRI | Name the library, disable Run, state that a required component could not be verified (section 3.6) |
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
  // Engine, pinned for reproducibility. See spec section 3.5.
  WEBR_VERSION:            '0.6.0',
  WEBR_BASE_URL:           'https://webr.r-wasm.org/v0.6.0/',
  WEBR_REPO_URL:           'https://repo.r-wasm.org',
  SELF_HOST_WEBR:          false,
  CHANNEL_TYPE:            'postmessage',   // 'postmessage' | 'auto'

  // JavaScript libraries. Exact versions only; SRI hashes live in index.html
  // script tags and are documented in docs/dependencies.md. See section 3.6.
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
  TRUSTED_OWNERS:          ['DepressionCenter'],
  FETCH_CONCURRENCY:       6,
  MAX_REPO_FILE_BYTES:     25 * 1024 * 1024,
  MAX_REPO_TOTAL_BYTES:    100 * 1024 * 1024,

  // Local files
  MAX_UPLOAD_FILE_BYTES:   250 * 1024 * 1024,

  // Virtual filesystem
  VFS_PROJECT_DIR:         '/home/web_user/project',
  MAX_VFS_DEPTH:           12,

  // Execution
  FIG_WIDTH_PX:            1008,
  FIG_HEIGHT_PX:           720,
  INSTALL_TIMEOUT_MS:      600000,
  STALL_WARNING_MS:        120000,

  // Caching
  CACHEABLE_ORIGINS:       ['https://webr.r-wasm.org',
                            'https://repo.r-wasm.org',
                            'https://cdn.jsdelivr.net'],
  CACHE_PREFIX:            'sharer-',
});
```

The library version numbers in `LIB_VERSIONS` are illustrative. Resolve the actual current versions at implementation time, pin them exactly, generate their SRI hashes per section 3.6, and keep `CONFIG`, the script tags, and `docs/dependencies.md` in agreement.

---

## 14. Implementation Guidance

- Wrap every `webR.FS` call in `try/catch`. Emscripten path routing is strict and throws.
- Do not use Node built-ins such as `fs` or `path`. All file work goes through `webR.FS`.
- Never string-interpolate untrusted values into R source. Bind them as R objects (section 8.3) or pass them through `jsonlite`.
- Never assign anything derived from a repository, from R output, or from a filename to `innerHTML`. Prose goes through `DOMPurify`; everything else uses `textContent`.
- Revoke every `URL.createObjectURL` you create.
- Keep the R engine warm across runs within a session unless Stop was pressed. Re-initializing costs seconds.
- Do not register `skipWaiting` on the service worker automatically during a run (section 4.4).
- Instrument timings: engine init, package install, per chunk. Put them in the manifest. Performance complaints are otherwise unfalsifiable.

---

## 15. Acceptance Criteria

The build is not done until all of the following pass on current versions of Chrome, Firefox, and Safari, on a normal, non cross-origin isolated GitHub Pages deployment.

**Reference case, `EMA-CleanR`:**

1. `?repo=DepressionCenter/EMA-CleanR` auto-detects `EMA-CleanR.rmd` as the entry point.
2. Preflight lists the nine `library()` packages plus `jsonlite`, resolves their dependency closure, and either reports a total download size or names precisely which packages have no wasm build.
3. `params` exists in R before chunk one, with `input_file_has_headers` as logical `TRUE`, `ignore_surveys` as a 7-element character vector, and `unlist(params$ema_item_labels)` as a 13-element named character vector.
4. The user drops in their own `EMA-Data.csv`, it overwrites the repository copy, and the overwrite is announced.
5. All 24 chunks execute in order, and `include=FALSE` on the setup chunk suppresses it from the report.
6. `dir.create("output")` succeeds and the six correlation CSVs are detected as outputs.
7. ggplot output appears as plots in the report.
8. Download all produces a ZIP containing outputs, report, log, manifest, and source.
9. The run manifest records the resolved commit SHA, webR version, R version, and package versions.

**General:**

10. Reload after a successful run pulls the engine and packages from cache with no network fetch to `webr.r-wasm.org`, verified in DevTools.
11. Stop and reset terminates the worker, and the app remains usable without a page reload.
12. Bumping `WEBR_VERSION` invalidates old cache buckets on next activate.
13. Every CDN script tag has an exact version, an `integrity` attribute, and `crossorigin="anonymous"`; corrupting one hash by hand blocks that library and produces the named error from section 12, not a blank page.
14. `?repo=` pointing at an untrusted owner shows the interstitial before any fetch.
15. Path traversal attempts in `entry` and in tree paths are rejected.
16. A repository with no `.R` or `.Rmd` produces a clear message, not a silent failure.
17. Rate-limit exhaustion degrades to upload mode.
18. axe-core reports zero violations, and the manual accessibility checklist is completed and recorded.
19. With service workers unavailable, the app still runs.

---

## 16. Known Limitations, to be Documented in the README

1. No interruption of running R code on statically hosted deployments (section 3.2). Stop restarts the engine.
2. No pandoc, therefore no `rmarkdown::render()`, no PDF or Word output, and no byte-identical knitr report (sections 8.3 and 8.4).
3. No inline R (`` `r expr` ``) and no child documents in this version.
4. Only packages with precompiled WebAssembly binaries can be used. Source installation is impossible in webR.
5. Browser memory is finite and 32-bit. Very large datasets combined with heavy package sets will fail. `tidyverse` is expensive; scripts that import specific packages instead will run faster and use less memory.
6. Private repositories require upload mode.
7. File overwrites by the script are not detected by the output diff (section 10.1); use the file browser.
8. First run downloads a substantial amount of WebAssembly. Subsequent runs are cached.
9. The application requires a network connection on first load, and thereafter for any package not already cached. It is not an offline-first application.
10. The Content Security Policy must allow `'unsafe-eval'`, because webR's Emscripten runtime evaluates JavaScript embedded in its WebAssembly binaries (section 3.4). This is a genuine, disclosed weakening of the cross-site-scripting posture. It does not affect the data-locality guarantee, which is enforced separately by `connect-src`.
11. Clickjacking protection cannot be enforced from the page itself, because `frame-ancestors` is ignored in a `<meta>` policy (section 3.4). On a deployment target that cannot set response headers, such as GitHub Pages, ShareR can be framed by another site.


## Contact

Mobile Technologies Core: efdc-mobiletech@umich.edu

[⬅ Back to README](https://github.com/DepressionCenter/ShareR/)

---

Copyright © 2026 The Regents of the University of Michigan