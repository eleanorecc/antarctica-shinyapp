wrangle_localdata <- function(coords, layer){

  r <- layer$rast_filepath |>
    list.files("\\.tif", full.names = TRUE) |>
    rast()
  v <- matrix(unlist(coords), length(coords), 2) |>
    apply(1, function(x){ifelse(x==-90, -88, x)}) |>
    st_linestring() |>
    st_sfc(crs = 4326) |>
    st_transform(3031)


  ## make this its own function?
  ## keep and dont recalculate line with new plotted layer
  ## also add to gbif 3031 epsg map2?

  # coords2linestring <- function(coords){
  #   v <- matrix(unlist(coords), length(coords), 2) |>
  #     apply(1, function(x){ifelse(x==-90, -88, x)}) |>
  #     st_linestring() |>
  #     st_sfc(crs = 4326) |>
  #     st_transform(3412)
  #   return(v)
  # }

  linelength <- as.numeric(st_length(v))
  distance <- seq(0, linelength, by = res(r)[[1]]*sqrt(2))
  pts <- v |>
    st_line_sample(sample = distance/linelength) |>
    vect()

  vals <- r |>
    extract(pts) |>
    select(-ID) |>
    setNames(layer$layernames) |>
    cbind(distance = distance)
  plotdata <- list(
    values = vals,
    plotymin = min(global(r, min)),
    ylab = layer$ylab
  )
  return(plotdata)
}

# coords2tile <- function(pt){
#
#   ## constrain lat -90 to 90, lon to < 180
#   constrained_lat <- max(-89.999999, pt[2])
#   constrained_lon <- ifelse(pt[1] == 180, 179.999999, pt[1])
#
#   ## epsg 4326 bounds
#   min_lat <- -90
#   max_lat <- 90
#   min_lon <- -180
#   max_lon <- 180
#
#   ## tile width and height in terms of lat lon
#   ## divide by zoom (4) with twice as many tiles wide as vertically
#   tile_width <- (max_lon - min_lon) / 2^5
#   tile_height <- (max_lat - min_lat) / 2^4
#
#   ## tile index
#   tile_x <- floor((constrained_lon - min_lon) / tile_width)
#   tile_y <- floor((max_lat - constrained_lat) / tile_height)
#
#   ## pixel position (256x256) within the tile
#   pixel_x <- floor((((constrained_lon - min_lon) %% tile_width) / tile_width) * 256)
#   pixel_y <- floor((((max_lat - constrained_lat) %% tile_height) / tile_height) * 256)
#
#   return(list(tx=tile_x, ty=tile_y, pxi=pixel_x, pxj=pixel_y))
# }

# getfeatureinfo <- function(x, cms_dataset){
#
#   wmts_url <- paste0(
#     "https://wmts.marine.copernicus.eu/teroWmts/?service=WMTS&request=GetFeatureInfo&INFOFORMAT=application/json&tilematrixset=EPSG:4326&tilematrix=5",
#     "&layer=", cms_dataset,
#     "&elevation=", x$depth,
#     "&time=", x$time,
#     "&tilerow=", x$ty,
#     "&tilecol=", x$tx,
#     "&i=", x$pxi,
#     "&j=", x$pxj
#   )
#   tryCatch({
#     response <- GET(wmts_url)
#     stop_for_status(response)
#     if(response$status_code == 200){
#       ## parse the JSON response
#       data <- fromJSON(content(response, as="text", encoding="UTF-8"))
#       return(data$features$properties$value)
#     } else {
#       print(paste("Request failed with status code:", response$status_code))
#     }
#   }, error = function(e){
#     print(paste("Error:", e$message))
#   })
# }

