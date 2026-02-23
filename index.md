# ncschooldata

**[Documentation](https://almartin82.github.io/ncschooldata/)** \|
**[Getting
Started](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks.html)**

Part of the [State Schooldata
Project](https://github.com/almartin82/njschooldata) - fetching and
analyzing state-published school data in R and Python. The original
[njschooldata](https://github.com/almartin82/njschooldata) package for
New Jersey inspired this family of 50 state packages.

Fetch and analyze North Carolina school enrollment data from the NC
Department of Public Instruction in R or Python.

## What can you find with ncschooldata?

**19 years of enrollment data (2006-2024).** 1.5 million students. 115+
local education agencies. Here are fifteen stories hiding in the
numbers:

------------------------------------------------------------------------

### 1. North Carolina gained 118,000 students since 2006

One of America’s fastest-growing school systems.

``` r
library(ncschooldata)
library(dplyr)
library(tidyr)
library(ggplot2)

enr <- fetch_enr_multi(c(2006, 2010, 2015, 2020, 2024), use_cache = TRUE)

statewide <- enr %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  select(end_year, n_students)

stopifnot(nrow(statewide) > 0)
statewide
```

![Statewide enrollment
trends](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/statewide-chart-1.png)

Statewide enrollment trends

------------------------------------------------------------------------

### 2. Wake County is the state’s largest district

The Research Triangle’s anchor district has nearly 160,000 students.

``` r
enr_2024 <- fetch_enr(2024, use_cache = TRUE)

top_districts <- enr_2024 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  arrange(desc(n_students)) %>%
  head(10) %>%
  select(district_name, n_students)

stopifnot(nrow(top_districts) > 0)
top_districts
```

![Top
districts](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/top-districts-chart-1.png)

Top districts

------------------------------------------------------------------------

### 3. Hispanic enrollment surpassed Asian enrollment fivefold

North Carolina’s demographic transformation since 2018 is dramatic.

``` r
enr_demo <- fetch_enr_multi(c(2018, 2019, 2020, 2021, 2024), use_cache = TRUE)

demographics <- enr_demo %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("white", "black", "hispanic", "asian")) %>%
  select(end_year, subgroup, n_students) %>%
  mutate(subgroup = factor(subgroup,
    levels = c("white", "black", "hispanic", "asian"),
    labels = c("White", "Black", "Hispanic", "Asian")))

stopifnot(nrow(demographics) > 0)
demographics
```

![Demographics
chart](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/demographics-chart-1.png)

Demographics chart

------------------------------------------------------------------------

### 4. Charlotte-Mecklenburg lost students post-COVID

Enrollment decline hit North Carolina’s second-largest district.

``` r
cms_trend <- enr_demo %>%
  filter(district_id == "600", subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  select(end_year, district_name, n_students) %>%
  mutate(change = n_students - lag(n_students))

stopifnot(nrow(cms_trend) > 0)
cms_trend
```

![Charlotte-Mecklenburg enrollment
decline](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/cms-chart-1.png)

Charlotte-Mecklenburg enrollment decline

------------------------------------------------------------------------

### 5. Charter schools serve a growing share of NC students

North Carolina’s charter sector continues to expand.

``` r
charter_summary <- enr_2024 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(is_charter_lea = is_charter) %>%
  group_by(is_charter_lea) %>%
  summarize(
    n_leas = n(),
    students = sum(n_students, na.rm = TRUE),
    .groups = "drop"
  )

state_total <- enr_2024 %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  pull(n_students)

charter_summary <- charter_summary %>%
  mutate(pct = round(students / state_total * 100, 1))

stopifnot(nrow(charter_summary) > 0)
charter_summary
```

![Charter school
enrollment](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/charter-chart-1.png)

Charter school enrollment

------------------------------------------------------------------------

### 6. The coast is booming while the Piedmont stalls

Brunswick and New Hanover counties are growing; Greensboro-area
enrollment is flat.

``` r
enr_regional <- fetch_enr_multi(c(2015, 2024), use_cache = TRUE)

coastal <- c("New Hanover", "Brunswick", "Pender")
piedmont <- c("Guilford", "Forsyth", "Alamance")

regional <- enr_regional %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(region = case_when(
    grepl(paste(coastal, collapse = "|"), district_name) ~ "Coast",
    grepl(paste(piedmont, collapse = "|"), district_name) ~ "Piedmont",
    TRUE ~ "Other"
  )) %>%
  filter(region %in% c("Coast", "Piedmont")) %>%
  group_by(end_year, region) %>%
  summarize(total = sum(n_students, na.rm = TRUE), .groups = "drop")

stopifnot(nrow(regional) > 0)
regional
```

![Regional
comparison](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/regional-chart-1.png)

Regional comparison

------------------------------------------------------------------------

### 7. Economically disadvantaged students are half of enrollment

Poverty defines North Carolina schools.

``` r
econ_data <- enr_2024 %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("total_enrollment", "econ_disadv")) %>%
  select(subgroup, n_students) %>%
  mutate(pct = round(n_students / max(n_students) * 100, 1))

stopifnot(nrow(econ_data) > 0)
econ_data
```

![Economically disadvantaged
students](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/econ-disadv-chart-1.png)

Economically disadvantaged students

------------------------------------------------------------------------

### 8. Durham demographics are shifting rapidly

The Triangle’s most diverse district is transforming.

``` r
durham_demographics <- enr_demo %>%
  filter(district_id == "320", grade_level == "TOTAL",
         subgroup %in% c("white", "black", "hispanic", "asian")) %>%
  group_by(end_year) %>%
  mutate(
    total = sum(n_students),
    pct = round(n_students / total * 100, 1)
  ) %>%
  ungroup() %>%
  select(end_year, subgroup, n_students, pct)

stopifnot(nrow(durham_demographics) > 0)
durham_demographics
```

![Durham demographics
transformation](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/durham-chart-1.png)

Durham demographics transformation

------------------------------------------------------------------------

### 9. English Learners grew 34% from 2018 to 2024

NC schools are adapting to a multilingual reality.

``` r
el_trend <- enr_demo %>%
  filter(is_state, grade_level == "TOTAL", subgroup == "lep") %>%
  select(end_year, n_students) %>%
  mutate(pct_change = round((n_students / first(n_students) - 1) * 100, 1))

stopifnot(nrow(el_trend) > 0)
el_trend
```

![English Learners
trend](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/el-chart-1.png)

English Learners trend

------------------------------------------------------------------------

### 10. Rural eastern NC is losing students fast

Tobacco country is emptying out while cities grow.

``` r
enr_multi <- fetch_enr_multi(c(2015, 2024), use_cache = TRUE)

# Eastern rural counties (traditional tobacco belt)
eastern_rural <- c("Edgecombe", "Halifax", "Hertford", "Northampton",
                   "Bertie", "Martin", "Washington", "Tyrrell")

eastern_data <- enr_multi %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(is_eastern = grepl(paste(eastern_rural, collapse = "|"), district_name)) %>%
  filter(is_eastern) %>%
  group_by(end_year) %>%
  summarize(total = sum(n_students, na.rm = TRUE), .groups = "drop") %>%
  mutate(pct_change = round((total / first(total) - 1) * 100, 1))

stopifnot(nrow(eastern_data) > 0)
eastern_data
```

![Eastern NC rural enrollment
decline](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/eastern-rural-chart-1.png)

Eastern NC rural enrollment decline

------------------------------------------------------------------------

### 11. Union County grew steadily since 2006

Charlotte’s southern suburbs keep adding students.

``` r
enr_union <- fetch_enr_multi(c(2006, 2010, 2015, 2020, 2024), use_cache = TRUE)

union_trend <- enr_union %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Union", district_name)) %>%
  select(end_year, district_name, n_students)

stopifnot(nrow(union_trend) > 0)
union_trend
```

![Union County
growth](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/union-growth-chart-1.png)

Union County growth

------------------------------------------------------------------------

### 12. Asheville’s mountain districts saw enrollment decline

Western NC has an aging population and shrinking schools.

``` r
enr_mountain <- fetch_enr_multi(c(2015, 2024), use_cache = TRUE)

# Mountain counties around Asheville
mountain <- c("Buncombe", "Henderson", "Haywood", "Madison",
              "Transylvania", "Yancey", "Mitchell")

mountain_data <- enr_mountain %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(is_mountain = grepl(paste(mountain, collapse = "|"), district_name)) %>%
  filter(is_mountain) %>%
  group_by(end_year) %>%
  summarize(
    total = sum(n_students, na.rm = TRUE),
    n_districts = n(),
    .groups = "drop"
  )

stopifnot(nrow(mountain_data) > 0)
mountain_data
```

![Mountain counties
enrollment](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/mountain-chart-1.png)

Mountain counties enrollment

------------------------------------------------------------------------

### 13. Special education enrollment from 2018 to 2024

More students identified, more services needed.

``` r
enr_sped <- fetch_enr_multi(c(2018, 2019, 2021, 2024), use_cache = TRUE)

sped_trend <- enr_sped %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("total_enrollment", "special_ed")) %>%
  select(end_year, subgroup, n_students) %>%
  pivot_wider(names_from = subgroup, values_from = n_students) %>%
  mutate(
    pct_sped = round(special_ed / total_enrollment * 100, 1),
    sped_change = round((special_ed / first(special_ed) - 1) * 100, 1)
  )

stopifnot(nrow(sped_trend) > 0)
sped_trend
```

![Special education
growth](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/sped-chart-1.png)

Special education growth

------------------------------------------------------------------------

### 14. The Triangle vs Triad: diverging trajectories

Raleigh-Durham grows while Greensboro-Winston stalls.

``` r
enr_metro <- fetch_enr_multi(c(2015, 2020, 2024), use_cache = TRUE)

triangle <- c("Wake", "Durham", "Orange", "Johnston", "Chatham")
triad <- c("Guilford", "Forsyth", "Davidson", "Randolph", "Alamance")

metro_data <- enr_metro %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(region = case_when(
    grepl(paste(triangle, collapse = "|"), district_name) ~ "Triangle",
    grepl(paste(triad, collapse = "|"), district_name) ~ "Triad",
    TRUE ~ "Other"
  )) %>%
  filter(region %in% c("Triangle", "Triad")) %>%
  group_by(end_year, region) %>%
  summarize(total = sum(n_students, na.rm = TRUE), .groups = "drop")

stopifnot(nrow(metro_data) > 0)
metro_data
```

![Triangle vs Triad
comparison](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/triangle-triad-chart-1.png)

Triangle vs Triad comparison

------------------------------------------------------------------------

### 15. COVID caused the largest enrollment drop in NC history

The 2020-2021 school year lost over 66,000 students statewide.

``` r
covid_trend <- enr %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  select(end_year, n_students) %>%
  mutate(change = n_students - lag(n_students))

stopifnot(nrow(covid_trend) > 0)
covid_trend
```

![COVID enrollment
impact](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/covid-chart-1.png)

COVID enrollment impact

------------------------------------------------------------------------

## Enrollment Visualizations

![North Carolina statewide enrollment
trends](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/statewide-chart-1.png)

![Top North Carolina
districts](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/top-districts-chart-1.png)

See the [full
vignette](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks.html)
for more insights.

## Installation

``` r
# install.packages("remotes")
remotes::install_github("almartin82/ncschooldata")
```

## Quick start

### R

``` r
library(ncschooldata)
library(dplyr)

# Fetch one year
enr_2024 <- fetch_enr(2024)

# Fetch multiple years
enr_recent <- fetch_enr_multi(2019:2024)

# State totals
enr_2024 %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL")

# District breakdown
enr_2024 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  arrange(desc(n_students))

# Demographics
enr_2024 %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("white", "black", "hispanic"))
```

### Python

``` python
import pyncschooldata as nc

# Fetch one year
enr_2024 = nc.fetch_enr(2024)

# Fetch multiple years
enr_recent = nc.fetch_enr_multi([2019, 2020, 2021, 2022, 2023, 2024])

# State totals
state_total = enr_2024[
    (enr_2024['is_state'] == True) &
    (enr_2024['subgroup'] == 'total_enrollment') &
    (enr_2024['grade_level'] == 'TOTAL')
]

# District breakdown
districts = enr_2024[
    (enr_2024['is_district'] == True) &
    (enr_2024['subgroup'] == 'total_enrollment') &
    (enr_2024['grade_level'] == 'TOTAL')
].sort_values('n_students', ascending=False)
```

------------------------------------------------------------------------

## Assessment Data (NEW)

The ncschooldata package now includes EOG (End-of-Grade) and EOC
(End-of-Course) assessment results. See the [assessment
vignette](https://almartin82.github.io/ncschooldata/articles/northcarolina-assessment.html)
for 15 stories from the data.

### R Assessment Example

``` r
library(ncschooldata)
library(dplyr)

# Fetch 2024 assessment data
assess <- fetch_assessment(2024, use_cache = TRUE)

# State-level math results
assess %>%
  filter(is_district, subject == "MA", subgroup == "ALL", grade == "ALL") %>%
  select(district_id, n_tested, pct_proficient) %>%
  head(10)

# Multi-year trends
assess_multi <- fetch_assessment_multi(2019:2024, use_cache = TRUE)

# District-specific data (Wake County = 920)
wake_assess <- fetch_district_assessment(2024, "920")
```

### Key Assessment Functions

| Function                                                                                                                    | Description                               |
|-----------------------------------------------------------------------------------------------------------------------------|-------------------------------------------|
| `fetch_assessment(year)`                                                                                                    | Get assessment data for one year          |
| `fetch_assessment_multi(years)`                                                                                             | Get assessment data for multiple years    |
| `fetch_district_assessment(year, district_id)`                                                                              | Get data for a specific district          |
| [`get_available_assessment_years()`](https://almartin82.github.io/ncschooldata/reference/get_available_assessment_years.md) | List available years (2014-2024, no 2020) |

------------------------------------------------------------------------

## Data availability

### Enrollment Data

| Years         | Source                     | Notes                                                       |
|---------------|----------------------------|-------------------------------------------------------------|
| **2006-2024** | NC DPI School Report Cards | ADM totals by school, LEA, and state                        |
| **2018+**     | NC DPI School Report Cards | Demographics by race/ethnicity, gender, special populations |
| **2006-2017** | NC DPI School Report Cards | Total enrollment only (no demographic breakdowns)           |

### Assessment Data

| Years         | Source                                                            | Notes                               |
|---------------|-------------------------------------------------------------------|-------------------------------------|
| **2014-2024** | NC DPI School Report Cards                                        | EOG (grades 3-8), EOC (high school) |
| **2020**      | Not available                                                     | COVID-19 testing waiver             |
| **Subjects**  | Math, Reading, Science, Biology, NC Math 1, NC Math 3, English II |                                     |

### What’s included

- **Levels:** State, LEA (~115 districts + charters), school (~2,700+)
- **Demographics (2018+):** White, Black, Hispanic, Asian, Native
  American, Pacific Islander, Two or More Races
- **Special populations (2018+):** Economically Disadvantaged, English
  Learners, Special Education
- **Gender (2018+):** Male, Female

### Notable LEA codes

| Code | District Name                 |
|------|-------------------------------|
| 920  | Wake County Schools           |
| 600  | Charlotte-Mecklenburg Schools |
| 410  | Guilford County Schools       |
| 320  | Durham Public Schools         |
| 360  | Forsyth County Schools        |

## Data Notes

### Data Source

NC Department of Public Instruction School Report Cards:
[dpi.nc.gov](https://www.dpi.nc.gov/data-reports/school-report-cards/school-report-card-resources-researchers)

Enrollment data is sourced from the NC DPI School Report Card datasets,
which include Average Daily Membership (ADM) and demographic breakdowns
from chronic absenteeism denominators.

### Census Day

Enrollment counts are based on Average Daily Membership (ADM),
calculated across the school year. ADM is the official enrollment metric
used by NC DPI for funding and reporting purposes.

### Suppression Rules

- Counts fewer than **10 students** are suppressed at the school level
  for privacy
- Suppressed values appear as `NA` in the data
- State and district totals include all students (no suppression at
  aggregate levels)
- When analyzing small schools or subgroups, expect some missing values

### Data Quality Notes

- **2018+**: Full demographic breakdowns (race/ethnicity, gender,
  special populations)
- **2006-2017**: Total enrollment only from ADM data
- **Charter schools**: Counted as separate LEAs with charter flag
- **Virtual schools**: Included in LEA counts where applicable
- **Special populations**: May overlap (e.g., a student can be both EL
  and economically disadvantaged)

### Known Limitations

- Demographic breakdowns not available before 2018 in bundled data
- Pre-K enrollment may be incomplete (not all programs report to DPI)
- Historical data before 2006 uses different reporting formats

## Part of the State Schooldata Project

A simple, consistent interface for accessing state-published school data
in Python and R.

**All 50 state packages:**
[github.com/almartin82](https://github.com/almartin82?tab=repositories&q=schooldata)

## Author

[Andy Martin](https://github.com/almartin82) (<almartin@gmail.com>)

## License

MIT
