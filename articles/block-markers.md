# Block markers: TOC, page breaks and landscape sections

{officedown} lets an `.Rmd` place a table of contents, page breaks and
landscape sections with HTML-comment markers such as
`<!---BLOCK_TOC--->`. Quarto has no equivalent of the `post_knit` step
that processes them, so in a plain Quarto render they are silently
dropped as HTML comments. The `officequarto` extension ships a small
Pandoc Lua filter (`scripts/markers.lua`) that brings them back for
**docx** output. It is active in every `officequarto` project
(`project: type: officequarto`); there is nothing to configure.

Like
[`vignette("officer-syntax")`](https://trekonom.github.io/officequarto/articles/officer-syntax.md),
this is not an `officequarto.*` option — it works the same regardless of
your `_quarto.yml` settings.

## Markers

Each marker must be on its own line, with blank lines around it.

| Marker | Result |
|----|----|
| `<!---BLOCK_TOC--->` | A live Word table of contents field (heading levels 1–3). Word fills it in on open / field update. |
| `<!---BLOCK_PAGEBREAK--->` | A page break. |
| `<!---BLOCK_LANDSCAPE_START--->` | Ends the portrait section before it. |
| `<!---BLOCK_LANDSCAPE_STOP--->` | Ends the landscape section (A4 landscape). |
| `<!---BLOCK_LANDSCAPE_STOP {"w":15840,"h":12240}--->` | Same, with a custom page size in twips (1/1440 inch). |

``` markdown
<!---BLOCK_TOC--->

# Portrait part

Text.

<!---BLOCK_LANDSCAPE_START--->

# Wide part

A wide table or figure.

<!---BLOCK_LANDSCAPE_STOP--->

# Portrait again
```

## Differences to {officedown}

- Only the markers listed above exist. `BLOCK_POUR_DOCX` and
  `BLOCK_MULTICOL_START/STOP` are not supported; for those, use the
  officer syntax from
  [`vignette("officer-syntax")`](https://trekonom.github.io/officequarto/articles/officer-syntax.md)
  (`block_pour_docx()`, `block_section()`).
- Marker arguments are limited to `w` and `h` (in twips) on
  `BLOCK_LANDSCAPE_STOP`, not officedown’s full YAML argument syntax.
- A section break carries only the page size: margins, headers and
  footers of the new section are Word’s defaults for a section without
  its own settings, not copied from the first section.
- Don’t combine landscape markers with `officequarto.page` — that option
  rewrites the page size of every section in the document, including the
  landscape ones.
- Unknown `BLOCK_*` names are left alone and stay inert HTML comments.
