#### This script validates VE model results using Latch 2017 DVMT data
  ### Files required: Latch 2017 data with est_vmiles field, crosswalk of 2010 Census tracts to Bzones,
  ### and previous model results ready to crosswalk for comparison

### The latch field to use is 'est_vmiles' which represents vmt per household

library(tidyverse)
library(rstudioapi)
library(openxlsx)
library(scales)
library(ggplot2)
library(tidycensus)
library(data.table)
library(sf)

setwd(dirname(getActiveDocumentContext()$path))

## Load files
tracts20 <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'Bzone to Tracts 2020')
tracts <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'Bzone for Latch')
census_to_bzone <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'Census to Bzone')
census_to_azone <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'Census to Azone')
hh_df <- read.csv('../results/output/Household_outputs.csv')
bzone_df <- read.csv('../results/output/Bzone_outputs.csv')
veh_df <- read.csv('../results/output/vehicle_outputs.csv')
latch <- read.csv('../defs/latch_2017-b(2).csv') %>%
  select(geocode, est_vmiles)
ve <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'VE')

##### Validation sources:
# Latch 2017: https://www.bts.gov/latch/latch-data
# FHWA licensed drivers by state 2019: https://www.fhwa.dot.gov/policyinformation/statistics/2019/dl1c.cfm
# DMV licensed drivers by county: https://www.oregon.gov/odot/DMV/docs/2019_age_summary.pdf
# Vehicles by MPO data: https://orscenplg.github.io/VEWiki/chapter3.html?q=valid#model-calibration-and-validation
    ## The SKATS MPO total household vehicles = 203004
# SKATS MPO LRTP 2020 population figures (Appendix A): https://www.mwvcog.org/media/3286
# Income data: ACS 2020
# Activity density D1D variable compared to Smart Location Database: https://www.epa.gov/smartgrowth/smart-location-mapping#SLD

### Load validation measures
temp <- hh_df %>%
  filter(Year==2020) %>%
  group_by(Bzone) %>%
  summarize(Dvmt_ve=sum(Dvmt, na.rm = T),
            population_ve=sum(HhSize, na.rm = T),
            Income_ve=sum(Income, na.rm = T),
            Vehicles_ve=sum(Vehicles, na.rm = T),
            Drivers_ve=sum(Drivers, na.rm = T)) %>%
  ungroup() %>%
  mutate(Income_pc_ve=round(Income_ve/population_ve))

spatial <- bzone_df %>%
  filter(Year==2020) %>%
  select(Bzone, NumHh, D1D) %>%
  left_join(temp) %>%
  mutate(Dvmt_ve=ifelse(is.na(Dvmt_ve), 0, Dvmt_ve)) %>%
  mutate(Dvmt_per_hh_ve=round(Dvmt_ve/NumHh, 1),
         Dvmt_per_hh_ve=ifelse(is.nan(Dvmt_per_hh_ve), 0, Dvmt_per_hh_ve))

##### VMT
vmt_tract <- tracts %>%
  left_join(spatial) %>%
  mutate(NumHh=NumHh*pct_bzone,
         Dvmt_ve=Dvmt_ve*pct_bzone) %>%
  group_by(GEOID) %>%
  summarize(NumHh=sum(NumHh, na.rm = T),
            Dvmt_ve=sum(Dvmt_ve, na.rm = T))
    #### verify DVMT and NumHh - differences are very small
    print(sum(vmt_tract$Dvmt_ve)-sum(spatial$Dvmt_ve))
    print(sum(vmt_tract$NumHh)-sum(spatial$NumHh))
  
vmt_tract <- vmt_tract %>%
  left_join(latch, by=c('GEOID'='geocode')) %>%
  mutate(Dvmt_per_hh_ve=Dvmt_ve/NumHh,
         Dvmt_per_hh_ve=ifelse(is.infinite(Dvmt_per_hh_ve), 0, Dvmt_per_hh_ve),
         pct_diff=(est_vmiles-Dvmt_per_hh_ve)/Dvmt_per_hh_ve,
         pct_diff=ifelse(is.nan(pct_diff) | is.na(pct_diff) | is.infinite(pct_diff), 0, pct_diff))

