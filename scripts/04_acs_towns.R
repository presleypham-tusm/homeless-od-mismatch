# 04_acs_towns.R
# Pull town-level covariates from the 2020-2024 ACS 5-year and join to the town-to-CoC crosswalk.
# Needs CENSUS_API_KEY in .Renviron. Run from the RStudio project so here() resolves.

library(here)
library(dplyr)
library(readr)
library(stringr)
library(tidycensus)

acs_year <- 2024

# Named variables (codes verified against load_variables() labels)
vars <- c(
  pop = "B01003_001",
  pov_total = "B17001_001", pov_below = "B17001_002",
  rent_pct_income = "B25071_001",                 # median gross rent as % of household income
  age_total = "B01001_001",
  m25_29 = "B01001_011", m30_34 = "B01001_012", m35_39 = "B01001_013", m40_44 = "B01001_014",
  f25_29 = "B01001_035", f30_34 = "B01001_036", f35_39 = "B01001_037", f40_44 = "B01001_038",
  race_total = "B03002_001", nh_black = "B03002_004", hispanic = "B03002_012"
)

# 1. Pull (county subdivisions = MA cities and towns) and keep the untouched result
raw <- get_acs(geography = "county subdivision", state = "MA", variables = vars,
               year = acs_year, survey = "acs5", output = "wide")
write_csv(raw, here("data", "raw", sprintf("acs5_%d_ma_cousub_raw.csv", acs_year)))

# 2. Make town names match the DPH names used in the crosswalk
acs <- raw |>
  filter(!str_detect(NAME, "County subdivisions not defined")) |>
  mutate(town = NAME |>
           str_remove(",.*$") |>                    # drop ", Plymouth County, Massachusetts"
           str_remove(" (city|town)$") |>           # drop the place-type word
           str_remove(" Town$") |>                  # e.g. "Barnstable Town"
           recode("Manchester-by-the-Sea" = "Manchester"))

xwalk <- read_csv(here("data", "processed", "town_to_coc.csv"), show_col_types = FALSE)

cat("In crosswalk but not in ACS:\n"); print(setdiff(xwalk$town, acs$town))
cat("In ACS but not in crosswalk:\n");  print(setdiff(acs$town, xwalk$town))
stopifnot(length(setdiff(xwalk$town, acs$town)) == 0, nrow(acs) == nrow(xwalk))

# 3. Derive covariates (percentages, 0-100)
# NOTE: rent_pct_income has 12 NAs (small towns) and is NOT in the primary model;
# kept here for the complete-case sensitivity check (see docs/analysis_plan.md, Deviations).
cov <- acs |>
  transmute(
    town,
    acs_pop = popE,
    pct_poverty = 100 * pov_belowE / pov_totalE,
    rent_pct_income = rent_pct_incomeE,
    pct_age_25_44 = 100 * (m25_29E + m30_34E + m35_39E + m40_44E +
                             f25_29E + f30_34E + f35_39E + f40_44E) / age_totalE,
    pct_black_nh = 100 * nh_blackE / race_totalE,
    pct_hispanic = 100 * hispanicE / race_totalE
  )

out <- xwalk |> select(town, coc_number, dph_pop = pop) |> left_join(cov, by = "town")

# 4. Checks
cat("\nRows:", nrow(out), "(expect 351)\n")
cat("\nMissing values by column:\n"); print(colSums(is.na(out)))
cat("\nACS population vs DPH population (percent difference):\n")
print(summary(100 * (out$acs_pop - out$dph_pop) / out$dph_pop))
cat("\nCovariate ranges:\n")
print(summary(out |> select(pct_poverty, rent_pct_income, pct_age_25_44, pct_black_nh, pct_hispanic)))

write_csv(out, here("data", "processed", "acs_town_covariates.csv"))
