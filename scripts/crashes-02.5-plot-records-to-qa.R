
# Description -------------------------------------------------------------

# Interactive QA map. Start with a blank base map, then search by crash report
# ID to display that record's raw (blue) and/or geocoded (orange) coordinates,
# with a connecting line when both are present.

# https://docs.google.com/spreadsheets/d/1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw/edit?usp=sharing (QA google sheet)


# load packages -----------------------------------------------------------

library(shiny)
library(bslib)
library(tidyverse)
library(leaflet)
library(sf)
library(here)

# specify where proj.db is located
Sys.setenv(PROJ_LIB="/opt/homebrew/Cellar/proj/9.4.0/share/proj")

# read in data ------------------------------------------------------------

df <- list.files(here("proc/records-to-qa/"), pattern = "^records-to-qa-.+\\.tsv$", full.names = TRUE) %>%
  map_dfr(read_tsv, show_col_types = FALSE)

city_boundary <- st_read(here("raw/pvd-city-boundaries/City_Boundary.shp"), quiet = TRUE) %>%
  st_transform(4326)

# helper: build popup html ------------------------------------------------

make_popup <- function(crash_report_id, address_sent_to_geocoder, nearest_intersection,
                       lat_raw, lon_raw, lat_api_best, lon_api_best, reason_for_qa) {
  raw_str <- if (is.na(lat_raw) || is.na(lon_raw)) "not available" else paste0(round(lat_raw, 5), ", ", round(lon_raw, 5))
  api_str <- if (is.na(lat_api_best) || is.na(lon_api_best)) "not available" else paste0(round(lat_api_best, 5), ", ", round(lon_api_best, 5))
  glue::glue("
    <b>ID:</b> {crash_report_id}<br>
    <b>Address:</b> {address_sent_to_geocoder}<br>
    <b>Nearest intersection:</b> {nearest_intersection}<br>
    <b>Raw coords:</b> {raw_str}<br>
    <b>Geocoded coords:</b> {api_str}<br>
    <b>Reason for QA:</b> {reason_for_qa}
  ")
}

# ui ----------------------------------------------------------------------

ui <- page_sidebar(
  title = "QA Crash Coordinates",
  sidebar = sidebar(
    textInput("search_id", "Crash report ID", placeholder = "e.g. 23573"),
    actionButton("search_btn", "Search", class = "btn-primary w-100"),
    uiOutput("search_result")
  ),
  leafletOutput("map", height = "100%"),
  fillable = TRUE
)

# server ------------------------------------------------------------------

server <- function(input, output, session) {

  # base map — no markers on load
  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(lng = -71.418, lat = 41.824, zoom = 13) %>%  # centered on Providence
      addPolygons(
        data        = city_boundary,
        color       = "#333333", weight = 2, opacity = 0.8,
        fill        = FALSE
      )
  })

  observeEvent(input$search_btn, {
    req(nchar(trimws(input$search_id)) > 0)

    id    <- suppressWarnings(as.integer(trimws(input$search_id)))
    match <- df %>% filter(crash_report_id == id)

    # clear previous markers, lines, and coordinate popup, then restore city boundary
    leafletProxy("map") %>%
      clearMarkers() %>%
      clearShapes() %>%
      removePopup("coord_popup") %>%
      addPolygons(
        data        = city_boundary,
        color       = "#333333", weight = 2, opacity = 0.8,
        fill        = FALSE
      )

    if (nrow(match) == 0) {
      output$search_result <- renderUI(
        tags$small(class = "text-danger", "ID not found.")
      )
      return()
    }

    r <- match[1, ]

    output$search_result <- renderUI(
      tags$small(class = "text-success", r$address_sent_to_geocoder)
    )

    has_raw <- !is.na(r$lat_raw) & !is.na(r$lon_raw)
    has_api <- !is.na(r$lat_api_best) & !is.na(r$lon_api_best)

    popup_html <- make_popup(r$crash_report_id, r$address_sent_to_geocoder,
                             r$nearest_intersection, r$lat_raw, r$lon_raw,
                             r$lat_api_best, r$lon_api_best, r$reason_for_qa)

    proxy <- leafletProxy("map")

    # connecting line
    if (has_raw & has_api) {
      proxy <- proxy %>%
        addPolylines(
          lng     = c(r$lon_raw, r$lon_api_best),
          lat     = c(r$lat_raw, r$lat_api_best),
          color   = "#999999", weight = 2, opacity = 0.8
        )
    }

    # raw coord — blue
    if (has_raw) {
      proxy <- proxy %>%
        addCircleMarkers(
          lng         = r$lon_raw,
          lat         = r$lat_raw,
          color       = "#2166ac", fillColor = "#2166ac",
          radius      = 8, weight = 1, fillOpacity = 0.9,
          popup       = popup_html
        )
    }

    # geocoded coord — orange
    if (has_api) {
      proxy <- proxy %>%
        addCircleMarkers(
          lng         = r$lon_api_best,
          lat         = r$lat_api_best,
          color       = "#d94701", fillColor = "#d94701",
          radius      = 8, weight = 1, fillOpacity = 0.9,
          popup       = popup_html
        )
    }

    # zoom to the record
    center_lat <- if (has_raw) r$lat_raw else r$lat_api_best
    center_lon <- if (has_raw) r$lon_raw else r$lon_api_best

    proxy %>% setView(lng = center_lon, lat = center_lat, zoom = 16)
  })

  # show lat/lon popup on map click
  observeEvent(input$map_click, {
    click <- input$map_click
    leafletProxy("map") %>%
      removePopup("coord_popup") %>%
      addPopups(
        lng     = click$lng,
        lat     = click$lat,
        popup   = paste0(round(click$lat, 5), ", ", round(click$lng, 5)),
        layerId = "coord_popup"
      )
  })
}

shinyApp(ui, server)

