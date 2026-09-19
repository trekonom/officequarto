## End-to-end check for the officequarto workflow.
## Expects that `quarto render report.qmd` has already run in the template/
## project (with the officequarto.styles, officequarto.pandoc-styles, and
## officequarto.keep-rendered configuration from template/_quarto.yml).
## Checks: report.docx was overwritten in-place by the hook (no separate
## written-back.docx anymore), header/footer from original.docx are
## preserved, the newly rendered body text is findable, the metadata written
## back from the original (subject/custom property) is present,
## body/bullet/numbered/letter-list/code-block paragraphs carry the
## configured ACME custom styles instead of Pandoc's default styles, that
## the table carries the configured style/layout/width (officequarto.tables,
## schema-conformant w:tblPr order), that word/styles.xml in the result
## contains exactly the styles from original.docx (Pandoc's syntax-
## highlighting run styles for the code block in report.qmd were removed
## despite being used - officequarto.pandoc-styles.code-block here only
## remaps the SourceCode paragraph role, not the *Tok run styles), and that
## the debug artifact kept via officequarto.keep-rendered shows the
## unpatched state.
library(xml2)
library(officequarto)
## oq_is_pandoc_code_style_id() is internal/not exported (see
## R/style-pruning.R) - accessed via ::: since this script runs outside the
## package namespace as a standalone Rscript.
oq_is_pandoc_code_style_id <- officequarto:::oq_is_pandoc_code_style_id

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

target <- "report.docx"
if (!file.exists(target)) fail("%s was not created", target)
ok("%s exists", target)

if (file.exists("report.written-back.docx")) {
  fail("report.written-back.docx should no longer be created (in-place overwrite)")
}
ok("no separate report.written-back.docx exists anymore")

tmp <- tempfile("check_")
dir.create(tmp)
utils::unzip(target, exdir = tmp)

header_txt <- xml_text(read_xml(file.path(tmp, "word", "header1.xml")))
if (!grepl("ACME GmbH", header_txt, fixed = TRUE)) fail("header text from original.docx is missing")
ok("header from original.docx is preserved")

footer_txt <- xml_text(read_xml(file.path(tmp, "word", "footer1.xml")))
if (!grepl("Vertraulich", footer_txt, fixed = TRUE)) fail("footer text from original.docx is missing")
ok("footer from original.docx is preserved")

body_txt <- xml_text(read_xml(file.path(tmp, "word", "document.xml")))
if (!grepl("muss im zurückgeschriebenen Dokument auffindbar sein", body_txt, fixed = TRUE)) {
  fail("newly rendered body content is missing")
}
ok("newly rendered body content is present")

core_txt <- xml_text(read_xml(file.path(tmp, "docProps", "core.xml")))
if (!grepl("Quartalsberichte", core_txt, fixed = TRUE)) fail("dc:subject from original.docx is missing")
ok("dc:subject from original.docx was written back")

custom_path <- file.path(tmp, "docProps", "custom.xml")
custom_has_property <- file.exists(custom_path) &&
  any(grepl("Vertraulichkeitsstufe", readLines(custom_path, warn = FALSE), fixed = TRUE))
if (!custom_has_property) fail("custom property from original.docx is missing")
ok("custom property from original.docx was written back")

document_doc <- read_xml(file.path(tmp, "word", "document.xml"))
ns <- xml_ns(document_doc)
pstyles <- xml_attr(xml_find_all(document_doc, "//w:p/w:pPr/w:pStyle", ns), "val")

n_body <- sum(pstyles == "FliesstextACME")
if (n_body < 1) fail("no body paragraph carries the configured style 'FliesstextACME' (found: %s)",
                      paste(unique(pstyles), collapse = ", "))
ok("%d body paragraph(s) carry the configured style", n_body)

