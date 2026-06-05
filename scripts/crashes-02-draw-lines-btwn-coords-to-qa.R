
# Description -------------------------------------------------------------

# This script reads in the output of the first script. It calculates the distance 
# between the two sets of coordinates. If the coordinates seem far away from each
# other (>100 meters), or if there are no raw coordinates, the script writes those 
# records out to a googlesheet. These records are then visualized in scipr 2.5 
# and must be manually inspected. The analyst tries to determine which sets of 
# coordinates to use for the final charting - their entries in the google sheet 
# specify which coordinates are best. 

# https://docs.google.com/spreadsheets/d/1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw/edit?usp=sharing (QA googlesheet)

# load packages -----------------------------------------------------------

library(tidyverse)
# specify where proj.db is located
Sys.setenv(PROJ_LIB="/opt/homebrew/Cellar/proj/9.4.0/share/proj")
library(sf)
# install.packages('sf', repos = c('https://r-spatial.r-universe.dev'))
library(googlesheets4)
library(googledrive)

source(here::here("scripts/crashes-00-project-parameters.R"))

# read in data ------------------------------------------------------------

df <- read_tsv(here::here(glue::glue("proc/addresses-with-gmaps-coordinates-{raw_date_range}.tsv")))

sf_city_boundary <- st_read(here::here("raw/pvd-city-boundaries/City_Boundary.shp")) %>%
  st_transform(4326)

# select certain columns --------------------------------------------------

df_selected <- df %>% 
  select(row_number, crash_report_id, street_or_highway, nearest_intersection, traffic_control, type, type_of_roadway,
         address_sent_to_geocoder, lat_raw, lon_raw, lat_api_best, lon_api_best, distance_btwn_coords_meters)

# Calculate distance between coordinate sets ------------------------------

df_complete_cases <- df_selected %>% 
  drop_na(row_number, lon_api_best, lat_api_best, lon_raw, lat_raw)
  
sf_raw_coords <-  df_complete_cases %>% 
  select(row_number, lon_raw, lat_raw) %>% 
  st_as_sf(coords = c("lon_raw", "lat_raw"), crs = 4326)

sf_api_coords <- df_complete_cases %>% 
  select(row_number, lon_api_best, lat_api_best) %>% 
  st_as_sf(coords = c("lon_api_best", "lat_api_best"), crs = 4326)

# connect our coordinates with lines to visualize in tableau
sf_with_line_geo <- df_complete_cases %>%
  mutate(geometry = st_sfc(mapply(function(a,b){st_cast(st_union(a,b),"LINESTRING")},
                                  sf_raw_coords$geometry, sf_api_coords$geometry, SIMPLIFY=FALSE))) %>%
  st_as_sf(crs = 4326)
  
# Determine which coords are best -----------------------------------------

# Case 1: distance is greater than 100 ------------------------------------

# for each record, we need to determine whether the raw or geocoded coordinates are correct (or maybe neither)
# if the distance between the two sets of coordinates is 100 or greater, they should be manually inspected (via tableau)
# and the best coordinate set should be selected and recorded (via the google sheet)

plus_100m_dist <- sf_with_line_geo %>%
  mutate(best_coords = case_when(street_or_highway == nearest_intersection ~ "Raw",
                                 T ~ "Not yet determined"),
         reason_for_qa = "distance greater than 100m") %>% 
  filter(distance_btwn_coords_meters > 100)        

# Case 2: raw coordinates are NULL -----------------------------------------

records_with_missing_raw_coords_but_google_coords <- df_selected %>%  
  filter(is.na(lat_raw) | is.na(lon_raw)) %>%
  mutate(reason_for_qa = "raw coords null but geocoded coords found")

# Case 3: raw coords exist but fall outside Providence city boundaries -----

sf_raw_all <- df_selected %>%
  filter(!is.na(lat_raw) & !is.na(lon_raw)) %>%
  st_as_sf(coords = c("lon_raw", "lat_raw"), crs = 4326, remove = FALSE)

