#create the Demographics SDTM and create the specs to track how each
#variable was created



# Demographics  Dataset  
dm_SDTM <- dm_raw %>%
  transmute(
    STUDYID = STUDY, DOMAIN = "DM",
    USUBJID = make_usubjid(PATNUM),
    SUBJID  = sub("^\\d+-", "", PATNUM),     # "701-1015" -> "1015"
    SITEID  = sub("-.*$",  "", PATNUM),      # "701-1015" -> "701"
    AGE     = as.numeric(IT.AGE), AGEU = "YEARS",
    SEX     = recode(toupper(IT.SEX), "MALE" = "M", "FEMALE" = "F", .default = "U"),
    RACE    = toupper(IT.RACE),
    ETHNIC  = toupper(IT.ETHNIC),
    COUNTRY = COUNTRY,
    ARM     = PLANNED_ARM, ARMCD  = PLANNED_ARMCD,
    ACTARM  = ACTUAL_ARM,  ACTARMCD = ACTUAL_ARMCD,
    RFICDTC = to_iso(IC_DT),
    DMDTC   = to_iso(COL_DT),
    oak_id, raw_source, patient_number)

#how vars were defined
spec_dm <- make_spec(dm_SDTM, dm_raw, "RAW_DM")


spec_dm <- set_spec_manually(spec_dm, "STUDYID",  "Collected", "STUDY",         "Direct map")
spec_dm <- set_spec_manually(spec_dm, "DOMAIN",   "Assigned",  NA,              "Constant DM")
spec_dm <- set_spec_manually(spec_dm, "USUBJID",  "Derived",   "PATNUM",        "01- + PATNUM (make_usubjid)")
spec_dm <- set_spec_manually(spec_dm, "SUBJID",   "Derived",   "PATNUM",        "Text after first - in PATNUM")
spec_dm <- set_spec_manually(spec_dm, "SITEID",   "Derived",   "PATNUM",        "Text before - in PATNUM")
spec_dm <- set_spec_manually(spec_dm, "AGE",      "Collected", "IT.AGE",        "as.numeric")
spec_dm <- set_spec_manually(spec_dm, "AGEU",     "Assigned",  NA,              "Constant YEARS")
spec_dm <- set_spec_manually(spec_dm, "SEX",      "Collected", "IT.SEX",        "toupper, MALE->M, FEMALE->F, else U")
spec_dm <- set_spec_manually(spec_dm, "RACE",     "Collected", "IT.RACE",       "toupper")
spec_dm <- set_spec_manually(spec_dm, "ETHNIC",   "Collected", "IT.ETHNIC",     "toupper")
spec_dm <- set_spec_manually(spec_dm, "ARM",      "Collected", "PLANNED_ARM",   "Direct map")
spec_dm <- set_spec_manually(spec_dm, "ARMCD",    "Collected", "PLANNED_ARMCD", "Direct map")
spec_dm <- set_spec_manually(spec_dm, "ACTARM",   "Collected", "ACTUAL_ARM",    "Direct map")
spec_dm <- set_spec_manually(spec_dm, "ACTARMCD", "Collected", "ACTUAL_ARMCD",  "Direct map")
spec_dm <- set_spec_manually(spec_dm, "RFICDTC",  "Collected", "IC_DT",         "to_iso, ISO 8601, partial dates kept")
spec_dm <- set_spec_manually(spec_dm, "DMDTC",    "Collected", "COL_DT",        "to_iso, ISO 8601, partial dates kept")


register_domain(db, run, raw = dm_raw, sdtm = dm_SDTM, spec = spec_dm,
                domain = "DM", script = "04_SDTM_dm.R")