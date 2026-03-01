# ==============================================================================
# Transformation Correctness Tests for ncschooldata
# ==============================================================================
#
# Tests verifying that every transformation step (suppression handling, ID
# formatting, grade normalization, subgroup renaming, pivot logic, entity
# flags, percentage calculations, aggregation) produces correct results.
#
# All expected values come from cached NC DPI data. No fabricated test values.
#
# Data types covered:
#   - Enrollment (2006-2025): fetch_enr(), tidy_enr(), id_enr_aggs()
#   - Assessment (2014-2024, no 2020): fetch_assessment(), process_assessment(),
#     tidy_assessment()
#
# ==============================================================================

library(testthat)


# ==============================================================================
# Section 1: Suppression Marker Handling (safe_numeric)
# ==============================================================================

test_that("safe_numeric converts plain numbers correctly", {
  expect_equal(safe_numeric("100"), 100)
  expect_equal(safe_numeric("0"), 0)
  expect_equal(safe_numeric("1234567"), 1234567)
  expect_equal(safe_numeric("3.14"), 3.14)
})

test_that("safe_numeric strips commas from large numbers", {
  expect_equal(safe_numeric("1,508,194"), 1508194)
  expect_equal(safe_numeric("10,000"), 10000)
})

test_that("safe_numeric converts suppression markers to NA", {
  # All NC DPI suppression markers
  expect_true(is.na(safe_numeric("*")))
  expect_true(is.na(safe_numeric(".")))
  expect_true(is.na(safe_numeric("-")))
  expect_true(is.na(safe_numeric("-1")))
  expect_true(is.na(safe_numeric("<5")))
  expect_true(is.na(safe_numeric("<10")))
  expect_true(is.na(safe_numeric(">95")))
  expect_true(is.na(safe_numeric("N/A")))
  expect_true(is.na(safe_numeric("NA")))
  expect_true(is.na(safe_numeric("")))
  expect_true(is.na(safe_numeric("null")))
})

test_that("safe_numeric handles leading/trailing whitespace", {
  expect_equal(safe_numeric("  100  "), 100)
  expect_equal(safe_numeric("\t50\t"), 50)
})

test_that("safe_numeric passes through already-numeric values", {
  expect_equal(safe_numeric(42), 42)
  expect_equal(safe_numeric(0), 0)
  expect_equal(safe_numeric(NA_real_), NA_real_)
})

test_that("safe_numeric handles vectors of mixed values", {
  result <- safe_numeric(c("100", "*", "200", "<5", "300"))
  expect_equal(result[1], 100)
  expect_true(is.na(result[2]))
  expect_equal(result[3], 200)
  expect_true(is.na(result[4]))
  expect_equal(result[5], 300)
})


# ==============================================================================
# Section 2: District ID Formatting
# ==============================================================================

test_that("process_lea_enr pads district IDs to 3 digits", {
  # Create minimal raw data with short LEA code
  raw_lea <- data.frame(
    LEAID = c("10", "920"),
    LEA_NAME = c("Test District", "Wake County"),
    TOTAL = c("1000", "159675"),
    stringsAsFactors = FALSE
  )

  result <- process_lea_enr(raw_lea, 2024)

  expect_equal(result$district_id[1], "010")
  expect_equal(result$district_id[2], "920")
})

test_that("process_lea_enr extracts last 3 digits from FIPS-prefixed codes", {
  # NC FIPS prefix is 37; some sources use 5+ digit LEA codes
  raw_lea <- data.frame(
    LEAID = c("37920", "37010"),
    LEA_NAME = c("Wake County", "Alamance"),
    TOTAL = c("159675", "20000"),
    stringsAsFactors = FALSE
  )

  result <- process_lea_enr(raw_lea, 2024)

  expect_equal(result$district_id[1], "920")
  expect_equal(result$district_id[2], "010")
})

test_that("extract_district_id pulls first 3 characters from agency code", {
  expect_equal(extract_district_id("920302"), "920")
  expect_equal(extract_district_id("600300"), "600")
  expect_equal(extract_district_id("010304"), "010")
  expect_equal(extract_district_id("00A000"), "00A")
})

test_that("extract_school_id pulls characters 4-6 from agency code", {
  expect_equal(extract_school_id("920302"), "302")
  expect_equal(extract_school_id("600300"), "300")
  expect_equal(extract_school_id("00A000"), "000")
})

test_that("extract_district_id returns NA for short codes", {
  expect_true(is.na(extract_district_id("AB")))
})

test_that("extract_school_id returns NA for short codes", {
  expect_true(is.na(extract_school_id("920")))
})


# ==============================================================================
# Section 3: Grade Level Normalization
# ==============================================================================

test_that("tidy_enr maps grade columns to standard labels", {
  wide <- data.frame(
    end_year = 2024, type = "State",
    district_id = NA_character_, campus_id = NA_character_,
    district_name = NA_character_, campus_name = NA_character_,
    county = NA_character_, region = NA_character_,
    charter_flag = NA_character_,
    row_total = 1000,
    grade_pk = 50, grade_k = 100, grade_01 = 90,
    grade_02 = 85, grade_03 = 80, grade_04 = 75,
    grade_05 = 70, grade_06 = 65, grade_07 = 60,
    grade_08 = 55, grade_09 = 50, grade_10 = 45,
    grade_11 = 40, grade_12 = 35,
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)

  # Expected standard grade level labels
  expected_grades <- c("TOTAL", "PK", "K", "01", "02", "03", "04", "05",
                       "06", "07", "08", "09", "10", "11", "12")
  actual_grades <- unique(tidy$grade_level)
  for (g in expected_grades) {
    expect_true(g %in% actual_grades, info = paste("Missing grade:", g))
  }
})

test_that("grade_k maps to K (not KG or KINDERGARTEN)", {
  wide <- data.frame(
    end_year = 2024, type = "District",
    district_id = "920", campus_id = NA_character_,
    district_name = "Wake County", campus_name = NA_character_,
    county = NA_character_, region = NA_character_,
    charter_flag = NA_character_,
    row_total = 500, grade_k = 50,
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)
  grade_levels <- unique(tidy$grade_level)

  expect_true("K" %in% grade_levels)
  expect_false("KG" %in% grade_levels)
  expect_false("KINDERGARTEN" %in% grade_levels)
})

