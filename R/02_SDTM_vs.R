#create the vital signs SDTM and create the specs to track how each
#variable was created

#Vital Signs  Dataset



#  lookup: which raw column becomes which VS test 
# NOTE: the raw data has no unit column, so the units here are assumed
vs_map <- data.frame(
  raw_col  = c("SYS_BP", "DIA_BP", "PULSE", "IT.TEMP", "IT.HEIGHT_VSORRES", "IT.WEIGHT"),
  VSTESTCD = c("SYSBP", "DIABP", "PULSE", "TEMP", "HEIGHT", "WEIGHT"),
  VSTEST   = c("Systolic Blood Pressure", "Diastolic Blood Pressure", "Pulse Rate",
               "Temperature", "Height", "Weight"),
  VSORRESU = c("mmHg", "mmHg", "beats/min", "C", "cm", "kg"),
  stringsAsFactors = FALSE)

#  SDTM VS: one row per raw column that has a value 
vs_SDTM <- vs_raw %>%
  mutate(across(all_of(vs_map$raw_col), as.character)) %>%
  pivot_longer(all_of(vs_map$raw_col), names_to = "raw_col", values_to = "VSORRES") %>%
  filter(!is.na(VSORRES), trimws(VSORRES) != "") %>%
  left_join(vs_map, by = "raw_col") %>%
  transmute(
    STUDYID = STUDY, DOMAIN = "VS",
    USUBJID = make_usubjid(PATNUM),
    VSTESTCD, VSTEST,
    VSPOS   = if_else(VSTESTCD %in% c("SYSBP", "DIABP", "PULSE"), toupper(SUBPOS), NA_character_),
    VSLOC   = if_else(VSTESTCD == "TEMP", toupper(IT.TEMP_LOC), NA_character_),
    VSORRES, VSORRESU,
    VSSTRESC = VSORRES,
    VSSTRESN = suppressWarnings(as.numeric(VSORRES)),
    VSSTRESU = VSORRESU,
    VISIT   = INSTANCE,
    VSDTC   = to_iso(VTLD),
    oak_id, raw_source, patient_number, source_var = raw_col) %>%
  group_by(USUBJID) %>%
  arrange(VSDTC, VSTESTCD, .by_group = TRUE) %>%
  mutate(VSSEQ = row_number()) %>%
  ungroup() %>%
  as.data.frame()

#  how each variable was created 
spec_vs <- make_spec(vs_SDTM, vs_raw, "RAW_VS")

spec_vs <- set_spec_manually(spec_vs, "STUDYID",   "Collected",   "STUDY",       "Direct map")
spec_vs <- set_spec_manually(spec_vs, "DOMAIN",    "Assigned",    NA,            "Constant VS")
spec_vs <- set_spec_manually(spec_vs, "USUBJID",   "Derived",     "PATNUM",      "01- + PATNUM (make_usubjid)")
spec_vs <- set_spec_manually(spec_vs, "VSTESTCD",  "Assigned",    NA,            "From vs_map lookup on source_var")
spec_vs <- set_spec_manually(spec_vs, "VSTEST",    "Assigned",    NA,            "From vs_map lookup on source_var")
spec_vs <- set_spec_manually(spec_vs, "VSPOS",     "Collected",   "SUBPOS",      "toupper, only for SYSBP, DIABP, PULSE")
spec_vs <- set_spec_manually(spec_vs, "VSLOC",     "Collected",   "IT.TEMP_LOC", "toupper, only for TEMP")
spec_vs <- set_spec_manually(spec_vs, "VSORRES",   "Collected",
                             "SYS_BP; DIA_BP; PULSE; IT.TEMP; IT.HEIGHT_VSORRES; IT.WEIGHT",
                             "pivot_longer, one row per non-blank value, kept as character")
spec_vs <- set_spec_manually(spec_vs, "VSORRESU",  "Assigned",    NA,            "From vs_map lookup (assumed units, raw data has none)")
spec_vs <- set_spec_manually(spec_vs, "VSSTRESC",  "Derived",     "VSORRES",     "Copy of VSORRES")
spec_vs <- set_spec_manually(spec_vs, "VSSTRESN",  "Derived",     "VSORRES",     "as.numeric, NA if non-numeric")
spec_vs <- set_spec_manually(spec_vs, "VSSTRESU",  "Derived",     "VSORRESU",    "Copy of VSORRESU")
spec_vs <- set_spec_manually(spec_vs, "VISIT",     "Collected",   "INSTANCE",    "Direct map")
spec_vs <- set_spec_manually(spec_vs, "VSDTC",     "Collected",   "VTLD",        "to_iso, ISO 8601, partial dates kept")
spec_vs <- set_spec_manually(spec_vs, "source_var", "Lineage key", NA,           "Name of the raw column each row was pivoted from")
spec_vs <- set_spec_manually(spec_vs, "VSSEQ",     "Derived",     NA,            "row_number within USUBJID, ordered by VSDTC, VSTESTCD")

#  load into the database 
register_domain(db, run, raw = vs_raw, sdtm = vs_SDTM, spec = spec_vs,
                domain = "VS", script = "02_sdtm_vs.R")