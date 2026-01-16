make_timeseries <- function(y, polygons, spatialweights, outfile) {

  ## rasterize the polygons and make an array with ids 
  ## this will be used to mask and calculate zonal stats on the arrays
  zones_rast <- polygons |> 
    rasterize(spatialweights, field = "GAR_Name") |> 
    flip(direction = "vertical")
  zones_array <- as.array(t(zones_rast))
  zone_ids <- unique(values(zones_rast))
  zone_ids <- zone_ids[!is.na(zone_ids)]

  ## gave spatialweights as terra raster so can use as polygons template
  ## but need as array to match yravgs arrays
  spatialweights <- as.array(t(spatialweights))

  ## calculate averages per year per polygon / zone
  tstab <- bind_rows(lapply(zone_ids, function(z) {

    ## create and apply binary mask for the zone
    mask <- ifelse(zones_array == z, 1, NA)
    y_masked <- sweep(y, MARGIN = c(1,2), FUN = "*", mask)

    ## calculate spatially-weighted sums
    ## multiply each pixel by its area before summing
    yrwgtsum <- y_masked |>
      sweep(MARGIN = c(1,2), FUN = "*", spatialweights) |>
      apply(MARGIN = 3, FUN = sum, na.rm = TRUE)

    ## calculate total non-NA area for each year
    ## this will be used as the denominator to get mean
    nonNAarea <- y_masked |>
      sweep(MARGIN = c(1,2), FUN = function(a, b){ ifelse(is.na(a), NA, b) }, spatialweights) |>
      apply(MARGIN = 3, FUN = sum, na.rm = TRUE)

    ## simple statistics treating all pixels as equal-area
    ## for comparison but not spatially accurate
    yrsd <- apply(y_masked, MARGIN = 3, FUN = sd, na.rm = TRUE)

    ## combine metrics and calculate weighted mean (yrwgtsum / nonNAarea)
    ## yrwgtmean is the spatially-accurate average to use for plotting
    data.frame(
      zone = z,
      year = 1:dim(y)[3],
      yrwgtsum = yrwgtsum,
      nonNAarea = nonNAarea,
      yrwgtmean = yrwgtsum / nonNAarea,
      yrsd = yrsd
    )
  }))
  write.csv(tstab, outfile, row.names = FALSE)
  return(TRUE)
}

read_tstabs <- function(dir, file, name) {
  here("www", dir, file) |> 
    read.csv() |> 
    mutate(year = 1997 + year) |> 
    mutate(plot_with = name)
}

merge_timeseries <- function() {
  datasets <- list(
    list(
      dir = "chlorophyllA", 
      file = "timeperiod_all_months_chl.csv", 
      name = "chlorophyllA"
    ),
    list(
      dir = "chlorophyllA", 
      file = "timeperiod_summer_months_chl.csv", 
      name = "chlorophyllA_Summer"
    ),
    list(
      dir = "chlorophyllA", 
      file = "timeperiod_winter_months_chl.csv", 
      name = "chlorophyllA_Winter"
    ),
    list(
      dir = "surfaceSalinity", 
      file = "timeperiod_all_months_sos.csv", 
      name = "surfaceSalinity"
    ),
    list(
      dir = "surfaceSalinity", 
      file = "timeperiod_summer_months_sos.csv", 
      name = "surfaceSalinity_Summer"
    ),
    list(
      dir = "surfaceSalinity", 
      file = "timeperiod_winter_months_sos.csv", 
      name = "surfaceSalinity_Winter"
    ),
    list(
      dir = "seaiceDays", 
      file = "timeperiod_all_months_icedays.csv", 
      name = "seaiceDays"
    )
  )
  
  datasets |> 
     lapply(function(ds){
       read_tstabs(ds$dir, ds$file, ds$name)
     }) |> 
     bind_rows() |> 
     write.csv(
      file.path(dirData, "tsData.csv"), 
      row.names = FALSE
    )
  
  return(TRUE)
}
