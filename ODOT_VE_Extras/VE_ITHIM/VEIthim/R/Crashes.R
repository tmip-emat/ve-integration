#' Predict injuries
#'
#' Predict injuries for baseline and scenarios based on Poisson regression model fitted
#' on baseline fatality counts and distances
#'
#' This function uses the Poisson regression model built in the \code{\link{distances_for_injury_function()}} to predict fatality
#' counts for the Baseline and all the scenarios. It performs the following steps:
#'
#' \itemize{
#' \item create an injuries data frame containing all the distances travelled by mode, age, sex and scenario
#'
#' \item predict the fatalities for each strike and casualty mode combination, age and sex category
#'   and each scenario (incl Baseline). If the sample mode is set to 'constant' (and not 'sample'),
#'   we also predict upper and lower confidence interval boundaries
#'
#' \item create a whw_temp list containing the total predicted fatality counts for each casualty
#'   and strike mode pair for each scenario split into whw and nov matrices and, for the
#'   constant mode also give the upper and lower confidence interval limit predictions
#'
#' \item create an injuries2 data frame containing the total predicted fatality counts
#'   for each casualty mode by age and sex for each scenario. This dataframe also
#'   contains total death per age and sex category and, for the constant mode the
#'   upper and lower total death predictions of the confidence interval.
#' }
#'
#'
#'
#' @param true_distances data frame containing population distances for each scenario
#' @param injuries_list list of dataframes set up with scenario specific information to supply to regression model for prediction
#' @param reg_model Poisson injury regression model
#' @param constant_mode whether or not we are in constant (vs sampling) mode
#'
#' @return injuries2 - dataframe containing predicted fatality counts for each casualty mode by age and sex and for each scenario, plus confidence interval limits for constant mode
#' @return whw_temp - list containing the fatality predictions for each casualty and strike mode pair split into whw and nov matrices for each scenario. Upper and lower confidence interval predictions are also included for the constant mode
#'
#' @export


prepareCrashData <- function(hhs, input_dir, base_year, config) {
  
  # we are using the California ITHIM model here
  # ie, mechanistic (non-probalistic) approach
  
  # two crash methods supported
  crash_method <- config[name=="crash_method"]$value
  
  # method 1: fars data
  if (crash_method == "fars"){
    
    # load fars data
    browser()
    injuries <- fread(file.path(input_dir, "fars.csv"))
    
    # if strike mode is null, replace with 'nov' (no other vehicle)
    injuries[strike_mode=="", strike_mode := "nov"]  # in-place
    
    # assign weight to account for multiple years of injury data
    # ie, convert to yearly rate
    injuries$yearly_rate = 1 / length(unique(injuries$year))
    
    # count fatalities by mode combinations
    agg_cols <- c("yearly_rate")
    injuries <- injuries[, lapply(.SD, sum),
                         by=.(cas_mode, strike_mode),
                         .SDcols=agg_cols]
  }
  
  # method 2: VE marea crash factors
  else if (crash_method == "ve"){
    
    # load ve crash rates
    injuries <- fread(file.path(input_dir, "marea_safety_factors.csv"))
    injuries <- injuries[Year==2021]
    
    # isolate fatality data (apples-to-apples with fars)
    fatal_cols <- colnames(injuries)[colnames(injuries) %like% "Fatal"]
    injuries <- injuries[, ..fatal_cols]
    colnames(injuries) <- tolower(gsub('Fatal','',fatal_cols))
    
    # combine bus/rail fatalities
    injuries$transit <- injuries$bus + injuries$rail
    mode_cols = c("auto", "transit", "walk", "bike")
    injuries <- injuries[, ..mode_cols]

    # reshape injuries to match fars format
    injuries <- melt(injuries,
                     measure.vars = mode_cols,
                     variable.name = "cas_mode",
                     value.name = "yearly_rate")
    
    # we can just assume all crashes have a strike_mode of "auto"
    # this is mostly ok, but we are missing single-vehicle crashes
    injuries$strike_mode <- "auto"
  }
    
  # we also need yearly distance by mode
  # first, rename mode cols
  mode_cols = c("auto", "transit", "walk", "bike")
  setnames(Hhs,
           c("Dvmt", "TransitPMT", "WalkPMT", "BikePMT"),
           mode_cols)
  agg_cols <- c("distance")
  distance_by_mode <- Hhs[, ..mode_cols][, lapply(.SD, sum),
                          .SDcols=mode_cols]
  
  # melt distances by mode 
  distance_by_mode <- melt(distance_by_mode,
                           measure.vars = mode_cols,
                           variable.name = "mode",
                           value.name = "distance")
  
  # if using ve safety factors, we need to estimate baseline fatalities by mode
  # which will then be used in the who-hit-who matrix
  # we currently have rates per 100 mil VMT
  if (crash_method == "ve"){
    yearly_vmt <- distance_by_mode[mode=="auto"]$distance * 365
    injuries$yearly_rate <- injuries$yearly_rate * yearly_vmt / 100000000
  }
  
  # append daily cas_mode distances
  injuries <- injuries[distance_by_mode,
                       on = c(cas_mode = "mode"),
                       nomatch = NULL]

  # annualize distance
  injuries$cas_mode_dist <- injuries$distance * 365
  injuries[ ,distance := NULL]  # clean up schema after join
  
  # append daily strike_mode distances
  injuries <- distance_by_mode[injuries, on = c(mode = "strike_mode")]
  injuries$strike_mode_dist <- injuries$distance * 365
  injuries$strike_mode_dist[is.na(injuries$strike_mode_dist)] <- 1
  injuries$strike_mode <- injuries$mode
  
  # calculate baseline rates
  injuries$rate <- injuries$yearly_rate / 
    (injuries$cas_mode_dist * injuries$strike_mode_dist)
  
  # clean up schema and return injuries roll-up
  scrub <- c("cas_mode_dist", "mode", "distance", "yearly_rate")
  injuries[ ,(scrub) := NULL]
  col_order <- c("cas_mode", "strike_mode", "strike_mode_dist", "rate")
  setcolorder(injuries, col_order)
  return(injuries)
}


injuries_function <- function(trips, injuryRates, scenarios) {
  
  # first, strike mode distances for each scenario
  agg_cols <- c("distance")
  strike_mode_dist <- trips[, lapply(.SD, sum),
                            by=.(scenario, mode),
                            .SDcols=agg_cols]
  
  # now, each trip can be assigned an injury risk
  keep_cols = c("PId", "scenario", "mode", "distance")
  injuryPredictions <- trips[, ..keep_cols][injuryRates,
                                            on = c(mode = "cas_mode"),
                                            allow.cartesian=TRUE]
  
  # we can now calculate trip-level injury rates
  injuryPredictions$injuries <- injuryPredictions$rate * 
    injuryPredictions$distance * injuryPredictions$strike_mode_dist
  
  # and annualize
  injuryPredictions$injuries <- injuryPredictions$injuries * 365
  
  # now roll-up to person level
  agg_cols <- c("injuries")
  injuryPredictions <- injuryPredictions[, lapply(.SD, sum),
                                         by=.(PId, scenario),
                                         .SDcols=agg_cols]
  
  # Change to wide format
  injuryPredictions <- injuryPredictions %>% 
    dplyr::select(PId, scenario, injuries) %>% 
    pivot_wider(names_from = 'scenario', values_from = 'injuries')
  
  # traffic_deaths prefix for each scenario
  inj_colnames <- paste(scenarios, 'traffic_deaths', sep = '_')
  setDT(injuryPredictions)
  setnames(injuryPredictions, scenarios, inj_colnames)
  return(injuryPredictions)
}

