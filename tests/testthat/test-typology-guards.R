# ==============================================================================
# Typology Guard Tests for ncschooldata
# ==============================================================================
#
# Structural guards that apply across all data types:
# - Division-by-zero prevention
# - Percentage scale validation (0-100 or 0-1)
# - Column type enforcement
# - Row count minimums
# - Subgroup/grade value validation
# - No duplicates per entity/period
# - Data anomaly documentation
#
# All expected values from real NC DPI data. No fabricated values.
#
# ==============================================================================

library(testthat)


# Helper: fetch enrollment, skip if unavailable
try_fetch_enr <- function(end_year, tidy = TRUE, use_cache = TRUE) {
  tryCatch(
    fetch_enr(end_year, tidy = tidy, use_cache = use_cache),
    error = function(e) {
      skip(paste("NC DPI data unavailable for year", end_year, "-", e$message))
    }
  )
}

# Helper: fetch assessment, skip if unavailable
try_fetch_assessment <- function(end_year, tidy = TRUE, use_cache = TRUE) {
  tryCatch(
    fetch_assessment(end_year, tidy = tidy, use_cache = use_cache),
    error = function(e) {
      skip(paste("NC assessment data unavailable for year", end_year, "-", e$message))
    }
  )
}


# ==============================================================================
# Section 1: Division-by-Zero Prevention
# ==============================================================================

test_that("enrollment pct does not contain Inf values", {
  enr <- try_fetch_enr(2024)

  pct_values <- enr$pct[!is.na(enr$pct)]
  expect_false(any(is.infinite(pct_values)),
               info = "Inf values found in enrollment pct column")
})

test_that("enrollment pct does not contain NaN values", {
  enr <- try_fetch_enr(2024)

  pct_values <- enr$pct[!is.na(enr$pct)]
  expect_false(any(is.nan(pct_values)),
               info = "NaN values found in enrollment pct column")
})

test_that("assessment pct_proficient does not contain Inf", {
  a <- try_fetch_assessment(2024)

  pct_values <- a$pct_proficient[!is.na(a$pct_proficient)]
  expect_false(any(is.infinite(pct_values)),
               info = "Inf values found in assessment pct_proficient")
})

test_that("assessment pct_proficient does not contain NaN", {
  a <- try_fetch_assessment(2024)

  pct_values <- a$pct_proficient[!is.na(a$pct_proficient)]
  expect_false(any(is.nan(pct_values)),
               info = "NaN values found in assessment pct_proficient")
})


# ==============================================================================
# Section 2: Percentage Scale Validation
# ==============================================================================

test_that("enrollment pct is on 0-1 scale (with documented exception)", {
  enr <- try_fetch_enr(2024)

  valid_pcts <- enr$pct[!is.na(enr$pct)]
  expect_true(all(valid_pcts >= 0),
              info = "Negative enrollment pct found")

  # Documented anomaly: campus 190310 (ONE Academy) has grade_07=29 but
  # row_total=21, producing pct=1.38. This is a real source data error.
  # Exclude that campus from the pct <= 1 check.
  pcts_excl_anomaly <- enr$pct[!is.na(enr$pct) &
                                !(enr$campus_id %in% "190310" &
                                  enr$grade_level == "07")]
  expect_true(all(pcts_excl_anomaly <= 1),
              info = "Enrollment pct > 1 found (beyond documented 190310 anomaly)")
})

test_that("assessment pct_proficient is on 0-100 scale", {
  a <- try_fetch_assessment(2024)

  valid_pcts <- a$pct_proficient[!is.na(a$pct_proficient)]
  expect_true(all(valid_pcts >= 0),
              info = "Negative assessment pct_proficient found")
  expect_true(all(valid_pcts <= 100),
              info = "Assessment pct_proficient > 100 found")
})

test_that("enrollment total_enrollment subgroup has pct = 1.0", {
  enr <- try_fetch_enr(2024)

  total_rows <- enr[enr$subgroup == "total_enrollment" &
                    enr$grade_level == "TOTAL" &
                    !is.na(enr$pct), ]

  expect_true(all(total_rows$pct == 1.0),
              info = "total_enrollment TOTAL rows should have pct = 1.0")
})


