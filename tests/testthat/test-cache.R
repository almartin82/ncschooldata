# Tests for caching functions

test_that("get_cache_dir returns valid path", {
  cache_dir <- get_cache_dir()
  expect_true(is.character(cache_dir))
  expect_true(grepl("ncschooldata", cache_dir))
})


test_that("get_cache_path generates correct paths", {
  path <- get_cache_path(2024, "tidy")
  expect_true(grepl("enr_tidy_2024.rds", path))

  path_wide <- get_cache_path(2023, "wide")
  expect_true(grepl("enr_wide_2023.rds", path_wide))
})


test_that("cache_exists returns FALSE for non-existent cache", {
  # Use a year that definitely won't be cached
  expect_false(cache_exists(9999, "tidy"))
  expect_false(cache_exists(9999, "wide"))
})


test_that("cache read/write roundtrip works", {
  # Create test data
  test_df <- data.frame(
    end_year = 9998,
    district_id = "001",
    n_students = 100
  )

  # Write to cache
  write_cache(test_df, 9998, "tidy")

  # Check it exists
  expect_true(cache_exists(9998, "tidy"))

  # Read it back
  read_df <- read_cache(9998, "tidy")
  expect_equal(read_df$end_year, 9998)
  expect_equal(read_df$n_students, 100)

  # Clean up
  clear_cache(9998, "tidy")
  expect_false(cache_exists(9998, "tidy"))
})


test_that("clear_cache removes files correctly", {
  # Create test cache files
  test_df <- data.frame(x = 1)
  write_cache(test_df, 9997, "tidy")
  write_cache(test_df, 9997, "wide")
  write_cache(test_df, 9996, "tidy")

  expect_true(cache_exists(9997, "tidy"))
  expect_true(cache_exists(9997, "wide"))
  expect_true(cache_exists(9996, "tidy"))

  # Clear specific year
  clear_cache(9997)
  expect_false(cache_exists(9997, "tidy"))
  expect_false(cache_exists(9997, "wide"))
  expect_true(cache_exists(9996, "tidy"))

  # Clean up remaining
  clear_cache(9996)
})
