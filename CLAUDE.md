# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Shiny application for exploring Antarctic Weddell Sea oceanographic data (WOBEC project). The app displays dual synchronized maps showing environmental variables (chlorophyll-a, sea ice, salinity) across three time periods (1998-2006, 2007-2015, 2016-2024), with support for GBIF species occurrence overlays and user-uploaded shapefiles.

## Running the Application

```bash
# Open in RStudio and run:
shiny::runApp()

# Or from R console in project directory:
R -e "shiny::runApp()"
```

## Core Architecture

### Three-File Shiny Structure

- **global.R**: Loads packages, defines datasets, spatial boundaries (Weddell Gyre, CCAMLR areas, study regions), and raster layer configurations. Contains the `rast2tile()` function for on-the-fly tile generation and the `allrasters` list defining available map layers.
- **ui.R**: Uses `htmlTemplate()` to inject Shiny inputs into `index.html`. Minimal R code - primarily input definitions.
- **server.R**: Core reactive logic for map rendering, tile management, user uploads, and species occurrence queries.

### Coordinate Reference Systems

The app uses **EPSG:3031** (Antarctic Polar Stereographic) for map display, requiring custom Leaflet CRS configuration (server.R:16-23). Vector data must be in EPSG:4326 (lat/lon) for Leaflet, while raster tiles are generated in EPSG:3031 using gdal2tiles.

### Map Tile System

Pre-generated tiles are stored in `www/` subdirectories with structure:
```
www/
  chlorophyllA/
    19982006/{z}/{x}/{y}.png
    20072015diff/...
  seaiceDays/...
  surfaceSalinity/...
```

Tiles are TMS-compatible, generated at zoom levels 2-4 with 256×256 pixel size. Dynamic tiles for distAnt data are generated on-demand in server.R:268-393 using terra/gdal.

### Data Processing Pipeline (dataprep/)

- **getdata.R**: Functions to fetch data from Copernicus Marine Service via Python's `copernicusmarine` module (uses reticulate). Handles dataset transitions (e.g., multi-year vs near-real-time salinity data).
- **wrangledata.R**: Time series and spatial aggregation functions. Key functions:
  - `annual_summaries()`: Aggregate monthly netCDF data to annual averages
  - `timeperiod_averages()`: Calculate 9-year period means and variability
  - `extents_and_sums()`: Process sea ice extent/days from concentration data
  - `maketiles()`: Convert rasters to leaflet tiles with color palettes
- **makeplots.R**: Highcharts plotting functions (currently unused in app but available for future features)

### Key Spatial Features

- **Weddell Gyre**: Defined by corner coordinates in global.R:46-66
- **CCAMLR Areas**: Statistical areas/subareas/divisions loaded from `www/statisticalAreasCCAMLR/`
- **Management Units**: Loaded from `www/mgmtAreas/`
- **WOBEC Study Area**: Clipped intersection stored in `www/studyAreaWOBEC/`
- **Points of Interest**: Kap Norvegia (71.33°S, 12.30°W), Maud Rise center (65.46°S, 2.95°E)

## Data Sources

All environmental data from Copernicus Marine Service:
- **Chlorophyll-a**: `c3s_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M`
- **Sea Ice**: `cmems_mod_glo_phy_my_0.083deg_P1D-m` (pre-2021) + `cmems_mod_glo_phy_myint_0.083deg_P1D-m` (2021+)
- **Salinity**: `cmems_obs-mob_glo_phy-sss_my_multi_P1M` (pre-2023) + `cmems_obs-mob_glo_phy-sss_nrt_multi_P1M` (2023+)

Species occurrence data from GBIF API with Antarctic Polar Stereographic tiles.

## Important Implementation Details

### Map Synchronization
Both maps (map1, map2) use `leaflet.extras::syncWith()` to maintain synchronized view/zoom (server.R:129-130).

### User File Uploads
Shapefiles must be uploaded as .zip archives. The app:
1. Extracts to temporary directory
2. Simplifies geometries >800KB using rmapshaper
3. Transforms to EPSG:4326 if needed
4. Adds to both maps with black outline, no fill

Upload limit: 30MB (server.R:425)

