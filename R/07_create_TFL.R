library(ggplot2)
dir.create("output", showWarnings = FALSE)

# inputs: read from the database 
adsl <- dbReadTable(db, "ADAM_ADSL") %>% mutate(across(c(TRTSDT, TRTEDT), ymd))
ae   <- dbReadTable(db, "SDTM_AE")
saf  <- adsl %>% filter(SAFFL == "Y")                    # safety population
N    <- saf %>% count(TRT01A, name = "N")                # denominator for every percentage

#Turn "2013", "2013-05" or "2013-05-12" into a Date, using the latest possible day
parse_late <- function(x) {
  len <- nchar(x)
  case_when(
    len == 10 ~ ymd(x, quiet = TRUE),
    len == 7  ~ ceiling_date(ymd(paste0(x, "-01"), quiet = TRUE), "month") - days(1),
    len == 4  ~ ymd(paste0(x, "-12-31"), quiet = TRUE)
  )
}

teae <- ae %>%
  inner_join(saf %>% select(USUBJID, TRT01A, TRTSDT, TRTEDT), by = "USUBJID") %>%
  mutate(ast_late = parse_late(AESTDTC)) %>%
  filter(is.na(ast_late) | (ast_late >= TRTSDT & (is.na(TRTEDT) | ast_late <= TRTEDT + 30)))

# Table 1: demographics (age and sex by arm) 
t1 <- bind_rows(
  saf %>% group_by(TRT01A) %>%
    summarise(cell = sprintf("%.1f (%.1f)", mean(AGE), sd(AGE)), .groups = "drop") %>%
    mutate(row = "Age, mean (SD)"),
  saf %>% count(TRT01A, SEX) %>% left_join(N, by = "TRT01A") %>%
    transmute(row = paste("Sex:", SEX), TRT01A, cell = sprintf("%d (%.1f%%)", n, 100 * n / N))) %>%
  select(row, TRT01A, cell) %>%
  pivot_wider(names_from = TRT01A, values_from = cell, values_fill = "0 (0.0%)")

# AE counts: subjects (not events) per preferred term and arm 
ae_pt <- teae %>% distinct(USUBJID, TRT01A, AEDECOD) %>%
  count(TRT01A, AEDECOD) %>% left_join(N, by = "TRT01A") %>% mutate(pct = 100 * n / N)
top10 <- ae_pt %>% group_by(AEDECOD) %>% summarise(tot = sum(n), .groups = "drop") %>%
  slice_max(tot, n = 10, with_ties = FALSE)

# Table 2: top 10 TEAEs, n (%) of subjects 
t2 <- ae_pt %>% inner_join(top10, by = "AEDECOD") %>%
  transmute(AEDECOD, tot, TRT01A, cell = sprintf("%d (%.1f%%)", n, pct)) %>%
  pivot_wider(names_from = TRT01A, values_from = cell, values_fill = "0 (0.0%)") %>%
  arrange(desc(tot)) %>% select(-tot)

# Figure data (registered so each figure has lineage too) 
f1 <- saf %>% select(USUBJID, TRT01A, AGE)
f2 <- ae_pt %>% inner_join(top10, by = "AEDECOD") %>% select(TRT01A, AEDECOD, n, N, pct)%>%
  rename(total_N=N)

# Figure 1: age distribution by arm 
fig1 <- ggplot(f1, aes(TRT01A, AGE, fill = TRT01A)) +
  geom_boxplot(show.legend = FALSE) +
  labs(title = "Figure 1. Age by treatment arm", subtitle = "Safety population",
       x = NULL, y = "Age (years)") + theme_bw()
ggsave("output/F1_age_by_arm.png", fig1, width = 6, height = 4, dpi = 150)

# Figure 2: top 10 TEAEs by arm 
fig2 <- ggplot(f2, aes(pct, reorder(AEDECOD, pct, sum), fill = TRT01A)) +
  geom_col(position = "dodge") +
  labs(title = "Figure 2. Top 10 treatment-emergent AEs", subtitle = "% of safety population",
       x = "% of subjects", y = NULL, fill = NULL) + theme_bw()
ggsave("output/F2_top_teae.png", fig2, width = 7, height = 4.5, dpi = 150)

# Register tables and figure data in the database 

register_dataset(db, t1, "TFL", "T1_DEMOG", run,
                 sources = "ADAM_ADSL", script = "07_tfl.R",
                 description = "Demographics: age and sex by arm")

register_dataset(db, t2, "TFL", "T2_TOP_AE", run,
                 sources = c("ADAM_ADSL", "SDTM_AE"), script = "07_tfl.R",
                 description = "Top 10 TEAEs by preferred term, n (%) of subjects")

register_dataset(db, f1, "TFL", "F1_DATA", run,
                 sources = "ADAM_ADSL", script = "07_tfl.R",
                 description = "Data behind Figure 1 (age by arm)")

register_dataset(db, f2, "TFL", "F2_DATA", run,
                 sources = c("ADAM_ADSL", "SDTM_AE"), script = "07_tfl.R",
                 description = "Data behind Figure 2 (top 10 TEAEs by arm)")

cat("TFL done: 2 tables in the database, 2 figures in output/")

