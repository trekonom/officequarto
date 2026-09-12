test_that("oq_resolve_aliased(): only the canonical name set resolves correctly, no warning", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(`list-number` = "Nummerierung ACME"), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_identical(res, "Nummerierung ACME")
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_aliased(): only the officedown alias set resolves correctly, no warning", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(ol_style = "Nummerierung ACME"), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_identical(res, "Nummerierung ACME")
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_aliased(): canonical name and alias set to the same value: no warning", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(`list-number` = "X", ol_style = "X"), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_identical(res, "X")
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_aliased(): on a conflicting canonical/alias value, canonical wins, exactly 1 warning", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(`list-number` = "Canonical-Wert", ol_style = "Alias-Wert"), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_identical(res, "Canonical-Wert")
  expect_length(warnings_seen, 1)
})

test_that("oq_resolve_aliased(): neither canonical nor alias set yields NULL", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(), "list-number", "ol_style", "officequarto.lists", warn_collect)
  expect_null(res)
})

test_that("oq_resolve_aliased(): officequarto.tables.width resolves correctly via the officedown alias 'tables_width'", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_aliased(list(tables_width = 0.8), "width", "tables_width", "officequarto.tables", warn_collect)
  expect_identical(res, 0.8)
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_inverted_aliased(): only the canonical name set resolves correctly, no warning", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_inverted_aliased(list(`band-rows` = TRUE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
  expect_identical(res, TRUE)
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_inverted_aliased(): only the alias set is negated correctly (no_hband=FALSE -> band-rows=TRUE)", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_inverted_aliased(list(tables_conditional_no_hband = FALSE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
  expect_identical(res, TRUE)
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_inverted_aliased(): canonical and (negated) alias set with the same intent: no warning", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_inverted_aliased(list(`band-rows` = TRUE, tables_conditional_no_hband = FALSE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
  expect_identical(res, TRUE)
  expect_length(warnings_seen, 0)
})

test_that("oq_resolve_inverted_aliased(): on conflicting intent, canonical wins, exactly 1 warning", {
  warnings_seen <- character(0)
  warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_inverted_aliased(list(`band-rows` = TRUE, tables_conditional_no_hband = TRUE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
  expect_identical(res, TRUE)
  expect_length(warnings_seen, 1)
})
