#create the exposure SDTM and create the specs to track how each
#variable was created

if (!exists("db")) source("00_setup.R") 
# create CDTM 
ec_SDTM <- ec_raw %>%
  transmute(
    STUDYID = STUDY, DOMAIN = "EC",
    USUBJID = make_usubjid(PATNUM),
    ECREFID = IT.ECREFID,
    ECTRT   = toupper(DRUGAD),
    ECDOSE  = suppressWarnings(as.numeric(IT.ECDSTXT)),   # IT.ECDSTXT may be text
    ECDOSU  = IT.ECDOSU,
    ECDOSFRM = DOSFM,
    ECDOSFRQ = DOSFRQ,
    ECROUTE = IT.ECROUTE,
    VISIT   = VISITNAME,
    ECSTDTC = to_iso(IT.ECSTDAT),
    ECENDTC = to_iso(IT.ECENDAT),
    oak_id, raw_source, patient_number) %>%
  group_by(USUBJID) %>%
  arrange(ECSTDTC, ECTRT, .by_group = TRUE) %>%
  mutate(ECSEQ = row_number()) %>% ungroup()

#how is each variable derived
spec_ec  <- make_spec(ec_SDTM, ec_raw, "RAW_EC")

spec_ec <- set_spec_manually(spec_ec, "STUDYID",  "Collected", "STUDY",      "Direct map")
spec_ec <- set_spec_manually(spec_ec, "DOMAIN",   "Assigned",  NA,           "Constant EC")
spec_ec <- set_spec_manually(spec_ec, "USUBJID",  "Derived",   "PATNUM",     "01- + PATNUM (make_usubjid)")
spec_ec <- set_spec_manually(spec_ec, "ECREFID",  "Collected", "IT.ECREFID", "Direct map")
spec_ec <- set_spec_manually(spec_ec, "ECTRT",    "Collected", "DRUGAD",     "toupper")
spec_ec <- set_spec_manually(spec_ec, "ECDOSE",   "Collected", "IT.ECDSTXT", "as.numeric, non-numeric text becomes NA")
spec_ec <- set_spec_manually(spec_ec, "ECDOSU",   "Collected", "IT.ECDOSU",  "Direct map")
spec_ec <- set_spec_manually(spec_ec, "ECDOSFRM", "Collected", "DOSFM",      "Direct map")
spec_ec <- set_spec_manually(spec_ec, "ECDOSFRQ", "Collected", "DOSFRQ",     "Direct map")
spec_ec <- set_spec_manually(spec_ec, "ECROUTE",  "Collected", "IT.ECROUTE", "Direct map")
spec_ec <- set_spec_manually(spec_ec, "VISIT",    "Collected", "VISITNAME",  "Direct map")
spec_ec <- set_spec_manually(spec_ec, "ECSTDTC",  "Collected", "IT.ECSTDAT", "to_iso, ISO 8601, partial dates kept")
spec_ec <- set_spec_manually(spec_ec, "ECENDTC",  "Collected", "IT.ECENDAT", "to_iso, ISO 8601, partial dates kept")
spec_ec <- set_spec_manually(spec_ec, "ECSEQ",    "Derived",   NA,           "row_number within USUBJID, ordered by ECSTDTC, ECTRT")

#load into database
register_domain(db, run, raw = ec_raw, sdtm = ec_SDTM, spec = spec_ec,
                domain = "EC", script = "01_SDTM_ec.R")
