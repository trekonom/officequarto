# Package index

## Post-render hook

The extension’s post-render orchestration, called by the bundled Quarto
extension shim.

- [`oq_writeback()`](https://trekonom.github.io/officequarto/reference/oq_writeback.md)
  : Run the officequarto post-render write-back hook

## Project scaffolding

Scaffold a new officequarto project, modeled on
usethis::create_project().

- [`oq_create_project()`](https://trekonom.github.io/officequarto/reference/oq_create_project.md)
  : Create a new officequarto project

- [`oq_create_quarto_yml()`](https://trekonom.github.io/officequarto/reference/oq_create_quarto_yml.md)
  :

  Create a standalone, reusable officequarto-ready `_quarto.yml`

## Native numbering

Live Word SEQ captions and REF references created by knitr hooks while
knitting.

- [`oq_numbering()`](https://trekonom.github.io/officequarto/reference/oq_numbering.md)
  : Native Word numbering for R-chunk figures and tables
- [`oq_fig_hook()`](https://trekonom.github.io/officequarto/reference/oq_fig_hook.md)
  : Default figure numbering hook
- [`oq_tbl_hook()`](https://trekonom.github.io/officequarto/reference/oq_tbl_hook.md)
  : Default table numbering hook
- [`oq_ref()`](https://trekonom.github.io/officequarto/reference/oq_ref.md)
  : Reference a numbered figure or table
