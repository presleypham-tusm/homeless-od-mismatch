# homeless-od-mismatch

**Question (draft):** Where do homelessness burden, overdose mortality, and addiction-treatment availability line up poorly in Massachusetts, and do those mismatches differ by race and ethnicity?

**Status:** in progress. Pipeline built for Massachusetts first, written to scale to national Continuums of Care (CoCs). No results yet; nothing here should be read as a finding.

## Data sources (add access date when downloaded)
| Source | What it provides | Geography | Accessed |
|---|---|---|---|
| HUD Point-in-Time (PIT) counts | Homelessness counts | CoC | TODO |
| CDC VSRR provisional overdose deaths | Overdose deaths, 12-month ending | County of residence | TODO |
| MA DPH opioid-related overdose reports | Overdose deaths | County / town | TODO |
| SAMHSA FindTreatment.gov API | Treatment facilities, services, payment | Facility address | TODO |

Raw data are not tracked in Git. `scripts/01_download.R` will fetch each file and record URL, date, and checksum.

## How to reproduce
1. Clone the repo and open `homeless-od-mismatch.Rproj` in RStudio.
2. Run `renv::restore()` to install the pinned package versions.
3. Run the scripts in `scripts/` in numeric order (none yet).

## Repository layout
- `data/raw`, `data/interim`, `data/processed`: data at each stage (contents untracked)
- `scripts/`: numbered analysis scripts
- `R/`: reusable functions
- `docs/`: project log, literature matrix, data dictionary
- `output/figures`, `output/tables`: generated results
- `reports/`: write-ups

## Limitations (see `docs/` as they are documented)
PIT counts undercount people experiencing homelessness; CoC and county boundaries do not align; overdose deaths are by residence and provisional; small counts are suppressed; facility listings are self-reported and do not measure capacity; all analyses are ecological, so they say nothing about individuals.

## Ethics
Uses only public, aggregate, non-identifiable data. IRB / HRPP determination: TODO.

## License and contact
MIT License (see `LICENSE.md`). Presley Pham, Tufts University School of Medicine.
