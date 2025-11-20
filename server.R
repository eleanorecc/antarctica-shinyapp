server <- function(input, output, session) {

  ## temporary directory to save added data ----
  # addData <- file.path(tempdir(), paste0("session_", session$token))
  addData <- tempdir()
  dir.create(addData, showWarnings = FALSE)
  # session_addData <- reactiveVal(addData)

  ## track distAnt processing state ----
  processingDistAnt <- reactiveVal(FALSE)

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

  ## caption based on map layer ----
  getCaptionData <- function(layer_name) {
    if (layer_name %in% distcsv$name) {
      info <- filter(distcsv, name == layer_name)
      return(list(
        title = info$name,
        description = "Data accessed from SCAR DistAnt Ecological Model Output Repository",
        dataset = "https://source.coop/scar/distant",
        url = "https://source.coop/scar/distant",
        reference = info$reference
      ))
    }

    for (i in 1:nrow(caption_metadata)) {
      if (str_detect(layer_name, regex(caption_metadata$layer_pattern[i], ignore_case = TRUE))) {
        return(list(
          title = caption_metadata$title[i],
          description = caption_metadata$description[i],
          dataset = caption_metadata$dataset_name[i],
          url = caption_metadata$url[i],
          reference = ""
        ))
      }
    }

    return(list(title = "Data Layer", description = "", dataset = "", url = "", reference = ""))
  }

  renderCaption <- function(caption_data) {
    tags$div(
      tags$p(class = "caption-title", caption_data$title),
      tags$p(
        class = "intro-text",
        caption_data$description,
        if (nzchar(caption_data$dataset) && nzchar(caption_data$url)) {
          tagList(
            tags$br(),
            tags$a(href = caption_data$url, target = "_blank", style = "color:#205d9e", caption_data$dataset)
          )
        }
      ),
      if (nzchar(caption_data$reference)) {
        tags$p(class = "caption-reference", caption_data$reference)
      }
    )
  }

  output$map1cap <- renderUI({
    if (!is.null(input$taxonKey) && nzchar(input$taxonKey)) {
      renderCaption(list(
        title = "Species Observations Data",
        description = "Species observations (basis of record: human and machine observation) collected in the Global Biodiversity Information Facility (GBIF)",
        dataset = "api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?srs=EPSG:3031",
        url = "https://www.gbif.org/occurrence/search?occurrence_status=present",
        reference = ""
      ))
    } else {
      req(input$tilesLeft)
      renderCaption(getCaptionData(input$tilesLeft))
    }
  })

  output$map2cap <- renderUI({
    if (!is.null(input$tilesDistAnt) && nzchar(input$tilesDistAnt)) {
      renderCaption(getCaptionData(input$tilesDistAnt))
    } else {
      req(input$tilesRight)
      renderCaption(getCaptionData(input$tilesRight))
    }
  })

  ## update left map tiles based on user selection ----
  observeEvent(input$tilesLeft, {
    p1 <- read.csv(file.path(
      dirData,
      first(unlist(str_split(input$tilesLeft, "_"))),
      ifelse(str_detect(input$tilesLeft, "diff"), "diffspalette.csv", "palette.csv")
    ))
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
        title = str_replace(input$tilesLeft, "_", "<br>"),
        pal = colorNumeric(palette = p1$col, domain = p1$breaks),
        labFormat = labelFormat(
          transform = function(x) sort(x)
        ),
        values = p1$breaks,
        opacity = 1
      )
  }, ignoreNULL = TRUE)

  ## add GBIF occurrence tiles ----
  ## Create debounced reactives to delay API calls until user stops typing/adjusting
  taxon_delayed <- debounce(reactive(input$taxonKey), 1000)
  year_delayed <- debounce(reactive(input$yearRange), 1000)

  observeEvent(c(taxon_delayed(), year_delayed()), {
    req(taxon_delayed())

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
      ## Build URL with year range filter
      yr <- year_delayed()
      speciesOccurance <- paste(
        "https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?srs=EPSG%3A3031",
        paste0("taxonKey=", key),
        paste0("basisOfRecord=", c("HUMAN_OBSERVATION", "MACHINE_OBSERVATION"), collapse = "&"),
        paste0("years=", yr[1], ",", yr[2]),
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
    }
  })
  ## update right map tiles based on user selection ----
  observeEvent(input$tilesRight, {
    p2 <- read.csv(file.path(
      dirData,
      first(unlist(str_split(input$tilesRight, "_"))),
      ifelse(str_detect(input$tilesRight, "diff"),"diffspalette.csv","palette.csv")
    ))
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
        title = str_replace(input$tilesRight, "_", "<br>"),
        pal = colorNumeric(palette = p2$col, domain = p2$breaks),
        values = p2$breaks,
        opacity = 1
      )
  })

  ## distAnt progress indicator ----
  output$distAntProgress <- renderUI({
    if(processingDistAnt()) {
      tags$div(
        style = "margin-top: 8px;",
        tags$div(
          class = "progress-bar-container",
          tags$div(class = "progress-bar-fill")
        ),
        tags$p(
          style = "font-size: 10px; color: rgba(200, 210, 225, 0.9); margin-top: 4px;",
          "Processing layer... this may take a moment"
        )
      )
    }
  })

  ## set progress state when input changes (runs before reactive)----
  observeEvent(input$tilesDistAnt, {
    req(input$tilesDistAnt)
    info <- filter(distcsv, name == input$tilesDistAnt)
    tileDir <- file.path(addData, info$dir)

    if(!file.exists(file.path(tileDir, "palette.csv"))) {
      processingDistAnt(TRUE)
    } else {
      processingDistAnt(FALSE)
    }
  }, priority = 10)  ## Higher priority ensures this runs first

  ## update map with distAnt data ----
  distAnt <- reactive({
    req(input$tilesDistAnt)

    ## ADD STUFF ABOUT PROCESSING/PROGRESS BAR HERE

    info <- filter(distcsv, name == input$tilesDistAnt)
    tileDir <- file.path(addData, info$dir)

    ## check if tiles already exist
    file_palette <- file.path(tileDir, "palette.csv")
    if(file.exists(file_palette)){
      pal <- read.csv(file_palette)
    } else {
      ## (enable caching)
      dir.create(tileDir, recursive = TRUE, showWarnings = FALSE)

      r <- curl_fetch_memory(info$url)
      if(r$status_code == 200){
        ## stream raster via GDAL VSI (no full download needed)
        message("Streaming COG and processing...")
        vsi_url <- paste0("/vsicurl/", info$url)

        ## template matching leaflet map tiles/extent
        x <- 12367396.2185
        template <- rast(ext(c(-x,x,-x,x)), nrow = 8192, ncol = 8192, crs = crs("EPSG:3031"))

        ## project to sterographic south after cropping
        ## then resample to template (using VSI streaming)
        message("Reprojecting and cropping data...")
        rresamp <- project(rast(vsi_url, lyrs = info$lyrnum), "EPSG:4326") |>
          crop(ext(c(-180, 180, -90, -50))) |>
          project("EPSG:3031") |>
          resample(template)

        message("Creating quantile-based color palette...")
        ## Calculate 257 quantile breaks from the full data range
        ## This gives actual data values at each percentile
        qt <- global(rresamp, quantile, probs = seq(0, 1, length.out = 257), na.rm = TRUE)
        breaks <- unlist(qt)

        message("Converting to 8-bit indexed color via quantile classification...")
        ## Classify data into 256 bins based on quantile breaks
        ## This allocates equal pixel counts per bin, giving better differentiation
        ## to the middle values without losing extreme value representation
        rcm <- matrix(c(breaks[1:256], breaks[2:257], 0:255), ncol = 3)
        rint <- classify(rresamp, rcm, include.lowest = TRUE, right = FALSE)
        cols <- data.frame(value = 0:255, col = hcl.colors(256, "viridis"))
        coltab(rint) <- cols

        writeRaster(
          rint, file.path(tileDir, "rint.tif"),
          datatype = "INT1U",
          overwrite = TRUE
        )
        ## each color index maps to original data value range
        pal <- data.frame(
          breaks_lower = breaks[1:256],
          breaks_upper = breaks[2:257],
          value = 0:255,
          col = cols$col
        ) 
        write.csv(
          pal, file.path(tileDir, "palette.csv"),
          row.names = FALSE
        )

        message("Creating VRT with RGBA expansion...")
        ## Use system call - simple, robust, works across environments
        ## gdal_translate is a C++ binary, no Python/numpy dependency
        system(paste(
          "gdal_translate -of vrt -expand rgba",
          file.path(tileDir, "rint.tif"),
          file.path(tileDir, "rint.vrt")
        ))

        message("Generating tiles...")
        ## Use Python binding - ensures numpy version consistency from requirements.txt
        ## gdal2tiles.py is numpy-intensive, needs correct Python environment
        gdal2tiles <- import("osgeo_utils.gdal2tiles")
        gdal2tiles$main(list(
          'gdal2tiles.py',
          '-p', 'raster',
          '-z', '3-4',
          '-x',
          '--tmscompatible',
          file.path(tileDir, "rint.vrt"),
          tileDir
        ))
        message("Tiles complete!\n\n")
      }
      pal <- read.csv(file.path(tileDir, "palette.csv"))
    }
    return(list(
      dir = tileDir,
      pal = pal
    ))
  })

  observe({
    message("adding distAnt tiles to map...")
    x <- distAnt()

    message(sprintf("filepath %s exists: %s", x$dir, file.exists(x$dir)))
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
        title = "DistAnt<br>Model",
        pal = colorBin(
          palette = x$pal$col,
          domain = range(unique_breaks),
          bins = legend_breaks,
          pretty = FALSE
        ),
        values = legend_breaks,
        opacity = 1
      )

    ## Tiles successfully added, hide progress indicator
    processingDistAnt(FALSE)
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
