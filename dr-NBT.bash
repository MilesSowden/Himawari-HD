#!/bin/bash

# === Setup ===
EPSG="EPSG:4326"

# NSW study
#EXTENT="-te 149 -36 151 -34"
#SCRATCH="/mnt/d/scratch/nsw"
#OUTDIR="/mnt/d/himawari/interp/nsw"
#DATADIR="/mnt/d/himawari/2019/12/10"

#Hanoi study 2019
#EXTENT="-te 103.8 19.0 107.8 23.0"  # 4x4
#SCRATCH="/mnt/d/scratch/Vietnam"
#OUTDIR="/mnt/d/himawari/interp/Vietnam"
##DATADIR="/mnt/d/himawari/2024/11/01"
#DATADIR="/mnt/d/himawari/2019/12/10"

#Hanoi study 2024
EXTENT="-te 103.8 19.0 107.8 23.0"  # 4x4
SCRATCH="/mnt/d/scratch/hanoi"
OUTDIR="/mnt/d/himawari/interp/hanoi"
DATADIR="/mnt/d/himawari/2024/11/01"
#DATADIR="/mnt/d/himawari/2019/12/10"


mkdir -p "$SCRATCH" "$OUTDIR"

# === Band configuration ===
declare -A band_res=( ["01"]="0.01" ["02"]="0.01" ["03"]="0.005" ["04"]="0.01" ["05"]="0.02" ["06"]="0.02" ["07"]="0.02" ["08"]="0.02" ["09"]="0.02" ["10"]="0.02" ["11"]="0.02" ["12"]="0.02" ["13"]="0.02" ["14"]="0.02" ["15"]="0.02" ["16"]="0.02" )
bands=(01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16)
red_band="03"

