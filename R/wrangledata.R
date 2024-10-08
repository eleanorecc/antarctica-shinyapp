source(here::here("global.R"))

## don't run script
wrangledata <- FALSE


## test example --
## Polarview Sentinel-1 imagery
if(wrangledata){
  tiffs_folder <- file.path(dirData, "www.polarview.aq")
  rast1 <- tiffs_folder |>
    list.files("v5.4.tif", full.names = TRUE) |>
    rast()

  cols <- coltab(rast1)
  rast1 <- project(rast1, "EPSG:3031")

  ## need to match shiny leaflet map extent
  dims <- floor(2*extent/res(rast1))
  template <- rast(ext(c(-extent,extent,-extent,extent)), nrow=dims[1], ncol=dims[2], crs=crs(rast1))

  rast2 <- resample(rast1, template)
  rast2 <- as.int(rast2, datatype="INT1U")
  coltab(rast2) <- cols


  ## addRasterImage does not handle sterographic projections
  ## need to make into tiles, so can use addTiles to put on leaflet map

  ## for now just save top layer to test tile in shiny map
  ## TODO figure out how best to make all layers available... lots of tiles...
  i <- nlyr(rast2)
  writeRaster(
    rast2[[i]],
    file.path(dirData, "delete.tif"),
    datatype="INT1U",
    overwrite = TRUE
  )
  ## for some reason for me the tiler r package gives warning: no module named 'osgeo'
  ## so will call gdal2tiles.py directly https://gdal.org/en/latest/programs/gdal2tiles.html
  system(paste(
    "gdal_translate -of vrt -expand rgba",
    file.path(dirData, "delete.tif"),
    file.path(tiffs_folder, "tiles.vrt")
  ))
  system(paste(
    "gdal2tiles.py -p raster -z 2-5 -s EPSG:3031 -x",
    file.path(tiffs_folder, "tiles.vrt"),
    file.path(tiffs_folder, "tiles")
  ))
}

