# script to help prepare PM2.5 input data required for ITHIM

import math
import numpy as np
import pandas as pd
import geopandas as gpd

from pathlib import Path


def select_best_utm_projection(gdf):

    # calculate longitude of centroid of union of all geometries in gdf
    avg_lng = gdf["geometry"].unary_union.centroid.x

    # calculate UTM zone from avg longitude to define CRS to project to
    utm_zone = math.floor((avg_lng + 180) / 6) + 1
    utm_crs = f"+proj=utm +zone={utm_zone} +ellps=WGS84 +datum=WGS84 +units=m +no_defs"

    return utm_crs


## parameters
# pm data can be obtained for https://wustl.app.box.com/v/ACAG-V5GL04-GWRPM25/folder/230744006317
# and converted to shapefile using https://wustl.app.box.com/s/9073l0k8go8kehtxd5ok46dmw1q63oav or similar
YEAR = 2021  # pm data year
GEOMETRY_FILE = "tl_2021_41_bg.shp"
GEOMETRY_XWALK = "bzone_cbg.csv"
PM_FILE = "pm.parquet"  # gis file (in this case, geoparquet) containing PM2.5 concentrations for study region

# directories
module_dir = Path(__file__).parent.parent
input_dir = module_dir.joinpath("data", "pm")
geo_dir = module_dir.joinpath("data", "geo")
output_dir = module_dir.joinpath("inst", "extdata")

# first, we need to establish geometry for the study region
# for SKATS, this means using the census block group -> taz crosswalk file
oregon_cbgs = gpd.read_file(geo_dir.joinpath(GEOMETRY_FILE))
oregon_cbgs["GEOID"] = oregon_cbgs.GEOID.astype(np.int64)

# and subset to study area
bzone_cbgs = pd.read_csv(geo_dir.joinpath(GEOMETRY_XWALK))
keep = oregon_cbgs.GEOID.isin(bzone_cbgs.GEOID)
oregon_cbgs = oregon_cbgs[keep].copy()

# find and apply best projection
projected_crs = select_best_utm_projection(oregon_cbgs)
oregon_cbgs = oregon_cbgs.to_crs(projected_crs)
oregon_cbgs["cbg_area"] = oregon_cbgs.area

# first, join PM estimates to cbgs, then allocate to bzones based on crosswalk
pm = gpd.read_parquet(input_dir.joinpath(PM_FILE))
pm = pm.explode(ignore_index=True, index_parts=False).to_crs(projected_crs)
if not pm.has_sindex:
    pm.sindex

# interesect pm, cbg estimates
pm_cbg = pm.sjoin(oregon_cbgs, how="inner")

# rename geometry columns
pm_cbg = pm_cbg.rename(columns={"geometry": "joined_geometry"})

# merge cell geometry so we can calculate intersecting area
pm_cbg = pd.DataFrame(pm_cbg).merge(oregon_cbgs[["geometry"]],
                                    left_on="index_right",
                                    right_index=True)
pm_cbg = pm_cbg.rename(columns={"index_right": "cbg_id"})

# geopandas intersecton 
# requires two GeoSeries, align=False performs row-wise intersection
pm_geo = gpd.GeoSeries(pm_cbg.joined_geometry)
cbg_geo = gpd.GeoSeries(pm_cbg.geometry)
pm_cbg["intersected_geometry"] = pm_geo.intersection(cbg_geo, align=False)
pm_cbg["intersection_area"] = gpd.GeoSeries(pm_cbg.intersected_geometry).area

# now, we can spatially average PM cocentrations for cbgs
pm_cbg["weighted_pm"] = pm_cbg["GWRPM25"] * pm_cbg["intersection_area"]
pm_cbg = pm_cbg.groupby("GEOID").agg(
    pm=("weighted_pm", "sum"),
    area=("intersection_area", "sum")
)
pm_cbg["pm"] = pm_cbg.pm / pm_cbg.area

# join to oregon_cbgs
oregon_cbgs = oregon_cbgs.set_index("GEOID")
oregon_cbgs = oregon_cbgs.join(pm_cbg)

# and use crosswalk to join to bzones
bzone_cbgs = bzone_cbgs.merge(oregon_cbgs[["pm"]], on="GEOID")
bzone_cbgs["weighted_pm"] = bzone_cbgs["pm"] * bzone_cbgs["pct_bzone"]
bzone_cbgs = bzone_cbgs.groupby("Bzone").agg(
    pm=("weighted_pm", "sum"),
    pct_area=("pct_bzone", "sum")
)
bzone_cbgs["PM25"] = bzone_cbgs.pm / bzone_cbgs.pct_area

# write bzone pm estimates to disk
# but first, align schema as required
bzone_cbgs["Geo"] = bzone_cbgs.index  # bzone ID is currently index
bzone_cbgs["Year"] = YEAR
write_cols = ["Geo", "Year", "PM25"]
bzone_cbgs[write_cols].to_csv(output_dir.joinpath("bzone_pm.csv", index=False))