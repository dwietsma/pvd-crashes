
# Providence Crash Map Project

## Background
The Providence Street Coalition decided to create a crash map that displays the coordinates of cycling and pedestrian crashes in Providence, Rhode Island. The motivation of this project is to make these data transparent to the Providence community, and to potentially identify areas in the city that are particularly dangerous. The Coalition hopes that these data help inform community members, policy makers, planners, and safe street advocates about street safety conditions.

## Sourcing Data
A Providence Streets Coalition member submitted a FOIA request to Rhode Island's department of transportation to source statewide crash data. The request was denied. Read about it in this [ProJo article](https://www.providencejournal.com/story/news/local/2023/06/26/rhode-island-crash-data-dangerous-roads-providence-streets-coalition/70337934007/). The group was able to source Providence crash data from the city's police department. These are the data used in this project.

## Data Processing Steps
Notably, these data only represent crashes in the city when a police report is filed. The data set is longitudinal and includes crashes that occurred over more than a decade. 4,375 records (crashes) were present in the raw file as delivered by the police department. When a police report is filed from a crash, the officer records some general information about the incident and it's location. 

Although the raw data set included coordinates, the data team wanted to quality check these locations. We first ran the street address and intersection information through a series of google apis to obtain a different set of coordinates. We compared these google coordinates to the original (raw) coordinates. If the two coordinate sets were more than 100 meters from each other, we manually went through those records and determined which set appeared more accurate.

## How to Update
### Google API Key Setup
This project [requires a google api key](https://developers.google.com/maps/documentation/geocoding/get-api-key). Once you've generated the key, create a file: 'config/google-api-key.R'. Set your key in this file with: google_key <- "xyz"
