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
library(ggplot2)
library(httr2)
library(jsonlite)
library(curl)

## directories ----
dirData <- here("www")
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

## ccamlr statistical areas, subareas, divisions
## https://github.com/ccamlr/data/tree/main/geographical_data/asd
asd <- st_read(file.path(dirData, "statisticalAreasCCAMLR"))

## https://github.com/ccamlr/data/tree/main/geographical_data/ssmu
# ssmu <- st_read(file.path(dirData, "mgmtAreasCCAMLR"))
mgmt <- st_read(file.path(dirData, "mgmtAreas"))

## add wobecs study area on top
# st_write(st_intersection(
#   st_set_agr(st_transform(studyAreaWOBECbox, st_crs(4326)), "constant"),
#   st_geometry(filter(asd, GAR_Name == "Subarea 48.6"))
# ), file.path(dirData, "studyAreaWOBEC/WOBEC_StudyArea.shp"))
wobec <- st_transform(st_read(file.path(dirData, "studyAreaWOBEC")), st_crs(4326))


## other datasets...

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


# chla <- bind_rows(
#   read.csv(file.path(dirData, "chlorophyllA", "timeperiod_all_months_chla.csv")) |>
#     mutate(plot_with = "chlorophyllA") |>
#     cbind(year = 1998:2024),
#   read.csv(file.path(dirData, "chlorophyllA", "timeperiod_summer_months_chla.csv")) |>
#     mutate(plot_with = "chlorophyllA_Summer") |>
#     cbind(year = 1998:2024),
#   read.csv(file.path(dirData, "chlorophyllA", "timeperiod_winter_months_chla.csv")) |>
#     mutate(plot_with = "chlorophyllA_Winter") |>
#     cbind(year = 1998:2024)) |>
#   mutate(yaxislabel = "Chlorophyll-a (mg m^-3)")
#
# salinity <- bind_rows(
#   read.csv(file.path(dirData, "surfaceSalinity", "timeperiod_all_months_salinity.csv")) |>
#     mutate(plot_with = "surfaceSalinity") |>
#     cbind(year = 1998:2024),
#   read.csv(file.path(dirData, "surfaceSalinity", "timeperiod_summer_months_salinity.csv")) |>
#     mutate(plot_with = "surfaceSalinity_Summer") |>
#     cbind(year = 1998:2024)) |>
#   mutate(yaxislabel = "Salinity (PSU)")
#
# icedays <- read.csv(file.path(dirData, "seaiceDays", "seaice_icedays.csv")) |>
#   mutate(plot_with = "seaiceDays") |>
#   mutate(yaxislabel = "Number of Days with Ice-Cover > 15%, Area Average") |>
#   cbind(year = 1998:2024)
# iceext <- read.csv(file.path(dirData, "seaiceMinExtent", "seaice_coverage_minext.csv")) |>
#   mutate(coveragearea = coveragearea/1e6) |>
#   pivot_longer(cols = c(index, coveragearea), values_to = "yrwgtmean") |>
#   mutate(plot_with = "seaiceMinExtent") |>
#   mutate(yaxislabel = ifelse(
#     name == "coveragearea",
#     "Area of Minimum Ice Extent (million km^2)",
#     "Day of the Year with Minimum Ice Extent"
#   ))
# bind_rows(chla, salinity, icedays, iceext) |>
#   select(plot_with, year, yvariable = yrwgtmean, yaxislabel) |>
#   write.csv(file.path(dirData, "tsdata.csv"), row.names = FALSE)

tsdata <- read.csv(file.path(dirData, "tsdata.csv"))


rast2tile <- function(url, lyrnum, saveDir){
  require(terra)
  require(dplyr)

  ## download the raster
  tmptif <- file.path(saveDir, "rast0.tif")
  download.file(url, destfile = tmptif)

  ## project to sterographic south after cropping
  r <- project(rast(tmptif, lyrs = lyrnum), "EPSG:4326") |>
    crop(ext(c(-180, 180, -90, -50))) |>
    project("EPSG:3031")

  ## resample to match leaflet map tiles/extent
  x <- 12367396.2185
  template <- rast(ext(c(-x,x,-x,x)), nrow = 8192, ncol = 8192, crs = crs("EPSG:3031"))
  rresamp <- resample(r, template)

  pal <- data.frame(value = 0:255, col = hcl.colors(256, "viridis"))
  values(rresamp) |>
    quantile(probs = seq(0, 1, length.out = 256), na.rm = TRUE) |>
    data.frame() |>
    cbind(pal) |>
    setNames(c("breaks","value","col")) |>
    write.csv(
      file.path(saveDir, "palette.csv"),
      row.names = FALSE
    )

  rint <- rresamp |>
    stretch(minq = 0.02, maxq = 0.98, minv = 0, maxv = 255) |>
    as.int(datatype = "INT1U")
  coltab(rint) <- pal

  writeRaster(
    rint, file.path(saveDir, "rint.tif"),
    datatype = "INT1U",
    overwrite = TRUE
  )
  system(paste(
    "gdal_translate -of vrt -expand rgba",
    file.path(saveDir, "rint.tif"),
    file.path(saveDir, "rint.vrt")
  ))
  system(paste(
    "gdal2tiles.py -p raster -z 2-4 -x -tmscompatible",
    file.path(saveDir, "rint.vrt"),
    saveDir
  ))
}

distcsv <-  read.csv(file.path(dirData, "distAnt.csv"))
distrasters <- as.list(pull(distcsv, name))