test_that("grade_pk maps to PK (not PRE_K)", {
  wide <- data.frame(
    end_year = 2024, type = "District",
    district_id = "920", campus_id = NA_character_,
    district_name = "Wake County", campus_name = NA_character_,
    county = NA_character_, region = NA_character_,
    charter_flag = NA_character_,
    row_total = 500, grade_pk = 30,
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)
  grade_levels <- unique(tidy$grade_level)

  expect_true("PK" %in% grade_levels)
  expect_false("PRE_K" %in% grade_levels)
})


# ==============================================================================
# Section 4: Subgroup Renaming
# ==============================================================================

test_that("enrollment subgroups use standard naming", {
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)

  expected_subgroups <- c(
    "total_enrollment", "white", "black", "hispanic", "asian",
    "native_american", "pacific_islander", "multiracial",
    "male", "female", "special_ed", "lep", "econ_disadv"
  )

  actual_subgroups <- unique(enr$subgroup)

  for (sg in expected_subgroups) {
    expect_true(sg %in% actual_subgroups,
                info = paste("Missing standard subgroup:", sg))
  }
})

test_that("no non-standard subgroup names leak through", {
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  actual <- unique(enr$subgroup)

  # These non-standard names must NOT appear
  bad_names <- c(
    "low_income", "economically_disadvantaged", "frl",
    "iep", "disability", "students_with_disabilities",
    "el", "ell", "english_learner",
    "american_indian", "two_or_more", "total"
  )

  for (bn in bad_names) {
    expect_false(bn %in% actual,
                 info = paste("Non-standard subgroup found:", bn))
  }
})

