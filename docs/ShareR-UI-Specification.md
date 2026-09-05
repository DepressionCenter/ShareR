ShareR User Interface (UI) Specifications
Product Vision:
A lightweight, modern, "RStudio-lite" web interface designed for non-technical researchers. It features a split-pane layout that emphasizes inputs (left) and results (right), hiding complex code and logs by default.

1. Global Visual Language
Typography: System fonts (system-ui, -apple-system, sans-serif) for UI elements. Monospace ('Consolas', 'Courier New') for code and logs.

Color Palette (University of Michigan Theme):

Primary Dark: #00274C (UM Dark Blue) - Used for headers, active text, primary borders.

Primary Accent: #FFCB05 (UM Maize) - Used for primary action buttons and logo accents.

Backgrounds: #f0f2f5 (Page base), #ffffff (Panels), #fafafa (Panel headers/tabs).

Text/UI Elements: #111827 (Main text), #6b7280 (Muted text), #e5e7eb (Borders).

Action/Links: #2563eb (Blue accents/links), #10b981 (Success/Download).

Layout: Full-viewport height (100vh), flexbox-driven. Fixed header and footer, with a main content area split into two side-by-side panels.

2. Header Section
Placement: Fixed at the top, full width, dark blue background.

Left Side (Branding):

Title: "ShareR" (Bold) with maize-yellow "R" followed by | [Repository Name] (Lighter font weight).

Slogan: "Share your science. R in the browser, nothing to install." displayed beneath the title in a small, muted gray font.

Right Side (Actions):

Run Button: Prominent Maize background, Dark Blue text, featuring a play icon (▶). On hover, background darkens slightly.

GitHub Link: White GitHub SVG icon, slightly transparent, turns fully opaque on hover. Links to the source repository.

3. Left Pane: Workspace (Inputs & Code)
Behavior: Horizontally resizable and collapsible by the user. The source editor remains inside this pane and is visible whenever a script is selected.

Workspace Actions:

The pane header provides an icon button to open a URL or repository. The **Files** label row provides root-level actions to create a script, create a data file, create a directory, and add files. Buttons use Bootstrap Icons and have accessible names and tooltips.

Current Script Inputs:

A compact list shows only data paths detected in the current script. It updates while the researcher edits a path in the source editor. Each row preserves the path expected by the script and provides Upload Replacement and Restore Original actions. No Delete action is shown.

File Tree:

A nested tree shows the files and directories currently staged in the browser workspace. Directories can be expanded or collapsed. Script files can be selected from the tree, while the existing script picker in the editor header remains available.

Every file row reveals ghost-style Upload Replacement and Restore Original buttons on hover or keyboard focus. The controls remain visible on devices without hover input.

Source Code Editor:

