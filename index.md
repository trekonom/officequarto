# officequarto

officequarto builds on a capability Quarto already has: rendering
`.docx` output against a Word `reference-doc`, which natively carries
over its styles, layout, headers, and footers. officequarto adds a
post-render step on top of that — filling in the document properties
Pandoc doesn’t carry over, and applying any additional style, table,
figure, or caption formatting you configure — all through one
`_quarto.yml` key, bundled as a ready-to-use Quarto project type. It
follows the same basic idea as
[{officedown}](https://github.com/ardata-fr/officedown), but for Quarto
instead of R Markdown.

## Installation

``` r

pak::pak("trekonom/officequarto")
```

## Usage

officequarto is an R package with its Quarto extension bundled inside —
installing the package is the only setup step; scaffolding a project
copies the extension in for you.

**Scaffold a new project**, pointing at your existing Word document:

``` r

officequarto::oq_create_project("my-report", reference_doc = "original.docx")
```

This creates `my-report/` with a `_quarto.yml` already wired up to
`original.docx` (see
[`vignette("options", package = "officequarto")`](https://trekonom.github.io/officequarto/articles/options.md)
for every available option), a copy of `original.docx`, the officequarto
extension, and a starter `.qmd` — ready to render:

``` bash
cd my-report
quarto render
```

The resulting `.docx` picks up `original.docx`’s styles, headers, and
footers automatically, and its document properties (subject, keywords,
description, category) are filled in from the original too — no second
output file is created. Want to keep the raw, unpatched Pandoc output
alongside it for comparison? Set `officequarto.keep-rendered: true` in
`_quarto.yml`.

Prefer to wire up an existing project by hand instead of scaffolding a
new one? Add `project: type: officequarto` and
`format.docx.reference-doc: <your .docx>` to its `_quarto.yml`, then
copy `system.file("_extensions", package = "officequarto")` into the
project root as `_extensions/officequarto/` — that’s exactly what
[`oq_create_project()`](https://trekonom.github.io/officequarto/reference/oq_create_project.md)
automates.
[`oq_create_quarto_yml()`](https://trekonom.github.io/officequarto/reference/oq_create_quarto_yml.md)
writes just the `_quarto.yml` part of that (every `officequarto` option
at its default value) as a standalone file — a starting point to
hand-edit, or to drop into an existing project you’re converting to
officequarto.

Already have a `_quarto.yml` you want
[`oq_create_project()`](https://trekonom.github.io/officequarto/reference/oq_create_project.md)
to use as-is, instead of generating one? Pass it as `quarto_yml`:

``` r

officequarto::oq_create_project(
  "my-report",
  reference_doc = "original.docx",
  quarto_yml = "my-quarto.yml"
)
```

It’s copied in verbatim — make sure it already sets
`format.docx.reference-doc` to match `original.docx`’s basename if you
supply both.

A complete example lives in
[`template/`](https://trekonom.github.io/officequarto/template/):
`original.docx` (sample template with its own header/footer/custom
properties/custom styles) + `report.qmd` + `_quarto.yml`.

## Learn more

- [`vignette("architecture", package = "officequarto")`](https://trekonom.github.io/officequarto/articles/architecture.md)
  — how the package and bundled extension fit together.
- [`vignette("options", package = "officequarto")`](https://trekonom.github.io/officequarto/articles/options.md)
  — every `officequarto.*` option: style-mapping, lists, tables,
  figures, captions, page layout, cross-references, and more.
- [`vignette("officer-syntax", package = "officequarto")`](https://trekonom.github.io/officequarto/articles/officer-syntax.md)
  — using {officer}’s run/paragraph/block constructors directly inline
  in a `.qmd`.

## Known limitations

- Only works inside a Quarto **project** (a `_quarto.yml` must be
  present) — `quarto render singlefile.qmd` without a project won’t
  trigger officequarto’s write-back step.
- officequarto writes back document **metadata and styling**, not body
  content — the body itself already comes from `reference-doc` via
  Pandoc’s native rendering.
- Not a full {officedown} replacement: no special `flextable` handling,
  table-of-contents field updates, comments, or tracked changes.
- If the rendered `.docx` is open in Word while rendering, the
  write-back can fail or go unnoticed until the file is reloaded — close
  it first.

See
[`vignette("options")`](https://trekonom.github.io/officequarto/articles/options.md)
for the full list of implementation-level caveats and edge cases.

## Getting help

Found a bug or have a question? Please [open an
issue](https://github.com/trekonom/officequarto/issues).

## Contributing

Want to contribute? See
[`CONTRIBUTING.md`](https://trekonom.github.io/officequarto/CONTRIBUTING.md)
for development setup, tests, and the end-to-end render checks.
