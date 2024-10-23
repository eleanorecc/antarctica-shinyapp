ui <- page_sidebar(
  tags$head(
    tags$style(HTML("
      #map {
        height: 58vh !important;
      }
      #map2 {
        height: 58vh !important;
      }
    "))
  ),

  ## input elements in sidebar ----
  sidebar = sidebar(
    h2("ANTARCTICA MARINE DATA"),
    # p("MAP1", style = "font-weight: bold; font-size: 18px"),
    p(
      "Use 'draw polyline' button in the top left of the map toolbar
      to draw on the map and view time series for those points,
      or cross-section of the data shown on the map.",
      style = "font-size: 12px; color: #606891"
    ),
    selectInput(
      inputId = "plottype",
      label = "Plot Type",
      choices = c("Time Series", "Cross Section"),
      selected = "Time Series"
    ),
    selectInput(
      inputId = "dataset",
      label = "Dataset",
      choices = c(
        `siconc, interm period` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_myint_0.083deg_P1M-m_202311/siconc",
        `Sea Ice Thickness (June 2024)` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_myint_0.083deg_P1M-m_202311/sithick",
        `Salinity (June 2024)` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_myint_0.083deg_P1M-m_202311/so",
        `Temperature (June 2024)` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_myint_0.083deg_P1M-m_202311/thetao",
        `Sea Ice Velocity (June 2024)` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_myint_0.083deg_P1M-m_202311/sea_ice_velocity",
        `Sea Ice Concentration (June 2021)` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_my_0.083deg_P1M-m_202311/siconc",
        `Sea Ice Thickness (June 2021)` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_my_0.083deg_P1M-m_202311/sithick",
        `Salinity (June 2021)` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_my_0.083deg_P1M-m_202311/so",
        `Temperature (June 2021)` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_my_0.083deg_P1M-m_202311/thetao",
        `Sea Ice Velocity (June 2021)` = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_my_0.083deg_P1M-m_202311/sea_ice_velocity"
      ),
      selected = "GLOBAL_MULTIYEAR_PHY_001_030/cmems_mod_glo_phy_myint_0.083deg_P1M-m_202311/siconc"
    ),
    br(),
    p(
      "Enter numeric GBIF taxon key (https://www.gbif.org/species) to add
      human and machine observation records from GBIF.",
      style = "font-size: 12px; color: #606891"
    ),
    textInput(
      inputId = "taxonkey",
      label = "GBIF Taxon Key",
      value = ""
    ),
    br(),
    p(
      "Upload a zipped shapefile (.zip) to view as an overlay on the map.",
      style = "font-size: 12px; color: #606891"
    ),
    fileInput(
      "shapefile",
      "Upload Shapefile",
      accept = c(".zip")
    ),
  ),

  ## output from server function ----

  ## maps
  nav_panel(
    "Main Panel",
    navset_tab(
      nav_panel(
        "MAP1",
        leafletOutput(outputId = "map2")
      ),
      nav_panel(
        "MAP2",
        leafletOutput(outputId = "map")
      )
    )
  ),

  ## timeseries or cross section plot
  highchartOutput("elevation_plot", height = "35vh")
)
