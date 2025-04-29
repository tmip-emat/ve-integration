#' Get relative risk for diseases given PM exposure
#'
#' Computes the relative risk (RR) for persons for each disease given PM exposure
#'
#' This function performs the following steps:
#' \itemize{
#' \item minimum ages for each age group corresponding to disease risks are assigned to the individuals in the
#'   synthetic population (with added PM exposure levels)
#'
#' \item loop through all diseases that are related to PM pollution:
#'   \itemize{
#'    \item depending on the disease (as some disease have different relative risks depending
#'      on the age of the individual) loop through disease specific age groups (or just
#'      one age group for most disease)
#'
#'    \item set the quantile of the value of the dose response curves to be extracted. If running in
#'      constant mode, the quantile is usually set to 0.5, i.e. to the median of the dose response curves.
#'      If running in sample mode, then the quantile can be set to be sampled from a distribution in the
#'      input parameters.
#'
#'    \item loop through the scenarios:
#'      \itemize{
#'      \item assign the relative risk for the given disease, age group, quantile and scenario to the
#'        relevant people in the synthetic population by calling the \code{\link{AP_dose_response()}} function
#'      }
#'    }
#' }
#'
#' @param pm_conc_pp individual PM exposures for each person in the synthetic population
#'
#' @return data frame of relative risks per person for each disease and each scenario
#'
#' @export


dose_response <- function (cause, outcome_type, dose, quantile = 0.5, censor_method = "75thPercentile", 
                           confidence_intervals = F) 
{
  if (is.null(dose) || class(dose) != "numeric") 
    stop("Please provide dose in numeric")
  if (is.na(quantile) || class(quantile) != "numeric" || quantile >= 
      1 || quantile < 0) 
    stop("Please provide the quantile value between 0 and 1")
  if (is.na(censor_method) || class(censor_method) != "character" || 
      !censor_method %in% c("none", "75thPercentile", "WHO-DRL", 
                            "WHO-QRL")) 
    stop("Please specificy `censor_method` by selecting either of four options: `none`, `75thPercentile`,`WHO-DRL`,`WHO-QRL`")
  # pert_75 <- readr::read_csv(system.file("extdata", "75p_diseases.csv",
  #                                        package = "drpa", mustWork = TRUE), col_type = readr::cols())
  pert_75 <- readr::read_csv('inst/extdata/drpa/extdata/75p_diseases.csv', col_type = readr::cols())
  if (!cause %in% pert_75$disease) {
    stop("Unsupported cause/disease. Please select from \n\n           all-cause-cancer  \n\n           all-cause-cvd  \n\n           all-cause-dementia \n\n           all-cause-mortality \n\n           alzheimer's-disease \n\n           bladder-cancer \n\n           breast-cancer \n\n           colon-cancer \n\n           coronary-heart-disease \n\n           depression \n\n           depressive-symptoms \n\n           diabetes \n\n           endometrial-cancer \n\n           esophageal-cancer \n\n           gastric-cardia-cancer \n\n           head-and-neck-cancer \n\n           heart-failure \n\n           kidney-cancer \n\n           liver-cancer \n\n           lung-cancer \n\n           major-depression \n\n           myeloid-leukemia \n\n           myeloma \n\n           parkinson's-disease \n\n           prostate-cancer \n\n           rectum-cancer \n\n           stroke \n\n           vascular-dementia \n")
  }
  if (!outcome_type %in% c("fatal", "non-fatal", "fatal-and-non-fatal")) {
    stop("Unsupported outcome_type. Please select from \n\n         fatal \n\n         non-fatal \n\n         fatal-and-non-fatal")
  }
  fname <- paste(cause, outcome_type, sep = "-")
  if (
    # !file.exists(system.file("extdata", paste0(fname, ".csv"),
    #                            package = "drpa"))) {
    !file.exists(paste0('inst/extdata/drpa/extdata/', fname, '.csv'))) {
    stop(paste("Sorry but for ", cause, " the outcome type ",
               outcome_type, " is not supported by the package"))
  }
  # lookup_table <- readr::read_csv(system.file("extdata", paste0(fname, 
  #                                                               ".csv"), package = "drpa", mustWork = TRUE), col_type = readr::cols())
  lookup_table <- readr::read_csv(paste0("inst/extdata/drpa/extdata/", fname, ".csv"), col_type = readr::cols())
  if (censor_method == "75thPercentile") {
    upper_limit <- pert_75 %>% dplyr::filter(disease == 
                                               cause) %>% dplyr::select(outcome_type) %>% as.numeric()
    dose[dose > upper_limit] <- upper_limit
  } else if (censor_method == "WHO-DRL") {
    dose[dose > 17.5] <- 17.5
  } else if (censor_method == "WHO-QRL") {
    dose[dose > 35] <- 35
  }
  rr <- approx(x = lookup_table$dose, y = lookup_table$RR, 
               xout = dose, yleft = 1, yright = min(lookup_table$RR))$y
  if (confidence_intervals || quantile != 0.5) {
    lb <- approx(x = lookup_table$dose, y = lookup_table$lb, 
                 xout = dose, yleft = 1, yright = min(lookup_table$lb))$y
    ub <- approx(x = lookup_table$dose, y = lookup_table$ub, 
                 xout = dose, yleft = 1, yright = min(lookup_table$ub))$y
  }
  if (quantile != 0.5) {
    rr <- qnorm(quantile, mean = rr, sd = (ub - lb)/1.96)
    rr[rr < 0] <- 0
  }
  if (confidence_intervals) {
    return(data.frame(rr = rr, lb = lb, ub = ub))
  } else {
    return(data.frame(rr = rr))
  }
}


