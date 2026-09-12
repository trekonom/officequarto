test_that("create_officequarto_project() scaffolds a new project with the bundled extension", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  create_officequarto_project(project_dir, open = FALSE)

  expect_true(file.exists(file.path(project_dir, "_quarto.yml")))
  quarto_yml <- readLines(file.path(project_dir, "_quarto.yml"))
  expect_true(any(grepl("type: officequarto", quarto_yml)))

  expect_true(file.exists(file.path(project_dir, "_extensions", "officequarto", "_extension.yml")))
  expect_true(file.exists(file.path(project_dir, "_extensions", "officequarto", "scripts", "writeback.R")))

  qmd_files <- list.files(project_dir, pattern = "\\.qmd$")
  expect_length(qmd_files, 1)
})

test_that("create_officequarto_project() copies reference_doc under its basename and references it in _quarto.yml", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  ref_doc <- tempfile("my-reference-", fileext = ".docx")
  writeLines("placeholder - not a real docx, only used to test file-copy behavior", ref_doc)
  on.exit(unlink(ref_doc), add = TRUE)

  create_officequarto_project(project_dir, reference_doc = ref_doc, open = FALSE)

  copied_path <- file.path(project_dir, basename(ref_doc))
  expect_true(file.exists(copied_path))

  quarto_yml <- readLines(file.path(project_dir, "_quarto.yml"))
  expect_true(any(grepl(sprintf("reference-doc: %s", basename(ref_doc)), quarto_yml, fixed = TRUE)))
})

test_that("create_officequarto_project() omits reference-doc from _quarto.yml when not supplied", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  create_officequarto_project(project_dir, open = FALSE)

  quarto_yml <- readLines(file.path(project_dir, "_quarto.yml"))
  expect_false(any(grepl("reference-doc:", quarto_yml, fixed = TRUE)))
})

test_that("create_officequarto_project() fails loudly if path already contains a _quarto.yml", {
  project_dir <- tempfile("oq_project_")
  dir.create(project_dir, recursive = TRUE)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  writeLines("project:\n  type: default", file.path(project_dir, "_quarto.yml"))

  expect_error(create_officequarto_project(project_dir, open = FALSE))
})

test_that("create_officequarto_project() fails loudly if reference_doc doesn't exist", {
  project_dir <- tempfile("oq_project_")
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)

  expect_error(create_officequarto_project(project_dir, reference_doc = "does/not/exist.docx", open = FALSE))
  expect_false(dir.exists(project_dir))
})