# Clean scratch directory
rm -f $SCRATCH/*

for hour in $(seq -w 00 23); do
  hhmm="${hour}00"
  echo "🕒 Processing time $hhmm"

  # === Step 1: Red band resamples ===
red_in=$(find "$DATADIR/${hhmm}" -name "*_OBS_B${red_band}-PRJ_GEOS141_*" | head -n 1)
has_red=true
if [[ ! -f "$red_in" ]]; then
  echo "⚠️ Missing red band at $hhmm – using fallback logic"
  has_red=false
else
  cdo -s -f nc setmisstoc,0 -selname,chan* "$red_in" "$SCRATCH/B${red_band}_${hhmm}_raw.nc"
  for res in 0.005 0.01 0.02; do
    gdalwarp -q -t_srs $EPSG $EXTENT -tr "$res" "$res" -r cubic "$SCRATCH/B${red_band}_${hhmm}_raw.nc" "$SCRATCH/B${red_band}_${hhmm}_${res}.nc"
  done
  rm -f "$SCRATCH/B${red_band}_${hhmm}_raw.nc"
fi

  
# === Step 2A: VIS bands copy ===
for band in 01 02 04 05 06; do
  input=$(find "$DATADIR/${hhmm}" -name "*_OBS_B${band}-PRJ_GEOS141_*" | head -n 1)
  [[ ! -f "$input" ]] && echo "⚠️ Missing B$band at $hhmm" && continue
  cdo -s -f nc selname,chan* "$input" "$SCRATCH/B${band}_${hhmm}_proc.nc" &
done

# === Step 2B: NBT conversion (IR bands only) ===
for band in 07 08 09 10 11 12 13 14 15 16; do
  input=$(find "$DATADIR/${hhmm}" -name "*_OBS_B${band}-PRJ_GEOS141_*" | head -n 1)
  [[ ! -f "$input" ]] && echo "⚠️ Missing B$band at $hhmm" && continue
  cdo -s divc,100 -subc,273.15 -selname,chan* "$input" "$SCRATCH/B${band}_${hhmm}_proc.nc" &
done
wait	#wait for all processsing to finish all 16 bands must stop here

# === Step 3: Warp all bands in parallel ===
for band in "${bands[@]}"; do
  [[ "$band" == "$red_band" ]] && continue
  input="$SCRATCH/B${band}_${hhmm}_proc.nc"
  native_res="${band_res[$band]}"
  gdalwarp -q -t_srs $EPSG $EXTENT -tr "$native_res" "$native_res" -r near "$input" "$SCRATCH/B${band}_${hhmm}_native.nc" &
  gdalwarp -q -t_srs $EPSG $EXTENT -tr 0.005 0.005 -r cubic "$input" "$SCRATCH/B${band}_${hhmm}_interp.nc" &
done
wait
rm -f "$SCRATCH/B??_${hhmm}_proc.nc"	#we don't need the large domain anymore

  # === Step 4: Enhancement ===
if $has_red; then
  # Red is present: do enhancement by delta
  for band in "${bands[@]}"; do
    [[ "$band" == "$red_band" ]] && continue
    cdo -s sub "$SCRATCH/B${band}_${hhmm}_native.nc" "$SCRATCH/B${red_band}_${hhmm}_${band_res[$band]}.nc" "$SCRATCH/B${band}_${hhmm}_delta.nc" &
  done; wait 
  
  cp "$SCRATCH/B03_${hhmm}_0.005.nc" "$SCRATCH/B03_${hhmm}_interp.nc"
  cp "$SCRATCH/B03_${hhmm}_0.005.nc" "$SCRATCH/B03_${hhmm}_enhanced.nc"

  for band in "${bands[@]}"; do
    [[ "$band" == "$red_band" ]] && continue
    gdalwarp -q -t_srs $EPSG $EXTENT -tr 0.005 0.005 -r cubic "$SCRATCH/B${band}_${hhmm}_delta.nc" "$SCRATCH/B${band}_${hhmm}_delta_interp.nc" &
  done; wait 
  
  for band in "${bands[@]}"; do
    [[ "$band" == "$red_band" ]] && continue
    cdo -s add "$SCRATCH/B${red_band}_${hhmm}_0.005.nc" "$SCRATCH/B${band}_${hhmm}_delta_interp.nc" "$SCRATCH/B${band}_${hhmm}_enhanced.nc" & 
  done; wait 
  rm -f "$SCRATCH/B*_${hhmm}_delta.nc" "$SCRATCH/B*_${hhmm}_delta_interp.nc"
  
else
  # Red is missing: enhancement is simply scaling
  for band in "${bands[@]}"; do
    [[ "$band" == "$red_band" ]] && continue
    gdalwarp -q -t_srs $EPSG $EXTENT -tr 0.005 0.005 -r cubic "$SCRATCH/B${band}_${hhmm}_native.nc" "$SCRATCH/B${band}_${hhmm}_enhanced.nc" &  
  done; wait 
  
  for band in "${bands[@]}"; do
    [[ "$band" == "$red_band" ]] && continue
    cp "$SCRATCH/B${band}_${hhmm}_enhanced.nc" "$SCRATCH/B${band}_${hhmm}_interp.nc" & 
  done; wait 
fi

# === Step 5: Export TIFs ===
for band in "${bands[@]}"; do
  if [[ "$band" -lt 07 ]]; then
    scale_min=-0.1
    scale_max=0.4	#theoretically 1 but give more weight to non cloud
  else
    scale_min=-0.5	#not sure bounds -1.5 to 1? allow saturation fire or cloud top
    scale_max=.5
  fi

  gdal_translate -q -ot Byte -scale $scale_min $scale_max 0 255 "$SCRATCH/B${band}_${hhmm}_interp.nc" "$SCRATCH/B${band}_${hhmm}_interp.tif" & 
  gdal_translate -q -ot Byte -scale $scale_min $scale_max 0 255 "$SCRATCH/B${band}_${hhmm}_enhanced.nc" "$SCRATCH/B${band}_${hhmm}_enhanced.tif" & 
done; wait 

# === Step 6: Composites (RGB, SWIR, Dust, BTD) for interp and enhanced ===
# step 1 build the vrt's
for variant in interp enhanced; do

  # === RGB True Colour Composite ===
  gdalbuildvrt -separate "$SCRATCH/TRUE_${hhmm}_${variant}.vrt" "$SCRATCH/B03_${hhmm}_${variant}.tif" "$SCRATCH/B02_${hhmm}_${variant}.tif" "$SCRATCH/B01_${hhmm}_${variant}.tif" & 

  # === SWIR Composite ===
  gdalbuildvrt -separate "$SCRATCH/SWIR_${hhmm}_${variant}.vrt" "$SCRATCH/B06_${hhmm}_${variant}.tif" "$SCRATCH/B05_${hhmm}_${variant}.tif" "$SCRATCH/B04_${hhmm}_${variant}.tif" & 
    
    # === Dust Composite ===
  gdalbuildvrt -separate "$SCRATCH/DUST_${hhmm}_${variant}.vrt" "$SCRATCH/B07_${hhmm}_${variant}.tif" "$SCRATCH/B13_${hhmm}_${variant}.tif" "$SCRATCH/B10_${hhmm}_${variant}.tif" & 
    
  # === ANG Composite ===
  gdalbuildvrt -separate "$SCRATCH/ANG_${hhmm}_${variant}.vrt" "$SCRATCH/B15_${hhmm}_${variant}.tif" "$SCRATCH/B11_${hhmm}_${variant}.tif" "$SCRATCH/B10_${hhmm}_${variant}.tif" &
    
    # === TIR Composite ===
  gdalbuildvrt -separate "$SCRATCH/TIR_${hhmm}_${variant}.vrt" "$SCRATCH/B07_${hhmm}_${variant}.tif" "$SCRATCH/B13_${hhmm}_${variant}.tif" "$SCRATCH/B15_${hhmm}_${variant}.tif" &  
done; wait

# step 2 do the colour Composite
for variant in interp enhanced; do

  # === RGB True Colour Composite ===
  gdal_translate -of GTiff "$SCRATCH/TRUE_${hhmm}_${variant}.vrt" "$OUTDIR/TRUE_${hhmm}_${variant}.tif" & 

  # === SWIR Composite ===
  gdal_translate -of GTiff "$SCRATCH/SWIR_${hhmm}_${variant}.vrt" "$OUTDIR/SWIR_${hhmm}_${variant}.tif" & 
  
    # === Dust Composite ===
  gdal_translate -of GTiff "$SCRATCH/DUST_${hhmm}_${variant}.vrt" "$OUTDIR/DUST_${hhmm}_${variant}.tif" & 
  
  # === ANG Composite ===
  gdal_translate -of GTiff "$SCRATCH/ANG_${hhmm}_${variant}.vrt" "$OUTDIR/ANG_${hhmm}_${variant}.tif" & 
  
    # === TIR Composite ===
  gdal_translate -of GTiff "$SCRATCH/TIR_${hhmm}_${variant}.vrt" "$OUTDIR/TIR_${hhmm}_${variant}.tif" &  
done; wait 



# === Step 7: Statistics (RMSE, Correlation, STD) ===
echo "📊 Band comparison statistics for $hhmm"
stats_file="$OUTDIR/stats_${hhmm}.txt"
echo "Band,RMSE,Correlation,STD" > "$stats_file"

for band in "${bands[@]}"; do
  if [[ "$band" != "$red_band" ]]; then
    interp="$SCRATCH/B${band}_${hhmm}_interp.nc"
    enhanced="$SCRATCH/B${band}_${hhmm}_enhanced.nc"

    # --- RMSE ---
    cdo -s sqr -sub "$interp" "$enhanced" "$SCRATCH/B${band}_${hhmm}_diff_sqr.nc"
    cdo -s sqrt -fldmean "$SCRATCH/B${band}_${hhmm}_diff_sqr.nc" "$SCRATCH/B${band}_${hhmm}_rmse.nc"
    rmse=$(cdo -s output "$SCRATCH/B${band}_${hhmm}_rmse.nc" | awk '{print $1}')

    # --- Correlation ---
    cdo -s fldcor "$interp" "$enhanced" "$SCRATCH/B${band}_${hhmm}_cor.nc"
    cor=$(cdo -s output "$SCRATCH/B${band}_${hhmm}_cor.nc" | awk '{print $1}')

    # --- Standard Deviation of Difference ---
    cdo -s sub "$interp" "$enhanced" "$SCRATCH/B${band}_${hhmm}_diff.nc"
    cdo -s fldstd "$SCRATCH/B${band}_${hhmm}_diff.nc" "$SCRATCH/B${band}_${hhmm}_std.nc"
    std=$(cdo -s output "$SCRATCH/B${band}_${hhmm}_std.nc" | awk '{print $1}')

    # --- Save to file ---
    echo "B${band},$rmse,$cor,$std" >> "$stats_file"
	
    # --- Cleanup ---
    rm -f "$SCRATCH/B${band}_${hhmm}"_{diff,diff_sqr,rmse,cor,std}.nc 
  fi
done

#Make the Taylor plot using Python
python3 MakeTaylor.py "$OUTDIR/stats_${hhmm}.txt" "$OUTDIR/Taylor_${hhmm}.jpg" & 

  echo "✅ Complete: $hhmm"
done; wait 

echo "✅ All processing complete across all hours"
