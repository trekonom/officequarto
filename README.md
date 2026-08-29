# officequarto

Prototype Quarto extension that lets any existing Word document be used as the target/template
format for Quarto (styles, layout, headers/footers are carried over) and, after `quarto render`,
overwrites the generated `.docx` in place with the document metadata carried over from the
original — the same basic idea as [{officedown}](https://github.com/ardata-fr/officedown), but
shipped as an installable Quarto extension instead of an R package.

## Usage in 3 steps

1. **Install the extension into a Quarto project** (a project with `_quarto.yml` is required —
   see [Known limitations](#known-limitations)):

   ```bash
   quarto add <owner>/officequarto
   ```

2. **Activate the hook and reference the original document** — in the project's `_quarto.yml`:

   ```yaml
   project:
     type: officequarto   # activates the write-back hook - required step, see below!

   format:
     docx:
       reference-doc: original.docx   # your existing Word document
   ```

   > **Important:** `quarto add` alone only installs the extension files. Without
   > `project: type: officequarto` in your own `_quarto.yml` the hook does **not** run — this is
   > not a zero-config mechanism (see [`dev/spike-notes.md`](dev/spike-notes.md)).

3. **Render:**

   ```bash
   quarto render
   ```

   The `*.docx` produced by Quarto/Pandoc is then automatically overwritten in place with the
   document metadata taken from `original.docx` — no second file is created. If you also want to
   keep the plain, unpatched Pandoc output for debugging, enable that with
   `officequarto-keep-rendered: true` (see below).

A complete example lives in [`template/`](template/): `original.docx` (sample template with its
own header/footer/custom properties/custom styles) + `report.qmd` + `_quarto.yml`.

## Architecture

```
_extensions/officequarto/
├── _extension.yml            contributes: project: { project: { type: default,
│                                                       post-render: [scripts/writeback.R] } }
└── scripts/
    ├── writeback.R           post-render hook (orchestration)
    ├── style_mapping.R       style-mapping core logic, sourced by writeback.R
    └── style_pruning.R       style-pruning core logic, sourced by writeback.R

template/                     example project (quarto use template)
├── _quarto.yml                project: type: officequarto, format.docx.officequarto-styles
├── original.docx              sample template (incl. three ACME custom styles)
└── report.qmd                 format: docx: reference-doc: original.docx
```

What happens on `quarto render`:

1. Pandoc/Quarto render the `.qmd` with `original.docx` as `reference-doc`. **This alone is
   enough** to carry over the original's styles, header, footer, and section properties — that's
   native Pandoc behavior, no custom code involved.
2. The post-render hook `scripts/writeback.R` then runs automatically: it resolves the path to
   `reference-doc` via `quarto inspect`, works on a copy of the freshly rendered `.docx` in a
   temporary directory, and transfers `docProps/core.xml` (subject, keywords, description,
   category) and `docProps/custom.xml` (freely defined custom properties) from the original into
   it — metadata that Pandoc otherwise replaces with fresh, empty values when rendering. The
   result then overwrites the `.docx` produced by Quarto in place; the original (`reference-doc`)
   is left untouched. With `officequarto-keep-rendered: true`, the plain, unpatched Pandoc output
   is additionally saved beforehand as `<name>.quarto-rendered.docx` (analogous to Quarto's own
   `keep-md` — handy for debugging, to see what Pandoc would have produced without the hook).
   It also strips any style definitions from `word/styles.xml` that Pandoc added but that aren't
   present in `reference-doc` (see [Style pruning](#style-pruning-keeping-only-reference-doc-styles)
   below).

Why no manual body replacement? That was the original plan (strip the original's body, insert the
rendered content). A spike showed that `reference-doc` already handles this completely for the
body — an additional XML merge step with `officer` added no value and also ran into an edge-case
bug in `officer 0.7.3` when merging two structurally very similar documents. Details in
[`dev/spike-notes.md`](dev/spike-notes.md).

## Style-mapping: map body text and lists onto your own Word styles

Pandoc renders body paragraphs and lists using the styles/layout defined in `reference-doc`, but
it does so under **its own, fixed style names** (depending on context, e.g. `Normal`,
`FirstParagraph`, or `Compact`) rather than your own, possibly differently named styles in the
template (e.g. `Fließtext` in a German corporate template). `officequarto` lets you customize
this — analogous to [{officedown}](https://github.com/ardata-fr/officedown)'s
`mapstyles`/`ol.style`/`ul.style`, optional and configurable per role:

```yaml
format:
  docx:
    reference-doc: original.docx
    officequarto-styles:
      body: "Fließtext ACME"                # real style name from original.docx
      list-bullet: "Aufzählung ACME"
      list-number: "Nummerierung ACME"
```

You provide the style **name** visible in the Word UI (not the internal style ID) — the hook
resolves that itself against `word/styles.xml` of `reference-doc`. All three fields are optional
and independent; roles that aren't configured stay on Pandoc's default styles.

How it works: body paragraphs are detected via an allowlist of known Pandoc body roles (`Normal`,
`FirstParagraph`, `Compact`, `BodyText`/`Body Text`); list paragraphs are detected via the presence
of `<w:numPr>` (not by style name, since Pandoc uses the same style for both bullet and numbered
lists). Bullet vs. numbered is distinguished via `word/numbering.xml` (`w:numFmt`: `bullet` vs.
anything else) — exactly as in {officedown}, there is **one style per list type, not per nesting
level**. If a configured style name doesn't exist in `reference-doc`, the hook aborts with a list
of the available paragraph styles instead of silently ignoring the misconfiguration.

## Style pruning: keeping only reference-doc styles

Pandoc's docx writer unconditionally adds its own style definitions on top of whatever
`reference-doc` already defines — most notably a full set of syntax-highlighting styles
(`SourceCode`, `KeywordTok`, `StringTok`, ...) for code blocks, regardless of whether the rendered
document actually contains any. `reference-doc` itself is never affected (Pandoc copies its styles
unchanged), but the rendered output ends up with extra style definitions that were never part of
your template. {officedown} has the same behavior, since it's a general property of Pandoc's
docx writer, not something specific to how `reference-doc` is used.

`officequarto` removes these again — **always, no configuration needed**: after the metadata merge
and style-mapping step, the hook compares every style ID in the rendered `word/styles.xml` against
`reference-doc`'s own style IDs and deletes anything that isn't there. The result contains
*exactly* the styles defined in `reference-doc`, nothing added by Pandoc.

If a style that gets removed this way is still actually used somewhere in the rendered content
(e.g. a real code block using a syntax-highlighting style your `reference-doc` doesn't define, or
— if you're not using `officequarto-styles` — Pandoc's own body/list role names like
`FirstParagraph`/`Compact` if your `reference-doc` happens not to define them), it is still
removed; the affected paragraph or run just falls back to Word's default formatting for that spot.
The hook logs a warning listing exactly which still-used styles got stripped, so you know to either
add that style to `reference-doc` or map the paragraphs to an existing style via
`officequarto-styles`.

### Opting back in for code blocks: `officequarto-pandoc-styles.code-block`

Since code-block styling is the most common reason to hit the warning above, there's a dedicated,
optional escape hatch. It lives in its own section, `officequarto-pandoc-styles`, a sibling of
`officequarto-styles` — since it's about Pandoc-added styles, not about remapping your own
reference-doc styles:

```yaml
format:
  docx:
    officequarto-styles:
      body: "Fließtext ACME"
      # ...
    officequarto-pandoc-styles:
      code-block: true                # keep Pandoc's own code-block styling as-is
      # code-block: "My Code Style"   # ...or map the code-block paragraphs to your own style
```

- Unset (the default): unchanged behavior — code-block styles are dropped like any other
  Pandoc-added extra.
- `true`: `SourceCode` and all `*Tok` syntax-highlighting character styles are exempted from
  pruning and kept exactly as Pandoc generated them — code blocks render with full syntax
  highlighting.
- a style name (string): only the `SourceCode` paragraph role is remapped to that style (must
  exist in `reference-doc`, same fail-loud resolution as `body`/`list-bullet`/`list-number`) — you
  get your own block formatting (font/indentation/shading), but the `*Tok` character styles are
  still pruned, so syntax-highlighting colors are still dropped. Block formatting and
  syntax-highlighting colors are deliberately independent concerns; there's no option to combine a
  custom block style with kept highlighting colors.

## Keeping a debug artifact: `officequarto-keep-rendered`

By default, the hook overwrites the `.docx` produced by Quarto directly — no second file is
created. To compare/debug (e.g. "what did Pandoc produce without officequarto?"), you can keep the
plain, unpatched Pandoc output as well, analogous to Quarto's own `keep-md`:

```yaml
format:
  docx:
    officequarto-keep-rendered: true   # optional, default: false
```

This additionally produces `<name>.quarto-rendered.docx` next to the final `<name>.docx`, holding
the unmodified Pandoc output (no metadata merge, no style-mapping).

## Requirements

- `quarto` (tested with 1.8.24) and `pandoc` (tested with 3.10.1) in `PATH`
- `Rscript` in `PATH` — the post-render hook is an R script. If `Rscript` itself is missing, Quarto
  aborts with its own error message before our script even starts; that can't be caught from
  within the script.
- R packages `xml2` and `jsonlite` (`install.packages(c("xml2", "jsonlite"))`) — the hook checks
  at startup whether both are available and otherwise aborts with a clear message.
- The command-line tools `zip`/`unzip` in `PATH` (present by default on macOS/Linux)

## Known limitations

- **Only works inside a Quarto project** (`_quarto.yml` present). According to the official Quarto
  documentation, pre-/post-render scripts are a project-only feature and do not run for
  `quarto render singlefile.qmd` without a project (see
  [quarto-dev/quarto-cli#13032](https://github.com/quarto-dev/quarto-cli/issues/13032)).
- The prototype writes back **document metadata** (subject/keywords/description/category/custom
  properties), not the body — that's already correct via `reference-doc`. Bookmark-precise,
  partial insertion of content into a larger, fixed body of the original (true
  {officedown}/content-control parity) is a possible future extension, but deliberately out of
  scope for this prototype.
- No full {officedown} feature parity (cross-references, special `flextable` handling, table of
  contents field updates, comments, tracked changes).
- Round-trip fidelity is inherently limited: if the rendered Pandoc document doesn't yet know the
  `docProps/custom.xml` part itself (registered in `[Content_Types].xml`/`_rels/.rels`), simply
  overwriting that file wouldn't register it (see `dev/spike-notes.md`).
- The hook overwrites the rendered `.docx` in place. If the file is open in another program at
  that point (e.g. Word), the overwrite can fail, or the program may keep showing the old state
  until manually reloaded.
- Style-mapping only patches `word/document.xml` (the main body), not footnotes/comments, and
  offers one style per list type (bullet/numbered) rather than per nesting level. Body detection
  relies on an allowlist of known Pandoc role names — a reference-doc that makes Pandoc render body
  text under a not-yet-listed role name won't be recognized.
- Style pruning is unconditional: if content actually uses a Pandoc-added style your `reference-doc`
  doesn't define (typically syntax-highlighted code blocks, or Pandoc's own body/list role names
  when `officequarto-styles` isn't configured for that role), that style definition is still
  removed and the content falls back to Word's default formatting — see
  [Style pruning](#style-pruning-keeping-only-reference-doc-styles).

## Development / tests

```bash
cd template
quarto render report.qmd
Rscript ../dev/check_writeback.R   # checks header/footer/body/metadata of the result
```

`dev/make_sample_docx.R` regenerates the sample template `template/original.docx`, including the
three ACME custom styles used for style-mapping (requires the R packages `officer` and `xml2`,
only for generating the sample template, not for the hook itself).
