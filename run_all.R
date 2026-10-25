# Run Generate Dataset

# 1. Clean up: close any old connection and delete the old database
if (exists("db") && DBI::dbIsValid(db)) DBI::dbDisconnect(db)
if (file.exists("SDTM_study.sqlite")) file.remove("SDTM_study.sqlite")
dir.create("spec", showWarnings = FALSE)

# 2. Setup: libraries, functions, study_ct, then opens db and starts the run
source("R/00_setup.R")

# 3. Run all files in sequence
for (f in c("R/01_sdtm_ec.R", "R/02_sdtm_vs.R", "R/03_sdtm_ae.R", "R/04_sdtm_dm.R",
            "R/05_SDTM_checks.R", "R/06_adam_adsl.R", "R/07_create_tfl.R")) {
  say("=== ", f, " ===")
  source(f, echo = FALSE)
}

DBI::dbDisconnect(db)
