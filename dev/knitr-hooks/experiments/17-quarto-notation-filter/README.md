# 17 – Spike: Quarto-Notation (`@fig-a`) für Hook-Items per Lua-Filter
**Frage:** Lässt sich `@fig-a` / `@tbl-a` für Items, die `oq_numbering()` nummeriert hat (id entfernt → Quarto kann nicht auflösen), per Lua-Filter in die `REF`-Felder umsetzen, die `oq_ref()` erzeugt?
**Prototyp:** `refs.lua` – Pass 1 sammelt die Lesezeichen-Namen aus rohen `openxml`-Inlines (`w:bookmarkStart w:name="…"`), Pass 2 ersetzt `Cite`-Knoten, deren Zitate (ganz oder teilweise) dazugehören, durch `REF`-Hyperlinks.

| Frage | Ergebnis (`run.R`) |
|---|---|
| 1. Läuft ein Filter vor Quarto's Crossref-Filter? | **Ja**, sowohl mit `filters: [refs.lua]` (Standard) als auch mit `at: pre-quarto`; identische Ergebnisse. Ohne Filter: 8× „Unable to resolve crossref“ und `?@fig-a` im Text. |
| 2. Cite-Formen | `@a`, `[@a]`, `[@a; @b]`, `[@a, p. 3]`, `[see @a]` werden aufgelöst (Präfix/Suffix bleiben erhalten); unbekannte ids (`@fig-nothere`) bleiben unangetastet und lösen Quarto's eigene Warnung aus. |
| 3. Warnungen | Keine neuen; nur für wirklich unbekannte Referenzen. Der Filter schreibt eine Zeile nach stderr (im fertigen Filter entfernen). |
| 4. Gemischte Dokumente | Native Items (`![](…){#fig-nat}`, `: cap {#tbl-nat}`) bleiben bei Quarto bzw. `auto-number`. Ein **gemischtes Zitat** `[@fig-a; @fig-nat]` war mit „alles oder nichts“ nur halb aufgelöst (`?@fig-a`); die Version mit Aufteilung (eigene Zitate → `REF`, übrige bleiben ein kleineres `Cite`) löst beide auf. |
| 5. Zusammen mit `auto-number: true` | Filter und Post-Render ergänzen sich: `Single: @fig-a and @fig-nat and @tbl-nat` → 3 `REF`-Felder (1 Filter, 2 `auto-number`). |
| Auslieferung | Über die Extension (`contributes.project.format.docx.filters: [scripts/markers.lua, scripts/refs.lua]`) funktioniert; `markers.lua` bleibt aktiv. |
| Echtes Word | Captions „Figure 1: HOOK-FIG-A“, „Figure 2: NATIVE-FIG“, „Table 1: NATIVE-TBL“; Verweise „Single: Figure 1 and Figure 2 and Table 1.“, „Mixed cite: Figure 1; Figure 2.“ |

**Wichtiger Randbefund (gemischte Dokumente):** Hook-Items und `auto-number`-Items nutzen dieselbe `SEQ Figure`-Folge und zählen daher gemeinsam (1, 2). Ohne `auto-number` behält ein natives Item Quarto's *statischen* Text („Figure 1: NATIVE-FIG“), während das Hook-Item ein `SEQ`-Feld hat → doppelte Nummern. Wer native und Hook-Items mischt, braucht `crossref.auto-number: true` (bislang nirgends dokumentiert).

**Entscheidung:** Machbar. Umsetzung: `scripts/refs.lua` in der Extension (Prototyp bereinigen: stderr-Zeile entfernen, nur bei docx, nur wenn Hook-Lesezeichen gefunden), Einbindung in `_extension.yml`, Fixture-Erweiterung + e2e-Check, Doku (Vignette: gemischte Dokumente → `auto-number`). Offen/bewusst nicht behandelt: `Cite` in Überschriften/Captions (Walk erfasst sie, aber nicht geprüft), `-@fig-a` (Suppress-Author-Modus, nicht geprüft).
