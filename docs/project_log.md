Decided: Scope option D (MA-first pipeline, built to scale to national CoCs). Two facility definitions compared side by side. Public repo. Mentor candidate is Dr. Siegel, to be re-contacted after the feasibility table. Claude Code is deferred until Stage 3.
Environment: M4 / 16 GB / 129 GiB free. R 4.5.0, RStudio 2026.09.0. Xcode CLT and git present. Homebrew not installed and not needed yet. conda active in the terminal.
Verified: The 2025 PIT/AHAR is out. VSRR county data is by residence and provisional. The buprenorphine practitioner locator is gone. MA OTP spatial access is already covered by DPH. Tufts treats public-data secondary analysis as likely NHSR but requires an IRB determination. WONDER bars publishing counts of 9 or fewer.
Open: Whether the organizer allows a late abstract, whether class excusal depends on it, the current MA CoC count, SAMHSA bulk download vs API, and IRB response.
Next: Finish Stage 0, send the IRB email, paste me the check outputs, then start Stage 1 (literature scan and feasibility table).

## 2026-10-14
Done: Stage 0 repo skeleton pushed to GitHub (renv, .gitignore for raw data, folders). Added docs/lit_matrix.csv (15 rows; L11-L15 unverified). Drafted README.
Decided: Research question framing B (descriptive mismatch plus race lens); E2SFCA is a Phase 2 candidate. SAMHSA data come from the documented FindTreatment.gov API (no bulk file needed).
Open: IRB email not yet sent; organizer reply on late abstract; docs/data_dictionary.csv missing; first-commit avatar check; 5 unverified citations; MA CoC count.
Next: 45-minute lookups (2025 by-CoC PIT link, latest MA DPH tables, SAMHSA MA state ID and payment/service codes), then scripts/01_download.R and 02_feasibility.R.

## 2026-10-15 to 2026-10-17
Done: Scripts 01 (SAMHSA download) and 02 (town-to-CoC crosswalk, summary table) run; 11 CoCs, 351 towns; totals tie out (28,311 homeless, 971 opioid deaths in 2025). Script 03 makes three figures (rates by CoC, homelessness vs deaths, race shares). Abstract drafted and cut under 450 words; citations verified against the PDFs (Baggett 2013, Yamamoto 2019, Goedel 2020). Dr. Siegel agreed to the abstract submission; he is being added as an author (confirm his final text approval before submitting). Wrote docs/analysis_plan.md.
Decided: A2 narrow facility definition (MOUD plus sliding fee), opioid-only outcome, public repo. Next phase is a multivariable model (towns nested in CoCs) following Dr. Siegel's reply: homelessness and deaths rank together (Spearman 0.63, n=11), MOUD does not (0.38; A2 -0.32).
Checked: 17 towns were assigned to the nearest CoC. Cape/Islands towns, Fairhaven and Hull are consistent with county-based CoC definitions. Cohasset is the one real question: it is in Norfolk County and MA-511 is Plymouth County plus Quincy and Weymouth, so it may belong to Balance of State (2025 deaths 0, population 8,381, so little effect on rates). Public state pages do not list towns per CoC; the HUD shapefile is the only source.
Open: DPH residence vs occurrence still unconfirmed (public pages do not say; ask BSAS or read the dashboard notes); IRB email not yet sent; PIT xlsb-to-CSV conversion is not scripted; docs/data_dictionary.csv missing; Cohasset sensitivity check; 40 facilities lack coordinates; citations L11-L15 unverified.
Next: send IRB email; commit scripts 02 and 03, data/processed, output/figures and analysis plan; tag plan-v0.1; get Census API key; write 04_acs_towns.R.

## 2026-10-19
Done: ACS 2020-2024 5-year pulled for 351 towns (scripts/04_acs_towns.R); name join exact, no unmatched towns. Built the town-level analysis table (scripts/05_model_dataset.R, data/processed/model_dataset.csv): 351 rows, no missing primary variables, 971 deaths tie out to the CoC table. BSAS email sent, awaiting response.
Checked: ACS vs DPH population within about 1% for most towns; 30 small rural/Cape towns differ by more than 10%. Rent missing in 12 small towns. 40 SAMHSA listings lack coordinates (32 MOUD); placed at their town's point-on-surface for the distance variable, which brought island and Cape distances down (max 31.7 to 25.7 km). A distance of 0 means a facility lists that town as its address. Distances are straight-line, including over water.
Decided: drop rent from primary model (sensitivity only); add sensitivity checks 7-8; keep DPH population as offset. See plan Deviations.
Open: DPH residence vs occurrence still unconfirmed (BSAS email sent; do not run 06_models.R until answered).
Next: 05b_explore.R (distributions, collinearity, overdispersion), then 06_models.R after the BSAS reply.
