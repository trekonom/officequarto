## Resolution of configuration options that can be set either under their
## canonical (new, descriptive) name or under an old officedown alias
## (naming convention: see README, "Option reference" section). Part of the
## officequarto R package - used by oq_writeback() (R/writeback.R), not run
## standalone.

## config: named list (e.g. the value of format.docx.officequarto.tables).
## canonical_key/alias_key: the two possible keys in config.
## group_label: for the warning message (e.g. "officequarto.tables"). warn_fn:
## function(fmt, ...) called on a conflict - like fail_fn in
## oq_resolve_style_id(), a callback function is used here too instead of a
## direct log_msg() call, so this file stays, like style-mapping.R and
## style-pruning.R, a pure function collection with no side effects of its
## own.
##
## If the canonical name and the alias are both set and disagree (different
## value), the canonical name wins; warn_fn is called with a message stating
## which value was discarded. If both are set and identical, there is no
## warning. If only one of the two is set, its value is used. If neither is
## set, NULL is returned.
#' @noRd
oq_resolve_aliased <- function(config, canonical_key, alias_key, group_label, warn_fn) {
  canonical_val <- config[[canonical_key]]
  alias_val <- config[[alias_key]]

  if (!is.null(canonical_val) && !is.null(alias_val) && !identical(canonical_val, alias_val)) {
    warn_fn(
      paste0(
        "%s: both '%s' (%s) and the officedown alias '%s' (%s) are set and ",
        "disagree - '%s' wins, the alias value is discarded."
      ),
      group_label, canonical_key, canonical_val, alias_key, alias_val, canonical_key
    )
  }

  if (!is.null(canonical_val)) return(canonical_val)
  alias_val
}

## Calls oq_resolve_aliased() for several fields of the same group at once
## and returns a named list (canonical name -> resolved value or NULL).
## fields is a named character vector canonical name -> officedown alias
## (e.g. c(width = "page_size_width", height = "page_size_height")). Useful
## for groups with many similarly-shaped fields (e.g.
## officequarto.page.size/.margins), to avoid the otherwise-needed
## repetition of oq_resolve_aliased() calls. config may be NULL (in which
## case every field is NULL, exactly as oq_resolve_aliased() would also
## handle it individually).
#' @noRd
oq_resolve_fields <- function(config, fields, group_label, warn_fn) {
  stats::setNames(
    lapply(names(fields), function(canonical) {
      if (is.null(config)) return(NULL)
      oq_resolve_aliased(config, canonical, fields[[canonical]], group_label, warn_fn)
    }),
    names(fields)
  )
}

## Variant of oq_resolve_aliased() for option pairs with OPPOSITE polarity
## between the canonical name and the officedown alias (e.g.
## officequarto.tables.conditional.band-rows, phrased positively, vs.
## officedown's no_hband, phrased negatively - "band-rows: true" and
## "no_hband: false" mean the same thing). oq_resolve_aliased() itself
## isn't suited for this, since its conflict check compares raw values for
## equality - with opposite polarity that would be misleading (different
## raw values could still express the same intent, or vice versa). The
## alias value is therefore negated before the comparison.
#' @noRd
oq_resolve_inverted_aliased <- function(config, canonical_key, alias_key, group_label, warn_fn) {
  canonical_val <- config[[canonical_key]]
  alias_raw <- config[[alias_key]]
  alias_val <- if (!is.null(alias_raw)) !alias_raw else NULL

  if (!is.null(canonical_val) && !is.null(alias_val) && !identical(canonical_val, alias_val)) {
    warn_fn(
      paste0(
        "%s: both '%s' (%s) and the (inverted-polarity) officedown alias '%s' (%s, ",
        "equivalent to %s) are set and disagree - '%s' wins, the alias value is ",
        "discarded."
      ),
      group_label, canonical_key, canonical_val, alias_key, alias_raw, alias_val, canonical_key
    )
  }

  if (!is.null(canonical_val)) return(canonical_val)
  alias_val
}
