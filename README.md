# WOBEC Dashboard

**Summary Data for Stakeholder Workshops**

An interactive web application for exploring Antarctic Weddell Sea oceanographic data, species occurrences, and ecological model outputs.

---

## About WOBEC

The **Weddell Sea** is a uniquely biodiverse and pristine area of the Southern Ocean surrounding Antarctica. To better protect this region—which is crucial for climate regulation and food provision and home to many rare and vulnerable species—the Commission for the Conservation of Antarctic Marine Living Resources (CCAMLR) is working to establish a **Weddell Sea Marine Protected Area** (WSMPA).

Realizing that **no systematic ecosystem monitoring exists** in the Eastern Weddell Sea, scientists from 11 institutes across 8 countries have joined forces together with stakeholders from economy, conservation, and society to design and initiate a long-term ecosystem observatory: the **Weddell Sea Observatory of Biodiversity and Ecosystem Change** (WOBEC). The aim is to support global biodiversity goals, establish a baseline for measuring changes, and strengthen the WSMPA process.

## Purpose of this Dashboard

This digital application provides **easy access to summary datasets** on already existing biogeochemical and physical oceanographic variables, prior species observations, and model output data. It serves as a basis for exploration and discussion in stakeholder workshops, enabling participants to:

- Compare environmental conditions across three time periods
- Visualize species occurrence patterns from GBIF
- Explore ecological model predictions from the SCAR distAnt repository
- Upload and overlay custom shapefiles for spatial analysis
- Examine key oceanographic features in the Weddell Gyre region

## Features

### Dual Interactive Maps

The application displays **two synchronized maps** side-by-side, allowing users to:
- Compare different variables simultaneously
- Compare the same variable across different time periods
- View both maps in Antarctic Polar Stereographic projection (EPSG:3031)
- Navigate seamlessly with synchronized zoom and pan

### Environmental Variables

Explore spatial patterns across **three time periods** (1998–2006, 2007–2015, 2016–2024):

- **Chlorophyll-a concentration** (mg/m³) — phytoplankton productivity indicator
- **Sea ice coverage** (days per year) — critical habitat and climate indicator
- **Surface salinity** (PSU) — ocean circulation and mixing patterns

### Species Occurrence Data

- Search for species by scientific name using **GBIF** (Global Biodiversity Information Facility)
- View occurrence records as map overlays
- Explore biodiversity patterns in the Weddell Sea region

### Ecological Model Outputs

- Access species distribution and ecological model predictions from the **SCAR distAnt** repository
- Dynamically load model layers for visualization
- Compare model outputs with observed environmental conditions

### Custom Data Upload

- Upload zipped shapefiles (.zip) to overlay custom spatial data
- Visualize study areas, management boundaries, or sampling locations
- Shapefiles are automatically transformed to the correct coordinate system

### Spatial Context Layers

- **CCAMLR Statistical Areas** — fisheries management boundaries
- **Management Units** — conservation planning regions
- **WOBEC Study Area** — project focus region
- **Weddell Gyre** — key oceanographic feature
- **Points of Interest** — Kap Norvegia, Maud Rise center

## Data Sources

All data are openly available from trusted scientific repositories:

| Data Type | Source | Coverage |
|-----------|--------|----------|
| **Chlorophyll-a** | Copernicus Marine Service | 1998–2024 |
| **Sea Ice** | Copernicus Marine Service | 1998–2024 |
| **Surface Salinity** | Copernicus Marine Service | 1998–2024 |
| **Species Occurrences** | GBIF API | All available records |
| **Ecological Models** | SCAR distAnt | Various species/variables |

### Copernicus Marine Service Datasets

- **Chlorophyll**: `c3s_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M`
- **Sea Ice**: `cmems_mod_glo_phy_my_0.083deg_P1D-m` (pre-2021) + `cmems_mod_glo_phy_myint_0.083deg_P1D-m` (2021+)
- **Salinity**: `cmems_obs-mob_glo_phy-sss_my_multi_P1M` (pre-2023) + `cmems_obs-mob_glo_phy-sss_nrt_multi_P1M` (2023+)

All environmental data are processed to show **9-year period averages** to capture decadal trends while reducing seasonal noise.

---

## Running the Application

### Prerequisites

