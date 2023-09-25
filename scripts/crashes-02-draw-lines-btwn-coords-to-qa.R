

# load packages -----------------------------------------------------------

library(tidyverse)
library(sf)

df <- read.csv("proc/addresses-with-gmaps-coordinates.tsv", sep = "\t")

df_selected <- df %>% 
  select(row_number, crash_report_id, street_or_highway, nearest_intersection, traffic_control,
         address_sent_to_geocoder, lat_raw, lon_raw, lat_api_best, lon_api_best, distance_btwn_coords_meters)

df_complete_cases <- df_selected %>% 
  drop_na(row_number, lon_api_best, lat_api_best, lon_raw, lat_raw)
  
sf_raw_coords <-  df_complete_cases %>% 
  select(row_number, lon_raw, lat_raw) %>% 
  st_as_sf(coords = c("lon_raw", "lat_raw"), crs = 4326)

sf_api_coords <- df_complete_cases %>% 
  select(row_number, lon_api_best, lat_api_best) %>% 
  st_as_sf(coords = c("lon_api_best", "lat_api_best"), crs = 4326)

# connect our coordinates with lines to visualize
sf_with_line_geo <- st_sfc(mapply(function(a,b){st_cast(st_union(a,b),"LINESTRING")}, sf_raw_coords$geometry, sf_api_coords$geometry, SIMPLIFY=FALSE)) %>% 
  bind_cols(df_complete_cases, .) %>% 
  rename("geometry" = ...13)

# determine which coords are best -----------------------------------------

# for each record, we need to determine whether the raw or geocoded coordinates are correct (or maybe neither)

# sf_final <- sf_with_line_geo %>% 
#   mutate(best_coords = case_when(street_or_highway == nearest_intersection ~ "Raw",
#                                  T ~ "Not yet determined"))

# write to google
sf_final %>% 
  filter(distance_btwn_coords_meters > 100) %>% 
  select(row_number, crash_report_id, best_coords) %>% 
  write_csv(here::here("proc/specify-which-coords-are-best.csv"))
  
# write out data ----------------------------------------------------------

sf_with_line_geo %>% 
  st_write(here::here("proc/lines-between-coordinates.shp"),
           append = FALSE)

