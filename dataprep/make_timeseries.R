make_timeseries <- function(y, polygons, spatialweights, outfile){

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
  return(tstab)
}

merge_timeseries <- function(dirData){
  chla <- bind_rows(
    read.csv(file.path(dirData, "chlorophyllA", "timeperiod_all_months_chla.csv")) |>
      mutate(plot_with = "chlorophyllA") |>
      cbind(year = 1998:2024),
    read.csv(file.path(dirData, "chlorophyllA", "timeperiod_summer_months_chla.csv")) |>
      mutate(plot_with = "chlorophyllA_Summer") |>
      cbind(year = 1998:2024),
    read.csv(file.path(dirData, "chlorophyllA", "timeperiod_winter_months_chla.csv")) |>
      mutate(plot_with = "chlorophyllA_Winter") |>
      cbind(year = 1998:2024)) |>
    mutate(yaxislabel = "Chlorophyll-a (mg m^-3)")

  salinity <- bind_rows(
    read.csv(file.path(dirData, "surfaceSalinity", "timeperiod_all_months_salinity.csv")) |>
      mutate(plot_with = "surfaceSalinity") |>
      cbind(year = 1998:2024),
    read.csv(file.path(dirData, "surfaceSalinity", "timeperiod_summer_months_salinity.csv")) |>
      mutate(plot_with = "surfaceSalinity_Summer") |>
      cbind(year = 1998:2024)) |>
    mutate(yaxislabel = "Salinity (PSU)")

  icedays <- read.csv(file.path(dirData, "seaiceDays", "seaice_icedays.csv")) |>
    mutate(plot_with = "seaiceDays") |>
    mutate(yaxislabel = "Number of Days with Ice-Cover > 15%, Area Average") |>
    cbind(year = 1998:2024)

  iceext <- read.csv(file.path(dirData, "seaiceMinExtent", "seaice_coverage_minext.csv")) |>
    mutate(coveragearea = coveragearea/1e6) |>
    pivot_longer(cols = c(index, coveragearea), values_to = "yrwgtmean") |>
    mutate(plot_with = "seaiceMinExtent") |>
    mutate(yaxislabel = ifelse(
      name == "coveragearea",
      "Area of Minimum Ice Extent (million km^2)",
      "Day of the Year with Minimum Ice Extent"
    ))

  tsdata <- bind_rows(chla, salinity, icedays, iceext) |>
    select(plot_with, year, yvariable = yrwgtmean, yaxislabel)

  write.csv(tsdata, file.path(dirData, "tsdata.csv"), row.names = FALSE)

  message("Generated tsdata.csv with ", nrow(tsdata), " rows")

  return(tsdata)
}
