## packages ----
library(here)
library(dplyr)
library(tidyr)
library(stringr)
library(shiny)
library(bslib)
library(shinyjs)
library(leaflet)
library(leaflet.extras)
library(leaflet.extras2)
library(leaflet.minicharts)
library(curl)
library(httr2)
library(jsonlite)
library(reticulate)
library(lubridate)
library(sf)
library(terra)
library(ncdf4)
library(r2d3)
library(ggplot2)

## if get errors with renv, can try installation with binaries
## and update renv to version installed before re-trying restore
# renv::record("geometries@0.2.5")
# renv::restore()

## directories and files ----
dirData <- here("www")
if(length(list.files(dirData)) == 0){
  message(
    "dirData is not found-- if on a remote server,
    check that the drive is mounted \n"
  )
}
ts_csv <- file.path(dirData, "tsData.csv")
if(file.exists(ts_csv)){ ts_data <- read.csv(ts_csv)}
distant_data <-  read.csv(file.path(dirData, "distAnt.csv"))

## for selectizeInput for tiles
# distrasters <- setNames(distant_data$name, distant_data$name)
distrasters <- distant_data |> 
  pull(dir) |> 
  as.list() |> 
  setNames(distant_data$name)

## python configuration ----
## check python installation with gdal
## to use gdal2tiles function via reticulate
## note shinyapps.io auto-detects system Python
if(Sys.getenv("SHINY_PORT") == ""){
  python_candidates <- c(
    ## first try pyenv virtualenv
    ## pyenv virtualenv 3.11.0 antarctica-shinyapp
    file.path(
      Sys.getenv("PYENV_ROOT", file.path(Sys.getenv("HOME"), ".pyenv")),
      "versions/antarctica-shinyapp/bin/python"
    ),
    ## next try homebrew
    "/opt/homebrew/bin/python3",
    "/usr/local/bin/python3",
    ## lastly try system python
    Sys.which("python3"),
    Sys.which("python")
  )
  valid_python <- NULL
  for(py_path in python_candidates){
    if(nzchar(py_path) && file.exists(py_path)){
      ## test python with gdal
      tryCatch({
        use_python(py_path, required = FALSE)
        py_run_string("from osgeo import gdal")
        valid_python <- py_path
        message("Using Python: ", py_path)
        break
      }, error = function(e) NULL)
    }
  }
  if(!is.null(valid_python)) {
    use_python(valid_python, required = TRUE)
  }
}


## datasets ----

## used in preparing the data
## and setting the leaflet map crs

## boundaries of weddell gyre
## https://doi.org/10.15784/601652
## https://eos.org/editors-vox/science-in-a-frozen-ocean
# latmin <- -80
# latmax <- -50
# lonmin <- -60
# lonmax <- 40
## expanding to boundaries of CCAMLR statistical areas
## from Subarea 48.1 on western side to Division 58.4.4b on eastern side
latmin <- -80
latmax <- -45
lonmin <- -70
lonmax <- 60
weddell_gyre_coords <- data.frame(
  lat = c(rep(latmax, 100), rep(latmin, 100), latmax),
  lon = c(
    seq(lonmin, lonmax, length.out = 100),
    seq(lonmax, lonmin, length.out = 100),
    lonmin
  )
)
weddell_gyre <- weddell_gyre_coords |>
  st_as_sf(coords = c("lon", "lat")) |>
  st_combine() |>
  st_cast("POLYGON") |>
  st_set_crs(st_crs(4326))

## ccamlr statistical areas, subareas, divisions
## https://github.com/ccamlr/data/tree/main/geographical_data/asd
asd <- st_read(file.path(dirData, "statisticalAreasCCAMLR"))

