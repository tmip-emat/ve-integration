# Exploratory Scoping

TMIP-EMAT is a methodological approach for exploratory modeling and analysis designed to integrate existing transportation models, including `VisionEval`, to perform exploratory analysis of a range of possible scenarios. It offers several features that enhance the functionality of underlying core models like `VisionEval` for exploratory analysis. The parameters in TMIP-EMAT can be used to scope the input variables of VisionEval, and Measures to scope its output variables. Considering the characteristics and limitations of VisionEval, the type of variables that can be effectively used for experiment scoping in TMIP-EMAT include the following:

### **Parameters (Scoping VisionEval Inputs)**:

- **Policy Levers**: These represent the policy choices or interventions that can be explored. Given VisionEval's focus on policy analysis, variables that directly correspond to policy adjustments within VisionEval's input files can be used. Examples from the VisionEval User Guide include: 
    - **Pricing strategies**: Fuel and electricity costs, road cost recovery mechanisms (registration fees, gas taxes, VMT fees), parking pricing policies.
    - **Transportation operations actions**: Transit service levels (service miles by mode), road lane-miles, ITS operations (ramp metering, signal optimization), Eco-Drive program participation.
    - **Land use policies**: Assumptions about development density, shares of households in mixed-use areas.
    - **Demand management programs**: Participation rates in TDM programs (both home and work-based).
    - **Vehicle and fuel characteristics**: Assumptions about the future vehicle fleet composition (e.g., percentage of light trucks, vehicle age, adoption rates of different powertrain technologies like EVs and PHEVs).

- **Exogenous Uncertainties**: These represent future conditions or factors outside of direct policy control that could influence the outcomes. VisionEval is designed to explore a range of possible future conditions, so suitable parameters could include: 
    - **Demographic projections: Population growth, household size, age distribution, per capita income.
    - **Economic conditions**: Factors influencing economic growth, which might affect travel behavior and other inputs.
    - **Technology deployment**: Uncertainty in the rate and extent of adoption of new transportation technologies like autonomous vehicles or ride-hailing services.
    - **Fuel prices**: Variations in the cost of gasoline, diesel, and electricity.

### **Measures (Scoping VisionEval Outputs)**:

These would correspond to the performance metrics that VisionEval calculates and reports. TMIP-EMAT can be used to explore the sensitivity of these measures to the variations in the input parameters. 

Examples from the VisionEval User Guide include:
- **Mobility metrics**: 
    - Daily VMT per capita
    - annual walk/bike trips per capita

- **Economic metrics**: 
    - Household vehicle operating costs 
    - household vehicle ownership costs 
    - household parking costs 
    - annual all vehicle delay per capita.

- **Land Use metrics**: 
    - Percentage of residents in mixed-use areas
    - number of dwelling units by type.

- **Energy metrics**: 
    - Annual per capita fuel consumption 
    - Average fuel efficiency, external social costs.


### **VisionEval's Limitations**:
Given that VisionEval operates at a broad geographic level and without explicit network representations, the parameters and measures that are scoped in TMIP-EMAT will also reflect this aggregate nature. TMIP-EMAT scoping should focus on how broad changes in policies and future conditions (represented by VisionEval's modifiable inputs) influence aggregate-level performance outcomes (VisionEval's outputs) across different geographies (region, Azone, Marea, Bzone).

