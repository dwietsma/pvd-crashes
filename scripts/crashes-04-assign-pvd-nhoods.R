library(tidyverse)
library(here)
library(sf)
library(janitor)

# read in data ------------------------------------------------------------

pvd_nhoods <- st_read(
  here("raw/pvd-neighborhood-boundaries/geo_export_3baabfdf-9339-428d-a62e-9180506f7ca3.shp"),
  stringsAsFactors = F) %>% 
  clean_names() %>%
  st_transform(crs = 2163) # this converts to the planar crs, which will work best for the coordinate intersection later on

df_raw <- read_tsv(here("proc/processed-addresses-with-selected-fields.tsv"))

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

vector_of_lnames <- apply(st_intersects(pvd_nhoods, df_transformed, sparse = F), 2, 
                          function(col) {
                            pvd_nhoods[which(col),]$lname
                          })

# swap out all chracter(0) with NA
cleaned_vector_of_lnames <- modify_if(.x = vector_of_lnames,
                                      .p = ~length(.x) == 0,
                                      .f = ~NA)

# the above may return two neighborhoods if on the line, let's only keep the first
lname_keep_first <- map_chr(cleaned_vector_of_lnames, ~pluck(.x, 1))

# assign nhood variable
df_filtered$pvd_nhood <- lname_keep_first

# add null latitudes back in
final <- bind_rows(df_filtered, df_nas)

# add crash counts to pvd_nhoods ------------------------------------------

final_spatial <- final %>% 
  mutate(year = year(crash_date)) %>% 
  filter(year %in% c(2010:2022),
         !is.na(pvd_nhood)) %>% 
  group_by(pvd_nhood, year) %>% 
  summarise(crash_count = n()) %>% 
  left_join(pvd_nhoods, ., by = c("lname" = "pvd_nhood"))

# write out data ----------------------------------------------------------

final %>% 
  write_tsv(
    here::here("proc/processed-addresses-with-selected-fields-and-pvd-nhoods.tsv"))

final_spatial %>% 
  st_write(here::here("proc/crash-counts-by-pvd-nhoods/crash-counts-by-pvd-nhoods.shp"))

