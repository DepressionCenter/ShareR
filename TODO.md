# ShareR: Two-Stage Build Plan

## Context

This plan merges two things: the existing `ShareR: Two-Stage Build Plan` (Stage 1 and Stage 2A/2B are complete; Stage 2C — accessibility/errors/docs — was next) and a new batch of UI/UX requests gathered directly from the running app (`index.html`, 4820 lines) plus `docs/ShareR-UI-Specification.md`. Rather than bolt the new UI work on after accessibility hardening (which would mean auditing accessibility twice — once for the current UI, once again for the new components), the UI/UX work is inserted **before** the renumbered accessibility stage, so that stage's a11y/error audit covers the final UI in one pass. A comment-cleanup pass bookends the new work per explicit instruction: once at the very start (stale "Stage 1/2A/2B" build-process comments already exist in the shipped code and should not multiply), and once at the very end (new code written during this plan will inevitably need the same scrub).

Everything through "Stage 2B" below is unchanged historical record — do not re-open it. New/changed content starts at **Stage 2C**.

---

## Stage 1 - Proof of Concept (quick and dirty, throwaway)

**Goal:** prove webR actually executes, under the exact channel and CSP constraints the spec mandates, on this static-hosting setup - before any other architecture is built.

**Scope, deliberately minimal:**

- Rewrite `index.html` (currently the stub) as a minimal semantic single page: `<header>` with title, `<main>` with a `<textarea>` pre-filled with a tiny sample script (adapt `src/code-sample-r.R`'s `print('Hello World')` plus one more line such as `summary(1:10)` so more than trivial output is proven), a Run button, a Stop button, and a `<pre role="log" aria-live="polite">` output region, plus a one-line status indicator (Idle / Loading engine / Running / Done / Error).
- Keep the required EFDC file header at the top of `index.html`.
- A small frozen `CONFIG` object with just what Stage 1 needs: `WEBR_VERSION: '0.6.0'`, `WEBR_BASE_URL` derived from it (`https://webr.r-wasm.org/v0.6.0/`), the CDN URL for `webr.mjs` (`https://cdn.jsdelivr.net/npm/webr@0.6.0/dist/webr.mjs` - package `webr`, not the deprecated `@r-wasm/webr`), and `CHANNEL_TYPE: 'postmessage'`.
- A real CSP `<meta>` tag, scoped to only what Stage 1 needs (this part is *not* throwaway - it carries forward): `script-src 'self' 'wasm-unsafe-eval' https://cdn.jsdelivr.net`, `worker-src 'self' blob: https://webr.r-wasm.org`, `connect-src 'self' https://webr.r-wasm.org https://cdn.jsdelivr.net`, plus the other locked-down directives from spec section 3.4 (`style-src 'self' 'unsafe-inline'`, `img-src 'self' data: blob:`, `font-src 'self'`, `form-action 'none'`, `base-uri 'none'`, `frame-ancestors 'none'`, `default-src 'none'`). `api.github.com` / `raw.githubusercontent.com` are added in Stage 2 when repo sync lands.
- JS: dynamically `import` `WebR` from the pinned CDN URL, lazily instantiate `new WebR({ channelType: ChannelType.PostMessage, baseUrl: CONFIG.WEBR_BASE_URL })` on first Run (keep the engine warm across runs per spec section 14), run the textarea's code via `new webR.Shelter()` + `shelter.captureR(code, { withAutoprint: true, captureStreams: true, captureConditions: true })` per spec section 8.1, append each output entry to the log distinguishing stdout/stderr/error by both a text prefix and color (cheap to do right from the start, matches spec section 10.3's "color is never the only indicator"). Stop = `webR.close()` then discard the reference so the next Run re-initializes, per spec section 3.2's "terminate and restart" pattern - label it "Stop and reset R" with the honest helper text from the spec, not a plain "Stop".
- Explicitly **not** in Stage 1: file upload, GitHub sync, `.Rmd` support, package installation, VFS diffing/outputs, plot capture, service worker, ZIP download, modals. These all land in Stage 2.

**Files touched:** `index.html` only.

**Verification:**
- Serve locally via `.\run-windows.ps1` (wraps `bin\ZippyServe.exe`) and open in a real browser.
- Manually confirm: no CSP violations in the console, Run shows "Loading engine..." then correct output text, Stop terminates and a subsequent Run re-initializes cleanly.
- No browser-automation tool is available in this environment, so in-browser behavior needs a manual check (or the `/run` skill if it can drive a real browser) - this will be stated plainly rather than claimed as tested, per `AGENTS.md` section 11.

### STAGE 1 STATUS: COMPLETE AND CONFIRMED WORKING (2026-07-27)

R executes in the browser under the full CSP and the `PostMessage` channel, verified by the user in Firefox 153 on a ZippyServe-hosted `http://localhost:8010`.

**Four defects were found and fixed during Stage 1, all of them in the spec's own instructions rather than in the implementation of them. `docs/ShareR-Technical-Specification.md` has been corrected for each; Stage 2 must use the corrected spec, not the original text.**

1. **npm package renamed.** `@r-wasm/webr` is deprecated and frozen at `0.2.0`; the live package is `webr`. (Spec 3.6)
2. **Wrong build imported.** `dist/webr.mjs` is the bundler build and has a static `import ... from 'module'` that no browser can resolve. Use `dist/webr.js`, the browser exports-condition build, which exists only from `0.6.0` onward. (Spec 3.6)
3. **CSP `script-src` omitted `https://webr.r-wasm.org`.** webR's worker `importScripts()` its `R.js` glue, which CSP evaluates against `script-src`, not `worker-src`. (Spec 3.4)
4. **CSP `script-src` omitted `'unsafe-eval'` - the expensive one.** `'wasm-unsafe-eval'` does not permit `eval()`, and Emscripten's `EM_JS` support (`addEmJs()` in `R.js`) builds JS functions from strings embedded in the wasm and runs them through a literal `eval()` while loading `libRblas.so`/`libRlapack.so`. Without it R aborts in `loadDylibs` throwing a bare `WebAssembly.Exception`, which the browser prints as `#<Exception>` with no message, file, or line. (Spec 3.4)

Also removed `frame-ancestors` from the `<meta>` CSP: browsers ignore it there, so it bought nothing and emitted five console warnings per load that masked real errors. Clickjacking protection now documented as a deployment-header responsibility and listed as a known limitation. (Spec 3.4, 16)

**Process lessons worth carrying into Stage 2:**

- **Bisect the environment before theorising about it.** Defect 4 was found in one step by loading an identical page with no CSP at all. Before that, several rounds went into gzip-truncation, `Range`-request preflight, and CORS-header theories - all of which were disproved by direct `curl` tests and none of which were the cause. When something fails opaquely, first establish a known-good control, then reintroduce constraints one at a time.
- **A strict CSP plus a SHA-256 inline-script hash was too much machinery for a throwaway proof of concept.** It is correct for the real application and is being kept, but it meant every edit required recomputing the hash, and it was itself the thing that was broken. For future spike work, prove the risky dependency first with the constraints off, then add the constraints back deliberately.
- Two webR console messages are expected and benign; both are now documented in spec 3.4 so they are not re-investigated: `Refused to get unsafe header "Content-Encoding"` (Emscripten gzip probe; verified irrelevant because the lazily loaded files are uncompressed and their `Content-Length` is accurate) and the `PostMessage` nested-REPL notice (the intended tradeoff from spec 3.2).

