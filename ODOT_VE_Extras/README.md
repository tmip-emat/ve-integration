# ODOT VisionEval Extras
This repo is for additional, Oregon specific, VE packages, modules, and model variants. 
The *setup.bat* script allows user to either install the modules that are available for VE 3.0 or 
setup the *.Renviron* to point to the right VE library so that users can run RStudio from this directory.
The setup script can install all the modules in the visioneval library provided dependencies are already
installed. If the installation is unsuccessful then it is recommend for users to start RStudio and install
the dependencies and the packages manually. The library path to visioneval library should be set when the *setup.bat* script is run.



**Here is the process for getting a model variant up and running:**

<u>Model variant</u>: “odot-mm-AP22”  

<u>Assumptions</u>: VE-State model (I’ll assume that git, RStudio, R v4.3.1, and Rtools v4.3 are installed on the machine):



Build a runtime VisionEval

1. Clone [https://github.com/ORScenPlg/VisionEval-Dev](https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Fgithub.com%2FORScenPlg%2FVisionEval-Dev&data=05|01||38662f3aab6a4170ec8208db9e5cc866|93676b1f90394fea97dbdde5da5b29fa|0|0|638277893578191818|Unknown|TWFpbGZsb3d8eyJWIjoiMC4wLjAwMDAiLCJQIjoiV2luMzIiLCJBTiI6Ik1haWwiLCJXVCI6Mn0%3D|3000|||&sdata=OJ%2BCHGmqUSad6EqqY44xNPVib%2B1Xj4t%2BWZW6RNcZazo%3D&reserved=0)     repository on a server or local machine. I’ll assume the location of the clone is C:\VisionEval-Dev
2. Navigate to C:\VisionEval-Dev and double click the VisionEval-dev.Rproj. This will open RStudio. Make sure that the version of R on your machine is not higher than v4.3.1.
3. Run the command “ve.build()”. This will build a runtime environment in “C:\VisionEval-Dev\built\visioneval\4.3.1\runtime”

Install ODOT Extra packages:

1. Clone [https://github.com/tmip-emat/ve-integration/tree/docs](https://github.com/tmip-emat/ve-integration/tree/docs) repository on a server or local machine. I’ll assume the location of the clone is C:\ve-integration

2. Navigate to C:\ve-integration\ODOT_VE_Extras, double click setup.bat, and follow the prompts. 

   Prompts:

   a. For R prompt choose the version used to build VisionEval runtime environment (in the instructions above 4.3.1). For      e.g. C:\Program Files\R\R-4.3.1.

   b. If you select "n", it asks for the visioneval library prompt choose the visioneval library built. From instructions above it is “C:\VisionEval-Dev\built\visioneval\4.3.1\ve-lib”

   

   RStudio to Install Packages

   1. When choosing the modules, choose to install all modules. Ideally this should install all the modules but for the very first time it might fail. This is because the work from home (WFH) and the multimodal modules require additional R libraries that are not installed during the VisionEval build. 
      1. If this step fails then:

​                     i.  Verify that “.Renviron” file is present in the “C:\ODOT_VE_Extras” directory. If not then:  double click “setup.bat” in “C:\ODOT_VE_Extras” and choose “n” for installation. On the visioneval library prompt enter C:\VisionEval-Dev\built\visioneval\4.3.1\ve-lib. This will create the write "".Renviron” file.

​                     ii.  Double click on VisionEval-dev.Rproj in “C:\ODOT_VE_Extras” directory. This will open RStudio and set the library to the one specified in “.Renviron” file. Install the missing dependencies using R command “install.packages”

​                    iii.  Install the modules using R command “install.packages”. Here’s an example to install multimodal module – “*install.packages(“VEStateVariants”, type=”source”, repos=NULL)*”. The additional arguments are necessary when installing modules from a local source.  ***Note***: If you are re-installing a package sometimes the build process fails to overwrite existing packages in the ve-lib built runtime. Sometimes it is helpful to delete the package that is being overwritten before re-installing.  

 

Install and Run VE-State Full OTP model

1. After successful installation of all the modules from ODOT_VE_Extras navigate to “C:\VisionEval-Dev\built\visioneval\4.3.1\runtime” and double click     VisionEval-dev.Rproj. This will open RStudio and setup visioneval environment and give access to odot models.
2. Enter the R command “odotmmAP22model <- installModel(“VE-State”,“odotmm-AP22”, confirm=FALSE)”. This will install the Full VE-State model with the MM and AP22 powertrain and AP inputs.
3. Enter the R command “odotmmAP22model$run()”. To run the model.

 






## Oregon Model Variants



### VE-State

Install the VEStateVariants package. Within that package there are the following variants of VE-State models

| name       | Powertrain | Travel Demand | Driverless | Full variant name | Scripts            | Inputs            |
| ---------- | ---------- | ------------- | ---------- | ----------------- | ------------------ | ----------------- |
| wfh-sld-dl | AP22       | WFH           | DL         | odot-wfh-sld-dl   | scripts-wfh-sld-dl | inputs-wfh-sld-dl |
| mm-ap22    | AP22       | 2017 MM       | -          | odotmm-AP22       | scripts-AP22-mm    | inputs-AP22       |
| AP22-wfh   | AP22       | WFH           | -          | odotmm-AP22-wfh   | scripts-AP22-wfh   | inputs-AP22       |
| WFH-STS    | STS        | WFH           | -          | odotWFH-STS       | scripts-wfh-sts    | inputs-wfh-STS    |
| STS        | STS        |               |            | odot-STS          | scripts-orig-STS   | inputs-STS        |
| mm-dl      | AP22       | 2017 MM       | DL         | odotmm-dl         | scripts-mm-dl      | inputs-mm-dl      |



**Oregon AP2022** (mm-ap22)

*VEStateVariants/inst/models/visioneval-odotmm-AP22.cnf*

- 2017 Multimodal Module
- AP22 powertrain
- AP22 inputs

**Oregon WFH AP2022** (AP22-wfh)

*VEStateVariants/inst/models/visioneval-odot-AP22-wfh.cnf*

- Work from Home Module (includes 2017 Multimodal Module)
- AP22 powertrain
- AP22 inputs

**Oregon MultiModal and Driverless with AP2022** (mm-dl)

*VEStateVariants/inst/models/visioneval-odotmm-dl.cnf*

- 2017 Multimodal Module
- Driverless module
- AP22 powertrain
- AP22 inputs



**Oregon Work From Home, Driverless, with SLD Capping** (wfh-sld-dl)

*VEStateVariants/inst/models/visioneval-odot-wfh-sld-dl.cnf*

- SLD Capping for D1B and D34. A new input file (“marea_max_sld_variables.csv”) is required to provide the "cap" based on SLD values. 
- Work from Home Module (includes 2017 Multimodal Module)
- Oregon Driverless Modules (VEHouseholdVehiclesDL, VESimLandUseDL, VETravelPerformanceDL)
- AP22 powertrain
- AP22 inputs

**Oregon Work from Home, STS** (WFH-STS)

*VEStateVariants/inst/models/visioneval-odotwfh-STS.cnf*

- Work from Home Module (includes 2017 Multimodal Module)
- STS powertrain
- STS inputs

**Oregon STS** (STS)

*VEStateVariants/inst/models/visioneval-odot-STS.cnf*

- STS powertrain
- STS inputs