vmt_azone <- tracts %>%
  left_join(spatial) %>%
  mutate(NumHh=NumHh*pct_bzone,
         Dvmt_ve=Dvmt_ve*pct_bzone) %>%
  left_join(latch, by=c('GEOID'='geocode')) %>%
  group_by(Bzone) %>%
  summarize(NumHh=sum(NumHh, na.rm = T),
            Dvmt_ve=sum(Dvmt_ve, na.rm = T),
            est_vmiles=mean(est_vmiles, na.rm = T)) %>%
  ungroup()
    #### verify DVMT and NumHh - differences are very small
    print(sum(vmt_azone$Dvmt_ve)-sum(spatial$Dvmt_ve))
    print(sum(vmt_azone$NumHh)-sum(spatial$NumHh))
    
vmt_azone <- ve %>% left_join(vmt_azone) %>%
  group_by(Azone) %>%
  summarize(NumHh=sum(NumHh, na.rm = T),
            Dvmt_ve=sum(Dvmt_ve, na.rm = T),
            est_vmiles=mean(est_vmiles, na.rm = T)) %>%
  ungroup()
    #### verify DVMT and NumHh - differences are very small
    print(sum(vmt_azone$Dvmt_ve)-sum(spatial$Dvmt_ve))
    print(sum(vmt_azone$NumHh)-sum(spatial$NumHh))

vmt_azone <- vmt_azone %>%
  mutate(Dvmt_per_hh_ve=Dvmt_ve/NumHh,
         pct_diff=(est_vmiles-Dvmt_per_hh_ve)/Dvmt_per_hh_ve)
  
vmt_total <- vmt_tract %>%
  mutate(model='LCOG') %>%
  group_by(model) %>%
  summarize(NumHh=sum(NumHh, na.rm = T),
            Dvmt_ve=sum(Dvmt_ve, na.rm = T),
            Average_latch=round(mean(est_vmiles, na.rm = T), 2)) %>%
  ungroup() %>%
  mutate(Average_ve=Dvmt_ve/NumHh,
         pct_error=(Average_ve-Average_latch)/Average_latch,
         min_error_tract=min(vmt_tract$pct_diff),
         first_quartile_error_tract=quantile(vmt_tract$pct_diff, 0.25),
         median_error_tract=median(vmt_tract$pct_diff),
         thrid_quartile_error_tract=quantile(vmt_tract$pct_diff, 0.75),
         max_error_tract=max(vmt_tract$pct_diff)) %>%
  select(-Dvmt_ve, -NumHh)


####### Income 

## Get ACS vars - using the aggregate household earnings?
#### Using 2020
vars <- data.table(load_variables(2020, 'acs5', cache = T)) %>%
  # filter(name=='B19025_001' | name=='B01001_001' | name=='B19301_001')
  filter(name=='B19301_001')

one <- get_acs(geography = 'block group',
               variables = vars$name,
               state = 'Oregon',
               Year=2020)

income_azone <- one %>% 
  # mutate(variable=ifelse(variable=='B01001_001', 'pop', variable)) %>%
  # mutate(variable=ifelse(variable=='B19025_001', 'agg_inc', variable)) %>%
  mutate(variable=ifelse(variable=='B19301_001', 'perCapIncHh', variable)) %>%
  select(GEOID, variable, estimate) %>%
  pivot_wider(names_from = variable, values_from = estimate) %>%
  # mutate(perCapIncHh=agg_inc/pop) %>%
  select(GEOID, perCapIncHh) %>%
  mutate(GEOID=as.numeric(GEOID)) %>%
  left_join(census_to_azone) %>%
  filter(!is.na(Azone)) %>%
  mutate(Year=2020) %>%
  mutate(perCapIncHh=ifelse(is.nan(perCapIncHh), NA, perCapIncHh)) %>%
  filter(pct_azone > 5) %>%
  group_by(Azone, Year) %>%
  summarize(Income_pc_census=mean(perCapIncHh, na.rm = T)) %>%
  ungroup() %>%
  rename(Geo=Azone) #%>%
# left_join(read.csv('inputs_ref/azone_hh_pop_by_age.csv')) %>%
# mutate(pop=Age0to14+Age15to19+Age20to29+Age30to54+Age55to64+Age65Plus) %>%
# select(-contains('Age')) %>%
# mutate(HhIncomePerCap.2020=(HhIncomePerCap.2020*pop)/(pop)) %>%
# select(-pop, -agg_inc)

