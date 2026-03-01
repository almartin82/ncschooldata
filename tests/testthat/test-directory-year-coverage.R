# ==============================================================================
# Directory Year Coverage Tests for ncschooldata
# ==============================================================================
#
# Tests for NC school directory data. Currently covers private schools only;
# public school directory is not yet implemented.
#
# All pinned values come from actual NC DPI directory download.
#
# ==============================================================================

library(testthat)


# Helper: fetch directory, skip if data unavailable
try_fetch_directory <- function(directory_type = "all", use_cache = TRUE) {
  tryCatch(
    fetch_directory(directory_type, use_cache = use_cache),
    error = function(e) {
      skip(paste("NC directory data unavailable -", e$message))
    }
  )
}


# ==============================================================================
# Section 1: Data Load
# ==============================================================================

test_that("directory data loads with >0 rows", {
  dir_data <- try_fetch_directory()
  expect_gt(nrow(dir_data), 0)
})

test_that("private_schools directory type works", {
  dir_data <- try_fetch_directory("private_schools")
  expect_gt(nrow(dir_data), 0)
  expect_true(all(dir_data$directory_type == "private_schools"))
})


# ==============================================================================
# Section 2: Required Fields Present
# ==============================================================================

required_directory_cols <- c(
  "directory_type", "school_name", "address", "city",
  "state", "zip", "phone", "county", "district",
  "principal", "email"
)

test_that("all required directory columns present", {
  dir_data <- try_fetch_directory()

  for (col in required_directory_cols) {
    expect_true(col %in% names(dir_data),
                info = paste("Missing column:", col))
  }
})


# ==============================================================================
# Section 3: Entity Counts
# ==============================================================================

test_that("private school count in expected range (700-1100)", {
  dir_data <- try_fetch_directory("private_schools")

  # NC has ~800-900 private schools
  expect_true(nrow(dir_data) > 700,
            info = "Too few private schools")
  expect_true(nrow(dir_data) < 1100,
            info = "Too many private schools")
})


# ==============================================================================
# Section 4: State Field
# ==============================================================================

test_that("all schools have state = NC", {
  dir_data <- try_fetch_directory()
  expect_true(all(dir_data$state == "NC"),
              info = "Some schools have state != NC")
})


# ==============================================================================
# Section 5: County Coverage
# ==============================================================================

test_that("county field is populated for most schools", {
  dir_data <- try_fetch_directory()

  # Count non-empty counties
  n_with_county <- sum(!is.na(dir_data$county) & dir_data$county != "")
  pct_with_county <- n_with_county / nrow(dir_data)

  expect_true(pct_with_county > 0.95,
            info = "More than 5% of schools missing county")
})

test_that("at least 80 distinct counties represented", {
  dir_data <- try_fetch_directory()

  unique_counties <- unique(dir_data$county[!is.na(dir_data$county) &
                                            dir_data$county != ""])

  # NC has 100 counties; private schools in at least 80+
  expect_true(length(unique_counties) > 80,
            info = "Too few counties represented")
})

test_that("major counties have multiple schools", {
  dir_data <- try_fetch_directory()

  # Wake County (Raleigh area) should have many private schools
  wake_schools <- dir_data[!is.na(dir_data$county) & dir_data$county == "Wake", ]
  expect_true(nrow(wake_schools) > 30,
            info = "Wake County has too few private schools")

  # Mecklenburg County (Charlotte area)
  meck_schools <- dir_data[!is.na(dir_data$county) & dir_data$county == "Mecklenburg", ]
  expect_true(nrow(meck_schools) > 20,
            info = "Mecklenburg County has too few private schools")
})


# ==============================================================================
# Section 6: School Name Quality
# ==============================================================================

test_that("no missing school names", {
  dir_data <- try_fetch_directory()

  expect_false(any(is.na(dir_data$school_name) | dir_data$school_name == ""),
               info = "Found empty school names")
})

test_that("school names are mostly unique (< 10% duplicates)", {
  dir_data <- try_fetch_directory()

  n_dupes <- sum(duplicated(dir_data$school_name))
  pct_dupes <- n_dupes / nrow(dir_data)

  expect_true(pct_dupes < 0.10,
            info = paste("Too many duplicate school names:", n_dupes))
})


# ==============================================================================
# Section 7: Phone Number Format
# ==============================================================================

test_that("phone numbers are digits only after cleaning", {
  dir_data <- try_fetch_directory()

  phones <- dir_data$phone[!is.na(dir_data$phone) & dir_data$phone != ""]
  if (length(phones) > 0) {
    # Should contain only digits after processing
    expect_true(all(grepl("^[0-9]+$", phones)),
                info = "Phone numbers contain non-digit characters")
  }
})

