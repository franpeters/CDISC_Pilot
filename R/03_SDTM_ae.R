#create the Adverse Events SDTM and create the specs to track how each
#variable was created


ae_SDTM <-
  assign_no_ct(raw_dat = ae_raw, raw_var = "IT.AETERM", tgt_var = "AETERM",
               id_vars = oak_id_vars()) %>%
  # MedDRA coding already collected in the raw data
  assign_no_ct(raw_dat = ae_raw, raw_var = "AELLT",    tgt_var = "AELLT",    id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "AELLTCD",  tgt_var = "AELLTCD",  id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "AEDECOD",  tgt_var = "AEDECOD",  id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "AEPTCD",   tgt_var = "AEPTCD",   id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "AEHLT",    tgt_var = "AEHLT",    id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "AEHLGT",   tgt_var = "AEHLGT",   id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "AEBODSYS", tgt_var = "AEBODSYS", id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "AEBDSYCD", tgt_var = "AEBDSYCD", id_vars = oak_id_vars()) %>%
  # severity, seriousness, causality, action, outcome
  assign_no_ct(raw_dat = ae_raw, raw_var = "IT.AESEV",  tgt_var = "AESEV", id_vars = oak_id_vars()) %>%
  assign_ct(raw_dat = ae_raw, raw_var = "IT.AESER", tgt_var = "AESER",
            ct_spec = study_ct, ct_clst = "C66742", id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "IT.AEREL",  tgt_var = "AEREL", id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "IT.AEACN",  tgt_var = "AEACN", id_vars = oak_id_vars()) %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "AEOUTCOME", tgt_var = "AEOUT", id_vars = oak_id_vars()) %>%
  # seriousness criteria: "Y" when "Yes", otherwise null
  hardcode_no_ct(raw_dat = condition_add(ae_raw, IT.AESDTH == "Yes"),
                 raw_var = "IT.AESDTH", tgt_var = "AESDTH", tgt_val = "Y", id_vars = oak_id_vars()) %>%
  hardcode_no_ct(raw_dat = condition_add(ae_raw, IT.AESHOSP == "Yes"),
                 raw_var = "IT.AESHOSP", tgt_var = "AESHOSP", tgt_val = "Y", id_vars = oak_id_vars()) %>%
  hardcode_no_ct(raw_dat = condition_add(ae_raw, IT.AESLIFE == "Yes"),
                 raw_var = "IT.AESLIFE", tgt_var = "AESLIFE", tgt_val = "Y", id_vars = oak_id_vars()) %>%
  # dates
  assign_datetime(raw_dat = ae_raw, raw_var = "IT.AESTDAT", tgt_var = "AESTDTC",
                  raw_fmt = list(c("m/d/y", "y")), id_vars = oak_id_vars()) %>%
  assign_datetime(raw_dat = ae_raw, raw_var = "IT.AEENDAT", tgt_var = "AEENDTC",
                  raw_fmt = list(c("m/d/y", "y")), id_vars = oak_id_vars()) %>%
  mutate(AESEV = toupper(AESEV), AEOUT = toupper(AEOUT),
         AEREL = toupper(AEREL), AEACN = toupper(AEACN))

# Identifiers: join the raw columns back by the lineage keys, then derive
ae_SDTM <- ae_SDTM %>%
  left_join(ae_raw %>% select(oak_id, raw_source, patient_number, STUDY, PATNUM),
            by = c("oak_id", "raw_source", "patient_number")) %>%
  mutate(STUDYID = STUDY,                          # or the STUDYID object from 00_common.R
         DOMAIN  = "AE",
         USUBJID = make_usubjid(PATNUM),
         SITEID  = sub("-.*$", "", PATNUM)) %>%    # "701-1015" -> "701"
  select(-STUDY, -PATNUM) %>%
  derive_seq(tgt_var = "AESEQ", rec_vars = c("USUBJID", "AETERM", "AESTDTC"))

#how vars were defined

spec_ae <- make_spec(ae_SDTM, ae_raw, "RAW_AE")
# 16 to derive manually

spec_ae <- set_spec_manually(spec_ae, "STUDYID", "Collected", "STUDY",      "Direct map")
spec_ae <- set_spec_manually(spec_ae, "DOMAIN",  "Assigned",  NA,           "Constant AE")
spec_ae <- set_spec_manually(spec_ae, "USUBJID", "Derived",   "PATNUM",     "01- + PATNUM (make_usubjid)")
spec_ae <- set_spec_manually(spec_ae, "SITEID",  "Derived",   "PATNUM",     "Text before - in PATNUM")
spec_ae <- set_spec_manually(spec_ae, "AESEQ",   "Derived",   NA,           "derive_seq by USUBJID, AETERM, AESTDTC")
spec_ae <- set_spec_manually(spec_ae, "AETERM",  "Collected", "IT.AETERM",  "assign_no_ct")
spec_ae <- set_spec_manually(spec_ae, "AESEV",   "Collected", "IT.AESEV",   "assign_no_ct + toupper")
spec_ae <- set_spec_manually(spec_ae, "AESER",   "Collected", "IT.AESER",   "assign_ct, codelist C66742 (Yes->Y, No->N)")
spec_ae <- set_spec_manually(spec_ae, "AEREL",   "Collected", "IT.AEREL",   "assign_no_ct + toupper")
spec_ae <- set_spec_manually(spec_ae, "AEACN",   "Collected", "IT.AEACN",   "assign_no_ct + toupper")
spec_ae <- set_spec_manually(spec_ae, "AEOUT",   "Collected", "AEOUTCOME",  "assign_no_ct + toupper")
spec_ae <- set_spec_manually(spec_ae, "AESDTH",  "Derived",   "IT.AESDTH",  "Y if Yes, else null")
spec_ae <- set_spec_manually(spec_ae, "AESHOSP", "Derived",   "IT.AESHOSP", "Y if Yes, else null")
spec_ae <- set_spec_manually(spec_ae, "AESLIFE", "Derived",   "IT.AESLIFE", "Y if Yes, else null")
spec_ae <- set_spec_manually(spec_ae, "AESTDTC", "Collected", "IT.AESTDAT", "assign_datetime, ISO 8601, partial dates kept")
spec_ae <- set_spec_manually(spec_ae, "AEENDTC", "Collected", "IT.AEENDAT", "assign_datetime, ISO 8601, partial dates kept")

#load into database


register_domain(db, run, raw = ae_raw, sdtm = ae_SDTM, spec = spec_ae,
                domain = "AE", script = "03_SDTM_ae.R")
