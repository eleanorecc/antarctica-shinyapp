server <- function(input, output, session) {

  ## add data folder
  ## for user-uploaded shapefile
  addData <- tempdir()
  dir.create(addData, showWarnings = FALSE)

  ## map layout and options ----

  ## for polar crs need to custom define leaflet options
  ## https://thomasswilliams.github.io/development/r/2022/06/18/leaflet-and-r.html
  ## https://tile.gbif.org/ui/3031/EPSG3031-leaflet.js
  ## use 256 tile size resolutions (double) to accommodate generated tiles

  epsg_3031 <- leafletCRS(
    crsClass = "L.Proj.CRS",
    code = "EPSG:3031",
    proj4def = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs",
    resolutions = resolutions,
    origin = c(-extent, extent),
    bounds = list(c(-extent, -extent), c(extent, extent))
  )

  map_options <- leafletOptions(
    ## instead of -90,0 south pole,
    ## center the Weddell sea
    center = c(-75, -45),
    zoom = 3,
    minZoom = 3,
    maxZoom = 4,
    crs = epsg_3031,
    worldCopyJump = FALSE,
    preferCanvas = TRUE
  )
  gbif_tile_options <- tileOptions(
    ## shift zoom levels with offset
    ## to match 256px gdal tile grid
    tileSize = 512,
    zoomOffset = -1,
    noWrap = TRUE,
    continuousWorld = TRUE,
    updateWhenZooming = FALSE,
    updateWhenIdle = TRUE,
    pane = "background"
  )
  spp_options <- gbif_tile_options
  spp_options$pane <- "spp"

  tile_options <- tileOptions(
    tileSize = 256,
    noWrap = TRUE,
    opacity = 0.8,
    tms = TRUE,
    continuousWorld = TRUE
  )

  ## make basemap ----
  basemap <- leaflet(options = c(map_options, leafletOptions(zoomControl = FALSE))) |>
    addMapPane("background", zIndex = 410) |>
    addMapPane("customtiles-left", zIndex = 420) |>
    addMapPane("customtiles-right", zIndex = 421) |>
    addMapPane("overlays", zIndex = 430)  |>
    addMapPane("spp", zIndex = 440)  |>
    addMapPane("owndata", zIndex = 450) |>
    addTiles(
      urlTemplate = "https://tile.gbif.org/3031/omt/{z}/{x}/{y}@2x.png?style=gbif-geyser",
      attribution = "OpenStreetMap | GBIF",
      options = gbif_tile_options
    ) |>
    addPolygons(
      data = asd,
      group = "Statistical Areas",
      popup = ~GAR_Name,
      fillOpacity = 0, weight = 1,
      options = pathOptions(pane = "overlays")
    ) |>
    addPolylines(
      data = coords_wobec,
      group = "WOBEC Expedition",
      color = "#a52600", weight = 1,
      options = pathOptions(pane = "overlays")
    ) |>
    addPolylines(
      data = coords_hafos,
      group = "HAFOS Expedition",
      color = "#71022e", weight = 1,
      options = pathOptions(pane = "overlays")
    ) |>
    addPolygons(
      data = wobec,
      group = "Study Area",
      popup = "Study Area",
      color = "red", fillOpacity = 0, weight = 2,
      options = pathOptions(pane = "overlays")
    ) |>
    addCircles(
      data = maud_rise_center,
      group = "Points of Interest",
      popup = "Maud Rise",
      fill = FALSE, weight = 12,
      options = pathOptions(pane = "overlays")
    ) |>
    addCircles(
      data = kap_norvegia,
      group = "Points of Interest",
      popup = "Kap Norvegia",
      fill = FALSE, weight = 12,
      options = pathOptions(pane = "overlays")
    ) |>
    hideGroup("WOBEC Expedition") |>
    hideGroup("HAFOS Expedition") |>
    hideGroup("Study Area") |>
    hideGroup("Statistical Areas") |>
    hideGroup("Points of Interest")

  ## cruise device layers — one group per (cruise, method_device), hidden by default ----
  cruise_colors <- c(wobec = "#a52600", hafos = "#71022e")

  for (cru in c("wobec", "hafos")) {
    devices <- if (cru == "wobec") devices_wobec else devices_hafos
    for (dev in devices) {
      subset_data <- cruise_data |> filter(cruise == cru, method_device == dev)
      group_name <- paste(cru, dev, sep = "__")

      points <- subset_data[st_geometry_type(subset_data) == "POINT", ]
      lines  <- subset_data[st_geometry_type(subset_data) == "LINESTRING", ]

      if (nrow(points) > 0) {
        basemap <- basemap |>
          addCircleMarkers(
            data = points, group = group_name,
            color = cruise_colors[[cru]], radius = 2, weight = 1,
            options = pathOptions(pane = "overlays")
          )
      }
      if (nrow(lines) > 0) {
        basemap <- basemap |>
          addPolylines(
            data = lines, group = group_name,
            color = cruise_colors[[cru]], weight = 3,
            options = pathOptions(pane = "overlays")
          )
      }
      basemap <- basemap |> hideGroup(group_name)
    }
  }

  basemap <- basemap |>
    ## placeholder tile groups for addSidebyside — populated by observers
    addTiles(
      layerId = "left-tiles",
      group   = "left-tiles",
      urlTemplate = "about:blank",
      options = tileOptions(
        tileSize = 256,
        noWrap = TRUE, tms = TRUE,
        continuousWorld = TRUE,
        pane = "customtiles-left"
      )
    ) |>
    addTiles(
      layerId = "right-tiles",
      group   = "right-tiles",
      urlTemplate = "about:blank",
      options = tileOptions(
        tileSize = 256,
        noWrap = TRUE, tms = TRUE,
        continuousWorld = TRUE,
        pane = "customtiles-right"
      )
    ) |>
    addSidebyside(
      layerId = "sbs",
      leftId  = "left-tiles",
      rightId = "right-tiles"
    )

  ## single map — syncWith() is removed entirely (not needed with one map instance)
  output$map <- renderLeaflet({ basemap })


  ## render the captions
  output$map1cap <- renderUI({
    if(!is.null(input$taxonKey) && nzchar(input$taxonKey)) {
      
      ## Add species name and year range to GBIF caption title
      species_name <- str_to_title(input$taxonKey)
      year_range <- if(!is.null(input$yearRange)) {
        paste0(input$yearRange[1], "-", input$yearRange[2])
      } else {
        ""
      }
      title <- if(nzchar(year_range)) {
        paste0("Species Observations (", species_name, "), ", year_range)
      } else {
        paste0("Species Observations (", species_name, ")")
      }
      renderCaption(list(
        title = title,
        description = "Species observations (basis of record: human and machine observation) collected in the Global Biodiversity Information Facility (GBIF)",
        dataset = "api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?srs=EPSG:3031",
        url = "https://www.gbif.org/occurrence/search?occurrence_status=present",
        reference = ""
      ))
    } else {
      req(input$tilesLeft)
      caption_data <- getCaptionData(input$tilesLeft)

      ## extract years from select dropdown input choice, same as filename
      year_match <- str_extract(input$tilesLeft, "(\\d{4})(\\d{4})")
      years <- paste(c(substr(year_match, 1, 4), substr(year_match, 5, 8)), collapse = "-")
      ## check if it's a diff layer
      if(str_detect(input$tilesLeft, "diff")) {
        caption_data$title <- sprintf(
          "%s, %s Difference %s minus 1998-2006",
          caption_data$title, caption_data$season, years
        )
      } else {
        caption_data$title <- sprintf(
          "%s, %s %s Average",
          caption_data$title, years, caption_data$season
        )
      }
      renderCaption(caption_data)
    }
  })
  output$map2cap <- renderUI({
    if(!is.null(input$tilesDistAnt) && nzchar(input$tilesDistAnt)) {
      renderCaption(getCaptionData(input$tilesDistAnt))
    } else {
      req(input$tilesRight)
      caption_data <- getCaptionData(input$tilesRight)

      ## extract years from select dropdown input choice, same as filename
      year_match <- str_extract(input$tilesRight, "(\\d{4})(\\d{4})")
      years <- paste(c(substr(year_match, 1, 4), substr(year_match, 5, 8)), collapse = "-")
      ## check if it's a diff layer
      if(str_detect(input$tilesRight, "diff")) {
        caption_data$title <- sprintf(
          "%s, %s Difference %s minus 1998-2006",
          caption_data$title, caption_data$season, years
        )
      } else {
        caption_data$title <- sprintf(
          "%s, %s %s Average",
          caption_data$title, years, caption_data$season
        )
      }
      renderCaption(caption_data)
    }
  })

  ## update left map tiles based on user selection ----
  observeEvent(input$tilesLeft, {
    updateSelectizeInput(session, "taxonKey", selected = character(0))

    p1 <- read.csv(file.path(
      dirData, str_replace_all(input$tilesLeft, "_", "/"),
      "palette.csv"
    ))

    max_bins <- 10
    p1bk <- unique(c(p1$breaks_lower, p1$breaks_upper))
    if(length(p1bk) > max_bins) {
      indices <- round(seq(1, length(p1bk), length.out = max_bins))
      p1_legend_breaks <- p1bk[indices]
    } else {
      p1_legend_breaks <- p1bk
    }

    leafletProxy("map") |>
      clearGroup("left-tiles") |>
      addTiles(
        layerId = "left-tiles",
        group   = "left-tiles",
        urlTemplate = sprintf(
          "%s/{z}/{x}/{-y}.png",
          str_replace_all(input$tilesLeft, "_", "/")
        ),
        options = tileOptions(
          tileSize = 256,
          noWrap = TRUE,
          opacity = 0.8,
          tms = TRUE,
          continuousWorld = TRUE,
          pane = "customtiles-left"
        )
      ) |>
      removeControl(layerId = "legend-left") |>
      addControl(
        layerId = "legend-left",
        position = "bottomleft",
        html = legendHTML(p1, p1_legend_breaks)
      ) |>
      addSidebyside(layerId = "sbs", leftId = "left-tiles", rightId = "right-tiles")
  }, ignoreNULL = TRUE)

  ## add GBIF occurrence tiles ----
  taxon_delayed <- debounce(reactive(input$taxonKey), 1000)
  year_delayed  <- debounce(reactive(input$yearRange), 1000)

  observeEvent(c(taxon_delayed(), year_delayed()), {
    req(taxon_delayed())

    nm  <- taxon_delayed() |> str_to_title() |> URLencode()
    res <- paste0("https://api.gbif.org/v1/species/match?name=", nm) |>
      request() |>
      req_headers(user_agent = "DataSummaryWOBEC/1.0") |>
      req_perform()

    if(resp_status(res) < 400){
      taxa <- resp_body_json(res)
      key  <- taxa$usageKey
    } else {
      key <- NULL
    }

    if(!is.null(key)){
      yr <- year_delayed()
      speciesOccurance <- paste(
        "https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?srs=EPSG%3A3031",
        paste0("taxonKey=", key),
        paste0("basisOfRecord=", c("HUMAN_OBSERVATION", "MACHINE_OBSERVATION"), collapse = "&"),
        paste0("year=", yr[1], ",", yr[2]),
        "style=purpleYellow.point",
        sep = "&"
      )
      message(paste("GBIF API URL:", speciesOccurance))

      leafletProxy("map") |>
        clearGroup("left-tiles") |>
        addTiles(
          layerId = "left-tiles",
          group   = "left-tiles",
          urlTemplate = speciesOccurance,
          options = spp_options
        ) |>
        removeControl(layerId = "legend-left") |>
        addSidebyside(layerId = "sbs", leftId = "left-tiles", rightId = "right-tiles")
    }
  })

  ## update right map tiles based on user selection ----
  observeEvent(input$tilesRight, {
    updateSelectizeInput(session, "tilesDistAnt", selected = character(0))

    p2 <- read.csv(file.path(
      dirData, str_replace_all(input$tilesRight, "_", "/"),
      "palette.csv"
    ))

    max_bins <- 10
    p2bk <- unique(c(p2$breaks_lower, p2$breaks_upper))
    if(length(p2bk) > max_bins) {
      indices <- round(seq(1, length(p2bk), length.out = max_bins))
      p2_legend_breaks <- p2bk[indices]
    } else {
      p2_legend_breaks <- p2bk
    }

    leafletProxy("map") |>
      clearGroup("right-tiles") |>
      addTiles(
        layerId = "right-tiles",
        group   = "right-tiles",
        urlTemplate = sprintf(
          "%s/{z}/{x}/{-y}.png",
          str_replace_all(input$tilesRight, "_", "/")
        ),
        options = tileOptions(
          tileSize = 256,
          noWrap = TRUE,
          opacity = 0.8,
          tms = TRUE,
          continuousWorld = TRUE,
          pane = "customtiles-right"
        )
      ) |>
      removeControl(layerId = "legend-right") |>
      addControl(
        layerId = "legend-right",
        position = "bottomright",
        html = legendHTML(p2, p2_legend_breaks)
      ) |>
      addSidebyside(layerId = "sbs", leftId = "left-tiles", rightId = "right-tiles")
  })

  ## update map with distAnt data ----
  distAnt_delayed <- debounce(reactive(input$tilesDistAnt), 1000)

  observeEvent(c(distAnt_delayed()), {
    req(distAnt_delayed())

    plotlyr <- distAnt_delayed()

    p2 <- read.csv(file.path(
      dirData, "distAnt",
      plotlyr, "palette.csv"
    ))

    max_bins <- 10
    p2bk <- unique(c(p2$breaks_lower, p2$breaks_upper))
    if(length(p2bk) > max_bins) {
      indices <- round(seq(1, length(p2bk), length.out = max_bins))
      p2_legend_breaks <- p2bk[indices]
    } else {
      p2_legend_breaks <- p2bk
    }

    leafletProxy("map") |>
      clearGroup("right-tiles") |>
      addTiles(
        layerId = "right-tiles",
        group   = "right-tiles",
        urlTemplate = sprintf("distAnt/%s/{z}/{x}/{-y}.png", plotlyr),
        options = tileOptions(
          tileSize = 256,
          noWrap = TRUE,
          opacity = 0.8,
          tms = TRUE,
          continuousWorld = TRUE,
          pane = "customtiles-right"
        )
      ) |>
      removeControl(layerId = "legend-right") |>
      addControl(
        layerId = "legend-right",
        position = "bottomright",
        html = legendHTML(p2, p2_legend_breaks)
      ) |>
      addSidebyside(layerId = "sbs", leftId = "left-tiles", rightId = "right-tiles")
  })

  ## overlay group visibility — driven by Box C multi-select ----
  observeEvent(input$overlayGroups, {
    all_groups <- c(
      "Statistical Areas", "WOBEC Expedition", "HAFOS Expedition", "Study Area",
      "Points of Interest", "Marginal Ice Zone"
    )
    selected <- input$overlayGroups

    proxy <- leafletProxy("map")
    for(grp in all_groups) {
      if(grp %in% selected){
        proxy <- showGroup(proxy, grp)
      } else {
        proxy <- hideGroup(proxy, grp)
      }
    }
  }, ignoreNULL = FALSE)

  ## WOBEC device visibility — driven by Box C selectize ----
  observeEvent(input$wobecDevices, {
    selected <- input$wobecDevices
    proxy <- leafletProxy("map")
    for (dev in devices_wobec) {
      grp <- paste("wobec", dev, sep = "__")
      if (dev %in% selected) {
        proxy <- showGroup(proxy, grp)
      } else {
        proxy <- hideGroup(proxy, grp)
      }
    }
  }, ignoreNULL = FALSE)

  ## HAFOS device visibility — driven by Box C selectize ----
  observeEvent(input$hafosDevices, {
    selected <- input$hafosDevices
    proxy <- leafletProxy("map")
    for (dev in devices_hafos) {
      grp <- paste("hafos", dev, sep = "__")
      if (dev %in% selected) {
        proxy <- showGroup(proxy, grp)
      } else {
        proxy <- hideGroup(proxy, grp)
      }
    }
  }, ignoreNULL = FALSE)


  ## MIZ reactive state ----
  fetch_miz <- function(mizDir, mizDate){
    url <- paste0(
      "https://usicecenter.gov/File/DownloadArchive?prd=16",
      format(mizDate, "%m%d%Y")
    )
    tryCatch(
      expr = {
        ## here we need to create the directory
        ## for the requested file to download and be saved into
        dir.create(mizDir, showWarnings = FALSE)
        req <- request(url) |>
          req_headers(`User-Agent` = "ocean-src/wobec") |>
          req_timeout(8) |> 
          req_error(is_error = function(resp){ FALSE })
        resp <- req_perform(req, path = file.path(mizDir, "miz.zip"))
        if(resp_status(resp) >= 400){
          NULL
        } else {
          unzip(file.path(mizDir, "miz.zip"), exdir = mizDir)
          mizfile <- list.files(mizDir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
          mizfile <- mizfile[[1]]
          if(length(mizfile) == 1){
            miz <- mizfile[[1]] |> 
              st_read(quiet = TRUE) |> 
              st_geometry()
          } else {
            NULL
          }
        }
      }, 
      error = function(e){ NULL }
    )
  }

  mizdata <- reactive({
    ## req ensures this code only runs when input (date) is changed
    req(input$mizDate)

    mizDir <- file.path(addData, "mizShapefile")

    ## fetch and unzip the MIZ shapefile
    result <- NULL
    loaded_date <- NULL
    for(i in seq(0, 6)){
      candidate <- input$mizDate - i
      result <- fetch_miz(mizDir, candidate)
      if(!is.null(result)){
        loaded_date <- candidate
        break
      }
    }
    if(!is.null(result)){
      mizdata <- list(
        data = result, 
        date = loaded_date, 
        status = "loaded"
      )
    } else {
      mizdata <- list(
        data = NULL, 
        date = NULL, 
        status = "unavailable"
      )
    }
    unlink(mizDir, recursive = TRUE)
    return(mizdata)
  })

  observe({
    downloaded_data <- mizdata()
    if(!is.null(downloaded_data) && !is.null(downloaded_data$data)){
      message("MIZ data downloaded, adding to map...")
      ## add the downloaded layer to map
      leafletProxy("map") |>
        clearGroup("Marginal Ice Zone") |>
        addPolygons(
          data = downloaded_data$data,
          group = "Marginal Ice Zone",
          col = "black",
          weight = 1.5,
          fillOpacity = 0,
          options = list(pane = "overlays")
        )
    }
  })
  ## output$mizStatus <- renderText({
  ##   state <- mizdata()
  ##   if(is.null(state)) return("Loading...")
  ##   switch(state$status,
  ##     loading = "Loading...",
  ##     loaded = paste0(
  ##       "Loaded: ",
  ##       format(state$date, "%Y-%m-%d"),
  ##       ". See 'Marginal Ice Zone' overlay."
  ##     ),
  ##     unavailable = "Data not available.",
  ##     ""
  ##   )
  ## })


  ## handling user-uploaded shapefile vector ----
  shpdata <- reactive({
    ## req ensures this code only runs when a file is uploaded
    req(input$shapefile)

    ## unzip the uploaded shapefile
    shpDir <- file.path(addData, "userShapefile")
    unzip(input$shapefile$datapath, exdir = shpDir)
    tmpfile <- list.files(shpDir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
    tmpfile <- tmpfile[[1]]
    if(length(tmpfile) == 1){
      shpfile <- st_read(tmpfile)
      if(object.size(shpfile) > 8e5){
        shpfile <- rmapshaper::ms_simplify(shpfile, keep = 0.01)
      }
      shpfile <- st_geometry(shpfile)
      ## vector geometries need to be in latlon for leaflet
      if(st_crs(shpfile) != st_crs("EPSG:4326")){
        shpfile <- st_transform(shpfile, st_crs("EPSG:4326"))
      }
    } else {
      ## TODO check the shp has at least 30% overlap with map latitudes?
      shpfile <- NULL
    }
    unlink(shpDir, recursive = TRUE)

    return(shpfile)
  })

  ## increase upload limit to 30MB (from default of 5) in options
  options(shiny.maxRequestSize = 80*1024^2)

  ## update when user uploads shapefile
  observe({
    uploaded_data <- shpdata()
    if(is.null(uploaded_data)){
      message("No shapefile for mapping...")
    }
    if(!is.null(uploaded_data)){
      message("Shapefile uploaded, adding to map...")
      ## add the uploaded layer to map
      leafletProxy("map") |>
        clearGroup("uploaded_data") |>
        addPolygons(
          data = uploaded_data,
          group = "uploaded_data",
          col = "black",
          weight = 1.5,
          fillOpacity = 0,
          options = list(pane = "owndata")
        )
    }
  })

  ## time series plots ----
  # output$timeseries <- renderPlot({
  #   plotvars <- c(input$tilesLeft, input$tilesRight) |>
  #     str_split("_[0-9]{4}") |>
  #     lapply(function(x){first(unlist(x))}) |>
  #     unlist()
  #
  #   df <- filter(tsdata, plot_with %in% plotvars)
  #   # yTitle <- paste0(unique(df$yaxislabel), "\n")
  #
  #   ggplot(df) +
  #     geom_point(aes(x = year, y = yvariable, color = plot_with), size = 2) +
  #     geom_line(aes(x = year, y = yvariable, color = plot_with), linewidth = 0.4) +
  #     facet_wrap(~yaxislabel, ncol = 1, scales = "free") +
  #     labs(x = "Year", y = NULL, color = NULL) +
  #     theme(
  #       legend.text = element_text(size = 12),
  #       strip.text = element_text(size = 16),
  #       axis.text = element_text(size = 14)
  #     )
  # })

  ## flowerplot ----
  # output$d3_flower <- renderD3({
  #   flower_json <- fromJSON(
  #     file.path(dirData, "flowerplot/flowerplot.json"),
  #     simplifyVector = FALSE
  #   )
  #
  #   r2d3(
  #     data = flower_json,
  #     script = file.path(dirData, "flowerplot/flowerplot.js"),
  #     d3_version = "6",
  #     options = list(
  #       plotYear = "BalticSea",
  #       addViewDepth = 0
  #     )
  #   )
  # })

  session$onSessionEnded(function() {
    unlink(addData, recursive = TRUE, force = TRUE)
  })
}
