# this module appends counterfactual scenario to persons table


#' Append counterfacual scenario
#'
#' Append travel estimates from counterfacual scenario to baseline scenario
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item creates a copy of VE persons synthesized from baseline VE household
#'
#'  \item appends counterfactual scenario travel estimates to persons copy
#'  
#'  \item estimates travel duration by mode and assigns to counterfactual scenario persons
#'  
#'  \item rbinds baseline, counterfactual scenario to align with downstream ithim fu
#'    }
#'
#' @param persons data.table containing VE persons (from reference scenario)
#' @param scenarioHhs data.table containing VE households for counterfactual scenario
#' @param scenario name of counterfactual scenario
#' @param settings data.table storing ithim settings/configuration
#'
#' @return data.table containing VE households
#'
#' @export


appendCounterfactualScenario <- function(persons, scenarioHhs, scenario, settings){
  
  # first, establish baseline scenario
  persons$scenario <- "baseline"
  
  # first, instantiate a person view of counterfactual scenario
  # keep all of the person-level attributes from baseline scenario
  keep_cols <- c(
    "HhId", "Bzone", "PId", "HhSize", "age", "sex", "PM25", "leisurePA")
  counterfactual <- copy(persons[, ..keep_cols])
  counterfactual$scenario <- scenario
  
  # now, join auto, transit, walk, and bike PMT from counterfactual
  setnames(scenarioHhs,
           c("Dvmt", "TransitPMT", "WalkPMT", "BikePMT"),
           c("auto_dist", "transit_dist", "walk_dist", "bike_dist"))
  join_cols <- c("HhId", "auto_dist", "transit_dist", "walk_dist", "bike_dist")
  counterfactual <- counterfactual[scenarioHhs[, ..join_cols], on = .(HhId)]

  # first, convert distances to duration
  counterfactual$auto_minutes <- counterfactual$auto_dist / settings[name=="speed_auto"]$value * 60
  counterfactual$transit_minutes <- counterfactual$transit_dist / settings[name=="speed_transit"]$value * 60
  counterfactual$walk_minutes <- counterfactual$walk_dist / settings[name=="speed_walk"]$value * 60
  counterfactual$bike_minutes <- counterfactual$bike_dist / settings[name=="speed_bike"]$value * 60
  
  # as before, decompose scenario hh travel totals to individuals
  travel_cols = c(
    "auto_dist", "transit_dist", "walk_dist", "bike_dist",
    "auto_minutes", "transit_minutes", "walk_minutes", "bike_minutes"
  )
  for (col in travel_cols) {
    replacement_values <- counterfactual[, ..col] / counterfactual$HhSize
    counterfactual[, (col) := replacement_values]
  }
  
  # bind two scenarios and return
  persons <- rbind(persons, counterfactual)
  return(persons)
}


#' Extract trips
#'
#' Converts person daily travel estimates to pseudo-trips (one trip per mode per day)
#' This is done because downstream ithim funcs operate on trip tables, so most
#' straightforward way to align model frameworks is to develop pseudo-trips
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item melts persons table to generate pseudo-trips view (each row is a trip)
#'
#'  \item adds duration to pseudo-trips view 
#'    }
#'
#' @param persons data.table containing VE persons (reference and counterfactual)
#'
#' @return data.table containing VE pseudo-trips
#'
#' @export


extractTrips <- function(persons){
  
  # easiest way to integrate with ITHIM is to treat each mode as a single trip
  # so will convert persons into a quasi trips table
  attr_cols <- c("PId", "leisurePA", "scenario")
  dist_cols <- c("auto_dist", "transit_dist", "walk_dist", "bike_dist")
  dur_cols <- c("auto_minutes", "transit_minutes", "walk_minutes", "bike_minutes")
  
  # first, melt on distance cols
  combined_cols <- c(attr_cols, dist_cols)
  trips <- melt(persons[, ..combined_cols],
                measure.vars = dist_cols,
                variable.name = "mode", value.name = "distance")[order(PId)]
  trips$mode <- gsub("_dist", "", trips$mode)  # clean up mode names
  
  # now, melt on duration cols
  combined_cols <- c("PId", "scenario", dur_cols)
  trip_dur <- melt(persons[, ..combined_cols],
                measure.vars = dur_cols,
                variable.name = "mode", value.name = "minutes")[order(PId)]
  trip_dur$mode <- gsub("_minutes", "", trip_dur$mode)  # clean up mode names
  
  # append minutes to trips df
  # TODO: at this point, we have not added walk/bike access to transit trips 
  trips <- trips[trip_dur, on = .(PId, scenario, mode)]
  
  return(trips)
}

  
