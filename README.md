# TidyMac

A menu bar app for macOS that organizes files sitting loose in folders you pick, like
Desktop or Downloads. It only touches files that look genuinely unsorted, and it never
moves anything for real until you've told it to.

## What "unsorted" means

By default, a file counts as unsorted if it's sitting directly in the root of a watched
folder, not inside any subfolder. If you already filed something into a subfolder,
that's a signal you organized it on purpose, so TidyMac leaves subfolders alone.

You can opt a folder into also cleaning up subfolders that look generic rather than
deliberately named, things like "New Folder" or "untitled". That's a per-folder setting
you turn on yourself; it's never the default, and even then TidyMac only looks one level
into a folder like that, never further.

## The safety model

This is a tool that moves real files, so the defaults are built around not trusting
itself:

**Dry run by default.** The first time you run TidyMac, and every time after that until
you change it yourself, it only shows you what it *would* move and where, without moving
anything. You switch to Auto-Organize deliberately, in Settings, when you're ready.

**Every real move is logged.** Source path, destination path, timestamp, which rule
matched. The log lives at `~/Library/Application Support/TidyMac/move-log.json` and is
plain JSON, so you can read it yourself if you want to.

**Undo actually works.** Not just "here's a log, good luck." The Activity tab in
Settings, and the "Undo Last Batch" button in the menu, reverse a batch by moving every
file back to where it came from. If something's changed since the move (the destination
file is gone, or something new is now sitting at the original path), that one file is
skipped and reported rather than overwritten, and the rest of the batch still gets
undone.

**Nothing gets overwritten.** If a file would land somewhere a file with that name
already exists, TidyMac renames the incoming file instead ("report (1).pdf"), it never
clobbers what's already there.

**A rule can't accidentally send a file somewhere you didn't intend.** A relative
destination (the default, e.g. `Screenshots`) is sanitized against `..` before it's used,
so even a typo'd or copy-pasted rule can't quietly move something out of the watched
folder. Writing an absolute destination (starting with `~/` or `/`) is the one deliberate
exception -- see "shared destinations" below -- and its exact resolved path is always
shown in the dry-run preview before anything moves, so there's nothing hidden about it.

None of this is a promise that nothing can ever go wrong. Undo depends on the log file
being intact, and the "is this file currently open" check is best-effort (macOS doesn't
have mandatory file locking, so it can only catch apps that cooperate with advisory
locks). But every one of these guarantees is backed by a test that tries to break it, not
just a test that checks the happy path.

## Setup

You need macOS 13 or later.

```
git clone https://github.com/<your-username>/tidy-mac.git
cd tidy-mac
swift build
.build/debug/TidyMac
```

Build first, then launch the binary directly, rather than using `swift run`.
`swift run` wraps the process in a way that doesn't get along with a long-running
`NSApplication` menu bar app on every setup; it can sit there with no output and no
menu bar icon, even though the build succeeded. Running `.build/debug/TidyMac` directly
is the reliable way to launch it. Once it's running, you'll see its icon appear in the
menu bar (if your menu bar is full, it might be tucked toward the edge, and note that
macOS hides the whole menu bar while another app is in full-screen mode). Click it, add
a folder to watch under Settings, and try "Organize Now" to see a preview before
anything moves.

If you have full Xcode installed, `open Package.swift` opens the project there instead,
and `swift test` (or Cmd-U) runs the test suite. This was built and tested in an
environment with only the Command Line Tools installed, not full Xcode, so the test
target uses plain XCTest rather than anything requiring a newer toolchain feature, and
every piece of logic was also independently verified with a throwaway executable that
imports `TidyMacCore` directly and asserts against a real filesystem, since `swift test`
itself needs XCTest.framework, which only ships with full Xcode.

## Project structure

```
Sources/
  TidyMacCore/      The engine: rule matching, scanning, moving, logging, undo.
                     No AppKit or SwiftUI in here, just Foundation, so it's fast
                     to test and easy to reason about in isolation.
  TidyMac/          The menu bar app: SwiftUI views, app state, settings persistence,
                     the file-system-change watcher.
Tests/
  TidyMacCoreTests/ Unit tests for everything in TidyMacCore.
```

Inside `TidyMacCore`:

- `Models/`: `FileRule`, `MatchCondition`, `FileCandidate`, `ScanSettings`, and the
  default rule set.
- `Scanner.swift`: walks a watched folder and classifies each entry as a candidate or a
  skip (subfolder, symlink, unreadable, in use).
- `RuleEngine.swift`: picks the first enabled rule that matches a candidate.
- `Organizer.swift`: the one entry point (`run(for:mode:)`) that ties scanning, rule
  matching, and either dry-run planning or a real move together.
