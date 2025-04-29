library(raster)
library(rasterVis)
library(ncdf4)
library(lattice)
library(terra)

# load nc file 
input_nc = 'C:/VE-ITHIM/pm_annual/V5GL04.HybridPM25.NorthAmerica.202201-202212.nc'
t1 = terra::rast(input_nc)
names(t1)
poly = as.polygons(t1, round=FALSE, aggregate=FALSE)

# Change the Input path.
varname = 'GWRPM25'
nc2raster = raster(input_nc, varname = varname, band = 1)

#To output a quick view for the dataset
png("C:\\VE-ITHIM\\plot2022.png",
    height = 15,
    width = 20,
    units = 'cm',
    res = 1000)

print(levelplot(nc2raster))
dev.off()

#Change the output path to save Geotif data.
nc2raster = stack(input_nc,varname = varname)
output = 'C:\\VE-ITHIM\\2022.tif'
writeRaster(nc2raster,output,format = 'GTiff',overwrite = TRUE)