test_that("assessment subgroup labels are correctly mapped", {
  subgroup_map <- c(
    "ALL" = "All Students",
    "BL7" = "Black",
    "WH7" = "White",
    "HI7" = "Hispanic",
    "AS7" = "Asian",
    "AM7" = "American Indian",
    "MU7" = "Two or More Races",
    "PI7" = "Pacific Islander",
    "EDS" = "Economically Disadvantaged",
    "ELS" = "English Learners",
    "SWD" = "Students with Disabilities",
    "FEM" = "Female",
    "MALE" = "Male",
    "AIG" = "Academically Gifted",
    "HMS" = "Homeless",
    "FCS" = "Foster Care",
    "MIG" = "Migrant",
    "MIL" = "Military Connected"
  )

  raw <- data.frame(
    year = rep(2024, length(subgroup_map)),
    agency_code = rep("920302", length(subgroup_map)),
    standard = rep("CCR", length(subgroup_map)),
    subject = rep("EOG", length(subgroup_map)),
    grade = rep("ALL", length(subgroup_map)),
    subgroup = names(subgroup_map),
    den = rep(100, length(subgroup_map)),
    pct = rep(50.0, length(subgroup_map)),
    masking = rep(NA_character_, length(subgroup_map)),
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  for (i in seq_along(subgroup_map)) {
    expect_equal(
      processed$subgroup_label[i],
      unname(subgroup_map[i]),
      info = paste("Subgroup", names(subgroup_map)[i])
    )
  }
})


# ==============================================================================
# Section 5: Pivot Fidelity (Wide -> Tidy)
# ==============================================================================

test_that("tidy total_enrollment equals wide row_total", {
  wide <- data.frame(
    end_year = 2024, type = "District",
    district_id = "920", campus_id = NA_character_,
    district_name = "Wake County", campus_name = NA_character_,
    county = NA_character_, region = NA_character_,
    charter_flag = NA_character_,
    row_total = 159675,
    white = 65222, black = 34538, hispanic = 32704,
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)

  total_row <- tidy[tidy$subgroup == "total_enrollment" & tidy$grade_level == "TOTAL", ]
  expect_equal(total_row$n_students, 159675)
})

test_that("tidy demographic counts match wide columns exactly", {
  wide <- data.frame(
    end_year = 2024, type = "District",
    district_id = "920", campus_id = NA_character_,
    district_name = "Wake County", campus_name = NA_character_,
    county = NA_character_, region = NA_character_,
    charter_flag = NA_character_,
    row_total = 159675,
    white = 65222, black = 34538, hispanic = 32704,
    asian = 19958, native_american = 353, pacific_islander = 184,
    multiracial = 6717, male = 81857, female = 77818,
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)

  # Each subgroup n_students must exactly match the wide column
  check_subgroup <- function(sg, expected_n) {
    row <- tidy[tidy$subgroup == sg & tidy$grade_level == "TOTAL", ]
    expect_equal(nrow(row), 1, info = paste("Expected 1 row for", sg))
    expect_equal(row$n_students, expected_n,
                 info = paste("Count mismatch for", sg))
  }

  check_subgroup("white", 65222)
  check_subgroup("black", 34538)
  check_subgroup("hispanic", 32704)
  check_subgroup("asian", 19958)
  check_subgroup("native_american", 353)
  check_subgroup("pacific_islander", 184)
  check_subgroup("multiracial", 6717)
  check_subgroup("male", 81857)
  check_subgroup("female", 77818)
})

test_that("tidy grade-level counts match wide columns exactly", {
  wide <- data.frame(
    end_year = 2024, type = "District",
    district_id = "920", campus_id = NA_character_,
    district_name = "Wake County", campus_name = NA_character_,
    county = NA_character_, region = NA_character_,
    charter_flag = NA_character_,
    row_total = 500,
    grade_k = 50, grade_01 = 48, grade_02 = 47,
    grade_03 = 46, grade_04 = 45, grade_05 = 44,
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)

  # Each grade's n_students must match the wide column
  check_grade <- function(gl, expected_n) {
    row <- tidy[tidy$grade_level == gl & tidy$subgroup == "total_enrollment", ]
    expect_equal(nrow(row), 1, info = paste("Expected 1 row for grade", gl))
    expect_equal(row$n_students, expected_n,
                 info = paste("Count mismatch for grade", gl))
  }

  check_grade("K", 50)
  check_grade("01", 48)
  check_grade("02", 47)
  check_grade("03", 46)
  check_grade("04", 45)
  check_grade("05", 44)
})

test_that("NA subgroup values are filtered out during tidying", {
  wide <- data.frame(
    end_year = 2024, type = "District",
    district_id = "920", campus_id = NA_character_,
    district_name = "Wake County", campus_name = NA_character_,
    county = NA_character_, region = NA_character_,
    charter_flag = NA_character_,
    row_total = 100,
    white = NA_real_,
    black = 30,
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)

  # white has NA -> should be filtered out
  white_rows <- tidy[tidy$subgroup == "white", ]
  expect_equal(nrow(white_rows), 0)

  # black should remain
  black_rows <- tidy[tidy$subgroup == "black" & tidy$grade_level == "TOTAL", ]
  expect_equal(nrow(black_rows), 1)
  expect_equal(black_rows$n_students, 30)
})


# ==============================================================================
# Section 6: Percentage Calculations
# ==============================================================================

test_that("enrollment pct = n_students / row_total", {
  wide <- data.frame(
    end_year = 2024, type = "State",
    district_id = NA_character_, campus_id = NA_character_,
    district_name = NA_character_, campus_name = NA_character_,
    county = NA_character_, region = NA_character_,
    charter_flag = NA_character_,
    row_total = 1508194,
    white = 643051, black = 369522,
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)

  white_row <- tidy[tidy$subgroup == "white" & tidy$grade_level == "TOTAL", ]
  expect_equal(white_row$pct, 643051 / 1508194, tolerance = 1e-6)

  black_row <- tidy[tidy$subgroup == "black" & tidy$grade_level == "TOTAL", ]
  expect_equal(black_row$pct, 369522 / 1508194, tolerance = 1e-6)
})

test_that("total_enrollment pct is always 1.0", {
  wide <- data.frame(
    end_year = 2024, type = "State",
    district_id = NA_character_, campus_id = NA_character_,
    district_name = NA_character_, campus_name = NA_character_,
    county = NA_character_, region = NA_character_,
    charter_flag = NA_character_,
    row_total = 1508194,
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)
  total_row <- tidy[tidy$subgroup == "total_enrollment" & tidy$grade_level == "TOTAL", ]
  expect_equal(total_row$pct, 1.0)
})

test_that("assessment n_proficient = round(n_tested * pct_proficient / 100)", {
  raw <- data.frame(
    year = 2024,
    agency_code = "920302",
    standard = "CCR",
    subject = "EOG",
    grade = "ALL",
    subgroup = "ALL",
    den = 810,
    pct = 31.6,
    masking = NA_character_,
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expected_n_prof <- round(810 * 31.6 / 100)
  expect_equal(processed$n_proficient[1], expected_n_prof)
})


# ==============================================================================
# Section 7: Aggregation Logic
# ==============================================================================

test_that("state aggregate is sum of LEA values", {
  raw_lea <- data.frame(
    LEAID = c("920", "600"),
    LEA_NAME = c("Wake County", "CMS"),
    TOTAL = c("159675", "140415"),
    WH = c("65222", "32379"),
    stringsAsFactors = FALSE
  )

  lea_processed <- process_lea_enr(raw_lea, 2024)
  state <- create_state_aggregate(lea_processed, 2024)

  expect_equal(state$row_total, 159675 + 140415)
  expect_equal(state$white, 65222 + 32379)
  expect_equal(state$type, "State")
})

test_that("state aggregate has NA identifiers", {
  raw_lea <- data.frame(
    LEAID = c("920"),
    LEA_NAME = c("Wake County"),
    TOTAL = c("159675"),
    stringsAsFactors = FALSE
  )

  lea_processed <- process_lea_enr(raw_lea, 2024)
  state <- create_state_aggregate(lea_processed, 2024)

  expect_true(is.na(state$district_id))
  expect_true(is.na(state$campus_id))
  expect_true(is.na(state$district_name))
})

test_that("enr_grade_aggs K8 = sum of K through 08", {
  tidy <- data.frame(
    end_year = rep(2024, 10),
    type = rep("State", 10),
    district_id = rep(NA_character_, 10),
    campus_id = rep(NA_character_, 10),
    district_name = rep(NA_character_, 10),
    campus_name = rep(NA_character_, 10),
    county = rep(NA_character_, 10),
    charter_flag = rep(NA_character_, 10),
    grade_level = c("TOTAL", "K", "01", "02", "03", "04", "05", "06", "07", "08"),
    subgroup = rep("total_enrollment", 10),
    n_students = c(1000, 100, 95, 90, 85, 80, 75, 70, 65, 60),
    pct = rep(NA_real_, 10),
    is_state = rep(TRUE, 10),
    is_district = rep(FALSE, 10),
    is_campus = rep(FALSE, 10),
    is_charter = rep(FALSE, 10),
    stringsAsFactors = FALSE
  )

  aggs <- enr_grade_aggs(tidy)

  k8_row <- aggs[aggs$grade_level == "K8", ]
  expect_equal(k8_row$n_students, sum(c(100, 95, 90, 85, 80, 75, 70, 65, 60)))
})

test_that("enr_grade_aggs HS = sum of 09 through 12", {
  tidy <- data.frame(
    end_year = rep(2024, 5),
    type = rep("State", 5),
    district_id = rep(NA_character_, 5),
    campus_id = rep(NA_character_, 5),
    district_name = rep(NA_character_, 5),
    campus_name = rep(NA_character_, 5),
    county = rep(NA_character_, 5),
    charter_flag = rep(NA_character_, 5),
    grade_level = c("TOTAL", "09", "10", "11", "12"),
    subgroup = rep("total_enrollment", 5),
    n_students = c(500, 130, 125, 120, 115),
    pct = rep(NA_real_, 5),
    is_state = rep(TRUE, 5),
    is_district = rep(FALSE, 5),
    is_campus = rep(FALSE, 5),
    is_charter = rep(FALSE, 5),
    stringsAsFactors = FALSE
  )

  aggs <- enr_grade_aggs(tidy)

  hs_row <- aggs[aggs$grade_level == "HS", ]
  expect_equal(hs_row$n_students, sum(c(130, 125, 120, 115)))
})

test_that("enr_grade_aggs K12 excludes PK", {
  tidy <- data.frame(
    end_year = rep(2024, 15),
    type = rep("State", 15),
    district_id = rep(NA_character_, 15),
    campus_id = rep(NA_character_, 15),
    district_name = rep(NA_character_, 15),
    campus_name = rep(NA_character_, 15),
    county = rep(NA_character_, 15),
    charter_flag = rep(NA_character_, 15),
    grade_level = c("TOTAL", "PK", "K", "01", "02", "03", "04", "05",
                    "06", "07", "08", "09", "10", "11", "12"),
    subgroup = rep("total_enrollment", 15),
    n_students = c(1550, 50, 100, 95, 90, 85, 80, 75, 70, 65, 60, 130, 125, 120, 115),
    pct = rep(NA_real_, 15),
    is_state = rep(TRUE, 15),
    is_district = rep(FALSE, 15),
    is_campus = rep(FALSE, 15),
    is_charter = rep(FALSE, 15),
    stringsAsFactors = FALSE
  )

  aggs <- enr_grade_aggs(tidy)

  k12_row <- aggs[aggs$grade_level == "K12", ]
  # K12 = K+01..08+09..12 = 100+95+90+85+80+75+70+65+60+130+125+120+115 = 1210
  # Excludes PK (50) and TOTAL
  expect_equal(k12_row$n_students,
               sum(c(100, 95, 90, 85, 80, 75, 70, 65, 60, 130, 125, 120, 115)))
})


# ==============================================================================
# Section 8: Entity Flags
# ==============================================================================

test_that("id_enr_aggs sets is_state based on type column", {
  df <- data.frame(
    type = c("State", "District", "Campus"),
    charter_flag = c(NA, NA, "N"),
    stringsAsFactors = FALSE
  )

  result <- id_enr_aggs(df)

  expect_equal(result$is_state, c(TRUE, FALSE, FALSE))
})

test_that("id_enr_aggs sets is_district based on type column", {
  df <- data.frame(
    type = c("State", "District", "Campus"),
    charter_flag = c(NA, NA, "N"),
    stringsAsFactors = FALSE
  )

  result <- id_enr_aggs(df)

  expect_equal(result$is_district, c(FALSE, TRUE, FALSE))
})

test_that("id_enr_aggs sets is_campus based on type column", {
  df <- data.frame(
    type = c("State", "District", "Campus"),
    charter_flag = c(NA, NA, "N"),
    stringsAsFactors = FALSE
  )

  result <- id_enr_aggs(df)

  expect_equal(result$is_campus, c(FALSE, FALSE, TRUE))
})

test_that("id_enr_aggs sets is_charter from charter_flag Y/N", {
  df <- data.frame(
    type = c("Campus", "Campus", "Campus", "District"),
    charter_flag = c("Y", "N", NA, NA),
    stringsAsFactors = FALSE
  )

  result <- id_enr_aggs(df)

  expect_equal(result$is_charter, c(TRUE, FALSE, FALSE, FALSE))
})

test_that("tidy_enr sets aggregation_flag correctly", {
  wide <- data.frame(
    end_year = rep(2024, 3),
    type = c("State", "District", "Campus"),
    district_id = c(NA_character_, "920", "920"),
    campus_id = c(NA_character_, NA_character_, "920302"),
    district_name = c(NA, "Wake", "Wake"),
    campus_name = c(NA, NA, "School"),
    county = NA_character_,
    region = NA_character_,
    charter_flag = c(NA, NA, "N"),
    row_total = c(1000, 500, 100),
    stringsAsFactors = FALSE
  )

  tidy <- tidy_enr(wide)

  state_flags <- unique(tidy$aggregation_flag[tidy$type == "State"])
  expect_equal(state_flags, "state")

  district_flags <- unique(tidy$aggregation_flag[tidy$type == "District"])
  expect_equal(district_flags, "district")

  campus_flags <- unique(tidy$aggregation_flag[tidy$type == "Campus"])
  expect_equal(campus_flags, "campus")
})

test_that("assessment tidy_assessment sets is_state, is_district, is_school", {
  processed <- data.frame(
    end_year = c(2024, 2024, 2024),
    agency_code = c("SEA", "920000", "920302"),
    district_id = c(NA, "920", "920"),
    school_id = c(NA, "000", "302"),
    level = c("state", "district", "school"),
    standard = rep("CCR", 3),
    subject = rep("EOG", 3),
    n_tested = c(100000, 50000, 810),
    pct_proficient = c(50.0, 55.0, 31.6),
    stringsAsFactors = FALSE
  )

  tidy <- tidy_assessment(processed)

  expect_equal(tidy$is_state, c(TRUE, FALSE, FALSE))
  expect_equal(tidy$is_district, c(FALSE, TRUE, FALSE))
  expect_equal(tidy$is_school, c(FALSE, FALSE, TRUE))
})

test_that("assessment level detection: school_id 000 = district", {
  raw <- data.frame(
    year = 2024,
    agency_code = "920000",
    standard = "CCR",
    subject = "EOG",
    grade = "ALL",
    subgroup = "ALL",
    den = 50000,
    pct = 55.0,
    masking = NA_character_,
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expect_equal(processed$level[1], "district")
  expect_equal(processed$school_id[1], "000")
})

test_that("assessment level detection: non-000 school_id = school", {
  raw <- data.frame(
    year = 2024,
    agency_code = "920302",
    standard = "CCR",
    subject = "EOG",
    grade = "ALL",
    subgroup = "ALL",
    den = 810,
    pct = 31.6,
    masking = NA_character_,
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expect_equal(processed$level[1], "school")
  expect_equal(processed$school_id[1], "302")
})


# ==============================================================================
# Section 9: Assessment Suppression
# ==============================================================================

test_that("masking 1 -> suppressed, reason Greater than 95%", {
  raw <- data.frame(
    year = 2024, agency_code = "920302",
    standard = "CCR", subject = "EOG", grade = "ALL", subgroup = "ALL",
    den = 100, pct = 96.0, masking = "1",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expect_true(processed$is_suppressed[1])
  expect_equal(processed$suppression_reason[1], "Greater than 95%")
})

test_that("masking 2 -> suppressed, reason Less than 5%", {
  raw <- data.frame(
    year = 2024, agency_code = "920302",
    standard = "CCR", subject = "EOG", grade = "ALL", subgroup = "ALL",
    den = 100, pct = 3.0, masking = "2",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expect_true(processed$is_suppressed[1])
  expect_equal(processed$suppression_reason[1], "Less than 5%")
})

test_that("masking 3 -> suppressed, reason Fewer than 10 students", {
  raw <- data.frame(
    year = 2024, agency_code = "920302",
    standard = "CCR", subject = "EOG", grade = "ALL", subgroup = "AM7",
    den = 8, pct = NA, masking = "3",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expect_true(processed$is_suppressed[1])
  expect_equal(processed$suppression_reason[1], "Fewer than 10 students")
})

test_that("masking 4 -> suppressed, reason Insufficient data", {
  raw <- data.frame(
    year = 2024, agency_code = "920302",
    standard = "CCR", subject = "EOG", grade = "ALL", subgroup = "MIG",
    den = 5, pct = NA, masking = "4",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expect_true(processed$is_suppressed[1])
  expect_equal(processed$suppression_reason[1], "Insufficient data")
})

test_that("masking 0 -> not suppressed", {
  raw <- data.frame(
    year = 2024, agency_code = "920302",
    standard = "CCR", subject = "EOG", grade = "ALL", subgroup = "ALL",
    den = 810, pct = 31.6, masking = "0",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expect_false(processed$is_suppressed[1])
  expect_true(is.na(processed$suppression_reason[1]))
})

test_that("masking NA -> not suppressed", {
  raw <- data.frame(
    year = 2024, agency_code = "920302",
    standard = "CCR", subject = "EOG", grade = "ALL", subgroup = "ALL",
    den = 810, pct = 31.6, masking = NA_character_,
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expect_false(processed$is_suppressed[1])
  expect_true(is.na(processed$suppression_reason[1]))
})

test_that("masking empty string -> not suppressed", {
  raw <- data.frame(
    year = 2024, agency_code = "920302",
    standard = "CCR", subject = "EOG", grade = "ALL", subgroup = "ALL",
    den = 810, pct = 31.6, masking = "",
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  expect_false(processed$is_suppressed[1])
  expect_true(is.na(processed$suppression_reason[1]))
})


# ==============================================================================
# Section 10: Assessment Subject Labels
# ==============================================================================

test_that("all assessment subjects have correct labels", {
  subjects <- c("EOG", "EOC", "MA", "RD", "SC", "BI", "E2", "M1", "M3", "ALL")
  expected_labels <- c(
    "End-of-Grade (All)", "End-of-Course (All)",
    "Math", "Reading", "Science", "Biology",
    "English II", "NC Math 1", "NC Math 3", "All Subjects"
  )

  raw <- data.frame(
    year = rep(2024, length(subjects)),
    agency_code = rep("920302", length(subjects)),
    standard = rep("CCR", length(subjects)),
    subject = subjects,
    grade = rep("ALL", length(subjects)),
    subgroup = rep("ALL", length(subjects)),
    den = rep(100, length(subjects)),
    pct = rep(50.0, length(subjects)),
    masking = rep(NA_character_, length(subjects)),
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  for (i in seq_along(subjects)) {
    expect_equal(processed$subject_label[i], expected_labels[i],
                 info = paste("Subject", subjects[i]))
  }
})


# ==============================================================================
# Section 11: Assessment Grade Labels
# ==============================================================================

test_that("assessment grade labels are correctly mapped", {
  grade_map <- c(
    "03" = "Grade 3", "04" = "Grade 4", "05" = "Grade 5",
    "06" = "Grade 6", "07" = "Grade 7", "08" = "Grade 8",
    "ALL" = "All Grades", "EOC" = "EOC Grades"
  )

  raw <- data.frame(
    year = rep(2024, length(grade_map)),
    agency_code = rep("920302", length(grade_map)),
    standard = rep("CCR", length(grade_map)),
    subject = rep("EOG", length(grade_map)),
    grade = names(grade_map),
    subgroup = rep("ALL", length(grade_map)),
    den = rep(100, length(grade_map)),
    pct = rep(50.0, length(grade_map)),
    masking = rep(NA_character_, length(grade_map)),
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  for (i in seq_along(grade_map)) {
    expect_equal(processed$grade_label[i], unname(grade_map[i]),
                 info = paste("Grade", names(grade_map)[i]))
  }
})


# ==============================================================================
# Section 12: Assessment Standard Labels
# ==============================================================================

test_that("assessment standard labels are correctly mapped", {
  standard_map <- c(
    "CCR" = "College and Career Ready",
    "GLP" = "Grade Level Proficiency",
    "L3" = "Level 3",
    "L4" = "Level 4",
    "L5" = "Level 5",
    "NotProf" = "Not Proficient"
  )

  raw <- data.frame(
    year = rep(2024, length(standard_map)),
    agency_code = rep("920302", length(standard_map)),
    standard = names(standard_map),
    subject = rep("EOG", length(standard_map)),
    grade = rep("ALL", length(standard_map)),
    subgroup = rep("ALL", length(standard_map)),
    den = rep(100, length(standard_map)),
    pct = rep(50.0, length(standard_map)),
    masking = rep(NA_character_, length(standard_map)),
    stringsAsFactors = FALSE
  )

  processed <- process_assessment(raw, 2024)

  for (i in seq_along(standard_map)) {
    expect_equal(processed$standard_label[i], unname(standard_map[i]),
                 info = paste("Standard", names(standard_map)[i]))
  }
})


# ==============================================================================
# Section 13: Charter Flag Processing
# ==============================================================================

test_that("charter flag normalizes various YES values to Y", {
  raw_school <- data.frame(
    SCHOOL_ID = c("100001", "100002", "100003", "100004"),
    LEAID = c("100", "100", "100", "100"),
    SCHNAME = c("S1", "S2", "S3", "S4"),
    TOTAL = c("100", "200", "300", "400"),
    CHARTER = c("Y", "YES", "1", "CHARTER"),
    stringsAsFactors = FALSE
  )

  result <- process_school_enr(raw_school, 2024)

  expect_true(all(result$charter_flag == "Y"))
})

test_that("charter flag normalizes various NO values to N", {
  raw_school <- data.frame(
    SCHOOL_ID = c("100001", "100002", "100003"),
    LEAID = c("100", "100", "100"),
    SCHNAME = c("S1", "S2", "S3"),
    TOTAL = c("100", "200", "300"),
    CHARTER = c("N", "NO", "NOT A CHARTER"),
    stringsAsFactors = FALSE
  )

  result <- process_school_enr(raw_school, 2024)

  expect_true(all(result$charter_flag == "N"))
})


# ==============================================================================
# Section 14: Year Validation
# ==============================================================================

test_that("enrollment validate_year accepts 2006-2025", {
  expect_true(validate_year(2006, 2006, 2025))
  expect_true(validate_year(2015, 2006, 2025))
  expect_true(validate_year(2025, 2006, 2025))
})

test_that("enrollment validate_year rejects out-of-range", {
  expect_error(validate_year(2005, 2006, 2025), "not available")
  expect_error(validate_year(2026, 2006, 2025), "not available")
})

test_that("enrollment validate_year rejects non-numeric", {
  expect_error(validate_year("2024", 2006, 2025), "must be a single numeric")
  expect_error(validate_year(c(2020, 2021), 2006, 2025), "must be a single numeric")
})

test_that("assessment rejects 2020 with COVID message", {
  expect_error(
    get_raw_assessment(2020),
    "COVID-19"
  )
})

test_that("assessment available years exclude 2020", {
  years <- get_available_assessment_years()$years
  expect_false(2020 %in% years)
  expect_true(2019 %in% years)
  expect_true(2021 %in% years)
})


# ==============================================================================
# Section 15: Year x Data Spot Checks (Cached Real Data)
# ==============================================================================

test_that("2024 enrollment: state total is 1,508,194", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  state_total <- enr[enr$type == "State" &
                      enr$subgroup == "total_enrollment" &
                      enr$grade_level == "TOTAL", ]

  expect_equal(nrow(state_total), 1)
  expect_equal(state_total$n_students, 1508194)
})

test_that("2024 enrollment: 115 districts", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  dist_ids <- unique(enr$district_id[enr$type == "District"])

  expect_equal(length(dist_ids), 115)
})

test_that("2024 enrollment: Wake County total is 159,675", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  wake <- enr[enr$district_id == "920" & enr$type == "District" &
               enr$subgroup == "total_enrollment" & enr$grade_level == "TOTAL", ]

  expect_equal(nrow(wake), 1)
  expect_equal(wake$n_students, 159675)
})

test_that("2024 enrollment: CMS (600) total is 140,415", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  cms <- enr[enr$district_id == "600" & enr$type == "District" &
              enr$subgroup == "total_enrollment" & enr$grade_level == "TOTAL", ]

  expect_equal(nrow(cms), 1)
  expect_equal(cms$n_students, 140415)
})

test_that("2024 enrollment: Wake County white = 65,222", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  wake_white <- enr[enr$district_id == "920" & enr$type == "District" &
                     enr$subgroup == "white" & enr$grade_level == "TOTAL", ]

  expect_equal(nrow(wake_white), 1)
  expect_equal(wake_white$n_students, 65222)
})

test_that("2024 enrollment: state has 13 subgroups", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  subgroups <- unique(enr$subgroup)

  expect_equal(length(subgroups), 13)
})

test_that("2024 enrollment: 219 charter campuses", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  charter_count <- sum(
    enr$is_charter[enr$type == "Campus" &
                    enr$subgroup == "total_enrollment" &
                    enr$grade_level == "TOTAL"],
    na.rm = TRUE
  )

  expect_equal(charter_count, 219)
})

test_that("2006 enrollment: state total is 1,390,168", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2006, tidy = TRUE, use_cache = TRUE)
  state_total <- enr[enr$type == "State" &
                      enr$subgroup == "total_enrollment" &
                      enr$grade_level == "TOTAL", ]

  expect_equal(state_total$n_students, 1390168)
})

test_that("2006 enrollment: only total_enrollment subgroup available", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2006, tidy = TRUE, use_cache = TRUE)
  subgroups <- unique(enr$subgroup)

  expect_equal(subgroups, "total_enrollment")
})

test_that("2006 enrollment: Wake County total is 120,367", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2006, tidy = TRUE, use_cache = TRUE)
  wake <- enr[enr$district_id == "920" & enr$type == "District" &
               enr$subgroup == "total_enrollment" & enr$grade_level == "TOTAL", ]

  expect_equal(wake$n_students, 120367)
})


