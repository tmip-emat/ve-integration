# Exploratory Scoping

**TMIP-EMAT** is not a transportation model in and of itself. It is a utility tool that enables an analyst to use the region’s transportation model for exploratory analyses. **Exploratory Modeling Approach (EMA)** has been used by planners to better understand systems with deep uncertainty by calibrating models that explain the system, where some inputs to the system have uncertainty associated with them, there are various policies or levers available to a decisionmaker to affect the system, and there are various outputs of the system which are of interest. An EMA research methodology explicitly treats the computational experiment (i.e., model) as a set of assumptions and hypotheses and aims to explore the impacts. This differs from treating the model as a predictive tool that is an accurate surrogate to the real world.

TMIP-EMAT is designed as a tool to engage stakeholders and policymakers in discussions around developing effective policies and facilitating discussions throughout an iterative and continuous planning process. With TMIP-EMAT, analysts, stakehoders and policymakers can explore key relationships between model inputs and outputs using interactive tools, study the range in outcomes to highlight that uncertainties exist in these relationships, and use the results to inform a robust decisionmaking approach.

### Scoping for Exploratory Modeling Analysis:

The first step in an exploratory modeling analysis is the scoping step, which defines the goals and objectives of the analysis, as well as more specifically how those goals and objectives will be explored using the model. Several key components are necessary in the scoping step:

- **Develop High-Level Scope Goals**: The first step in the scoping process is to define the goals and objectives for doing the analysis and translate those into to policies that could support those goals and identify the uncertainties that could affect meeting the policies’ ability to meet the goals. These goals need not be overly specific, but should define a set of high-level objectives to explore using the model.
- **Identify Model Functionality**. In this step, the scoping goals are matched against the inputs and sensitivities of the core model along with potential performance measures. Inputs and sensitivities include both exogenous inputs, or uncertainty variables, that policymakers have little or no control over (e.g., fuel price) and endogenous policies, referred to as policy levers (e.g., tolls or transit fares). Performance measures are outputs of the model that can be used to assess how well goals and objectives are met based upon the set of policy options that are explored during the exploratory modeling analysis.
- **Finalize Scope**. The set of uncertainties, policy-levers, and performance measures is assessed on the basis of priorities, as well as the functionality of the model and then finalized. There is a number of limiting factors that may prevent the full set of desired uncertainties, policy levers, and performance measures to be included within the final scope.

### High - Level Scoping

The first step of the scoping process is a high-level scoping exercise, which is intended to get agency planners and modelers thinking about the goals and objectives of the analysis and what sets of policies, strategies, and uncertainties would be of interest in relation to those goals and objectives. Rather than limiting the exercise based upon the capabilities of a specific core model, this step involves thinking more broadly about the goals and objectives.

In the context of TMIP-EMAT, a goal is what the community is trying to accomplish. Some examples of common goals used in the TMIP-EMAT process include the following:
- Increase transit ridership.
- Reduce congestion and improve reliability.
- Understand telecommuting effects on sprawl.
- Improve economic opportunities and access in economically disadvantaged neighborhoods.
- Reduce auto usage in the suburbs.
- Understand future impacts of automated vehicles.
- Improve financial stability of transportation system through tolls/managed lanes.
- Improve freight movements.
The specific goals of the analysis help to define other parameters of the analysis as well. For instance, in some cases the goals dictate the examination of a set of policies in conjunction with uncertainties, while in other cases, the analysis may be purely exploratory, examining effects of uncertainty only.
The choice of goals impacts this decision. For instance, if a goal is to reduce congestion, it would make sense to formulate policy levers that have a chance of impacting future levels of congestion (e.g., pricing, highway expansion project, improvements to transit service, or other congestion management policies). Often multiple policy levers are considered that may each have different impacts on the set of goals. Conversely, if a goal is to better understand the impacts of automated vehicles, then policy levers may not be of interest since there is no clear objectives for impacting the system performance. In this case, an uncertainty driven analysis may be warranted.
In some cases, the goals dictate the examination of a set of policies in conjunction with uncertainties, while in other cases, the analysis may be purely exploratory, examining effects of uncertainty only

### Identify Model Functionality

Once the high-level scoping exercise is complete, it is necessary to identify the specific set of uncertainties and policy levers that will be tested and define how the uncertainties and policy levers are defined within the travel model. We define uncertainties and policy levers as follows:
- **Uncertainties**. Uncertainties are factors outside the decisionmaker’s control that may have an effect on performance measures and may help or hinder the ability of policy levers to reach stated goals. Some examples of uncertainties are as follows:
    − Fuel prices.
    − Values of time.
    − Land use and demographics changes.
    − Impacts of automated vehicles.
    − Behavior-related sensitivities of the model.
    − Telecommuting levels.
- **Policy Levers**. Policy levers are factors within the decisionmaker’s control that are implemented to help reach a defined goal or goals. Examples of policy levers include the following:
    − Highway capacity expansion.
    − Transit service changes.
    − VMT charge, tolls, and managed lanes.
    − Parking pricing.
    − Travel demand management strategies.
    − User-specific travel cost changes (e.g., transit subsidies for low-income population).
    − Land use policy (e.g., infill development).