n_title <- sum(pstyles == "TitelACME")
if (n_title != 1) fail("expected 1 title paragraph with style 'TitelACME' (officequarto.style-map: {\"Titel ACME\": [Title]}), found %d", n_title)
if ("Title" %in% pstyles) fail("there should no longer be an unmapped 'Title' paragraph (officequarto.style-map)")
ok("%d title paragraph carries the style 'TitelACME' configured via officequarto.style-map (free-form style mapping, Gruppe 7)", n_title)

## Footnote/endnote paragraph styling (issue #2): officequarto.style-map is
## also applied to word/footnotes.xml - original.docx deliberately defines
## no footnote-text style of its own, so Pandoc falls back to the fixed ID
## "FootnoteText", which is redirected to "FussnotentextACME" via style-map
## (see README "Footnotes and endnotes").
footnotes_doc <- read_xml(file.path(tmp, "word", "footnotes.xml"))
footnotes_ns <- xml_ns(footnotes_doc)
footnote_pstyles <- xml_attr(xml_find_all(footnotes_doc, "//w:p/w:pPr/w:pStyle", footnotes_ns), "val")

if (!("FussnotentextACME" %in% footnote_pstyles)) {
  fail("no footnote paragraph carries the style 'FussnotentextACME' configured via officequarto.style-map (found: %s)",
       paste(unique(footnote_pstyles), collapse = ", "))
}
ok("footnote paragraph carries the style 'FussnotentextACME' configured via officequarto.style-map (free-form style mapping now also reaches word/footnotes.xml)")

if ("FootnoteText" %in% footnote_pstyles) {
  fail("there should no longer be an unmapped Pandoc fallback style 'FootnoteText' (officequarto.style-map)")
}
ok("no unmapped Pandoc fallback style 'FootnoteText' remains")

separator_footnote <- xml_find_first(footnotes_doc, "//w:footnote[@w:type='separator']", footnotes_ns)
if (is.na(separator_footnote)) fail("the separator footnote (w:id=-1) generated by Word/Pandoc is unexpectedly missing")
separator_pstyle <- xml_attr(xml_find_first(separator_footnote, ".//w:pStyle", footnotes_ns), "val")
if (!is.na(separator_pstyle)) fail("the separator footnote should carry no w:pStyle (not caught by style mapping), found: '%s'", separator_pstyle)
ok("the separator footnote (w:type='separator') remains untouched by style mapping")

## Nesting level per list paragraph (officequarto.lists.* as an array, see
## report.qmd "Kennzahlen"/"Naechste Schritte"/"Varianten" and
## dev/spike-notes.md Spike O). w:ilvl falls back to 0 when the element is
## missing (like oq_paragraph_ilvl()), but is always set for Pandoc lists.
list_paragraphs <- xml_find_all(document_doc, "//w:p[./w:pPr/w:numPr]", ns)
list_pstyle <- xml_attr(xml_find_first(list_paragraphs, "./w:pPr/w:pStyle", ns), "val")
list_ilvl_val <- xml_attr(xml_find_first(list_paragraphs, "./w:pPr/w:numPr/w:ilvl", ns), "val")
list_ilvl <- ifelse(is.na(list_ilvl_val), 0L, as.integer(list_ilvl_val))
n_at_level <- function(style, ilvl) sum(list_pstyle == style & list_ilvl == ilvl)

n_bullet0 <- n_at_level("AufzaehlungACME", 0L)
n_bullet1 <- n_at_level("AufzaehlungACME2", 1L)
n_bullet2 <- n_at_level("AufzaehlungACME3", 2L)
if (n_bullet0 != 3 || n_bullet1 != 2 || n_bullet2 != 2) {
  fail("expected 3/2/2 bullet paragraphs with style 'AufzaehlungACME'/'AufzaehlungACME2'/'AufzaehlungACME3' at level 0/1/2, found %d/%d/%d",
       n_bullet0, n_bullet1, n_bullet2)
}
ok("%d/%d/%d bullet paragraphs carry the style configured per nesting level", n_bullet0, n_bullet1, n_bullet2)