# wrangle_wmsdata <- function(layer, coords, time, depth){
#
#   resolution <- 40075017/256/2^4
#
#   # coords <- list(list(-60,-80),list(-90,-90))
#   # get_elevation <- -9.5
#   # get_time <- "2024-02-02T00:00:00.000000000"
#   # layer$dataset <- "GLOBAL_ANALYSISFORECAST_PHY_001_024/cmems_mod_glo_phy-thetao_anfc_0.083deg_PT6H-i_202406/thetao"
#   # layer$ylab <- "Temperature (deg C)"
#   # layer$plotmin <- -5
#
#   v <- matrix(unlist(coords), length(coords), 2) |>
#     ## lat -90 is a singularity in the crs transformation
#     apply(1, function(x){ifelse(x==-90, -88, x)}) |>
#     st_linestring() |>
#     st_sfc(crs = 4326) |>
#     st_transform(3031)
#
#   linelength <- as.numeric(st_length(v))
#   distance <- seq(0, linelength, by = resolution*sqrt(2))
#   pts <- st_line_sample(v, sample = distance/linelength)
#
#   coords_data <- pts |>
#     st_transform(4326) |>
#     st_cast("POINT") |>
#     st_as_text() |>
#     str_extract_all("[\\-0-9\\.]+") |>
#     lapply(as.numeric) |>
#     lapply(coords2tile) |>
#     lapply(function(x){
#       x$time = get_time
#       x$depth = get_elevation
#       getfeatureinfo(x, layer$dataset)
#     })
#
#   vals <- data.frame(value = unlist(coords_data), distance = distance)
#   colnames(vals) <- c(str_extract(layer$dataset, "(?<=/)[A-Za-z0-9]+$"), "distance")
#   plotdata <- list(
#     values = vals,
#     plotymin = layer$plotmin,
#     ylab = layer$ylab
#   )
#   return(plotdata)
# }

## get feature info it too slow, not really designed for that use...
## but how to handle credentials though to use the Copernicus Marine Toolbox??

time_series_plot <- function(plotdata){

  tsplot <- highchart() |>
    hc_xAxis(
      type = "datetime",
      title = list(text = "Date")
    ) |>
    hc_yAxis(
      title = list(text = plotdata$ylab),
      min = plotdata$plotymin
    ) |>
    hc_plotOptions(
      series = list(
        color = "#2771aa",
        marker = list(
          symbol = "circle",
          fillColor = "#FFFFFF",
          radius = 2.5,
          lineWidth = 1
        )
      )
    ) |>
    hc_legend(enabled = FALSE) |>
    hc_tooltip(shared = TRUE) |>
    hc_add_theme(hc_theme_538())

  if(nrow(plotdata$values) > 0){
    ## if there are data to add,
    ## wrangle and add them
    dat <- select(plotdata$values, -distance)
    datrange <- diff(range(dat, na.rm = TRUE))
    digits <- max(0, -floor(log10(datrange)) + 3)

    dat <- dat |>
      apply(2, function(x){
        data.frame(
          mean = mean(x, na.rm = TRUE),
          min = min(x, na.rm = TRUE),
          max = max(x, na.rm = TRUE),
          sd = sd(x, na.rm = TRUE)
        )
      }) |>
      bind_rows() |>
      cbind(date = names(dat)) |>
      mutate(
        datetime = as.Date(date),
        mean_plus_sd = round(mean + sd, digits),
        mean_minus_sd = round(mean - sd, digits),
        mean = round(mean, digits)
      ) |>
      select(
        datetime, min, max, mean,
        mean_plus_sd, mean_minus_sd
      )
    ## add series to plot
    tsplot <- tsplot |>
      hc_add_series(
        name = "Mean",
        id = "mean",
        data = dat,
        type = "line",
        color = "black",
        zIndex = 1,
        hcaes(x = datetime, y = mean)
      ) |>
      hc_add_series(
        name = "Mean Minus/Plus StDev",
        data = dat,
        type = "arearange",
        lineWidth = 0,
        fillOpacity = 0.5,
        zIndex = 0,
        linkedTo = "mean",
        hcaes(x = datetime, low = mean_minus_sd, high = mean_plus_sd)
      )
  }
  return(tsplot)
}

cross_section_plot <- function(plotdata){

  xsplot <- highchart() |>
    hc_chart(type = "spline", zoomType = "x") |>
    hc_xAxis(
      type = "linear",
      title = list(text = "Distance (m)")
    ) |>
    hc_yAxis(
      title = list(text = plotdata$ylab),
      min = plotdata$plotymin
    ) |>
    hc_tooltip(
      headerFormat = "{series.name}<br>",
      pointFormat = "<b>{point.y:.2f}</b>"
    ) |>
    hc_plotOptions(
      series = list(
        marker = list(
          symbol = "circle",
          fillColor = "#FFFFFF",
          enabled = TRUE,
          radius = 2.5,
          lineWidth = 1,
          lineColor = NULL
        ),
        pointInterval = plotdata$values$distance[2],
        pointStart = 0
      )
    ) |>
    hc_legend(
      align = "right",
      verticalAlign = "top",
      layout = "vertical"
    ) |>
    hc_add_theme(hc_theme_538())

  for(nm in setdiff(names(plotdata$values), "distance")){
    dat <- pull(plotdata$values, nm)
    xsplot <- xsplot |>
      hc_add_series(
        name = nm,
        data = dat
      )
  }

  return(xsplot)
}