income_total <- income_azone %>%
  left_join(read.csv('../inputs/azone_hh_pop_by_age.csv')) %>%
  mutate(pop=Age0to14+Age15to19+Age20to29+Age30to54+Age55to64+Age65Plus) %>%
  select(-contains('Age')) %>%
  group_by(Year) %>%
  summarize(Income_pc_census=sum(Income_pc_census*pop)/sum(pop)) %>%
  ungroup() %>% 
  mutate(Model='LCOG') %>% select(Model, everything()) %>%
  cbind(
    spatial %>% 
      summarize(population_ve=sum(population_ve, na.rm = T),
                Income_ve=sum(Income_ve*1.32, na.rm = T)) %>%
      mutate(Income_pc_ve=Income_ve/population_ve)
  ) %>% mutate(Pct_diff = (Income_pc_ve-Income_pc_census)/Income_pc_census)

income_azone <- 

# two <- one %>% 
#   mutate(GEOID=as.numeric(GEOID)) %>%
#   mutate(variable=ifelse(variable=='B19025_001', 'income_census', variable),
#          variable=ifelse(variable=='B19301_001', 'income_pc_census', variable)) %>%
#   pivot_wider(names_from = variable, values_from = estimate) %>%
#   mutate(income_census=ifelse(is.na(income_census), 0, income_census),
#          income_pc_census=ifelse(is.na(income_pc_census), 0, income_pc_census)) %>%
#   group_by(GEOID) %>%
#   summarize(income_census=sum(income_census, na.rm = T),
#             income_pc_census=mean(income_pc_census, na.rm = T)) %>%
#   ungroup() 
#   
# income_tract <- tracts20 %>%
#   left_join(spatial) %>%
#   mutate(population_ve=pct_bzone*population_ve,
#          Income_ve=pct_bzone*Income_ve) %>%
#   group_by(GEOID) %>%
#   summarize(population_ve=sum(population_ve, na.rm = T),
#          Income_ve=sum(Income_ve, na.rm = T)) %>%
#   ungroup() %>%
#   left_join(two) %>%
#   mutate(income_pc_ve=Income_ve/population_ve,
#          pct_diff=(income_pc_census-income_pc_ve)/income_pc_ve)
# 
# three <- tracts20 %>%
#   left_join(one %>% mutate(GEOID=as.numeric(GEOID))) %>%
#   mutate(variable=ifelse(variable=='B19025_001', 'income_census', variable),
#          variable=ifelse(variable=='B19301_001', 'income_pc_census', variable)) %>%
#   pivot_wider(names_from = variable, values_from = estimate) %>%
#   mutate(income_census=ifelse(is.na(income_census), 0, income_census),
#          income_pc_census=ifelse(is.na(income_pc_census), 0, income_pc_census)) %>%
#   group_by(Bzone, GEOID, pct_bzone) %>%
#   summarize(income_census=sum(income_census, na.rm = T),
#             income_pc_census=mean(income_pc_census, na.rm = T)) %>%
#   ungroup() %>%
#   mutate(income_census=income_census*pct_bzone) %>%
#   group_by(Bzone) %>%
#   summarize(income_pc_census=mean(income_pc_census, na.rm = T),
#             income_census=sum(income_census, na.rm = T)) %>%
#   ungroup()
# 
# income_azone <- ve %>%
#   left_join(two) %>%
#   left_join(spatial) %>%
#   group_by(Azone) %>%
#   summarize(income_pc_census=mean(income_pc_census, na.rm = T),
#             income_census=sum(income_census, na.rm = T),
#             population_ve=sum(population_ve, na.rm = T),
#             income_ve=sum(Income_ve, na.rm = T)) %>%
#   ungroup() %>%
#   mutate(income_pc_ve=income_ve/population_ve,
#          pct_diff=(income_pc_census-income_pc_ve)/income_pc_ve)
# 
# income_total <- income_tract %>%
#   mutate(model='LCOG') %>%
#   group_by(model) %>%
#   summarize(population_ve=sum(population_ve, na.rm = T),
#             Income_ve=sum(Income_ve, na.rm = T),
#             Income_census=sum(income, na.rm = T),
#             population_census=sum(population, na.rm = T)) %>%
#   ungroup() %>%
#   mutate(Income_pc_ve=Income_ve/population_ve,
#          Income_pc_census=Income_census/population_census,
#          pct_diff=(Income_pc_census-Income_pc_ve)/Income_pc_ve,
#          min_tract=min(income_tract$pct_diff),
#          first_quartile_tract=quantile(income_tract$pct_diff, 0.25),
#          median_tract=median(income_tract$pct_diff),
#          third_quartile_tract=quantile(income_tract$pct_diff, 0.75),
#          max_tract=max(income_tract$pct_diff))


###### Vehicles - source = Wiki VE-State validation by MPO (https://orscenplg.github.io/VEWiki/chapter3.html?q=table%209#light-duty-vehicles)

