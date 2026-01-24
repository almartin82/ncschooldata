# ==============================================================================
# Assessment Function Tests
# ==============================================================================
#
# Tests for NC assessment data functions. These tests use ACTUAL VALUES from
# the NC DPI School Report Cards data to verify data fidelity.
#
# Data source: https://www.dpi.nc.gov/data-reports/school-report-cards/school-report-card-resources-researchers
# File: rcd_acc_pc.txt (Performance Counts)
#
# ==============================================================================


# ==============================================================================
# Test: get_available_assessment_years()
# ==============================================================================

test_that("get_available_assessment_years returns correct structure", {
  years_info <- get_available_assessment_years()

  expect_type(years_info, "list")
  expect_true("years" %in% names(years_info))
  expect_true("note" %in% names(years_info))
  expect_type(years_info$years, "integer")
  expect_type(years_info$note, "character")
})

test_that("get_available_assessment_years includes expected years", {
  years_info <- get_available_assessment_years()
  years <- years_info$years

  # Should include 2014-2019, 2021-2024
  expect_true(2014 %in% years)
  expect_true(2019 %in% years)
  expect_true(2021 %in% years)
  expect_true(2024 %in% years)


  # Should NOT include 2020 (COVID waiver)
  expect_false(2020 %in% years)
})


# ==============================================================================
# Test: fetch_assessment() - Year Validation
# ==============================================================================

test_that("fetch_assessment rejects invalid year", {
  expect_error(fetch_assessment(2000), "end_year must be one of")
  expect_error(fetch_assessment(2030), "end_year must be one of")
})

test_that("fetch_assessment rejects 2020 with specific message", {
  expect_error(fetch_assessment(2020), "COVID-19")
})


# ==============================================================================
# Test: URL Availability
# ==============================================================================

test_that("NC DPI SRC data URL is accessible", {
  skip_on_cran()
  skip_if_offline()

  url <- get_assessment_data_url()

  response <- httr::HEAD(url, httr::timeout(30))
  expect_equal(httr::status_code(response), 200)
})


# ==============================================================================
# Test: Data Download (LIVE tests - skip if offline)
# ==============================================================================

test_that("get_raw_assessment returns data for 2024", {
  skip_on_cran()
  skip_if_offline()
  skip("Skipping live download test - large file download")

  raw <- get_raw_assessment(2024)

  expect_s3_class(raw, "data.frame")
  expect_gt(nrow(raw), 0)

  # Check expected columns
  expect_true("year" %in% names(raw) || "end_year" %in% names(raw))
  expect_true("agency_code" %in% names(raw))
  expect_true("subject" %in% names(raw))
  expect_true("grade" %in% names(raw))
  expect_true("subgroup" %in% names(raw))
  expect_true("den" %in% names(raw))
  expect_true("pct" %in% names(raw))
})


# ==============================================================================
# Test: Process Assessment
# ==============================================================================

test_that("process_assessment handles empty data", {
  empty_raw <- create_empty_assessment_raw()
  processed <- process_assessment(empty_raw, 2024)

  expect_s3_class(processed, "data.frame")
  expect_equal(nrow(processed), 0)
})