## add wobecs study area on top
## make the file if it doesnt yet exist
# latmin <- -75.54747
# latmax <- -60.00026
# lonmin <- -20
# lonmax <- 9.998232
# wobec_coords <- data.frame(
#   lat = c(rep(latmax, 100), rep(latmin, 100), latmax),
#   lon = c(
#     seq(lonmin, lonmax, length.out = 100),
#     seq(lonmax, lonmin, length.out = 100),
#     lonmin
#   )
# )
# subarea <- asd |> 
#   filter(GAR_Name == "Subarea 48.6") |> 
#   st_geometry()
# wobec_coords |>
#   st_as_sf(coords = c("lon", "lat")) |>
#   st_combine() |>
#   st_cast("POLYGON") |>
#   st_set_crs(st_crs(4326)) |> 
#   st_intersection(subarea) |> 
#   st_write(file.path(dirData, "studyAreaWOBEC/WOBEC_StudyArea.shp"))
wobec <- st_read(file.path(dirData, "studyAreaWOBEC"))


## other datasets...

## https://add.scar.org/

## high resolution polygons for coastline
## https://data.bas.ac.uk/items/4ecd795d-e038-412f-b430-251b33fc880e/

## high resolution polygons for seamask, CC BY 4.0 license
## https://data.bas.ac.uk/items/9288fd09-681b-4377-84b2-6ab9b9c6c05d/



## points of interest
## (1) kap norvega
## (2) maud rise sea mound

## https://www.marineregions.org/gazetteer.php?p=details&id=22139
## https://latitude.to/articles-by-country/aq/antarctica/259278/cape-norvegia
kap_norvegia <- data.frame(lat = -71.333332, lon = -12.2999988) |>
  st_as_sf(coords = c("lon", "lat")) |>
  st_set_crs(st_crs(4326))


## https://www.marineregions.org/gazetteer.php?p=details&id=6990
maud_rise_center <- data.frame(lat = -65.46003868, lon = 2.95221053) |>
  st_as_sf(coords = c("lon", "lat")) |>
  st_set_crs(st_crs(4326))


## for leaflet map
## and for processing spatial data
zooms <- 0:8
extent <- 12367396.2185
resolutions <- 2*extent/256/2^zooms
dims <- rep(256*2^5, 2)

allrasters <- list(
  `Number of Days with >15% Sea Ice` = list(
    `T0: 1998-2006` = "seaiceDays_all_19982006",
    `2007-2015` = "seaiceDays_all_20072015",
    `2016-2024` = "seaiceDays_all_20162024",
    `2007-2015 minus T0` = "seaiceDays_all_20072015diff",
    `2016-2024 minus T0` = "seaiceDays_all_20162024diff"
  ),
  `Annual Chlorophyll A` = list(
    `T0: 1998-2006` = "chlorophyllA_all_19982006",
    `2007-2015` = "chlorophyllA_all_20072015",
    `2016-2024` = "chlorophyllA_all_20162024",
    `2007-2015 minus T0` = "chlorophyllA_all_20072015diff",
    `2016-2024 minus T0` = "chlorophyllA_all_20162024diff"
  ),
  `Summer Chlorophyll A (January-March)` = list(
    `T0: 1998-2006` = "chlorophyllA_summer_19982006",
    `2007-2015` = "chlorophyllA_summer_20072015",
    `2016-2024` = "chlorophyllA_summer_20162024",
    `2007-2015 minus T0` = "chlorophyllA_summer_20072015diff",
    `2016-2024 minus T0` = "chlorophyllA_summer_20162024diff"
  ),
  `Winter Chlorophyll A (July-September)` = list(
    `T0: 1998-2006` = "chlorophyllA_winter_19982006",
    `2007-2015` = "chlorophyllA_winter_20072015",
    `2016-2024` = "chlorophyllA_winter_20162024",
    `2007-2015 minus T0` = "chlorophyllA_winter_20072015diff",
    `2016-2024 minus T0` = "chlorophyllA_winter_20162024diff"
  ),
  `Annual Surface Salinity` = list(
    `T0: 1998-2006` = "surfaceSalinity_all_19982006",
    `2007-2015` = "surfaceSalinity_all_20072015",
    `2016-2024` = "surfaceSalinity_all_20162024",
    `2007-2015 minus T0` = "surfaceSalinity_all_20072015diff",
    `2016-2024 minus T0` = "surfaceSalinity_all_20162024diff"
  ),
  `Summer Surface Salinity (January-March)` = list(
    `T0: 1998-2006` = "surfaceSalinity_summer_19982006",
    `2007-2015` = "surfaceSalinity_summer_20072015",
    `2016-2024` = "surfaceSalinity_summer_20162024",
    `2007-2015 minus T0` = "surfaceSalinity_summer_20072015diff",
    `2016-2024 minus T0` = "surfaceSalinity_summer_20162024diff"
  )
)