---

## Specification revised before Stage 2 (2026-07-27)

After Stage 1, the user directed a significant simplification and two feature additions. `docs/ShareR-Technical-Specification.md` was substantially rewritten; **the spec is now the authority and this plan should not be read as overriding it.** New section **0.1 "Design principle: keep it simple"** is the highest-priority instruction in the document.

**Removed from the spec as over-engineering.** Do not reintroduce any of these:

| Removed | Why |
| --- | --- |
| CSP as a privacy control (strict `connect-src` allowlist, SHA-256 inline-script hash) | It broke webR twice, produced an error with no message, and consumed most of a session. Data locality is a property of the source code, not a browser control. CSP is now deliberately permissive hygiene. |
| Service worker + Cache Storage version-keyed buckets (old section 4) | Pinned engine URLs are immutable, so the browser's HTTP cache already does this. Also removes the mid-run worker-update failure mode. |
| Subresource Integrity hashes | Regeneration friction on every version bump; defends a threat this static tool does not face. |
| Local dependency-closure resolution from the `PACKAGES` index | `webR.installPackages()` already does it correctly. |
| Owner trust interstitial, `CONFIG.TRUSTED_OWNERS` | Trains click-through; stops nothing the Run button does not. Replaced by prominently displaying the script's source origin. |
| `sharer.json` and `.sharerignore` | **User was emphatic:** never require a researcher to change their repo or workflow for our tool. It also contradicted the project's own headline claim of running an *unmodified* repository. Everything configurable now passes via URL parameters, including `packages=` and `repos=`. |
| IndexedDB tree cache, SHA-256 of every input file | Bookkeeping disproportionate to the benefit. |

**Added to the spec, and the reason Stage 2 cannot ship without them:**

1. **`entry` accepts a full `http(s)` URL** to a single `.R`/`.Rmd` file, with no `repo` involved (spec 5.1). Decided by inspecting the value, not a mode flag.
2. **`data=` stages input files so uploading is optional** (spec 5.1). Accepts repeated params, comma-separated lists, a `<url>|<filename>` rename form, and **directories** (a value ending in `/`). Directory resolution order: repo-relative filtered from the already-fetched tree (free, preferred), then a GitHub URL via the Contents API, then generic HTML autoindex parsing (best-effort, must fail loudly). This was previously deferred as a "future enhancement"; the user moved it into scope because **the EMA-CleanR reference case cannot be tested without it**.
3. **One staged file list, three sources** (spec 7), replacing the old "repository mode vs upload mode" split. Precedence is local > URL > repository, with every override announced. There is no separate upload mode.
4. **CORS reality documented as a first-class limitation** (spec 5.5), because it, not CSP, is what actually blocks arbitrary URLs.

**Empirically verified during this revision, so Stage 2 does not have to rediscover it.** Tested with live requests carrying an `Origin` header:

| Host | Fetchable by browser JS? |
| --- | --- |
| `raw.githubusercontent.com`, `gist.githubusercontent.com` | Yes, `access-control-allow-origin: *` |
| GitHub Pages `*.github.io` | Yes, confirmed on a real asset |
| `cdn.jsdelivr.net/gh/<owner>/<repo>@<ref>/<path>` | Yes; serves any file from any public GitHub repo. **Recommend this as the escape hatch.** |
| Dropbox, Google Drive, Google Sites | **No.** No CORS header; Google Sites redirects to a login page. Not fixable from our side. |

ZippyServe serves no directory index, so local directory-listing tests need the explicit comma-separated form.

---

## Stage 2 - Full Implementation, split into sub-stages

Split deliberately so each sub-stage ends at a **manually verifiable running application**, rather than accumulating unverifiable code. Each builds directly on the previous `index.html`. Stage 1's file is the starting point and may be restructured freely.

### Stage 2A - Load and run a real script from anywhere

**Goal: `?entry=<url>&data=<url>` runs a real `.R` file end to end.** This is the highest-risk, highest-value increment and it is what unblocks EMA-CleanR testing.

1. Full frozen `CONFIG` per spec section 13 (note: no `TRUSTED_OWNERS`, no cache keys, no SRI).
2. URL parameter parsing and validation per spec 5.1/5.2: `entry`/`script` alias, `data` (repeated, comma-separated, `|filename` rename, trailing-slash directories), `repo`, `ref`/`branch`, `packages`, `repos`, `autorun`. Validate URLs with the `URL` constructor and an `http:`/`https:` protocol check; enforce the working-directory traversal assertion on every write path.
3. Fetching: always `arrayBuffer()`, never `text()` (binary `.rds`/`.xlsx` corruption). Write via `webR.FS.writeFile` into `CONFIG.VFS_PROJECT_DIR`, creating directories depth-first, catching `EEXIST` specifically. `setwd()` into the project dir and confirm.
4. The staged file list UI (spec 7): name, size, source, remove, and replace-with-local. Local file selection must be a real `<button>` that also accepts drop and paste.
5. Distinct CORS failure messaging (spec 5.5) falling back to local file selection.
6. Run a plain `.R` file with streaming output via `webR.stream()` alongside `captureR`.

**Done when:** a `.R` file hosted on GitHub Pages or `cdn.jsdelivr.net/gh/`, with a CSV supplied via `data=`, runs and prints correct output; and the same works with zero URL parameters using only local files.

### Stage 2B - R Markdown, packages, and outputs

**Goal: EMA-CleanR runs to completion and produces its outputs.**

1. Load `js-yaml`, `marked`, `DOMPurify`, `fflate` from pinned jsDelivr URLs (no `integrity` attribute); fail loudly naming any library whose global is missing.
2. `.Rmd` engine per spec 8.3: front matter via `js-yaml`; knitr `params` honoring the `value:` sub-key convention; bind via `webR.objs.globalEnv.bind` plus `jsonlite::fromJSON`, **never string-interpolated into R source**; line-by-line fence-state chunk parser, not a whole-document regex; chunk options including `knitr::opts_chunk$set`; non-`r` engines skipped with a visible notice; prose through `marked` plus **`DOMPurify.sanitize`** (non-negotiable, spec 0.1); sequential per-chunk `Shelter` in a shared global env.
3. Package detection by scanning plus `packages=`/`repos=` URL params, always including `jsonlite`. One `installPackages` call, streamed progress, `INSTALL_TIMEOUT_MS`, failure naming the specific package and explaining the no-wasm-build cause.
4. Outputs per spec 10: `walkVfs` before/after diff (there is no `readDir`), `output_dir` inclusion, file browser, `ImageBitmap` plots to `<canvas>` with `aria-label`, CSV preview, `textContent` only for R-derived text, revoke every object URL, `fflate` ZIP with outputs, report, log, manifest, and source.

**Done when:** every EMA-CleanR acceptance item in spec 15 (items 6-13) passes, verified against the local copy at `c:\git\EMA-CleanR`.

**STATUS: Stage 2A and 2B are complete.** `index.html` is now 4820 lines with a working Report/Plots/Files results pane, gutter output markers, package install fallback (see memory `sharer-webr-package-repos`), and ZIP download. This is the real, current starting point for everything below — **all file:line references in Stages 2C-2F below point at the actual current `index.html`, not a hypothetical future state.**