n_number0 <- n_at_level("NummerierungACME", 0L)
n_number1 <- n_at_level("NummerierungACME2", 1L)
n_number2 <- n_at_level("NummerierungACME3", 2L)
if (n_number0 != 3 || n_number1 != 3 || n_number2 != 2) {
  fail("expected 3/3/2 numbered paragraphs with style 'NummerierungACME'/'NummerierungACME2'/'NummerierungACME3' at level 0/1/2, found %d/%d/%d",
       n_number0, n_number1, n_number2)
}
ok("%d/%d/%d numbered paragraphs carry the style configured per nesting level", n_number0, n_number1, n_number2)

n_letter0 <- n_at_level("BuchstabierungACME", 0L)
n_letter1_clamped <- n_at_level("BuchstabierungACME", 1L)
if (n_letter0 != 3 || n_letter1_clamped != 1) {
  fail("expected 3 letter-list paragraphs at level 0 and, clamped, 1 at level 1 with the same style 'BuchstabierungACME' (officequarto.lists.list-letter stays scalar), found %d/%d",
       n_letter0, n_letter1_clamped)
}
if ("BuchstabierungACME2" %in% list_pstyle) {
  fail("'BuchstabierungACME2' should not occur - list-letter is configured as a scalar, level 1 must clamp to 'BuchstabierungACME'")
}
ok("%d/%d letter-list paragraphs at level 0/1 carry (via clamping) the same configured style", n_letter0, n_letter1_clamped)

if (any(pstyles == "Normal") || any(pstyles == "Compact") || any(pstyles == "FirstParagraph")) {
  fail("unmapped Pandoc default styles are still present in the result: %s",
       paste(unique(pstyles), collapse = ", "))
}
ok("no unmapped Pandoc default styles (Normal/Compact/FirstParagraph) remain")

## [not(.//w:tbl)] excludes Pandoc's synthetic wrapper table around
## caption+table (see table-mapping.R/oq_apply_table_options) - without this
## filter, xml_find_first would find the wrapper table first (document
## order: ancestor before descendant), not the actual data table.
tbl_pr <- xml_find_first(document_doc, "//w:tbl[not(.//w:tbl)]/w:tblPr", ns)
if (is.na(tbl_pr)) fail("no w:tbl/w:tblPr found in the result document (expected: the table from report.qmd)")

tbl_style <- xml_attr(xml_find_first(tbl_pr, "./w:tblStyle", ns), "val")
if (!identical(tbl_style, "TabelleACME")) {
  fail("table should carry the configured style 'TabelleACME' (officequarto.tables.style), found: '%s'", tbl_style)
}
ok("table carries the configured style 'TabelleACME' (officequarto.tables.style)")

tbl_layout <- xml_attr(xml_find_first(tbl_pr, "./w:tblLayout", ns), "type")
if (!identical(tbl_layout, "fixed")) {
  fail("table should carry tblLayout type='fixed' (officequarto.tables.layout), found: '%s'", tbl_layout)
}
ok("table carries the configured layout 'fixed' (officequarto.tables.layout)")

tbl_w_node <- xml_find_first(tbl_pr, "./w:tblW", ns)
tbl_w_type <- xml_attr(tbl_w_node, "type")
tbl_w_val <- xml_attr(tbl_w_node, "w")
if (!identical(tbl_w_type, "pct") || !identical(tbl_w_val, "4000")) {
  fail("table should carry tblW type='pct' w='4000' (officequarto.tables.width: 0.8), found: type='%s' w='%s'", tbl_w_type, tbl_w_val)
}
ok("table carries the configured width 0.8 (officequarto.tables.width, as tblW type='pct' w='4000')")

