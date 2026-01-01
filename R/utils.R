# ==============================================================================
# Utility Functions
# ==============================================================================

#' @importFrom rlang .data
NULL


#' Convert to numeric, handling suppression markers
#'
#' NC DPI uses various markers for suppressed data (*, <, >, etc.)
#' and may use commas in large numbers.
#'
#' @param x Vector to convert
#' @return Numeric vector with NA for non-numeric values
#' @keywords internal
safe_numeric <- function(x) {
  if (is.numeric(x)) return(x)

  # Convert to character if factor
  x <- as.character(x)

  # Remove commas and whitespace
  x <- gsub(",", "", x)
  x <- trimws(x)


  # Handle common suppression markers
  x[x %in% c("*", ".", "-", "-1", "<5", "<10", ">95", "N/A", "NA", "", "null")] <- NA_character_
  x[grepl("^<|^>|^\\*", x)] <- NA_character_

  suppressWarnings(as.numeric(x))
}


#' Clean and standardize LEA/school names
#'
#' @param x Character vector of names
#' @return Cleaned character vector
#' @keywords internal
clean_name <- function(x) {
  x <- trimws(x)
  # Standardize common abbreviations
  x <- gsub("\\s+", " ", x)  # Collapse multiple spaces
  x
}


#' Validate school year
#'
#' @param end_year School year end
#' @param min_year Minimum valid year
#' @param max_year Maximum valid year
#' @return TRUE if valid, otherwise throws error
#' @keywords internal
validate_year <- function(end_year, min_year = 2006, max_year = 2025) {
  if (!is.numeric(end_year) || length(end_year) != 1)
    stop("end_year must be a single numeric value")

  if (end_year < min_year || end_year > max_year) {
    stop(paste0(
      "Year ", end_year, " not available. ",
      "Available years: ", min_year, "-", max_year
    ))
  }

  TRUE
}
