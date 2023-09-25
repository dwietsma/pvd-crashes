
# load packages -----------------------------------------------------------

library(tidyverse)
library(here)
library(ggmap)
library(leaflet)
library(viridis)
library(RColorBrewer)
library(sf)
library(mapview)

# read in data ------------------------------------------------------------

accidents_with_coords <- read_tsv(here::here("proc/processed-addresses-with-selected-fields.tsv"),
                                  col_types = cols(
                                    .default = col_character(),
                                    row_number = col_double(),
                                    crash_date = col_date(format = ""),
                                    crash_report_id = col_double(),
                                    crash_time = col_time(format = ""),
                                    count_pedestrian = col_double(),
                                    count_bicycle = col_double(),
                                    scooter = col_logical(),
                                    wheel_chair = col_logical(),
                                    number_of_vehicles = col_double(),
                                    report_date = col_date(format = ""),
                                    person_count = col_double(),
                                    injury_count = col_double(),
                                    number_of_lanes = col_double(),
                                    lat_raw = col_double(),
                                    lon_raw = col_double(),
                                    has_st_number = col_logical(),
                                    is_intersection_null = col_logical(),
                                    street_intersects_self = col_logical(),
                                    final_lat = col_double(),
                                    final_lon = col_double()
                                  ))

# plot coordinates with leaflet -------------------------------------------

# recode injury field and jitter the coordinates to avoid overplotting
accidents_sf <- accidents_with_coords %>% 
  mutate(injury_recoded = case_when(most_serious_injury == "Fatal" ~ "Fatal",
                                    most_serious_injury == "Incapacitating" ~ "Incapacitating",
                                    T ~ "Other")) %>% 
  filter(!is.na(final_lon), !is.na(final_lat)) %>% 
  st_as_sf(coords = c("final_lon", "final_lat"), crs = 4326) %>% 
  st_jitter(factor = 0.000005) 

# define color palette
# Call RColorBrewer::display.brewer.all() to see all possible palettes
pal <- colorFactor(palette = c("red2", "orange3", "steelblue2"), domain = accidents_with_coords$injury_recoded)

accidents_sf %>%
  leaflet() %>% 
  addProviderTiles(providers$CartoDB.Positron) %>%
  setView(lng = -71.402550, lat = 41.826771, zoom = 13) %>%
  addCircles(stroke = T,
             color = "black",
             weight = .5,
             radius = 25,
             fillOpacity = .7,
             fillColor = ~pal(injury_recoded)) %>% 
  addLegend("bottomright", 
            pal = pal,
            values = ~injury_recoded)


# plot spatial density ----------------------------------------------------

# Spatial density plot
base_map <- get_map(location = c(lon = -71.402550, lat = 41.826771), 
                    zoom = 13,
                    source = "stamen",
                    color = "bw")

base_map_for_gg <- ggmap(base_map, extent = "device", legend = "none")

base_map_for_gg + 
  stat_density2d(data = accidents_with_coords,
                 aes(x = lon, y = lat, fill=..level.., alpha=..level..),
                 geom="polygon",
                 show.legend = F) +
  scale_fill_viridis(option="C") +
  guides(size=FALSE, alpha = FALSE)