tbl_look <- xml_find_first(tbl_pr, "./w:tblLook", ns)
expected_look <- c(firstRow = "1", lastRow = "1", noHBand = "1", noVBand = "0")
for (attr_name in names(expected_look)) {
  actual <- xml_attr(tbl_look, attr_name)
  if (!identical(actual, expected_look[[attr_name]])) {
    fail("table: w:tblLook/@%s should be '%s' (officequarto.tables.conditional), found: '%s'",
         attr_name, expected_look[[attr_name]], actual)
  }
}
ok("table carries the configured conditional-formatting flags (first-row/last-row/band-rows/band-columns via officequarto.tables.conditional, some via officedown alias)")

tbl_pr_children <- xml_name(xml_children(tbl_pr))
tbl_pr_order <- match(tbl_pr_children, c("tblStyle", "tblW", "tblLayout", "tblLook"))
if (is.unsorted(tbl_pr_order, na.rm = TRUE)) {
  fail("w:tblPr child elements are not in schema order: %s", paste(tbl_pr_children, collapse = ", "))
}
ok("w:tblPr child elements are in schema order: %s", paste(tbl_pr_children, collapse = ", "))

caption_p <- xml_find_first(document_doc, "//w:p[w:pPr/w:pStyle/@w:val='BeschriftungACME']", ns)
if (is.na(caption_p)) fail("no table caption found with the configured style 'BeschriftungACME' (officequarto.tables.caption.style)")
ok("table caption carries the configured style 'BeschriftungACME' (officequarto.tables.caption.style)")

caption_runs <- xml_find_all(caption_p, "./w:r", ns)
if (length(caption_runs) != 2) {
  fail("table caption should be split into 2 runs (prefix+number bold / rest normal), found: %d", length(caption_runs))
}
caption_first_text <- xml_text(xml_find_first(caption_runs[[1]], "./w:t", ns))
caption_first_bold <- xml_attr(xml_find_first(caption_runs[[1]], "./w:rPr/w:b", ns), "val")
caption_second_text <- xml_text(xml_find_first(caption_runs[[2]], "./w:t", ns))
if (!identical(caption_first_text, "Tab. 1")) {
  fail("table caption: first run should be 'Tab. 1' (officequarto.tables.caption.prefix), found: '%s'", caption_first_text)
}
if (!identical(caption_first_bold, "1")) {
  fail("table caption: first run should be bold (officequarto.tables.caption.number-bold: true), w:b/@val='%s'", caption_first_bold)
}
if (!identical(caption_second_text, " -- Quartalskennzahlen")) {
  fail("table caption: second run should be ' -- Quartalskennzahlen' (officequarto.tables.caption.separator via alias tables_caption_sep), found: '%s'", caption_second_text)
}
ok("table caption text correctly reformatted: bold 'Tab. 1' + ' -- Quartalskennzahlen' (prefix/separator via officequarto.tables.caption, separator via officedown alias)")

## officequarto.tables.caption.above: false (test config) - caption should
## come AFTER the table, against Pandoc's default (tables: caption above).
table_caption_after_tbl <- xml_find_first(caption_p, "./preceding-sibling::w:tbl[1]", ns)
if (is.na(table_caption_after_tbl)) {
  fail("table caption should come AFTER the table (officequarto.tables.caption.above: false), but comes before it")
}
ok("table caption comes after the table (officequarto.tables.caption.above: false, against Pandoc's default)")

plot_p <- xml_find_first(document_doc, "//w:p[.//w:drawing]", ns)
if (is.na(plot_p)) fail("no figure paragraph (w:p with w:drawing) found in the result document (expected: the figure from report.qmd)")
plot_pstyle <- xml_attr(xml_find_first(plot_p, "./w:pPr/w:pStyle", ns), "val")
if (!identical(plot_pstyle, "AbbildungACME")) {
  fail("figure paragraph should carry the configured style 'AbbildungACME' (officequarto.plots.style), found: '%s'", plot_pstyle)
}
ok("figure paragraph carries the configured style 'AbbildungACME' (officequarto.plots.style)")
plot_align <- xml_attr(xml_find_first(plot_p, "./w:pPr/w:jc", ns), "val")
if (!identical(plot_align, "right")) {
  fail("figure paragraph should be right-aligned (officequarto.plots.align via alias plots_align), found: '%s'", plot_align)
}
ok("figure paragraph is right-aligned (officequarto.plots.align via officedown alias plots_align)")