caption_metadata <- data.frame(
  layer_pattern = c("chlorophyll", "seaice", "salinity"),
  title = c("Chlorophyll A Data", "Sea Ice Data", "Surface Salinity Data"),
  description = c(
    "Chlorophyll A averages calculated from Copernicus Marine Dataset:",
    "Sea Ice-Days averages calculated (taking days with >15% sea ice concentrations as 'ice covered') from Copernicus Marine Dataset:",
    "Salinity averages calculated from Copernicus Marine Dataset:"
  ),
  dataset_name = c(
    "c3s_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M",
    "cmems_mod_glo_phy_my_0.083deg_P1D-m",
    "cmems_obs-mob_glo_phy-sss_my_multi_P1M"
  ),
  url = c(
    "https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_108/services",
    "https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/services",
    "https://data.marine.copernicus.eu/product/MULTIOBS_GLO_PHY_S_SURFACE_MYNRT_015_013/services"
  ),
  stringsAsFactors = FALSE
)

## caption based on map layer ----
getCaptionData <- function(layer_name) {
  if(layer_name %in% distant_data$dir) {
    info <- filter(distant_data, dir == layer_name)
    return(list(
      title = info$name,
      description = "Data accessed from SCAR DistAnt Ecological Model Output Repository",
      dataset = "https://source.coop/scar/distant",
      url = "https://source.coop/scar/distant",
      season = "",
      reference = info$reference
    ))
  }
  v <- which(str_detect(layer_name, c("chlorophyllA", "seaiceDays", "surfaceSalinity")))
  s <- str_to_title(str_extract(layer_name, "summer|winter"))
  if(length(v) == 1){
    return(list(
      title = caption_metadata$title[v],
      description = caption_metadata$description[v],
      dataset = caption_metadata$dataset_name[v],
      url = caption_metadata$url[v],
      season = ifelse(is.na(s), "", s),
      reference = ""
    ))
  }
  return(list(
    title = "Data Layer", 
    description = "", 
    dataset = "", 
    url = "", 
    reference = ""
  ))
}
renderCaption <- function(caption_data) {
  tags$div(
    tags$p(class = "caption-title", caption_data$title),
    tags$p(
      class = "intro-text",
      caption_data$description,
      if(nzchar(caption_data$dataset) && nzchar(caption_data$url)) {
        tagList(
          tags$br(),
          tags$a(href = caption_data$url, target = "_blank", style = "color:#205d9e", caption_data$dataset)
        )
      }
    ),
    if(nzchar(caption_data$reference)) {
      tags$p(class = "caption-reference", caption_data$reference)
    }
  )
}

