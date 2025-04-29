#### Use this script to compile VisionEval export() results into one spreadsheet ####
#---------------------------------------------------------------------------------#
library(tidyverse)
library(rstudioapi)
library(openxlsx)

setwd(dirname(getActiveDocumentContext()$path))

# Household

## Get file names - remove ithim from this list
file <- list.files('../results/output')
list <- list.files(paste0('../results/output/', file), pattern = 'Household', full.names = T)
list <- list[!grepl('ithim', list)]
# bzones <- read.csv('../defs/bzone_summary_Portland.csv') %>%
#   filter(MetroB==1)

hh_df <- data.frame()

## Load CSVs, optionally filter bzones to what are in Target Rule area by uncommenting line 23
for (i in list){
  data <- read.csv(i)
  data <- data %>% 
    mutate(HH=1)%>%
    # filter(Bzone %in% bzones$Bzone) %>%
    select(Year, Marea, Azone, Bzone, where(is.numeric))
  exclude <- c('Year', 'Marea', 'Azone', 'Bzone')
  cols <- names(data)
  cols <- setdiff(cols, exclude)
  mean_vars <- cols[grepl('Ave|Avg', cols)]
  sum_vars <- setdiff(cols, mean_vars)
  data <- data %>% 
    group_by(Year, Marea, Azone, Bzone) %>%
    summarize(across(all_of(sum_vars), ~sum(., na.rm = T)),
              across(all_of(mean_vars), ~mean(., na.rm = T)))
  
  hh_df <- rbind(hh_df, data)
}

hh_df <- hh_df %>%
  mutate(dvmt_pc=round(Dvmt/HhSize, 1),
         trips_per_cap=round(VehicleTrips/HhSize, 1),
         income_pc=Income/HhSize,
         transit_trips_pc=round(TransitTrips/HhSize, 1)) %>%
  group_by(Year) %>%
  mutate(income_bin=4,
         income_bin=ifelse(income_pc <= quantile(income_pc, 0.75), 3, income_bin),
         income_bin=ifelse(income_pc <= quantile(income_pc, 0.5), 2, income_bin),
         income_bin=ifelse(income_pc <= quantile(income_pc, 0.25), 1, income_bin),
         income_quartile=ifelse(income_bin==1, quantile(income_pc, 0.25), NA),
         income_quartile=ifelse(income_bin==2, quantile(income_pc, 0.5), income_quartile),
         income_quartile=ifelse(income_bin==3, quantile(income_pc, 0.75), income_quartile),
         income_quartile=ifelse(income_bin==4, quantile(income_pc, 1), income_quartile),
         transit_trips_pc=TransitTrips/HhSize,
         vehicles_per_hh=Vehicles/HH) %>%
  ungroup() 

temp <- hh_df %>%
  group_by(Year, income_bin) %>%
  summarize(dvmt_pc=mean(dvmt_pc, na.rm = T),
            transit_trips_pc=mean(transit_trips_pc, na.rm = T),
            vehicles_per_hh=mean(vehicles_per_hh, na.rm = T)) %>%
  ungroup() %>%
  mutate(income_bin=as.character(income_bin),
         Year=as.character(Year))

# Bzone - using same function but loading global csv files

## Get file names - remove ithim files
list <- list.files(paste0('../results/output/', file), pattern = 'Bzone', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)
list <- list[!grepl('ithim', list)]

bzone_df <- data.frame()

## Load CSVs, optionally filter bzones to what is in Target Rule area by uncommenting line ###
for (i in list){
  data <- read.csv(i) %>%
    mutate(Azone=ifelse(Bzone==56 & Year==2050, 'Salem_1', Azone),
           Azone=ifelse(Bzone==450 & Year==2050, 'Salem_5', Azone),
           Azone=ifelse(Azone=='Marion_Inside_UGB_3' & Year==2050, 'Salem_5', Azone),
           azone_secondary=ifelse(grepl('Salem', Azone), 'Salem UGB', 'Other'),
           azone_secondary=ifelse(grepl('Keizer', Azone), 'Keizer UGB', azone_secondary),
           azone_secondary=ifelse(grepl('Marion_Inside', Azone), 'Marion UGB', azone_secondary))
  # data <- data %>% filter(Bzone %in% bzones$Bzone)
  bzone_df <- rbind(bzone_df, data)
}

