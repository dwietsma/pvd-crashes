
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

accidents_with_coords <- read_csv(here("proc/addresses-with-gmaps-coordinates.csv"))

# plot coordinates with leaflet -------------------------------------------

# recode injury field and jitter the coordinates to avoid overplotting
accidents_sf <- accidents_with_coords %>% 
  mutate(injury_recoded = case_when(most_serious_injury == "Fatal" ~ "Fatal",
                                    most_serious_injury == "Incapacitating" ~ "Incapacitating",
                                    T ~ "Other")) %>% 
  filter(!is.na(lon), !is.na(lat)) %>% 
  st_as_sf(coords = c("lon", "lat"), crs = 4326) %>% 
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

