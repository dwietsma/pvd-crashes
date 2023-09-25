

# load packages -----------------------------------------------------------

library(tidyverse)
library(googlesheets4)
library(googledrive)

# read in data ------------------------------------------------------------

# connect to google drive & sheets
drive_auth(email = "dwietsma@gmail.com")
gs4_auth(token = drive_token())

full_df <- read.csv("proc/addresses-with-gmaps-coordinates.tsv",
                    sep = "\t",
                    stringsAsFactors = F)

google_sheet <- read_sheet("1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw")


# add and cleanup some fields in full_df ----------------------------------

# add manually created 'best_coordinate_set' field from out QA googlesheet to the full dataframe 
joined <- google_sheet %>% 
  select(crash_report_id, best_coordinate_set) %>% 
  left_join(full_df, ., by = "crash_report_id")

# add a field that says whether our final_lat fields are Raw, Amended, or Unknown
final_full <- joined %>% 
  mutate(street_intersects_self = case_when(street_or_highway == nearest_intersection ~ T,
                                            T ~ F),
         best_coordinate_set_expanded = case_when(is.na(lat_raw) & street_intersects_self == T ~ "Unknown",
                                                  !is.na(lat_raw) & street_intersects_self == T ~ "Raw",
                                                  best_coordinate_set == "Geocoded" ~ "Amended",
                                                  is.na(lat_raw) ~ "Amended",
                                                  T ~ "Raw"),
         final_lat = case_when(best_coordinate_set_expanded == "Amended" ~ lat_api_best,
                               best_coordinate_set_expanded == "Raw" ~ lat_raw,
                               best_coordinate_set_expanded == "Unknown" ~ NA_real_),
         final_lon = case_when(best_coordinate_set_expanded == "Amended" ~ lon_api_best,
                               best_coordinate_set_expanded == "Raw" ~ lon_raw,
                               best_coordinate_set_expanded == "Unknown" ~ NA_real_))
  
# write out data ----------------------------------------------------------

# write out all of the messy fields
final_full %>% 
  write_tsv("proc/processed-addresses-with-all-fields.tsv")

# remove some of the messy fields and write out a more streamlined data set
final_selected <- final_full %>% 
  select(-c(is_address_blank, lon_api_first_try, lat_api_first_try, type, 
            loctype, address_returned_by_geocoder, address_returned_by_autocomplete, 
            place_ids_autocompleted, lat_api_second_try, lon_api_second_try, 
            lat_api_best, lon_api_best, distance_btwn_coords_meters))

final_selected %>% 
  write_tsv("proc/processed-addresses-with-selected-fields.tsv")

# df <- readr::read_tsv("proc/processed-addresses-with-selected-fields.tsv")

