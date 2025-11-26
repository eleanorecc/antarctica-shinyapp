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
    addMapPane("customtiles", zIndex = 420)  |>
    addMapPane("overlays", zIndex = 430)  |>
    addMapPane("spp", zIndex = 440)  |>
    addMapPane("owndata", zIndex = 450) |>
    addTiles(
      urlTemplate = "https://tile.gbif.org/3031/omt/{z}/{x}/{y}@2x.png?style=gbif-geyser",
      attribution = "OpenStreetMap | GBIF",
      options = gbif_tile_options
    ) |>
    addLayersControl(
      overlayGroups = c("Statistical Areas", "Management Units", "Study Area", "Points of Interest"),
      position = "bottomleft"
    ) |>
    hideGroup("Statistical Areas") |>
    hideGroup("Management Units") |>
    hideGroup("Study Area") |>
    hideGroup("Points of Interest") |>
    addPolygons(
      data = asd,
      group = "Statistical Areas",
      popup = ~GAR_Name,
      fillOpacity = 0, weight = 1,
      options = pathOptions(pane = "overlays")
    ) |>
    addPolygons(
      data = mgmt,
      group = "Management Units",
      fillOpacity = 0, weight = 2,
      color = "white", opacity = 0.5,
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
    )

  ## two synced leaflet maps side-by-side
  output$map1 <- renderLeaflet({ syncWith(basemap, "maps") })
  output$map2 <- renderLeaflet({ syncWith(basemap, "maps") })


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

      ## Check if it's a diff layer and modify title
      if(str_detect(input$tilesLeft, "diff")) {
        ## Extract years from filename like "20072015diff"
        year_match <- str_extract(input$tilesLeft, "(\\d{4})(\\d{4})diff")
        if(!is.na(year_match)) {
          year1 <- str_sub(year_match, 1, 4)
          year2 <- str_sub(year_match, 5, 8)
          ## Modify title to say "Difference"
          caption_data$title <- str_replace(caption_data$title, " Data$", " Data Difference")
          caption_data$title <- paste0(caption_data$title, ", ", year1, "-", year2, " minus 1998-2006")
        }
      } else {
        ## Extract year range from selection name for non-diff layers
        for(category in allrasters) {
          year_label <- names(which(category == input$tilesLeft))[1]
          if(!is.na(year_label)) {
            year_match <- str_extract(year_label, "\\d{4}-\\d{4}")
            if(!is.na(year_match)) {
              caption_data$title <- paste0(caption_data$title, ", ", year_match)
            }
            break
          }
        }
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

      ## Check if it's a diff layer and modify title
      if(str_detect(input$tilesLeft, "diff")) {
        ## Extract years from filename like "20072015diff"
        year_match <- str_extract(input$tilesLeft, "(\\d{4})(\\d{4})diff")
        if(!is.na(year_match)) {
          year1 <- str_sub(year_match, 1, 4)
          year2 <- str_sub(year_match, 5, 8)
          ## Modify title to say "Difference"
          caption_data$title <- str_replace(caption_data$title, " Data$", " Data Difference")
          caption_data$title <- paste0(caption_data$title, ", ", year1, "-", year2, " minus 1998-2006")
        }
      } else {
        ## Extract year range from selection name for non-diff layers
        for(category in allrasters) {
          year_label <- names(which(category == input$tilesRight))[1]
          if(!is.na(year_label)) {
            year_match <- str_extract(year_label, "\\d{4}-\\d{4}")
            if(!is.na(year_match)) {
              caption_data$title <- paste0(caption_data$title, ", ", year_match)
            }
            break
          }
        }
      }
      renderCaption(caption_data)
    }
  })

  ## update left map tiles based on user selection ----
  observeEvent(input$tilesLeft, {
    p1 <- read.csv(file.path(
      dirData, str_replace_all(input$tilesLeft, "_", "/"),
      "palette.csv"
    ))

    ## Get unique breaks only (removes duplicates from quantiles with repeated values)
    unique_breaks <- unique(sort(c(p1$breaks_lower, p1$breaks_upper)))

    ## Reduce to max 20 bins for legend display
    max_bins <- 20
    if(length(unique_breaks) > max_bins) {
      ## Select evenly-spaced subset of breaks
      indices <- round(seq(1, length(unique_breaks), length.out = max_bins))
      legend_breaks <- unique_breaks[indices]
    } else {
      legend_breaks <- unique_breaks
    }

    leafletProxy("map1") |>
      clearGroup("spp") |>
      clearGroup("map1tiles") |>
      addTiles(
        group = "map1tiles",
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
          pane = "customtiles"
        )
      ) |>
      clearControls() |>
      addLegend(
        position = "bottomright",
        title = NULL,
        pal = colorBin(
          palette = p1$col,
          domain = range(unique_breaks),
          bins = legend_breaks,
          pretty = FALSE
        ),
        values = legend_breaks,
        opacity = 1
      )
    
    ## remove has-tiles class if no GBIF tiles are displayed
    runjs("$('#tilesLeft').siblings('.selectize-control').removeClass('has-tiles');")
  }, ignoreNULL = TRUE)

  ## add GBIF occurrence tiles ----
  ## Create debounced reactives to delay API calls until user stops typing/adjusting
  taxon_delayed <- debounce(reactive(input$taxonKey), 1000)
  year_delayed <- debounce(reactive(input$yearRange), 1000)

  observeEvent(c(taxon_delayed(), year_delayed()), {
    ## req stops execution if value is null or empty
    ## avoids api calls with invalid or empty search terms
    req(taxon_delayed())

    ## need to find taxon key given the species name
    nm <- taxon_delayed() |>
      str_to_title() |>
      URLencode()
    res <- paste0("https://api.gbif.org/v1/species/match?name=", nm) |>
      request() |>
      req_headers(user_agent = "DataSummaryWOBEC/1.0") |>
      req_perform()

    if(resp_status(res) < 400){
      taxa <- resp_body_json(res)
      key <- taxa$usageKey
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

      leafletProxy("map1") |>
        clearGroup("spp") |>
        clearGroup("map1tiles") |>
        clearControls() |>
        addTiles(
          group = "spp",
          urlTemplate = speciesOccurance,
          options = spp_options
        )

      ## add has-tiles to make selectize controls semi-transparent
      runjs("$('#tilesLeft').siblings('.selectize-control').addClass('has-tiles');")
    }
  })

  ## update right map tiles based on user selection ----
  observeEvent(input$tilesRight, {
    p2 <- read.csv(file.path(
      dirData, str_replace_all(input$tilesRight, "_", "/"),
      "palette.csv"
    ))

    ## Get unique breaks only (removes duplicates from quantiles with repeated values)
    unique_breaks <- unique(sort(c(p2$breaks_lower, p2$breaks_upper)))

    ## Reduce to max 20 bins for legend display
    max_bins <- 20
    if(length(unique_breaks) > max_bins) {
      ## Select evenly-spaced subset of breaks
      indices <- round(seq(1, length(unique_breaks), length.out = max_bins))
      legend_breaks <- unique_breaks[indices]
    } else {
      legend_breaks <- unique_breaks
    }

    leafletProxy("map2") |>
      clearGroup("map2tiles") |>
      addTiles(
        group = "map2tiles",
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
          pane = "customtiles"
        )
      ) |>
      clearControls() |>
      addLegend(
        position = "bottomright",
        title = NULL,
        pal = colorBin(
          palette = p2$col,
          domain = range(unique_breaks),
          bins = legend_breaks,
          pretty = FALSE
        ),
        values = legend_breaks,
        opacity = 1
      )
    
    ## remove transparency when switching back to Copernicus tiles
    runjs("$('#tilesRight').siblings('.selectize-control').removeClass('has-tiles');")
  })

  ## update map with distAnt data ----
  distAnt <- reactive({
    req(input$tilesDistAnt)

    info <- filter(distant_data, name == input$tilesDistAnt)
    tileDir <- file.path(dirData, "distAnt", info$dir)

    ## Read pre-generated palette
    pal <- read.csv(file.path(tileDir, "palette.csv"))

    return(list(
      dir = tileDir,
      pal = pal
    ))
  })

  observe({
    x <- distAnt()
    addResourcePath("distAntTiles", x$dir)

    ## Get unique breaks only (removes duplicates from quantiles with repeated values)
    unique_breaks <- unique(sort(c(x$pal$breaks_lower, x$pal$breaks_upper)))

    ## Reduce to max 20 bins for legend display
    max_bins <- 20
    if(length(unique_breaks) > max_bins) {
      ## Select evenly-spaced subset of breaks
      indices <- round(seq(1, length(unique_breaks), length.out = max_bins))
      legend_breaks <- unique_breaks[indices]
    } else {
      legend_breaks <- unique_breaks
    }

    leafletProxy("map2") |>
      clearGroup("map2tiles") |>
      addTiles(
        group = "map2tiles",
        urlTemplate = "distAntTiles/{z}/{x}/{-y}.png",
        # urlTemplate = sprintf("%s/{z}/{x}/{-y}.png", x$dir),
        options = tileOptions(
          tileSize = 256,
          noWrap = TRUE,
          opacity = 0.8,
          tms = TRUE,
          continuousWorld = TRUE,
          pane = "customtiles"
        )
      ) |>
      clearControls() |>
      addLegend(
        position = "bottomright",
        title = NULL,
        pal = colorBin(
          palette = x$pal$col,
          domain = range(unique_breaks),
          bins = legend_breaks,
          pretty = FALSE
        ),
        values = legend_breaks,
        opacity = 1
      )

    ## has-tiles class to make selectize controls semi-transparent
    runjs("$('#tilesRight').siblings('.selectize-control').addClass('has-tiles');")
  })

  ## handling user-uploaded data ----
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
  options(shiny.maxRequestSize = 30*1024^2)

  ## update when user uploads shapefile
  observe({
    message("Shpfile exists, adding to map...")
    uploaded_data <- shpdata()
    if(is.null(uploaded_data)){
      message("no shapefile for mapping...")
    }
    if(!is.null(uploaded_data)){
      ## add the uploaded layer to both maps
      leafletProxy("map1") |>
        clearGroup("uploaded_data") |>
        addPolygons(
          data = uploaded_data,
          group = "uploaded_data",
          col = "black",
          weight = 1.5,
          fillOpacity = 0,
          options = list(pane = "owndata")
        )
      leafletProxy("map2") |>
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