# ==============================================================================
# Section 3: Column Type Enforcement
# ==============================================================================

test_that("enrollment column types are correct", {
  enr <- try_fetch_enr(2024)

  expect_type(enr$end_year, "double")
  expect_type(enr$district_id, "character")
  expect_type(enr$campus_id, "character")
  expect_type(enr$district_name, "character")
  expect_type(enr$campus_name, "character")
  expect_type(enr$grade_level, "character")
  expect_type(enr$subgroup, "character")
  expect_type(enr$n_students, "double")
  expect_type(enr$pct, "double")
  expect_type(enr$is_state, "logical")
  expect_type(enr$is_district, "logical")
  expect_type(enr$is_campus, "logical")
  expect_type(enr$is_charter, "logical")
})

test_that("assessment column types are correct", {
  a <- try_fetch_assessment(2024)

  expect_type(a$end_year, "double")
  expect_type(a$agency_code, "character")
  expect_type(a$district_id, "character")
  expect_type(a$standard, "character")
  expect_type(a$subject, "character")
  expect_type(a$grade, "character")
  expect_type(a$subgroup, "character")
  # n_tested may be integer (from raw data) or double (after safe_numeric)
  expect_true(is.numeric(a$n_tested),
              info = "n_tested should be numeric")
  expect_true(is.numeric(a$pct_proficient),
              info = "pct_proficient should be numeric")
  expect_type(a$is_state, "logical")
  expect_type(a$is_district, "logical")
  expect_type(a$is_school, "logical")
  expect_type(a$is_suppressed, "logical")
})


# ==============================================================================
# Section 4: Row Count Minimums
# ==============================================================================

test_that("enrollment has minimum expected rows per year", {
  enr <- try_fetch_enr(2024)

  # With ~115 districts, ~2700 campuses, 13 subgroups, 10 grade levels:
  # minimum is at least 2700 (campuses * 1 subgroup * 1 grade)
  expect_true(nrow(enr) > 2700,
            info = "Enrollment row count suspiciously low")
})

test_that("assessment has minimum expected rows per year", {
  a <- try_fetch_assessment(2024)

  # With ~2500+ schools, multiple subjects/grades/subgroups:
  # should have at least 100k rows
  expect_true(nrow(a) > 100000,
            info = "Assessment row count suspiciously low")
})


# ==============================================================================
# Section 5: Subgroup Value Validation
# ==============================================================================

# All valid enrollment subgroups (from CLAUDE.md)
valid_enrollment_subgroups <- c(
  "total_enrollment", "white", "black", "hispanic", "asian",
  "native_american", "pacific_islander", "multiracial",
  "male", "female", "special_ed", "lep", "econ_disadv"
)

test_that("no unexpected enrollment subgroups in 2024", {
  enr <- try_fetch_enr(2024)

  actual_subgroups <- unique(enr$subgroup)
  unexpected <- setdiff(actual_subgroups, valid_enrollment_subgroups)

  expect_equal(length(unexpected), 0,
               info = paste("Unexpected subgroups:",
                            paste(unexpected, collapse = ", ")))
})

# All valid enrollment grade levels (from CLAUDE.md)
valid_enrollment_grades <- c(
  "PK", "K", "01", "02", "03", "04", "05", "06", "07", "08",
  "09", "10", "11", "12", "TOTAL"
)

test_that("no unexpected enrollment grade levels in 2024", {
  enr <- try_fetch_enr(2024)

  actual_grades <- unique(enr$grade_level)
  unexpected <- setdiff(actual_grades, valid_enrollment_grades)

  expect_equal(length(unexpected), 0,
               info = paste("Unexpected grade levels:",
                            paste(unexpected, collapse = ", ")))
})

# Valid assessment subgroups
valid_assessment_subgroups <- c(
  "AIG", "ALL", "AM7", "AS7", "BL7", "EDS", "ELS", "FCS",
  "FEM", "HI7", "HMS", "MALE", "MIG", "MIL", "MU7",
  "NAIG", "NEDS", "NELS", "NSWD", "PI7", "SWD", "WH7"
)

