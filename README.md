# Meta-analysis Workshop – for ecological and evolutionary physiologists

**Website:** <https://nicholaswunz.github.io/meta-analysis-workshop/>

A self-contained Quarto website for graduate students with basic R skills and no prior experience of meta-analysis.

The material is grouped into three sections (Foundations, Models, Advanced). Each section has **self-learning** lecture pages (concepts, illustrations, annotated R code, worked examples on real comparative-physiology data, interpretation and write-up examples) and a **hands-on activity** on simulated data with known true parameters (with hidden solutions). Sections are not tied to particular days, so they can be scheduled flexibly.

## Structure

| Section | Self-learning pages | Hands-on activity |
|---|---|---|
| Foundations | What is meta-analysis? · Systematic review & search (PECOST, Boolean) · Effect sizes (r, Zr, lnRR, SMD, OR, RR, lnRR_Q10, ARR, lnVR, lnCVR; SE, precision, weights) | Activity 1: effect sizes in Excel vs `metafor::escalc()`, forest plots, fixed vs random effects |
| Models | Fixed, random & multilevel models · Heterogeneity (Q, I², prediction intervals, orchard plots) · Non-independence (shared controls, phylogeny) | Activity 2: multilevel model → + shared controls & phylogeny; I² per random effect; results write-up; orchard plot |
| Advanced | Multilevel meta-regression · Publication bias · Variability & location-scale models · Phylogenetic & spatial meta-analysis | Activity 3: meta-regression with sex & body size; small-study & time-lag model; results write-up |

Every model is fitted with **metafor** (plus **orchaRd** for plots and I²); equivalent **brms** code is collected in `resources/brms-companion.qmd`.

## Getting started

1. Open `meta-analysis-workshop.Rproj` in RStudio/Positron.
2. Install packages as described in `setup.qmd` (pacman, tidyverse, metafor, clubSandwich, ape, rotl, corrplot, patchwork, readxl, here, sp, and orchaRd and metaAidR from GitHub; brms is optional).
3. Render the website with `quarto render` (or preview with `quarto preview`). The rendered site goes to `_site/`.

## Publishing

The website is built and published automatically by GitHub Actions (`.github/workflows/publish.yml`) every time changes are pushed to the `main` branch. The workflow installs R, Quarto and the R packages, runs `quarto render`, and deploys the `_site/` folder to GitHub Pages. To check a build, open the **Actions** tab of the repository.

One-off setup: in the repository on GitHub, go to **Settings → Pages → Build and deployment → Source** and choose **GitHub Actions**.

Tip: the first build takes a while (installing packages and bootstrapping I² estimates). If you render the site locally with `quarto render` and commit the `_freeze/` folder, the online build reuses your local results and only re-runs pages you have changed.

## Folders

- `data/` – local copies of the real datasets (Wu & Seebacher 2022; Rodgers et al. 2021 incl. tree; Arnold et al. 2021; the lecture pages download these from the authors' repositories) and simulated practical datasets (`sim_correlation.csv`, `sim_contrast.csv`, `sim_tree.tre`, `sim_spatial_arr.csv`, `sim_truth.csv`).
- `excel/` – Activity 1 Excel templates and worked solutions (with live formulas).
- `scripts/simulate_data.R` – regenerates the simulated data (`SIM_SEED`, default 22); `scripts/make_excel_workbooks.py` rebuilds the Excel files.
- `R/theme_workshop.R` – shared ggplot theme, colours and formatting helpers.
- `foundations/`, `models/`, `advanced/` – self-learning lecture pages.
- `activities/` – hands-on activities.
- `brms_fits/` – cache for fitted brms models.
- `.github/workflows/` – the GitHub Actions workflow that publishes the website.
- `resources/` – writing guide, brms companion, data dictionary, references.

## Sources and credit

Adapted from and inspired by: Noble & Pottier's *Meta-Analysis Workshop* (https://daniel1noble.github.io/meta-analysis_workshop/), Nakagawa et al.'s *Meta-analysis tutorial* (https://itchyshin.github.io/Meta-analysis_tutorial/), the Physalia *Meta-analysis in R* course (Sánchez-Tójar & Dimri), Lacza et al.'s *One dataset, four meta-analyses* and Mizuno et al.'s *Unified framework for phylogenetic and spatial meta-analysis* tutorials. Real datasets are redistributed for teaching from the authors' public repositories – please cite the original papers.