---

### Stage 2C - Comment Cleanup Pass (Part 1)

**Goal:** the comment style violations that already exist in the shipped code do not get copy-pasted into new code written during Stages 2D-2F.

**Scope.** Read every comment in `index.html` (`grep -n "//"` and `grep -n "/\*"` to enumerate). Confirmed by direct search, the following need fixing:

- Build-process/session references that must go entirely: `index.html:9` ("Stage 2B: .Rmd chunk execution..."), `index.html:2447` ("confirmed during Stage 1"), `index.html:2462` ("Stage 1 already proved..."), `index.html:4463` ("a keyboard trap that plain Stage 2A never had"). Rewrite each to describe the current code's behavior/constraint directly, with no reference to when or in what development phase it was built.
- Oversized comment blocks to condense to 1-2 lines each, keeping only the load-bearing "why" (drop restated context, historical narration, and multi-sentence justification): at minimum `index.html:1197-1203` (`WEBR_FALLBACK_REPO_URLS`, ~7 lines), `index.html:294-297` (`.panel-scroll`, 4 lines), `index.html:243-246` (`.sr-only`, 4 lines), `index.html:3301-3310` (`renderChunkResult` codeFolding explanation, ~10 lines), `index.html:4322-4331` (`annotateSourceViewerOutputMarkers`, ~10 lines), `index.html:4587-4593` (source-toggle inline-style Chromium workaround, ~7 lines — this one will also need a rewrite in Stage 2D.3 anyway, so touch it once there instead of twice).
- **Keep as-is:** the ~44 `spec section N` cross-references scattered throughout (e.g. `index.html:1191`, `index.html:41`). These point at a durable, checked-in design doc (`docs/ShareR-Technical-Specification.md`) for future maintainers, not at conversational/planning history — that is exactly the kind of "why" AGENTS.md section 4 asks for. Do not strip these.
- `index.html:1848` ("per the user's own rule") refers to the *R script author's* own coding convention being detected by the parser, not to any instruction given to an AI agent — keep, but reword if it reads ambiguously in isolation.

**Rule going forward (applies to every stage below, not just this one):** comments explain a non-obvious *why* in 1-2 lines, addressed to a future maintainer who never saw this project being built — never "the user wanted," "per the plan," "Stage N," or any other reference to how or when the code came to be written.

**Done when:** `grep -niE "stage [0-9]|claude|the user (asked|wanted)|per the plan|as discussed" index.html` returns nothing, and no comment block exceeds 2 lines except the ones explicitly justified above (spec cross-references, which are single-line anyway).