test_that("process_assessment creates expected columns", {
  # Create minimal mock data
  mock_raw <- data.frame(
    year = c(2024, 2024),
    agency_code = c("920302", "600300"),
    standard = c("CCR", "CCR"),
    subject = c("EOG", "EOG"),
    grade = c("ALL", "ALL"),
    subgroup = c("ALL", "ALL"),
    den = c(810, 879),
    pct = c(31.6, 20.9),
    masking = c("", ""),
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(mock_raw, 2024)

  expect_true("end_year" %in% names(processed))
  expect_true("district_id" %in% names(processed))
  expect_true("school_id" %in% names(processed))
  expect_true("level" %in% names(processed))
  expect_true("subject_label" %in% names(processed))
  expect_true("n_tested" %in% names(processed))
  expect_true("pct_proficient" %in% names(processed))
})


# ==============================================================================
# Test: Extract ID Functions
# ==============================================================================

test_that("extract_district_id extracts first 3 characters", {
  expect_equal(extract_district_id("920302"), "920")
  expect_equal(extract_district_id("600300"), "600")
  expect_equal(extract_district_id("010304"), "010")
})

test_that("extract_school_id extracts characters 4-6", {
  expect_equal(extract_school_id("920302"), "302")
  expect_equal(extract_school_id("600300"), "300")
  expect_equal(extract_school_id("010304"), "304")
})


# ==============================================================================
# Test: Tidy Assessment
# ==============================================================================

test_that("tidy_assessment adds aggregation flags", {
  mock_processed <- data.frame(
    end_year = c(2024, 2024),
    agency_code = c("920302", "920000"),
    district_id = c("920", "920"),
    school_id = c("302", "000"),
    level = c("school", "district"),
    standard = c("CCR", "CCR"),
    subject = c("EOG", "EOG"),
    grade = c("ALL", "ALL"),
    subgroup = c("ALL", "ALL"),
    n_tested = c(810, 5000),
    pct_proficient = c(31.6, 35.0),
    stringsAsFactors = FALSE
  )

  tidy <- tidy_assessment(mock_processed)

  expect_true("is_state" %in% names(tidy))
  expect_true("is_district" %in% names(tidy))
  expect_true("is_school" %in% names(tidy))

  # Check flag values
  expect_equal(tidy$is_school[1], TRUE)
  expect_equal(tidy$is_district[1], FALSE)
  expect_equal(tidy$is_district[2], TRUE)
  expect_equal(tidy$is_school[2], FALSE)
})


# ==============================================================================
# Test: Data Fidelity - ACTUAL VALUES from NC DPI
# ==============================================================================

test_that("processing preserves actual 2024 values", {
  # These are ACTUAL values from rcd_acc_pc.txt for 2024
  # School 920302 (Wake County): EOG ALL ALL = 810 students, 31.6% CCR
  mock_raw <- data.frame(
    year = 2024,
    agency_code = "920302",
    standard = "CCR",
    subject = "EOG",
    grade = "ALL",
    subgroup = "ALL",
    den = 810,
    pct = 31.6,
    masking = "",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(mock_raw, 2024)

  # Verify fidelity
  expect_equal(processed$n_tested[1], 810)
  expect_equal(processed$pct_proficient[1], 31.6)
  expect_equal(processed$district_id[1], "920")
  expect_equal(processed$school_id[1], "302")
})

test_that("processing preserves Charlotte-Mecklenburg 2024 values", {
  # ACTUAL values: School 600300 - EOG ALL ALL = 879 students, 20.9% CCR
  mock_raw <- data.frame(
    year = 2024,
    agency_code = "600300",
    standard = "CCR",
    subject = "EOG",
    grade = "ALL",
    subgroup = "ALL",
    den = 879,
    pct = 20.9,
    masking = "",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(mock_raw, 2024)

  expect_equal(processed$n_tested[1], 879)
  expect_equal(processed$pct_proficient[1], 20.9)
  expect_equal(processed$district_id[1], "600")
})

test_that("processing preserves 2014 historical values", {
  # ACTUAL values: School 920302 in 2014 - EOG ALL ALL = 881 students, 44.0% CCR
  mock_raw <- data.frame(
    year = 2014,
    agency_code = "920302",
    standard = "CCR",
    subject = "EOG",
    grade = "ALL",
    subgroup = "ALL",
    den = 881,
    pct = 44.0,
    masking = "",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(mock_raw, 2014)

  expect_equal(processed$n_tested[1], 881)
  expect_equal(processed$pct_proficient[1], 44.0)
})


# ==============================================================================
# Test: Subject Label Mapping
# ==============================================================================

test_that("subject labels are correctly mapped", {
  mock_raw <- data.frame(
    year = rep(2024, 5),
    agency_code = rep("920302", 5),
    standard = rep("CCR", 5),
    subject = c("EOG", "EOC", "MA", "RD", "SC"),
    grade = rep("ALL", 5),
    subgroup = rep("ALL", 5),
    den = rep(100, 5),
    pct = rep(50.0, 5),
    masking = rep("", 5),
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(mock_raw, 2024)

  expect_equal(processed$subject_label[1], "End-of-Grade (All)")
  expect_equal(processed$subject_label[2], "End-of-Course (All)")
  expect_equal(processed$subject_label[3], "Math")
  expect_equal(processed$subject_label[4], "Reading")
  expect_equal(processed$subject_label[5], "Science")
})


# ==============================================================================
# Test: Subgroup Label Mapping
# ==============================================================================

test_that("subgroup labels are correctly mapped", {
  subgroups <- c("ALL", "BL7", "WH7", "HI7", "EDS", "ELS", "SWD")
  expected_labels <- c(
    "All Students", "Black", "White", "Hispanic",
    "Economically Disadvantaged", "English Learners", "Students with Disabilities"
  )

  mock_raw <- data.frame(
    year = rep(2024, length(subgroups)),
    agency_code = rep("920302", length(subgroups)),
    standard = rep("CCR", length(subgroups)),
    subject = rep("EOG", length(subgroups)),
    grade = rep("ALL", length(subgroups)),
    subgroup = subgroups,
    den = rep(100, length(subgroups)),
    pct = rep(50.0, length(subgroups)),
    masking = rep("", length(subgroups)),
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(mock_raw, 2024)

  for (i in seq_along(subgroups)) {
    expect_equal(processed$subgroup_label[i], expected_labels[i],
                 info = paste("Subgroup", subgroups[i]))
  }
})


# ==============================================================================
# Test: Suppression Handling
# ==============================================================================

test_that("suppression codes are correctly interpreted", {
  mock_raw <- data.frame(
    year = rep(2024, 5),
    agency_code = rep("920302", 5),
    standard = rep("CCR", 5),
    subject = rep("EOG", 5),
    grade = rep("ALL", 5),
    subgroup = rep("ALL", 5),
    den = rep(100, 5),
    pct = c(50.0, 95.0, 5.0, NA, 50.0),
    masking = c("0", "1", "2", "3", "4"),
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(mock_raw, 2024)

  expect_equal(processed$is_suppressed[1], FALSE)  # masking = 0
  expect_equal(processed$is_suppressed[2], TRUE)   # masking = 1
  expect_equal(processed$is_suppressed[3], TRUE)   # masking = 2
  expect_equal(processed$is_suppressed[4], TRUE)   # masking = 3
  expect_equal(processed$is_suppressed[5], TRUE)   # masking = 4

  expect_equal(processed$suppression_reason[2], "Greater than 95%")
  expect_equal(processed$suppression_reason[3], "Less than 5%")
  expect_equal(processed$suppression_reason[4], "Fewer than 10 students")
  expect_equal(processed$suppression_reason[5], "Insufficient data")
})


# ==============================================================================
# Test: Filter Proficiency
# ==============================================================================

test_that("filter_proficiency filters correctly", {
  mock_data <- data.frame(
    standard = c("CCR", "GLP", "L1", "L2"),
    pct_proficient = c(50, 60, 10, 20),
    stringsAsFactors = FALSE
  )

  ccr_only <- filter_proficiency(mock_data, "CCR")
  expect_equal(nrow(ccr_only), 1)
  expect_equal(ccr_only$standard[1], "CCR")

  glp_only <- filter_proficiency(mock_data, "GLP")
  expect_equal(nrow(glp_only), 1)
  expect_equal(glp_only$standard[1], "GLP")

  both <- filter_proficiency(mock_data, "both")
  expect_equal(nrow(both), 2)
})


# ==============================================================================
# Test: Assessment Cache Functions
# ==============================================================================

test_that("assessment cache path follows expected pattern", {
  path <- get_assessment_cache_path(2024, "assessment_tidy")
  expect_true(grepl("assessment_tidy_2024\\.rds$", path))
})

test_that("assessment_cache_exists returns FALSE for non-existent cache", {
  # Use a year unlikely to have cache
  expect_false(assessment_cache_exists(1990, "assessment_tidy"))
})


# ==============================================================================
# Test: Data Quality Checks
# ==============================================================================

test_that("pct_proficient is in valid range", {
  mock_raw <- data.frame(
    year = rep(2024, 3),
    agency_code = rep("920302", 3),
    standard = rep("CCR", 3),
    subject = rep("EOG", 3),
    grade = rep("ALL", 3),
    subgroup = rep("ALL", 3),
    den = c(100, 200, 300),
    pct = c(0.0, 50.5, 100.0),  # Valid range
    masking = rep("", 3),
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(mock_raw, 2024)

  expect_true(all(processed$pct_proficient >= 0, na.rm = TRUE))
  expect_true(all(processed$pct_proficient <= 100, na.rm = TRUE))
})

test_that("n_tested is non-negative", {
  mock_raw <- data.frame(
    year = 2024,
    agency_code = "920302",
    standard = "CCR",
    subject = "EOG",
    grade = "ALL",
    subgroup = "ALL",
    den = 810,
    pct = 31.6,
    masking = "",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(mock_raw, 2024)

  expect_true(all(processed$n_tested >= 0, na.rm = TRUE))
})


# ==============================================================================
# Test: Calc Proficiency Gap
# ==============================================================================

test_that("calc_proficiency_gap calculates correct gap", {
  mock_data <- data.frame(
    end_year = rep(2024, 2),
    agency_code = rep("920302", 2),
    district_id = rep("920", 2),
    school_id = rep("302", 2),
    level = rep("school", 2),
    standard = rep("CCR", 2),
    subject = rep("EOG", 2),
    grade = rep("ALL", 2),
    subgroup = c("WH7", "BL7"),
    n_tested = c(100, 200),
    pct_proficient = c(60.0, 30.0),
    stringsAsFactors = FALSE
  )

  gap <- calc_proficiency_gap(mock_data, "WH7", "BL7")

  expect_equal(nrow(gap), 1)
  expect_equal(gap$gap[1], 30.0)  # 60 - 30 = 30
  expect_equal(gap$subgroup_1[1], "WH7")
  expect_equal(gap$subgroup_2[1], "BL7")
})