- **R** (version 4.5 or higher)
- **RStudio** or **Positron** (recommended)
- **Homebrew** (macOS package manager): [Install Homebrew](https://brew.sh/)

#### System Dependencies

- **netCDF library**: Required for processing oceanographic data
  - macOS: `brew install netcdf`
  - Ubuntu/Debian: `sudo apt-get install libnetcdf-dev`
  - Other systems: See [netCDF installation guide](https://www.unidata.ucar.edu/software/netcdf/)

- **GDAL**: Required for spatial data processing and generating distAnt model tiles
  - macOS: `brew install gdal`
  - Ubuntu/Debian: `sudo apt-get install gdal-bin libgdal-dev`

  This installs GDAL C libraries and command-line tools system-wide.

#### Python Environment Setup

This project uses Python (via reticulate) for GDAL tile generation. **Both local development and shinyapps.io deployment use the same Python packages** specified in `requirements.txt`.

##### 1. Install pyenv and pyenv-virtualenv (macOS with zsh)

```bash
# Install pyenv for Python version management
brew install pyenv

# Install pyenv-virtualenv for virtual environment support
brew install pyenv-virtualenv

# Add to your ~/.zshrc (for zsh shell)
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init --path)"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc

# Restart your shell
exec "$SHELL"
```

##### 2. Install Python and Create Virtual Environment

```bash
# Install Python 3.11 (matches shinyapps.io)
pyenv install 3.11.0

# Navigate to project directory
cd /path/to/antarctica-shinyapp

# Create project-specific virtual environment
pyenv virtualenv 3.11.0 antarctica-shinyapp

# Set local Python version (auto-activates in this directory)
pyenv local antarctica-shinyapp
```

##### 3. Install Python Packages

**Important:** You need **both** brew GDAL (C libraries) and pip GDAL (Python bindings):
- `brew install gdal` → System C libraries (prerequisite)
- `pip install GDAL` → Python bindings that link to C libraries

```bash
# Ensure virtualenv is activated (should auto-activate in project dir)
# Install GDAL Python bindings (links to brew's GDAL C libraries)
pip install GDAL==$(gdal-config --version)

# Install numpy (required by GDAL for tile generation)
# Version range ensures compatibility with both local (numpy 2.x) and shinyapps.io (numpy 1.x)
pip install "numpy>=1.24,<3.0"

# Verify installation
python -c "from osgeo import gdal; print('GDAL Python bindings installed successfully')"
```

**Note:** On shinyapps.io, Python packages are installed automatically from `requirements.txt` — no additional configuration needed for deployment.

### Package Management

This project uses **renv** for reproducible R package management. All required packages are tracked in `renv.lock`.

**First-time setup:**
```r
# 1. Open R in the project directory
# 2. renv will automatically bootstrap
# 3. Restore all packages from the lockfile:
renv::restore()
```

**Adding new packages:**
```r
# Install the package as usual
install.packages("new_package")

# Update the lockfile
renv::snapshot()
```

Key packages used in this project:
- `shiny`, `leaflet`, `leaflet.extras`, `leaflet.minicharts` (web interface)
- `sf`, `terra`, `ncdf4` (spatial and netCDF data handling)
- `dplyr`, `tidyr`, `stringr` (data wrangling)
- `httr2`, `jsonlite`, `curl` (API access)
- `reticulate` (Python interoperability for Copernicus data access)

### Launch the App

```bash
# Option 1: Open in RStudio and run
shiny::runApp()

# Option 2: From R console in project directory
R -e "shiny::runApp()"

# Option 3: From terminal
Rscript -e "shiny::runApp()"
```

The app will open in your default web browser, typically at `http://127.0.0.1:XXXX`.

---

## Data Processing Pipeline

The `dataprep/` directory contains scripts for downloading, processing, and preparing data for visualization:

### Data Acquisition (`dataprep/getdata.R`)

Functions to fetch data from the Copernicus Marine Service using Python's `copernicusmarine` module via `reticulate`. Handles:
- Dataset transitions (e.g., multi-year vs. near-real-time data)
- Spatial subsetting to the Weddell Sea region
- Temporal aggregation for multiple decades

Key functions:
- `get_chla()` — Download chlorophyll-a data
- `get_seaice()` — Download sea ice concentration data
- `get_salinity()` — Download sea surface salinity data

**Installing copernicusmarine for data preparation (optional):**

The Shiny app does not require `copernicusmarine` — this is only needed if you want to download new data from Copernicus Marine Service. Install in your `antarctica-shinyapp` virtual environment:

```bash
# Activate the virtual environment
pyenv activate antarctica-shinyapp

# Install copernicusmarine
pip install copernicusmarine
```

To use the data acquisition functions, provide your Copernicus Marine Service credentials as function arguments:

```r
library(reticulate)
source("dataprep/getdata.R")

params <- dataparams(getdates = c("2024-01-01", "2024-12-31"), bboxcoords = bbox)
results <- get_chla(params, user = "your_username", pass = "your_password")
```

Register for a free account at [Copernicus Marine Service](https://data.marine.copernicus.eu/) to obtain credentials.

### Data Wrangling (`dataprep/wrangledata.R`)

Time series and spatial aggregation functions to create summary products:

- `annual_summaries()` — Aggregate monthly netCDF data to annual averages
- `timeperiod_averages()` — Calculate 9-year period means and variability
- `extents_and_sums()` — Process sea ice extent/days from concentration data
- `maketiles()` — Convert rasters to Leaflet tiles with appropriate color palettes

### Visualization (`dataprep/makeplots.R`)

Highcharts plotting functions for time series and trends (available for future features).

### Tile Generation

Environmental data are converted to **TMS-compatible map tiles** stored in `www/` subdirectories:
- Zoom levels: 2–4
- Tile size: 256×256 pixels
- Projection: EPSG:3031 (Antarctic Polar Stereographic)
- Format: PNG with transparency

Dynamic tiles for distAnt model outputs are generated on-the-fly during user sessions.

---

## Technical Architecture

### Core Application Files

- **`global.R`** — Package loading, spatial boundaries, raster configurations
- **`ui.R`** — Shiny UI using `htmlTemplate()` to inject inputs into `index.html`
- **`server.R`** — Reactive logic for map rendering, tile management, uploads, and API queries
- **`index.html`** — HTML template with modern UI design
- **`www/style.css`** — Custom styling with CSS design tokens (glassmorphism, gradients, animations)

### Key Technologies

- **R Shiny** — Web application framework
- **Leaflet** — Interactive mapping with custom Antarctic projection
- **Terra & GDAL** — Raster processing and tile generation
- **SF** — Vector spatial data handling
- **Bootstrap 5** — Responsive UI framework
- **Python (via reticulate)** — Copernicus Marine API access

### Map Projection

The app uses **EPSG:3031** (Antarctic Polar Stereographic) for accurate representation of polar regions. This requires:
- Custom Leaflet CRS configuration (server.R:16-23)
- Vector data in EPSG:4326 (lat/lon) for Leaflet overlay
- Raster tiles generated in EPSG:3031 using gdal2tiles

### Session Management

Each user session creates a temporary directory for dynamic tiles, automatically cleaned up when the session ends.

---

## Development

### Project Structure

```
antarctica-shinyapp/
├── global.R                    # Configuration and data definitions
├── ui.R                        # Shiny UI setup
├── server.R                    # Server-side logic
├── index.html                  # HTML template
├── dataprep/                   # Data processing scripts
│   ├── getdata.R              # Data download functions
│   ├── wrangledata.R          # Processing and aggregation
│   └── makeplots.R            # Plotting functions
├── www/                        # Static assets and tiles
│   ├── style.css              # Custom styling
│   ├── images/                # Logo, icons, backgrounds
│   ├── chlorophyllA/          # Chlorophyll tile pyramids
│   ├── seaiceDays/            # Sea ice tile pyramids
│   ├── surfaceSalinity/       # Salinity tile pyramids
│   ├── statisticalAreasCCAMLR/ # CCAMLR boundaries
│   ├── mgmtAreas/             # Management unit boundaries
│   ├── studyAreaWOBEC/        # WOBEC study area
│   └── distAnt.csv            # Model repository metadata
├── CLAUDE.md                   # AI assistant guidance
└── README.md                   # This file
```

### Contributing

This project is developed as part of the WOBEC initiative. For questions or collaboration inquiries, please visit [wobec.aq](https://wobec.aq) or open an issue on GitHub.

### Updating Data

To refresh the environmental data layers:
1. Use functions in `dataprep/getdata.R` to download latest data
2. Process with `dataprep/wrangledata.R` to generate period averages
3. Create new tiles using `maketiles()` function
4. Update `allrasters` list in `global.R` if adding new variables

---

## Resources and Links

### Data Sources
- **Copernicus Marine Service**: [data.marine.copernicus.eu/products](https://data.marine.copernicus.eu/products)
- **GBIF**: [gbif.org](https://www.gbif.org/en)
- **SCAR distAnt**: [source.coop/repositories/scar/distant](https://source.coop/repositories/scar/distant)

### Learn More
- **WOBEC Official Website**: [wobec.aq](https://wobec.aq)
- **WOBEC Data Management Plan v1.0**: [doi.org/10.5281/zenodo.15040396](https://doi.org/10.5281/zenodo.15040396)

### Related Initiatives
- **CCAMLR**: [ccamlr.org](https://www.ccamlr.org)
- **Weddell Sea MPA**: Information available through CCAMLR

---

## License

[Add license information as appropriate]

## Acknowledgments

WOBEC is a collaborative effort involving scientists from 11 institutes across 8 countries, working together with stakeholders from economy, conservation, and society.

Data products used in this application are provided by:
- Copernicus Marine Service
- Global Biodiversity Information Facility (GBIF)
- Scientific Committee on Antarctic Research (SCAR)

---

**Contact**: For more information about WOBEC, visit [wobec.aq](https://wobec.aq)
