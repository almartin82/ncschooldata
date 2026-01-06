# ==============================================================================
# Directory Data Processing Functions
# ==============================================================================
#
# This file contains functions for processing raw directory data from the
# North Carolina Department of Public Instruction (NCDPI) into a standard format.
#
# ==============================================================================

#' Process raw directory data
#'
#' Processes the raw school directory data into a standardized format.
#'
#' @param raw_data List of raw data frames from get_raw_directory()
#' @return Data frame with standardized columns
#' @keywords internal
process_directory <- function(raw_data) {

  # Process each directory type and combine
  processed <- lapply(names(raw_data), function(type) {
    df <- raw_data[[type]]

    # Standardize column names (convert to lowercase for matching)
    names(df) <- tolower(names(df))

    # Create a result data frame with all required columns
    n_rows <- nrow(df)
    result <- data.frame(
      directory_type = rep(type, n_rows),
      school_name = NA_character_,
      address = NA_character_,
      city = NA_character_,
      state = rep("NC", n_rows),
      zip = NA_character_,
      phone = NA_character_,
      county = NA_character_,
      district = NA_character_,
      principal = NA_character_,
      email = NA_character_,
      stringsAsFactors = FALSE
    )

    # Map columns based on NC Excel structure
    # NC uses descriptive column names (with embedded newlines)
    col_map <- list(
      school_name = c("school Name", "school", "name"),
      district = c("district", "school district"),
      county = c("county", "county name"),
      address = c("mailing  Street Address", "mailing street address", "address", "street address"),
      city = c("mailing City", "city"),
      state = c("mailing State", "state"),
      zip = c("mailing Zip", "zip", "zip code"),
      phone = c("phone", "telephone"),
      principal = c("administrator", "principal", "contact person"),
      email = c("email", "email address", "e-mail")
    )

    # Map columns
    for (std_col in names(col_map)) {
      for (pattern in col_map[[std_col]]) {
        matched <- grep(pattern, names(df), ignore.case = TRUE)
        if (length(matched) > 0) {
          result[[std_col]] <- as.character(df[[matched[1]]])
          break
        }
      }
    }

    # Remove rows with missing school name (essential field)
    # Also remove separator rows (where school_name is ".")
    if ("school_name" %in% names(result)) {
      result <- result[!is.na(result$school_name) &
                       result$school_name != "" &
                       result$school_name != ".", , drop = FALSE]
    }

    # Clean up phone numbers (remove common formatting)
    if ("phone" %in% names(result)) {
      result$phone <- gsub("[^0-9]", "", result$phone)
    }

    # Clean up zip codes (remove any non-numeric characters except for trailing 4 digit zip+4)
    if ("zip" %in% names(result)) {
      result$zip <- gsub("[^0-9-]", "", result$zip)
    }

    # Convert to tibble
    tibble::as_tibble(result)
  })

  # Combine all directory types
  combined <- dplyr::bind_rows(processed)

  # Select only columns that exist
  available_cols <- intersect(c("directory_type", "school_name", "address", "city",
                               "state", "zip", "phone", "county", "district",
                               "principal", "email"),
                             names(combined))

  combined <- combined[, available_cols, drop = FALSE]

  combined
}