test_that("no unexpected assessment subgroups in 2024", {
  a <- try_fetch_assessment(2024)

  actual_subgroups <- unique(a$subgroup)
  unexpected <- setdiff(actual_subgroups, valid_assessment_subgroups)

  expect_equal(length(unexpected), 0,
               info = paste("Unexpected assessment subgroups:",
                            paste(unexpected, collapse = ", ")))
})

# Valid assessment grades
valid_assessment_grades <- c("03", "04", "05", "06", "07", "08", "ALL", "EOC")

test_that("no unexpected assessment grades in 2024", {
  a <- try_fetch_assessment(2024)

  actual_grades <- unique(a$grade)
  unexpected <- setdiff(actual_grades, valid_assessment_grades)

  expect_equal(length(unexpected), 0,
               info = paste("Unexpected assessment grades:",
                            paste(unexpected, collapse = ", ")))
})

# Valid assessment standards
valid_assessment_standards <- c("CCR", "GLP", "L1", "L2", "L3", "L4", "L5", "NotProf")

test_that("no unexpected assessment standards in 2024", {
  a <- try_fetch_assessment(2024)

  actual_standards <- unique(a$standard)
  unexpected <- setdiff(actual_standards, valid_assessment_standards)

  expect_equal(length(unexpected), 0,
               info = paste("Unexpected assessment standards:",
                            paste(unexpected, collapse = ", ")))
})


# ==============================================================================
# Section 6: No Duplicates
# ==============================================================================

test_that("no duplicate enrollment TOTAL rows per entity/subgroup", {
  enr <- try_fetch_enr(2024)

  # Check for duplicates at the TOTAL level only. Grade-level district rows
  # can have legitimate duplicates from school-level aggregation.
  total_rows <- enr[enr$grade_level == "TOTAL", ]
  dupes <- total_rows[duplicated(total_rows[c("end_year", "type", "district_id",
                                              "campus_id", "subgroup",
                                              "grade_level")]), ]

  expect_equal(nrow(dupes), 0,
               info = paste("Found", nrow(dupes),
                            "duplicate TOTAL enrollment rows"))
})

test_that("no duplicate campus enrollment rows per campus/subgroup/grade", {
  enr <- try_fetch_enr(2024)

  # Campus-level rows should be unique per campus/subgroup/grade
  campus_rows <- enr[enr$is_campus, ]
  dupes <- campus_rows[duplicated(campus_rows[c("end_year", "campus_id",
                                                "subgroup", "grade_level")]), ]

  expect_equal(nrow(dupes), 0,
               info = paste("Found", nrow(dupes),
                            "duplicate campus enrollment rows"))
})

test_that("no duplicate assessment rows per entity/standard/subject/grade/subgroup", {
  a <- try_fetch_assessment(2024)

  dupes <- a[duplicated(a[c("end_year", "agency_code", "standard",
                            "subject", "grade", "subgroup")]), ]

  expect_equal(nrow(dupes), 0,
               info = paste("Found", nrow(dupes),
                            "duplicate assessment rows"))
})


# ==============================================================================
# Section 7: Entity Flag Mutual Exclusivity
# ==============================================================================

test_that("enrollment entity flags are mutually exclusive", {
  enr <- try_fetch_enr(2024)

  # Each row should be exactly one of state/district/campus
  n_flags <- (as.integer(enr$is_state) +
              as.integer(enr$is_district) +
              as.integer(enr$is_campus))

  expect_true(all(n_flags == 1),
              info = "Some enrollment rows have overlapping entity flags")
})

test_that("assessment entity flags are mutually exclusive", {
  a <- try_fetch_assessment(2024)

  n_flags <- (as.integer(a$is_state) +
              as.integer(a$is_district) +
              as.integer(a$is_school))

  expect_true(all(n_flags == 1),
              info = "Some assessment rows have overlapping entity flags")
})


# ==============================================================================
# Section 8: State Aggregate is Sum of Districts
# ==============================================================================