### GDAL/Terra Raster Processing
When generating tiles on-the-fly (distAnt or new data):
1. Download raster → reproject to EPSG:4326 → crop to -50°S
2. Reproject to EPSG:3031 → resample to 8192×8192 template
3. Stretch to 0-255 using 2nd/98th percentiles
4. Convert to INT1U with viridis color table
5. gdal_translate → gdal2tiles.py to generate TMS tiles

### Session Management
Each session creates a temporary directory for dynamic tiles, cleaned up on session end (server.R:483-485).

## Key R Packages

- **Spatial**: sf, terra
- **Shiny**: shiny, bslib, leaflet, leaflet.extras, leaflet.minicharts
- **Data**: dplyr, tidyr, stringr, here
- **API**: httr2, jsonlite, curl
- **Python interop**: reticulate (for Copernicus Marine API)

## Common Modifications

### Adding New Environmental Variables
1. Add data download function to `dataprep/getdata.R` following `get_chla()` pattern
2. Process with `dataprep/wrangledata.R` functions to generate 3-period averages
3. Create tiles using `maketiles()` function
4. Add to `allrasters` list in global.R
5. Update caption logic in server.R:133-162 if needed

### Adding New Basemap Layers
Add `addTiles()` call to basemap definition (server.R:59-126) with appropriate pane and options.

### Modifying Time Periods
Currently hardcoded as 9-year periods (1998-2006, 2007-2015, 2016-2024). To change:
- Update loops in `dataprep/wrangledata.R` functions (e.g., `(9*i-8):(9*i)`)
- Regenerate all tiles
- Update layer names in global.R `allrasters` list

## UI Styling System

### Design System (www/style.css)

The app uses a modern design system with CSS custom properties (design tokens) defined in `:root`:

**Key Variables:**
- **Colors**: `--primary-blue`, `--secondary-blue`, `--accent-green`, plus light variations
- **Shadows**: `--shadow-soft`, `--shadow-medium` for consistent depth
- **Border Radius**: `--border-radius-sm` (12px), `--border-radius-md` (20px), `--border-radius-lg` (40px)
- **Transitions**: `--transition-smooth` for consistent animations

**To modify the color scheme**: Update CSS variables at the top of `www/style.css` rather than individual selectors.

### Visual Design Patterns

**Glassmorphism**: Applied to navigation menu, map input panel, data section headers, and map captions using `backdrop-filter: blur()` for a modern, layered aesthetic.

**Gradients**: Used on backgrounds, buttons, and overlays for depth and visual interest.

**Micro-interactions**:
- Box hover: Slide right effect with shadow increase
- Button hover: Lift effect (-2px transform)
- Input focus: Green accent border with glow
- All transitions use smooth cubic-bezier timing (0.3s)

**Animations**: Fade-in animations (0.6s ease-out) applied to content boxes, maps, and input panels using keyframe animations.

### Typography

- **Hierarchy**: H2 (98px) → H3 (40px) → Body (13px)
- **Weights**: 700 (headings) → 600 (subheadings) → 400 (body)
- **Font smoothing**: `-webkit-font-smoothing: antialiased` for crisp rendering
- **Letter spacing**: Negative on large headings (-2px), positive on UI elements (0.5px)

### Accessibility

- **Focus states**: All interactive elements have visible green accent focus borders
- **Color contrast**: WCAG compliant color combinations
- **Motion**: Animations respect `prefers-reduced-motion` media query
- **Smooth scrolling**: CSS scroll-behavior with snap points for section navigation

### Responsive Design

- Background attachments change to `scroll` on mobile for performance
- Existing media queries preserved for layout adjustments
- Touch-friendly sizing maintained for interactive elements

### Future Enhancement Opportunities

- Dark mode toggle
- Loading animations/skeleton screens for data loading
- Progress indicators for map tile loading
- Enhanced tooltips with animations
- Interactive legend with hover effects

## File Structure Notes

- `www/distAnt.csv`: DistAnt model raster URLs and metadata for dynamic tile generation
- `www/tsdata.csv`: Time series data (currently unused, commented out in server.R:462-481)
- `www/images/`: Static assets for HTML template
- `www/modules/`: Additional assets or modules
- `www/style.css`: Custom CSS with design tokens and modern UI patterns (glassmorphism, gradients, animations)
- `index.html`: Main HTML template with placeholders for Shiny inputs/outputs
