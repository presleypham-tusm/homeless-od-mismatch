# homeless-od-mismatch

**Question (draft):** Where do homelessness burden, overdose mortality, and addiction-treatment availability line up poorly in Massachusetts, and do those mismatches differ by race and ethnicity?

**Status:** exploratory prototype. The pipeline is built for Massachusetts first and written to scale to other states' Continuums of Care (CoCs). Results so far are descriptive (11 CoCs) and should not be read as findings. Next phase: a multivariable model with towns nested in CoCs (see `docs/analysis_plan.md`).

## Data sources
| Source | What it provides | Geography | Accessed |
|---|---|---|---|
| HUD Point-in-Time (PIT) counts, 2025 | Homelessness counts, incl. race/ethnicity | CoC | 2026-10-15 |
| HUD CoC GIS boundaries (MA, 2025) | CoC polygons | CoC | 2026-10-15 |
| MA DPH BSAS dashboard, "All communities" download | Opioid-related overdose deaths 2021-2025 (provisional), town population | Town / county / state | 2026-10-15 |
| SAMHSA FindTreatment.gov API | Substance use treatment facilities, services, payment | Facility address | 2026-10-15 |

Raw data are not tracked in Git. `scripts/01_download_samhsa.R` records URL, date, and checksum for what it downloads in `data/raw/MANIFEST.csv`. The HUD and DPH files were downloaded by hand; the PIT spreadsheet-to-CSV step is not yet scripted (TODO).

## How to reproduce
1. Clone the repo and open `homeless-od-mismatch.Rproj` in RStudio.
2. Run `renv::restore()` to install the pinned package versions.
3. Place the HUD CoC shapefile zip and the DPH download in `data/raw/` (see Data sources).
4. Run the scripts in `scripts/` in numeric order: `01_download_samhsa.R`, `02_town_to_coc.R`, `03_figures.R`.

## Repository layout
- `data/raw`, `data/interim`, `data/processed`: data at each stage (raw and interim untracked)
- `scripts/`: numbered analysis scripts
- `R/`: reusable functions
- `docs/`: project log, analysis plan, literature matrix
- `output/figures`, `output/tables`: generated results
- `reports/`: write-ups

## Limitations
PIT counts undercount people experiencing homelessness, and in Massachusetts most of the count is sheltered families. Town-to-CoC assignment uses geography; a few coastal towns outside the HUD polygons were assigned to the nearest CoC (flagged in `data/processed/town_to_coc.csv`). Overdose deaths are provisional, and whether they are attributed by residence or by place of occurrence is being confirmed. Facility listings are self-reported, do not measure capacity, and about 12% lack coordinates. All analyses are ecological, so they say nothing about individuals.

## Ethics
Uses only public, aggregate data. IRB / HRPP determination: pending.

## License and contact
MIT License (see `LICENSE.md`). Presley Pham, Tufts University School of Medicine.