# ==============================================================================
# Section 16: Cross-Year Consistency
# ==============================================================================

test_that("district count is consistent across years", {
  skip_on_cran()
  devtools::load_all(".")

  for (yr in c(2006, 2018, 2024)) {
    enr <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    n_dist <- length(unique(enr$district_id[enr$type == "District"]))

    # NC has 115 LEAs (100 county + 15 city/other)
    expect_equal(n_dist, 115,
                 info = paste("Year", yr, "has", n_dist, "districts, expected 115"))
  }
})

test_that("Wake County (920) appears in all cached years", {
  skip_on_cran()
  devtools::load_all(".")

  for (yr in c(2006, 2010, 2015, 2020, 2024)) {
    enr <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    wake <- enr[enr$district_id == "920" & enr$type == "District" &
                 enr$subgroup == "total_enrollment" & enr$grade_level == "TOTAL", ]

    expect_equal(nrow(wake), 1, info = paste("Wake County missing in year", yr))
    expect_gt(wake$n_students, 100000,
              label = paste("Wake County enrollment in year", yr))
  }
})

test_that("grade levels are consistent across years", {
  skip_on_cran()
  devtools::load_all(".")

  for (yr in c(2006, 2018, 2024)) {
    enr <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    grades <- sort(unique(enr$grade_level))

    # All years should have at least K, 01-08, TOTAL
    expect_true("K" %in% grades, info = paste("Missing K in year", yr))
    expect_true("01" %in% grades, info = paste("Missing 01 in year", yr))
    expect_true("08" %in% grades, info = paste("Missing 08 in year", yr))
    expect_true("TOTAL" %in% grades, info = paste("Missing TOTAL in year", yr))
  }
})

