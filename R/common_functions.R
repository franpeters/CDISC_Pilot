
make_usubjid <- function(patnum) paste0("01-", patnum)   # raw PATNUM "701-1015" -> "01-701-1015"

to_iso <- function(x) {
  if (inherits(x, c("Date", "POSIXt"))) return(format(x, "%Y-%m-%d"))
  x <- trimws(as.character(x))
  full <- suppressWarnings(
    lubridate::parse_date_time(x, orders = c("mdY HMS", "mdY HM", "mdY",
                                             "Ymd HMS", "Ymd HM", "Ymd", "dbY"),
                               quiet = TRUE))
  dplyr::case_when(
    is.na(x) | x == ""   ~ NA_character_,
    grepl("^\\d{4}$", x) ~ x,                         # year only, kept as a partial date
    TRUE                 ~ format(full, "%Y-%m-%d"))
}

make_spec <- function(df, raw, src_table) {
  keys <- c("oak_id", "raw_source", "patient_number")
  spec <- data.frame(variable = names(df), origin = NA_character_,
                     source_table = src_table, source_variable = NA_character_,
                     derivation = NA_character_, stringsAsFactors = FALSE)
  
  # same name exists in the raw data -> Collected, direct map
  same <- spec$variable %in% names(raw)
  spec$origin[same]          <- "Collected"
  spec$source_variable[same] <- spec$variable[same]
  
  # lineage keys
  k <- spec$variable %in% keys
  spec$origin[k] <- "Lineage key"
  
  # everything still blank needs a human
  todo <- is.na(spec$origin)
  say(sum(same), " auto-matched, ", sum(k), " lineage keys, ", sum(todo), " to fill by hand: ",
      paste(spec$variable[todo], collapse = ", "))
  spec
}

set_spec_manually <- function(spec, var, origin, source = NA, how = NA) {
  i <- match(var, spec$variable)
  if (is.na(i)) stop(var, " not in spec")
  spec$origin[i] <- origin; spec$source_variable[i] <- source; spec$derivation[i] <- how
  spec
}
