# HAUS6-HURP-Spindle-Profile-QuPath-MATLAB

**Repository:** https://github.com/kskendo/HAUS6-HURP-Spindle-Profile-QuPath-MATLAB

QuPath and MATLAB pipeline for quantification of HAUS6 and HURP spindle intensity profiles from pole-to-pole fluorescence images.

Developed for:
> Skendo et al. (2026) *Title to be confirmed upon publication.* (in preparation)

**Scripts authored by:** Nicolas Liaudet, Bioimaging Core Facility, University of Geneva
([https://www.unige.ch/medecine/bioimaging/](https://www.unige.ch/medecine/bioimaging/en/bioimaging-core-facility/))
**License:** CC BY-NC 4.0
**Manual annotations by:** Kristjana Skendo, Meraldi Lab, University of Geneva

---

## Overview

The pipeline has two parts:

| Part | Tool | Scripts | What it does |
|------|------|---------|--------------|
| 1 | QuPath | `Set_Channels.groovy`, `Extract_Signal_Profile_v2.groovy` | Manual annotation and intensity profile extraction per image |
| 2 | MATLAB | `Protein_localizer.mlx` + supporting `.m` files | Data loading, processing, statistical analysis, and visualization |

---

## Biological context

Sum projection images of immunofluorescence-stained metaphase spindles (HAUS6, HURP, DAPI channels) are analyzed for spindle-wide intensity distributions. For each cell, intensity profiles are extracted along the spindle pole-to-pole axis at two metaphase plate widths (big and small), with background subtraction. Profiles are then averaged per condition (siCTRL, siHAUS6, siHURP) and compared using repeated measures ANOVA with post-hoc Bonferroni correction in MATLAB.

---

## Requirements

**QuPath:**
- [QuPath](https://qupath.github.io/) version 0.5.2 or newer
- Three-channel sum projection images (.tif):
  - Channel 1: HAUS6
  - Channel 2: HURP
  - Channel 3: DAPI
- Images must have pixel calibration set in micrometers

**MATLAB:**
- MATLAB R2021b or newer (tested with R2024b)
- Statistics and Machine Learning Toolbox (required for `fitrm`, `ranova`, `manova`, `mauchly`, `multcompare`)

---

## Usage

### Part 1 — QuPath: annotation and profile extraction

#### Step 1 — Set up the project
1. Create a new QuPath project and import your sum projection `.tif` images.
2. Open the script editor (**Automate > Script Editor**).
3. Run `Set_Channels.groovy` to set channel names (HAUS6, HURP, DAPI) and display ranges.

#### Step 2 — Draw annotations (per image, manually)
For each image, draw and classify the following annotations using the **line tool** and **rectangle tool**:

| Annotation class | Tool | Description |
|-----------------|------|-------------|
| `Pole to Pole` | Line | Straight line from one spindle pole to the other (spindle axis) |
| `Big metaphase width` | Line | Line perpendicular to spindle axis, as wide as the full spindle at the metaphase plate |
| `Small metaphase width` | Line | Line perpendicular to spindle axis, as wide as the DAPI signal only (chromosome plate width) |
| `Background` | Rectangle | Square ROI placed behind both spindle poles, outside the spindle |

Assign each annotation the correct class using the **Annotations panel** or right-click menu.

#### Step 3 — Extract profiles
1. In the script editor, run `Extract_Signal_Profile_v2.groovy`.
2. Two CSV files are saved per image in a `measurements/` subfolder of the project:
   - `<imagename>_small.csv` — profile at small metaphase width
   - `<imagename>_big.csv` — profile at big metaphase width

**CSV output columns:**
```
Distance (µm); HAUS6; HURP; DAPI;
Background HAUS6; Background HURP; Background DAPI;
Thickness (µm); Pixel spacing (µm); Image resolution (µm)
```
- Distance is in µm, centered at the intersection of the metaphase width line with the spindle axis
- Sampling interval: 0.05 µm (configurable in script)
- Delimiter: semicolon `;` (configurable in script)

---

### Part 2 — MATLAB: processing, statistics, and visualization

#### Step 1 — Open the live script
Open `Protein_localizer.mlx` in MATLAB. This is the main entry point that calls all supporting functions in order.

#### Step 2 — Run the pipeline
The live script runs these steps automatically:

| Function | Description |
|----------|-------------|
| `Initialization.m` | Loads default options from `defaultOptions.mat` |
| `LoadData.m` | Prompts for the `measurements/` folder, reads all CSVs, detects conditions from filenames (`siCTRL`, `siHAUS6`, `siHURP`), and builds a long-format data table |
| `ProcessData.m` | Interpolates profiles to common grids (absolute µm and relative %), subtracts background, and min-max normalizes each profile |
| `ShowProfiles.m` | Plots individual traces, grouped mean ± SEM, and statistical results; exports all figures to `compilation.pdf` |

#### Condition detection from filename
Filenames must contain one of: `siCTRL`, `siHURP`, `siHaus6`, or `siHAUS6` (case handled automatically).
Example: `SUM__siCTRL_1_19_R3D_D3D_small.csv`

#### Statistical analysis (inside `ShowProfiles.m` → `ProfileStats.m`)
- Repeated measures ANOVA (condition × distance interaction)
- Mauchly's test for sphericity; Greenhouse-Geisser correction applied if violated
- Post-hoc Bonferroni correction if interaction is significant
- Results printed in figure subtitles and exported to `compilation.pdf`

---

## Full workflow

```
Sum projection images (.tif)
        |
        v
QuPath: Set_Channels.groovy  (once per project)
        |
        v
QuPath: manual annotation (Pole to Pole, Big/Small metaphase width, Background)
        |
        v
QuPath: Extract_Signal_Profile_v2.groovy
        |
        v
measurements/<image>_small.csv
measurements/<image>_big.csv
        |
        v
MATLAB: Protein_localizer.mlx
  → Initialization → LoadData → ProcessData → ShowProfiles → ProfileStats
        |
        v
compilation.pdf  (individual traces + grouped mean±SEM + statistics)
```

---

## Example data

Example output CSV files are provided in the `example_data/` folder:
- `SUM__siCTRL_1_19_R3D_D3D_small.csv` — example small metaphase width profile (siCTRL)
- `SUM__siCTRL_1_19_R3D_D3D_big.csv` — example big metaphase width profile (siCTRL)

---

## Citation

If you use this pipeline, please cite:

> Skendo K et al. (2026) Title to be confirmed. DOI: to be added upon publication.

and acknowledge the script author:

> Scripts developed by N. Liaudet, Bioimaging Core Facility, University of Geneva.

---

## License

**CC BY-NC 4.0** — Scripts authored by Nicolas Liaudet, Bioimaging Core Facility, University of Geneva.
Free to use for non-commercial purposes with attribution.
See `LICENSE` for full terms.

---

## Contact

Kristjana Skendo (experimental data and annotations)
Meraldi Lab, Department of Cell Physiology and Metabolism
University of Geneva
patrick.meraldi@unige.ch

Nicolas Liaudet (scripts)
Bioimaging Core Facility, University of Geneva
https://www.unige.ch/medecine/bioimaging/en/bioimaging-core-facility/