Editor Window: Dark theme (#1e1e1e background, light gray text), standard syntax highlighting colors for comments, strings, and functions. The editor stays in the Workspace pane when the pane is resized or collapsed.

Interactive Gutters (Line Numbers): The left margin of the code features line numbers. Lines that generate specific outputs display interactive marker icons:

📊 (Chart Icon) for lines generating plots.

📄 (File Icon) for lines saving files.

Interaction: Clicking these icons instantly jumps the right pane to the corresponding output.

4. Right Pane: Results (Outputs & Logs)
Header: Contains the section title ("Results") and a green "↓ Download Zip" button aligned to the right.

Tab Navigation:

Three tabs: Report, Plots, and Files.

Active Tab: Displays a dark blue bottom border and bold, dark text. Inactive tabs use muted gray text.

Tab Contents:

Report: Renders the HTML preview of the knitted markdown analysis.

Plots: Displays generated graphics in stacked cards with a light gray placeholder background.

Files: Lists generated files (e.g., .csv outputs) in horizontal cards displaying the file icon, name, size, and source line number. Includes a placeholder "Preview" button.

Highlight Animation: When triggered by clicking an icon in the left pane's code gutter, the targeted output item flashes yellow (#fef08a) and pulses slightly for 1.5 seconds to draw the user's eye, then fades back to normal.

Execution Log (Console):

Placement: Anchored to the bottom of the right pane.

Behavior: Collapsed by default, showing only a "▸ Execution Log" header. When clicked, it slides up to reveal terminal output.

Styling: Black background, bright green (#00ff00) monospace text, simulating a command-line interface.

5. Footer Section
Placement: Fixed at the bottom of the screen, very small text size.

Content (Centered):

Copyright: © 2026 The Regents of the University of Michigan

Divider: Vertical pipe (|)

Link: Eisenberg Family Depression Center (Links to specific URL).

Divider: Vertical pipe (|)

Link: Small GitHub SVG icon followed by View Code on GitHub (Links to ShareR repo).

Styling: Text is muted gray; links are standard web blue and underline on hover.

--------


Here are the functional logic and interaction specifications, written as user flows and application behaviors rather than underlying code:

### ShareR Functional Logic & Interaction Specifications

**Objective:** Define the behavioral logic that connects the user interface to the webR environment, ensuring a seamless, responsive experience without detailing the specific code implementation.

---

#### 1. Initialization & "Magic Link" Logic

* **Auto-Load:** When a user navigates to the app via a URL with repository parameters (e.g., `?repo=DepressionCenter/EMA-CleanR`), the application skips any preliminary setup screens.
* **Auto-Stage:** The app automatically fetches the default files from the specified repository, stages them in the background, and immediately presents the split-pane workspace.
* **Empty Start:** With no `entry`, `script`, `data`, or `repo` parameter, the Report area displays a file/folder drop target, file and folder picker buttons, New Script and Open URL or Repository actions, and a sample link to `?repo=DepressionCenter/EMA-CleanR`.
* **Multiple Scripts:** When loading does not select one script automatically, the researcher chooses a script from the Workspace file tree or the editor's script picker. No source-selection dialog opens automatically.

#### 2. Layout & View State Logic

* **Workspace Resizing:** The left pane can be resized horizontally on desktop and vertically in the stacked mobile layout. The resize separator is also keyboard operable.
* **Workspace Collapse:** The left pane can be collapsed to a narrow rail and restored without losing files, editor text, selection, or execution state.


* **Tab Navigation:**
* Only one tab's content (Report, Plots, or Files) can be visible at a time in the right pane.
* Clicking a tab header instantly hides the current content and displays the targeted content.


* **Console Toggling:**
* Clicking the console header toggles the log container's height between 0 (hidden) and a fixed max-height.
* When new logs are generated by the execution engine while the console is open, the container must automatically scroll to the bottom to show the latest entry.



#### 3. Code-to-Output Linking (The "Magic Gutter")

* **Trigger:** The user clicks a specific output icon (📊 or 📄) in the code editor's left margin.
* **Sequence of Actions:**
1. **Switch Tab:** The right pane automatically switches to the corresponding tab (e.g., clicking 📊 switches to the "Plots" tab).
2. **Scroll to Target:** The right pane smoothly scrolls until the specific generated output (plot or file card) is centered in the view.
3. **Highlight Flash:** The targeted output element plays a brief 1.5-second visual animation (a yellow background and border flash) to draw the user's attention, then fades back to its normal state.



#### 4. Workspace File and Input Logic

* **Current Inputs:** ShareR statically resolves supported data-reading calls in the active editor text. Literal paths and safely resolvable path variables appear in Current Script Inputs; the list refreshes as the script changes.
* **Replacement:** Upload Replacement opens the operating system's native file picker and writes the selected bytes to the existing workspace path. The filename expected by the script (for example, `EMA-Data.csv`) is preserved regardless of the selected file's local name.
* **Restore:** Restore Original reverts a changed repository or URL file to its initial staged bytes. The button is disabled when no restore point exists or the file is unchanged.
* **File Tree Actions:** The Upload Replacement, Restore Original, and Duplicate actions are available on every file row. Duplicate inserts `-1`, `-2`, and so on before the filename extension. Script rows also switch the active editor script.
* **Directory Actions:** Every directory row provides actions to create a script, create a data file, create a sub-directory, and add files inside that directory.
* **Adding Content:** Files may be added from the Files toolbar, a directory row, the empty-start buttons, paste, or drag and drop. Files and folders dropped from the computer retain their supplied relative paths and may target a specific tree directory.
* **Moving Content:** Workspace files and directories can be dragged onto another directory or the root Files area. Every draggable row also provides a keyboard-operable Move action. A directory cannot be moved inside itself, and an existing destination path is never overwritten.
* **Creating Content:** New `.R` and `.Rmd` scripts and new directories use project-relative, traversal-safe paths. Creating a script selects it immediately. Empty directories are created in the webR virtual filesystem on the next run.
* **Browser Only:** Local files, new scripts, directories, edits, and replacements remain in the browser session; ShareR does not upload them to a server.

#### 5. Execution & Export Logic

* **Run Button States:**
* When clicked, the button text changes (e.g., "Running...") and is temporarily disabled to prevent double-execution.
* Once the background execution is complete, the button resets to its default state.


* **Zip Download Flow:**
* When the user clicks "Download Zip," the application collects all files currently residing in the webR output directory.
* It bundles them into a single `.zip` archive on the fly and triggers a standard browser download prompt for the user.
