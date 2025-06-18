htmlTemplate(
  filename = here("index.html"),

  ## header ----


  ## stakeholders of the Weddell Sea ----


  ## summary data ----
  leftmap_input = selectInput(
    inputId = "tilesLeft",
    label = NULL,
    choices = allrasters
  ),
  rightmap_input = selectInput(
    inputId = "tilesRight",
    label = NULL,
    choices = allrasters
  ),
  taxonkey_input = textInput(
    inputId = "taxonKey",
    label = NULL,
    value = ""
  ),
  distant_input = selectizeInput(
    inputId = "distAnt",
    label = "SCAR DistAnt",
    choices = distrasters,
    selected = NULL,
    options = list(
      placeholder = 'Select...',
      onInitialize = I('function() { this.setValue(""); }')
    )
  ),
  shapefile_input = fileInput(
    "shapefile",
    "Upload Shapefile",
    accept = c(".zip")
  ),

  ## main content area
  # timeseries_ui = plotOutput("timeseries", height = "36vh"),
  map1ui = leafletOutput(outputId = "map1", height = 480),
  map2ui = leafletOutput(outputId = "map2", height = 480)

  ## system graphic ----


  ## resources ----



  ## footer ----

)
