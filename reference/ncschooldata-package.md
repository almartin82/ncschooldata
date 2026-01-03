# ncschooldata: Fetch and Process North Carolina School Data

Downloads and processes school data from the North Carolina Department
of Public Instruction (NC DPI). Provides functions for fetching
enrollment data from the Statistical Profile system and transforming it
into tidy format for analysis.

## Main functions

- [`fetch_enr`](https://almartin82.github.io/ncschooldata/reference/fetch_enr.md):

  Fetch enrollment data for a school year

- [`fetch_enr_multi`](https://almartin82.github.io/ncschooldata/reference/fetch_enr_multi.md):

  Fetch enrollment data for multiple years

- [`get_available_years`](https://almartin82.github.io/ncschooldata/reference/get_available_years.md):

  List available school years

- [`tidy_enr`](https://almartin82.github.io/ncschooldata/reference/tidy_enr.md):

  Transform wide data to tidy (long) format

- [`id_enr_aggs`](https://almartin82.github.io/ncschooldata/reference/id_enr_aggs.md):

  Add aggregation level flags

- [`enr_grade_aggs`](https://almartin82.github.io/ncschooldata/reference/enr_grade_aggs.md):

  Create grade-level aggregations

## Cache functions

- [`cache_status`](https://almartin82.github.io/ncschooldata/reference/cache_status.md):

  View cached data files

- [`clear_cache`](https://almartin82.github.io/ncschooldata/reference/clear_cache.md):

  Remove cached data files

## ID System

North Carolina uses a hierarchical ID system:

- LEA (District) codes: 3 digits (e.g., 920 = Wake County Schools)

- School codes: 6 digits (LEA code + 3-digit school number)

## Data Sources

Data is sourced from:

- NC DPI Statistical Profile:
  <http://apps.schools.nc.gov/ords/f?p=145:1>

## Format Eras

- Era 1 (2006-2010):

  Asian and Pacific Islander combined in one category

- Era 2 (2011-present):

  Seven separate race/ethnicity categories per federal standards

## Known Limitations

- Pre-2011 data combines Asian and Pacific Islander into one category

- Some small cell sizes may be suppressed for privacy

- Charter school data availability varies by year

## See also

Useful links:

- <https://almartin82.github.io/ncschooldata>

- <https://github.com/almartin82/ncschooldata>

- Report bugs at <https://github.com/almartin82/ncschooldata/issues>

## Author

**Maintainer**: Al Martin <almartin@example.com>
