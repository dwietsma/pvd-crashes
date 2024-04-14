
# https://docs.google.com/spreadsheets/d/1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw/edit?usp=sharing (QA googlesheet)

# load packages -----------------------------------------------------------

library(tidyverse)
library(googlesheets4)
library(googledrive)

# read in data ------------------------------------------------------------

# connect to google drive & sheets
drive_auth(email = "dwietsma@gmail.com")
gs4_auth(token = drive_token())


filepaths <- list.files(here::here("proc"),
                        pattern = "^addresses-with-gmaps-coordinates.*.tsv",
                        full.names = T)

full_df <- map_dfr(.x = filepaths,
               .f = read.csv,
               sep = "\t",
               stringsAsFactors = F)

google_sheet <- read_sheet("1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw")

# cleanup google sheet data -----------------------------------------------

google_sheet_cleaned <- google_sheet %>% 
  select(-c(date_row_was_created, `notes (optional)`)) %>% 
  mutate(best_coordinate_set = case_when(best_coordinate_set == "Cannot be determined" ~ "Unknown",
                                         T ~ best_coordinate_set),
         corrected_lat = as.numeric(str_extract(correct_coordinates, "^(\\d|\\.)*")),
         corrected_lon = as.numeric(str_extract(correct_coordinates, "-\\d+\\.\\d+")))

manually_qaed_records <- google_sheet_cleaned$crash_report_id

# add and cleanup some fields in full_df ----------------------------------

# add manually created 'best_coordinate_set' field from out QA googlesheet to the full dataframe 
joined <-  left_join(full_df, google_sheet_cleaned, by = "crash_report_id")

# add a field that says whether our final_lat fields are Raw, Amended, or Unknown
final_full <- joined %>% 
  mutate(manually_qaed_record = if_else(crash_report_id %in% manually_qaed_records, T, F),
         street_intersects_self = case_when(street_or_highway == nearest_intersection ~ T,
                                            T ~ F),
         best_coordinate_set_expanded = case_when(is.na(lat_raw) & street_intersects_self == T ~ "Unknown", # records with no addresses, intersections or police (raw) coords must be unknown
                                                  !is.na(lat_raw) & street_intersects_self == T ~ "Raw", # no addresses or intersections, we must go with (raw) police coords
                                                  manually_qaed_record == T ~ best_coordinate_set, # for the rows we looked at, we use the selected coord set
                                                  T ~ "Raw"), # all else should be police (raw) coordinates
         final_lat = case_when(best_coordinate_set_expanded == "Neither" ~ corrected_lat,
                               best_coordinate_set_expanded == "Amended" ~ lat_api_best,
                               best_coordinate_set_expanded == "Raw" ~ lat_raw,
                               best_coordinate_set_expanded == "Unknown" ~ NA_real_),
         final_lon = case_when(best_coordinate_set_expanded == "Neither" ~ corrected_lon,
                               best_coordinate_set_expanded == "Amended" ~ lon_api_best,
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
            lat_api_best, lon_api_best, distance_btwn_coords_meters, corrected_lat, corrected_lon, correct_coordinates))

final_selected %>% 
  write_tsv("proc/processed-addresses-with-selected-fields.tsv")

# df <- readr::read_tsv("proc/processed-addresses-with-selected-fields.tsv")

