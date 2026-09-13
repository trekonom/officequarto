test_that("knit_print.run() wraps to_wml() output as an inline raw openxml span for docx", {
  testthat::skip_if_not_installed("officer")
  testthat::skip_if_not_installed("knitr")

  old <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  on.exit(knitr::opts_knit$set(rmarkdown.pandoc.to = old), add = TRUE)
  knitr::opts_knit$set(rmarkdown.pandoc.to = "docx")

  x <- officer::ftext("hello", officer::fp_text(bold = TRUE))
  out <- as.character(knit_print.run(x))

  expect_true(grepl("^`<w:r>", out))
  expect_true(grepl("`\\{=openxml\\}$", out))
  expect_true(grepl("hello", out))
})

test_that("knit_print.fp_par() wraps to_wml() output as an inline raw openxml span for docx", {
  testthat::skip_if_not_installed("officer")
  testthat::skip_if_not_installed("knitr")

  old <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  on.exit(knitr::opts_knit$set(rmarkdown.pandoc.to = old), add = TRUE)
  knitr::opts_knit$set(rmarkdown.pandoc.to = "docx")

  x <- officer::fp_par(text.align = "center")
  out <- as.character(knit_print.fp_par(x))

  expect_true(grepl("^`<w:pPr>", out))
  expect_true(grepl("`\\{=openxml\\}$", out))
})

test_that("knit_print.block() wraps to_wml() output in a fenced openxml block for docx", {
  testthat::skip_if_not_installed("officer")
  testthat::skip_if_not_installed("knitr")

  old <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  on.exit(knitr::opts_knit$set(rmarkdown.pandoc.to = old), add = TRUE)
  knitr::opts_knit$set(rmarkdown.pandoc.to = "docx")

  x <- officer::fpar(officer::ftext("hello"))
  out <- as.character(knit_print.block(x))

  expect_true(grepl("^```\\{=openxml\\}\n", out))
  expect_true(grepl("\n```$", out))
  expect_true(grepl("hello", out))
})

test_that("knit_print methods emit empty output for a non-docx pandoc target", {
  testthat::skip_if_not_installed("officer")
  testthat::skip_if_not_installed("knitr")

  old <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  on.exit(knitr::opts_knit$set(rmarkdown.pandoc.to = old), add = TRUE)
  knitr::opts_knit$set(rmarkdown.pandoc.to = "html")

  x <- officer::ftext("hello", officer::fp_text(bold = TRUE))
  out <- as.character(knit_print.run(x))

  expect_identical(out, "")
})