vehicles_total <- spatial %>%
  summarize(Vehicles_ve=sum(Vehicles_ve, na.rm = T)) %>%
  mutate(Vehicles_mpo=203004,
         Vehicles_diff=percent((Vehicles_mpo-Vehicles_ve)/Vehicles_ve, accuracy = 0.1))


###### Drivers
# Apply proportions taken from DMV statistics - will update with actual DMV statistics when available - https://www.oregon.gov/odot/DMV/docs/2019_age_summary.pdf
vars <- data.table(load_variables(2020, 'acs5', cache = T)) %>%
  filter(name=='B01001_001')

one <- get_acs(geography = 'tract',
               variables = vars$name,
               state = 'Oregon',
               Year=2020)

prop <- one %>% filter(grepl('Lane', NAME)) %>%
  mutate(county='Lane') %>%
  mutate(variable=ifelse(variable=='B01001_001', 'population', variable)) %>%
  filter(variable=='population') %>%
  group_by(county) %>%
  summarize(population=sum(estimate, na.rm = T)) %>%
  ungroup() %>%
  mutate(drivers=290310) %>%
  mutate(prop=drivers/population) %>%
  select(county, prop)

two <- one %>%
  mutate(GEOID=as.numeric(GEOID)) %>%
  mutate(variable=ifelse(variable=='B01001_001', 'population', variable)) %>%
  filter(variable=='population') %>%
  pivot_wider(names_from = variable, values_from = estimate) %>%
  mutate(population=ifelse(is.na(population), 0, population),
         county='Lane') %>%
  group_by(GEOID, county) %>%
  summarize(population=sum(population, na.rm = T)) %>%
  ungroup() %>%
  left_join(prop) %>% 
  mutate(drivers_census_est=prop*population) %>%
  select(GEOID, drivers_census_est)

drivers_tract <- tracts20 %>%
  left_join(spatial) %>%
  mutate(Drivers_ve=Drivers_ve*pct_bzone) %>%
  group_by(GEOID) %>%
  summarize(Drivers_ve=sum(Drivers_ve, na.rm = T)) %>%
  ungroup() %>%
  left_join(two) %>%
  mutate(pct_diff=(drivers_census_est-Drivers_ve)/Drivers_ve)
    ### check totals
    print(sum(drivers_tract$Drivers_ve, na.rm = T)-sum(spatial$Drivers_ve, na.rm = T))

drivers_azone <- tracts20 %>%
  left_join(two) %>%
  mutate(drivers_census_est=drivers_census_est*pct_bzone) %>%
  group_by(Bzone) %>%
  summarize(drivers_census_est=sum(drivers_census_est, na.rm = T)) %>%
  ungroup() %>%
  left_join(spatial) %>%
  left_join(ve) %>%
  group_by(Azone) %>%
  summarize(drivers_census_est=sum(drivers_census_est, na.rm = T),
            drivers_ve=sum(Drivers_ve, na.rm = T)) %>%
  ungroup() %>%
  mutate(pct_dif=(drivers_census_est-drivers_ve)/drivers_ve)

drivers_total <- drivers_tract %>%
  mutate(model='SKATS') %>%
  group_by(model) %>%
  summarize(drivers_census_est=sum(drivers_census_est, na.rm = T),
            Drivers_ve=sum(Drivers_ve, na.rm = T)) %>%
  ungroup() %>%
  mutate(pct_diff=(drivers_census_est-Drivers_ve)/Drivers_ve,
         min_tract=min(drivers_tract$pct_diff),
         first_quartile_tract=quantile(drivers_tract$pct_diff, 0.25),
         median_tract=median(drivers_tract$pct_diff),
         third_quartile_tract=quantile(drivers_tract$pct_diff, 0.75),
         max_tract=max(drivers_tract$pct_diff))

#### Activity density
temp <- read.xlsx('../defs/D1D.xlsx', sheet = 'Sheet1') %>%
  rename(D1D_sld=3)

d1d_bg <- temp %>%
  left_join(spatial) %>%
  rename(D1D_ve=D1D,
         GEOID=2) %>%
  mutate(D1D_ve=D1D_ve/608*pct_bzone,
         D1D_sld=D1D_sld*pct_bzone) %>%
  group_by(GEOID) %>%
  summarize(D1D_ve=sum(D1D_ve),
            D1D_sld=sum(D1D_sld)) %>%
  mutate(D1D_diff=(D1D_sld-D1D_ve)/D1D_ve) %>%
  select(GEOID, D1D_ve, D1D_sld, D1D_diff)

