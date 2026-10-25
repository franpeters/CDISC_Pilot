#generic packages
library(DBI)
library(dplyr)
library(tidyr)
library(lubridate)
library(gt)

# CDISC analysis packages
library(sdtm.oak)
library(pharmaverseraw)

source("R/common_functions.R")
source("R/database_functions.R")


# read in the controlled terminology provided by the sdtm.oak R package
study_ct <- read.csv(system.file("raw_data/sdtm_ct.csv", package = "sdtm.oak"))

# one term is missing so derive this first
# (not ideal but this pipeline is for demo purposes)
study_ct <- study_ct %>% add_row(codelist_code = "C66742", term_code = "C49487",
                                 term_value = "N", collected_value = "No", term_preferred_term = "No", term_synonyms = "No")

db  <- dbConnect(RSQLite::SQLite(), "SDTM_study.sqlite")

# creates the required metadata tables in the database
run <- start_run(db)  

#load raw data
raw=data(package = "pharmaverseraw")

#Adverse Events Raw Dataset
ae_raw <- pharmaverseraw::ae_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM",
                       raw_src = "ae_raw")   

# Demographics Raw Dataset  
dm_raw <- pharmaverseraw::dm_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "dm_raw") 

#Exposure as Collected Raw Dataset
ec_raw <- pharmaverseraw::ec_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "ec_raw") 

#Vital Signs Raw Dataset
vs_raw<- pharmaverseraw::vs_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "vs_raw") 


# inspect the datasets
for (d in list(dm_raw, ec_raw, vs_raw)) { print(names(d)); print(head(d, 3)); cat("\n") }

# create the USUBJIDs
src <- list(AE = pharmaverseraw::ae_raw, DM = dm_raw, EC = ec_raw, VS = vs_raw)
sapply(src, function(d) mean(make_usubjid(d$PATNUM) %in% pharmaversesdtm::dm$USUBJID))

