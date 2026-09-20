test_that("oq_create_project() scaffolds a new project with the bundled extension", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  oq_create_project(project_dir, open = FALSE)

  expect_true(file.exists(file.path(project_dir, "_quarto.yml")))
  quarto_yml <- readLines(file.path(project_dir, "_quarto.yml"))
  expect_true(any(grepl("type: officequarto", quarto_yml)))

  expect_true(file.exists(file.path(project_dir, "_extensions", "officequarto", "_extension.yml")))
  expect_true(file.exists(file.path(project_dir, "_extensions", "officequarto", "scripts", "writeback.R")))

  qmd_files <- list.files(project_dir, pattern = "\\.qmd$")
  expect_length(qmd_files, 1)
})

test_that("oq_create_project() copies reference_doc under its basename and references it in _quarto.yml", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  ref_doc <- tempfile("my-reference-", fileext = ".docx")
  writeLines("placeholder - not a real docx, only used to test file-copy behavior", ref_doc)
  on.exit(unlink(ref_doc), add = TRUE)

  oq_create_project(project_dir, reference_doc = ref_doc, open = FALSE)

  copied_path <- file.path(project_dir, basename(ref_doc))
  expect_true(file.exists(copied_path))

  quarto_yml <- readLines(file.path(project_dir, "_quarto.yml"))
  expect_true(any(grepl(sprintf("reference-doc: %s", basename(ref_doc)), quarto_yml, fixed = TRUE)))
})

test_that("oq_create_project() omits reference-doc from _quarto.yml when not supplied", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  oq_create_project(project_dir, open = FALSE)

  quarto_yml <- readLines(file.path(project_dir, "_quarto.yml"))
  expect_false(any(grepl("reference-doc:", quarto_yml, fixed = TRUE)))
})

test_that("oq_create_project() fails loudly if path already contains a _quarto.yml", {
  project_dir <- tempfile("oq_project_")
  dir.create(project_dir, recursive = TRUE)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  writeLines("project:\n  type: default", file.path(project_dir, "_quarto.yml"))

  expect_error(oq_create_project(project_dir, open = FALSE))
})

test_that("oq_create_project() fails loudly if reference_doc doesn't exist", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  expect_error(oq_create_project(project_dir, reference_doc = "does/not/exist.docx", open = FALSE))
  expect_false(dir.exists(project_dir))
})

test_that("oq_create_project()'s _quarto.yml lists every officequarto option at its default value", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  oq_create_project(project_dir, open = FALSE)
  quarto_yml <- readLines(file.path(project_dir, "_quarto.yml"))

  ## Boolean/enum options with a real behavioral default: literal value.
  expect_true(any(grepl("keep-rendered: false", quarto_yml, fixed = TRUE)))
  expect_true(any(grepl("first-row: false", quarto_yml, fixed = TRUE)))
  expect_true(any(grepl("numbered: true", quarto_yml, fixed = TRUE)))
  expect_true(any(grepl("auto-number: false", quarto_yml, fixed = TRUE)))
  expect_true(any(grepl("code-block: false", quarto_yml, fixed = TRUE)))

  ## String/style-name options with no universal default: explicit null.
  expect_true(any(grepl("body: null", quarto_yml, fixed = TRUE)))
  expect_true(any(grepl("style: null", quarto_yml, fixed = TRUE)))

  ## style-map is free-form (no fixed default entries) - present only as a
  ## commented-out shape example, never as an active key.
  active_lines <- quarto_yml[!grepl("^\\s*#", quarto_yml)]
  expect_false(any(grepl("^\\s*style-map:", active_lines)))
})

test_that("oq_create_project() copies quarto_yml verbatim instead of generating one", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  custom_yml <- tempfile("custom-", fileext = ".yml")
  writeLines(c("project:", "  type: officequarto", "", "# my own custom content"), custom_yml)
  on.exit(unlink(custom_yml), add = TRUE)

  oq_create_project(project_dir, quarto_yml = custom_yml, open = FALSE)

  expect_identical(readLines(file.path(project_dir, "_quarto.yml")), readLines(custom_yml))
})

test_that("oq_create_project() with both quarto_yml and reference_doc copies the docx but leaves the yaml untouched", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  ref_doc <- tempfile("my-reference-", fileext = ".docx")
  writeLines("placeholder - not a real docx, only used to test file-copy behavior", ref_doc)
  on.exit(unlink(ref_doc), add = TRUE)

  custom_yml <- tempfile("custom-", fileext = ".yml")
  writeLines(c("project:", "  type: officequarto"), custom_yml)
  on.exit(unlink(custom_yml), add = TRUE)

  oq_create_project(project_dir, reference_doc = ref_doc, quarto_yml = custom_yml, open = FALSE)

  expect_true(file.exists(file.path(project_dir, basename(ref_doc))))
  expect_identical(readLines(file.path(project_dir, "_quarto.yml")), readLines(custom_yml))
})

test_that("oq_create_project() fails loudly if quarto_yml doesn't exist", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  expect_error(oq_create_project(project_dir, quarto_yml = "does/not/exist.yml", open = FALSE))
  expect_false(dir.exists(project_dir))
})

test_that("a fully-expanded, all-default oq_create_project() scaffold still renders end-to-end", {
  testthat::skip_if_not(nzchar(Sys.which("quarto")), "quarto CLI not on PATH")

  work_dir <- tempfile("oq_e2e_")
  dir.create(work_dir)
  on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

  ## Pandoc's own built-in default reference.docx - a guaranteed valid,
  ## minimal reference-doc, with no dependency on template/original.docx
  ## (excluded from the built package via .Rbuildignore, so it doesn't exist
  ## in an R-CMD-check environment).
  ref_doc <- file.path(work_dir, "pandoc-default-reference.docx")
  status <- system2("quarto", c("pandoc", "--print-default-data-file", "reference.docx"),
                     stdout = ref_doc, stderr = FALSE)
  testthat::skip_if_not(
    identical(status, 0L) && file.exists(ref_doc) && file.size(ref_doc) > 0,
    "could not obtain Pandoc's default reference.docx"
  )

  project_dir <- file.path(work_dir, "project")
  oq_create_project(project_dir, reference_doc = ref_doc, open = FALSE)

  qmd_file <- list.files(project_dir, pattern = "\\.qmd$", full.names = TRUE)
  expect_length(qmd_file, 1)

  old_wd <- setwd(project_dir)
  on.exit(setwd(old_wd), add = TRUE)
  render_out <- system2("quarto", c("render", shQuote(basename(qmd_file))), stdout = TRUE, stderr = TRUE)
  render_status <- attr(render_out, "status")
  expect_true(is.null(render_status) || render_status == 0)
  expect_true(file.exists(sub("\\.qmd$", ".docx", basename(qmd_file))))
})
