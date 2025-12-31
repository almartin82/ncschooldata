# Tests for utility functions

test_that("safe_numeric handles various inputs", {
  # Normal numbers
  expect_equal(safe_numeric("100"), 100)
  expect_equal(safe_numeric("1,234"), 1234)
  expect_equal(safe_numeric(100), 100)

  # Suppressed values
  expect_true(is.na(safe_numeric("*")))
  expect_true(is.na(safe_numeric("-1")))
  expect_true(is.na(safe_numeric("<5")))
  expect_true(is.na(safe_numeric("<10")))
  expect_true(is.na(safe_numeric(">95")))
  expect_true(is.na(safe_numeric("")))
  expect_true(is.na(safe_numeric("N/A")))
  expect_true(is.na(safe_numeric("null")))

  # Whitespace handling
  expect_equal(safe_numeric("  100  "), 100)
})


test_that("clean_name handles various inputs", {
  expect_equal(clean_name("  Wake County Schools  "), "Wake County Schools")
  expect_equal(clean_name("Multiple   Spaces"), "Multiple Spaces")
})


test_that("validate_year catches invalid years", {
  expect_error(validate_year(2000, 2006, 2025), "not available")
  expect_error(validate_year(2030, 2006, 2025), "not available")
  expect_error(validate_year("2020", 2006, 2025), "must be a single numeric")
  expect_error(validate_year(c(2020, 2021), 2006, 2025), "must be a single numeric")

  # Valid years should not error

  expect_true(validate_year(2020, 2006, 2025))
  expect_true(validate_year(2006, 2006, 2025))
  expect_true(validate_year(2025, 2006, 2025))
})