plot_caption_p <- xml_find_first(document_doc, "//w:p[w:pPr/w:pStyle/@w:val='AbbildungsbeschriftungACME']", ns)
if (is.na(plot_caption_p)) fail("no figure caption found with the configured style 'AbbildungsbeschriftungACME' (officequarto.plots.caption.style via alias plots_caption_style)")
ok("figure caption carries the configured style 'AbbildungsbeschriftungACME' (officequarto.plots.caption.style via officedown alias plots_caption_style)")

plot_caption_runs <- xml_find_all(plot_caption_p, "./w:r", ns)
if (length(plot_caption_runs) != 2) {
  fail("figure caption should be split into 2 runs (number-bold explicitly set), found: %d", length(plot_caption_runs))
}
plot_caption_first_text <- xml_text(xml_find_first(plot_caption_runs[[1]], "./w:t", ns))
plot_caption_first_bold <- xml_attr(xml_find_first(plot_caption_runs[[1]], "./w:rPr/w:b", ns), "val")
plot_caption_second_text <- xml_text(xml_find_first(plot_caption_runs[[2]], "./w:t", ns))
if (!identical(plot_caption_first_text, "Abb. 1")) {
  fail("figure caption: first run should be 'Abb. 1' (officequarto.plots.caption.prefix), found: '%s'", plot_caption_first_text)
}
if (!identical(plot_caption_first_bold, "0")) {
  fail("figure caption: first run should explicitly NOT be bold (officequarto.plots.caption.number-bold: false via alias), w:b/@val='%s'", plot_caption_first_bold)
}
if (!identical(plot_caption_second_text, " | Umsatzentwicklung")) {
  fail("figure caption: second run should be ' | Umsatzentwicklung' (officequarto.plots.caption.separator), found: '%s'", plot_caption_second_text)
}
ok("figure caption text correctly reformatted: non-bold 'Abb. 1' + ' | Umsatzentwicklung' (prefix/separator/number-bold via officequarto.plots.caption, some via officedown alias)")

## officequarto.plots.caption.above: true (test config, via alias
## plots_topcaption) - caption should come BEFORE the figure, against
## Pandoc's default (figures: caption below).
plot_caption_before_img <- xml_find_first(plot_caption_p, "./following-sibling::w:p[.//w:drawing][1]", ns)
if (is.na(plot_caption_before_img)) {
  fail("figure caption should come BEFORE the figure (officequarto.plots.caption.above: true via alias plots_topcaption), but comes after it")
}
ok("figure caption comes before the figure (officequarto.plots.caption.above: true via officedown alias plots_topcaption, against Pandoc's default)")

## Regression test: caption WITHOUT a crossref ID ({#tbl-...}/{#fig-...}) -
## Pandoc generates a different structure for this (no wrapper table, style
## 'TableCaption' instead of 'ImageCaption' for tables) than for crossref-
## managed captions; an earlier version didn't detect this case at all
## (table/figure captions even ended up swapped), see dev/spike-notes.md and
## ../hello-wordto.
plain_table_caption_p <- xml_find_first(
  document_doc, "//w:p[w:r/w:t='Regionale Verteilung']", ns
)
if (is.na(plain_table_caption_p)) fail("no table caption without a crossref ID ('Regionale Verteilung') found in the result document")
plain_table_caption_style <- xml_attr(xml_find_first(plain_table_caption_p, "./w:pPr/w:pStyle", ns), "val")
if (!identical(plain_table_caption_style, "BeschriftungACME")) {
  fail("table caption without a crossref ID should also carry the configured style 'BeschriftungACME', found: '%s'", plain_table_caption_style)
}
ok("table caption without a crossref ID (no {#tbl-...}, Pandoc style 'TableCaption') also carries the configured style 'BeschriftungACME'")

