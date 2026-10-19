# Analysis plan (draft v0.1, 2026-10-17)

Status: draft written BEFORE any model is fit. Edit freely; commit it before running `scripts/06_models.R`, then tag the commit (`git tag plan-v0.1`) so the order of events is on record. Changes after the models run go in a dated "Deviations" section at the bottom, not as silent edits.

## 1. Question

Across Massachusetts cities and towns, is opioid-related overdose mortality associated with (a) the homelessness rate of the town's Continuum of Care (CoC) and (b) availability of medication for opioid use disorder (MOUD), after accounting for town-level socioeconomic and demographic differences?

Suggested by Dr. Siegel's reaction to the prototype: homelessness and deaths rank together across the 11 CoCs, MOUD availability does not, so how do these interrelate in a multivariable model? Descriptive and associational only; no causal claims.

## 2. Unit, outcome, exposures

| Element | Definition | Source (already in repo unless noted) |
|---|---|---|
| Unit | 351 MA cities/towns, nested in 11 CoCs | `data/processed/town_to_coc.csv` |
| Outcome | Opioid-related overdose deaths in 2025 (all races summed) | DPH BSAS download |
| Offset | log(town population) | DPH `CITY_TOWN_POPULATION` |
| Exposure 1 | 2025 PIT homeless count per 10,000, at CoC level, applied to each town in the CoC | HUD PIT 2025 |
| Exposure 2a | MOUD facilities per 100,000, CoC level (current rate) | SAMHSA via script 01/02 |
| Exposure 2b | Straight-line distance (km) from town point-on-surface to nearest MOUD facility | SAMHSA coordinates; 40 listings lack coordinates |
| Covariates (max 5) | % in poverty, median rent as share of income, % age 25-44, % Black non-Hispanic, % Hispanic | ACS 5-year by town (TO PULL; confirm latest vintage) |

2025 is the primary year because the PIT count, facility pull and deaths are then contemporaneous. 2021-2024 are not pooled in the primary model because deaths fell sharply over the period (2,277 in 2021 to 971 in 2025) and the homelessness exposure exists for one year.

## 3. Model

Negative binomial mixed model, log link, offset log(population), random intercept for CoC:

`deaths ~ homeless_per_10k_coc + moud_exposure + covariates + offset(log(pop)) + (1 | coc)` (glmmTMB).

Main limitation to state up front: homelessness varies only across 11 CoCs, so its coefficient has an effective sample of 11 regardless of the 351 towns. Report confidence intervals, not just p-values. Four CoCs (Boston, Lynn, Cambridge, Fall River) are a single town each, and Balance of State has 114 towns, so exposures are measured coarsely for it.

## 4. Pre-specified sensitivity checks

1. Drop Boston (largest unit, 128 deaths in 2025).
2. Leave-one-CoC-out (11 refits): do signs and magnitudes hold?
3. Poisson with CoC-clustered standard errors instead of the mixed model.
4. Alternative facility definitions: sliding-fee MOUD (A2), OTP-only.
5. 2024-2025 pooled outcome.
6. Move Cohasset to Balance of State (see crosswalk note in project log).

## 5. What this analysis will NOT claim

- That homelessness or treatment availability causes or prevents deaths.
- That a weak MOUD coefficient means treatment does not work (facilities are placed where need is high; counts are not capacity).
- Anything about individuals (ecological design), or race-specific death rates (town-level race cells are mostly under 10).
- Statistical significance as a finding, given the 11 CoC-level units.

## 6. Data still to get

- ACS 5-year town estimates via `tidycensus` (free Census API key; store in `.Renviron`, never in the repo).
- Optional later: geocode the 40 facilities missing coordinates; PIT counts for 2021-2024 (in the HUD multi-year file; check 2021 completeness first).

## 7. Scripts to write (numbering continues)

- `04_acs_towns.R`: pull and clean covariates, join to towns.
- `05_model_dataset.R`: build one town-level analysis table; assert 351 rows, no NA covariates, totals tie out (971 deaths).
- `06_models.R`: primary model plus the sensitivity checks; write tables to `output/tables/`.

## 8. Questions for Dr. Siegel

- Is town (nested in CoC) the right unit, or would he prefer county or CoC-by-year?
- Which covariates would he consider essential?
- Is 2025-only acceptable as the primary outcome year?

## Deviations
(none yet)
