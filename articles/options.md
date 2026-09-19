# Configuring officequarto

Every option below lives nested under a single
`format.docx.officequarto` key — no `officequarto-`-prefixed sibling
keys. Each group (`styles`, `lists`, `tables`, `plots`, …) is a
subsection inside it:

``` yaml
format:
  docx:
    reference-doc: original.docx
    officequarto:
      keep-rendered: true
      styles:
        body: "Fließtext ACME"
      lists:
        list-bullet: "Aufzählung ACME"
      tables:
        style: "Tabelle ACME"
      # ... plots, style-map, page, crossref, pandoc-styles - see below
```

officedown aliases (`ul_style`, `tables_width`, `plots_topcaption`, …)
are unaffected by this — see [officedown aliases](#officedown-aliases)
below.

## Style-mapping

Pandoc renders body paragraphs using the styles defined in
`reference-doc`, but does so under **its own, fixed style names**
(depending on context, e.g. `Normal`, `FirstParagraph`, or `Compact`)
rather than your own, possibly differently named style in the template
(e.g. `Fließtext` in a German corporate template).
`officequarto.styles.body` lets you customize this — analogous to
[{officedown}](https://github.com/ardata-fr/officedown)’s
`mapstyles`/`Normal` mapping:

``` yaml
format:
  docx:
    reference-doc: original.docx
    officequarto:
      styles:
        body: "Fließtext ACME"   # real style name from original.docx
```

You provide the style **name** visible in the Word UI (not the internal
style ID) — the hook resolves that itself against `word/styles.xml` of
`reference-doc`. Body paragraphs are detected via an allowlist of known
Pandoc body roles (`Normal`, `FirstParagraph`, `Compact`, `BodyText`/
`Body Text`). If a configured style name doesn’t exist in
`reference-doc`, the hook aborts with a list of the available paragraph
styles instead of silently ignoring the misconfiguration. This allowlist
never matches footnote/endnote text, even though those are otherwise
reachable by other style-mapping mechanisms — see [Footnotes and
endnotes](#footnotes-and-endnotes) below.

## Lists

`officequarto.lists` mirrors `officequarto.styles.body` for list
paragraphs — analogous to {officedown}’s `ol.style`/`ul.style`:

``` yaml
format:
  docx:
    officequarto:
      lists:
        list-bullet: "Aufzählung ACME"
        list-number: "Nummerierung ACME"
        list-letter: "Buchstabierung ACME"    # a/b/c or A/B/C lists - officequarto-only, no officedown equivalent
```

All three fields are optional and independent; roles that aren’t
configured stay on Pandoc’s default styles. List paragraphs are detected
via the presence of `<w:numPr>` (not by style name, since Pandoc uses
the same style regardless of list type). List type is distinguished via
`word/numbering.xml` (`w:numFmt`): `bullet` → `list-bullet`;
`lowerLetter`/`upperLetter` (from markdown `a.`/`A.` markers) →
`list-letter`; anything else (`decimal`, roman numerals, …) →
`list-number`.

### Per-nesting-level styles

Each of `list-bullet`/`list-number`/`list-letter` also accepts an
**array** of style names instead of a single value — one style per
nesting level, index 0 = the top level:

``` yaml
officequarto:
  lists:
    list-bullet: ["Aufzählung ACME", "Aufzählung ACME 2", "Aufzählung ACME 3"]
```

A nesting level deeper than the array clamps to the deepest configured
entry — the same convention Word’s own built-in styles use
(`List Bullet`/`List Bullet 2`/`List Bullet 3`: nothing beyond level 3
either, deeper indents just keep reusing it). A plain scalar still works
exactly as before (the same style at every level) — this is an
**officequarto-only extension**, {officedown} has no per-nesting-level
equivalent for `ol.style`/`ul.style`.

### officedown aliases

`officequarto` uses its own, more descriptive option names
(e.g. `list-bullet`/`list-number`) rather than copying {officedown}’s
option names verbatim. If you’re coming from {officedown}, though, its
original option names remain usable as **aliases** in the same
`officequarto.lists` section, so you don’t have to relearn names you
already know:

``` yaml
officequarto:
  lists:
    list-bullet: "Aufzählung ACME"   # canonical name
    # ul_style: "Aufzählung ACME"    # ...or the officedown alias — same effect
```

If both the canonical name and its alias are set to *different* values,
the canonical name wins and the hook logs a warning naming the discarded
alias value. See [Option reference](#option-reference) for the full
canonical-name/alias table (filled in incrementally as more {officedown}
option groups are ported).

## Table options

`officequarto.tables` lets you control how every table in the rendered
document is formatted — analogous to {officedown}’s `tables` option,
ported as the first group of a broader {officedown}-option port (see
[Option reference](#option-reference)):

``` yaml
format:
  docx:
    officequarto:
      tables:
        style: "Tabelle ACME"    # Word table style name, resolved like officequarto.styles.body
        layout: fixed            # "autofit" or "fixed"
        width: 0.8                # relative to page width (0..1)
        # tables_style/tables_layout/tables_width also work as officedown aliases, same
        # conflict rule as officequarto.lists' ol_style/ul_style (see officedown aliases above)
```

All three fields are independently optional (per-field opt-in, like
`officequarto.styles`/ `officequarto.lists`) — an unset field is left
exactly as Pandoc rendered it, there’s no forced fallback to
officedown’s own defaults. `style` is resolved against `reference-doc`’s
**table** styles (not paragraph styles), same fail-loud lookup as
`body`/`list-bullet`/etc. `layout`/`width` are written directly onto
every table’s `w:tblPr` (`w:tblLayout`/`w:tblW`), inserted in
OOXML-schema order alongside whatever `w:tblPr` children Pandoc already
produced.

officedown’s `tab.lp` option (a bookdown cross-reference label-prefix)
is deliberately **not** ported — it’s an authoring-syntax concept with
no equivalent once Quarto has already resolved cross-references before
this hook ever runs. If you need to change the visible “Table”/“Figure”
caption prefix text, use Quarto’s own native
`crossref.tbl-title`/`crossref.fig-title` in your `_quarto.yml` instead
— no `officequarto` option needed for that.

### Table conditional formatting

`officequarto.tables.conditional` controls Word’s “Table Style Options”
checkboxes (Header Row, Total Row, First/Last Column, Banded
Rows/Columns) — which variant of the table style’s conditional
formatting gets applied to each table:

``` yaml
format:
  docx:
    officequarto:
      tables:
        conditional:
          first-row: true       # highlight header row
          first-column: false
          last-row: false
          last-column: false
          band-rows: true       # alternating row shading
          band-columns: false
```

Each field is independently optional, same as `style`/`layout`/`width`.
`band-rows`/`band-columns` are officequarto’s own, positively-phrased
names for officedown’s `no_hband`/`no_vband` — the officedown aliases
(`tables_conditional_no_hband`/`tables_conditional_no_vband`) still work
but carry the *opposite* polarity (`no_hband: false` means the same
thing as `band-rows: true`); the hook resolves and negates them
correctly, including the conflict warning if both are set to
contradictory values.

### Table captions

`officequarto.tables.caption` controls how table captions are formatted
— analogous to {officedown}’s `tables.caption`:

``` yaml
format:
  docx:
    officequarto:
      tables:
        caption:
          style: "Beschriftung ACME"            # paragraph style for the caption
          prefix: "Tab. "                       # text before the number (officedown: pre)
          separator: " -- "                     # text between number and caption (officedown: sep)
          number-bold: true                     # bold the "prefix + number" portion only
```

Each field is independently optional. `style` remaps Pandoc’s caption
paragraph role the same way `code-block` remaps `SourceCode` — for
tables specifically, this is `TableCaption` for a plain markdown caption
(`: My caption`, no crossref ID) or the `ImageCaption` role shared with
figures for a Quarto crossref-managed one (`{#tbl-xyz}`); officequarto
detects which structure applies and only touches paragraphs structurally
identified as table captions, not figure ones — see
[`dev/spike-notes.md`](https://github.com/trekonom/officequarto/blob/main/dev/spike-notes.md)
(Spike L) for the empirical trail.

`prefix`/`separator`/`number-bold` are inherently more fragile than
everything else in `officequarto`, and it’s worth understanding why:
Quarto’s docx table captions currently render as **static,
already-baked-in text** (e.g. `"Table 1: My caption"` as a single text
run), not a real Word field — there’s no live number to hook into.
`officequarto` rewrites that text after the fact by locating the
sequential table number it printed (counting captioned tables in
document order, the same way Quarto itself numbers them) and splicing in
your configured prefix/separator around it. The one part of Pandoc’s
generated text this approach doesn’t try to predict is the *shape* of
the auto-generated prefix itself — it can vary with your own
`crossref.tbl-title`/`title-delim` settings, and is additionally
reshaped by Pandoc’s smart-typography conversion (e.g. a configured `--`
becomes a real “–” character, with a non-breaking space before the
number) — so rather than reconstructing that string from config,
`officequarto` anchors on the number itself (immune to typographic
conversion) to find the split point. If a caption doesn’t match the
expected “prefix + number + separator + text” shape, it’s left untouched
rather than guessed at. Note this only applies to a Quarto
crossref-numbered caption in the first place — a plain markdown caption
(no `{#tbl-xyz}`) is never auto-numbered by Quarto at all, so there’s no
generated prefix to split out; `style` still applies to it, but
`prefix`/`separator`/`number-bold` only make sense for numbered
captions.

officedown’s `tnd`/`tns` (per-section numbering depth, e.g. `"2-1"`) are
**not** ported — Quarto numbers tables globally, not per heading
section, so there’s no existing per-section counter to key off;
replicating that would mean officequarto tracking heading boundaries and
maintaining its own numbering scheme, a substantially larger feature
with no direct precedent elsewhere in this project.

### All table options together

Every `officequarto.tables` field shown in one place, including
`caption.above` (explained in [Caption position](#caption-position)
below — easy to miss if you only skim the sections above, since it’s
documented together with figures rather than repeated per group):

``` yaml
format:
  docx:
    officequarto:
      tables:
        style: "Tabelle ACME"           # Word table style name
        layout: fixed                    # "autofit" or "fixed"
        width: 0.8                       # relative to page width (0..1)
        conditional:
          first-row: true                # highlight header row
          first-column: false            # highlight first column
          last-row: false                # highlight total row
          last-column: false             # highlight last column
          band-rows: true                # alternating row shading
          band-columns: false            # alternating column shading
        caption:
          style: "Beschriftung ACME"     # paragraph style for the caption
          prefix: "Tab. "                # text before the number
          separator: " -- "              # text between number and caption
          number-bold: true              # bold the "prefix + number" portion only
          above: false                   # move the caption after the table (Pandoc's default is already "above")
```

Every field here is independently optional — shown together only for
reference; normally you’d set just the ones you need. See the sections
above for what each one does, its default, and its officedown alias
(also summarized in [Option reference](#option-reference)).

## Figure options

`officequarto.plots` controls the paragraph holding each figure —
analogous to {officedown}’s `plots` option:

``` yaml
format:
  docx:
    officequarto:
      plots:
        style: "Abbildung ACME"   # paragraph style for the image paragraph
        align: right               # "left", "center", or "right"
```

Both fields independently optional, same per-field opt-in as everywhere
else. Figure paragraphs are detected by the presence of a `w:drawing`
(not by style name — Pandoc reuses the same context-dependent role names
for image paragraphs as for body text, e.g. `Compact`, verified
empirically; `officequarto.styles.body` explicitly excludes
drawing-paragraphs so the two features don’t compete for the same
paragraph).

officedown’s `fig.lp` is dropped for the same reason as `tab.lp` (see
above) — no Quarto/post-render equivalent. `topcaption` (caption
position) was implemented together for both tables and figures — see
[Caption position](#caption-position) below.

### Figure captions

`officequarto.plots.caption` mirrors [table captions](#table-captions)
exactly — same fields, same text-parsing approach and its caveats, same
`tnd`/`tns` exclusion rationale, just for figures. Unlike tables, Pandoc
always uses the `ImageCaption` role for figure captions, with or without
a crossref ID:

``` yaml
format:
  docx:
    officequarto:
      plots:
        caption:
          style: "Abbildungsbeschriftung ACME"
          prefix: "Abb. "
          separator: " | "
          number-bold: false
```

Table and figure captions are structurally distinguished by direct
positional adjacency (a table caption is immediately followed by the
table; a figure caption is immediately preceded by the image paragraph)
— see [Table captions](#table-captions) above for the full mechanism;
the actual text-rewriting logic is shared code, only the
paragraph-finding differs.

### Caption position

Both `officequarto.tables.caption` and `officequarto.plots.caption`
accept an `above` field (officedown: `topcaption`) that moves the
caption paragraph before or after its table/figure:

``` yaml
officequarto:
  tables:
    caption:
      above: false   # move the table caption after the table (Pandoc's own default is already "above")
  plots:
    caption:
      above: true    # move the figure caption before the image (Pandoc's own default is already "below")
```

Worth knowing before you reach for this: Pandoc’s own, unconfigured
default already matches {officedown}’s per-type default (tables: caption
above; figures: caption below) — `above` only needs setting when you
want to *override* that default, e.g. to force a table’s caption below
it. Leave it unset otherwise. `above` lives under `caption` rather than
as a top-level `officequarto.tables`/`officequarto.plots` field, grouped
with the rest of the caption options since that’s what it affects.

### All figure options together

Every `officequarto.plots` field shown in one place, mirroring [All
table options together](#all-table-options-together) above:

``` yaml
format:
  docx:
    officequarto:
      plots:
        style: "Abbildung ACME"                    # paragraph style for the image paragraph
        align: right                                # "left", "center", or "right"
        caption:
          style: "Abbildungsbeschriftung ACME"      # paragraph style for the caption
          prefix: "Abb. "                            # text before the number
          separator: " | "                           # text between number and caption
          number-bold: false                         # explicit "not bold" (overrides any inherited bold)
          above: true                                 # move the caption before the image (Pandoc's default is already "below")
```

Every field here is independently optional — shown together only for
reference; normally you’d set just the ones you need.

## Free-form style mapping

The curated options above (`officequarto.styles`, `officequarto.lists`,
`officequarto.tables`, `officequarto.plots`) cover the common cases with
dedicated detection logic (list markers, drawings, table structure).
`officequarto.style-map` is a generic escape hatch for everything else —
analogous to {officedown}’s `mapstyles`, remapping any Pandoc-rendered
paragraph style directly by name:

``` yaml
format:
  docx:
    officequarto:
      style-map:
        "Titel ACME": [Title]
        "Zitat ACME": [BlockQuote]
```

Keys are real Word style **display names** in `reference-doc` (resolved
the same fail-loud way as `body`/`list-bullet`/etc.); values are lists
of **source paragraph style IDs** to redirect to that target — unlike
the target side, these are matched as literal, technical Pandoc style
IDs (e.g. `Title`, `Heading1`, `BlockQuote`), not resolved against
display names, since they’re generally stable, well-known
Pandoc-internal identifiers rather than something you’d look up in
Word’s UI. A source ID that doesn’t occur in the document is simply a
no-op, not an error; a source ID assigned to two different targets is a
configuration error and aborts.

> **Caveat — source IDs for built-in Word roles are not always
> portable.** For a genuinely Pandoc-invented role (`Normal`,
> `FirstParagraph`, `Compact`, `SourceCode`, `ImageCaption`/
> `TableCaption`), the source ID is always the same regardless of
> `reference-doc`. But for a role that has a real *built-in Word
> equivalent* — confirmed for blockquotes (`> ...` in Markdown) — Pandoc
> reuses whatever style ID your `reference-doc` already defines for that
> built-in role instead of a fixed generic one, and that ID can be
> **localized** (e.g. a Dutch-authored template may use `Bloktekst` for
> its “Block Text” style, not `BlockQuote`) — the same phenomenon
> documented for caption styles above. If a `style-map` rule silently
> matches 0 paragraphs, render with `officequarto.keep-rendered: true`
> and check the actual `pStyle` in `<name>.quarto-rendered.docx` rather
> than assuming a name like `BlockQuote` from this example. See
> [`dev/spike-notes.md`](https://github.com/trekonom/officequarto/blob/main/dev/spike-notes.md)
> (Spike M) for the empirical trail.

This runs **last**, after every other style-mapping step, so by default
it only affects paragraphs none of the curated options already touched —
but since it matches on whatever `pStyle` a paragraph currently has, it
can also be pointed at an already-remapped target name to override it
further, if you deliberately want that.

## Footnotes and endnotes

`officequarto.lists.*`, `officequarto.pandoc-styles.code-block`, and
`officequarto.style-map` are all applied to
`word/footnotes.xml`/`word/endnotes.xml` in addition to the main body —
e.g. a bullet list or code block inside a footnote gets the same styling
as one in the body.

`officequarto.styles.body` does **not** apply to footnote/endnote text,
and this isn’t a missing-detection gap — it’s structural. Pandoc never
renders footnote/endnote text under one of its context-dependent body
role names (`Normal`/`FirstParagraph`/`Compact`/…). Instead, one of two
things happens, verified against real rendered output:

- If `reference-doc` defines its own built-in footnote-text style,
  Pandoc already reuses that style’s own (possibly localized) ID
  directly — the same mechanism documented for blockquotes under
  [Free-form style mapping](#free-form-style-mapping) above. No
  `officequarto` configuration is needed or possible here; it’s already
  correct.
- If `reference-doc` defines no footnote-text style at all (like this
  project’s own sample `original.docx`), Pandoc falls back to the fixed,
  un-localized OOXML reserved style ID `FootnoteText` (`EndnoteText` for
  endnotes) — a Word built-in style ID recognized natively even without
  an explicit `<w:style>` definition. To give footnotes your own styling
  in this case, redirect it like any other Pandoc-invented style via
  `officequarto.style-map`:

``` yaml
format:
  docx:
    officequarto:
      style-map:
        "Fußnotentext ACME": [FootnoteText]
        "Endnotentext ACME": [EndnoteText]
```

Only the footnote/endnote **paragraph** style (`w:pStyle`, the body-text
formatting) is covered. The footnote/endnote **marker** character style
(`FootnoteReference`/`EndnoteReference`, the small superscript number)
isn’t remapped by `officequarto` — out of scope for now.

`word/comments.xml` is still not touched by any style-mapping mechanism
(only read, for style-pruning reference counting).

## Page layout

Page size and margins already carry over from `reference-doc` natively
via Pandoc — like everything else, no configuration needed for that.
`officequarto.page` exists for a different case: overriding them
*without* editing `reference-doc` itself. Pandoc’s docx writer has no
YAML knob for this at all (unlike its LaTeX/PDF writer’s `geometry`
options), so this patches `w:sectPr`/`w:pgSz`/`w:pgMar` directly,
analogous to {officedown}’s `page_size`/`page_margins`:

``` yaml
format:
  docx:
    officequarto:
      page:
        size:
          width: 11.7      # inches
          height: 8.3
          orientation: landscape   # "portrait" or "landscape"
        margins:
          top: 0.75         # inches
          bottom: 0.75
          left: 1
          right: 1
          header: 0.4
          footer: 0.4
          gutter: 0
```

Values are in inches (matching officedown), converted internally to
twips for OOXML. Every field is independently optional, applied
uniformly to every section in the document (most documents have exactly
one `w:sectPr`; a document with genuinely different per-section layouts
isn’t the target scenario here, same as officedown’s own single-section
assumption). Setting `orientation` does **not** automatically swap
`width`/`height` — you’re responsible for consistent dimensions, same as
in officedown.

`officequarto.page` is a single combined section (unlike officedown’s
separate `page_size`/ `page_margins`), with `size`/`margins` as
sub-groups — consistent with how `officequarto.tables` groups
`conditional`/`caption` together rather than splitting into more
top-level sections. officedown’s `orient` is spelled out as
`orientation` here; its alias remains `page_size_orient` (officedown’s
actual literal option name, needed verbatim regardless of the new
spelling).

## Cross-reference text

By default, a cross-reference like `@tbl-kennzahlen` renders as just the
number (“Table 1”) — both Quarto’s own default and {officedown}’s.
`officequarto.crossref.numbered: false` (officedown: `reference_num`)
shows the caption’s descriptive text instead:

``` yaml
format:
  docx:
    officequarto:
      crossref:
        numbered: false   # show "Quartalskennzahlen" instead of "Table 1" at each @tbl-kennzahlen
```

Same underlying limitation as everywhere else that touches
captions/cross-references: Quarto resolves `@tbl-xyz`/`@fig-xyz`
references to static text (a hyperlink run reading e.g. `"Table 1"`)
before this hook ever runs, so there’s no live field to flip —
`officequarto` finds each cross-reference hyperlink whose anchor points
at a known table/figure caption and replaces its text with that
caption’s own descriptive text (the part after the number, unaffected by
any `prefix`/ `separator` customization on the caption itself). Only
takes effect when explicitly set to `false` — Pandoc’s own default
already shows the number, matching officedown’s default too, so there’s
nothing to do otherwise. Setting it (even without touching
`officequarto.tables.caption`/ `officequarto.plots.caption` directly)
still requires officequarto to walk every caption to build the anchor →
text lookup, so expect the same log lines about captions being processed
even if you haven’t configured any caption styling yourself.

## Live numbering

Everything above
(`officequarto.tables.caption`/`officequarto.plots.caption`’s `prefix`/
`separator`/`number-bold`, and `crossref.numbered: false`) works around
the same limitation: Quarto’s captions and cross-references are static,
already-baked-in text — not real Word fields — by the time this hook
runs, so there’s no live number to reformat, only text to parse and
rewrite. `officequarto.crossref.auto-number: true` closes that gap
directly instead of working around it: it converts crossref-numbered
captions and their cross-references into **real, live Word `SEQ`/ `REF`
fields** — the same mechanism Word’s own Insert Caption/Insert
Cross-reference commands produce, and the same mechanism {officedown}
uses (this project ported the field shapes directly from
{officedown}’s/{officer}’s own source). Numbers then genuinely renumber
in Word when tables or figures are added, removed, or reordered — no
re-render needed.

``` yaml
format:
  docx:
    officequarto:
      crossref:
        auto-number: true
```

- Only affects captions that Quarto actually numbers — a crossref-ID’d
  (`{#tbl-xyz}`/`{#fig-xyz}`) table or figure. Plain (non-crossref)
  captions have no generated number to begin with and are left as static
  text, same as always.
- `prefix`/`separator`/`number-bold`/`style` (under
  `tables.caption`/`plots.caption`) keep working exactly as documented
  above — same keys, same meaning — they now style the text runs
  *around* a live field instead of rewriting static text.
- **Mutually exclusive with `crossref.numbered: false`** — a live number
  and “always show descriptive text instead of a number” are
  contradictory display modes. Setting both aborts the render with an
  explicit error.
- **These are now genuinely live fields.** Unlike today’s plain static
  caption/cross-reference text, which you could freely hand-edit in
  Word, retyping the visible number will be silently overwritten the
  next time Word recalculates the field (on open, or F9) — Word computes
  these simple fields automatically during layout, without any forced
  “update fields” prompt.
- Not ported: per-chapter/section numbering restart ({officedown}’s
  `tnd`/`tns`, backed by a `STYLEREF` field) — flat, document-wide
  numbering only for now, matching Quarto’s own current numbering
  scheme.

## Style pruning

Pandoc’s docx writer unconditionally adds its own style definitions on
top of whatever `reference-doc` already defines — most notably a full
set of syntax-highlighting styles (`SourceCode`, `KeywordTok`,
`StringTok`, …) for code blocks, regardless of whether the rendered
document actually contains any. `reference-doc` itself is never affected
(Pandoc copies its styles unchanged), but the rendered output ends up
with extra style definitions that were never part of your template.
{officedown} has the same behavior, since it’s a general property of
Pandoc’s docx writer, not something specific to how `reference-doc` is
used.

`officequarto` removes these again — **always, no configuration
needed**: after the metadata merge and style-mapping step, the hook
compares every style ID in the rendered `word/styles.xml` against
`reference-doc`’s own style IDs and deletes anything that isn’t there.
The result contains *exactly* the styles defined in `reference-doc`,
nothing added by Pandoc.

If a style that gets removed this way is still actually used somewhere
in the rendered content (e.g. a real code block using a
syntax-highlighting style your `reference-doc` doesn’t define, or — if
you’re not using `officequarto.styles`/`officequarto.lists` — Pandoc’s
own body/list role names like `FirstParagraph`/`Compact` if your
`reference-doc` happens not to define them), it is still removed; the
affected paragraph or run just falls back to Word’s default formatting
for that spot. The hook logs a warning listing exactly which still-used
styles got stripped, so you know to either add that style to
`reference-doc` or map the paragraphs to an existing style via
`officequarto.styles`/`officequarto.lists`.

### Opting back in for code blocks

Since code-block styling is the most common reason to hit the warning
above, there’s a dedicated, optional escape hatch. It lives in its own
subsection, `officequarto.pandoc-styles`, a sibling of
`officequarto.styles` — since it’s about Pandoc-added styles, not about
remapping your own reference-doc styles:

``` yaml
format:
  docx:
    officequarto:
      styles:
        body: "Fließtext ACME"
        # ...
      pandoc-styles:
        code-block: true                # keep Pandoc's own code-block styling as-is
        # code-block: "My Code Style"   # ...or map the code-block paragraphs to your own style
```

- Unset (the default): unchanged behavior — code-block styles are
  dropped like any other Pandoc-added extra.
- `true`: `SourceCode` and all `*Tok` syntax-highlighting character
  styles are exempted from pruning and kept exactly as Pandoc generated
  them — code blocks render with full syntax highlighting.
- a style name (string): only the `SourceCode` paragraph role is
  remapped to that style (must exist in `reference-doc`, same fail-loud
  resolution as `body`/`list-bullet`/`list-number`) — you get your own
  block formatting (font/indentation/shading), but the `*Tok` character
  styles are still pruned, so syntax-highlighting colors are still
  dropped. Block formatting and syntax-highlighting colors are
  deliberately independent concerns; there’s no option to combine a
  custom block style with kept highlighting colors.

## Keeping a debug artifact

By default, the hook overwrites the `.docx` produced by Quarto directly
— no second file is created. To compare/debug (e.g. “what did Pandoc
produce without officequarto?”), you can keep the plain, unpatched
Pandoc output as well, analogous to Quarto’s own `keep-md`:

``` yaml
format:
  docx:
    officequarto:
      keep-rendered: true   # optional, default: false
```

This additionally produces `<name>.quarto-rendered.docx` next to the
final `<name>.docx`, holding the unmodified Pandoc output (no metadata
merge, no style-mapping).

## Option reference

Canonical option names use kebab-case and are the primary, documented
way to configure `officequarto`. Every option lives nested under
`format.docx.officequarto` — the “New name” column below omits that
common `officequarto.` prefix’s parent path for brevity, but always
starts with the subsection name (`styles.`, `lists.`, `tables.`, …).
Where an option corresponds to one from {officedown}, its original name
(with `.` replaced by `_`) remains usable as an alias — see [officedown
aliases](#officedown-aliases). This table is filled in as each
{officedown} option group is ported; groups not yet listed here aren’t
implemented yet.

| New name (under `officequarto.`) | officedown alias | Meaning | Default |
|----|----|----|----|
| `styles.body` | *(none — officedown maps `Normal` implicitly)* | Word style for body paragraphs | unset (Pandoc default) |
| `lists.list-bullet` | `ul_style` | Word style for bullet-list paragraphs — scalar, or array indexed by nesting level (see [Per-nesting-level styles](#per-nesting-level-styles)) | unset (Pandoc default) |
| `lists.list-number` | `ol_style` | Word style for numbered-list paragraphs (decimal, roman, …) — scalar, or array indexed by nesting level | unset (Pandoc default) |
| `lists.list-letter` | *(none — no officedown equivalent)* | Word style for lettered-list paragraphs (`a.`/`b.`/… or `A.`/`B.`/…) — scalar, or array indexed by nesting level | unset (Pandoc default) |
| `tables.style` | `tables_style` | Word table style name | unset (Pandoc/reference-doc default) |
| `tables.layout` | `tables_layout` | Table layout, `autofit` or `fixed` | unset (Pandoc default) |
| `tables.width` | `tables_width` | Table width relative to page width (0–1) | unset (Pandoc default) |
| `tables.conditional.first-row` | `tables_conditional_first_row` | Highlight header row | unset (Pandoc default) |
| `tables.conditional.first-column` | `tables_conditional_first_column` | Highlight first column | unset (Pandoc default) |
| `tables.conditional.last-row` | `tables_conditional_last_row` | Highlight total row | unset (Pandoc default) |
| `tables.conditional.last-column` | `tables_conditional_last_column` | Highlight last column | unset (Pandoc default) |
| `tables.conditional.band-rows` | `tables_conditional_no_hband` *(inverted)* | Alternating row shading | unset (Pandoc default) |
| `tables.conditional.band-columns` | `tables_conditional_no_vband` *(inverted)* | Alternating column shading | unset (Pandoc default) |
| `tables.caption.style` | `tables_caption_style` | Paragraph style for the caption | unset (Pandoc’s `TableCaption`/`ImageCaption`) |
| `tables.caption.prefix` | `tables_caption_pre` | Text before the number | unset (Pandoc-generated text) |
| `tables.caption.separator` | `tables_caption_sep` | Text between number and caption | unset (Pandoc-generated text) |
| `tables.caption.number-bold` | `tables_caption_bold` | Bold the prefix+number portion | unset (Pandoc default, not bold) |
| `tables.caption.above` | `tables_topcaption` | Move the caption before (`true`) or after (`false`) the table | unset (Pandoc default, already “above”) |
| `plots.style` | `plots_style` | Paragraph style for the image paragraph | unset (Pandoc default) |
| `plots.align` | `plots_align` | Image alignment, `left`/`center`/`right` | unset (Pandoc default) |
| `plots.caption.style` | `plots_caption_style` | Paragraph style for the caption | unset (Pandoc’s `ImageCaption`) |
| `plots.caption.prefix` | `plots_caption_pre` | Text before the number | unset (Pandoc-generated text) |
| `plots.caption.separator` | `plots_caption_sep` | Text between number and caption | unset (Pandoc-generated text) |
| `plots.caption.number-bold` | `plots_caption_bold` | Bold the prefix+number portion | unset (Pandoc default, not bold) |
| `plots.caption.above` | `plots_topcaption` | Move the caption before (`true`) or after (`false`) the figure | unset (Pandoc default, already “below”) |
| `style-map` | *(renamed from officedown’s `mapstyles`, shape unchanged)* | Free-form target-style → source-style-IDs map | unset (no effect) |
| `page.size.width` | `page_size_width` | Page width (inches) | unset (`reference-doc` default) |
| `page.size.height` | `page_size_height` | Page height (inches) | unset (`reference-doc` default) |
| `page.size.orientation` | `page_size_orient` | `portrait`/`landscape` | unset (`reference-doc` default) |
| `page.margins.top` | `page_margins_top` | Top margin (inches) | unset (`reference-doc` default) |
| `page.margins.bottom` | `page_margins_bottom` | Bottom margin (inches) | unset (`reference-doc` default) |
| `page.margins.left` | `page_margins_left` | Left margin (inches) | unset (`reference-doc` default) |
| `page.margins.right` | `page_margins_right` | Right margin (inches) | unset (`reference-doc` default) |
| `page.margins.header` | `page_margins_header` | Header distance (inches) | unset (`reference-doc` default) |
| `page.margins.footer` | `page_margins_footer` | Footer distance (inches) | unset (`reference-doc` default) |
| `page.margins.gutter` | `page_margins_gutter` | Gutter margin (inches) | unset (`reference-doc` default) |
| `crossref.numbered` | `reference_num` | Show the number (`true`) or caption text (`false`) at cross-references | unset (Pandoc default, already numbered) |
| `crossref.auto-number` | *(none — {officedown} is always field-based)* | Convert captions/cross-references into live Word `SEQ`/`REF` fields instead of static text | unset (static text, current behavior) |
| `pandoc-styles.code-block` | *(none — no officedown equivalent)* | Exempt Pandoc’s code-block styles from pruning (`true`), or remap the block role to a style (name) | unset (code-block styles are pruned) |
| `keep-rendered` | *(none — no officedown equivalent)* | Also save the unpatched Pandoc output as `<name>.quarto-rendered.docx` | `false` |