**STATUS: COMPLETE (2026-07-29).** The four "Stage N" references and the ambiguous "per the user's own rule" line are fixed; the five explicitly-named oversized blocks are condensed; the verification grep returns nothing. A broader scan turned up roughly 80 additional 3-5 line comment blocks file-wide that were **not** touched: these are single coherent wrapped sentences of genuine engineering rationale (no conversational/planning content), and mechanically slashing them to a hard 2-line cap would have discarded real information a future maintainer needs — judged not worth the risk of a large blind edit pass across a 4820-line production file with no test suite to catch regressions. The three worst outliers (13-20 line blocks: zoom-control implementation history, package-install-failure semantics, the library()-disabling scanner's limits) were tightened by roughly a third each rather than gutted. If stricter enforcement across every remaining block is wanted, it can be done as a follow-up pass.

---

### Stage 2D - UI/UX Enhancement Pass

Ten requested changes, sequenced so the highest-risk/most-foundational item (the editor rewrite) happens first — everything else that touches the same DOM (gutter markers, the script picker, panel resize) is then built once against the final structure instead of being redone.

Shared building blocks used by more than one sub-stage:
- **Ghost icon-button CSS**, adapted from `c:\git\FieldStationAI\index.html:313-328` (`.msg-actions button` pattern: transparent background, low-opacity until hover/focus, circular hit target, `opacity` transition, revealed on container `:hover`/`:focus-within`). Define once as a reusable class (e.g. `.ghost-icon-btn` + a `.ghost-icon-btn-group` container), used by the per-plot download button (2D.4), the editor-header toolbar (2D.1/2D.2), and anywhere else an icon-only low-emphasis action is needed.
- **Blob + `URL.createObjectURL` + `<a download>` pattern**, already established at `index.html:3208-3213` and tracked for revocation via `App.objectUrls` — reuse for every new single-file download in this stage rather than inventing a second pattern.
- **`activateTab(index)`** (`index.html:4468-4479`) and **`jumpToOutput(tabIndex, elementId)`** (`index.html:4292-4302`) — reuse for every new "jump to this tab/element" interaction (file-list icon jump, fake Report/Plots row "Preview" buttons).
- **`CONFIG.LIB_VERSIONS`** (`index.html:1211-1216`) and the lazy-dynamic-`import()`-on-first-use pattern already used for webR itself in `getEngine()` (`index.html:2450-2459`) — every new library below loads this way, not via an eager `<script src>` tag like js-yaml/marked/DOMPurify/fflate currently do. Exact version pins must be verified live against the npm registry/jsDelivr at implementation time (the same diligence Stage 1 used to verify the webR 0.6.0 pin) — do not fabricate version numbers.
- A shared **copyright footer string** for exported documents, sourced from the same text already in `.print-footer-copyright` (`index.html:1177-1186`) rather than duplicated: factor it into one small helper (e.g. `getCopyrightFooterText()`) used by both the existing print CSS and every new exporter's footer.

#### 2D.1 - CodeMirror 6 migration: editable source viewer, gutter markers, maximize, download

Replaces the hand-rolled read-only viewer (`renderSourceViewer` `index.html:4256-4287`, tokenizer `appendTokenizedLine`/`findCommentStart` `index.html:4207-4250`, gutter markers `annotateSourceViewerOutputMarkers`/`placeMarker` `index.html:4322-4367`) with a CodeMirror 6 `EditorView` mounted into `#source-code-lines` (`index.html:1030`).

1. Load CodeMirror 6 lazily on first "Show Source Code" (reuse `initSourceToggle`, `index.html:4594-4603`) via jsDelivr `+esm` resolution of the `codemirror` meta-package (bundles state/view/commands/language/search) plus `@codemirror/legacy-modes` for `StreamLanguage.define(r)` (CM5's R mode, ported) — verify exact package/version combination live before pinning.
2. Line numbers: CM6's built-in `lineNumbers()` gutter. Plot/file marker icons: a custom `gutter()` extension with a `GutterMarker` subclass rendering the existing 📊/📄 glyphs, click handler calling the existing `jumpToOutput(1, plotItemId)` / `jumpToOutput(2, fileId)` — same target IDs `annotateSourceViewerOutputMarkers` already produces, just re-platformed onto CM6's marker API instead of the old `.marker-slot` divs. `PLOT_CALL_RE`/`FILE_WRITE_CALL_RE`/`findCandidateLines` (`index.html:4309-4320`) are unchanged; only the DOM-attachment layer changes.
3. Editable, and edits feed execution immediately: an `EditorView.updateListener` writes the current doc text back into the active script's in-memory staged content on every change, so the next Run uses the edited text (Run's existing "read the active script's content" call site now reads this live value instead of the immutable staged original). On edit, clear existing gutter markers for that script (the previous run's plot/file attribution no longer corresponds to changed code) until the next Run re-annotates — this mirrors the existing re-annotate-per-run behavior, just triggered one edit earlier.
4. Editor-header toolbar (`#source-viewer-filename`, `index.html:1029`, currently plain text): becomes a small flex row with (a) the clickable script-title button (wired in 2D.2), (b) a ghost "Maximize" icon button, (c) a ghost "Download" icon button, using the shared ghost-icon-button class.
5. **Maximize**: reuse the app's existing `<dialog>` pattern (`load-script-modal`/`error-modal`, `index.html:1094-1162`) rather than a hand-rolled overlay — native `showModal()` gives a real focus trap and Escape-to-close for free, which is exactly the gap the plan's own history flagged in FieldStationAI's modal. Re-parent the single live CM6 `EditorView` into the dialog's content on open and back into `#source-code-lines` on close (one editor instance, two mount points) so no state/undo-history is lost either way.
6. **Download**: serialize the current editor doc text and trigger a download named after the active script's own filename/extension, via the shared Blob+objectURL+`<a download>` pattern. Factor this into one helper (e.g. `downloadActiveScript()`) — it is reused verbatim by the fake "Report" file row's "Download Script" button in 2D.9.

**Done when:** the editor is directly editable with working undo/redo and R syntax highlighting; existing 📊/📄 gutter icons still jump to the right Plots/Files tab item; editing code and pressing Run executes the edited version; Maximize opens a real focus-trapped fullscreen dialog and Escape closes it cleanly; Download saves the current (possibly edited) script content under its original filename.

#### 2D.2 - Script picker popover (replaces the "Script to run" dropdown)

Replaces `#entry-select-field`/`#entry-select` (`index.html:1017-1020`, populated by `renderEntrySelect` `index.html:4167-4178`, wired at `index.html:4759-4761`) with a popover anchored to the editor-header title button added in 2D.1. **Does not touch** `#entry-candidates` (`index.html:999-1005`) — that fieldset resolves *initial* ambiguity before any script is staged/shown; this popover is for switching the *already-loaded* active script and is a different moment in the flow.

1. Title button gets `cursor: pointer`, a small decorative swap/chevron icon (`aria-hidden="true"`), and `aria-haspopup="true"`.
2. Popover content: use the native `popover` attribute (light-dismiss and Escape-to-close for free, consistent with 2D.1's preference for native primitives over hand-rolled equivalents) containing a simple vanilla-JS file tree — group the flat staged-scripts array by `/`-splitting each path into nested plain objects, render as nested `<ul>`/`<li>`, folder labels non-interactive, each leaf file a real `<button>`. The currently-active script's button gets `aria-current="true"` plus the existing `.selected` visual treatment (`styles/um-style.css:123-126`).
3. Selecting a file calls the same underlying state transition the old `change` handler used (`App.explicitEntryPath = ...; syncUrlBar(...)`, leading into `updateSelectedEntry()` `index.html:4388-4406`) — only the UI layer changes, not the selection state machine.
4. On open, move focus to the current script's entry in the tree; on close, return focus to the title button.

**Done when:** clicking the script title opens the popover with the file tree, current script visibly marked, keyboard-operable (Tab/Enter/Escape), and selecting a different file swaps the active script exactly as the old dropdown did (including URL-bar sync).

#### 2D.3 - Workspace panel collapse + resize handle + wider expanded width

Touches `.workspace-pane` (`index.html:288-293`, `987`), the code-toggle inline-style workaround (`index.html:4587-4603`), and the mobile breakpoint (`index.html:950-953`).

1. Bump the code-expanded inline max-width from the current `"40%"` (`index.html:4601`) to `"42%"` (within the requested 40-45% range) — same inline-style mechanism, same documented Chromium `resize`-freeze reason, just the number changes and the surrounding comment gets condensed per Stage 2C's rule.
2. Add one persistent element on the pane's right edge: a `role="separator" aria-orientation="vertical" tabindex="0"` handle, full pane height, `cursor: col-resize`, containing a small collapse/expand icon button. Pointer drag (pointerdown/pointermove/pointerup) sets the same inline `elWorkspacePane.style.maxWidth` property live, clamped to `[260px, 60% of #main-content width]`; ArrowLeft/ArrowRight on the focused separator adjust it in fixed steps for keyboard users (WAI-ARIA separator pattern). This one handle covers both the narrow default state and the code-expanded state — no separate gating logic needed.
3. Collapsed state (`.workspace-pane.collapsed`): width shrinks to ~32px, `.panel-header`'s content and `.panel-scroll` are hidden, leaving only the border, the resize/collapse handle, and its expand icon visible, exactly as requested. Toggled by the icon button inside the handle.
4. Mobile default: on page load, if `window.matchMedia("(max-width: 900px)").matches` (reusing the existing breakpoint at `index.html:950`, per the user's confirmed choice), apply `.collapsed` initially; otherwise leave expanded as today. Checked once at load, not on live resize, to avoid yanking an in-progress user's layout. The new pointer-drag resize logic is only attached above the 900px breakpoint — under it, the existing native `resize: vertical` behavior (`index.html:952`) is untouched, since that's a different (vertical) resize axis for the stacked mobile layout and the user confirmed nothing more is needed there.

**Done when:** on a viewport ≤900px the panel loads collapsed to a thin rail; the collapse icon toggles it open/closed at any width; above 900px, dragging the handle resizes the panel live between its min and max bounds, and the code-expanded default is now 42% instead of 40%.

**STATUS: COMPLETE (2026-08-02).** Implemented with several deliberate deviations from the literal spec text above, each found by validating the design against the live W3C ARIA Authoring Practices Guide Window Splitter pattern before writing code, and each recorded in full (with rationale) in the working plan used to build this: the collapse-toggle button is a DOM sibling of the `role="separator"` handle rather than nested inside it (avoids an axe-core `nested-interactive` violation and an event-bubbling hazard — both are absolutely positioned at the same spot so it still reads as one control); the button uses a new dedicated 24x24px `.workspace-collapse-btn` class rather than the existing `.ghost-icon-btn` (that class is built for hover-revealed card corners, wrong fit for a control that must stay visible when it's the only thing left in a collapsed rail); the handle is a constant 32px in every state; both `style.maxWidth` and `style.minWidth` are written inline on collapse/expand/drag (never via a CSS class) — this turned out to be load-bearing, not just cautious, since the base stylesheet's `min-width:260px` would otherwise silently defeat any smaller class-driven `max-width`; the collapsed pane also got an explicit `min-height:44px`, fixing a real bug where it would render at zero height under the mobile stacked (`flex-direction:column`) layout, since its only remaining content was `position:absolute` and contributed nothing to flex main-axis sizing; and the drag handler suspends the pane's `max-width` CSS transition for the duration of a drag so the panel edge tracks the pointer instead of lagging ~200ms behind it. ArrowLeft/ArrowRight resize is implemented as spec'd; Enter/Home/End extras mentioned as optional by the APG pattern were deliberately left out per this project's "don't add a mechanism the spec didn't ask for" rule — the collapse button remains reachable and fully keyboard-operable via a second Tab stop regardless. Verification was limited to confirming the served file is syntactically intact (ZippyServe serves it byte-identical to source, app boots without file-load errors) — no browser automation is available in this environment, so live drag behavior, the mobile-collapsed-by-default layout, and screen-reader announcements via `aria-valuenow`/`aria-valuetext` still need a human check.

**Follow-up fix (2026-08-02, same day):** first-round manual testing found the handle looked like "the outline of a vertical box... top to bottom of the page" with a "tiny arrow in the middle," and dragging didn't work. Root cause: the collapse button was vertically centered directly on top of the resize handle's most natural grab point, intercepting the drag gesture before it could start, and a permanent `border-left` running the full pane height read as an unwanted decorative box rather than a functional handle. Fixed by narrowing the handle to a slim 10px strip with a small decorative grip-dots SVG (`pointer-events:none`, so clicks still reach the handle underneath) that only shows a highlight accent line on hover/focus/drag, and moving the collapse button to the top of the panel (`top: 8px`, no longer vertically centered) so it no longer sits inside the handle's primary drag zone. See memory `sharer-resize-handle-design` for the general rule this established.

**Second follow-up round (2026-08-02, same day), from a screenshot plus two more rounds of live feedback:**
- The collapse button (now at the top) visually overlapped the header's own "Change script..." button, worst at minimum pane width. Fixed with `#workspace-pane .panel-header { padding-right: 40px; }`, reserving room so header content never renders under the independently-positioned toggle.
- The grip visual was redesigned again: rather than a thin accent line on the full-height strip, the strip is now a fully invisible drag hit-zone and a short (72px), always-visible gray pill with darker dots is centered within it — closer to a conventional resize-panel grabber, and taller/more discoverable than the first 16px-tall icon attempt. The `:focus-visible::before` accent-line rule (which likely caused a separately reported "three bold vertical lines" glitch by drawing alongside the focus outline) was removed entirely in this redesign.
- Max resize width bumped from 60% to 70% of `#main-content`'s width (`CONFIG.WORKSPACE_PANE_MAX_WIDTH_PCT`).
- The mobile (≤900px) collapsed state had a real bug: `setWorkspacePaneCollapsed` unconditionally shrank *width* to the collapsed thickness even under the mobile column layout, producing a narrow vertical box with wasted blank space beside it instead of the vertically-stacked layout the breakpoint is meant to produce. Fixed by adding `App.workspacePaneMobileLayout` (set once, alongside the existing mobile check) and branching: desktop collapse still shrinks width via inline style as before; mobile collapse leaves width alone (governed by the existing `max-width:none` mobile rule) and relies on `.collapsed`'s existing `min-height:44px` rule to shrink height instead, matching the column layout's actual resize axis.
- The resize handle (drag-to-resize-width) has no function on mobile (never wired there) and visually broke in the short collapsed-mobile state (its 72px pill overflowing a ~44px-tall rail), so it's now hidden entirely under the `@media (max-width:900px)` block; the native `resize:vertical` grip remains the sole mobile resize affordance, as originally intended.
- Neither `.workspace-pane` nor `.results-pane` had a height cap on mobile, so `.panel-scroll`'s existing `overflow-y:auto` never actually engaged — each panel just grew to fit all of its content instead of scrolling internally. Fixed with `.workspace-pane, .results-pane { max-height: 100vh; }` inside the same media query.

**Third follow-up round (2026-08-02, same day):** two more real bugs, one of them the actual root cause behind the desktop max-width complaint from round one that the round-two 60%→70% bump had failed to fix (raising the percentage did nothing because it was never the binding constraint):
- **Root cause of "can't resize past ~40%":** on a flex item, `max-width` is a ceiling, not a target — it only clamps the flex algorithm's own computed size down, it can never pull the pane wider than what `flex:1` against `.results-pane`'s `flex:2` naturally resolves to (well under half the container). `setWorkspacePaneWidthPx` and `initSourceToggle`'s 42%-widen were both only ever setting `max-width`, never touching `min-width` — so neither could actually force the pane wider than its natural ~35-40% share. Fixed by pinning `min-width` to the exact same value as `max-width` in both places, which defeats the flex-grow distribution and forces an exact size. Recorded as a general lesson in memory `sharer-resize-handle-design`.
- **Mobile collapse still showed a tall box, not a short horizontal rail:** the `.collapsed` class's `min-height:44px` CSS rule turned out to be exactly the same category of bug — a class-driven, one-sided constraint that the flex column layout's own basis/grow computation could simply ignore. Fixed by removing that CSS rule entirely and, in `setWorkspacePaneCollapsed`, branching on `App.workspacePaneMobileLayout`: mobile now pins `minHeight`/`maxHeight` together via inline style (mirroring the desktop width fix exactly) instead of width, restoring both on expand via a new `App.workspacePaneExpandedHeight` stash (parallel to the existing `workspacePaneExpandedWidth`).
- Also fixed: the collapse-toggle chevron pointed left/right even on mobile, where collapsing now visibly shrinks height, not width — added a `@media (max-width:900px)` rule rotating the same SVG icon 90°/270° (composed as a single `transform` value, not stacked with the desktop rule, since only one `transform` declaration ever wins) so it points up when expanded and down when collapsed on mobile.

**Fourth follow-up round (2026-08-02, same day):** `initSourceToggle` had the exact same "not mobile-aware" oversight the third round had just fixed in `setWorkspacePaneCollapsed`, just missed in that pass because it's a separate function — on a small/narrow screen, expanding the workspace pane and then clicking "Show Source Code" pinned the pane to 42% width unconditionally, which on the mobile column layout actively *shrinks* the pane (its normal mobile width is the full row, not ~40%), squeezing the editor into a sliver too narrow to render usably ("the code box never shows up"). Fixed by gating the 42% min/max-width pinning behind `!App.workspacePaneMobileLayout`, matching every other width-mutating call site. Grepped every remaining `elWorkspacePane.style` write site to confirm no other instance of this same oversight survives — `setWorkspacePaneWidthPx` is the only other width-pinning function, and it's structurally unreachable on mobile since the drag/keyboard listeners that call it are never wired there in the first place.

**Fifth follow-up round (2026-08-02, same day):** the width-shrink from round four's bug was fixed, but the source editor still didn't visibly appear on mobile — a second, independent bug in the same interaction. `.editor-container` relies on `flex:1; min-height:0` to claim whatever vertical space `.panel-scroll` has left (documented at its own definition), which only resolves to a real height if the whole ancestor chain up through `.workspace-pane` has a bounded/definite height. On mobile that chain is a plain flex-basis/flex-grow share of `#main-content`, which can resolve to (and, per the same resize:vertical first-layout-freeze Chromium quirk already documented on `initSourceToggle`, likely stays frozen at) a height computed before the editor ever joined the visible content — so the editor was present in the DOM, not `hidden`, but rendered at effectively zero height. Fixed with an explicit `elWorkspacePane.style.minHeight = "60vh"` set directly in `initSourceToggle`'s mobile branch (cleared on close), the same "always drive a resize-enabled element's size via a direct inline-style write, never a bare reliance on the flex chain" principle applied to the height axis this time. General lesson recorded in memory `sharer-resize-handle-design`.

**Separate, related but out-of-scope-for-2D.3 responsive polish, same day, requested alongside the above:** the header, footer, and the Run/Stop/Print/Download-all buttons were also made to shrink to icon-only / smaller text under the same 900px breakpoint, since a cramped header was part of what was squeezing the workspace pane on small screens too. Run and Stop both got proper inline-SVG icons (Stop previously had no icon at all and read "Stop and reset R"; visible label shortened to "Stop", full description preserved via `aria-label="Stop and reset R"` for WCAG 2.5.3 Label-in-Name compliance) using the same `.btn-icon`/`.btn-text` span convention Print/Download-all already used. On screens ≤900px, `.btn-text` is hidden for exactly these four buttons (not the per-file Files-tab buttons, which don't yet have their own `aria-label` and would lose their accessible name entirely if included in a blanket rule) — each retains an explicit `aria-label` so its accessible name survives, including `downloadResultsZip`'s transient "Building ZIP..." state, which now updates the button's `aria-label` in step with its visible text rather than leaving it stale. The header's tagline is hidden entirely on mobile and the title/repo-name text shrinks; the footer copyright text shrinks further (0.7rem to 0.6rem) and the GitHub link's "View Code on GitHub" label is hidden in favor of just its icon, with a new `aria-label` on the link covering the accessible name.

**Two more rounds of the same responsive-polish thread, same day:** (1) On mobile, the header's Run/Stop/GitHub icons looked disproportionate once their button text was hidden -- Run/Stop's own 14px glyphs were kept exactly as-is (per explicit instruction), but their surrounding button padding was tightened (`padding: 5px 8px`) and the GitHub mark was shrunk from 26px to 18px so nothing dwarfs the 14px icons next to it; the repo-name label (`.header-center-label`, previously just shrunk to 0.95rem) is now hidden outright alongside the tagline, matching the "hide, don't just shrink" instruction. The staged-file carousel's Replace/Remove buttons became icon-only (a new upload-arrow and trash-can inline SVG, `REPLACE_ICON_SVG`/`REMOVE_ICON_SVG`) at *every* screen width, not just mobile, each keeping its existing `aria-label` plus a newly-added `title` tooltip; the filename text shrunk slightly (0.75rem to 0.7rem); the relative-path-on-hover ask was already satisfied by the pre-existing `name.title = f.path`, so no change was needed there. (2) **The "Show/Hide Source Code" toggle was removed entirely** -- the source editor is now always shown once a script is staged, on the reasoning that the workspace pane has nothing else competing for its remaining vertical space. This deleted `initSourceToggle`, its button/wrapper markup, and the now-dead `.toggle-btn`/`.code-toggle-wrapper` CSS, and moved its one remaining real job -- preventing the mobile zero-height editor bug -- from a toggle-triggered inline style into a permanent static rule, `.workspace-pane:not(.collapsed) { min-height: 60vh; }` in the mobile media query (safe as a *static* rule per the same Chromium quirk that made a *dynamic* class-driven change unsafe, since it's part of the very first layout rather than a later change to it). `renderSourceViewer()` now sets `elSourceEditor.hidden` directly (false once a script is staged, true otherwise) instead of deferring to a toggle button that no longer exists. Desktop's default pane width was deliberately left unchanged rather than auto-widened now that code is always visible -- the 2D.3 resize handle is the intended mechanism for a user who wants more room, not a new automatic behavior.

#### 2D.4 - Ghost PNG download button on every plot

Touches `.plot-gallery-item` (`index.html:3138-3151`, CSS `index.html:753-760`) and `bitmapToPlotImage` (`index.html:3126-3136`).

1. Give `.plot-gallery-item` `position: relative`.
2. Add one ghost icon button (shared CSS from the stage intro) absolutely positioned top-right, revealed on hover/focus like the FieldStationAI pattern.
3. No new library: the `<img>` already built by `bitmapToPlotImage` carries a `toDataURL("image/png")` source in memory — either use that data URL directly as the download `href`, or (for consistency with the rest of the app's Blob-based downloads and to share code with the ZIP-all-plots feature in 2D.9) draw the bitmap to a fresh canvas and use `canvas.toBlob(..., "image/png")` + the shared Blob/objectURL/`<a download>` pattern. Filename: `plot-<chunk-label>-<index>.png`.

**Done when:** every rendered plot has a small top-right icon-only button that downloads that exact plot as a standalone PNG.

**STATUS: COMPLETE (2026-07-30).** Implemented as specified, with two adjustments made once it was visible in the running app: the download icon is a hand-authored inline SVG (`DOWNLOAD_ICON_SVG`), not a text glyph — the first attempt used a plain "⤓" character, which rendered too thin to read clearly at button size — via a shared `createPlotDownloadButton()` + widened `.ghost-icon-btn` (28px→34px, added border and maize hover fill). The same button was also added to each plot rendered inline in the **Report** tab (a new `.plot-inline-wrap` container), not just the Plots-tab gallery — not in the original 2D.4 scope, but requested once the Plots-tab version was working and the Report tab's plots were noticed to have none.

#### 2D.5 - Output-file gutter icon jumps to its Report section

Touches `renderChunkResult` (`index.html:3311-3358`, no `id` currently set on the chunk's wrapping `div`), `buildChunkAttributionMap` (referenced at `index.html:3622`), and `renderFilesTab`'s icon (`index.html:3194-3205`).

This turned out to be straightforward, not "non-trivial" — the reverse-direction infrastructure already exists (`chunkByFilePath` attribution, `jumpToOutput`), it's just missing one id.

1. In `renderChunkResult`, assign `wrap.id = "report-chunk-" + slugifyForElementId(label || String(index))` and stash it on the node (`node.reportElementId = wrap.id`). Chunk-block rendering into the Report tab (`index.html:3446/3491/3496/3518`) already happens before `buildChunkAttributionMap`/`renderFilesTab` run (`index.html:3622-3623`), so the id is available in time.
2. Extend whatever `buildChunkAttributionMap` returns per file path to also carry `reportElementId` from the owning node.
3. In `renderFilesTab`, when `attribution.reportElementId` exists, make `iconEl` a real `<button>` (not a plain `<div>`) calling `jumpToOutput(0, attribution.reportElementId)`, keeping the existing tooltip text. Files with no chunk attribution (e.g. `run-manifest.json`) keep the icon non-interactive, as today.

**Done when:** clicking a file's icon in the Files tab switches to the Report tab and scroll-and-flashes the chunk that produced it, mirroring the existing gutter-to-output jump in reverse.

**STATUS: COMPLETE (2026-07-30).** Implemented as specified, plus two latent bugs found and fixed along the way — both real defects in shared code other `jumpToOutput` callers depend on too, not scoped to this feature alone: (1) `report-chunk-` ids were keyed only by chunk label, so a script with duplicate/default-named chunks collided and every file jumped to the *first* matching chunk — fixed by suffixing the id with the chunk's own `startLine`, mirroring the dedupe-slug pattern `buildReportTocAndNumbering` already uses for heading ids. (2) `jumpToOutput` could scroll to the wrong place (or leave the pane stuck at the top, unable to scroll further) when the target tab's zoom-frame height was stale from having been computed while that tab was hidden — its `ResizeObserver` never fires for a hidden element — fixed by forcing a synchronous height refresh immediately after `activateTab()`, before scrolling. Diagnosing this also surfaced a real, pre-existing, unrelated rendering gap noticed via the same EMA-CleanR test run (not originally scoped to 2D.5, fixed adjacent to it since it blocked verification): R's `results='asis'`-style HTML output (e.g. the `table1` package's printed tables) and raw HTML mixed with markdown directly in `.Rmd` prose were not rendering correctly. Fixed with a new `sanitizeRAsisHtml`/`runInlineMarkdownOverTextNodes` pair plus a `marked.use({ renderer: { html(token) {...} } })` override, which reproduces pandoc's own documented behavior (confirmed against pandoc's docs, not assumed): HTML tags pass through untouched, but the text between them still gets run through markdown.

#### 2D.6 - Report/Plots tab export buttons: Web page, Word, Open Document, PowerPoint

Inserted into `.results-actions` (`index.html:1043-1050`) before `#print-results-button`, present identically on both tabs (the user's two bullets for "Report and Plot tabs" and "the Plots tab" describe the same requirement; implemented once). PDF is deliberately **not** one of these buttons — the existing Print button already covers it via the browser's native print-to-PDF, which respects the real `@media print` CSS (`index.html:156-219`) far more faithfully than reconstructing the page in a PDF library would.

1. **Web page (HTML)** - no library. Serialize the tab's sanitized content (`elTabReportZoomInner`/`elTabPlotsZoomInner`, both already DOMPurify-clean) into a minimal standalone HTML document with inline CSS and the shared copyright footer text, images embedded as data URLs so the file is self-contained. Blob download.
2. **Word (.docx)** - `docx` (MIT). Report: one paragraph flow mirroring the tab's structure (prose blocks as paragraphs, chunk output as monospace blocks, plots as inline images). Plots: one image per page, landscape orientation (`PageOrientation.LANDSCAPE`), footer with the shared copyright text sized small.
3. **Open Document (.odt)** - no dedicated templating library; hand-build the minimal ODF package (a well-documented, bounded XML skeleton: `content.xml`, `styles.xml`, `META-INF/manifest.xml`, embedded `Pictures/`) and zip it with **fflate** (already loaded, avoids adding a second zip library like PizZip for what both DOCX and ODT need anyway — DOCX/PPTX/ODT/XLSX are all zip containers). Same layout rules as DOCX: full report flow, or one plot per landscape page.
4. **PowerPoint (.pptx)** - `PptxGenJS` (MIT), naturally landscape slides. Plots: one plot per slide. Report: one slide per top-level block (each prose block or chunk result becomes its own slide) — stated here as the default interpretation since the user's per-slide rule was specified for Plots only; easy to revisit if it doesn't feel right in practice. Footer text box on every slide with the shared tiny copyright line.

**Done when:** each of the four buttons produces a file that opens correctly in a real Word/LibreOffice/PowerPoint/browser, with the copyright line visible but unobtrusive in the footer of every page/slide, and Plots-tab exports show one plot per page/slide as specified.

#### 2D.7 - Output files list: Preview / Download / Download XLSX / Download PDF

Rewrites the button set inside `renderFilesTab`'s per-row loop (`index.html:3190-3248`), replacing the current single "Download" link (and CSV-only "Preview" button) with up to four buttons per row.

1. **Preview** (icon + "Preview"; tooltip "Preview first 20 rows" for tabular files, else "Preview this file") - generalizes the existing CSV-only preview (`buildCsvPreviewTable`, toggled at `index.html:3236-3246`) to other common R-output types with vanilla JS/native APIs: JSON/JSONL pretty-printed in a `<pre>`, plain text/markdown/log in a `<pre>`, images already have inline preview (`index.html:3221-3225`, keep), TSV reuses the CSV table builder with a different delimiter. Unsupported types (e.g. `.rds`, `.xlsx` binary) get no Preview button, per the "otherwise skip" pattern already established elsewhere in this stage.
2. **Download `<ext>`** - the existing Blob/objectURL/`<a download>` link (`index.html:3208-3219`), relabeled to show the actual extension in the button text.
3. **Download XLSX** - only rendered for CSV/TSV files. `ExcelJS` (MIT), parses the file's own text and writes one worksheet, download via the library's `writeBuffer()` + the shared Blob pattern.
4. **Download PDF** - only rendered for file types that can be faithfully converted without a full document-rendering engine: CSV/TSV (via `jsPDF` + `jspdf-autotable`, paginated table), plain-text-like files (`.txt/.log/.md/.json/.r/.rmd`, via `jsPDF`'s wrapped text), and image types (via `jsPDF`'s `addImage`, one-page PDF). Skipped entirely for anything else (binary/`xlsx`/`zip`/already-`pdf`), matching the user's own "otherwise skip this button" instruction applied per file type rather than as an all-or-nothing decision.

**Done when:** every output row shows the right subset of these four buttons for its file type, each does what its tooltip says, and no button appears for a format it can't honestly support.

#### 2D.8 - Fake "Report" file row above the outputs list

A synthetic row rendered above the real `outputFiles` loop in `renderFilesTab`, styled like a `.file-row` but with its own three buttons (deliberately different from the real rows, per the user's instruction):

1. **Preview** - `jumpToOutput`-style tab switch to Report (`activateTab(0)`), no scroll/flash target needed since it's the whole tab.
2. **Download Script** - calls the same `downloadActiveScript()` helper built in 2D.1.
3. **Download PDF** - switches to the Report tab (`activateTab(0)`) then calls `window.print()`. This is the explicit fallback behavior the user specified ("if we are not able to have GPLv3 PDF generator libraries... simply open the print preview") — and given 2D.6 already established that native print-to-PDF is the higher-fidelity choice for whole-tab export, there's no reason to build a second PDF path here; this button is that same decision applied to the fake row.

#### 2D.9 - Fake "Plots" file row above the outputs list

Same pattern as 2D.8, three buttons:

1. **Preview** - `activateTab(1)`.
2. **Download ZIP** - every currently-captured plot bitmap converted to PNG bytes (reusing the canvas/`toBlob` helper from 2D.4) and packed into one archive with **fflate** (already the app's ZIP library, `buildZip` pattern at `index.html:3724-3749`), one image file per plot.
3. **Download PDF** - `activateTab(1)` then `window.print()`, same fallback reasoning as 2D.8.

**Done when (2D.8 + 2D.9 together):** both fake rows appear above the real output files, visually distinguished as not-a-real-output-file, and all six buttons across the two rows work as specified.

#### 2D.10 - Detect a script's own interactive-input calls and pre-fill them, unmodified

**Non-negotiable constraint driving this whole sub-stage:** the researcher's script is never touched or required to follow a ShareR-specific convention — no new chunk option, no wrapper function, no `sharer::` package to import. ShareR only ever *parses what's already there*. This directly follows from the project's own reason for existing (run an unmodified repository) — see the "Removed from the spec as over-engineering" table earlier in this plan, `sharer.json`/`.sharerignore` row.

Real, synchronous, mid-statement input (making R's own `readline()`/`menu()`/`browser()` actually block and wait) is confirmed **not possible** under the `PostMessage` channel ShareR uses — webR's own docs state plainly that these are unsupported on that channel. The only alternative, the `SharedArrayBuffer` channel, requires `crossOriginIsolated` (real `COOP`/`COEP` response headers), which GitHub Pages cannot serve natively; the only workaround is a Service Worker header-injection hack, which would mean reversing the Stage-2-revision decision to remove the service worker entirely (see the same "Removed from the spec" table, service worker row). Not pursued here.

Instead: pause at the **chunk boundary** (which already exists as a natural pause point — one `shelter.captureR()` call per chunk), ask once before that chunk runs, and **rewrite the chunk's source text** to splice in the answer before executing it — the same "detect a call via regex, rewrite the chunk source, execute once" shape `disableMissingPackageLoadCalls` already uses for `library()`/`require()` calls, applied to a different set of calls.

1. During the same per-chunk pre-scan pass that already runs `PLOT_CALL_RE`/`FILE_WRITE_CALL_RE` and the package-detection scan, comment-stripped the same way (`findCommentStart`), also scan for calls to `readline(`, `scan(`, `menu(`, `file.choose(`, `askYesNo(`.
2. Extract each full call expression with the same balanced-paren matching (and the same documented limitation) `disableMissingPackageLoadCalls` already accepts: no string/comment awareness *inside* the parens, best-effort, not a real R parser.
3. Best-effort label extraction per call: the first quoted-string-literal argument for `readline("...")`/`askYesNo("...")`; a literal `c("a", "b", ...)` of quoted strings parsed into real choices for `menu(...)`; no parsing needed for `file.choose()`. A call whose relevant argument isn't a static literal falls back to a generic "this chunk asks for input" label — the same class of best-effort fallback the plot/file gutter markers already use when a candidate line can't be matched confidently.
4. One native `<dialog>` (reusing 2D.1's dialog infrastructure) per chunk, listing every call detected in that chunk with one labeled field each: text input for `readline`/`scan(character)`, a number input for `scan(numeric)`, a radio/select list built from `menu()`'s parsed choices, a real `<input type="file">` for `file.choose()` that stages the picked file into the VFS via the app's existing local-file-staging path (no second upload mechanism), and Yes/No/Cancel for `askYesNo()`. Every field has a visible Skip affordance.
5. Rewrite the chunk's source by replacing each matched call expression with a properly R-quoted literal of the answer — via a small dedicated R-literal-quoting helper (escapes backslashes/quotes/newlines), never naive string concatenation, per `AGENTS.md` section 7. Skipped fields get exactly the value real, unmodified `Rscript` batch execution already produces for that call today: `""` for `readline`/`scan(character)`, `NA` for `scan(numeric)`/`askYesNo()`, `0` for `menu()` (R's own documented "user cancelled" return). `file.choose()` is replaced with the quoted staged file path.
6. Execute the rewritten chunk exactly once — mirrors `disableMissingPackageLoadCalls`'s existing "one rewrite, one real execution" shape; the original, unrewritten text is never actually run.

**Known limitations, stated plainly rather than glossed over:**
- Detection is regex/paren-balance based, not a real parser: calls built indirectly (`fn <- readline; fn()`), or whose arguments aren't static literals, may be missed or fall back to a generic prompt.
- One modal per chunk, not per statement: a chunk needing a *later* prompt computed from an *earlier* prompt's answer within the same chunk isn't supported — the researcher would need two chunks, which is a normal authoring choice already available to them, not something ShareR imposes.

**Done when:** an unmodified script containing a real `readline("Enter your name: ")` (or `scan()`/`menu()`/`file.choose()`/`askYesNo()`) call — sourced from a repo the researcher never touched for ShareR — shows one modal before that chunk runs, and the chunk executes using either the entered value or R's own real batch-mode default when skipped.

---

### Stage 2E - Accessibility, Errors, and Documentation

*(This is the original plan's "Stage 2C," renumbered so it runs after the UI/UX pass above and therefore audits the final UI in one pass instead of two. Content unchanged from the original plan.)*

**Goal: shippable.**

1. Setup/Running/Results states with focus moved to the new region's heading and a polite live-region announcement; skip link and landmarks; keyboard-operable file chooser; `prefers-reduced-motion`; contrast verified against `um-style.css`, not assumed.
2. Every row of the spec 12 error table; stall watchdog; Diagnostics panel (webR version, R version, channel, `crossOriginIsolated`, storage estimate).
3. `run-manifest.json`; timing instrumentation.
4. axe-core pass plus the manual checklist (keyboard, screen reader, 200 percent zoom, forced-colors) recorded in `docs/security-privacy-accessibility.md`. Per `AGENTS.md` section 11, record what was actually run; do not claim passes.
5. Rewrite `README.md` from the EFDC template to match the as-built app, including the CORS limitation and the honest privacy language from spec 2.3.

**Additional item picked up from Stage 2D:** explicitly re-verify keyboard operability and focus handling for the six new interactive components built in 2D (CM6 editor + maximize dialog, script-picker popover, workspace collapse/resize separator, per-plot ghost buttons, new file-row button sets, the interactive-input dialog from 2D.10) as part of the manual accessibility checklist in item 4 above — these are new enough that they shouldn't be assumed correct just because they reused native primitives (`<dialog>`, `popover`) elsewhere in this plan.

**Done when:** spec 15 items 14-22 pass and the README matches reality.

---

### Stage 2F - Comment Cleanup Pass (Part 2)

**Goal:** the code written across Stage 2D (and any touched in Stage 2E) matches the same comment standard enforced in Stage 2C, now that all new code exists.

1. Re-run the same audit as Stage 2C (`grep -niE "stage [0-9]|claude|the user (asked|wanted)|per the plan|as discussed"` plus a manual scan for any comment block longer than 2 lines) across the full file, including everything added in 2D/2E.
2. Pay particular attention to the new library-integration code (2D.1 CodeMirror wiring, 2D.6/2D.7's document-export helpers) — this kind of code tends to accumulate "here's how this library's API works" comments that describe *what* the next line does rather than *why* it's structured that way; trim to the load-bearing why only, or delete if the code is self-explanatory.
3. Confirm no comment anywhere in `index.html` references this plan, its stages, or the fact that an AI coding agent was involved in writing it.

**Done when:** the same grep from Stage 2C's "Done when" still returns nothing, run against the fully-built app.

---

### Cross-cutting rules for all sub-stages

- **Verification is manual and must be honest.** There is no browser automation in this environment (no `chromium-cli`). State plainly what was executed versus what needs a human to confirm, per `AGENTS.md` section 11.
- Serve with `.\run-windows.ps1` (ZippyServe on port 8010).
- Reference fixture is the local clone at `c:\git\EMA-CleanR`.
- Before adding any mechanism not named in the spec, re-read spec section 0.1. The default answer is no.
- Every new external library in Stage 2D loads lazily via dynamic `import()` on first use of the feature that needs it (matching `getEngine()`'s existing pattern), never as an eager page-load `<script src>` tag — a researcher who never clicks "Download PPTX" should never pay for PptxGenJS's weight.
- `TODO.md` at the repo root is a synced copy of this plan file for in-repo visibility; when this plan file changes materially, update `TODO.md` to match in the same session.
