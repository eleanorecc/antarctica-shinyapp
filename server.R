server <- function(input, output, session) {

  ## map ----

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

    basemap <- leaflet(options = map_options) |>
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
      addDrawToolbar(
        targetGroup = "draw",
        singleFeature = TRUE,
        polygonOptions = FALSE,
        markerOptions = FALSE,
        rectangleOptions = FALSE,
        circleOptions = FALSE,
        circleMarkerOptions = FALSE,
        editOptions = editToolbarOptions(
          edit = FALSE,
          remove = TRUE,
          selectedPathOptions = selectedPathOptions()
        )
      ) |>
    addLayersControl(
      overlayGroups = c("Statistical Areas", "Study Area", "Points of Interest"),
      position = "bottomleft"
    ) |>
    hideGroup("Statistical Areas") |>
    hideGroup("Study Area") |>
    hideGroup("Points of Interest") |>
    addPolygons(
      data = asd,
      group = "Statistical Areas",
      fillOpacity = 0, weight = 1,
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
  })
  observeEvent(input$taxonkey, {
    taxon_delayed <- debounce(reactive(input$taxonkey), 1000)
    res <- paste0("https://api.gbif.org/v1/species/match?name=", URLencode(taxon_delayed())) |>
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
      speciesOccurance <- paste(
        "https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?srs=EPSG%3A3031",
        paste0("taxonKey=", key),
        paste0("basisOfRecord=", c("HUMAN_OBSERVATION", "MACHINE_OBSERVATION"), collapse = "&"),
        "style=purpleYellow.point",
        sep = "&"
      )
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

  ## handling user-uploaded data ----
  shpdata <- reactive({
    ## req ensures this code only runs when a file is uploaded
    req(input$shapefile)

    ## unzip the uploaded shapefile
    dirtmp <- tempdir()
    unzip(input$shapefile$datapath, exdir = dirtmp)
    tmpfile <- list.files(dirtmp, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
    tmpfile <- tmpfile[[1]]
    if(length(tmpfile) == 1){
      shpfile <- st_read(tmpfile) |>
        rmapshaper::ms_simplify(keep = 0.01) |>
        st_geometry()
      ## vector geometries need to be in latlon for leaflet
      if(st_crs(shpfile) != st_crs("EPSG:4326")){
        shpfile <- st_transform(shpfile, st_crs("EPSG:4326"))
      }
    } else {
      ## TODO check the shp has at least 30% overlap with map latitudes?
      shpfile <- NULL
    }
    return(shpfile)
  })

  ## increase upload limit to 30MB (from default of 5) in options
  options(shiny.maxRequestSize = 30*1024^2)

  ## update when user uploads shapefile
  observe({
    message("SHPDATA EXISTS; ADD TO MAP...")
    uploaded_data <- shpdata()
    if(is.null(uploaded_data)){message("NULL  SHP DATA  FOR MAPPING...")}
    if(!is.null(uploaded_data)){
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
    }
  })



  ## time series plots ----
  output$timeseries <- renderPlot({
    plotvars <- c(input$tilesLeft, input$tilesRight) |>
      str_split("_[0-9]{4}") |>
      lapply(function(x){first(unlist(x))}) |>
      unlist()

    df <- filter(tsdata, plot_with %in% plotvars)
    # yTitle <- paste0(unique(df$yaxislabel), "\n")

    ggplot(df) +
      geom_point(aes(x = year, y = yvariable, color = plot_with), size = 2) +
      geom_line(aes(x = year, y = yvariable, color = plot_with), linewidth = 0.4) +
      facet_wrap(~yaxislabel, ncol = 1, scales = "free") +
      labs(x = "Year", y = NULL, color = NULL) +
      theme(
        legend.text = element_text(size = 12),
        strip.text = element_text(size = 16),
        axis.text = element_text(size = 14)
      )
  })
}