- `FileOperationsPerforming.swift`: the seam between planning and disk. Dry run never
  touches this at all.
- `MoveLogStore.swift` / `MoveUndoer.swift`: logging and undo.

## Adding or editing rules

Open Settings → Rules. A rule has:

- A name (just for display).
- One or more conditions: file extension, filename contains, filename starts with, or a
  regular expression against the filename.
- Whether it needs *any* of its conditions to match, or *all* of them.
- A destination, either relative to whichever folder is being watched (`Documents/PDFs`
  means "the Documents/PDFs folder inside whichever watched folder this file is in," not
  a single fixed folder) or, starting with `~/` or `/`, an absolute shared destination --
  see below.

Rules are checked top to bottom, and the first enabled rule that matches wins. That's the
whole conflict-resolution story: if a screenshot is also technically a PNG, whichever
rule is higher in the list is the one that gets it. This is why the built-in Screenshots
rule is listed above the built-in Images rule. Drag rules in the list to reorder them,
toggle the checkbox to disable one without deleting it, and "Reset to Defaults" if you
want the original set back.

"Add Rule" also offers a handful of common starting points (invoices, RAW photos, screen
recordings, ebooks, fonts, disk images, design files, data files, torrents) that pre-fill
a sensible name/destination/conditions -- picking one just saves typing, it's still a
completely normal, fully editable rule afterward, not a locked-in template.

### Shared destinations

If you watch more than one folder, a relative destination means each watched folder
grows its own separate subfolder for that rule -- two watched folders both get their own
`Screenshots` folder, for instance. Writing an absolute destination instead, like
`~/Pictures/Screenshots`, sends matches from *every* watched folder to that one real
folder, so they don't end up scattered across each watched location.

## How it decides where things go, out of the box

| Rule | Matches | Goes to |
|---|---|---|
| Screenshots | Filenames starting with "Screenshot" or "Screen Shot" | `Screenshots/` |
| PDFs | `.pdf` | `Documents/PDFs/` |
| Installers | `.dmg`, `.pkg` | `Downloads/Installers/` |
| Images | `.jpg`, `.jpeg`, `.png`, `.heic`, `.gif`, `.tiff`, `.webp` | `Pictures/` |
| Documents | `.doc(x)`, `.xls(x)`, `.ppt(x)`, `.txt`, `.rtf`, `.pages`, `.numbers`, `.key` | `Documents/` |
| Archives | `.zip`, `.tar`, `.gz`, `.tgz`, `.rar`, `.7z`, `.bz2` | `Archives/` |
| Audio | `.mp3`, `.wav`, `.m4a`, `.aac`, `.flac` | `Audio/` |
| Video | `.mp4`, `.mov`, `.avi`, `.mkv`, `.m4v` | `Videos/` |

A file with no extension, or one that matches none of your rules, is left alone and shows
up in the preview as "no rule matched" rather than getting swept into a catch-all folder.

## Triggers

Settings → General lets you pick when TidyMac checks your watched folders:

- **Manual only**: nothing happens until you click "Organize Now."
- **When files change**: a lightweight watcher notices when a watched folder's contents
  change and checks it.
- **On a schedule**: checks every N minutes.

Whichever trigger fires, it respects the dry-run/auto-organize setting: in dry run, a
trigger only refreshes the preview; in auto-organize, it actually moves files. The manual
"Organize Now" button always shows you a preview with a "Move These Files" button first,
regardless of the global mode, since that's a direct request to look at one folder right
now.

## Cleaning up empty folders

Settings → Folders has a "Clean Up Empty Folders…" button per watched folder. It scans
that folder's direct subfolders for ones with nothing meaningful in them (a lone
`.DS_Store` still counts as empty) and shows you the list before removing anything --
uncheck any you want to keep. This is a delete, not a move, so it gets the same
re-verify-right-before-touching-it treatment as everything else: if something gets added
to a folder between the preview and your click, that folder is left alone. It's logged
and undoable exactly like a move, which is safe here specifically because the folder was
already verified empty before it was ever removed, so undoing it back into existence
loses nothing.

## What this doesn't try to do

- It doesn't read image metadata to detect screenshots, just the filename convention
  macOS itself uses ("Screenshot ... .png"). Metadata-based detection depends on
  Spotlight indexing having already run, which isn't reliable enough to test
  deterministically, so it was left out rather than shipped half-working.
- The "file in use" check is advisory-lock-based, which most well-behaved apps respect,
  but macOS doesn't force any process to. Don't treat it as a guarantee against ever
  moving a file mid-write.
- It doesn't handle files with compound extensions specially (`archive.tar.gz` is
  matched on `.gz`, not `.tar.gz`), since that's how `URL.pathExtension` works and adding
  special-casing for it felt like solving a problem nobody using this app has run into.