gen_pa_rr <- function(mmets, scenarios, input_dir) {
  
  # load physical activity relative risk values
  # these are stored in global env in ITHIM, which is not ideal....
  diseases <- fread(file.path(input_dir, "disease_outcomes_lookup.csv"))
  diseases <- diseases[physical_activity==1]  # isolate PA pathway
  
  ### iterate over all all disease outcomes that are related to physical activity levels
  for (i in 1:nrow(diseases)) {
    
    # isolate row corresponding to disease
    disease <- diseases[i,]
    
    # define the potential outcomes as either fatal or fatal-and-non-fatal
    outcome <- ifelse(disease$outcome == "deaths", "fatal",
                      "fatal-and-non-fatal"
    )
    
    # calculate rr value for baseline and scenario and append to mmets
    for (scenario in scenarios) {
      
      # Apply PA DR function for baseline
      # Use a hard censor method of WHO-QRL which flattens the relationship after 35 MMETs per week
      scenario_col <- paste0("mmet_", scenario)
      rr <- dose_response(
        cause = disease$pa_acronym,  # name of PA DR curve
        outcome_type = outcome,
        dose = mmets[[scenario_col]],
        censor_method = "WHO-QRL"
      )
      
      # append rr value to mmets
      scenario_rr_col <- paste("RR_pa", scenario, disease$acronym, sep = "_")
      mmets[[scenario_rr_col]] <- rr$rr
      
      # but, need to truncate based on age
      # pathway only valid btw 15-70 years old
      mmets[age<15, (scenario_rr_col) := 1]
      mmets[age>69, (scenario_rr_col) := 1]
    }  # end of scenarios loop
  }  # end of disease loop
  
  # clean up columns and return ap relative risks
  scrub <- paste0("mmet_", scenarios)
  mmets[ ,(scrub) := NULL]  # in-place
  return(mmets)
}


combined_rr_ap_pa <- function(ind_pa, ind_ap, scenarios, input_dir, conf_int = FALSE) {
  
  # load all relative risk values
  # these are stored in global env in ITHIM, which is not ideal....
  diseases <- fread(file.path(input_dir, "disease_outcomes_lookup.csv"))
  
  # Replace NaNs with 1
  ind_ap[is.na(ind_ap)] <- 1
  
  # Replace Na with 1
  ind_pa[is.na(ind_pa)] <- 1
  
  # join pa and ap datasets (all data.frames)
  ind_pa[, c("age", "sex"):=NULL]  # only need age, sex in one df
  ind_ap_pa <- ind_ap[ind_pa, on = .(PId)]
  
  ### iterating over all all disease outcomes that are affected by both PA and AP
  for (j in c(1:nrow(diseases))[diseases$physical_activity == 1 & diseases$air_pollution == 1]) {
    
    ac <- as.character(diseases$acronym[j])
    
    for (scen in scenarios) { # loop through scenarios
      ind_ap_pa[[paste("RR_pa_ap", scen, ac, sep = "_")]] <- ind_ap_pa[[paste("RR_pa", scen, ac, sep = "_")]] * ind_ap_pa[[paste("RR_ap", scen, ac, sep = "_")]]
      
      # for confidence intervals, multiply the upper and lower RR for AP and PA respectively wherever possible,
      # otherwise use the given RR values instead
      if (conf_int) {
        column_pa_lb <- ifelse(paste("RR_pa", scen, ac, "lb", sep = "_") %in% colnames(ind_ap_pa), paste("RR_pa", scen, ac, "lb", sep = "_"), paste("RR_pa", scen, ac, sep = "_"))
        column_pa_ub <- ifelse(paste("RR_pa", scen, ac, "ub", sep = "_") %in% colnames(ind_ap_pa), paste("RR_pa", scen, ac, "ub", sep = "_"), paste("RR_pa", scen, ac, sep = "_"))
        
        column_ap_lb <- ifelse(paste("RR_ap", scen, ac, "lb", sep = "_") %in% colnames(ind_ap_pa), paste("RR_ap", scen, ac, "lb", sep = "_"), paste("RR_ap", scen, ac, sep = "_"))
        column_ap_ub <- ifelse(paste("RR_ap", scen, ac, "ub", sep = "_") %in% colnames(ind_ap_pa), paste("RR_ap", scen, ac, "ub", sep = "_"), paste("RR_ap", scen, ac, sep = "_"))
        
        
        ind_ap_pa[[paste("RR_pa_ap", scen, ac, "lb", sep = "_")]] <- ind_ap_pa[[column_pa_lb]] * ind_ap_pa[[column_ap_lb]]
        
        ind_ap_pa[[paste("RR_pa_ap", scen, ac, "ub", sep = "_")]] <- ind_ap_pa[[column_pa_ub]] * ind_ap_pa[[column_ap_ub]]
      }
    }
  }
  
  return(ind_ap_pa)
}