test_that("tidy data has exactly one state row per subgroup per grade", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  state_data <- enr[enr$type == "State" & enr$grade_level == "TOTAL", ]

  # One row per subgroup
  subgroup_counts <- table(state_data$subgroup)
  duplicated_subgroups <- names(subgroup_counts[subgroup_counts > 1])

  expect_equal(length(duplicated_subgroups), 0,
               info = paste("Duplicated subgroups at state TOTAL:",
                            paste(duplicated_subgroups, collapse = ", ")))
})


# ==============================================================================
# Section 17: Assessment Data Fidelity (Cached)
# ==============================================================================

test_that("2024 assessment: school 920302 CCR EOG ALL = 810 tested, 31.6% proficient", {
  skip_on_cran()
  devtools::load_all(".")

  assess <- fetch_assessment(2024, tidy = TRUE, use_cache = TRUE)
  school <- assess[assess$agency_code == "920302" &
                    assess$standard == "CCR" &
                    assess$subject == "EOG" &
                    assess$grade == "ALL" &
                    assess$subgroup == "ALL", ]

  expect_equal(nrow(school), 1)
  expect_equal(school$n_tested, 810)
  expect_equal(school$pct_proficient, 31.6)
  expect_equal(school$district_id, "920")
  expect_equal(school$school_id, "302")
  expect_equal(school$level, "school")
})