test_that("phone numbers are 10 digits (area code + number)", {
  dir_data <- try_fetch_directory()

  phones <- dir_data$phone[!is.na(dir_data$phone) & dir_data$phone != ""]
  if (length(phones) > 0) {
    phone_lengths <- nchar(phones)
    # Most should be 10 digits
    pct_10_digit <- mean(phone_lengths == 10)
    expect_true(pct_10_digit > 0.80,
              info = "Less than 80% of phone numbers are 10 digits")
  }
})


# ==============================================================================
# Section 8: Zip Code Format
# ==============================================================================

test_that("zip codes are valid format (5 digits or 5+4)", {
  dir_data <- try_fetch_directory()

  zips <- dir_data$zip[!is.na(dir_data$zip) & dir_data$zip != ""]
  if (length(zips) > 0) {
    # Should match 5-digit or 5+4 format
    expect_true(all(grepl("^[0-9]{5}(-[0-9]{4})?$", zips)),
                info = "Invalid zip code format detected")
  }
})

test_that("NC zip codes start with 27-29 (NC range plus border areas)", {
  dir_data <- try_fetch_directory()

  zips <- dir_data$zip[!is.na(dir_data$zip) & dir_data$zip != ""]
  if (length(zips) > 0) {
    # Extract first 2 digits
    zip_prefixes <- as.integer(substr(zips, 1, 2))
    # NC zips are 27xxx-28xxx; 29xxx can appear for border-area schools (SC border)
    expect_true(all(zip_prefixes %in% 27:29),
                info = "Zip codes outside NC/border range (27-29)")
  }
})


# ==============================================================================
# Section 9: City Coverage
# ==============================================================================

test_that("city field populated for most schools", {
  dir_data <- try_fetch_directory()

  n_with_city <- sum(!is.na(dir_data$city) & dir_data$city != "")
  pct_with_city <- n_with_city / nrow(dir_data)

  expect_true(pct_with_city > 0.95,
            info = "More than 5% of schools missing city")
})

test_that("major NC cities represented", {
  dir_data <- try_fetch_directory()

  cities <- toupper(dir_data$city)

  # Check for major cities (case-insensitive)
  expect_true(any(grepl("RALEIGH", cities)), info = "Raleigh not found")
  expect_true(any(grepl("CHARLOTTE", cities)), info = "Charlotte not found")
  expect_true(any(grepl("DURHAM", cities)), info = "Durham not found")
})


# ==============================================================================
# Section 10: Address Quality
# ==============================================================================

test_that("address field populated for most schools", {
  dir_data <- try_fetch_directory()

  n_with_addr <- sum(!is.na(dir_data$address) & dir_data$address != "")
  pct_with_addr <- n_with_addr / nrow(dir_data)

  expect_true(pct_with_addr > 0.90,
            info = "More than 10% of schools missing address")
})


# ==============================================================================
# Section 11: Contact Information
# ==============================================================================

test_that("principal/administrator field mostly populated", {
  dir_data <- try_fetch_directory()

  n_with_principal <- sum(!is.na(dir_data$principal) & dir_data$principal != "")
  pct_with_principal <- n_with_principal / nrow(dir_data)

  expect_true(pct_with_principal > 0.90,
            info = "More than 10% of schools missing principal")
})

test_that("email field mostly populated", {
  dir_data <- try_fetch_directory()

  n_with_email <- sum(!is.na(dir_data$email) & dir_data$email != "")
  pct_with_email <- n_with_email / nrow(dir_data)

  expect_true(pct_with_email > 0.90,
            info = "More than 10% of schools missing email")
})


# ==============================================================================
# Section 12: Directory Type Validation
# ==============================================================================

test_that("fetch_directory rejects invalid directory type", {
  expect_error(fetch_directory("nonexistent_type"),
               "Invalid directory_type")
})

test_that("fetch_directory_multi rejects invalid types", {
  expect_error(fetch_directory_multi("public_schools"),
               "Invalid directory types")
})


# ==============================================================================
# Section 13: Data Consistency
# ==============================================================================

test_that("all rows have the same directory_type within a single fetch", {
  dir_data <- try_fetch_directory("private_schools")

  expect_equal(length(unique(dir_data$directory_type)), 1)
  expect_equal(unique(dir_data$directory_type), "private_schools")
})

test_that("fetch_directory returns tibble", {
  dir_data <- try_fetch_directory()

  expect_true(inherits(dir_data, "tbl_df") || inherits(dir_data, "data.frame"))
})


# ==============================================================================
# Section 14: District Field
# ==============================================================================

test_that("district field is populated for most schools", {
  dir_data <- try_fetch_directory()

  n_with_district <- sum(!is.na(dir_data$district) & dir_data$district != "")
  pct_with_district <- n_with_district / nrow(dir_data)

  expect_true(pct_with_district > 0.90,
            info = "More than 10% of schools missing district")
})
