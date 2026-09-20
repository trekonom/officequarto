test_that("oq_create_quarto_yml() writes a default, all-defaults _quarto.yml", {
  target <- tempfile("oq_quarto_yml_", fileext = ".yml")
  on.exit(unlink(target), add = TRUE)

  result <- oq_create_quarto_yml(target)

  expect_identical(result, normalizePath(target))
  quarto_yml <- readLines(target)
  expect_true(any(grepl("type: officequarto", quarto_yml)))
  expect_false(any(grepl("reference-doc:", quarto_yml, fixed = TRUE)))
})

test_that("oq_create_quarto_yml() fails loudly if the target already exists, unless overwrite = TRUE", {
  target <- tempfile("oq_quarto_yml_", fileext = ".yml")
  on.exit(unlink(target), add = TRUE)
  writeLines("placeholder", target)

  expect_error(oq_create_quarto_yml(target))

  oq_create_quarto_yml(target, overwrite = TRUE)
  quarto_yml <- readLines(target)
  expect_true(any(grepl("type: officequarto", quarto_yml)))
})
