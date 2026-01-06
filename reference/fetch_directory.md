# Fetch North Carolina school directory

Downloads and processes the North Carolina school directory.

## Usage

``` r
fetch_directory(directory_type = "all", use_cache = TRUE)
```

## Arguments

- directory_type:

  Type of directory to fetch ("private_schools" or "all")

- use_cache:

  If TRUE, use cached data if available (default: TRUE)

## Value

Data frame with school directory information

## Examples

``` r
if (FALSE) { # \dontrun{
# Get all private schools
directory <- fetch_directory()

# Get only private schools
private <- fetch_directory("private_schools")

# Filter by county
wake_schools <- directory |>
  dplyr::filter(county == "Wake")
} # }
```