#### MPG and MPKWH
mpg <- veh_df %>%
  group_by(Year) %>%
  summarize(MPG=mean(MPG, na.rm = T),
            MPGe=mean(MPGe, na.rm = T),
            MPKWH=mean(MPKWH, na.rm = T))

#### alt modes
alt_modes <-rbind(
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2005),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2010),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2020),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2035),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2045)
) %>%
  left_join(hh_df %>% select(Bzone, Azone, Year, VehicleTrips, WalkTrips, BikeTrips, TransitTrips, HhSize, CommuteDistanceAdj) %>%
              mutate(WalkTrips=ifelse(is.infinite(WalkTrips), 0, WalkTrips),
                     BikeTrips=ifelse(is.infinite(BikeTrips), 0, BikeTrips)), by=c('Bzone', 'Year')) %>%
  group_by(Azone, Year) %>%
  summarize(Population=round(sum(HhSize, na.rm = T)),
            VehicleTrips=round(sum(VehicleTrips, na.rm = T)),
            WalkTrips=round(sum(WalkTrips, na.rm = T)),
            BikeTrips=round(sum(BikeTrips, na.rm = T)),
            TransitTrips=round(sum(TransitTrips, na.rm = T)),
            CommuteDistanceAdj=round(sum(CommuteDistanceAdj, na.rm = T))) %>%
  ungroup() %>%
  mutate(VehicleTrips_pc=round(VehicleTrips/Population, 1),
         WalkTrips_pc=round(WalkTrips/Population, 1),
         BikeTrips_pc=round(BikeTrips/Population, 2),
         TransitTrips_pc=round(TransitTrips/Population, 1),
         CommuteDist_pc=round(CommuteDistanceAdj/Population, 1),
         CommuteDist_per_vehicle_trip=round(CommuteDistanceAdj/VehicleTrips, 1)) %>%
  filter(!is.na(Azone))

#### CO2e
co2e_bzone <- rbind(
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2005),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2010),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2020),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2035),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2045)
) %>%
  left_join(hh_df %>% select(Bzone, Year, DailyCO2e, Dvmt, HhSize), by=c('Bzone', 'Year')) %>%
  mutate(co2e_pc=DailyCO2e/HhSize,
         co2e_per_dvmt=DailyCO2e/Dvmt) %>%
  rename(Population=HhSize)

co2e_azone <- rbind(
  data.frame(Azone=unique(bzone_df$Azone), Year=2005),
  data.frame(Azone=unique(bzone_df$Azone), Year=2010),
  data.frame(Azone=unique(bzone_df$Azone), Year=2020),
  data.frame(Azone=unique(bzone_df$Azone), Year=2035),
  data.frame(Azone=unique(bzone_df$Azone), Year=2045)
) %>%
  left_join(hh_df %>% select(Azone, Year, DailyCO2e, Dvmt, HhSize), by=c('Azone', 'Year')) %>%
  group_by(Azone, Year) %>%
  summarize(DailyCO2e=sum(DailyCO2e, na.rm = T),
            Dvmt=sum(Dvmt, na.rm = T),
            HhSize=sum(HhSize, na.rm = T)) %>%
  ungroup() %>%
  mutate(co2e_pc=DailyCO2e/HhSize,
         co2e_per_dvmt=DailyCO2e/Dvmt) %>%
  rename(Population=HhSize)

co2e_total <- co2e_bzone %>%
  group_by(Year) %>%
  summarize(Population=round(sum(Population, na.rm = T)),
            DailyCO2e=sum(DailyCO2e, na.rm = T),
            Dvmt=sum(Dvmt, na.rm = T)) %>%
  ungroup() %>%
  mutate(co2e_pc=DailyCO2e/Population,
         co2e_per_dvmt=DailyCO2e/Dvmt)

#### Compile results
list <- list('VMT Tract'=vmt_tract, 'VMT Azone'=vmt_azone, 'VMT total'=vmt_total,
             'Income Tract'=income_tract, 'Income Azone'=income_azone, 'Income total'=income_total,
             'Drivers Tract'=drivers_tract, 'Drivers Azone'=drivers_azone, 'Drivers total'=drivers_total,
             'CO2e Bzone'=co2e_bzone, 'CO2e Azone'=co2e_azone, 'CO2e total'=co2e_total,
             'D1D Block Group'=d1d_bg, 'Vehicles total'=vehicles_total, 'MPG'=mpg,
             'Transit modes&dist'=alt_modes
             )
write.xlsx(list, file='../results/output/validation results.xlsx')
