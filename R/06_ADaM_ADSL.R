

dm <- dbReadTable(db, "SDTM_DM")
ec <- dbReadTable(db, "SDTM_EC")

# Treatment start/end from exposure: records with a dose (or placebo) and a full date
trt <- ec %>%
  filter(coalesce(ECDOSE, 0) > 0 | str_detect(ECTRT, "PLACEBO"), nchar(ECSTDTC) == 10) %>%
  mutate(start = ymd(ECSTDTC),
         end   = ymd(if_else(nchar(coalesce(ECENDTC, "")) == 10, ECENDTC, ECSTDTC))) %>%
  group_by(USUBJID) %>%
  summarise(TRTSDT = min(start), TRTEDT = max(end), .groups = "drop")

# One row per subject: DM variables carried over, plus derived treatment variables
adsl <- dm %>%
  left_join(trt, by = "USUBJID") %>%
  mutate(TRT01P  = ARM,
         TRT01A  = ACTARM,
         TRTDURD = as.numeric(TRTEDT - TRTSDT) + 1,
         AGEGR1  = case_when(AGE < 65 ~ "<65", AGE <= 80 ~ "65-80", AGE > 80 ~ ">80"),
         SAFFL   = if_else(!is.na(TRTSDT), "Y", "N")) %>%
  select(STUDYID, USUBJID, SUBJID, SITEID, AGE, AGEU, AGEGR1, SEX, RACE, ETHNIC, COUNTRY,
         ARM, ACTARM, TRT01P, TRT01A, TRTSDT, TRTEDT, TRTDURD, SAFFL)

stopifnot(!anyDuplicated(adsl$USUBJID), nrow(adsl) == nrow(dm))
say("ADSL: ", nrow(adsl), " subjects, ", sum(adsl$SAFFL == "Y"), " in the safety population")

# Spec: same pattern as the SDTM domains
spec_adsl <- make_spec(adsl, dm, "SDTM_DM") %>%
  mutate(origin = if_else(origin == "Collected", "Predecessor", origin))   # ADaM wording

spec_adsl <- set_spec_manually(spec_adsl, "TRT01P",  "Derived", "ARM",    "Planned treatment = ARM")
spec_adsl <- set_spec_manually(spec_adsl, "TRT01A",  "Derived", "ACTARM", "Actual treatment = ACTARM")
spec_adsl <- set_spec_manually(spec_adsl, "TRTSDT",  "Derived", "ECSTDTC", "First exposure with dose > 0 or placebo, full dates only")
spec_adsl <- set_spec_manually(spec_adsl, "TRTEDT",  "Derived", "ECENDTC", "Last exposure end (start date if no end), full dates only")
spec_adsl <- set_spec_manually(spec_adsl, "TRTDURD", "Derived", "TRTSDT; TRTEDT", "TRTEDT - TRTSDT + 1")
spec_adsl <- set_spec_manually(spec_adsl, "AGEGR1",  "Derived", "AGE",    "<65, 65-80, >80")
spec_adsl <- set_spec_manually(spec_adsl, "SAFFL",   "Derived", "TRTSDT", "Y if TRTSDT is not missing")

# The exposure-derived rows come from EC, not DM
spec_adsl <- spec_adsl %>%
  mutate(source_table = if_else(variable %in% c("TRTSDT", "TRTEDT", "TRTDURD", "SAFFL"),
                                "SDTM_EC", source_table)) %>%
  finalise_spec()

write_csv(spec_adsl, "spec/adsl_adam_spec.csv")
register_dataset(db, adsl, "ADAM", "ADSL", run, sources = c("SDTM_DM", "SDTM_EC"),
                 script = "06_adam_adsl.R", spec = spec_adsl)