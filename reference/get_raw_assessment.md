# Download raw assessment data from NC DPI

Downloads assessment data from the NC DPI School Report Cards data file.
The data includes EOG (End-of-Grade) and EOC (End-of-Course) test
results at the school and district (LEA) level.

## Usage

``` r
get_raw_assessment(end_year)
```

## Arguments

- end_year:

  School year end (e.g., 2024 for 2023-24 school year). Valid years:
  2014-2019, 2021-2024 (no 2020 due to COVID waiver).

## Value

Data frame with assessment data