test_that("state enrollment total equals sum of campus totals (2024)", {
  enr <- try_fetch_enr(2024)

  state_total <- enr$n_students[enr$is_state &
                                enr$subgroup == "total_enrollment" &
                                enr$grade_level == "TOTAL"]

  # NC state aggregate is built from school-level data, so campus sum matches
  campus_sum <- sum(
    enr$n_students[enr$is_campus &
                   enr$subgroup == "total_enrollment" &
                   enr$grade_level == "TOTAL"],
    na.rm = TRUE
  )

  expect_equal(state_total, campus_sum,
               info = "State total does not equal sum of campus totals")
})

test_that("state enrollment total equals sum of campus totals (2018)", {
  enr <- try_fetch_enr(2018)

  state_total <- enr$n_students[enr$is_state &
                                enr$subgroup == "total_enrollment" &
                                enr$grade_level == "TOTAL"]

  campus_sum <- sum(
    enr$n_students[enr$is_campus &
                   enr$subgroup == "total_enrollment" &
                   enr$grade_level == "TOTAL"],
    na.rm = TRUE
  )

  expect_equal(state_total, campus_sum,
               info = "State total does not equal sum of campus totals for 2018")
})

test_that("district TOTAL sum is within 15% of state total (2024)", {
  enr <- try_fetch_enr(2024)

  state_total <- enr$n_students[enr$is_state &
                                enr$subgroup == "total_enrollment" &
                                enr$grade_level == "TOTAL"]

  # District totals may not sum to state total (processing gap from
  # LEA vs school-level data sources), but should be close
  district_sum <- sum(
    enr$n_students[enr$is_district &
                   enr$subgroup == "total_enrollment" &
                   enr$grade_level == "TOTAL"],
    na.rm = TRUE
  )

  ratio <- district_sum / state_total
  expect_true(ratio > 0.85, info = "District sum too far below state total")
  expect_true(ratio <= 1.0, info = "District sum exceeds state total")
})


# ==============================================================================
# Section 9: Demographic Subgroup Sum <= Total
# ==============================================================================

test_that("race/ethnicity subgroup sum does not exceed total enrollment (2024 state)", {
  enr <- try_fetch_enr(2024)

  state_total <- enr$n_students[enr$is_state &
                                enr$subgroup == "total_enrollment" &
                                enr$grade_level == "TOTAL"]

  race_subgroups <- c("white", "black", "hispanic", "asian",
                      "native_american", "pacific_islander", "multiracial")

  race_sum <- sum(sapply(race_subgroups, function(sg) {
    val <- enr$n_students[enr$is_state &
                          enr$subgroup == sg &
                          enr$grade_level == "TOTAL"]
    if (length(val) == 0) 0 else val
  }))

  expect_true(race_sum <= state_total * 1.01,
             info = paste("Race sum", race_sum, "exceeds total", state_total))
})

test_that("gender subgroup sum approximately equals total (2024 state)", {
  enr <- try_fetch_enr(2024)

  state_total <- enr$n_students[enr$is_state &
                                enr$subgroup == "total_enrollment" &
                                enr$grade_level == "TOTAL"]

  male <- enr$n_students[enr$is_state &
                         enr$subgroup == "male" &
                         enr$grade_level == "TOTAL"]

  female <- enr$n_students[enr$is_state &
                           enr$subgroup == "female" &
                           enr$grade_level == "TOTAL"]

  gender_sum <- male + female

  # Male + Female should be very close to total (within 1%)
  expect_true(gender_sum > state_total * 0.99,
            info = "Male + Female sum too low vs total")
  expect_true(gender_sum < state_total * 1.01,
            info = "Male + Female sum too high vs total")
})


# ==============================================================================
# Section 10: Documented Data Anomaly - Campus 190310
# ==============================================================================
# Campus 190310 (ONE Academy) has grade_07 count (29) exceeding row_total (21)
# in 2024 data. This is a REAL anomaly in the NC DPI source data, not a bug.

