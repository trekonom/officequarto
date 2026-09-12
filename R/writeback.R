## Post-render hook of the officequarto extension.
##
## Background (see dev/spike-notes.md): Pandoc/Quarto already fully carry
## over the `reference-doc`'s styles, headers, footers, and section
## properties into every rendered .docx - a manual, XML-level body
## replacement is NOT needed for this, and is even error-prone with the
## available tools (officer::body_add_docx) on documents already derived
## from a reference-doc (sections/header merge bug for two structurally
## similar documents).
##
## What Pandoc, on the other hand, does NOT carry over from the original:
## the docProps metadata (docProps/core.xml, docProps/custom.xml) - Pandoc
## writes a new, largely empty core.xml for those instead. That's exactly
## what this hook writes back: it takes the freshly rendered .docx
## (body/header/footer/styles already correct) and transfers the
## original's subject/keywords/category/custom properties into it.
##
## All configuration lives bundled under the single key
## `format.docx.officequarto` (no more `officequarto-`-prefixed sibling
## keys) - see README/CLAUDE.md for the full structure. Most important
## subsections:
##
## `officequarto.styles.body` and `officequarto.lists.*` (list-bullet/
## list-number/list-letter, its own section, separate from `styles`, since
## conceptually it's its own group): body and list paragraphs are remapped
## onto real reference-doc styles named by the user (see R/style-mapping.R
## for the core logic). For officedown migrants, the list options
## additionally accept the old officedown names (`ol_style`/`ul_style`) as
## an alias for the new, more descriptive names (`list-number`/
## `list-bullet`) - see R/option-aliases.R for the resolution logic
## including the conflict rule. `list-letter` (letter lists, a/b/c or
## A/B/C) is an officequarto-only addition with no officedown precedent,
## hence no alias. All three list options additionally accept an array
## instead of a scalar - one style per nesting level (index 0 = top
## level), more deeply nested paragraphs clamp to the last array entry -
## see R/style-mapping.R (oq_style_for_level()/oq_paragraph_ilvl()) and
## dev/spike-notes.md Spike O.
##
## The hook overwrites the .docx produced by Quarto/Pandoc directly in
## place - no second output file is created. Anyone wanting to keep the
## raw, unpatched Pandoc result for debugging purposes can enable that via
## `officequarto.keep-rendered: true` (analogous to Quarto's own
## `keep-md`); it is then additionally stored as
## `<name>.quarto-rendered.docx`.
##
## Additionally, optionally configurable via `officequarto.tables`: table
## style/layout/width are applied to every w:tbl in the document (see
## R/table-mapping.R for the core logic; Gruppe 1 of the officedown option
## port, see README). As with the list options, style/layout/width
## additionally accept the officedown aliases tables_style/
## tables_layout/tables_width (see R/option-aliases.R).
##
## Additionally, always active: Pandoc's docx writer adds its own style
## definitions when rendering, ones that don't exist in the reference-doc
## at all (e.g. syntax-highlighting styles for code blocks, regardless of
## whether any occur). These are removed again by default, so the
## resulting docx contains only styles from the reference-doc (see
## R/style-pruning.R for the core logic). Via
## `officequarto.pandoc-styles.code-block` (its own section, independent of
## `officequarto.styles`), Pandoc's code-block styles can be exempted from
## this: `true` keeps them unchanged (full syntax highlighting), a style
## name only maps the SourceCode paragraph role onto a style of the user's
## own reference-doc (syntax-highlighting colors are removed in this case).
##
## Since the switch to an R package, this logic lives in oq_writeback()
## (exported) instead of in a top-level scripted hook - the hook shim
## under inst/_extensions/officequarto/scripts/writeback.R now only calls
## officequarto::oq_writeback(). The old source()/get_script_dir() loading
## logic is gone entirely: R packages load all R/*.R files together into
## one namespace, load order no longer matters.

#' @noRd
log_msg <- function(fmt, ...) cat(sprintf(paste0("[officequarto] ", fmt, "\n"), ...))

#' @noRd
fail <- function(fmt, ...) stop(sprintf(paste0("officequarto: ", fmt), ...), call. = FALSE)

#' @noRd
warn_msg <- function(fmt, ...) log_msg(paste0("Warnung: ", fmt), ...)

## Transfers dc:subject, cp:keywords, cp:category from core_from into
## core_to and returns the (possibly changed) core_to xml2 doc.
#' @noRd
merge_core_properties <- function(core_to, core_from) {
  ns_from <- xml2::xml_ns(core_from)
  root_to <- xml2::xml_root(core_to)
  for (field in c("dc:subject", "cp:keywords", "dc:description", "cp:category")) {
    src_node <- xml2::xml_find_first(core_from, paste0("//", field), ns_from)
    if (is.na(src_node) || !nzchar(trimws(xml2::xml_text(src_node)))) next
    dst_node <- xml2::xml_find_first(root_to, paste0("//", field), xml2::xml_ns(root_to))
    if (is.na(dst_node)) {
      dst_node <- xml2::xml_add_child(root_to, field)
    }
    xml2::xml_text(dst_node) <- xml2::xml_text(src_node)
  }
  core_to
}

