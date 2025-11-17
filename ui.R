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
  shapefile_input = fileInput(
    inputId = "shapefile",
    label = NULL,
    accept = c(".zip")
  ),
  taxonkey_input = textInput(
    inputId = "taxonKey",
    label = NULL,
    value = ""
  ),
  distant_input = selectizeInput(
    inputId = "distAnt",
    label = NULL,
    choices = distrasters,
    selected = NULL,
    options = list(
      placeholder = 'Select...',
      onInitialize = I('function() { this.setValue(""); }')
    )
  ),

  ## main content area
  # timeseries_ui = plotOutput("timeseries", height = "36vh"),
  map1ui = leafletOutput(outputId = "map1", height = "100%"),
  map2ui = leafletOutput(outputId = "map2", height = "100%"),

  map1caption = htmlOutput("map1cap"),
  map2caption = htmlOutput("map2cap")

  ## system graphic ----
  # d3_flower_ui = d3Output("d3_flower", height = "100%")


  ## resources ----



  ## footer ----

)
