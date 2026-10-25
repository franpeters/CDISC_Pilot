# CDISC Pilot Pipeline

## What this project is

A small example data pipeline that takes simulated from the `pharmaverseraw` package clinical trial data (no privacy concerns) and moves it through the standard CDISC stages. It stores every stage in one SQLite database and records where each table and variable came from creating a 'data lineage' which would be a more complex data tree once finsihed. It then produces a short QC report. This pipeline is the beginning of creating an R shiny project to show all of the data.

Developed as a pilot.

The pieces are:

1.  **Raw**: the data as collected on the case report forms (CRFs).
2.  **SDTM**: the same data reorganised into the CDISC standard tabulation format (one table per topic, standard variable names).
3.  **ADaM**: analysis-ready data. Here that is one table analysis dataset subject level (ADSL) table, with one row per
4.  **TFL**: tables, listings and figures built from ADaM.
5.  **RMarkdown** report to display the TFLs - as a replacement for R shiny application which needs more time to be developed

## How to run it

``` r
source("run_all.R")               # rebuilds everything from scratch
rmarkdown::render("report.Rmd")   # generates example two-page report
```

`run_all.R` deletes the old `SDTM_study.sqlite`, opens a new connection, runs every script in order, and then closes the connection to the database. `"report.Rmd"` generates the report to show some example results.

## Folder layout

```         
run_all.R                 the only file you run - sources all files in R folder
R/
  0_common_functions.R    make_usubjid(), to_iso()
  database_functions.R    logging, saving to SQLite, lineage
  00_setup.R              libraries, controlled terminology, database connection
  01_SDTM_ec.R            exposure
  02_SDTM_vs.R            vital signs
  03_SDTM_ae.R            adverse events
  04_SDTM_dm.R            demographics
  05_SDTM_checks.R        automated checks
  06_adam_adsl.R          subject-level analysis table
  07_tfl.R                two tables and two figures
spec/                     one CSV per dataset describing each variable
output/                   figure PNGs
report.Rmd                the report
SDTM_study.sqlite         the database (not committed)
```

## What each stage does

**Raw to SDTM.** The `SDTM.oak` package contains algorithms that maps raw columns to SDTM variables. Plain `dplyr` is used where the package doesn't fit (DM, EC and the wide-to-long reshape of VS). Dates are converted to ISO 8601, and partial dates such as `2013` are kept as they are, not guessed. The subject ID (`USUBJID`) are built the same way in every domain: `"01-"` plus the raw patient number.

**SDTM to ADaM:** ADSL takes demographics from DM and works out treatment start and end dates from exposure (EC). It then adds treatment arm, treatment duration, age group and a safety population flag.

**ADaM to TFL:** Percentages use the safety population in each arm as the denominator. Adverse events are counted by subject, not by event. An AE is "treatment-emergent" if it starts on or after the first dose and up to 30 days after the last dose.

All data is saved into an SQLite database and tracks the data as a lineage so full trace-ability of how a variable is derived is not lost.

## What it is tracking (the lineage)

