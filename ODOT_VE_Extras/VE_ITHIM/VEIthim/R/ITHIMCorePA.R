#' Calculate total AP exposure per person
#' 
#' Calculate total AP exposure per person based on population and personal travel
#' 
#' This function performs the following steps:
#' 
#' \itemize{
#' \item the ventilation rates per mode are defined - these parameters are fixed
#' 
#' \item the exposure factor rates by activity are defined - these parameters are fixed
#' 
#' \item calculate pm concentration not related to transport
#' 
#' \item calculate PM emission factors for each mode by dividing total emissions by distances travelled
#' 
#' \item calculate PM emissions for each mode in each scenario by multiplying the scenario distance
#'   by the emission factors
#' 
#' \item for modes without any assigned distance, use the PM emissions from the VEHICLE_INVENTORY instead
#' 
#' \item calculate the total PM concentrations for each scenario
#' 
#' \item add ventilation and exposure factors to the trip set by stage mode
#' 
#' \item add total scenario PM concentrations to the trip set
#' 
#' \item add the inhaled air and total PM (in micro grams) to the trip set
#' 
#' \item define the amount of time per day spent as leisure sedentary screen time, 
#'   non-discretionary time and other time - fixed
#' 
#' \item add total time spent travelling by each participant to the trip set
#'
#' \item calculate the sleep and the rest ventilation rates
#' 
#' \item for each participant in the synthetic population (with travel component), 
#'   calculate the total air inhaled, the total PM inhaled and 
#'   the total PM concentration inhaled for each scenario
#'
#' \item assign all participants in the synthetic population without travel component,
#'   the baseline or scenario PM concentrations
#'
#' \item join all people with and without travel in the synthetic population
#' }
#' 
#' 
#' @param dist total distance travelled by mode by the population for all scenarios
#' @param trip_scen_sets trips data frame of all trips from all scenarios
#' 
#' @return background PM concentration for baseline and all scenarios
#' @return total AP exposure per person in the synthetic population (for baseline and scenarios)
#' 
#' @export


total_mmet <- function(persons, trips, scenarios, input_dir) {
  
  # read mets
  mets <- fread(file.path(input_dir, "ithim", "mets.csv"),
                select = c("mode", "met"))
  
  # extract all people from the trip set with an active travel (walk or cycle) stage mode
  active_modes <- c("walk", "bike")
  rd_pa <- trips[trips$mode %in% active_modes]

  # Scale trip duration to entire week
  rd_pa$weekly_hrs <- rd_pa$minutes / 60 * 7
  
  # convert leisure PA to marginal mets
  agg_cols <- c("leisurePA")
  mmets <- rd_pa[, lapply(.SD, first),
                 by=.(PId, scenario),
                 .SDcols=agg_cols ]
  mmets$mmet <- mmets$leisurePA / 60 * (mets[mode=="moderate"][, met] - 1)
  
  # walking mets
  agg_cols <- c("weekly_hrs")
  walk_mmet <- rd_pa[mode=="walk"][, lapply(.SD, sum, na.rm=TRUE),
                                   by=.(PId, scenario),
                                   .SDcols=agg_cols ]
  walk_mmet$mmet <- walk_mmet$weekly_hrs * (mets[mode=="walk"][, met] - 1)
  
  # biking mets
  bike_mmet <- rd_pa[mode=="bike"][, lapply(.SD, sum, na.rm=TRUE),
                                   by=.(PId, scenario),
                                   .SDcols=agg_cols ]
  bike_mmet$mmet <- bike_mmet$weekly_hrs * (mets[mode=="bike"][, met] - 1)
  
  # sum mets across activity types
  mmets$walk_mmets <- walk_mmet$mmet
  mmets$bike_mmets <- bike_mmet$mmet
  mmets$total_mmets <- mmets$mmet + walk_mmet$mmet + bike_mmet$mmet
  
  # Calculate total air and pm inhaled in each person
  # Change to wide format
  mmets <- mmets %>% 
    dplyr::select(PId, scenario, total_mmets) %>% 
    pivot_wider(names_from = 'scenario', values_from = 'total_mmets')
  
  # pm_conc prefix for each scenario
  pa_colnames <- paste('mmet', scenarios, sep = '_')
  setDT(mmets)
  setnames(mmets, scenarios, pa_colnames)
  
  # Join person info to mmets
  join_cols <- c("PId", "age", "sex")
  mmets <- mmets[persons$scenarioPersons[scenario=="baseline", ..join_cols],
                 on = .(PId)]
  
  # enforce sorting and return
  return(mmets[order(PId)])
}

