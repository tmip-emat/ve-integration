## development code for ITHIM model implementation

# #Load packages and test functions
library(data.table)
library(tidyr)
library(pracma)
library(dplyr)
source("R/LoadSettings.R")
source("R/HarmonizeData.R")
source("R/GenerateScenarios.R")
source("R/ITHIMCoreAP.R")
source("R/ITHIMCorePA.R")
source("R/RiskFuncsAP.R")
source("R/RiskFuncsPA.R")
source("R/HealthBurden.R")
source("R/Crashes.R")

# load ithim settings and parse base, forecast years
input_dir <- file.path("inst", "extdata")
settings <- loadSettings(input_dir)

# before looking at future years, need to prepare crash data using base year
# we will use these rates for all future time periods
Hhs <- loadVEHhs(settings$results_dir, settings$base_model, settings$base_year)
injuryRates <- prepareCrashData(Hhs, input_dir, settings$base_year, settings$config)

# we'll need to loop through each future year
for (year in settings$future_years){
  
  ### LOAD REQUIRED VE OUTPUTS
  print(paste(year, settings$base_model))
  
  # load VE Hhs table
  Hhs <- loadVEHhs(settings$results_dir, settings$reference_model, year)
  
  # transform households table into persons table
  persons <- hhsToPersons(Hhs, input_dir, settings$settings)
  
  # join baseline PM2.5, leisure PA estimates to persons tables
  # persons dt is now nested; second level in persons list
  persons$refPersons <- appendZoneAttributes(persons$persons, year, input_dir)
  
  # now we have established the baseline (reference) population
  # we will now work on scenarios one at a time
  # comparing each to the reference scenario population
  for (scenario in settings$scenarios){
    
    ### PREPARE SCENARIO OUTPUTS
    print(paste(year, scenario))
    
    # instantiate list of (baseline, scenario)
    ref_scenarios <- c("baseline", scenario)
    
    # load VE Hhs table for scenarios
    scenarioHhs <- loadVEHhs(settings$results_dir, scenario, year)
    
    # append this counterfactual scenario to persons
    persons$scenarioPersons <- appendCounterfactualScenario(
      persons$refPersons, scenarioHhs, scenario, settings$settings)
    
    # extract pseudo trips from persons
    trips <- extractTrips(persons$scenarioPersons)
    
    ### RUN CORE ITHIM STEPS
    ## AP pathway
    pm_exposure <- scenario_pm_calculations(trips, persons, input_dir, settings$settings)
    
    # Assign relative risks to each person in the synthetic population for each disease
    # related to air pollution and each scenario based on the individual PM exposure levels
    RR_AP_calculations <- gen_ap_rr(pm_exposure, ref_scenarios, input_dir)
    
    ## PA pathway
    # calculate total mMETs for each person in the synthetic population
    mmets <- total_mmet(persons, trips, ref_scenarios, input_dir)
    
    # assign a relative risk to each person in the synthetic population for each disease
    # related to physical activity levels and each scenario based on the individual mMET values
    RR_PA_calculations <- gen_pa_rr(mmets, ref_scenarios, input_dir)
    
    # create one dataframe containing both the PA, the AP and the combined PA and AP relative risks
    # (for those diseases affected by both PA and AP) for all people in the synthetic population and all scenarios
    RR_PA_AP_calculations <- combined_rr_ap_pa(
      ind_pa = RR_PA_calculations, ind_ap = RR_AP_calculations, ref_scenarios, input_dir)
    
    # calculate the health burden (Yll and deaths) for each disease and age and sex category
    # by combining the AP and PA pathways for diseases affected by both AP and PA
    healthBurden <- health_burden(
      ind_ap_pa = RR_PA_AP_calculations, input_dir, ref_scenarios)

    ## crash pathway
    # this is a modified version of the California ITHIM code
    # i.e., rates based, non-probabilistic approach
    injuries <- injuries_function(trips, injuryRates, ref_scenarios)
    injuryBurden <- injury_death_to_yll(
      persons$scenarioPersons, injuries, input_dir, ref_scenarios)
    
    ### SUMMARIZE IMPACTS
    healthBurden <- join_hb_and_injury(healthBurden, injuryBurden)
    aggregateHealthBurden(
      healthBurden, persons$refPersons, scenario, settings$results_dir)
    
  }  # end of scenarios loop
}  # end of years loop
