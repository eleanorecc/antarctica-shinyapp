make_tiles <- function(resampled_raster, idx = 1, tile_directory, usepal = "viridis", reclass = "quantiles") {
  tryCatch({
    rastervalues <- values(resampled_raster, na.rm = TRUE)
    minval <- min(rastervalues, na.rm = TRUE) 
    maxval <- max(rastervalues, na.rm = TRUE)

    if(reclass == "quantiles"){
      ## calculate the quantiles and breaks
      breaks <- quantile(
        rastervalues, 
        probs = seq(0, 1, length.out = 257), 
        na.rm = TRUE
      )
    }
    if(reclass == "natural"){
      set.seed(123)
      if(length(rastervalues) > 25000){
        rastervalues <- sample(rastervalues, 25000)
      }
      km <- kmeans(rastervalues, centers = 256, iter.max = 50, nstart = 3)
      centers <- sort(km$centers[,1])
      breaks <- c(minval, (centers[-length(centers)] + centers[-1]) / 2, maxval)
    }
    if(reclass == "none"){
      ## linear/equal interval breaks 
      ## preserving data distribution
      breaks <- seq(minval, maxval, length.out = 257)
    }

    ## make breaks unique
    ub <- unique(breaks)
    nb <- length(ub)

    ## reclassify the raster using the breaks
    rcm <- matrix(c(ub[1:(nb-1)], ub[2:nb], 0:(nb-2)), ncol = 3)
    rint <- classify(resampled_raster[[idx]], rcm, include.lowest = TRUE, right = TRUE)
    cols <- data.frame(value = 0:(nb-2), col = hcl.colors(nb-1, usepal))
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
      breaks_lower = ub[1:(nb-1)],
      breaks_upper = ub[2:nb],
      value = 0:(nb-2),
      col = cols$col
    )
    write.csv(
      pal, 
      file.path(tile_directory, "palette.csv"), 
      row.names = FALSE
    )

    ## make the tiles
    message("making .vrt file")
    system(paste(
      "gdal_translate -of vrt -expand rgba",
      file.path(tile_directory, "rint.tif"),
      file.path(tile_directory, "rint.vrt")
    ))

    message("tile-izing...")
    system(paste(
      "gdal2tiles.py -p raster -z 2-4 -x -w none --processes=4",
      file.path(tile_directory, "rint.vrt"),
      tile_directory
    ))
    message("tiles complete. \n\n")

    file.remove(file.path(tile_directory, "rint.tif"))
    file.remove(file.path(tile_directory, "rint.vrt"))
    
    return(TRUE)

  }, error = function(e) {
    return(FALSE)
  })
}