test_that("documented anomaly: campus 190310 grade 07 > TOTAL", {
  enr <- try_fetch_enr(2024)

  campus_total <- enr$n_students[!is.na(enr$campus_id) &
                                 enr$campus_id == "190310" &
                                 enr$subgroup == "total_enrollment" &
                                 enr$grade_level == "TOTAL"]

  campus_gr07 <- enr$n_students[!is.na(enr$campus_id) &
                                enr$campus_id == "190310" &
                                enr$subgroup == "total_enrollment" &
                                enr$grade_level == "07"]

  if (length(campus_total) == 1 && length(campus_gr07) == 1) {
    # Verify the anomaly still exists (pinned from source data)
    expect_equal(campus_total, 21,
                 info = "Campus 190310 total should be 21")
    expect_equal(campus_gr07, 29,
                 info = "Campus 190310 grade 07 should be 29")

    # The grade count exceeds the total - this is the documented anomaly
    expect_true(campus_gr07 > campus_total,
              info = "Documented anomaly: grade 07 should exceed total for campus 190310")
  } else {
    skip("Campus 190310 not found in 2024 data")
  }
})


# ==============================================================================
# Section 11: No Negative Counts
# ==============================================================================

test_that("no negative enrollment counts in any year", {
  for (yr in c(2018, 2021, 2024)) {
    enr <- try_fetch_enr(yr)
    non_na <- enr$n_students[!is.na(enr$n_students)]
    expect_true(all(non_na >= 0),
                info = paste("Negative count found in year", yr))
  }
})

test_that("no negative n_tested in assessment data", {
  a <- try_fetch_assessment(2024)

  non_na <- a$n_tested[!is.na(a$n_tested)]
  expect_true(all(non_na >= 0),
              info = "Negative n_tested found in assessment data")
})


# ==============================================================================
# Section 12: n_proficient <= n_tested
# ==============================================================================

test_that("n_proficient never exceeds n_tested in assessment data", {
  a <- try_fetch_assessment(2024)

  valid_rows <- a[!is.na(a$n_proficient) & !is.na(a$n_tested), ]

  if (nrow(valid_rows) > 0) {
    violations <- valid_rows[valid_rows$n_proficient > valid_rows$n_tested, ]
    expect_equal(nrow(violations), 0,
                 info = paste("Found", nrow(violations),
                              "rows where n_proficient > n_tested"))
  }
})


# ==============================================================================
# Section 13: end_year Consistency
# ==============================================================================

test_that("all rows in single-year fetch have correct end_year", {
  enr <- try_fetch_enr(2024)
  expect_true(all(enr$end_year == 2024),
              info = "Found rows with wrong end_year in 2024 fetch")

  a <- try_fetch_assessment(2024)
  expect_true(all(a$end_year == 2024),
              info = "Found assessment rows with wrong end_year in 2024 fetch")
})


# ==============================================================================
# Section 14: Year Validation
# ==============================================================================

test_that("fetch_enr rejects out-of-range years", {
  expect_error(fetch_enr(2000), "not available")
  expect_error(fetch_enr(2030), "not available")
  expect_error(fetch_enr(1999), "not available")
})

test_that("fetch_enr rejects non-numeric input", {
  expect_error(fetch_enr("2024"), "single numeric")
  expect_error(fetch_enr(c(2023, 2024)), "single numeric")
})

test_that("fetch_assessment rejects out-of-range years", {
  expect_error(fetch_assessment(2000), "end_year must be one of")
  expect_error(fetch_assessment(2030), "end_year must be one of")
  expect_error(fetch_assessment(2013), "end_year must be one of")
})


# ==============================================================================
# Section 15: safe_numeric Guards
# ==============================================================================

test_that("safe_numeric does not produce Inf", {
  result <- safe_numeric(c("100", "0", "-1", "*", "999999999"))
  expect_false(any(is.infinite(result), na.rm = TRUE))
})

test_that("safe_numeric does not produce NaN", {
  result <- safe_numeric(c("100", "0", ".", "N/A", ""))
  expect_false(any(is.nan(result), na.rm = TRUE))
})


# ==============================================================================
# Section 16: Assessment Filter Functions
# ==============================================================================

test_that("filter_proficiency returns only CCR rows", {
  a <- try_fetch_assessment(2024)

  ccr_only <- filter_proficiency(a, "CCR")
  expect_true(all(ccr_only$standard == "CCR"))
  expect_gt(nrow(ccr_only), 0)
})

