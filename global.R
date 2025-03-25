## concise version of what is needed for the stakeholder workshop

## maps in 3 decades + recent: 1990s, 2000s, 2010s, 2020-2025
## mean and standard deviation for each


## use data from 3 variables:
## (1) sea ice - extent, concentration, thickness
## (2) primary production - ocean color and compare to cholophyll a
## (3) salinity

## packages ----
library(here)
library(dplyr)
library(tidyr)
library(stringr)
library(sf)
library(shiny)
library(bslib)
library(leaflet)
library(leaflet.extras)
library(leaflet.minicharts)
library(plotly)

## directories ----
dirData <- here("data")
if(length(list.files(dirData)) == 0){
  message(
    "dirData is not found-- if on a remote server,
    check that the drive is mounted \n"
  )
}

## datasets ----

## used in preparing the data
## and setting the leaflet map crs

## boundaries of weddell gyre
## https://doi.org/10.15784/601652
## https://eos.org/editors-vox/science-in-a-frozen-ocean
weddell_gyre_corners <- data.frame(
  lat = c(-50, -50, -80, -80, -50),
  lon = c(-60, 40, 40, -60, -60)
)
weddell_gyre_coords <- data.frame(
  lat = c(
    rep(max(weddell_gyre_corners$lat), 100),
    rep(min(weddell_gyre_corners$lat), 100),
    max(weddell_gyre_corners$lat)
  ),
  lon = c(
    seq(min(weddell_gyre_corners$lon), max(weddell_gyre_corners$lon), length.out = 100),
    seq(max(weddell_gyre_corners$lon), min(weddell_gyre_corners$lon), length.out = 100),
    min(weddell_gyre_corners$lon)
  )
)
weddell_gyre <- weddell_gyre_coords |>
  st_as_sf(coords = c("lon", "lat")) |>
  st_combine() |>
  st_cast("POLYGON") |>
  st_set_crs(st_crs(4326))


## add wobecs study area on top
wobec <- st_read(file.path(dirData, "studyAreaWOBEC")) |>
  st_transform(st_crs(4326))

## ccamlr statistical areas, subareas, divisions
## https://github.com/ccamlr/data/tree/main/geographical_data/asd
asd <- st_read(file.path(dirData, "statisticalAreasCCAMLR"))


## other datsets...

## https://add.scar.org/

## high resolution polygons for coastline
## https://data.bas.ac.uk/items/4ecd795d-e038-412f-b430-251b33fc880e/

## high resolution polygons for seamask, CC BY 4.0 license
## https://data.bas.ac.uk/items/9288fd09-681b-4377-84b2-6ab9b9c6c05d/



## also extract time series for 2 areas
## (1) kap norvega
## (2) maud rise sea mound

## https://www.marineregions.org/gazetteer.php?p=details&id=22139
## https://latitude.to/articles-by-country/aq/antarctica/259278/cape-norvegia
kap_norvegia <- data.frame(lat = -71.333332, lon = -12.2999988) |>
  st_as_sf(coords = c("lon", "lat")) |>
  st_set_crs(st_crs(4326))


## https://www.marineregions.org/gazetteer.php?p=details&id=6990
maud_rise_coords <- data.frame(
  lat = c(-67.5, -63.5, -63.5, -67.5, -67.5),
  lon = c(7.5, 7.5, -1.0, -1.0, 7.5)
)
maud_rise <- maud_rise_coords |>
  st_as_sf(coords = c("lon", "lat")) |>
  st_combine() |>
  st_cast("POLYGON") |>
  st_set_crs(st_crs(4326)) |>
  st_transform(st_crs(3031))

maud_rise_center <- data.frame(lat = -65.46003868, lon = 2.95221053) |>
  st_as_sf(coords = c("lon", "lat")) |>
  st_set_crs(st_crs(4326))


## for map
## and processing spatial data
zooms <- 0:6
extent <- 12367396.2185
resolutions <- 2*extent/256/2^zooms

# tiffs <- list.files(file.path(getwd(),"data"), recursive = TRUE, full.names = TRUE, pattern = ".tif")
# saveDir <- dirname(tiffs)
# saveDir[2:3] <- paste0(saveDir[2:3], c("/Summer", "/Winter"))
# mapply(function(x,y){maketiles(x,y)}, tiffs, saveDir)


# tsdata <- bind_rows(
#   read.csv(file.path(dirData, "seaiceDays", "seaice_icedays.csv")) |>
#     mutate(
#       yaxislabel = "Number of Days with Ice-Cover > 15%, Area Average",
#       plot_with = "iceDays"
#     ) |>
#     select(plot_with, year, yvariable = yrwgtmean, yaxislabel),
#   read.csv(file.path(dirData, "seaiceMinExtent", "seaice_coverage_minext.csv")) |>
#     mutate(coveragearea = coveragearea/1e6) |>
#     pivot_longer(cols = c(day_of_year, coveragearea)) |>
#     mutate(
#       yaxislabel = ifelse(
#         name == "coveragearea",
#         "Area of Minimum Ice Extent (million km^2)",
#         "Day of the Year with Minimum Ice Extent"
#       ),
#       plot_with = "minIceExtent"
#     ) |>
#     select(plot_with, year, yvariable = value, yaxislabel),
#   read.csv(file.path(dirData, "chlorophyllA", "timeperiod_chla.csv")) |>
#     mutate(
#       yaxislabel = "Chlorophyll-a (mg m^-3)",
#       plot_with = paste0("chla", months)
#     ) |>
#     select(plot_with, year, yvariable = yrwgtmean, yaxislabel),
#   read.csv(file.path(dirData, "surfaceSalinity", "timeperiod_salinity.csv")) |>
#     mutate(
#       yaxislabel = "Salinity (PSU)",
#       plot_with = "annualSalinity"
#     ) |>
#     select(plot_with, year, yvariable = yrwgtmean, yaxislabel)
# )
# write.csv(tsdata, file.path(dirData, "tsdata.csv"), row.names = FALSE)
tsdata <- read.csv(file.path(dirData, "tsdata.csv"))

