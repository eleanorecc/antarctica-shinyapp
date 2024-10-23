## packages ----
library(here)
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
dirShiny <- here()
dirData <- "/home/ellie/data/antarctic-data-wobec"
if(length(list.files(dirData)) == 0){
  message(
    "dirData is not found-- if on a remote server,
    check that the drive is mounted \n"
  )
}

## plotting functions ----
source(here("R", "makeplots.R"))

## datasets ----
data <- list(
  `Monthly Maximum Temperature` = list(
    filepaths = file.path(dirData, "Reanalysis-NCEP-DOE", "tmax_2m_mon_mean.nc"),
    rastfile = file.path(dirShiny, "data", "tmax_rast"),
    tilesfolder = file.path(dirShiny, "www", "tmax_tiles"),
    layernames = c(),
    attrib = "NCEP/DOE",
    plotyrange = c(),
    ylab = "Monthly Max Temp (degC)"
  ),
  `Wind Speeds, Monthly Mean` = list(
    filepaths = file.path(dirData, "Reanalysis-NCEP-DOE", "wspd_10m_mon_mean.nc"),
    rastfile = file.path(dirShiny, "data", "wind_rast"),
    tilesfolder = file.path(dirShiny, "www", "wind_tiles"),
    layernames = c(),
    attrib = "NCEP/DOE",
    plotyrange = c(),
    ylab = "Wind Speed (m/s)"
  ),
  `Monthly Mean Temperature 1-20m BGL` = list(
    filepaths = file.path(dirData, "Reanalysis-NCEP-DOE", "tmp_10-200cm_mon_mean.nc"),
    rastfile = file.path(dirShiny, "data", "tmp20m_rast"),
    tilesfolder = file.path(dirShiny, "www", "tmp20m_tiles"),
    layernames = c(),
    attrib = "NCEP/DOE",
    plotyrange = c(),
    ylab = "Temperature (degC)"
  ),
  ## https://topex.ucsd.edu/marine_topo/
  ## https://topex.ucsd.edu/pub/global_topo_1min/README_PERMISSIONS.txt
  `Seafloor Topography` = list(
    filepaths = file.path(dirData, "DEM", "topo_25.1.nc"),
    rastfile = file.path(dirShiny, "data", "bathy_rast"),
    tilesfolder = file.path(dirShiny, "www", "bathy_tiles"),
    layernames = c("Depths"),
    attrib = "Smith and Sandwell 1997",
    plotyrange = c(),
    ylab = ""
  ),
  ## https://tc.copernicus.org/preprints/tc-2017-223/tc-2017-223.pdf
  `Digital Elevation Model of Antarctica` = list(
    filepaths = file.path(dirData, "DEM", "Antarctica_Cryosat2_1km_DEMv1.0.tif"),
    rastfile = file.path(dirShiny, "data", "dem_rast"),
    tilesfolder = file.path(dirShiny, "www", "dem_tiles"),
    layernames = c("Elevation"),
    attrib = "Slater, Shepherd, et al 2017",
    plotyrange = c(0, 4100),
    ylab = "Elevation (m) drived from data acquired July 2010-16"
  )
)

tile_size <- 512

## National Ice Center Antarctic daily sea ice charts
usnic <- "https://usicecenter.gov/File/DownloadArchive?prd=22"
nic_zip <- file.path(dirShiny, "www", "tmp.kmz")
nic_dir <- file.path(dirShiny, "www", "tmp")

pal <- colorFactor(
  c("#5de5a1","#31abf2"),
  c("CT81","CT18")
)

