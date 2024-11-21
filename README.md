# Providence Crash Map Project

## Background

The Providence Street Coalition decided to create a crash map that displays the coordinates of cycling and pedestrian crashes in Providence, Rhode Island. The motivation of this project is to make these data transparent to the Providence community, and to potentially identify areas in the city that are particularly dangerous. The Coalition hopes that these data help inform community members, policy makers, planners, and safe street advocates about street safety conditions.

## Data Sourcing Overview

A Providence Streets Coalition member submitted a FOIA request to Rhode Island's department of transportation to source statewide crash data. The request was denied. Read about it in this [ProJo article](https://www.providencejournal.com/story/news/local/2023/06/26/rhode-island-crash-data-dangerous-roads-providence-streets-coalition/70337934007/). The group was able to source Providence crash data from the city's police department. These are the data used in this project.

## Data Processing and QA Overview

Notably, these data only represent crashes in the city when a police report is filed. The data set is longitudinal and includes crashes that occurred over more than a decade. When a police report is filed from a crash, the officer records some general information about the incident and it's location.

Although the raw data set included coordinates, the data team wanted to quality check these locations. The 1st script runs the street address and intersection information through a series of google apis to obtain secondary coordinate sets. We compare the original (raw) coordinates to the secondary coordinates (returned by google). If the coordinate sets are more than 100 meters apart, we write these records to a [shared googlesheet](https://docs.google.com/spreadsheets/d/1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw/edit?usp=sharing%20(QA%20googlesheet)). We manually inspect the records in the googlesheet with the help of a tableau visualization. In the googlesheet we specify which coordinate sets are best (occasionally it's neither and we write in alternative coordinates to use). These records get re-absorbed and eventually inform a series of tableau and arc map visualizations.

## How to Update

Data request info

### Google API Key Setup

This project [requires a google api key](https://developers.google.com/maps/documentation/geocoding/get-api-key). Once you've generated the key, create a file: 'config/google-api-key.R'. Set your key in this file with: google_key \<- "xyz"

### R package setup with renv

googlesheet manually inspection

### updating tableau (extracts)

data -\> 'refresh' all extracts update year in title if needed