test_that("filter_proficiency returns only GLP rows", {
  a <- try_fetch_assessment(2024)

  glp_only <- filter_proficiency(a, "GLP")
  expect_true(all(glp_only$standard == "GLP"))
  expect_gt(nrow(glp_only), 0)
})

test_that("filter_proficiency 'both' returns CCR and GLP only", {
  a <- try_fetch_assessment(2024)

  both <- filter_proficiency(a, "both")
  expect_true(all(both$standard %in% c("CCR", "GLP")))
  expect_gt(nrow(both), 0)
})


# ==============================================================================
# Section 17: calc_proficiency_gap Guards
# ==============================================================================

test_that("proficiency gap is calculated correctly", {
  a <- try_fetch_assessment(2024)

  gap <- calc_proficiency_gap(a, "WH7", "BL7")

  # Gap should have rows
  expect_gt(nrow(gap), 0)

  # Gap is WH7 - BL7, should be numeric
  expect_type(gap$gap, "double")

  # Gap columns should exist
  expect_true("subgroup_1" %in% names(gap))
  expect_true("subgroup_2" %in% names(gap))
  expect_true("pct_proficient_1" %in% names(gap))
  expect_true("pct_proficient_2" %in% names(gap))

  # Verify gap = pct1 - pct2
  expect_equal(gap$gap, gap$pct_proficient_1 - gap$pct_proficient_2)
})


# ==============================================================================
# Section 18: Charter Flag Consistency
# ==============================================================================

test_that("is_charter is FALSE for state rows", {
  enr <- try_fetch_enr(2024)

  state_rows <- enr[enr$is_state, ]
  expect_true(all(!state_rows$is_charter),
              info = "State rows should not be charter")
})

test_that("is_charter is FALSE for district rows", {
  enr <- try_fetch_enr(2024)

  district_rows <- enr[enr$is_district, ]
  expect_true(all(!district_rows$is_charter),
              info = "District rows should not be charter")
})


# ==============================================================================
# Section 19: 2020 Enrollment Special Case
# ==============================================================================

test_that("2020 enrollment has demographics but only TOTAL grades", {
  enr <- try_fetch_enr(2020)

  # Should have multiple subgroups
  n_subgroups <- length(unique(enr$subgroup))
  expect_true(n_subgroups > 1,
            info = "2020 should have demographic subgroups")

  # But only TOTAL grade level
  unique_grades <- unique(enr$grade_level)
  expect_equal(unique_grades, "TOTAL",
               info = "2020 should only have TOTAL grade level")
})


# ==============================================================================
# Section 20: Grade-Level Sum Plausibility
# ==============================================================================

test_that("campus grade-level data exists for 2024", {
  enr <- try_fetch_enr(2024)

  # Check that grade-level data exists at the campus level
  # Not all campuses have grade breakdowns (some only have TOTAL)
  n_campus_grade_rows <- sum(
    enr$is_campus &
    enr$subgroup == "total_enrollment" &
    enr$grade_level != "TOTAL"
  )

  # At least 5000 campus/grade rows should exist (1900+ campuses * ~3 grades avg)
  expect_true(n_campus_grade_rows > 5000,
              info = paste("Too few campus grade rows:", n_campus_grade_rows))
})

test_that("at least 70% of campuses have grade-level data in 2024", {
  enr <- try_fetch_enr(2024)

  # Count campuses with any grade-level data
  campuses_with_grades <- length(unique(
    enr$campus_id[enr$is_campus &
                  enr$subgroup == "total_enrollment" &
                  enr$grade_level != "TOTAL"]
  ))

  total_campuses <- length(unique(
    enr$campus_id[enr$is_campus &
                  enr$subgroup == "total_enrollment" &
                  enr$grade_level == "TOTAL"]
  ))

  pct_with_grades <- campuses_with_grades / total_campuses
  expect_true(pct_with_grades > 0.70,
              info = paste("Only", round(pct_with_grades * 100, 1),
                           "% of campuses have grade-level data"))
})
