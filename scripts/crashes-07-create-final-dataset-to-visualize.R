
# Description -------------------------------------------------------------

# This script reads in the output of script 6. It does some final cleanup -
# selecting certain columns, refactoring variables, and jittering the coordinates
# to reduce points from overlapping on the map

# load packages -----------------------------------------------------------

library(tidyverse)
library(lubridate)
library(sf)
# here

# read in data ------------------------------------------------------------

df_raw <- read_tsv(here::here("proc/processed-addresses-with-selected-fields-and-pvd-nhoods-wards-and-blocks.tsv"),
                   col_types = cols(
                     row_number = col_double(),
                     crash_date = col_date(format = ""),
                     crash_report_id = col_double(),
                     crash_time = col_time(format = ""),
                     collision_type = col_character(),
                     count_pedestrian = col_double(),
                     count_bicycle = col_double(),
                     scooter = col_logical(),
                     wheel_chair = col_logical(),
                     number_of_vehicles = col_double(),
                     street_or_highway = col_character(),
                     nearest_intersection = col_character(),
                     report_date = col_character(),
                     type_of_roadway = col_character(),
                     road_surface_condition = col_character(),
                     light_condition = col_character(),
                     weather_condition = col_character(),
                     manner_of_impact = col_character(),
                     hit_and_run = col_character(),
                     traffic_control = col_character(),
                     person_count = col_double(),
                     injury_count = col_double(),
                     most_serious_injury = col_character(),
                     number_of_lanes = col_double(),
                     lat_raw = col_double(),
                     lon_raw = col_double(),
                     has_st_number = col_logical(),
                     is_intersection_null = col_logical(),
                     address_sent_to_geocoder = col_character(),
                     api_coord_conf = col_character(),
                     best_coordinate_set = col_character(),
                     manually_qaed_record = col_logical(),
                     street_intersects_self = col_logical(),
                     best_coordinate_set_expanded = col_character(),
                     final_lat = col_double(),
                     final_lon = col_double(),
                     year = col_double(),
                     month = col_character(),
                     pvd_nhood = col_character(),
                     pvd_wards = col_double(),
                     geoid20 = col_double()
                   ))

df_selected <- df_raw %>%
  select(year, crash_report_id, crash_date, crash_time, collision_type, address_sent_to_geocoder,
         hit_and_run, most_serious_injury, traffic_control, road_surface_condition,
         pvd_nhood, pvd_wards, geoid20,
         final_lat, final_lon) %>% 
  filter(!is.na(pvd_nhood))

# jitter final coordinates so they don't overlap --------------------------

df_final <- st_as_sf(df_selected, coords = c("final_lon", "final_lat"), crs = 4326) %>% 
  st_jitter(., factor = .002) %>% 
  mutate(final_lon = sf::st_coordinates(.)[,1],
         final_lat = sf::st_coordinates(.)[,2],
         traffic_controls = case_when(traffic_control == "No Controls" ~ "No Traffic Controls",
                                      traffic_control %in% c("Other", "Unknown") ~ "Other",
                                      traffic_control %in% c("Flashing Traffic Control Signal", 
                                                             "Pavement Markings",
                                                             "School Zone Signs",
                                                             "Stop Signs",
                                                             "Warning Signs",
                                                             "Yield Signs") ~ "Signs & Markings",
                                      
                                      TRUE ~ traffic_control),
         road_conditions = case_when(road_surface_condition %in% c("Slush", "Sand", "Ice/Frost",
                                                                   "Other", "Snow", "Unknown",
                                                                   "Mud, Dirt, Gravel") ~ "Other",
                                     T ~ road_surface_condition)) %>% 
  st_drop_geometry() %>% 
  select(-c(traffic_control, road_surface_condition))
  
# write out data ----------------------------------------------------------

df_final %>% 
  write_tsv(here::here("proc/final-pvd-crashes.tsv"))

# plot --------------------------------------------------------------------

# library(leaflet) 
# 
# df %>%
#   leaflet() %>%
#   addProviderTiles(providers$CartoDB.Positron) %>%
#   setView(lng = -71.402550, lat = 41.826771, zoom = 14) %>%
#   addCircles(stroke = T,
#              color = "black",
#              weight = 10)


