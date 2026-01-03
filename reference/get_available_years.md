# Get available years

Returns the range of years for which enrollment data is available from
the North Carolina Department of Public Instruction (NC DPI).

## Usage

``` r
get_available_years()
```

## Value

A list with:

- min_year:

  First available year (2006)

- max_year:

  Last available year (2025)

- description:

  Description of data availability

## Examples

``` r
years <- get_available_years()
print(years$min_year)
#> [1] 2006
print(years$max_year)
#> [1] 2025
```
