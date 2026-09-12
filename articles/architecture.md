# Package architecture

officequarto is an R package
(`DESCRIPTION`/`NAMESPACE`/`R/`/`tests/testthat/` at the repo root) that
also bundles the Quarto extension it powers, under `inst/`:

    R/                             package logic - one exported function, oq_writeback(), everything
    │                               else internal; a package loads all of R/*.R into one namespace at
    │                               once, so file boundaries below are purely organizational
    ├── writeback.R                 oq_writeback() - post-render hook orchestration (exported)
    ├── create-project.R            oq_create_project() - project scaffolding (exported)
    ├── style-mapping.R              style-mapping core logic
    ├── style-pruning.R              style-pruning core logic
    ├── option-aliases.R             canonical-name/officedown-alias resolution
    ├── table-mapping.R              table style/layout/width/conditional-formatting logic
    ├── table-caption-mapping.R      table caption style/prefix/separator/bold logic (also the
    │                                shared, generic caption-rewriting logic reused by
    │                                plot-caption-mapping.R)
    ├── plot-mapping.R                figure style/align logic
    ├── plot-caption-mapping.R        figure caption paragraph detection
    ├── style-map.R                   free-form style-map (mapstyles) logic
    ├── page-mapping.R                page size/margins (section properties) logic
    └── crossref-mapping.R            cross-reference text rewriting logic

    inst/_extensions/officequarto/  the Quarto extension itself - installed alongside the package,
    ├── _extension.yml               reachable via system.file("_extensions", package = "officequarto");
    │                                contributes: project: { project: { type: default,
    │                                post-render: [scripts/writeback.R] } }
    └── scripts/
        └── writeback.R              thin shim: requireNamespace("officequarto") + officequarto::oq_writeback()

    template/                       example/dev project (this package's own fixture, not shipped)
    ├── _quarto.yml                  project: type: officequarto, format.docx.officequarto
    ├── original.docx                 sample template (incl. sixteen ACME custom paragraph styles)
    ├── report.qmd                    format: docx: reference-doc: original.docx
    └── _extensions                   symlink -> ../inst/_extensions (dev convenience only)

## What happens on `quarto render`

1.  Pandoc/Quarto render the `.qmd` with `original.docx` as
    `reference-doc`. **This alone is enough** to carry over the
    original’s styles, header, footer, and section properties — that’s
    native Pandoc behavior, no custom code involved.
2.  The post-render hook then runs automatically (the thin shim in
    `_extensions/officequarto/scripts/writeback.R` calls the package’s
    exported
    [`oq_writeback()`](https://trekonom.github.io/officequarto/reference/oq_writeback.md)):
    it resolves the path to `reference-doc` via `quarto inspect`, works
    on a copy of the freshly rendered `.docx` in a temporary directory,
    and transfers `docProps/core.xml` (subject, keywords, description,
    category) and `docProps/custom.xml` (freely defined custom
    properties) from the original into it — metadata that Pandoc
    otherwise replaces with fresh, empty values when rendering. The
    result then overwrites the `.docx` produced by Quarto in place; the
    original (`reference-doc`) is left untouched. With
    `officequarto.keep-rendered: true`, the plain, unpatched Pandoc
    output is additionally saved beforehand as
    `<name>.quarto-rendered.docx` (analogous to Quarto’s own `keep-md` —
    handy for debugging, to see what Pandoc would have produced without
    the hook). It also strips any style definitions from
    `word/styles.xml` that Pandoc added but that aren’t present in
    `reference-doc` (see
    [`vignette("options")`](https://trekonom.github.io/officequarto/articles/options.md)’s
    “Style pruning” section).

## Why no manual body replacement?

That was the original plan (strip the original’s body, insert the
rendered content). A spike showed that `reference-doc` already handles
this completely for the body — an additional XML merge step with
`officer` added no value and also ran into an edge-case bug in
`officer 0.7.3` when merging two structurally very similar documents.
Details in
[`dev/spike-notes.md`](https://github.com/trekonom/officequarto/blob/main/dev/spike-notes.md).
