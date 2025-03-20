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
library(sf)
library(shiny)
library(leaflet)
# library(leafem)
# library(leaflet.extras)
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
weddell_gyre_coords <- data.frame(
  lat = c(-60, -50, -80, -80, -60),
  lon = c(-60, 40, 40, -60, -60)
)
weddell_gyre <- weddell_gyre_coords |>
  st_as_sf(coords = c("lon", "lat")) |>
  st_combine() |>
  st_cast("POLYGON") |>
  st_set_crs(st_crs(4326)) |>
  st_transform(st_crs(3031))


## ccamlr statistical areas, subareas, divisions
## https://github.com/ccamlr/data/tree/main/geographical_data/asd
asd <- st_read(file.path(dirData, "statisticalAreasCCAMLR")) |>
  st_transform(st_crs(3031))


## https://add.scar.org/

## high resolution polygons for coastline
## https://data.bas.ac.uk/items/4ecd795d-e038-412f-b430-251b33fc880e/
coast <- st_read(file.path(dirData, "add_coastline_high_res_polygon_v7_10"))

## high resolution polygons for seamask, CC BY 4.0 license
## https://data.bas.ac.uk/items/9288fd09-681b-4377-84b2-6ab9b9c6c05d/
seamask <- st_read(file.path(dirData, "add_seamask_high_res_v7_10"))


## shapefile from Katharina Teschke at awi
## add shapefile of study area on top
wobec <- st_read(file.path(dirData, "studyAreaWOBEC")) |>
  st_transform(st_crs(3031))


## will extract time series for 2 areas
## (1) kap norvega
## (2) maud rise sea mound

## https://www.marineregions.org/gazetteer.php?p=details&id=22139
## https://latitude.to/articles-by-country/aq/antarctica/259278/cape-norvegia
kap_norvega <- data.frame(x = -71.333332, y = -12.2999988) |>
  st_as_sf(coords = c("x", "y")) |>
  st_set_crs(st_crs(4326)) |>
  st_transform(st_crs(3031))


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
  st_set_crs(st_crs(4326)) |>
  st_transform(st_crs(3031))


## for the shiny app
gbif_tile_size <- 512
extent <- 12367396.2185
# data <- list(
#   `Polarview Ice Concentration` = list(
#     rast_filepath = file.path(dirData, "www.polarview.aq"),
#     tiles_filepath = file.path(dirData, "www.polarview.aq", "tiles"),
#     layernames = c("2023-09-01", "2023-10-01", "2023-11-01", "2023-12-01"),
#     ylab = "Ice Concentration (%)"
#   )
# )