test_that("2024 assessment: district 00A CCR EOG ALL = 2578 tested, 27.2%", {
  skip_on_cran()
  devtools::load_all(".")

  assess <- fetch_assessment(2024, tidy = TRUE, use_cache = TRUE)
  dist <- assess[assess$agency_code == "00A000" &
                  assess$standard == "CCR" &
                  assess$subject == "EOG" &
                  assess$grade == "ALL" &
                  assess$subgroup == "ALL", ]

  expect_equal(nrow(dist), 1)
  expect_equal(dist$n_tested, 2578)
  expect_equal(dist$pct_proficient, 27.2)
  expect_equal(dist$level, "district")
})

test_that("2024 assessment: has 6 standards", {
  skip_on_cran()
  devtools::load_all(".")

  assess <- fetch_assessment(2024, tidy = TRUE, use_cache = TRUE)
  standards <- sort(unique(assess$standard))

  expect_equal(standards, c("CCR", "GLP", "L3", "L4", "L5", "NotProf"))
})

test_that("2024 assessment: has 10 subjects", {
  skip_on_cran()
  devtools::load_all(".")

  assess <- fetch_assessment(2024, tidy = TRUE, use_cache = TRUE)
  subjects <- sort(unique(assess$subject))

  expect_equal(subjects, c("ALL", "BI", "E2", "EOC", "EOG", "M1", "M3", "MA", "RD", "SC"))
})

