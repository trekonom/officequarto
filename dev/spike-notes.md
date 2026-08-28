# Spike-Notizen

Ergebnisse aus Phase 0 (Setup & Spike), verifiziert am 2026-08-28 mit
`quarto 1.8.24`, `Rscript 4.5.2`, `pandoc 3.10.1`.

## Spike A — `reference-doc` allein reicht für Style-Übernahme

`format: docx: reference-doc: original.docx` reicht **ohne jeden eigenen Code**, um Styles,
Header, Footer und Section-Properties (Seitenränder, Papierformat) aus einem beliebigen
Original-`.docx` zu übernehmen. Das ist natives Pandoc-Verhalten (der docx-Writer benutzt das
Referenzdokument als Vorlage für `styles.xml`, `header*.xml`, `footer*.xml` und `sectPr`).

**Überraschender Zusatzfund, der Phase 3 grundlegend verändert hat:** Ein per `reference-doc`
gerendertes `.docx` enthält Header/Footer/Section-Properties des Originals bereits *vollständig
und unverändert* — verifiziert per `unzip`-Diff zwischen `original.docx` und dem reinen
Pandoc-Ergebnis `bericht.docx`, noch bevor irgendein eigener Post-Render-Code lief. Das
ursprünglich geplante "Body des Originals manuell entfernen und Rendering-Body einfügen, dabei
Header/Footer erhalten" (Phase-3-Spezifikation) ist damit für den Kern-Anwendungsfall bereits
durch Pandoc selbst erledigt — ein zusätzlicher XML-Merge-Schritt bringt hier keinen Mehrwert.

Versuch, das im Konzept beschriebene manuelle Body-Ersetzen trotzdem umzusetzen
(`officer::body_add_docx()`, um den Rendering-Output in eine Kopie des Originals einzufügen),
ist an einem Bug/Grenzfall von `officer 0.7.3` gescheitert: Sobald der Body eines Dokuments
vollständig geleert wird (0 Absätze) oder zwei strukturell sehr ähnliche Dokumente (beide mit
eigenen Header/Footer/Sections, da beide von `original.docx` abstammen) gemergt werden, wirft
`print()` beim Reserialisieren einen Fehler in `process_sections_content()` (Zeilen-Mismatch
zwischen Content-Sections und Header/Footer-Dateien). Reproduzierbar mit einem Minimalbeispiel
(zwei Absätze, ein Header, ein Footer).

**Konsequenz für Phase 3:** Der Post-Render-Hook baut nicht mehr selbst den Body zusammen,
sondern arbeitet mit dem bereits korrekten Pandoc-Ergebnis weiter (siehe Abschnitt "Was der Hook
tatsächlich noch beiträgt" unten).

## Was der Hook tatsächlich noch beiträgt

Was Pandoc **nicht** aus dem Original übernimmt: `docProps/core.xml` (Titel, Subject, Keywords,
Description, Category) und `docProps/custom.xml` (frei definierte Custom-Properties, z. B.
Vertraulichkeitsstufe, Dokumentennummer). Pandoc schreibt dafür ein neues, weitgehend leeres
`core.xml` auf Basis der `.qmd`-Metadaten. Genau das übernimmt `scripts/writeback.R`: Es kopiert
das bereits korrekte gerenderte `.docx`, überträgt `dc:subject`/`cp:keywords`/`dc:description`/
`cp:category` sowie `docProps/custom.xml` aus dem Original hinein und speichert das Ergebnis als
`<name>.written-back.docx`.

**Bekannte Grenze:** Wenn das gerenderte Pandoc-Dokument den Part `docProps/custom.xml` selbst
noch nicht kennt (in `[Content_Types].xml`/`_rels/.rels` registriert), würde ein reines
Überschreiben dieser Datei einen nicht referenzierten Part erzeugen. Im getesteten Fall (Original
als `reference-doc`) ist der Part durch Pandoc bereits korrekt registriert; für exotischere
Ausgangsdokumente ist das nicht garantiert und bleibt dokumentierte Einschränkung des Prototyps.

## Spike B — `contributes: project:` in `_extension.yml`

Funktioniert wie erwartet, **ist aber kein Zero-Config-Mechanismus**: `quarto add` installiert
nur die Extension-Dateien. Der Post-Render-Hook wird erst aktiv, wenn das Nutzerprojekt in seiner
eigenen `_quarto.yml` `project: { type: officequarto }` setzt. Verifiziert per Gegenprobe: mit
`project: type: default` (kein `officequarto`) läuft `writeback.R` nachweislich **nicht** —
`bericht.written-back.docx` wird nicht erzeugt. Mit `project: type: officequarto` läuft der Hook
zuverlässig bei jedem `quarto render`.

## Spike C — Umgebungsvariablen im Post-Render-Skript

Zuverlässig verfügbar (per `Sys.getenv()` bestätigt):

- `QUARTO_PROJECT_OUTPUT_FILES` — newline-separierte Liste der Output-Dateien, **relativ** zu
  `QUARTO_PROJECT_OUTPUT_DIR` (im Test: `bericht.docx`)
- `QUARTO_PROJECT_OUTPUT_DIR` — absoluter Pfad (im Test: `.../template`)
- `QUARTO_PROJECT_RENDER_ALL` — `"1"` bei Full-Render
- `QUARTO_PROJECT_DIR` — absoluter Projekt-Root, wird u. a. genutzt, um `original.docx` und die
  Projektkonfiguration zu finden

Den Pfad des `reference-doc` selbst liefert keine Env-Variable — dafür wird `quarto inspect
<project_dir>` aufgerufen und `config.format.docx["reference-doc"]` aus dem JSON gelesen. Das ist
robuster als eigenes YAML-Parsing von `_quarto.yml`, weil `quarto inspect` bereits Merges/
Defaults auflöst.

## Offene Fragen aus Abschnitt 3 des Konzepts — Status

| Frage | Status |
|---|---|
| `contributes: project:` funktioniert? | Ja, mit der oben genannten Aktivierungspflicht |
| `reference-doc` reicht für Style-Übernahme? | Ja, inkl. Header/Footer/Section-Properties — mehr als ursprünglich angenommen |
| Zuverlässige Env-Variablen? | `QUARTO_PROJECT_OUTPUT_FILES`/`_OUTPUT_DIR`/`_DIR`, siehe oben |
| Eigener Projekttyp nötig? | `type:` ja, aber `type: default` reicht — die Extension muss keinen eigenen Custom-Type definieren |
| Content-Zuordnung beim Zurückschreiben? | MVP schreibt Metadaten zurück, nicht den Body (der ist durch `reference-doc` bereits korrekt) — Body-Bookmark-Zuordnung bleibt zukünftige Ausbaustufe |
| R-Verfügbarkeit prüfen? | `writeback.R` prüft `xml2`/`jsonlite`, `quarto`-CLI, `zip`/`unzip` per `requireNamespace`/`Sys.which` und bricht mit verständlicher Meldung ab; ein fehlendes `Rscript` selbst kann das Skript naturgemäß nicht abfangen (siehe README) |