As part of identifying the uncertainties and policy levers to include in the analysis is translating the policy levers and uncertainties from high-level concepts (e.g., impacts of autonomous vehicles) to adjustable model inputs or parameters (e.g., allowable vehicle spacing or capacity on a highway). The representation of each uncertainty or policy lever may include a combination of input variables and parameters to appropriately represent the lever or factor within the model.

An important component of this exercise is analyzing the model functionality. For instance, if the existing model does not have a mode choice component, testing policies around the impacts of added transit service would require large changes to the underlying core model to be tested effectively. Conversely, a model that includes auto operating costs as an input can easily test the impacts of changes to fuel prices. Examples of matching specific goals with policy levers and uncertainties are given later in this section.

In addition to the selection of uncertainties and policy levers, the scoping process also must define the range of each input to the model. Since these represent the inputs to the model that will be varied in the analysis, careful attention to these ranges is important as they will drive the results of the analysis. Some policy levers are simple binary variables—either the policy is enacted or not. Other policy levers and uncertainty variables are continuous variables that require careful consideration and review of other sources to arrive at a reasonable set of ranges.
The scoping exercise also must identify key performance measures that can be used to evaluate the efficacy of policies and the extent to which goals of the analysis are achieved. Again, performance measures should be tied to the specific goals of the analysis, and the performance measures should be outputs from the core model (or metrics that can be derived from the results of the core model). Examples of performance measures that might be used in an exploratory modeling analysis include the following:
- VMT (by vehicle class, speed, area, etc.).
- Transit ridership.
- Mode share.
- Travel times for specific roadways or corridors.
- Congestion and reliability measures.
- Economically disadvantaged population measures, such as travel times or accessibility.
- Revenue generated.

### Finalize Scope

An important component to the process is performing sensitivity tests to isolate how individual policy levers and uncertainties impact the key performance measures being considered. Performing such tests is important to do before finalizing the scope for the analysis. If an uncertainty or policy lever, as it is coded in the model, has little impact on the performance measures of interest, it may not be worthwhile including in the analysis since there is an opportunity cost associated with each policy lever and uncertainty. For each policy lever and uncertainty that are included, the experimental design will typically increase by about 10 full model runs. By determining when a policy lever or uncertainty is unimportant, the analysis can either replace that policy lever or uncertainty with another more impactful one, or remove it and reduce the number of full model runs required.

The final number and set of policy levers and uncertainties that can be included in the application is dependent on the chosen core model(s) run times, the computer resources available, and schedule constraints for project analysis. As a rule of thumb, for meta-model development, 10 core model runs need to be run for each uncertainty and policy lever. Therefore, if there are 4 uncertainties and 4 policy levers, then the core model will need to be run 80 times. In addition, other model set-up constraints, such as number of individual highway networks that need to be coded, may dictate the number and set of policy levers that can be feasibly developed.

### When VisionEval is Core Model in TMIP-EMAT

TMIP-EMAT is a methodological approach for exploratory modeling and analysis designed to integrate existing transportation models, including `VisionEval`, to perform exploratory analysis of a range of possible scenarios. It offers several features that enhance the functionality of underlying core models like `VisionEval` for exploratory analysis. The parameters in TMIP-EMAT can be used to scope the input variables of VisionEval, and Measures to scope its output variables. Considering the characteristics and limitations of VisionEval, the type of variables that can be effectively used for experiment scoping in TMIP-EMAT include the following:

### **Parameters (Scoping VisionEval Inputs)**:

- **Policy Levers**: These represent the policy choices or interventions that can be explored. Given VisionEval's focus on policy analysis, variables that directly correspond to policy adjustments within VisionEval's input files can be used. Examples from the VisionEval User Guide include: 
    - **Pricing strategies**: Fuel and electricity costs, road cost recovery mechanisms (registration fees, gas taxes, VMT fees), parking pricing policies.
    - **Transportation operations actions**: Transit service levels (service miles by mode), road lane-miles, ITS operations (ramp metering, signal optimization), Eco-Drive program participation.
    - **Land use policies**: Assumptions about development density, shares of households in mixed-use areas.
    - **Demand management programs**: Participation rates in TDM programs (both home and work-based).
    - **Vehicle and fuel characteristics**: Assumptions about the future vehicle fleet composition (e.g., percentage of light trucks, vehicle age, adoption rates of different powertrain technologies like EVs and PHEVs).

- **Exogenous Uncertainties**: These represent future conditions or factors outside of direct policy control that could influence the outcomes. VisionEval is designed to explore a range of possible future conditions, so suitable parameters could include: 
    - **Demographic projections**: Population growth, household size, age distribution, per capita income.
    - **Economic conditions**: Factors influencing economic growth, which might affect travel behavior and other inputs.
    - **Technology deployment**: Uncertainty in the rate and extent of adoption of new transportation technologies like autonomous vehicles or ride-hailing services.
    - **Fuel prices**: Variations in the cost of gasoline, diesel, and electricity.

### **Measures (Scoping VisionEval Outputs)**:

These would correspond to the performance metrics that VisionEval calculates and reports. TMIP-EMAT can be used to explore the sensitivity of these measures to the variations in the input parameters. Examples from the VisionEval User Guide include:

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