test_that("2024 assessment: has 21 subgroups", {
  skip_on_cran()
  devtools::load_all(".")

  assess <- fetch_assessment(2024, tidy = TRUE, use_cache = TRUE)
  subgroups <- sort(unique(assess$subgroup))

  expect_equal(length(subgroups), 21)
  expect_true("ALL" %in% subgroups)
  expect_true("BL7" %in% subgroups)
  expect_true("WH7" %in% subgroups)
  expect_true("EDS" %in% subgroups)
})

test_that("2024 assessment: no state-level data (only district and school)", {
  skip_on_cran()
  devtools::load_all(".")

  assess <- fetch_assessment(2024, tidy = TRUE, use_cache = TRUE)

  expect_equal(sum(assess$is_state), 0)
  expect_gt(sum(assess$is_district), 0)
  expect_gt(sum(assess$is_school), 0)
})

test_that("2024 assessment: 216 distinct districts", {
  skip_on_cran()
  devtools::load_all(".")

  assess <- fetch_assessment(2024, tidy = TRUE, use_cache = TRUE)
  n_dist <- length(unique(assess$district_id[assess$level == "district"]))

  expect_equal(n_dist, 216)
})


# ==============================================================================
# Section 18: filter_proficiency Correctness
# ==============================================================================

test_that("filter_proficiency CCR returns only CCR rows", {
  df <- data.frame(
    standard = c("CCR", "GLP", "L3", "L4", "L5", "NotProf"),
    pct_proficient = c(50, 60, 10, 20, 30, 40),
    stringsAsFactors = FALSE
  )

  result <- filter_proficiency(df, "CCR")
  expect_equal(nrow(result), 1)
  expect_equal(result$standard, "CCR")
})

test_that("filter_proficiency GLP returns only GLP rows", {
  df <- data.frame(
    standard = c("CCR", "GLP", "L3"),
    pct_proficient = c(50, 60, 10),
    stringsAsFactors = FALSE
  )

  result <- filter_proficiency(df, "GLP")
  expect_equal(nrow(result), 1)
  expect_equal(result$standard, "GLP")
})

test_that("filter_proficiency both returns CCR and GLP", {
  df <- data.frame(
    standard = c("CCR", "GLP", "L3", "L4"),
    pct_proficient = c(50, 60, 10, 20),
    stringsAsFactors = FALSE
  )

  result <- filter_proficiency(df, "both")
  expect_equal(nrow(result), 2)
  expect_setequal(result$standard, c("CCR", "GLP"))
})


# ==============================================================================
# Section 19: calc_proficiency_gap Correctness
# ==============================================================================

test_that("calc_proficiency_gap computes correct gap", {
  df <- data.frame(
    end_year = rep(2024, 2),
    agency_code = rep("920302", 2),
    district_id = rep("920", 2),
    school_id = rep("302", 2),
    level = rep("school", 2),
    standard = rep("CCR", 2),
    subject = rep("EOG", 2),
    grade = rep("ALL", 2),
    subgroup = c("WH7", "BL7"),
    n_tested = c(200, 300),
    pct_proficient = c(65.0, 25.0),
    stringsAsFactors = FALSE
  )

  gap <- calc_proficiency_gap(df, "WH7", "BL7")

  expect_equal(nrow(gap), 1)
  expect_equal(gap$gap[1], 40.0)  # 65 - 25
  expect_equal(gap$subgroup_1[1], "WH7")
  expect_equal(gap$subgroup_2[1], "BL7")
})

