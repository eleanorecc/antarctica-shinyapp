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
library(leaflet.minicharts)
library(curl)
library(httr2)
library(jsonlite)
library(reticulate)
library(sf)
library(terra)
library(r2d3)
library(ggplot2)


## directories and files ----
dirData <- here("www")
if(length(list.files(dirData)) == 0){
  message(
    "dirData is not found-- if on a remote server,
    check that the drive is mounted \n"
  )
}
ts_data <- read.csv(file.path(dirData, "tsdata.csv"))
distant_data <-  read.csv(file.path(dirData, "distant.csv"))

## python configuration ----
## local: use pyenv virtualenv (for Positron GUI)
## shinyapps.io: auto-detects system Python
if(Sys.getenv("SHINY_PORT") == ""){
  pyenv_root <- Sys.getenv("PYENV_ROOT", file.path(Sys.getenv("HOME"), ".pyenv"))
  pyenv_python <- file.path(pyenv_root, "versions/antarctica-shinyapp/bin/python")

  if(file.exists(pyenv_python)){
    use_python(pyenv_python, required = TRUE)
  } else {
    stop(paste(
      "Python virtualenv not found at: ", pyenv_python, "\n",
      "Run: pyenv virtualenv 3.11.0 antarctica-shinyapp"
    ))
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

## https://github.com/ccamlr/data/tree/main/geographical_data/ssmu
# ssmu <- st_read(file.path(dirData, "mgmtAreasCCAMLR"))
mgmt <- st_read(file.path(dirData, "mgmtAreas"))

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
zooms <- 0:6
extent <- 12367396.2185
resolutions <- 2*extent/256/2^zooms
dims <- rep(256*2^5, 2)

allrasters <- list(
  `Chlorophyll A` = list(
    `1998-2006` = "chlorophyllA_19982006",
    `2007-2015` = "chlorophyllA_20072015",
    `2016-2024` = "chlorophyllA_20162024",
    `2007-2015 minus 1998-2006` = "chlorophyllA_20072015diff",
    `2016-2024 minus 1998-2006` = "chlorophyllA_20162024diff"
  ),
  `Chlorophyll A Summer` = list(
    `1998-2006` = "chlorophyllA_Summer_19982006",
    `2007-2015` = "chlorophyllA_Summer_20072015",
    `2016-2024` = "chlorophyllA_Summer_20162024",
    `2007-2015 minus 1998-2006` = "chlorophyllA_Summer_20072015diff",
    `2016-2024 minus 1998-2006` = "chlorophyllA_Summer_20162024diff"
  ),
  `Chlorophyll A Winter` = list(
    `1998-2006` = "chlorophyllA_Winter_19982006",
    `2007-2015` = "chlorophyllA_Winter_20072015",
    `2016-2024` = "chlorophyllA_Winter_20162024",
    `2007-2015 minus 1998-2006` = "chlorophyllA_Winter_20072015diff",
    `2016-2024 minus 1998-2006` = "chlorophyllA_Winter_20162024diff"
  ),
  `Sea Ice Days` = list(
    `1998-2006` = "seaiceDays_19982006",
    `2007-2015` = "seaiceDays_20072015",
    `2016-2024` = "seaiceDays_20162024",
    `2007-2015 minus 1998-2006` = "seaiceDays_20072015diff",
    `2016-2024 minus 1998-2006` = "seaiceDays_20162024diff"
  ),
  `Sea Ice Min Extent` = list(
    `1998-2006` = "seaiceMinExtent_19982006",
    `2007-2015` = "seaiceMinExtent_20072015",
    `2016-2024` = "seaiceMinExtent_20162024"
  ),
  `Surface Salinity` = list(
    `1998-2006` = "surfaceSalinity_19982006",
    `2007-2015` = "surfaceSalinity_20072015",
    `2016-2024` = "surfaceSalinity_20162024",
    `2007-2015 minus 1998-2006` = "surfaceSalinity_20072015diff",
    `2016-2024 minus 1998-2006` = "surfaceSalinity_20162024diff"
  ),
  `Surface Salinity Summer` = list(
    `1998-2006` = "surfaceSalinity_Summer_19982006",
    `2007-2015` = "surfaceSalinity_Summer_20072015",
    `2016-2024` = "surfaceSalinity_Summer_20162024",
    `2007-2015 minus 1998-2006` = "surfaceSalinity_Summer_20072015diff",
    `2016-2024 minus 1998-2006` = "surfaceSalinity_Summer_20162024diff"
  )
)

caption_metadata <- data.frame(
  layer_pattern = c("chlorophyll", "seaice", "salinity"),
  title = c("Chlorophyll A Data", "Sea Ice Data", "Salinity Data"),
  description = c(
    "Chlorophyll A averages calculated from Copernicus Marine Dataset:",
    "Sea Ice averages and minimums calculated (taking >15% covered area as 'ice covered') from Copernicus Marine Dataset:",
    "Salinity averages calculated from Copernicus Marine Dataset:"
  ),
  dataset_name = c(
    "c3s_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M",
    "cmems_mod_glo_phy_my_0.083deg_P1D-m",
    "cmems_obs-mob_glo_phy-sss_my_multi_P1M"
  ),
  url = c(
    "https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_108/services",
    "https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/service",
    "https://data.marine.copernicus.eu/product/MULTIOBS_GLO_PHY_S_SURFACE_MYNRT_015_013/services"
  ),
  stringsAsFactors = FALSE
)

