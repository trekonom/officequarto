test_that("oq_resolve_aliased(): nur canonical Name gesetzt wird korrekt aufgeloest, keine Warnung", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(`list-number` = "Nummerierung ACME"), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_identical(res, "Nummerierung ACME")
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_aliased(): nur officedown-Alias gesetzt wird korrekt aufgeloest, keine Warnung", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(ol_style = "Nummerierung ACME"), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_identical(res, "Nummerierung ACME")
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_aliased(): canonical Name und Alias mit gleichem Wert gesetzt: keine Warnung", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(`list-number` = "X", ol_style = "X"), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_identical(res, "X")
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_aliased(): bei widerspruechlichem canonical/Alias-Wert gewinnt canonical, genau 1 Warnung", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(`list-number` = "Canonical-Wert", ol_style = "Alias-Wert"), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_identical(res, "Canonical-Wert")
  expect_length(warnings_seen, 1)
})

test_that("oq_resolve_aliased(): weder canonical noch Alias gesetzt ergibt NULL", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_null(res)
})

test_that("oq_resolve_aliased(): officequarto.tables.width ueber den officedown-Alias 'tables_width' wird korrekt aufgeloest", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(tables_width = 0.8), "width", "tables_width", "officequarto.tables", warn_collect)
  expect_identical(res, 0.8)
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_inverted_aliased(): nur canonical Name gesetzt wird korrekt aufgeloest, keine Warnung", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_inverted_aliased(list(`band-rows` = TRUE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
  expect_identical(res, TRUE)
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_inverted_aliased(): nur Alias gesetzt wird korrekt negiert (no_hband=FALSE -> band-rows=TRUE)", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_inverted_aliased(list(tables_conditional_no_hband = FALSE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
  expect_identical(res, TRUE)
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_inverted_aliased(): canonical und (negierter) Alias mit gleicher Absicht gesetzt: keine Warnung", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_inverted_aliased(list(`band-rows` = TRUE, tables_conditional_no_hband = FALSE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
  expect_identical(res, TRUE)
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_inverted_aliased(): bei widerspruechlicher Absicht gewinnt canonical, genau 1 Warnung", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_inverted_aliased(list(`band-rows` = TRUE, tables_conditional_no_hband = TRUE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
  expect_identical(res, TRUE)
  expect_length(warnings_seen, 1)
})
