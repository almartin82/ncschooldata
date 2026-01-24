# Get available assessment years

Returns the range of years for which assessment data is available from
the NC DPI School Report Cards data.

## Usage

``` r
get_available_assessment_years()
```

## Value

A list with:

- years:

  Vector of available years

- note:

  Description of data availability

## Examples

``` r
years <- get_available_assessment_years()
print(years$years)
#>  [1] 2014 2015 2016 2017 2018 2019 2021 2022 2023 2024
```
