htmlTemplate(
  filename = here("index.html"),

  ## Enable shinyjs for JavaScript execution
  shinyjs_init = useShinyjs(),

  ## Box A — left map inputs
  boxa_left_input = selectInput(
    inputId = "tilesLeft",
    label = NULL,
    choices = allrasters
  ),
  taxonkey_input = textInput(
    inputId = "taxonKey",
    label = NULL,
    value = ""
  ),
  gbif_years = sliderInput(
    inputId = "yearRange",
    label = NULL,
    min = 1900,
    max = as.integer(format(Sys.Date(), "%Y")),
    value = c(2000, 2020),
    step = 1,
    sep = ""
  ),

  ## Box B — right map inputs
  boxb_right_input = selectInput(
    inputId = "tilesRight",
    label = NULL,
    choices = allrasters
  ),
  distant_input = selectizeInput(
    inputId = "tilesDistAnt",
    label = NULL,
    choices = distrasters,
    selected = NULL,
    options = list(
      placeholder = 'Select...',
      onInitialize = I('function() { this.setValue(""); }')
    )
  ),

  ## Box C — shared overlays
  overlay_input = selectizeInput(
    inputId = "overlayGroups",
    label = NULL,
    choices = c(
      "Statistical Areas", "WOBEC Expedition", "HAFOS Expedition", 
      "Study Area", "Points of Interest", "Marginal Ice Zone"
    ),
    selected = NULL,
    multiple = TRUE,
    options = list(placeholder = "Add overlay...")
  ),
  miz_date_input = dateInput(
    inputId = "mizDate",
    label = NULL,
    value = NA
  ),
  wobec_device_input = selectizeInput(
    inputId = "wobecDevices", 
    label = NULL,
    choices = devices_wobec, 
    selected = NULL,
    multiple = TRUE,
    options = list(placeholder = "WOBEC (2025/12/15 - 2026/2/2) sampling by method/device...")
  ),
  hafos_device_input = selectizeInput(
    inputId = "hafosDevices", label = NULL,
    choices = devices_hafos, selected = NULL, multiple = TRUE,
    options = list(placeholder = "HAFOS (2024/12/24 - 2025/3/10) sampling by method/device...")
  ),
  shapefile_input = fileInput(
    inputId = "shapefile",
    label = NULL,
    accept = c(".zip")
  ),

  ## main content area
  mapui = leafletOutput(outputId = "map", height = "100%"),

  map1caption = uiOutput("map1cap"),
  map2caption = uiOutput("map2cap")
)
