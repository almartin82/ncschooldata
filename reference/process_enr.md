# Process raw NC enrollment data

Transforms raw data from NC DPI into a standardized schema combining LEA
and school data.

## Usage

``` r
process_enr(raw_data, end_year)
```

## Arguments

- raw_data:

  List containing lea and school data frames from get_raw_enr

- end_year:

  School year end

## Value

Processed data frame with standardized columns
