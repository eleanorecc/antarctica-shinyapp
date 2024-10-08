## packages ----
library(httr)
library(dplyr)
library(stringr)
library(lubridate)
library(blueant)
library(terra)
library(sf)
library(shiny)
library(bslib)
library(leaflet)
library(leafem)
library(leaflet.extras)
library(highcharter)


## directories ----
dirData <- here::here("data")
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
gbif_tile_size <- 512
extent <- 12367396.2185


data <- list(
  `Polarview Ice Concentration` = list(
    rast_filepath = file.path(dirData, "www.polarview.aq"),
    tiles_filepath = file.path(dirData, "www.polarview.aq", "tiles"),
    layernames = c("2023-09-01", "2023-10-01", "2023-11-01", "2023-12-01"),
    ylab = "Ice Concentration (%)"
  )
)