outside_city <- sf_raw_all %>%
  mutate(within_city = lengths(st_within(geometry, sf_city_boundary)) > 0) %>%
  filter(!within_city) %>%
  st_drop_geometry() %>%
  # exclude records already captured by the >100m criterion
  anti_join(plus_100m_dist, by = "crash_report_id") %>%
  mutate(best_coords = "Not yet determined",
         reason_for_qa = "raw coords fall outside of city boundary")

# Case 4: raw coords present but no geocoded coordinates ------------------

records_raw_only <- df_selected %>%
  filter(!is.na(lat_raw) & is.na(lat_api_best)) %>%
  mutate(best_coords = "Not yet determined",
         reason_for_qa = "raw coords exist but geocoded coords null")

# write out data to be visualized to help qa ------------------------------

# lines shapefile: records with both coord sets (distance >100m + outside-city with API)
outside_city_with_both <- outside_city %>%
  filter(!is.na(lat_api_best))

sf_lines_to_write <- if (nrow(outside_city_with_both) > 0) {
  sf_outside_city_lines <- outside_city_with_both %>%
    mutate(geometry = st_sfc(
      mapply(function(a, b) { st_cast(st_union(a, b), "LINESTRING") },
             st_as_sf(outside_city_with_both, coords = c("lon_raw", "lat_raw"), crs = 4326)$geometry,
             st_as_sf(outside_city_with_both, coords = c("lon_api_best", "lat_api_best"), crs = 4326)$geometry,
             SIMPLIFY = FALSE)
    )) %>%
    st_as_sf(crs = 4326)
  bind_rows(plus_100m_dist, sf_outside_city_lines)
} else {
  plus_100m_dist
}

# warning message is typical here
sf_lines_to_write %>%
  st_write(here::here("proc/qa-the-latest-batch-of-data/lines-between-coordinates.shp"),
           append = FALSE)

# points shapefile: records with raw coords only (no API coords to draw a line to)
outside_city_no_api <- outside_city %>%
  filter(is.na(lat_api_best))

bind_rows(records_raw_only, outside_city_no_api) %>%
  distinct(crash_report_id, .keep_all = TRUE) %>%
  st_as_sf(coords = c("lon_raw", "lat_raw"), crs = 4326) %>%
  st_write(here::here("proc/qa-the-latest-batch-of-data/points-raw-coord-only.shp"),
           append = FALSE)

# combine all four cases for google sheet ---------------------------------

final_gsheet <- plus_100m_dist %>% 
  st_drop_geometry() %>% 
bind_rows(
  .,                                                          # Case 1: distance > 100m
  select(records_with_missing_raw_coords_but_google_coords,   # Case 2: no raw, has API
         any_of(names(plus_100m_dist))),
  select(outside_city, any_of(names(plus_100m_dist))),         # Case 3: raw outside city
  select(records_raw_only, any_of(names(plus_100m_dist)))      # Case 4: raw only, no API
) %>%
  distinct(crash_report_id, .keep_all = TRUE)

# write records to qa to google sheet -------------------------------------

# connect to google drive & sheets

# designate project-specific cache
options(gargle_oauth_cache = here::here(".google_tokens"))

# check the value of the option, if you like
# gargle::gargle_oauth_cache()

# trigger auth on purpose --> store a token in the specified cache
# drive_auth()

# see your token file in the cache, if you like
# list.files(".google_tokens/")

# step 2 (do this all following runs)
# authorize
drive_auth(email = "dwietsma@gmail.com")
gs4_auth(token = drive_token())

# read in the existing records that have already been qa'ed
sheet_ss <- "1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw"
gsheet_existing_records <- read_sheet(sheet_ss)

# append only records whose crash ids have not already been qa'ed
append_these_rows_to_google <- final_gsheet %>% 
  select(crash_report_id,
         best_coordinate_set = best_coords,
         reason_for_qa) %>% 
  mutate(date_row_was_created = Sys.Date()) %>% 
  anti_join(., gsheet_existing_records, by = "crash_report_id")

# append rows
sheet_append(sheet_ss, append_these_rows_to_google, sheet = 1)

# write out for use in crashes-02.5
write_tsv(final_gsheet, here::here(glue::glue("proc/records-to-qa/records-to-qa-{raw_date_range}.tsv")))



