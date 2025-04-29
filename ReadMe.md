# TMIP-EMAT and VisionEval 3.0

The repository hosts the [TMIP-EMAT](https://tmip-emat.github.io/) framework that is used to run ODOT VE models built in [VisionEval 3.0](https://visioneval.org/). 
It also includes Oregon-specific additional packages which contains specialized model variants of VisionEval.

## Structure
There are six directories contained in the repository:

1. **EMAT-Conda-Setup** - The directory contains the yaml file *emat_install.yml* that can be used to create an emat conda environment. To create the environment use the command
```
conda env create -f emat_install.yml
```
2. **EMAT-VE-Configs** - The directory contains two yaml files. The yaml file *ve-model-config.yml* is used to specify VE model configurations and the yaml file *odot-otp-scope.yml* is used to
specify the scope i.e. the design elements of the experiments along with the measures that should be collected from a model run.
3. **EMAT-VE-Database** - The directory will store the database that TMIP-EMAT will use to run the experiments and store the results.
4. **ODOT_VE_Extras** - The directory contains Oregon's specialized variants of VisionEval.
5. **Scenario-Inputs/OTP** - This directory contains scenario input files in sub-directories for each experiment parameter defined by the scope in *odot-otp-scope.yml*.
6. **Temporary** - TMIP-EMAT creates a temporary directory to run experiments. This directory is used as a host for those temporary directories to make post TMIP-EMAT run cleanup easy.


In addition to the directories the repository contains following files in the root directory:
1. *emat_ve_wrapper.py* - The python script that defines how TMIP interfaces with VisionEval models, setup scenarios, run scenarios, and collect results.
2. *extract_outputs.R* - R script used with the VE model to extract the measures as defined in the scope *odot-otp-scope.yml*.
3. *ODOT-TMIP-METAMODEL.ipynb* - The jupyter python notebook used to run and visualize TMIP-EMAT experiments.
4. *metamodel_variables.csv* - This file contains a list (partial or complete) of variables collected from model runs to build the metamodel for.

## Setup Requirements

The TMIP EMAT operates in python and interfaces with VisionEval. Thus, all the software requirements needed for [TMIP-EMAT](https://tmip-emat.github.io/source/emat.install.html) and [VisionEval 3.0](https://visioneval.org/docs/getting-started.html#installation) should be met.  

## Example: Setup ODOT TMIP EMAT Integration

1. Build the 'VisionEval' runtime enviornment: 
	-	Clone the repository located at [https://github.com/ORScenPlg/VisionEval-Dev](https://github.com/ORScenPlg/VisionEval-Dev) to a server or local machine. I'll assume the location of the clone is C:\VisionEval-Dev.

	-	Navigate to C:\VisionEval-Dev and double click the VisionEval-dev.Rproj. This will open RStudio. Make sure that the version of R on your machine is not higher than v4.3.1.
	
	-	Run the command “ve.build()”. This will build a runtime environment in “C:\VisionEval-Dev\built\visioneval\4.3.1\runtime”

2. Install ODOT Extra packages:
	-	Clone [https://github.com/tmip-emat/ve-integration/tree/docs](https://github.com/tmip-emat/ve-integration/tree/docs) repository on a server or local machine. I’ll assume the location of the clone is C:\ve-integration
	
	-	Navigate to C:\ve-integration\ODOT_VE_Extras, double click setup.bat, and follow the prompts. 

   	Prompts:

	-	For R prompt choose the version used to build VisionEval runtime environment (in the instructions above 4.3.1). For e.g. C:\Program Files\R\R-4.3.1.

	-	If you select "n", it asks for the visioneval library prompt choose the visioneval library built. From instructions above it is “C:\VisionEval-Dev\built\visioneval\4.3.1\ve-lib”

	-	Install the modules

   
	Notes: RStudio to Install Packages

	When choosing the modules, choose to install all modules. Ideally this should install all the modules but for the very first time it might fail. This is because the work from home (WFH) and the multimodal modules require additional R libraries that are not installed during the VisionEval build. If this step fails then:

	-	Verify that “.Renviron” file is present in the “C:\ve-integration\ODOT_VE_Extras” directory. If not then:  double click “setup.bat” in “C:\ODOT_VE_Extras” and choose “n” for installation. On the visioneval library prompt enter C:\VisionEval-Dev\built\visioneval\4.3.1\ve-lib. This will create the write "".Renviron” file.

	-	Double click on VisionEval-dev.Rproj in “C:\ve-integration\ODOT_VE_Extras” directory. This will open RStudio and set the library to the one specified in “.Renviron” file. Install the missing dependencies using R command “install.packages”

	-	Install the modules using R command “install.packages”. Here’s an example to install multimodal module – “*install.packages(“VEStateVariants”, type=”source”, repos=NULL)*”. The additional arguments are necessary when installing modules from a local source.  ***Note***: If you are re-installing a package sometimes the build process fails to overwrite existing packages in the ve-lib built runtime. Sometimes it is helpful to delete the package that is being overwritten before re-installing.  

3. Install and Run VE-State Full OTP model

	-	After successful installation of all the modules from ODOT_VE_Extras navigate to “C:\VisionEval-Dev\built\visioneval\4.3.1\runtime” and double click     VisionEval-dev.Rproj. This will open RStudio and setup visioneval environment and give access to odot models.
	-	Enter the R command “odotmm-dlmodel <- installModel(“VE-State”,“odotmm-dl”, confirm=FALSE)”. This will install the Full VE-State model with the MM and AP22 powertrain and AP inputs.
	-	Enter the R command “odotmm-dlmodel$run()”. To run the model.

	Following variants of VE-State models are available

	| name       | Powertrain | Travel Demand | Driverless | Full variant name | Scripts            | Inputs            |
	| ---------- | ---------- | ------------- | ---------- | ----------------- | ------------------ | ----------------- |
	| wfh-sld-dl | AP22       | WFH           | DL         | odot-wfh-sld-dl   | scripts-wfh-sld-dl | inputs-wfh-sld-dl |
	| mm-ap22    | AP22       | 2017 MM       | -          | odotmm-AP22       | scripts-AP22-mm    | inputs-AP22       |
	| AP22-wfh   | AP22       | WFH           | -          | odotmm-AP22-wfh   | scripts-AP22-wfh   | inputs-AP22       |
	| WFH-STS    | STS        | WFH           | -          | odotWFH-STS       | scripts-wfh-sts    | inputs-wfh-STS    |
	| STS        | STS        |               |            | odot-STS          | scripts-orig-STS   | inputs-STS        |
	| mm-dl      | AP22       | 2017 MM       | DL         | odotmm-dl         | scripts-mm-dl      | inputs-mm-dl      |

4. EMAT-Conda setup for running the ‘odot_otp_round1’

	-	Upon completion of the base year model run, we set up the ‘emat’ environment by navigating to the ‘C:\ve-integration\EMAT-Conda-Setup’ directory.

	- Using anaconda prompt, create a new environment called ‘emat’ with all the essential libraries for running EMAT.
	`conda env create -f emat_install.yml`


4. Run the scenarios

	-	Open Anaconda3 command prompt and activate the *emat* environment.
	-	Navigate to the TMIP-EMAT directory **C:\ve-integration**.
	-	Enter the command `jupyter notebook` and press *Enter*. This will open a jupyter notbook in a browser and list all the files contained in the **C:\ve-integration** directory.
	-	Within the jupyter notebook navigate to **C:\ve-integration\EMAT-VE-Configs** directory and edit the following parameters in the *ve-model-config.yml*:
		-	*base-model*: This is the path to the model run that contains the datastore for base year. EMAT uses this model to load the results in all the model runs.
		-	*r_library_path*: This is the path to VisionEval R library that will be used to run all the VE models.
		-	*r_runtime_path*: This is the path to VisionEval runtime environment directory.
		-	*r_executable*: This is the location of **R** executable that will be used to run VE models.

	-	Click on *ODOT-TMIP-METAMODEL.ipynb*. This will open the jupyter notbook.
	-	Check the values of following parameters in the **Cell Block 2**:
		-	*run_experiments*: It's a logical value that determines whether to run multiple scenarios (**True**) or load the results from the database (**False**).
		-	*database_name*: A character value that tells the name of the database. If one doesn't exists then the notebook will create one. Note that if the notebook is creating the database then it cannot load results and the run_experiments should be set to True.
		-	*model_scope_name*: A character value that indicates the name of the model scope file that should be used to design the experiments.
		-	*num_workers*: An integer value that specifies the number of parallel processors to use to run scenarios.
		-	*num_experiments*: An integer value that specifies the number of scenarios to create.
	- 	Run the remianing cells of the jupyter notebook to run the scenarios and visualize the results. 

