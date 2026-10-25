library(DBI)
library(tidyverse)

# Timestamped log line
say <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")

# TRUE for Date and POSIXt columns (SQLite has no date type, so these become text)
is_date <- function(x) inherits(x, c("Date", "POSIXt"))

# Replace the old rows  in a metadata table, then append the new rows
save_meta <- function(db, table, df, key_col, key_val) {
  if (dbExistsTable(db, table))
    dbExecute(db, paste0("DELETE FROM ", table, " WHERE ", key_col, " = ?"), params = list(key_val))
  if (nrow(df) > 0) dbWriteTable(db, table, df, append = TRUE)
}

# Start a run: record the time and package versions
start_run <- function(db) {
  run_id <- format(Sys.time(), "%Y%m%d%H%M%S")
  pkgs   <- c("admiral", "sdtm.oak", "dplyr", "DBI", "RSQLite")
  vers   <- sapply(pkgs, function(p) tryCatch(as.character(packageVersion(p)),
                                              error = function(e) "not installed"))
  
  df <- data.frame(run_id    = run_id,
                   run_ts    = as.character(Sys.time()),
                   r_version = R.version.string,
                   pkgs      = paste(pkgs, vers, sep = "=", collapse = ";"))
  save_meta(db, "META_RUN", df, "run_id", run_id)
  
  say("Started run ", run_id)
  run_id
}

# Write a data frame to SQLite and record its lineage (table name = LAYER_name, e.g. SDTM_AE)
#   sources : tables it was built from
#   spec    : optional data frame (variable, origin, source_table, source_variable, derivation)
register_dataset <- function(db, df, layer, name, run_id, sources = character(),
                             script = NA_character_, description = NA_character_, spec = NULL) {
  tbl <- paste0(layer, "_", name)
  say("---- ", tbl, " ----")
  stopifnot(is.data.frame(df), !tbl %in% sources)
  
  # 1. Data
  #store date as a character - not ideal but ran out of time to tidy up the logic
  df <- df %>% as.data.frame() %>% mutate(across(where(is_date), as.character))
  dbWriteTable(db, tbl, df, overwrite = TRUE)
  say("  wrote ", nrow(df), " rows x ", ncol(df), " cols")
  
  # 2. Table-level metadata (using the hash detects changes between runs)
  meta <- data.frame(table_name = tbl, run_id = run_id, layer = layer, dataset = name,
                     description = description, n_rows = nrow(df), n_cols = ncol(df),
                     content_hash = digest::digest(df), script = script,
                     created_ts = as.character(Sys.time()))
  save_meta(db, "META_DATASET", meta, "table_name", tbl)
  
  # 3. Lineage edges: one row per source table (none for a root table)
  source_not_yet <- setdiff(sources, dbListTables(db))
  if (length(source_not_yet) > 0) say("  WARNING: source not in database yet: ", paste(not_yet, collapse = ", "))
  edges <- data.frame(target_table = character(), source_table = character(), script = character())
  if (length(sources) > 0)
    edges <- data.frame(target_table = tbl, source_table = sources, script = script)
  save_meta(db, "META_LINEAGE_DATASET", edges, "target_table", tbl)
  say("  lineage: ", if (length(sources) == 0) "no sources (root table)"
      else paste(paste(sources, collapse = ", "), "->", tbl))
  
  # 4. Variable metadata: always all five spec columns, so META_VARIABLE keeps one layout
  spec_cols <- c("variable", "origin", "source_table", "source_variable", "derivation")
  if (is.null(spec)) spec <- data.frame(variable = character())
  spec <- as.data.frame(spec)
  for (col in setdiff(spec_cols, names(spec))) spec[[col]] <- rep(NA_character_, nrow(spec))
  spec <- spec[, spec_cols]
  spec[] <- lapply(spec, as.character)
  
  vars <- data.frame(table_name = tbl,
                     variable   = names(df),
                     type       = sapply(df, function(x) class(x)[1]),
                     row.names  = NULL)
  vars <- left_join(vars, spec, by = "variable")
  
  extra <- setdiff(spec$variable, vars$variable)
  say("  spec covers ", sum(vars$variable %in% spec$variable), " of ", nrow(vars), " variables")
  if (length(extra) > 0) say("  WARNING: in spec but not in data: ", paste(extra, collapse = ", "))
  save_meta(db, "META_VARIABLE", vars, "table_name", tbl)
  
  invisible(tbl)
}

# Fill the repetitive spec rows; stop if any variable still has no origin
finalise_spec <- function(spec) {
  todo <- spec$variable[is.na(spec$origin)]
  if (length(todo) > 0) stop("spec has no origin for: ", paste(todo, collapse = ", "))
  
  spec %>% mutate(
    derivation = case_when(
      !is.na(derivation)      ~ derivation,
      origin == "Lineage key" ~ paste("sdtm.oak lineage key, links to", source_table),
      origin == "Collected"   ~ "Direct map"),
    source_variable = if_else(origin == "Lineage key", variable, source_variable))
}

# Register the raw and SDTM tables together and save the spec as a CSV
register_domain <- function(db, run, raw, sdtm, spec, domain, script, extra_sources = character()) {
  spec <- finalise_spec(spec)
  write_csv(spec, file.path("spec", paste0(tolower(domain), "_sdtm_spec.csv")))
  
  register_dataset(db, raw, "RAW", domain, run, script = script)
  register_dataset(db, as.data.frame(sdtm)[, spec$variable], "SDTM", domain, run,
                   sources = c(paste0("RAW_", domain), extra_sources), script = script, spec = spec)
}

# Print everything upstream of a table as an indented tree
show_lineage <- function(db, tbl) {
  res <- dbGetQuery(db, "
    WITH RECURSIVE up(tbl, depth) AS (
      SELECT ?, 0
      UNION ALL
      SELECT l.source_table, up.depth + 1
      FROM META_LINEAGE_DATASET l JOIN up ON l.target_table = up.tbl)
    SELECT tbl, MIN(depth) AS depth FROM up GROUP BY tbl ORDER BY depth, tbl",
                    params = list(tbl))
  for (i in seq_len(nrow(res))) say("  ", strrep("  ", res$depth[i]), res$tbl[i])
}