plain_plot_caption_p <- xml_find_first(
  document_doc, "//w:p[w:r/w:t='Verteilungsdiagramm']", ns
)
if (is.na(plain_plot_caption_p)) fail("no figure caption without a crossref ID ('Verteilungsdiagramm') found in the result document")
plain_plot_caption_style <- xml_attr(xml_find_first(plain_plot_caption_p, "./w:pPr/w:pStyle", ns), "val")
if (!identical(plain_plot_caption_style, "AbbildungsbeschriftungACME")) {
  fail("figure caption without a crossref ID should also carry the configured style 'AbbildungsbeschriftungACME', found: '%s'", plain_plot_caption_style)
}
ok("figure caption without a crossref ID (no {#fig-...}) also carries the configured style 'AbbildungsbeschriftungACME'")

sect_pr <- xml_find_first(document_doc, "//w:sectPr", ns)
if (is.na(sect_pr)) fail("no w:sectPr found in the result document")

pg_sz <- xml_find_first(sect_pr, "./w:pgSz", ns)
expected_pg_sz <- c(w = "16848", h = "11952", orient = "landscape")
for (attr_name in names(expected_pg_sz)) {
  actual <- xml_attr(pg_sz, attr_name)
  if (!identical(actual, expected_pg_sz[[attr_name]])) {
    fail("w:pgSz/@%s should be '%s' (officequarto.page.size), found: '%s'", attr_name, expected_pg_sz[[attr_name]], actual)
  }
}
ok("page size set correctly: 11.7x8.3 inches, landscape (officequarto.page.size, orientation via officedown alias page_size_orient)")

pg_mar <- xml_find_first(sect_pr, "./w:pgMar", ns)
expected_pg_mar <- c(top = "1080", bottom = "1080", left = "1440", right = "1440", header = "576", footer = "576", gutter = "0")
for (attr_name in names(expected_pg_mar)) {
  actual <- xml_attr(pg_mar, attr_name)
  if (!identical(actual, expected_pg_mar[[attr_name]])) {
    fail("w:pgMar/@%s should be '%s' (officequarto.page.margins), found: '%s'", attr_name, expected_pg_mar[[attr_name]], actual)
  }
}
ok("page margins set correctly (officequarto.page.margins, bottom via officedown alias page_margins_bottom)")

tbl_crossref <- xml_find_first(document_doc, "//w:hyperlink[@w:anchor='tbl-kennzahlen']", ns)
if (is.na(tbl_crossref)) fail("no crossref hyperlink with anchor 'tbl-kennzahlen' found (expected: 'Siehe @tbl-kennzahlen' from report.qmd)")
tbl_crossref_text <- xml_text(tbl_crossref)
if (!identical(tbl_crossref_text, "Quartalskennzahlen")) {
  fail("table crossref should be switched to the caption text 'Quartalskennzahlen' (officequarto.crossref.numbered: false via alias reference_num), found: '%s'", tbl_crossref_text)
}
ok("table crossref shows the caption text 'Quartalskennzahlen' instead of the number (officequarto.crossref.numbered: false via officedown alias reference_num)")

fig_crossref <- xml_find_first(document_doc, "//w:hyperlink[@w:anchor='fig-umsatz']", ns)
if (is.na(fig_crossref)) fail("no crossref hyperlink with anchor 'fig-umsatz' found (expected: 'Siehe @fig-umsatz' from report.qmd)")
fig_crossref_text <- xml_text(fig_crossref)
if (!identical(fig_crossref_text, "Umsatzentwicklung")) {
  fail("figure crossref should be switched to the caption text 'Umsatzentwicklung' (officequarto.crossref.numbered: false), found: '%s'", fig_crossref_text)
}
ok("figure crossref shows the caption text 'Umsatzentwicklung' instead of the number (officequarto.crossref.numbered: false)")

