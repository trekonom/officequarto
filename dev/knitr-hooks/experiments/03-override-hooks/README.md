# 03 – Built-in-Hooks überschreiben
**Hypothese:** Ersetzen von `plot` oder `chunk` zerstört Quarto's Zellen-/Crossref-Verarbeitung.
**Ergebnis:** bestätigt. Referenz (`base.qmd`): Caption, „Figure 1", `w:hyperlink w:anchor="fig-a"`, kein ungelöstes `@fig-a`.
- `plot-hook.qmd` (plot-Hook ersetzt): Caption bleibt, aber **„Figure 1"-Präfix, Crossref-Link und Auflösung von `@fig-a` fehlen**.
- `chunk-hook.qmd` (chunk-Hook ohne Delegation): Präfix bleibt, **Crossref-Link fehlt, `@fig-a` unaufgelöst**.
**Evidenz:** `Rscript run.R`. Ursache: Quarto-Hooks sind `delegating_hook`s (`hooks.R:179`), knitr kennt kein Chaining; ein User-`knit_hooks$set()` im Setup-Chunk ersetzt sie. Konsequenz: officedown's `knit_hooks$plot` (`officedown/R/hooks.R :: plot_word_fig_caption`) ist in Quarto **nicht** ohne Weiteres einsetzbar; sauber wäre Chaining (alten Hook per `knitr::knit_hooks$get("plot")` sichern und aufrufen).
