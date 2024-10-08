wrangle_data <- function(coords, layer){

  r <- layer$rast_filepath |>
    list.files("\\.tif", full.names = TRUE) |>
    rast()
  v <- matrix(unlist(coords), length(coords), 2) |>
    st_linestring() |>
    st_sfc(crs = 4326) |>
    st_transform(crs(r))

  linelength <- as.numeric(st_length(v))
  distance <- seq(0, linelength, by = res(r)[[1]]*sqrt(2))
  pts <- v |>
    st_line_sample(sample = distance/linelength) |>
    vect()

  vals <-  r |>
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