# Azone - using same function but loading global csv files
list <- list.files(paste0('../results/output/', file), pattern = 'Azone', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

azone_df <- data.frame()

## Load CSVs
for (i in list){
  data <- read.csv(i) %>%
    mutate(azone_secondary=ifelse(grepl('Salem', Azone), 'Salem UGB', 'Other'),
           azone_secondary=ifelse(grepl('Keizer', Azone), 'Keizer UGB', azone_secondary),
           azone_secondary=ifelse(grepl('Marion_Inside', Azone), 'Marion UGB', azone_secondary))
  azone_df <- rbind(azone_df, data) 
}

# Marea - using same function but loading global csv files (only accounts for numeric outputs, not characters)
list <- list.files(paste0('../results/output/', file), pattern = 'Marea', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

marea_df <- data.frame()

## Load CSVs
for (i in list){
  data <- read.csv(i)
  if(!exists('Marea', data)) {
    data <- mutate(data, Marea = 'NA')
  }
  data <- data %>%
    select(Scenario, Global, Marea, Year, where(is.numeric))
  exclude <- c('Scenario', 'Global', 'Marea', 'Year')
  cols <- setdiff(names(data), exclude)
  data <- data %>%
    pivot_longer(cols = cols, names_to = 'Output', values_to = 'Value') %>%
    select(Scenario, Global, Marea, Year, Output, Value) %>%
    distinct(Year, Output, .keep_all = T)
  marea_df <- rbind(marea_df, data)
}

# Region - using same function but loading global csv files
list <- list.fileslist <- list.files(paste0('../results/output/', file), pattern = 'Region', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

region_df <- data.frame()

## Load CSVs
for (i in list){
  data <- read.csv(i)
  region_df <- rbind(region_df, data)
}

# Vehicles
list <- list.files
list <- list.files(paste0('../results/output/', file), pattern = 'Vehicle', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

vehicle_df <- data.frame()

## Load CSVs, optionally filter bzones to what is in Target Rule area by uncommenting line ###
for (i in list){
  data <- read.csv(i)
  data <- data %>%
    # filter(!grepl('CarSvc', VehicleAccess)) %>%
    mutate(ICEV=ifelse(Powertrain=='ICEV',1,0),
           PHEV=ifelse(Powertrain=='PHEV',1,0),
           BEV=ifelse(Powertrain=='BEV',1,0),
           HEV=ifelse(Powertrain=='HEV',1,0),
           NA_powertrain=ifelse(is.na(Powertrain),1,0),
           Auto=ifelse(Type=='Auto',1,0),
           LtTrk=ifelse(Type=='LtTrk',1,0),
           Auto_HH=ifelse(Type=='Auto' & !grepl('CarSvc', VehicleAccess), 1, 0),
           LtTrk_HH=ifelse(Type=='LtTrk' & !grepl('CarSvc', VehicleAccess), 1, 0),
           HH_ICEV=ifelse(Powertrain=='ICEV' & !grepl('CarSvc', VehicleAccess), 1, 0),
           HH_PHEV=ifelse(Powertrain=='PHEV' & !grepl('CarSvc', VehicleAccess), 1, 0),
           HH_BEV=ifelse(Powertrain=='BEV' & !grepl('CarSvc', VehicleAccess), 1, 0),
           HH_HEV=ifelse(Powertrain=='HEV' & !grepl('CarSvc', VehicleAccess), 1, 0),
           access_LowCarSvc=ifelse(VehicleAccess=='LowCarSvc',1,0),
           access_HighCarSvc=ifelse(VehicleAccess=='HighCarSvc',1,0),
           access_Own=ifelse(VehicleAccess=='Own',1,0)) %>%
    select(Marea, Azone, Bzone, Year, where(is.numeric))
  cols <- names(data)
  exclude <- c('Year', 'Marea', 'Azone', 'Bzone', 'VehId', 'Global', 'HhId', 'Type', 'Powertrain', 'VehicleAccess')
  cols <- setdiff(cols, exclude)
  sum_vars <- cols[grepl('ICEV|PHEV|BEV|HEV|NA_powertrain|Auto|LtTrk|access', cols)]
  mean_vars <- setdiff(cols, sum_vars)
  data <- data %>% group_by(Marea, Azone, Bzone, Year) %>%
    summarize(across(all_of(sum_vars), ~sum(., na.rm = T)),
              across(all_of(mean_vars), ~mean(., na.rm = T))) %>%
    ungroup() %>%
    mutate(Azone=ifelse(Bzone==56 & Year==2050, 'Salem_1', Azone),
           Azone=ifelse(Bzone==450 & Year==2050, 'Salem_5', Azone),
           Azone=ifelse(Azone=='Marion_Inside_UGB_3' & Year==2050, 'Salem_5', Azone),
           azone_secondary=ifelse(grepl('Salem', Azone), 'Salem UGB', 'Other'),
           azone_secondary=ifelse(grepl('Keizer', Azone), 'Keizer UGB', azone_secondary),
           azone_secondary=ifelse(grepl('Marion_Inside', Azone), 'Marion UGB', azone_secondary))
  vehicle_df <- rbind(vehicle_df, data)
}


### Worker results
list <- list.files
list <- list.files(paste0('../results/output/', file), pattern = 'Worker', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

wrk_df <- data.frame()

for(i in list) {
  data <- read.csv(i)
  data <- data %>%
    mutate(WorkFromHome=ifelse(WorkFromHome=='Yes', 1, 0),
           TeleWork=ifelse(TeleWork!='Yes', 1, 0),
           TeleWorkDays=ifelse(is.na(TeleWorkDays), 0, TeleWorkDays),
           TeleworkDays_0=ifelse(TeleWorkDays==0, 1, 0),
           TeleworkDays_1=ifelse(TeleWorkDays==1, 1, 0),
           TeleworkDays_2=ifelse(TeleWorkDays==2, 1, 0),
           TeleworkDays_3=ifelse(TeleWorkDays==3, 1, 0),
           TeleworkDays_4=ifelse(TeleWorkDays==4, 1, 0),
           TeleworkDays_5=ifelse(TeleWorkDays==5, 1, 0),
           PartTimeTelework=ifelse(TeleworkDays_1==1 | TeleworkDays_2==1 | TeleworkDays_3==1 | TeleworkDays_4==1, 1, 0),
           FullTimeTelework=ifelse(TeleWorkDays==5, 1, 0),
           NoTelework=ifelse(TeleWorkDays==0, 1, 0),
           Occupation_1=ifelse(Occupation==1, 1, 0),
           Occupation_2=ifelse(Occupation==1, 1, 0),
           Occupation_3=ifelse(Occupation==1, 1, 0))
  cols <- names(data)
  exclude <- c('Year', 'Bzone', 'Azone', 'Marea', 'HhId', 'WkrId', 'Scenario', 'Global', 'Occupation', 'TeleWorkDays', 'WorkFromHome')
  cols <- setdiff(cols, exclude)
  sum_vars <- cols[grepl('PaysForParking|IsCashOut|IsECO|TeleWork|TeleworkDays_0|TeleworkDays_1|TeleworkDays_2|TeleworkDays_3|TeleworkDays_4|TeleworkDays_5|PartTimeTelework|FullTimeTelework|NoTelework|Occupation_1|Occupation_2|Occupation_3', cols)]
  mean_vars <- setdiff(cols, sum_vars)
  data <- data %>% group_by(Bzone, Azone, Marea, Year) %>%
    summarize(across(all_of(sum_vars), ~sum(., na.rm = T)),
              across(all_of(mean_vars), ~mean(., na.rm = T))) %>%
    ungroup() %>%
    mutate(Azone=ifelse(Bzone==56 & Year==2050, 'Salem_1', Azone),
           Azone=ifelse(Bzone==450 & Year==2050, 'Salem_5', Azone),
           Azone=ifelse(Azone=='Marion_Inside_UGB_3' & Year==2050, 'Salem_5', Azone),
           azone_secondary=ifelse(grepl('Salem', Azone), 'Salem UGB', 'Other'),
           azone_secondary=ifelse(grepl('Keizer', Azone), 'Keizer UGB', azone_secondary),
           azone_secondary=ifelse(grepl('Marion_Inside', Azone), 'Marion UGB', azone_secondary))
  wrk_df <- rbind(wrk_df, data)
}

temp2 <- marea_df %>%
  filter(Output=='VanDvmt' | Output=='VanCO2e' | Output=='ComSvcNonUrbanCO2e' |
           Output=='ComSvcUrbanCO2e' | Output=='ComSvcRuralDvmt' | Output=='ComSvcTownDvmt' |
           Output=='ComSvcUrbanDvmt') %>%
  select(Year, Output, Value) %>%
  pivot_wider(names_from = Output, values_from = Value)

temp <- hh_df %>%
  group_by(Year) %>%
  summarize(DailyCO2e=sum(DailyCO2e, na.rm = T),
            Dvmt=sum(Dvmt, na.rm = T),
            HhSize=sum(HhSize, na.rm = T),
            VehicleTrips=sum(VehicleTrips, na.rm = T),
            Vehicles=sum(Vehicles, na.rm = T),
            trips_per_cap=mean(trips_per_cap, na.rm = T),
            Population=sum(HhSize, na.rm = T),
            HH=sum(HH, na.rm = T),
            IsUrbanMixNbrhd=sum(IsUrbanMixNbrhd, na.rm = T)) %>%
  ungroup() %>%
  left_join(temp2) %>%
  mutate(Dvmt=Dvmt+VanDvmt+ComSvcRuralDvmt+ComSvcTownDvmt+ComSvcUrbanDvmt,
         DailyCO2e=DailyCO2e+VanCO2e+ComSvcNonUrbanCO2e+ComSvcUrbanCO2e,
         Dvmt_pc=round(Dvmt/HhSize, 1)) %>%
  mutate(co2_per_dvmt=round((DailyCO2e)/Dvmt, 2),
         co2_pc=round(DailyCO2e/HhSize, 2),
         mixed_use_pct=IsUrbanMixNbrhd/HH) %>%
  select(Year, DailyCO2e, co2_pc, co2_per_dvmt, Dvmt, Dvmt_pc, VehicleTrips, Vehicles, trips_per_cap, Population, mixed_use_pct)

temp2 <- hh_df %>%
  mutate(azone_secondary=ifelse(grepl('Salem', Azone), 'Salem UGB', 'Other'),
         azone_secondary=ifelse(grepl('Keizer', Azone), 'Keizer UGB', azone_secondary),
         azone_secondary=ifelse(grepl('Marion_Inside', Azone), 'Marion UGB', azone_secondary)) %>%
  group_by(azone_secondary, Year) %>%
  summarize(HH=sum(HH, na.rm = T),
            IsUrbanMixNbrhd=sum(IsUrbanMixNbrhd, na.rm = T)) %>%
  ungroup() %>%
  mutate(mixed_use_pct=IsUrbanMixNbrhd/HH) %>%
  arrange(azone_secondary, Year)

#ITHIM if applicable

## Get ithim files - ithim produces files at household and Bzone levels if ithim output files exist
list <- list.files(paste0('../results/output/', file), pattern = 'Bzone', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

if(any(grepl('ithim', list))) {
  
  list <- list[grep('ithim', list)]
  
  ithim_df <- data.frame()
  
  for(i in list) {
    
    data <- read.csv(i) %>% select(-1) %>%
      mutate(Year=max(hh_df$Year)) %>%
      select(Bzone, Year, everything())
    
    if(dim(ithim_df)[1]==0) {
      ithim_df <- data
    } else {
      ithim_df <- left_join(ithim_df, data)
    }
    
  }
  
  ## Summarize ithim outputs for the scenario
  ithim_sum <- ithim_df %>% select(-Bzone, -Year) %>%
    summarize_all(sum)
  
  write.csv(ithim_df, '../results/output/ithim_Bzone_results.csv', row.names = F)
  write.csv(ithim_sum, '../results/output/ithim_summary.csv', row.names = F)
  
}


# Write all results to CSV files
write.csv(hh_df, '../results/output/Household_outputs.csv', row.names = F)
write.csv(bzone_df, '../results/output/Bzone_outputs.csv', row.names = F)
write.csv(azone_df, '../results/output/Azone_outputs.csv', row.names = F)
write.csv(marea_df, '../results/output/Marea_outputs.csv', row.names = F)
write.csv(region_df, '../results/output/region_outputs.csv', row.names = F)
write.csv(vehicle_df, '../results/output/vehicle_outputs.csv', row.names = F)
write.csv(wrk_df, '../results/output/worker_outputs.csv', row.names = F)
write.csv(temp, '../results/output/target rule.csv', row.names = F)
write.csv(temp2, '../results/output/mixed use Azone.csv', row.names = F)

#----------------------------------------------------------------------------#
### Export key metrics for comparison with TAZ data
bzone_vars <- bzone_df %>% select(Year, Bzone, Pop, GQ, SFDU, MFDU, GQDU, TotEmp, RetEmp, SvcEmp)
write.csv(bzone_vars, '../results/output/for_taz_comparison.csv', row.names = F)

#-----------------------------------------------------------------------------#
# Develop the summary table metrics - this process was a one-off customized for SKATS

# 1) Read in the VE sheet from the crosswalk table
ve <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'VE')

# 2) Compile the results at each level
results <- hh_df %>%
  group_by(Year, Azone) %>%
  summarize(AveVehCostPM=mean(AveVehCostPM, na.rm = T),
            HH=sum(HH, na.rm = T),
            NumHighCarSvc=sum(NumHighCarSvc, na.rm = T),
            IsUrbanMixNbrhd=sum(IsUrbanMixNbrhd, na.rm = T),
            IsIMP=sum(IsIMP, na.rm = T),
            HhSize=sum(HhSize, na.rm = T),
            Dvmt=sum(Dvmt, na.rm = T)) %>% ungroup() %>%
  mutate(PctHighCarSvc=NumHighCarSvc/HH,
         PctMixedUse=IsUrbanMixNbrhd/HH,
         ImpProp=IsIMP/HH,
         DvmtPc=Dvmt/HhSize) %>%
  select(Year, Azone, AveVehCostPM, PctHighCarSvc, PctMixedUse, ImpProp, DvmtPc) %>%
  left_join(
    wrk_df %>% group_by(Year, Azone) %>%
      summarize(NoTelework=sum(NoTelework, na.rm = T),
                PartTimeTelework=sum(PartTimeTelework, na.rm = T),
                FullTimeTelework=sum(FullTimeTelework, na.rm = T),
                IsECO=sum(IsECO, na.rm = T)) %>%
      ungroup() %>%
      mutate(PctNoTelework=NoTelework/(NoTelework+PartTimeTelework+FullTimeTelework),
             PctPartTimeTelework=PartTimeTelework/(NoTelework+PartTimeTelework+FullTimeTelework),
             PctFullTimeTelework=FullTimeTelework/(NoTelework+PartTimeTelework+FullTimeTelework),
             WfhPct=(PartTimeTelework+FullTimeTelework)/(NoTelework+PartTimeTelework+FullTimeTelework),
             EcoProp=IsECO/(NoTelework+PartTimeTelework+FullTimeTelework)) %>%
      select(Year, Azone, contains('Pct'), contains('Prop'))
  ) %>% left_join(
    vehicle_df %>% group_by(Year, Azone) %>%
      summarize(HH_ICEV=sum(HH_ICEV, na.rm = T),
                HH_PHEV=sum(HH_PHEV, na.rm = T),
                HH_BEV=sum(HH_BEV, na.rm = T),
                HH_HEV=sum(HH_HEV, na.rm = T),
                MPG=mean(MPG, na.rm = T),
                MPGe=mean(MPGe, na.rm = T)) %>%
      ungroup() %>%
      mutate(MPG=(MPG+MPGe)/2,
             PctNonIce=(HH_PHEV+HH_HEV+HH_BEV)/(HH_PHEV+HH_HEV+HH_BEV+HH_ICEV)) %>%
      select(Year, Azone, MPG, PctNonIce)
  ) %>% mutate(Marea='LCOG') %>%
  left_join(marea_df %>% 
              select(Marea, Year, Output, Value) %>%
              filter(Output=='BusGGE') %>%
              pivot_wider(names_from = Output, values_from = Value)
            )

# 3) Compile the Azone inputs
azone_inputs <- read.csv('../inputs/azone_hh_pop_by_age.csv') %>%
  mutate(Population=Age0to14+Age15to19+Age20to29+Age30to54+Age55to64+Age65Plus) %>%
  select(Geo, Year, Population) %>%
  left_join(
    read.csv('../inputs/azone_hhsize_targets.csv')
  ) %>%
  left_join(
    read.csv('../inputs/azone_per_cap_inc.csv') %>%
      select(-contains('GQ'))
  ) %>%
  left_join(
    read.csv('../inputs/azone_fuel_power_cost.csv') %>%
      mutate(PowerCost.2020=PowerCost.2005*1.37,
             FuelCost.2020=FuelCost.2005*1.37) %>%
      select(Geo, Year, contains('2020'))
  ) %>% left_join(
    read.csv('../inputs/azone_hh_veh_own_taxes.csv') %>%
      mutate(VehOwnFlatRateFee.2020=VehOwnFlatRateFee.2005*1.37) %>%
      select(Geo, Year, contains('2020'))
  ) %>% left_join(
    read.csv('../inputs/azone_veh_use_taxes.csv') %>%
      mutate(FuelTax.2020=FuelTax.2005*1.37) %>%
      select(Geo, Year, contains('2020'))
  ) %>% left_join(
    read.csv('../inputs/azone_payd_insurance_prop.csv')
  ) %>% left_join(
    read.csv('../inputs/azone_prop_sov_dvmt_diverted.csv')
  ) %>% left_join(
    read.csv('../inputs/azone_charging_availability.csv') %>%
      select(-contains('GQ'))
  ) %>% left_join(
    read.csv('../inputs/bzone_dwelling_units.csv') %>%
      mutate(hhs=SFDU+MFDU) %>%
      left_join(ve %>% select(Bzone, Azone), by=c('Geo'='Bzone')) %>%
                  group_by(Azone, Year) %>%
                  summarize(hhs=sum(hhs, na.rm = T)) %>%
                  ungroup() %>%
      rename(Geo=Azone)
  ) %>%
  group_by(Geo, Year) %>%
  mutate(hh_weight=hhs/sum(hhs, na.rm = T)) %>%
  ungroup() %>%
  mutate(PropSovDvmtDiverted=PropSovDvmtDiverted*hh_weight) %>%
  group_by(Geo, Year) %>%
  summarize(
    Population=sum(Population, na.rm = T),
    AveHhSize=mean(AveHhSize, na.rm = T),
    Prop1PerHh=mean(Prop1PerHh, na.rm = T),
    HHIncomePC.2020=mean(HHIncomePC.2020, na.rm = T),
    PowerCost.2020=mean(PowerCost.2020, na.rm = T),
    FuelCost.2020=mean(FuelCost.2020, na.rm = T),
    VehOwnFlatRateFee.2020=mean(VehOwnFlatRateFee.2020, na.rm = T),
    FuelTax.2020=mean(FuelTax.2020, na.rm = T),
    PaydHhProp=mean(PaydHhProp, na.rm = T),
    PropSovDvmtDiverted=sum(PropSovDvmtDiverted, na.rm = T),
    PropSFChargingAvail=mean(PropSFChargingAvail, na.rm = T),
    PropMFChargingAvail=mean(PropMFChargingAvail, na.rm = T)
  ) %>% ungroup() %>%
  mutate(IncGR=0)

# 4) Compile the Bzone inputs
bzone_inputs <- read.csv('../inputs/bzone_employment.csv') %>%
  left_join(
    read.csv('../inputs/bzone_dwelling_units.csv')
  ) %>% left_join(
    read.csv('../inputs/bzone_parking.csv')
  ) %>% left_join(
    ve, by=c('Geo'='Bzone')
  ) %>% mutate(
    EmpPaysForParking=PropWkrPay*TotEmp,
    PkgCost.2020=1.37*PkgCost.2010
  )

#### Do one of the parking cost metrics here
temp <- bzone_inputs %>% 
  filter(PkgCost.2020 > 0) %>%
  group_by(Azone, Year) %>%
  mutate(weight=TotEmp/sum(TotEmp)) %>%
  ungroup() %>%
  mutate(PkgCost.2020=PkgCost.2020*weight) %>%
  group_by(Azone, Year) %>%
  summarize(PkgCost.2020_Charged=sum(PkgCost.2020, na.rm = T)) %>%
  ungroup()

bzone_inputs <- bzone_inputs %>%
  group_by(Azone, Year) %>%
  mutate(weight=TotEmp/sum(TotEmp)) %>%
  ungroup() %>%
  mutate(PkgCost.2020=PkgCost.2020*weight) %>%
  group_by(Azone, Year) %>%
  summarize(
    TotEmp=sum(TotEmp, na.rm = T),
    RetEmp=sum(RetEmp, na.rm = T),
    SvcEmp=sum(SvcEmp, na.rm = T),
    SFDU=sum(SFDU, na.rm = T),
    MFDU=sum(MFDU, na.rm = T),
    PropNonWrkTripPay=mean(PropNonWrkTripPay, na.rm = T),
    EmpPaysForParking=sum(EmpPaysForParking, na.rm = T),
    PkgCost.2020_All=mean(PkgCost.2020, na.rm = T),
  ) %>% ungroup() %>%
  left_join(temp) %>% 
  replace(is.na(.), 0) 

# 5) Get the Marea inputs
marea_inputs <- ve %>%
  distinct(Marea, Azone) %>%
  mutate(Year=2005) %>%
  rbind(
    ve %>%
      distinct(Marea, Azone) %>%
      mutate(Year=2010),
    ve %>%
      distinct(Marea, Azone) %>%
      mutate(Year=2020),
    ve %>%
      distinct(Marea, Azone) %>%
      mutate(Year=2035),
    ve %>%
      distinct(Marea, Azone) %>%
      mutate(Year=2045)
  ) %>% left_join(
    read.csv('../inputs/marea_transit_service.csv')
  ) %>% left_join(
    read.csv('../inputs/marea_lane_miles.csv')
  ) %>% left_join(
   read.csv('../inputs/marea_operations_deployment.csv') %>%
     select(-contains('Other'))
  ) %>% left_join(
    read.csv('../inputs/marea_transit_fuel.csv') %>%
      select(-contains('Gasoline'))
  ) %>% left_join(
    read.csv('../inputs/marea_transit_biofuel_mix.csv')
  ) %>% left_join(
    read.csv('../inputs/marea_transit_powertrain_prop.csv') %>%
      select(-contains('Hev'))
  ) %>% mutate(
    TransitServiceMilesBus=MBRevMi+RBRevMi,
    BusEquivMiles=(DRRevMi*0.18)+(VPRevMi*0.88)+MBRevMi+(RBRevMi*1.91)+(MGRevMi*1.09)+(SRRevMi*1.92)+(HRRevMi*3.43)+(CRRevMi*2.5),
    BusPropCng=ifelse(Year==2050, 0, BusPropCng), ## zero, all EV
    BusPropDiesel=ifelse(Year==2050, 0, BusPropDiesel), ## zero, all EV
    TransitEthanolPropGasoline=ifelse(Year==2050, 0, TransitEthanolPropGasoline), ## zero, all EV
    TransitBiodieselPropDiesel=ifelse(Year==2050, 0, TransitBiodieselPropDiesel), ## zero, all EV
    TransitRngPropCng=ifelse(Year==2050, 0, TransitRngPropCng) ## zero, all EV
    ) %>% select(
      Azone, Year, TransitServiceMilesBus, BusEquivMiles, FwyLaneMi, ArtLaneMi, contains('DeployProp'), contains('BusProp'),
      TransitEthanolPropGasoline, TransitBiodieselPropDiesel, TransitRngPropCng
    )

# 6) Get the regional values for certain values
temp <- read.csv('../inputs/bzone_parking.csv') %>%
  left_join(read.csv('../inputs/bzone_dwelling_units.csv') %>%
              mutate(hhs=SFDU+MFDU) %>%
              select(Geo, Year, hhs)) %>%
  group_by(Year) %>%
  mutate(hhs2=sum(hhs, na.rm = T)) %>%
  ungroup() %>%
  mutate(weight=hhs/hhs2,
         PkgCost.2020=1.37*PkgCost.2010,
         PkgCost.2020=PkgCost.2020*weight) %>%
  group_by(Year) %>%
  summarize(PropNonWrkTripPay=mean(PropNonWrkTripPay, na.rm = T),
            PkgCost.2020_All=sum(PkgCost.2020, na.rm = T)) %>%
  ungroup() %>%
  left_join(read.csv('../inputs/bzone_parking.csv') %>%
              left_join(read.csv('../inputs/bzone_dwelling_units.csv') %>%
                          mutate(hhs=SFDU+MFDU) %>%
                          select(Geo, Year, hhs)) %>%
              filter(PkgCost.2010 > 0) %>%
              group_by(Year) %>%
              mutate(hhs2=sum(hhs, na.rm = T)) %>%
              ungroup() %>%
              mutate(weight=hhs/hhs2,
                     PkgCost.2020=1.37*PkgCost.2010,
                     PkgCost.2020=PkgCost.2020*weight) %>%
              group_by(Year) %>%
              summarize(PkgCost.2020_Charged=sum(PkgCost.2020, na.rm = T)) %>%
              ungroup())

regional <- read.csv('../inputs/bzone_employment.csv') %>%
  left_join(read.csv('../inputs/bzone_parking.csv') %>%
              select(Geo, Year,PropWkrPay)) %>%
  left_join(read.csv('../inputs/bzone_dwelling_units.csv')) %>%
  mutate(EmpPaysForParking=PropWkrPay*TotEmp) %>%
  rename(Bzone=Geo) %>%
  left_join(hh_df %>% select(Bzone, Year, HH, IsUrbanMixNbrhd, AveVehCostPM, Dvmt, HhSize, NumHighCarSvc, IsIMP)) %>%
  left_join(wrk_df %>% select(Bzone, Year, NoTelework, PartTimeTelework, FullTimeTelework, IsECO)) %>%
  group_by(Year) %>%
  summarize(Dvmt=sum(Dvmt, na.rm = T),
            HhSize=sum(HhSize, na.rm = T),
            EmpPaysForParking=sum(EmpPaysForParking, na.rm = T),
            IsECO=sum(IsECO, na.rm = T),
            IsIMP=sum(IsIMP, na.rm = T),
            TotEmp=sum(TotEmp, na.rm = T),
            RetEmp=sum(RetEmp, na.rm = T),
            SvcEmp=sum(SvcEmp, na.rm = T),
            SFDU=sum(SFDU, na.rm = T),
            MFDU=sum(MFDU, na.rm = T),
            HH=sum(HH, na.rm = T),
            NumHighCarSvc=sum(NumHighCarSvc, na.rm = T),
            IsUrbanMixNbrhd=sum(IsUrbanMixNbrhd, na.rm = T),
            AveVehCostPM=mean(AveVehCostPM, na.rm = T),
            NoTelework=sum(NoTelework, na.rm = T),
            PartTimeTelework=sum(PartTimeTelework, na.rm = T),
            FullTimeTelework=sum(FullTimeTelework, na.rm = T)) %>%
  ungroup() %>%
  mutate(IsECO=IsECO/(NoTelework+PartTimeTelework+FullTimeTelework),
         IsIMP=IsIMP/HH) %>%
  rename(EcoProp=IsECO,
         ImpProp=IsIMP) %>%
  left_join(read.csv('../inputs/azone_prop_sov_dvmt_diverted.csv') %>%
              left_join(read.csv('../inputs/azone_hh_pop_by_age.csv')) %>%
              left_join(read.csv('../inputs/azone_hhsize_targets.csv')) %>%
              left_join(read.csv('../inputs/azone_per_cap_inc.csv')) %>%
              left_join(read.csv('../inputs/azone_fuel_power_cost.csv')) %>%
              left_join(read.csv('../inputs/azone_veh_use_taxes.csv')) %>%
              left_join(read.csv('../inputs/azone_hh_veh_own_taxes.csv')) %>%
              left_join(read.csv('../inputs/azone_payd_insurance_prop.csv')) %>%
              left_join(read.csv('../inputs/azone_charging_availability.csv')) %>%
              left_join(read.csv('../inputs/bzone_dwelling_units.csv') %>% 
                          mutate(hhs=SFDU+MFDU) %>%
                          left_join(ve %>% select(Bzone, Azone), by=c('Geo'='Bzone')) %>%
                          group_by(Azone, Year) %>%
                          summarize(hhs=sum(hhs, na.rm = T)) %>%
                          ungroup() %>%
                          rename(Geo=Azone)) %>%
              mutate(Population=Age0to14+Age15to19+Age20to29+Age30to54+Age55to64+Age65Plus) %>%
              group_by(Year) %>%
              mutate(hh_weight=hhs/sum(hhs, na.rm = T)) %>%
              ungroup() %>%
              mutate(PropSovDvmtDiverted=PropSovDvmtDiverted*hh_weight) %>%
              group_by(Year) %>%
              summarize(Population=sum(Population, na.rm = T),
                        AveHhSize=mean(AveHhSize, na.rm = T),
                        Prop1PerHh=mean(Prop1PerHh, na.rm = T),
                        HHIncomePC.2020=mean(HHIncomePC.2020, na.rm = T),
                        PowerCost.2020=1.37*mean(PowerCost.2005, na.rm = T),
                        FuelCost.2020=1.37*mean(FuelCost.2005, na.rm = T),
                        FuelTax.2020=1.37*mean(FuelTax.2005, na.rm = T),
                        PaydHhProp=mean(PaydHhProp, na.rm = T),
                        VehOwnFlatRateFee.2020=1.37*mean(VehOwnFlatRateFee.2005, na.rm = T),
                        PropSovDvmtDiverted=sum(PropSovDvmtDiverted, na.rm = T),
                        PropSFChargingAvail=mean(PropSFChargingAvail, na.rm = T),
                        PropMFChargingAvail=mean(PropMFChargingAvail, na.rm = T)) %>%
              ungroup()) %>%
  mutate(DvmtPc=Dvmt/HhSize,
         PropEmpPaysForParking=EmpPaysForParking/TotEmp,
         PctMixedUse=IsUrbanMixNbrhd/HH,
         PctNoTelework=NoTelework/(NoTelework+PartTimeTelework+FullTimeTelework),
         PctPartTimeTelework=PartTimeTelework/(NoTelework+PartTimeTelework+FullTimeTelework),
         PctFullTimeTelework=FullTimeTelework/(NoTelework+PartTimeTelework+FullTimeTelework),
         WfhPct=(PartTimeTelework+FullTimeTelework)/(NoTelework+PartTimeTelework+FullTimeTelework),
         PctHighCarSvc=NumHighCarSvc/HH,
         region='Region') %>%
  left_join(temp) %>%
  filter(Year==2020 | Year==2045) %>%
  mutate(combined=paste0(region, '_', Year)) %>%
  select(-region, -Year, -EmpPaysForParking, -HhSize) %>%
  pivot_longer(cols = -c('combined'), names_to = 'Output', values_to = 'Value')
  

# 7) Join everything and format/order
st <- results %>%
  filter(Year==2020 | Year==2045) %>% 
  left_join(azone_inputs, by=c('Azone'='Geo', 'Year')) %>%
  left_join(bzone_inputs) %>%
  left_join(marea_inputs) %>%
  mutate(PropEmpPaysForParking=EmpPaysForParking/TotEmp,
         combined=paste0(Azone, '_', Year)) %>%
  select(-Azone, -Year, -Marea, -EmpPaysForParking) %>%
  pivot_longer(cols = -c('combined'), names_to = 'Output', values_to = 'Value')

st$combined <- factor(st$combined, levels=c('Eugene_2020', 'Springfield_2020', 'Coburg_2020',
                                            'Eugene_2045', 'Springfield_2045', 'Coburg_2045'))

st <- st[order(st$combined),]

st <- st %>% pivot_wider(names_from = combined, values_from = Value)

st$Output <- factor(st$Output, levels=c(
  'Population', 'TotEmp', 'RetEmp', 'SvcEmp', 'AveHhSize', 'Prop1PerHh', 'DvmtPc',
  'HHIncomePC.2020', 'IncGR', 'SFDU', 'MFDU', 'PctMixedUse', 'PropEmpPaysForParking',
  'PropNonWrkTripPay', 'PkgCost.2020_Charged', 'PkgCost.2020_All', 'AveVehCostPM',
  'PowerCost.2020', 'VehOwnFlatRateFee.2020', 'FuelCost.2020', 'FuelTax.2020',
  'PaydHhProp', 'PropSovDvmtDiverted', 'TransitServiceMilesBus', 'BusEquivMiles',
  'EcoProp', 'ImpProp', 'PctHighCarSvc', 'PctNoTelework', 'PctPartTimeTelework',
  'PctFullTimeTelework', 'WfhPct', 'FwyLaneMi', 'ArtLaneMi', 'RampMeterDeployProp',
  'IncidentMgtDeployProp', 'SignalCoordDeployProp', 'AccessMgtDeployProp', 'MPG',
  'PctNonIce', 'BusGGE', 'BusPropDiesel', 'BusPropCng', 'TransitEthanolPropGasoline',
  'TransitBiodieselPropDiesel', 'TransitRngPropCng', 'BusPropIcev', 'BusPropBev',
  'PropSFChargingAvail', 'PropMFChargingAvail'
))

st <- st[order(st$Output),]
st <- st %>% filter(!is.na(Output))

write.csv(st, '../results/output/summary_table_processed.csv', row.names = F)

# DO NOT RUN BELOW THIS LINE
#-----------------------------------------------------------------------------#

## Choose summarization level - note if you need to make custom assumptions here on what Geographies you are summarizing
#### This needs to match a column name in the results
#### Select either 'Azone', 'Marea', or a custom geography to summarize by - this table should only be used for geographies larger than bzones
###### Custom geographies will require additions to the base loops 
level = 'Azone'
negate = if(level=='Azone'){'Marea'} else if(level=='Marea'){'Azone'}

## Choose years to summarize - these years must be in the model and can only select 2 for comparison
years = c(2021, 2050)

## Are we using bus factors for revenue miles? Enter 'Yes' or 'No'. Entering 'Yes' will convert all revenue miles to bus equivalent
bus_factors = 'Yes'

## Inputs - enter which inputs need to be presented as sum or averages
### Ex. Population sums vs TDM proportions
### Marea or region inputs should be processed separately in the marea inputs list
inputs_sum <- c('azone_hh_pop_by_age', 'bzone_employment', 'bzone_dwelling_units')
inputs_avg <- c('azone_per_cap_inc', 'azone_payd_insurance_prop', 'bzone_parking', 'azone_fuel_power_cost', 'azone_hh_veh_own_taxes',
                'azone_veh_use_taxes', 'bzone_travel_demand_mgt', 'azone_prop_sov_dvmt_diverted', 'azone_charging_availability',
                'azone_hhsize_targets')
inputs_marea <- c('marea_lane_miles', 'marea_transit_service', 'marea_operations_deployment',
                  'marea_transit_fuel', 'marea_transit_biofuel_mix', 'marea_transit_powertrain_prop')

### Sum calculations
sum_df <- data.frame()

for(i in years) {
  if(level=='Azone'){
    data <- ve %>% mutate(Year=i) %>%
      distinct(Marea, Azone, Year)
    sum_df <- rbind(sum_df, data)
  } else if(level=='Marea'){
    data <- ve %>% mutate(Year=i) %>%
      distinct(Marea, Year)
    sum_df <- rbind(sum_df, data)
  }
}

for(i in inputs_sum){
  data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
    filter(Year %in% years)
  
  cols <- setdiff(names(data), c('Geo', 'Azone', 'Marea', 'Year'))
  
  if(level=='Azone'){
    if(substr(i, 1, 5)=='azone'){
      if(i=='azone_hh_pop_by_age'){
        data <- data %>% group_by(Geo, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          mutate(Population=Age0to14+Age15to19+Age20to29+Age30to54+Age55to64+Age65Plus) %>%
          rename(Azone=Geo) %>%
          select(Azone, Year, Population)
        

      } else {
        data <- data %>% group_by(Geo, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          rename(Azone=Geo)
      }
    } else if(substr(i, 1, 5)=='bzone') {
      if(i=='bzone_dwelling_units'){
        data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
          group_by(Azone, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          mutate(HHs=SFDU+MFDU,
                 Pct_SFDU=SFDU/HHs,
                 Pct_MFDU=MFDU/HHs) %>%
          select(Azone, Year, HHs, contains('Pct'))
        
      } else {
        data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
          group_by(Azone, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup()
      }
    } 
    
    sum_df <- sum_df %>% left_join(data, by=c('Azone', 'Year'))
    
  } else if(level=='Marea'){
    if(substr(i, 1, 5)=='azone'){
      if(i=='azone_hh_pop_by_age'){
        data <- data %>% left_join(ve %>% select(Marea, Azone), by=c('Geo'='Azone')) %>%
          group_by(Marea, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          mutate(Population=Age0to14+Age15to19+Age20to29+Age30to54+Age55to64+Age65Plus) %>%
          select(Marea, Year, Population)
      } else {
        data <- data %>% group_by(Geo, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          rename(Marea=Geo)
      }
    } else if(substr(i, 1, 5)=='bzone') {
      if(i=='bzone_dwelling_units'){
        data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
          group_by(Marea, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          mutate(HHs=SFDU+MFDU,
                 Pct_SFDU=SFDU/HHs,
                 Pct_MFDU=MFDU/HHs) %>%
          select(Marea, Year, HHs, contains('Pct'))
      } else {
        data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
          group_by(Marea, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup()
      }
    } 
    
    sum_df <- sum_df %>% left_join(data, by=c('Marea', 'Year'))
    
  }
}

### Average calculations
for(i in inputs_avg){
  data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
    filter(Year %in% years)
  
  cols <- setdiff(names(data), c('Geo', 'Azone', 'Marea', 'Year'))
  
  if(level=='Azone'){
    if(substr(i, 1, 5)=='azone'){
      data <- data %>% group_by(Geo, Year) %>%
        summarize(across(all_of(cols), ~mean(., na.rm = T))) %>%
        ungroup() %>%
        rename(Azone=Geo)
    } else if(substr(i, 1, 5)=='bzone') {
      data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
        group_by(Azone, Year) %>%
        summarize(across(all_of(cols), ~mean(., na.rm = T))) %>%
        ungroup()
    } 
    
    sum_df <- sum_df %>% left_join(data, by=c('Azone', 'Year'))
    
    #### Add in a piece for parking here - need to get the average across only Bzones that charge parking
    if(i=='bzone_parking' & level=='Azone') {
      data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
        filter(Year %in% years) %>% filter(PkgCost.2010 > 0) %>%
        left_join(ve, by=c('Geo' = 'Bzone')) %>%
        group_by(Azone, Year) %>%
        summarize(PkgCost.2010=mean(PkgCost.2010, na.rm = T)) %>%
        ungroup() %>%
        rename(PkgCost.2010_filtered=PkgCost.2010)
      sum_df <- sum_df %>% left_join(data, by=c('Azone', 'Year'))
    }
    
  } else if(level=='Marea'){
    if(substr(i, 1, 5)=='azone'){
      data <- data %>% left_join(ve %>% distinct(Marea, Azone), by=c('Geo'='Azone')) %>%
        group_by(Marea, Year) %>%
        summarize(across(all_of(cols), ~mean(., na.rm = T))) %>%
        ungroup()
    } else if(substr(i, 1, 5)=='bzone'){
      data <- data %>% left_join(ve %>% select('Marea', 'Bzone'), by=c('Geo'='Bzone')) %>%
        group_by(Marea, Year) %>%
        summarize(across(all_of(cols), ~mean(., na.rm = T))) %>%
        ungroup()
    }
    
    sum_df <- sum_df %>% left_join(data, by=c('Marea', 'Year'))
    
    #### Add in a piece for parking here - need to get the average across only Bzones that charge parking
    if(i=='bzone_parking' & level=='Marea') {
      data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
        filter(Year %in% years) %>% filter(PkgCost.2010 > 0) %>%
        left_join(ve, by=c('Geo' = 'Bzone')) %>%
        group_by(Marea, Year) %>%
        summarize(PkgCost.2010=mean(PkgCost.2010, na.rm = T)) %>%
        ungroup() %>%
        rename(PkgCost.2010_filtered=PkgCost.2010)
      sum_df <- sum_df %>% left_join(data, by=c('Marea', 'Year'))
    }
  }
}

### Marea - we will want to save this as an Excel file on a separate sheet and combine later when formatting
marea_df <- data.frame()

for(i in years) {
  data <- ve %>% distinct(Marea) %>% mutate(Year=i)
  marea_df <- rbind(marea_df, data)
}

for(i in inputs_marea) {
  data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
    filter(Year %in% years)
  
  if(i=='marea_transit_service' & bus_factors=='Yes') {
    data <- data %>% 
      mutate(BusRevMi=MBRevMi+(RBRevMi*1.91),
             TotalRevMi=BusRevMi+(DRRevMi*.18)+(VPRevMi*.88)+(MGRevMi*1.09)+(SRRevMi*1.92)+(HRRevMi*3.43)+(CRRevMi*2.5)) %>%
      select(Geo, Year, BusRevMi, TotalRevMi)
    
    marea_df <- marea_df %>% left_join(data, by=c('Marea'='Geo', 'Year'))
    
  } else if(i=='marea_transit_service' & bus_factors=='No') {
    data <- data %>% 
      mutate(BusRevMi=MBRevMi+RBRevMi,
             TotalRevMi=BusRevMi+DRRevMi+VPRevMi+MGRevMi+SRRevMi+HRRevMi+CRRevMi) %>%
      select(Geo, Year, BusRevMi, TotalRevMi)
    
    marea_df <- marea_df %>% left_join(data, by=c('Marea'='Geo', 'Year'))
    
  } else if(i!='marea_transit_service') {
    marea_df <- marea_df %>% left_join(data, by=c('Marea'='Geo', 'Year'))
  }
}

### Can query outputs from the compiled dataframes established earlier in the script
output <- hh_df %>% filter(Year %in% years) %>%
  group_by(!!sym(level), Year) %>%
  summarize(AveVehCostPM=mean(AveVehCostPM, na.rm = T),
            HH=sum(HH, na.rm = T),
            IsUrbanMixNbrhd=sum(IsUrbanMixNbrhd, na.rm = T)) %>% #### average vehicle cost per mile by geography
  ungroup() %>% 
  mutate(MixedUse_pct=IsUrbanMixNbrhd/HH) %>%
  select(-HH, -IsUrbanMixNbrhd) %>%
  left_join(     ##### percent of households with high car service
    temp <- bzone_df %>% filter(Year %in% years) %>% 
      group_by(!!sym(level), Year, CarSvcLevel) %>%
      summarize(HH=sum(SFDU+MFDU, na.rm = T)) %>%
      ungroup() %>%
      pivot_wider(names_from = CarSvcLevel, values_from = HH) %>%
      mutate(pct_HHs_HighCarSvc=High/(Low+High),
             pct_HHs_HighCarSvc=ifelse(is.na(pct_HHs_HighCarSvc), 0, pct_HHs_HighCarSvc)) %>%
      select(!!sym(level), Year, pct_HHs_HighCarSvc)
  ) %>%
  left_join(    ##### Percent Non-ICE vehicles and Effective HH MPG
    temp <- vehicle_df %>%
      filter(Year %in% years) %>%
      group_by(!!sym(level), Year) %>%
      summarize(HH_ICEV=sum(HH_ICEV, na.rm = T),
                HH_PHEV=sum(HH_PHEV, na.rm = T),
                HH_BEV=sum(HH_BEV, na.rm = T),
                HH_HEV=sum(HH_HEV, na.rm = T),
                MPG=mean(MPG, na.rm = T),
                MPGe=mean(MPGe, na.rm = T)) %>%
      ungroup() %>%
      mutate(Effective_HH_MPG=(MPG+MPGe)/2,
             non_ICEV_prop=(HH_PHEV+HH_BEV+HH_HEV)/(HH_PHEV+HH_BEV+HH_HEV+HH_ICEV)) %>%
      select(!!sym(level), Year, Effective_HH_MPG, non_ICEV_prop)
  ) %>%
  left_join(    #### Proportion of workers who are no, part, or full time teleworking
    temp <- wrk_df %>% filter(Year %in% years) %>%
      group_by(!!sym(level), Year) %>%
      summarize(PartTimeTelework=sum(PartTimeTelework, na.rm = T),
                FullTimeTelework=sum(FullTimeTelework, na.rm = T),
                NoTelework=sum(NoTelework, na.rm = T)) %>%
      ungroup() %>%
      mutate(PartTimeTelework_pct=PartTimeTelework/(PartTimeTelework+FullTimeTelework+NoTelework),
             FullTimeTelework_pct=FullTimeTelework/(PartTimeTelework+FullTimeTelework+NoTelework),
             NoTelework_pct=NoTelework/(PartTimeTelework+FullTimeTelework+NoTelework)) %>%
      select(!!sym(level), Year, PartTimeTelework_pct, FullTimeTelework_pct, NoTelework_pct)
  )

## Now perform custom calculations on the summary dataframe
custom_df_sum <- sum_df %>%
  left_join(output) %>%
  select(-all_of(negate)) %>% ### May need to comment out this line in the case of using level = 'Marea'
  pivot_longer(cols = -c(!!sym(level), Year), names_to = 'Measure', values_to = 'Value') %>%
  pivot_wider(names_from = Year, values_from = Value) %>%
  mutate(pct_change = ((!!sym(as.character(years[2])) - !!sym(as.character(years[1]))) / !!sym(as.character(years[1]))),
         pct_change=ifelse(is.infinite(pct_change), 1, pct_change),
         pct_change=ifelse(is.nan(pct_change), 0, pct_change)) %>%
  pivot_longer(cols=-c(!!sym(level), Measure), names_to = 'Year', values_to = 'Value') %>%
  mutate(name=paste0(!!sym(level), '_', Year)) %>%
  select(name, Measure, Value) %>%
  pivot_wider(names_from = name, values_from = Value) %>%
  select(Measure, ends_with(as.character(years[1])), ends_with(as.character(years[2])), ends_with('pct_change'))

custom_df_marea <- marea_df %>%
  pivot_longer(cols = -c(Marea, Year), names_to = 'Measure', values_to = 'Value') %>%
  pivot_wider(names_from = Year, values_from = Value) %>%
  mutate(pct_change = ((!!sym(as.character(years[2])) - !!sym(as.character(years[1]))) / !!sym(as.character(years[1]))),
         pct_change=ifelse(is.infinite(pct_change), 1, pct_change),
         pct_change=ifelse(is.nan(pct_change), 0, pct_change)) %>%
  pivot_longer(cols=-c(Marea, Measure), names_to = 'Year', values_to = 'Value') %>%
  mutate(name=paste0(Marea, '_', Year)) %>%
  select(name, Measure, Value) %>%
  pivot_wider(names_from = name, values_from = Value) %>%
  select(Measure, ends_with(as.character(years[1])), ends_with(as.character(years[2])), ends_with('pct_change'))

## Write the Excel file
list <- list('Summary - selected Geo' = custom_df_sum, 'Summary - Marea metrics' = custom_df_marea)
write.xlsx(list, file = '../results/output/summary_table_processed.xlsx')
