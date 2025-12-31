# ncschooldata

An R package for fetching, processing, and analyzing school enrollment data from the North Carolina Department of Public Instruction (NC DPI).

## Installation

```r
# Install from GitHub
devtools::install_github("almartin82/ncschooldata")
```

## Quick Start

```r
library(ncschooldata)

# Fetch 2024 enrollment data (2023-24 school year)
enr_2024 <- fetch_enr(2024)

# View state totals
enr_2024 %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL")

# Get Wake County Schools data
wake <- enr_2024 %>%
  filter(district_id == "920")

# Fetch multiple years
enr_multi <- fetch_enr_multi(2020:2024)
```

## Data Availability

### Years Available

| Era | Years | Race/Ethnicity Categories | Notes |
|-----|-------|---------------------------|-------|
| Era 1 | 2006-2010 | 5 categories | Asian and Pacific Islander combined |
| Era 2 | 2011-2025 | 7 categories | Separate Asian and Pacific Islander per federal standards |

**Total Available**: 20 years (2006-2025)

### Aggregation Levels

- **State**: Statewide totals
- **District (LEA)**: 115 Local Education Agencies + charter schools
- **School (Campus)**: Individual school buildings (~2,700 schools)

### Demographics Available

| Category | Available Years | Notes |
|----------|-----------------|-------|
| Total Enrollment | 2006-2025 | All students |
| White | 2006-2025 | |
| Black/African American | 2006-2025 | |
| Hispanic/Latino | 2006-2025 | |
| Asian | 2011-2025 | Combined with Pacific Islander pre-2011 |
| Pacific Islander | 2011-2025 | Combined with Asian pre-2011 |
| American Indian/Alaska Native | 2006-2025 | |
| Two or More Races | 2011-2025 | Not collected pre-2011 |
| Male/Female | Varies | Not always available at school level |

### Grade Levels

Pre-K through Grade 12 enrollment counts available at all levels.

### Special Populations

| Category | Available Years | Notes |
|----------|-----------------|-------|
| Economically Disadvantaged | Varies | Based on free/reduced lunch eligibility |
| Limited English Proficient | Varies | Also called English Learners (EL) |
| Special Education | Varies | Students with IEPs |

## Data Sources

### Primary: NC DPI Statistical Profile

The NC Department of Public Instruction maintains the Statistical Profile application at:
- **URL**: http://apps.schools.nc.gov/ords/f?p=145:1
- **Data Type**: Oracle APEX interactive reports
- **Coverage**: 2006-present

Key tables:
- Table A1: LEA Final Pupils by Grade
- Table 10: Pupils in Membership by Race & Sex
- Table B2: School Enrollment

### Secondary: NCES Common Core of Data (CCD)

Federal data source used as fallback:
- **URL**: https://nces.ed.gov/ccd/
- **Data Type**: CSV/DAT flat files
- **Coverage**: All 50 states, annual releases

## ID System

North Carolina uses a hierarchical identifier system:

| Level | Format | Example | Description |
|-------|--------|---------|-------------|
| State | N/A | - | Aggregate only |
| LEA (District) | 3 digits | `920` | Wake County Schools |
| School | 6 digits | `920358` | LEA code + 3-digit school number |

### Notable LEA Codes

| Code | District Name |
|------|---------------|
| 920 | Wake County Schools |
| 600 | Charlotte-Mecklenburg Schools |
| 410 | Guilford County Schools |
| 320 | Durham Public Schools |
| 360 | Forsyth County Schools |

## Known Limitations

### Data Quality Caveats

1. **Pre-2011 Race Categories**: Asian and Pacific Islander are combined in a single category before the 2011-12 school year.

2. **Two or More Races**: This category was not collected before 2011-12.

3. **Small Cell Suppression**: Counts of fewer than 5 students may be suppressed for privacy in some reports.

4. **Charter School Data**: Charter school reporting has evolved over time. Earlier years may have incomplete charter data.

5. **Special Populations**: Economically disadvantaged, LEP, and special education counts may not be available for all years or all aggregation levels.

### Technical Notes

- The NC DPI Statistical Profile uses Oracle APEX, which requires session-based access for some data exports.
- When the APEX endpoint is unavailable, the package falls back to NCES CCD data.
- NCES data may be released with a 1-2 year lag compared to NC DPI data.

## Functions

### Main Functions

| Function | Description |
|----------|-------------|
| `fetch_enr(end_year)` | Fetch enrollment data for a school year |
| `fetch_enr_multi(end_years)` | Fetch enrollment data for multiple years |
| `get_available_years()` | List available school years |
| `tidy_enr(df)` | Transform wide data to tidy (long) format |
| `id_enr_aggs(df)` | Add aggregation level flags |
| `enr_grade_aggs(df)` | Create K-8, HS, K-12 aggregations |

### Cache Functions

| Function | Description |
|----------|-------------|
| `cache_status()` | View cached data files |
| `clear_cache()` | Remove cached data files |

## Output Schema

### Wide Format (`tidy = FALSE`)

| Column | Type | Description |
|--------|------|-------------|
| end_year | integer | School year end (2024 = 2023-24) |
| type | character | "State", "District", or "Campus" |
| district_id | character | 3-digit LEA code |
| campus_id | character | 6-digit school code |
| district_name | character | LEA name |
| campus_name | character | School name |
| county | character | County name |
| region | character | NC education region |
| charter_flag | character | "Y" or "N" |
| row_total | integer | Total enrollment |
| white, black, hispanic, asian, pacific_islander, native_american, multiracial | integer | Race/ethnicity counts |
| male, female | integer | Gender counts |
| econ_disadv, lep, special_ed | integer | Special population counts |
| grade_pk through grade_12 | integer | Grade-level counts |

### Tidy Format (`tidy = TRUE`, default)

| Column | Type | Description |
|--------|------|-------------|
| end_year | integer | School year end |
| type | character | Aggregation level |
| district_id | character | LEA code |
| campus_id | character | School code |
| district_name | character | LEA name |
| campus_name | character | School name |
| grade_level | character | "TOTAL", "PK", "K", "01"-"12" |
| subgroup | character | "total_enrollment", "white", etc. |
| n_students | integer | Student count |
| pct | numeric | Percentage of total (0-1) |
| is_state | logical | State-level record |
| is_district | logical | District-level record |
| is_campus | logical | School-level record |
| is_charter | logical | Charter school |

## License

MIT License

## Contact

- NC DPI Statistical Profile: 919-807-3700
- NC DPI Data Questions: StudentAccounting@dpi.nc.gov
