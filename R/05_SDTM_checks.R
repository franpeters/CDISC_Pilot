# R/05_checks.R
if (!exists("db")) source("R/00_setup.R")

ae <- dbReadTable(db, "SDTM_AE")
raw_ae <- dbReadTable(db, "RAW_AE")
dm <- dbReadTable(db, "SDTM_DM")
ec <- dbReadTable(db, "SDTM_EC")
raw_ec <- dbReadTable(db, "RAW_EC")
vs <- dbReadTable(db, "SDTM_VS")
vs_raw <- dbReadTable(db, "RAW_VS")

iso_regex <- "^\\d{4}(-\\d{2}(-\\d{2})?)?$"

# Raw dates present but SDTM date missing (lost in conversion)
check_missing_date <- function(raw, sdtm, raw_col, sdtm_col)
  sum(!is.na(raw[[raw_col]][match(sdtm$oak_id, raw$oak_id)]) & is.na(sdtm[[sdtm_col]]))


check <- function(desc, ok) { say(if (isTRUE(ok)) "PASS " else "FAIL ", desc); isTRUE(ok) }

res <- c(
  # keys and structure
  check("DM: one row per subject",       !anyDuplicated(dm$USUBJID)),
  check("AE: AESEQ unique per subject",  !anyDuplicated(ae[c("USUBJID", "AESEQ")])),
  check("EC: ECSEQ unique per subject",  !anyDuplicated(ec[c("USUBJID", "ECSEQ")])),
  check("VS: VSSEQ unique per subject",  !anyDuplicated(vs[c("USUBJID", "VSSEQ")])),
  
  # nothing gained or lost between raw and SDTM
  check("AE: one SDTM row per raw row",  nrow(ae) == nrow(raw_ae)),
  check("EC: one SDTM row per raw row",  nrow(ec) == nrow(raw_ec)),
  check("VS: every row has a source_var", !anyNA(vs$source_var)),
  
  # subjects line up across domains
  check("AE subjects all in DM",         all(ae$USUBJID %in% dm$USUBJID)),
  check("EC subjects all in DM",         all(ec$USUBJID %in% dm$USUBJID)),
  check("VS subjects all in DM",         all(vs$USUBJID %in% dm$USUBJID)),
  
  # dates: valid format, and none lost in conversion
  check("AE dates are ISO 8601",         all(grepl(iso_regex, na.omit(c(ae$AESTDTC, ae$AEENDTC))))),
  check("EC dates are ISO 8601",         all(grepl(iso_regex, na.omit(c(ec$ECSTDTC, ec$ECENDTC))))),
  check("AE: no start dates lost",       check_missing_date(raw_ae, ae, "IT.AESTDAT", "AESTDTC") == 0),
  check("EC: no start dates lost",       check_missing_date(raw_ec, ec, "IT.ECSTDAT", "ECSTDTC") == 0),
  check("VS dates all convert to ISO",   !anyNA(to_iso(unique(na.omit(vs_raw$VTLD))))),
  
  # controlled values
  check("AESER only Y/N",                all(ae$AESER %in% c("Y", "N"))),
  check("DM: SEX only M/F/U",            all(dm$SEX %in% c("M", "F", "U"))),
  
  # lineage metadata
  check("No table is its own source",
        nrow(dbGetQuery(db, "SELECT 1 FROM META_LINEAGE_DATASET WHERE target_table = source_table")) == 0),
  check("Every lineage source is a registered table",
        nrow(dbGetQuery(db, "SELECT 1 FROM META_LINEAGE_DATASET
                             WHERE source_table NOT IN (SELECT table_name FROM META_DATASET)")) == 0)
)


if (!all(res)) stop(sum(!res), " check(s) failed")