## officer inline syntax (`r ftext(...)`, see report.qmd "Officer-Inline-
## Syntax" and vignette("officer-syntax")): officequarto's own
## knit_print.run()/knit_print.fp_par() (R/knit-print.R, registered in
## R/zzz.R) wrap officer::to_wml() output as raw inline openxml for Pandoc,
## which is spliced directly into word/document.xml - no involvement from
## writeback.R for the run() case, so this only proves the run fragment
## survived Pandoc's render and writeback.R's style-mapping/pruning pass
## untouched. fp_par() is different: it splices a whole misplaced w:pPr
## into the paragraph's run flow (not a run/rPr fragment), which is
## schema-invalid on its own (CT_P allows only one w:pPr, and only as the
## first child) and made the rendered docx fail to open in real Word -
## confirmed directly against Word, not just XML well-formedness/
## python-docx, which stayed silent about it. oq_merge_misplaced_ppr()
## (R/officer-par-merge.R), run unconditionally in writeback.R, fixes this
## up before anything else touches document.xml.
ftext_run <- xml_find_first(document_doc, "//w:r[w:t='officequarto' and ./w:rPr/w:b/@w:val='true']", ns)
if (is.na(ftext_run)) fail("no run with text 'officequarto' and bold rPr found (expected: officer::ftext() inline)")
ftext_color <- xml_attr(xml_find_first(ftext_run, "./w:rPr/w:color", ns), "val")
if (!identical(ftext_color, "C32900")) {
  fail("officer::ftext() run should carry color 'C32900' (fp_text(color = \"#C32900\")), found: '%s'", ftext_color)
}
ok("officer::ftext() inline run carries the configured bold/color formatting (fp_text(bold = TRUE, color = \"#C32900\"))")

## No paragraph anywhere in the document should carry more than one w:pPr
## (oq_merge_misplaced_ppr() must have cleaned up both officer::fp_par()'s
## own misplaced pPr AND left Pandoc's own, unrelated caption-wrapper-cell
## double-pPr quirk correctly merged down to one - see
## R/officer-par-merge.R and table-caption-mapping.R).
ppr_per_paragraph <- xml_find_all(document_doc, "//w:p", ns)
multi_ppr_count <- sum(vapply(ppr_per_paragraph, function(p) length(xml_find_all(p, "./w:pPr", ns)) > 1, logical(1)))
if (multi_ppr_count > 0) fail("%d paragraph(s) still carry more than one w:pPr (oq_merge_misplaced_ppr() should have merged these down to one)", multi_ppr_count)
ok("no paragraph carries more than one w:pPr")

## ftext() and fp_par() are inline in the same sentence/paragraph in
## report.qmd, so the merged pPr is the ftext() run's own paragraph's pPr.
ftext_par <- xml_find_first(ftext_run, "./ancestor::w:p", ns)
fp_par_ppr <- xml_find_first(ftext_par, "./w:pPr[w:jc/@w:val='center']", ns)
if (is.na(fp_par_ppr)) fail("no w:pPr with jc/@val='center' merged into the paragraph's own pPr (expected: officer::fp_par(text.align = \"center\") inline)")
if (is.na(xml_find_first(fp_par_ppr, "./w:pStyle", ns))) fail("the paragraph carrying the merged fp_par() properties lost its own w:pStyle (oq_merge_misplaced_ppr() must not drop a well-formed pStyle it didn't itself add)")
ok("officer::fp_par() inline paragraph-properties fragment (w:jc val='center') was correctly merged into the paragraph's own pPr, its pre-existing pStyle preserved")

rendered_styles_doc <- read_xml(file.path(tmp, "word", "styles.xml"))
rendered_style_ids <- xml_attr(xml_find_all(rendered_styles_doc, "//w:style", ns), "styleId")

