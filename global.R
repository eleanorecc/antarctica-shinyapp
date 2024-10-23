## packages ----
library(httr)
library(curl)
library(jsonlite)
library(dplyr)
library(stringr)
library(lubridate)
library(terra)
library(sf)
library(shiny)
library(bslib)
library(leaflet)
library(leafem)
library(leaflet.extras)
library(highcharter)


## directories ----
dirData <- "/home/ellie/data/antarctic-data-wobec"
if(length(list.files(dirData)) == 0){
  message(
    "dirData is not found-- if on a remote server,
    check that the drive is mounted \n"
  )
}

## plotting functions ----
source(here::here("R", "makeplots.R"))

## datasets ----

## used in preparing the data
## and setting the leaflet map crs
tile_size <- 512
# gbif_extent <- 12367396.2185

## https://data.bas.ac.uk/items/aaec1295-b0a8-4c49-a751-d964c326ce8d/
coast <- file.path(dirData, "coastline-medium") |>
  st_read() |>
  st_transform("EPSG:4326")


data <- list(
  `Polarview Ice Concentration` = list(
    rast_filepath = file.path(dirData, "www.polarview.aq"),
    tiles_filepath = file.path(dirData, "www.polarview.aq", "tiles"),
    layernames = c("2023-09-01", "2023-10-01", "2023-11-01", "2023-12-01"),
    ylab = "Ice Concentration (%)"
  )
)
