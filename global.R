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


extent <- 12367396.2185

allrasters <- list(
  `Chlorophyll A` = list(
    `1998-2006` = "chlorophyllA_19982006",
    `2007-2015` = "chlorophyllA_20072015",
    `2016-2024` = "chlorophyllA_20162024",
    `2007-2015 vs 1998-2006` = "chlorophyllA_2007diff",
    `2016-2024 vs 1998-2006` = "chlorophyllA_2016diff"
  ),
  `Chlorophyll A Summer` = list(
    `1998-2006` = "chlorophyllA_Summer_19982006",
    `2007-2015` = "chlorophyllA_Summer_20072015",
    `2016-2024` = "chlorophyllA_Summer_20162024",
    `2007-2015 vs 1998-2006` = "chlorophyllA_Summer_2007diff",
    `2016-2024 vs 1998-2006` = "chlorophyllA_Summer_2016diff"
  ),
  `Chlorophyll A Winter` = list(
    `1998-2006` = "chlorophyllA_Winter_19982006",
    `2007-2015` = "chlorophyllA_Winter_20072015",
    `2016-2024` = "chlorophyllA_Winter_20162024",
    `2007-2015 vs 1998-2006` = "chlorophyllA_Winter_2007diff",
    `2016-2024 vs 1998-2006` = "chlorophyllA_Winter_2016diff"
  ),
  `Sea Ice Days` = list(
    `1998-2006` = "seaiceDays_19982006",
    `2007-2015` = "seaiceDays_20072015",
    `2016-2024` = "seaiceDays_20162024",
    `2007-2015 vs 1998-2006` = "seaiceDays_2007diff",
    `2016-2024 vs 1998-2006` = "seaiceDays_2016diff"
  ),
  `Sea Ice Min Extent` = list(
    `1998-2006` = "seaiceMinExtent_19982006",
    `2007-2015` = "seaiceMinExtent_20072015",
    `2016-2024` = "seaiceMinExtent_20162024",
    `2007-2015 vs 1998-2006` = "seaiceMinExtent_2007diff",
    `2016-2024 vs 1998-2006` = "seaiceMinExtent_2016diff"
  ),
  `Surface Salinity` = list(
    `1998-2006` = "surfaceSalinity_19982006",
    `2007-2015` = "surfaceSalinity_20072015",
    `2016-2024` = "surfaceSalinity_20162024",
    `2007-2015 vs 1998-2006` = "surfaceSalinity_2007diff",
    `2016-2024 vs 1998-2006` = "surfaceSalinity_2016diff"
  )
)

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

# data <- list(
#   `Polarview Ice Concentration` = list(
#     rast_filepath = file.path(dirData, "www.polarview.aq"),
#     tiles_filepath = file.path(dirData, "www.polarview.aq", "tiles"),
#     layernames = c("2023-09-01", "2023-10-01", "2023-11-01", "2023-12-01"),
#     ylab = "Ice Concentration (%)"
#   )
# )