Everything is stored in an SQLite database. Tables are named {`LAYER}_name`, for example `RAW_AE`, `SDTM_AE`, `ADAM_ADSL`, `TFL_T1_DEMOG`. Alongside them are four metadata tables:

| Table | What it records |
|------------------------------------|------------------------------------|
| `META_RUN` | One row per pipeline run: time, R version, package versions. This contains information for the 'run of R code that saved the data to the database' |
| `META_DATASET` | One row per table: layer, rows, columns, a content hash, the source script that made it - in case you need to trace back to the code that generated the value |
| `META_LINEAGE_DATASET` | One row per arrow: "this table was built from data in that table" |
| `META_VARIABLE` | One row per variable: origin (Collected, Derived, Assigned), source variable, derivation text |

There are three levels of lineage:

- **Table level:** `show_lineage(db, "TFL_T2_TOP_AE")` prints every table upstream of it.
- **Variable level:** `META_VARIABLE` says how each variable was made, for example `USUBJID` is `"01-" + PATNUM`.
- **Row level:** SDTM rows keep `oak_id`, `raw_source` and `patient_number`, which point back to the raw row. VS rows also keep `source_var`, because one raw row becomes up to six VS rows.

## Checks

`05_SDTM_checks.R` reads the stored tables and checks things like:

1.  sequence numbers are unique

2.  every subject exists in DM

3.  dates are valid ISO 8601

4.  no dates were lost in conversion

5.  no table is listed as its own source.

[If any check fails, the build stops.]{.underline}

## Assumptions and known limits

- Raw VS has no unit column. Units are assumed (mmHg, beats/min, C, cm, kg) and should be checked against the reference data. - this can be added in but due to time constraints was not added in
- The bundled controlled terminology covers only a few codelists. Severity, causality, action and outcome are uppercased, not validated against CDISC terms. - using an API or extended source would rectify this. Again, used what was available in the time
- Partial AE start dates are treated as the latest possible date, and missing start dates are kept as treatment-emergent. This is the cautious choice.
- Treatment start and end come from records with a dose above zero (or placebo) and a full date.
- The TEAE rule currently lives in the TFL script, not in an ADAE table - should be moved to a separate script
- Ran out of time but to create a full dataset I would add in:
  1.  `RFSTDTC` and `RFENDTC` in DM data module
  2.  standardised VS units,
  3.  XPT export,
  4.  define.xml.

## How I would improve it: 

The domain scripts repeat the same pattern. Putting it into functions makes each script shorter and means a fix is made once.

| Function | What it would do |
|------------------------------------|------------------------------------|
| `read_raw(name)` | Load a `pharmaverseraw` dataset and add the `oak_id` columns |
| `add_identifiers(df, raw, domain)` | Add `STUDYID`, `DOMAIN`, `USUBJID`, `SITEID` and the sequence variable |
| `register_tfl(...)` | Register a table or figure with its sources |

Other changes that would help:

- Move settings (study ID, the 30-day window, file paths) into one `config.R`.
- Add an ADAE table, so the TEAE rule lives in ADaM and lineage runs TFL to ADAE to SDTM_AE.
- Add unit tests with `testthat` for `to_iso()` and `parse_late()`.
- Write the check results to the database so the report can show them.
- Deploying within Docker container to improve portability and reproducability
- Using renv to enforce package verison
- Used git branches for each new feature - developed as a test to focus on the new data type. Not intended as a production piece of code

## Improving Usability: a Shiny app to view the lineage

A small read-only app that opens `study.sqlite` and shows what the pipeline did.

**Tab 1: Lineage graph.** A diagram of all tables, left to right: RAW, SDTM, ADAM, TFL, with arrows from `META_LINEAGE_DATASET`. Built with `visNetwork`, and colour-coded by layer. Clicking a table selects it.

**Tab 2: View and Inspect Variables.** For the selected table, a list from `META_VARIABLE` showing each variable, its origin, source variable and derivation text. A filter for "Derived only" would show where the logic is.

**Tab 3: Row trace.** Pick an AE record from SDTM and see the matching raw record side by side, joined on `oak_id`. A later version could start from a cell in a TFL table and list the records behind it, using a contributors table.

**Tab 4: Checks and runs.** The latest result of every check (PASS or FAIL) from `META_CHECKS`, and the run history from `META_RUN`. A comparison of `content_hash` between runs would show which tables changed.

Suggested packages: `shiny`, `DBI`, `RSQLite`, `visNetwork`, `DT`, `dplyr`.

Every tab only reads from the database tables, so the app needs no changes when a new dataset is registered. It simply reads the data from the structure that is present from all analysis examples, resulting in less development work per project.

## Packages

```         
 pharmaverseraw_0.1.1 
 SDTM.oak_0.2.0       
 gt_1.4.0
 lubridate_1.9.5      
 forcats_1.0.1        
 stringr_1.6.0
 dplyr_1.2.1
 purrr_1.2.2
 readr_2.2.0
 tidyr_1.3.2
 tibble_3.3.1
 ggplot2_4.0.3
 tidyverse_2.0.0
 DBI_1.3.0           
```