## generate HTML for a custom positioned legend
## side: "left" or "right" — controls which corner-icon variant is used
legendHTML <- function(palette_df, breaks, side = c("left", "right")) {
  side <- match.arg(side)
  pal <- colorBin(
    palette = palette_df$col,
    domain  = range(breaks),
    bins    = breaks,
    pretty  = FALSE
  )
  colors <- pal(breaks[-length(breaks)] + diff(breaks) / 2)
  ## sea-ice-days ranges span >30 (0-366 raw, ~50-300 for diffs) while
  ## chlorophyll/salinity stay well under that - use whole integers for the
  ## former (never needs sub-day precision or scientific notation). Tighter
  ## spreads (e.g. chlorophyll/salinity's sub-1 ranges) need 4 decimals to
  ## stay meaningful; wider small spreads use 2. Drop the outer breaks
  ## (often extreme outliers) so a couple of far-flung bin edges don't
  ## distort how tightly packed the legend entries actually are.
  inner_breaks <- if (length(breaks) > 3) breaks[-c(1, length(breaks))] else breaks
  spread <- diff(range(inner_breaks))
  labels <- if (spread > 30) {
    sprintf("%d", round(breaks))
  } else if (spread < 4) {
    sprintf("%.4f", breaks)
  } else {
    sprintf("%.2f", breaks)
  }
  items  <- paste0(
    '<div style="display:flex;align-items:center;margin-bottom:1px;">',
    '<i style="background:', colors,
    ';width:18px;height:8px;display:inline-block;margin-right:5px;"></i>',
    '<span style="font-size:10px;">', labels[-length(labels)], ' &ndash; ', labels[-1], '</span>',
    '</div>',
    collapse = ""
  )
  paste0(
    '<div class="legend-custom legend-', side, '">',
    '<a href="#" class="legend-arrow" role="button" aria-label="Toggle legend" onclick="',
    'event.preventDefault();this.closest(\'.legend-custom\').classList.toggle(\'legend-collapsed\');',
    '"><i class="fa-solid fa-up-right-from-square"></i></a>',
    '<div class="legend-items">', items, '</div>',
    '</div>'
  )
}

## Polarstern expedition coordinates
## now that the cruise is finished, read from get_cruise_data script
coords_wobec <- read.csv(file.path(dirData, "coords_polarstern_wobec.csv")) |> 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |> 
  summarise(geometry = st_cast(st_combine(geometry), "LINESTRING"))

coords_hafos <- read.csv(file.path(dirData, "coords_polarstern_hafos.csv")) |> 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |> 
  summarise(geometry = st_cast(st_combine(geometry), "LINESTRING"))


## Cruise data
cruise_data <- read.csv(file.path(dirData, "cruise_data.csv")) |>
  st_as_sf(wkt = "geometry", crs = 4326)

## vectors of devices for selectize inputs
devices_wobec <- cruise_data |> 
  st_drop_geometry() |> 
  filter(cruise == "wobec") |> 
  group_by(method_device) |> 
  summarize(count = n()) |> 
  arrange(desc(count)) |> 
  pull(method_device)

devices_hafos <- cruise_data |> 
  st_drop_geometry() |> 
  filter(cruise == "hafos") |> 
  group_by(method_device) |> 
  summarize(count = n()) |> 
  arrange(desc(count)) |> 
  pull(method_device)


## for deploying app
## only include these files!
# rsconnect::deployApp(
#     appName = "wobec-summary-data",
#     account = "ocean-src",
#     appFiles = c(
#       "global.R",
#       "ui.R",
#       "server.R",
#       "requirements.txt",
#       "renv.lock",
#       "index.html",
#       "www/images",
#       "www/style.css",
#       "www/distAnt.csv",
#       "www/tsData.csv",
#       "www/coords_polarstern_wobec.csv",
#       "www/coords_polarstern_hafos.csv",
#       "www/cruise_data.csv",
#       "www/distAnt",
#       "www/chlorophyllA/all",
#       "www/chlorophyllA/summer",
#       "www/chlorophyllA/winter",
#       "www/surfaceSalinity/all",
#       "www/surfaceSalinity/summer",
#       "www/surfaceSalinity/winter",
#       "www/seaiceDays/all",
#       "www/statisticalAreasCCAMLR",
#       "www/studyAreaWOBEC"
#     )
#   )