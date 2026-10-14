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
