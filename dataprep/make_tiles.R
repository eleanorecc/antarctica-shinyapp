make_tiles <- function(resampled_raster, idx = 1, tile_directory, usepal = "viridis") {
  tryCatch({
    ## calculate the quantiles and breaks
    breaks <- quantile(
      values(resampled_raster, na.rm = TRUE), 
      probs = seq(0, 1, length.out = 257), 
      na.rm = TRUE
    )

    ## reclassify the raster using the quantile breaks
    rcm <- matrix(c(breaks[1:256], breaks[2:257], 0:255), ncol = 3)
    rint <- classify(resampled_raster[[idx]], rcm, include.lowest = TRUE, right = FALSE)
    cols <- data.frame(value = 0:255, col = hcl.colors(256, usepal))
    coltab(rint) <- cols
    
    ## make int1u raster
    writeRaster(
      rint,
      file.path(tile_directory, "rint.tif"), 
      datatype = "INT1U", 
      overwrite = TRUE
    )

    ## creating color palette
    pal <- data.frame(
      breaks_lower = breaks[1:256],
      breaks_upper = breaks[2:257],
      value = 0:255,
      col = cols$col
    )
    write.csv(
      pal, 
      file.path(tile_directory, "palette.csv"), 
      row.names = FALSE
    )

    ## make the tiles
    system(paste(
      "gdal_translate -of vrt -expand rgba",
      file.path(tile_directory, "rint.tif"),
      file.path(tile_directory, "rint.vrt")
    ))
    system(paste(
      "gdal2tiles.py -p raster -z 2-4 -x -w none --processes=4",
      file.path(tile_directory, "rint.vrt"),
      tile_directory
    ))
    file.remove(file.path(tile_directory, "rint.tif"))
    file.remove(file.path(tile_directory, "rint.vrt"))
    
    return(TRUE)

  }, error = function(e) {
    return(FALSE)
  })
}