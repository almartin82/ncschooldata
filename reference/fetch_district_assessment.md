# Get assessment data for a specific district

Convenience function to fetch assessment data for a single district.

## Usage

``` r
fetch_district_assessment(end_year, district_id, tidy = TRUE, use_cache = TRUE)
```

## Arguments

- end_year:

  School year end

- district_id:

  3-digit district ID (e.g., "920" for Wake County)

- tidy:

  If TRUE (default), returns tidy format

- use_cache:

  If TRUE (default), uses cached data

## Value

Data frame filtered to specified district

## Examples

``` r
if (FALSE) { # \dontrun{
# Get Wake County (district 920) assessment data
wake_assess <- fetch_district_assessment(2024, "920")

# Get Charlotte-Mecklenburg (district 600) data
cms_assess <- fetch_district_assessment(2024, "600")
} # }
```