orig_tmp <- tempfile("check_orig_")
dir.create(orig_tmp)
utils::unzip("original.docx", exdir = orig_tmp)
orig_styles_doc <- read_xml(file.path(orig_tmp, "word", "styles.xml"))
orig_style_ids <- xml_attr(xml_find_all(orig_styles_doc, "//w:style", xml_ns(orig_styles_doc)), "styleId")
unlink(orig_tmp, recursive = TRUE)

if (!setequal(rendered_style_ids, orig_style_ids)) {
  fail("word/styles.xml of %s should contain exactly the styles from original.docx (extra: %s, missing: %s)",
       target,
       paste(setdiff(rendered_style_ids, orig_style_ids), collapse = ", "),
       paste(setdiff(orig_style_ids, rendered_style_ids), collapse = ", "))
}
ok("word/styles.xml contains exactly the %d styles from original.docx (no Pandoc extras)", length(orig_style_ids))

if (any(oq_is_pandoc_code_style_id(rendered_style_ids))) {
  fail("Pandoc's syntax-highlighting styles (*Tok/SourceCode) should have been removed")
}
ok("Pandoc's syntax-highlighting styles (*Tok/SourceCode) were removed")

code_pstyles <- xml_attr(xml_find_all(document_doc, "//w:p/w:pPr/w:pStyle", ns), "val")
if (!("CodeACME" %in% code_pstyles)) {
  fail("code-block paragraph should be remapped to the configured style 'CodeACME' (officequarto.pandoc-styles.code-block), found: %s",
       paste(unique(code_pstyles), collapse = ", "))
}
if ("SourceCode" %in% code_pstyles) {
  fail("code-block paragraph should no longer reference 'SourceCode' (should have been remapped to 'CodeACME')")
}
ok("code-block paragraph carries the configured style 'CodeACME' (officequarto.pandoc-styles.code-block)")

code_rstyles <- xml_attr(xml_find_all(document_doc, "//w:r/w:rPr/w:rStyle", ns), "val")
if (!any(oq_is_pandoc_code_style_id(code_rstyles))) {
  fail("expected the code block to still reference *Tok run styles (syntax-highlighting warning-path test case)")
}
ok("code block still references removed *Tok run styles (syntax highlighting falls back to default formatting as intended - only the block role gets remapped)")

unlink(tmp, recursive = TRUE)

debug_target <- "report.quarto-rendered.docx"
if (!file.exists(debug_target)) {
  fail("%s was not created (officequarto.keep-rendered: true in _quarto.yml expected)", debug_target)
}
ok("%s exists (officequarto.keep-rendered)", debug_target)

debug_tmp <- tempfile("check_debug_")
dir.create(debug_tmp)
utils::unzip(debug_target, exdir = debug_tmp)

debug_custom_path <- file.path(debug_tmp, "docProps", "custom.xml")
debug_has_property <- file.exists(debug_custom_path) &&
  any(grepl("Vertraulichkeitsstufe", readLines(debug_custom_path, warn = FALSE), fixed = TRUE))
if (debug_has_property) {
  fail("%s should be the unpatched Pandoc output, but already carries the written-back custom property", debug_target)
}
ok("%s shows the unpatched state (no written-back custom property)", debug_target)

debug_document_doc <- read_xml(file.path(debug_tmp, "word", "document.xml"))
debug_pstyles <- xml_attr(xml_find_all(debug_document_doc, "//w:p/w:pPr/w:pStyle", xml_ns(debug_document_doc)), "val")
if (!any(debug_pstyles %in% c("Normal", "Compact", "FirstParagraph"))) {
  fail("%s should still carry Pandoc's default styles (found: %s)",
       debug_target, paste(unique(debug_pstyles), collapse = ", "))
}
ok("%s still shows Pandoc's default styles (no style mapping applied)", debug_target)

unlink(debug_tmp, recursive = TRUE)
cat("\nAll checks passed.\n")
