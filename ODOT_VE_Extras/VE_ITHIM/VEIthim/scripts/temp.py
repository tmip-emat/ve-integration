import math
import numpy as np
import pandas as pd
import geopandas as gpd

from pathlib import Path

outputs = Path(r"C:\Users\theodore.mansfield\VisionEval-Extras\VEIthim\models\VERSPM-scenarios\results\output\VERSPM-scenarios_CSV_202402231250")
all_files = list(outputs.glob("ithim_Bzone_*.csv"))
mort_cols = [
    "deaths_pa_ap_all_cause", "deaths_ap_copd", "deaths_pa_ap_diabetes",
    "deaths_pa_colon_cancer", "traffic_deaths"
]
yll_cols = [
    "ylls_pa_ap_all_cause", "ylls_ap_copd", "ylls_pa_ap_diabetes",
    "ylls_pa_colon_cancer", "traffic_ylls"
]

# isolate 2021, 2050 death files
files_2050 = [file for file in all_files if file.name.endswith("2050.csv")]
deaths_2050 = [file for file in files_2050 if "mortality" in file.name]

res_2050_mort = []
for file in deaths_2050:
    scenario = file.name.split("VE-")[-1].split("-mortality")[0]
    chunk = pd.read_csv(file)
    chunk = pd.DataFrame(chunk[mort_cols].sum())
    chunk.columns = [scenario]
    res_2050_mort.append(chunk)
res_2050_mort = pd.concat(res_2050_mort, axis=1)

# and ylls
ylls_2050 = [file for file in files_2050 if "ylls" in file.name]
res_2050_yll = []
for file in ylls_2050:
    scenario = file.name.split("VE-")[-1].split("-ylls")[0]
    chunk = pd.read_csv(file)
    chunk = pd.DataFrame(chunk[yll_cols].sum())
    chunk.columns = [scenario]
    res_2050_yll.append(chunk)
res_2050_yll = pd.concat(res_2050_yll, axis=1)

res_2050_mort.to_csv(outputs.joinpath("res_2050_mort.csv"))
res_2050_yll.to_csv(outputs.joinpath("res_2050_yll.csv"))