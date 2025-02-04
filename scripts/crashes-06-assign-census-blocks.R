
# Description -------------------------------------------------------------

# This script reads in the output of script 5 and a shapefile of Providence census block 
# It intersects the final coordinate set with the ward geometeries to assign
# a census block to each record.

# load packages -----------------------------------------------------------
library(tidyverse)
library(here)
# set the proj environmental variable, location would change depending on setup
Sys.setenv(PROJ_LIB = "/opt/homebrew/Cellar/proj/9.4.0/share/proj")
library(sf)
library(janitor)
library(lubridate)

# read in data ------------------------------------------------------------

# set the proj environmental variable, location would change depending on setup
Sys.setenv(PROJ_LIB = "/opt/homebrew/Cellar/proj/9.4.0/share/proj")
  
ri_blocks <- st_read(
  here::here("raw/ri-census-blocks/tl_2022_44_tabblock20.shp"),
  stringsAsFactors = F) %>% 
  clean_names() %>%
  st_transform(crs = 2163) # this converts to the planar crs, which will work best for the coordinate intersection later on

df_raw <- read_tsv(here::here("proc/processed-addresses-with-selected-fields-and-pvd-nhoods-and-wards.tsv"))

# -------------------------------------------------------------------------

# remove nas because they will break our function below
df_filtered <- df_raw %>% 
  filter(!is.na(final_lat))

# set na latitudes asside, we will add them back in later
df_nas <- filter(df_raw, is.na(final_lat))

# transform into sf class
df_transformed <- st_as_sf(x = df_filtered,
                           coords = c("final_lon", "final_lat"),
                           crs = 4326) %>% # need to first assign crs, https://crd150.github.io/georeferencing.html
  st_transform(crs = 2163) # then transform to planar to avoid later warnings

# apply function to each row to intersect neighboorhoods and coordinates
# https://gis.stackexchange.com/questions/282750/identify-polygon-containing-point-with-r-sf-package

vector_of_blocks <- apply(st_intersects(ri_blocks, df_transformed, sparse = F), 2, 
                            function(col) {
                              ri_blocks[which(col),]$geoid20
                            })

# swap out all chracter(0) with NA
cleaned_vector_of_blocks <- modify_if(.x = vector_of_blocks,
                                      .p = ~length(.x) == 0,
                                      .f = ~NA)

# the above may return two neighborhoods if on the line, let's only keep the first
block_keep_first <- map_chr(cleaned_vector_of_blocks, ~pluck(.x, 1))

# assign nhood variable
df_filtered$geoid20 <- block_keep_first

# add null latitudes back in
final <- bind_rows(df_filtered, df_nas)

final_spatial <- final %>% 
  mutate(year = year(crash_date)) %>% 
  filter(!is.na(geoid20)) %>% 
  group_by(geoid20, year) %>% 
  summarise(crash_count = n(), .groups = "drop") %>% 
  left_join(ri_blocks, ., by = "geoid20") %>% 
  group_by(tractce20) %>% 
  filter(any(!is.na(crash_count))) %>% 
  ungroup() %>% 
  filter(!tractce20 %in% c("010800", "012500", "012000", "010200",
                           "013500", "014700", "014100")) %>% 
  replace_na(list(crash_count = 0))

# write out data ----------------------------------------------------------

final %>% 
  write_tsv(
    here::here("proc/processed-addresses-with-selected-fields-and-pvd-nhoods-wards-and-blocks.tsv"))

final_spatial %>% 
  st_write(here::here("proc/crash-counts-by-pvd-census-blocks/crash-counts-by-pvd-census-blocks.shp"),
           append = FALSE)


