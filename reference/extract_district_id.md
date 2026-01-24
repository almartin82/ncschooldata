# Extract district ID from agency code

NC agency codes are typically 6 characters: 3-digit LEA + 3-digit
school. Some codes may have additional characters for special entities.

## Usage

``` r
extract_district_id(agency_code)
```

## Arguments

- agency_code:

  Character vector of agency codes

## Value

Character vector of district IDs (3 digits)