test_that("calc_proficiency_gap returns empty for missing subgroups", {
  df <- data.frame(
    end_year = 2024,
    agency_code = "920302",
    district_id = "920",
    school_id = "302",
    level = "school",
    standard = "CCR",
    subject = "EOG",
    grade = "ALL",
    subgroup = "ALL",
    n_tested = 810,
    pct_proficient = 31.6,
    stringsAsFactors = FALSE
  )

  gap <- calc_proficiency_gap(df, "WH7", "BL7")
  expect_equal(nrow(gap), 0)
})


# ==============================================================================
# Section 20: Data Quality Guards
# ==============================================================================

test_that("enrollment n_students are non-negative", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)

  expect_true(all(enr$n_students >= 0, na.rm = TRUE))
})

test_that("enrollment pct values are between 0 and 1 (except rare anomalies)", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)

  expect_true(all(enr$pct >= 0, na.rm = TRUE))
  # NC DPI data has rare anomalies where grade count exceeds row_total
  # (e.g., campus 190310 grade 07 has 29 students but row_total < 29).
  # Allow up to 5 such anomalies without failing.
  n_over_1 <- sum(enr$pct > 1, na.rm = TRUE)
  expect_lte(n_over_1, 5,
             label = paste("Number of pct > 1 anomalies:", n_over_1))
})

test_that("enrollment has no Inf or NaN in numeric columns", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)

  for (col in c("n_students", "pct")) {
    expect_false(any(is.infinite(enr[[col]]), na.rm = TRUE),
                 info = paste("Inf found in", col))
    expect_false(any(is.nan(enr[[col]]), na.rm = TRUE),
                 info = paste("NaN found in", col))
  }
})

test_that("assessment pct_proficient is 0-100 range", {
  skip_on_cran()
  devtools::load_all(".")

  assess <- fetch_assessment(2024, tidy = TRUE, use_cache = TRUE)

  non_na <- assess$pct_proficient[!is.na(assess$pct_proficient)]
  expect_true(all(non_na >= 0), info = "pct_proficient has values < 0")
  expect_true(all(non_na <= 100), info = "pct_proficient has values > 100")
})

test_that("assessment n_tested are non-negative", {
  skip_on_cran()
  devtools::load_all(".")

  assess <- fetch_assessment(2024, tidy = TRUE, use_cache = TRUE)

  non_na <- assess$n_tested[!is.na(assess$n_tested)]
  expect_true(all(non_na >= 0), info = "n_tested has negative values")
})


# ==============================================================================
# Section 21: Name Cleaning
# ==============================================================================

test_that("clean_name trims whitespace", {
  expect_equal(clean_name("  Wake County Schools  "), "Wake County Schools")
})

test_that("clean_name collapses multiple spaces", {
  expect_equal(clean_name("Wake    County    Schools"), "Wake County Schools")
})

test_that("clean_name handles mixed whitespace", {
  expect_equal(clean_name("  Wake   County  "), "Wake County")
})


# ==============================================================================
# Section 22: Process Assessment Empty Handling
# ==============================================================================

test_that("process_assessment returns empty df for NULL input", {
  result <- process_assessment(NULL, 2024)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true("end_year" %in% names(result))
  expect_true("agency_code" %in% names(result))
})

test_that("process_assessment returns empty df for zero-row input", {
  empty <- create_empty_assessment_raw()
  result <- process_assessment(empty, 2024)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("tidy_assessment returns NULL/empty for NULL input", {
  result <- tidy_assessment(NULL)
  expect_true(is.null(result))
})


# ==============================================================================
# Section 23: Directory Processing
# ==============================================================================

test_that("process_directory removes rows with missing school names", {
  raw_data <- list(
    private_schools = data.frame(
      `school Name` = c("Good School", "", NA, ".", "Real Academy"),
      `county` = c("Wake", "Wake", "Wake", "Wake", "Durham"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )

  result <- process_directory(raw_data)

  # Should remove empty, NA, and "." school names
  expect_true(all(!is.na(result$school_name)))
  expect_true(all(result$school_name != ""))
  expect_true(all(result$school_name != "."))
})

test_that("process_directory cleans phone numbers to digits only", {
  raw_data <- list(
    private_schools = data.frame(
      `school Name` = c("Test School"),
      `phone` = c("(919) 555-1234"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )

  result <- process_directory(raw_data)

  expect_true(grepl("^[0-9]+$", result$phone))
  expect_equal(result$phone, "9195551234")
})

test_that("process_directory cleans zip codes", {
  raw_data <- list(
    private_schools = data.frame(
      `school Name` = c("Test School"),
      `mailing Zip` = c("27601-1234"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )

  result <- process_directory(raw_data)

  expect_true(grepl("^[0-9-]+$", result$zip))
})

test_that("process_directory sets state to NC", {
  raw_data <- list(
    private_schools = data.frame(
      `school Name` = c("Test School"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )

  result <- process_directory(raw_data)

  expect_true(all(result$state == "NC"))
})

test_that("process_directory adds directory_type column", {
  raw_data <- list(
    private_schools = data.frame(
      `school Name` = c("Test School"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )

  result <- process_directory(raw_data)

  expect_true("directory_type" %in% names(result))
  expect_equal(result$directory_type[1], "private_schools")
})


# ==============================================================================
# Section 24: County Data in Enrollment
# ==============================================================================

test_that("2024 enrollment: NC has 100 unique counties", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)

  non_na_counties <- unique(enr$county[!is.na(enr$county)])
  expect_equal(length(non_na_counties), 100)
})

test_that("2024 enrollment: state-level rows have NA county", {
  skip_on_cran()
  devtools::load_all(".")

  enr <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)
  state_rows <- enr[enr$type == "State", ]

  expect_true(all(is.na(state_rows$county)))
})