#' Run the officequarto post-render write-back hook
#'
#' @description Reads the officequarto configuration for the current render
#'   via `quarto inspect`, then rewrites the rendered `.docx` output(s) in
#'   place: metadata merge from `reference-doc`, paragraph/table/figure style
#'   mapping, captions, page layout, free-form style-map, cross-reference
#'   text/fields, and style pruning. Called by the thin hook script shipped
#'   under `_extensions/officequarto/scripts/writeback.R` (see
#'   `system.file("_extensions", package = "officequarto")`) - not meant to
#'   be called directly outside of a Quarto post-render context, since it
#'   reads its entire configuration from environment variables Quarto sets
#'   for that hook.
#' @return Invisibly, `NULL`. Called for its side effect of overwriting the
#'   rendered `.docx` file(s) referenced by `QUARTO_PROJECT_OUTPUT_FILES`.
#' @export
oq_writeback <- function() {
  output_files <- Sys.getenv("QUARTO_PROJECT_OUTPUT_FILES", unset = "")
  output_dir <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", unset = ".")
  project_dir <- Sys.getenv("QUARTO_PROJECT_DIR", unset = ".")

  if (!nzchar(output_files)) {
    log_msg("QUARTO_PROJECT_OUTPUT_FILES not set, nothing to do.")
    return(invisible(NULL))
  }

  docx_outputs <- Filter(
    function(f) grepl("\\.docx$", f, ignore.case = TRUE),
    strsplit(output_files, "\n")[[1]]
  )

  if (length(docx_outputs) == 0) {
    log_msg("no .docx outputs in this render, nothing to do.")
    return(invisible(NULL))
  }

  for (pkg in c("xml2", "jsonlite")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      fail("R package '%s' is required but not installed.", pkg)
    }
  }
  if (!nzchar(Sys.which("quarto"))) fail("'quarto' CLI not found in PATH.")
  if (!nzchar(Sys.which("zip")) || !nzchar(Sys.which("unzip"))) {
    fail("'zip'/'unzip' are required for writing back, but not found in PATH.")
  }

  inspect_raw <- suppressWarnings(
    system2("quarto", c("inspect", shQuote(project_dir)), stdout = TRUE, stderr = FALSE)
  )
  inspect <- tryCatch(
    jsonlite::fromJSON(paste(inspect_raw, collapse = "\n"), simplifyVector = TRUE),
    error = function(e) NULL
  )
  reference_doc <- tryCatch(inspect$config$format$docx$`reference-doc`, error = function(e) NULL)

  if (is.null(reference_doc) || !nzchar(reference_doc)) {
    log_msg("no format.docx.reference-doc in the project configuration - skipping.")
    return(invisible(NULL))
  }

  reference_doc_path <- file.path(project_dir, reference_doc)
  if (!file.exists(reference_doc_path)) {
    fail("reference-doc '%s' was not found.", reference_doc_path)
  }

  ## All configuration lives under the single key
  ## format.docx.officequarto (see the comment block above) - read once
  ## here, then passed down per subsection.
  officequarto_config <- tryCatch(inspect$config$format$docx$officequarto, error = function(e) NULL)

  style_config <- officequarto_config$styles
  lists_config <- officequarto_config$lists
  pandoc_style_config <- officequarto_config$`pandoc-styles`
  keep_rendered <- officequarto_config$`keep-rendered`
  if (is.null(keep_rendered)) keep_rendered <- FALSE

  code_block_config <- tryCatch(pandoc_style_config$`code-block`, error = function(e) NULL)
  code_block_valid <- is.null(code_block_config) || identical(code_block_config, FALSE) ||
    isTRUE(code_block_config) || (is.character(code_block_config) && length(code_block_config) == 1 && nzchar(code_block_config))
  if (!code_block_valid) {
    fail("officequarto.pandoc-styles.code-block must be either true or a style name (string).")
  }

  ## table_style_val/table_layout_val/table_width_val each resolve
  ## canonical name vs. officedown alias (tables_style/tables_layout/
  ## tables_width) - done once here, not per output file, since the
  ## configuration is the same across the whole render.
  table_config <- officequarto_config$tables
  table_style_val <- if (!is.null(table_config)) {
    oq_resolve_aliased(table_config, "style", "tables_style", "officequarto.tables", warn_msg)
  } else NULL
  table_layout_val <- if (!is.null(table_config)) {
    oq_resolve_aliased(table_config, "layout", "tables_layout", "officequarto.tables", warn_msg)
  } else NULL
  table_width_val <- if (!is.null(table_config)) {
    oq_resolve_aliased(table_config, "width", "tables_width", "officequarto.tables", warn_msg)
  } else NULL

  if (!is.null(table_layout_val) && !(table_layout_val %in% c("autofit", "fixed"))) {
    fail("officequarto.tables.layout must be 'autofit' or 'fixed' (got: '%s').", table_layout_val)
  }
  if (!is.null(table_width_val) && (!is.numeric(table_width_val) || length(table_width_val) != 1 || table_width_val <= 0)) {
    fail("officequarto.tables.width must be a single positive number (got: '%s').", table_width_val)
  }

  ## Gruppe 2 (officequarto.tables.conditional.*) - each field
  ## independently optional, canonical name vs. officedown alias
  ## (band-rows/band-columns with inverted polarity relative to
  ## no_hband/no_vband), see table-mapping.R.
  table_conditional_config <- table_config$conditional
  table_conditional_options <- list(
    `first-row`    = oq_resolve_table_bool_option(table_conditional_config, "first-row", "tables_conditional_first_row", FALSE, "officequarto.tables.conditional.first-row", warn_msg, fail),
    `first-column` = oq_resolve_table_bool_option(table_conditional_config, "first-column", "tables_conditional_first_column", FALSE, "officequarto.tables.conditional.first-column", warn_msg, fail),
    `last-row`     = oq_resolve_table_bool_option(table_conditional_config, "last-row", "tables_conditional_last_row", FALSE, "officequarto.tables.conditional.last-row", warn_msg, fail),
    `last-column`  = oq_resolve_table_bool_option(table_conditional_config, "last-column", "tables_conditional_last_column", FALSE, "officequarto.tables.conditional.last-column", warn_msg, fail),
    `band-rows`    = oq_resolve_table_bool_option(table_conditional_config, "band-rows", "tables_conditional_no_hband", TRUE, "officequarto.tables.conditional.band-rows", warn_msg, fail),
    `band-columns` = oq_resolve_table_bool_option(table_conditional_config, "band-columns", "tables_conditional_no_vband", TRUE, "officequarto.tables.conditional.band-columns", warn_msg, fail)
  )

  ## Gruppe 3 (officequarto.tables.caption.*) - style is resolved against
  ## reference-doc's paragraph styles like body/list-*/code-block (later,
  ## once name_to_id is available, see below); prefix/separator/
  ## number-bold are plain values/booleans, fully resolvable here.
  table_caption_config <- table_config$caption
  table_caption_style_val <- if (!is.null(table_caption_config)) {
    oq_resolve_aliased(table_caption_config, "style", "tables_caption_style", "officequarto.tables.caption", warn_msg)
  } else NULL
  table_caption_prefix_val <- if (!is.null(table_caption_config)) {
    oq_resolve_aliased(table_caption_config, "prefix", "tables_caption_pre", "officequarto.tables.caption", warn_msg)
  } else NULL
  table_caption_separator_val <- if (!is.null(table_caption_config)) {
    oq_resolve_aliased(table_caption_config, "separator", "tables_caption_sep", "officequarto.tables.caption", warn_msg)
  } else NULL
  table_caption_bold_val <- if (!is.null(table_caption_config)) {
    oq_resolve_aliased(table_caption_config, "number-bold", "tables_caption_bold", "officequarto.tables.caption", warn_msg)
  } else NULL
  if (!is.null(table_caption_bold_val) && (!is.logical(table_caption_bold_val) || length(table_caption_bold_val) != 1 || is.na(table_caption_bold_val))) {
    fail("officequarto.tables.caption.number-bold must be true or false (got: '%s').", table_caption_bold_val)
  }
  ## caption-above (officedown: topcaption) - subsequently placed under
  ## caption.above rather than as its own top-level key (the original
  ## proposal before Gruppe 3), since a caption section now exists and all
  ## caption options belong together there.
  table_caption_above_val <- if (!is.null(table_caption_config)) {
    oq_resolve_aliased(table_caption_config, "above", "tables_topcaption", "officequarto.tables.caption", warn_msg)
  } else NULL
  if (!is.null(table_caption_above_val) && (!is.logical(table_caption_above_val) || length(table_caption_above_val) != 1 || is.na(table_caption_above_val))) {
    fail("officequarto.tables.caption.above must be true or false (got: '%s').", table_caption_above_val)
  }

  ## Gruppe 4 (officequarto.plots.style/align) - fig.lp deliberately not
  ## ported (see plot-mapping.R), topcaption deferred (see above).
  plot_config <- officequarto_config$plots
  plot_style_val <- if (!is.null(plot_config)) {
    oq_resolve_aliased(plot_config, "style", "plots_style", "officequarto.plots", warn_msg)
  } else NULL
  plot_align_val <- if (!is.null(plot_config)) {
    oq_resolve_aliased(plot_config, "align", "plots_align", "officequarto.plots", warn_msg)
  } else NULL
  if (!is.null(plot_align_val) && !(plot_align_val %in% c("left", "center", "right"))) {
    fail("officequarto.plots.align must be 'left', 'center', or 'right' (got: '%s').", plot_align_val)
  }

  ## Gruppe 5 (officequarto.plots.caption.*) - identical pattern to
  ## Gruppe 3 (officequarto.tables.caption.*), see there for the rationale.
  plot_caption_config <- plot_config$caption
  plot_caption_style_val <- if (!is.null(plot_caption_config)) {
    oq_resolve_aliased(plot_caption_config, "style", "plots_caption_style", "officequarto.plots.caption", warn_msg)
  } else NULL
  plot_caption_prefix_val <- if (!is.null(plot_caption_config)) {
    oq_resolve_aliased(plot_caption_config, "prefix", "plots_caption_pre", "officequarto.plots.caption", warn_msg)
  } else NULL
  plot_caption_separator_val <- if (!is.null(plot_caption_config)) {
    oq_resolve_aliased(plot_caption_config, "separator", "plots_caption_sep", "officequarto.plots.caption", warn_msg)
  } else NULL
  plot_caption_bold_val <- if (!is.null(plot_caption_config)) {
    oq_resolve_aliased(plot_caption_config, "number-bold", "plots_caption_bold", "officequarto.plots.caption", warn_msg)
  } else NULL
  if (!is.null(plot_caption_bold_val) && (!is.logical(plot_caption_bold_val) || length(plot_caption_bold_val) != 1 || is.na(plot_caption_bold_val))) {
    fail("officequarto.plots.caption.number-bold must be true or false (got: '%s').", plot_caption_bold_val)
  }
  plot_caption_above_val <- if (!is.null(plot_caption_config)) {
    oq_resolve_aliased(plot_caption_config, "above", "plots_topcaption", "officequarto.plots.caption", warn_msg)
  } else NULL
  if (!is.null(plot_caption_above_val) && (!is.logical(plot_caption_above_val) || length(plot_caption_above_val) != 1 || is.na(plot_caption_above_val))) {
    fail("officequarto.plots.caption.above must be true or false (got: '%s').", plot_caption_above_val)
  }

  ## Gruppe 7 (officequarto.style-map, officedown: mapstyles) - free-form
  ## style mapping, see style-map.R. Only rough shape validation here
  ## (named list); the actual resolution (target style against
  ## reference-doc) happens per output file further below, since it needs
  ## name_to_id.
  style_map_config <- officequarto_config$`style-map`
  if (!is.null(style_map_config) && (!is.list(style_map_config) || is.null(names(style_map_config)) || any(!nzchar(names(style_map_config))))) {
    fail("officequarto.style-map must be a named list (target style name -> list of source pStyle IDs).")
  }

  ## Gruppe 8 (officequarto.page.size/.margins) - values in inches, see
  ## page-mapping.R for the twips conversion and the rationale for why this
  ## group (unlike all others) touches section properties rather than
  ## styles.
  page_config <- officequarto_config$page

  page_size_fields <- c(width = "page_size_width", height = "page_size_height", orientation = "page_size_orient")
  page_size_vals <- oq_resolve_fields(page_config$size, page_size_fields, "officequarto.page.size", warn_msg)
  for (f in c("width", "height")) {
    v <- page_size_vals[[f]]
    if (!is.null(v) && (!is.numeric(v) || length(v) != 1 || v <= 0)) {
      fail("officequarto.page.size.%s must be a single positive number (got: '%s').", f, v)
    }
  }
  if (!is.null(page_size_vals$orientation) && !(page_size_vals$orientation %in% c("portrait", "landscape"))) {
    fail("officequarto.page.size.orientation must be 'portrait' or 'landscape' (got: '%s').", page_size_vals$orientation)
  }

  page_margin_fields <- c(
    top = "page_margins_top", bottom = "page_margins_bottom",
    left = "page_margins_left", right = "page_margins_right",
    header = "page_margins_header", footer = "page_margins_footer",
    gutter = "page_margins_gutter"
  )
  page_margin_vals <- oq_resolve_fields(page_config$margins, page_margin_fields, "officequarto.page.margins", warn_msg)
  for (f in names(page_margin_fields)) {
    v <- page_margin_vals[[f]]
    if (!is.null(v) && (!is.numeric(v) || length(v) != 1 || v < 0)) {
      fail("officequarto.page.margins.%s must be a single, non-negative number (got: '%s').", f, v)
    }
  }

  ## Gruppe 9 (officequarto.crossref.numbered, officedown: reference_num) -
  ## see crossref-mapping.R. Pandoc's own default already matches
  ## "numbered" (cross-references show the number) - only an explicit
  ## `false` triggers any processing at all (see below, where this
  ## additionally causes the caption detection/text-splitting from Gruppe
  ## 3/5 to run "silently", even when officequarto.tables.caption/
  ## plots.caption themselves aren't configured).
  crossref_config <- officequarto_config$crossref
  crossref_numbered_val <- if (!is.null(crossref_config)) {
    oq_resolve_aliased(crossref_config, "numbered", "reference_num", "officequarto.crossref", warn_msg)
  } else NULL
  if (!is.null(crossref_numbered_val) && (!is.logical(crossref_numbered_val) || length(crossref_numbered_val) != 1 || is.na(crossref_numbered_val))) {
    fail("officequarto.crossref.numbered must be true or false (got: '%s').", crossref_numbered_val)
  }
  crossref_rewrite_needed <- isFALSE(crossref_numbered_val)

  ## officequarto.crossref.auto-number (no officedown equivalent -
  ## {officedown} is always field-based, so it has no corresponding switch,
  ## the exact same situation as officequarto.lists.list-letter) - converts
  ## captions/cross-references into real, live-numbering Word SEQ/REF
  ## fields instead of rewriting them as static text. See
  ## table-caption-mapping.R (oq_convert_caption_to_field()) and
  ## crossref-mapping.R (oq_apply_crossref_fields()) for the core logic,
  ## dev/spike-notes.md Spike P for the empirically verified bookmark
  ## structure this exploits. Mutually exclusive with
  ## officequarto.crossref.numbered: false (a live field and "always show
  ## caption text instead of a number" are contradictory display modes) -
  ## fail-loud, analogous to the existing code-block validity check above,
  ## deliberately without its own dev/check-*.R test coverage (like the
  ## other inline config validity checks in this file also lack).
  crossref_auto_number_val <- if (!is.null(crossref_config)) crossref_config[["auto-number"]] else NULL
  if (!is.null(crossref_auto_number_val) && (!is.logical(crossref_auto_number_val) || length(crossref_auto_number_val) != 1 || is.na(crossref_auto_number_val))) {
    fail("officequarto.crossref.auto-number must be true or false (got: '%s').", crossref_auto_number_val)
  }
  if (isTRUE(crossref_auto_number_val) && isFALSE(crossref_numbered_val)) {
    fail("officequarto.crossref.auto-number and officequarto.crossref.numbered: false are mutually exclusive (a live SEQ/REF field and 'always show caption text instead of a number' are contradictory display modes) - choose one of the two.")
  }
  crossref_auto_number_needed <- isTRUE(crossref_auto_number_val)

  for (rel_path in docx_outputs) {
    rendered_path <- file.path(output_dir, rel_path)
    if (!file.exists(rendered_path)) {
      log_msg("rendered document '%s' not found, skipping.", rendered_path)
      next
    }

    work_dir <- tempfile("officequarto_")
    dir.create(work_dir)
    on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

    system2("unzip", c("-oq", shQuote(rendered_path), "-d", shQuote(work_dir)))

    orig_dir <- file.path(work_dir, "__original__")
    dir.create(orig_dir)
    system2("unzip", c("-oq", shQuote(reference_doc_path), "docProps/core.xml", "docProps/custom.xml",
                        "word/styles.xml", "-d", shQuote(orig_dir)))

    core_to_path <- file.path(work_dir, "docProps", "core.xml")
    core_from_path <- file.path(orig_dir, "docProps", "core.xml")
    if (file.exists(core_to_path) && file.exists(core_from_path)) {
      core_to <- xml2::read_xml(core_to_path)
      core_from <- xml2::read_xml(core_from_path)
      core_to <- merge_core_properties(core_to, core_from)
      xml2::write_xml(core_to, core_to_path)
    }

    custom_from_path <- file.path(orig_dir, "docProps", "custom.xml")
    if (file.exists(custom_from_path)) {
      file.copy(custom_from_path, file.path(work_dir, "docProps", "custom.xml"), overwrite = TRUE)
    }

    if (!is.null(style_config) || !is.null(lists_config) || !is.null(code_block_config) || !is.null(table_config) || !is.null(plot_config) || !is.null(style_map_config) || !is.null(page_config) || crossref_rewrite_needed || crossref_auto_number_needed) {
      styles_path <- file.path(work_dir, "word", "styles.xml")
      document_path <- file.path(work_dir, "word", "document.xml")
      numbering_path <- file.path(work_dir, "word", "numbering.xml")

      styles_doc <- xml2::read_xml(styles_path)
      document_doc <- xml2::read_xml(document_path)
      ## name_to_id is needed both by the paragraph style mapping below and
      ## by the table caption style mapping (Gruppe 3), so it's computed
      ## centrally once here instead of in both blocks.
      name_to_id <- oq_style_name_to_id(styles_doc)

      ## Footnotes/endnotes (word/footnotes.xml, word/endnotes.xml) only
      ## exist if the rendered document actually contains any
      ## (file.exists() guard, as already used for the reference counting
      ## for style pruning further below). Only read if one of the two
      ## groups that could change something there is actually running
      ## (the curated body/list/code-block mapping and the free-form
      ## officequarto.style-map, see Issue #2 "Footnote/endnote paragraph
      ## styling") - tables/figures/page layout/crossrefs deliberately
      ## continue to patch document.xml only (out of scope, see
      ## README/CLAUDE.md).
      notes_needed <- !is.null(style_config) || !is.null(lists_config) ||
        !is.null(code_block_config) || !is.null(style_map_config)
      footnotes_path <- file.path(work_dir, "word", "footnotes.xml")
      endnotes_path <- file.path(work_dir, "word", "endnotes.xml")
      footnotes_doc <- if (notes_needed && file.exists(footnotes_path)) xml2::read_xml(footnotes_path) else NULL
      endnotes_doc <- if (notes_needed && file.exists(endnotes_path)) xml2::read_xml(endnotes_path) else NULL

      if (!is.null(style_config) || !is.null(lists_config) || !is.null(code_block_config)) {
        style_num_id <- oq_style_num_id(styles_doc)

        style_ids <- list()
        if (!is.null(style_config$body)) {
          style_ids$body <- oq_resolve_style_id(name_to_id, style_config$body, "officequarto.styles.body", fail)
        }
        ## list-bullet/list-number/list-letter accept either a scalar (one
        ## style for every nesting level, unchanged behavior) or an array
        ## (one style per level, index 0 = top level) - both forms arrive
        ## from quarto inspect's JSON as a character vector (length 1 or
        ## length n), and oq_resolve_aliased()'s identical()-based conflict
        ## check works for this unchanged. oq_resolve_style_ids() resolves
        ## each entry individually, fail-loud, preserving order.
        list_bullet_val <- oq_resolve_aliased(lists_config, "list-bullet", "ul_style", "officequarto.lists", warn_msg)
        if (!is.null(list_bullet_val)) {
          style_ids$list_bullet <- oq_resolve_style_ids(name_to_id, list_bullet_val, "officequarto.lists.list-bullet", fail)
        }
        list_number_val <- oq_resolve_aliased(lists_config, "list-number", "ol_style", "officequarto.lists", warn_msg)
        if (!is.null(list_number_val)) {
          style_ids$list_number <- oq_resolve_style_ids(name_to_id, list_number_val, "officequarto.lists.list-number", fail)
        }
        if (!is.null(lists_config$`list-letter`)) {
          style_ids$list_letter <- oq_resolve_style_ids(name_to_id, lists_config$`list-letter`, "officequarto.lists.list-letter", fail)
        }
        if (is.character(code_block_config) && nzchar(code_block_config)) {
          style_ids$code <- oq_resolve_style_id(name_to_id, code_block_config, "officequarto.pandoc-styles.code-block", fail)
        }

        num_fmt_map <- if (file.exists(numbering_path)) {
          oq_num_fmt_map(xml2::read_xml(numbering_path))
        } else {
          character(0)
        }

        result <- oq_apply_style_mapping(document_doc, num_fmt_map, style_ids, style_num_id)
        log_msg("style mapping applied: %d body paragraph(s), %d list paragraph(s), %d code-block paragraph(s).",
                 result$n_body, result$n_list, result$n_code)
        if (result$n_list_clamped > 0) {
          log_msg("of these, %d list paragraph(s) were mapped via clamping to the deepest configured list style (nesting deeper than configured).",
                   result$n_list_clamped)
        }

        ## Footnotes/endnotes share word/numbering.xml with the main
        ## document (the numId space is docx-wide) and the same resolved
        ## style_ids/style_num_id - only the paragraph selector differs.
        ## Body-role detection (officequarto.styles.body) structurally
        ## NEVER fires there (see oq_apply_style_mapping()'s documentation
        ## in style-mapping.R) - n_body is therefore deliberately left
        ## unlogged, to avoid always-zero noise. List/SourceCode detection,
        ## however, apply unchanged if a footnote/endnote itself contains a
        ## list or a code block.
        if (!is.null(footnotes_doc)) {
          fn_result <- oq_apply_style_mapping(footnotes_doc, num_fmt_map, style_ids, style_num_id,
                                               paragraph_xpath = oq_note_paragraph_xpath("footnote"))
          if (fn_result$n_list > 0 || fn_result$n_code > 0) {
            log_msg("style mapping applied to word/footnotes.xml: %d list paragraph(s), %d code-block paragraph(s).",
                     fn_result$n_list, fn_result$n_code)
          }
        }
        if (!is.null(endnotes_doc)) {
          en_result <- oq_apply_style_mapping(endnotes_doc, num_fmt_map, style_ids, style_num_id,
                                               paragraph_xpath = oq_note_paragraph_xpath("endnote"))
          if (en_result$n_list > 0 || en_result$n_code > 0) {
            log_msg("style mapping applied to word/endnotes.xml: %d list paragraph(s), %d code-block paragraph(s).",
                     en_result$n_list, en_result$n_code)
          }
        }
      }

      if (!is.null(table_config)) {
        table_options <- list(layout = table_layout_val, width = table_width_val, conditional = table_conditional_options)
        if (!is.null(table_style_val)) {
          table_style_name_to_id <- oq_style_name_to_id(styles_doc, type = "table")
          table_options$style <- oq_resolve_style_id(table_style_name_to_id, table_style_val, "officequarto.tables.style", fail)
        }
        n_tables <- oq_apply_table_options(document_doc, table_options)
        log_msg("table options applied: %d table(s).", n_tables)
      }

      ## crossref_rewrite_needed (Gruppe 9) lets this block run even when
      ## officequarto.tables.caption itself isn't configured - caption_options
      ## then stays empty (no style/text change), but oq_apply_captions()
      ## still returns the anchor_text needed for Gruppe 9 (see
      ## table-caption-mapping.R).
      crossref_anchor_text <- character(0)
      crossref_converted_anchors <- character(0)
      if (!is.null(table_caption_config) || crossref_rewrite_needed || crossref_auto_number_needed) {
        caption_options <- list(prefix = table_caption_prefix_val, separator = table_caption_separator_val, number_bold = table_caption_bold_val, above = table_caption_above_val, auto_number = crossref_auto_number_needed)
        if (!is.null(table_caption_style_val)) {
          caption_options$style <- oq_resolve_style_id(name_to_id, table_caption_style_val, "officequarto.tables.caption.style", fail)
        }
        caption_result <- oq_apply_captions(document_doc, oq_find_table_caption_paragraphs(document_doc, xml2::xml_ns(document_doc)), caption_options, oq_table_caption_content, seq_id = "Table")
        log_msg("table captions: %d found, %d text rewritten, %d field(s) converted, %d moved.",
                 caption_result$n_found, caption_result$n_text_rewritten, caption_result$n_field_converted, caption_result$n_moved)
        crossref_anchor_text <- c(crossref_anchor_text, caption_result$anchor_text)
        crossref_converted_anchors <- c(crossref_converted_anchors, caption_result$converted_anchors)
      }

      if (!is.null(plot_config)) {
        plot_options <- list(align = plot_align_val)
        if (!is.null(plot_style_val)) {
          plot_options$style <- oq_resolve_style_id(name_to_id, plot_style_val, "officequarto.plots.style", fail)
        }
        n_plots <- oq_apply_plot_options(document_doc, plot_options)
        log_msg("figure options applied: %d figure(s).", n_plots)
      }

      if (!is.null(plot_caption_config) || crossref_rewrite_needed || crossref_auto_number_needed) {
        plot_caption_options <- list(prefix = plot_caption_prefix_val, separator = plot_caption_separator_val, number_bold = plot_caption_bold_val, above = plot_caption_above_val, auto_number = crossref_auto_number_needed)
        if (!is.null(plot_caption_style_val)) {
          plot_caption_options$style <- oq_resolve_style_id(name_to_id, plot_caption_style_val, "officequarto.plots.caption.style", fail)
        }
        plot_caption_result <- oq_apply_captions(document_doc, oq_find_plot_caption_paragraphs(document_doc, xml2::xml_ns(document_doc)), plot_caption_options, oq_plot_caption_content, seq_id = "Figure")
        log_msg("figure captions: %d found, %d text rewritten, %d field(s) converted, %d moved.",
                 plot_caption_result$n_found, plot_caption_result$n_text_rewritten, plot_caption_result$n_field_converted, plot_caption_result$n_moved)
        crossref_anchor_text <- c(crossref_anchor_text, plot_caption_result$anchor_text)
        crossref_converted_anchors <- c(crossref_converted_anchors, plot_caption_result$converted_anchors)
      }

      if (crossref_rewrite_needed) {
        n_crossref <- oq_apply_crossref_text(document_doc, crossref_anchor_text)
        log_msg("cross-references switched to caption text (officequarto.crossref.numbered: false): %d.", n_crossref)
      } else if (crossref_auto_number_needed) {
        n_crossref_fields <- oq_apply_crossref_fields(document_doc, crossref_converted_anchors)
        log_msg("cross-references switched to SEQ/REF fields (officequarto.crossref.auto-number: true): %d.", n_crossref_fields)
      }

      ## Deliberately the last step (see style-map.R): by default this
      ## therefore only touches paragraphs left untouched by the steps
      ## above, but can also, if needed, deliberately override an
      ## already-remapped target style once more.
      if (!is.null(style_map_config)) {
        source_to_target <- oq_resolve_style_map(style_map_config, name_to_id, fail)
        n_mapped <- oq_apply_style_map(document_doc, source_to_target)
        log_msg("free-form style mapping (officequarto.style-map) applied: %d paragraph(s).", n_mapped)

        ## The same resolved mapping, just with the footnote/endnote-
        ## specific paragraph selector (excludes separator/
        ## continuationSeparator - otherwise, e.g., a rule "X": [Normal]
        ## would also match a footnote's pStyle-less separator-line
        ## paragraph). This makes FootnoteText/EndnoteText in particular
        ## (Pandoc's fixed fallback style ID, possibly never defined in
        ## reference-doc, see README "Footnotes and endnotes") addressable
        ## as an entirely ordinary source ID - the actual solution path
        ## for Issue #2, deliberately with no configuration option of its
        ## own (see CLAUDE.md).
        if (!is.null(footnotes_doc)) {
          n_fn_mapped <- oq_apply_style_map(footnotes_doc, source_to_target, oq_note_paragraph_xpath("footnote"))
          if (n_fn_mapped > 0) {
            log_msg("free-form style mapping applied to word/footnotes.xml: %d paragraph(s).", n_fn_mapped)
          }
        }
        if (!is.null(endnotes_doc)) {
          n_en_mapped <- oq_apply_style_map(endnotes_doc, source_to_target, oq_note_paragraph_xpath("endnote"))
          if (n_en_mapped > 0) {
            log_msg("free-form style mapping applied to word/endnotes.xml: %d paragraph(s).", n_en_mapped)
          }
        }
      }

      if (!is.null(page_config)) {
        n_sections <- oq_apply_page_options(document_doc, list(size = page_size_vals, margins = page_margin_vals))
        log_msg("page layout (officequarto.page) applied: %d section(s).", n_sections)
      }

      xml2::write_xml(document_doc, document_path)
      if (!is.null(footnotes_doc)) xml2::write_xml(footnotes_doc, footnotes_path)
      if (!is.null(endnotes_doc)) xml2::write_xml(endnotes_doc, endnotes_path)
    }

    ref_styles_path <- file.path(orig_dir, "word", "styles.xml")
    if (file.exists(ref_styles_path)) {
      ref_style_ids <- oq_all_style_ids(xml2::read_xml(ref_styles_path))

      content_paths <- file.path(
        work_dir, "word",
        c("document.xml", "footnotes.xml", "endnotes.xml", "comments.xml")
      )
      content_docs <- lapply(content_paths[file.exists(content_paths)], xml2::read_xml)
      referenced_ids <- oq_referenced_style_ids(content_docs)

      rendered_styles_path <- file.path(work_dir, "word", "styles.xml")
      rendered_styles_doc <- xml2::read_xml(rendered_styles_path)

      keep_style_ids <- ref_style_ids
      if (isTRUE(code_block_config)) {
        rendered_ids_all <- oq_all_style_ids(rendered_styles_doc)
        code_style_ids <- rendered_ids_all[oq_is_pandoc_code_style_id(rendered_ids_all)]
        keep_style_ids <- union(keep_style_ids, code_style_ids)
        if (length(code_style_ids) > 0) {
          log_msg("keeping Pandoc's code-block styles (officequarto.pandoc-styles.code-block: true): %s",
                   paste(code_style_ids, collapse = ", "))
        }
      }

      prune_result <- oq_prune_foreign_styles(rendered_styles_doc, keep_style_ids, referenced_ids)
      xml2::write_xml(rendered_styles_doc, rendered_styles_path)

      log_msg("styles pruned: %d removed, %d kept.",
               length(prune_result$removed), length(keep_style_ids))
      if (length(prune_result$removed_but_referenced) > 0) {
        log_msg(paste0(
          "Warning: the following removed styles are still referenced in the document and fall ",
          "back to Word's default formatting: %s (add them to the reference-doc, redirect them to ",
          "an existing style via officequarto.styles/officequarto.lists, or, for code-block ",
          "styles, set officequarto.pandoc-styles.code-block)."
        ), paste(prune_result$removed_but_referenced, collapse = ", "))
      }
    }

    if (isTRUE(keep_rendered)) {
      debug_path <- file.path(
        dirname(rendered_path),
        paste0(tools::file_path_sans_ext(basename(rendered_path)), ".quarto-rendered.docx")
      )
      file.copy(rendered_path, debug_path, overwrite = TRUE)
      log_msg("kept the raw Quarto/Pandoc result (officequarto.keep-rendered): %s", debug_path)
    }

    ## Zip into a temporary file and only then copy it over rendered_path,
    ## instead of zipping directly into rendered_path - if zipping fails,
    ## this leaves the previous (valid) output file untouched instead of
    ## ending up damaged/empty.
    tmp_zip <- tempfile("officequarto_out_", fileext = ".docx")
    old_wd <- setwd(work_dir)
    system2("zip", c("-rq", shQuote(tmp_zip), "."))
    setwd(old_wd)
    file.copy(tmp_zip, rendered_path, overwrite = TRUE)
    file.remove(tmp_zip)

    log_msg("updated: %s", rendered_path)
  }

  invisible(NULL)
}
