# Himawari-HD via Δr–NBT

**A Generalized Resolution Enhancement Method Using Red Shift and Normalized Brightness Temperature**  
*Author: Miles Sowden (Sigma Theta, Scarborough, Western Australia)*  
*Contact: miles.sowden@sigmatheta.biz*

---

## Abstract

This study introduces Ar-NBT, a generalized resolution enhancement framework that upgrades all 16 bands of the Himawari-8 Advanced Himawari Imager (AHI) to 0.005° spatial resolution using physically based interpolation and thermodynamic normalization. During daytime, the method exploits the high-resolution red visible band (Band 03) to compute spatial deltas (Δr) for each visible and infrared band. These deltas are interpolated and applied to the red band at high spatial resolution to generate enhanced outputs. At night, enhancement is achieved through normalized brightness temperature (NBT), defined as a scaled representation of thermal infrared brightness temperature in degrees Celsius. The framework is fully deterministic and requires no cloud masking, machine learning, or parameter tuning, making it suitable for near-real-time operational use. Ar-NBT is evaluated using a major bushfire event in New South Wales, Australia (10 December 2019), and further validated during a severe urban haze episode in Hanoi, Vietnam (1 November 2024). Enhanced imagery reveals fine-scale cloud and aerosol structures that are not resolved in native-resolution products. Quantitative comparisons with conventional bicubic interpolations yield strong agreement (correlation coefficient r > 0.98, RMSE < 0.013), confirming radiometric accuracy. Composite products demonstrate improved interpretability across diverse atmospheric conditions.

---

## Repository Contents

This repository contains:
- Bash scripts for full-band enhancement using Ar-NBT
- Sample outputs and composite imagery
- Documentation for reproducing the enhancement workflow

---

## Method Summary

- **Daytime Enhancement**: Uses high-resolution red band (Band 03) to compute Δr fields for each band.
- **Nighttime Enhancement**: Applies NBT scaling to thermal infrared bands.
- **Processing Tools**: Uses GDAL and CDO for reprojection, arithmetic, and resampling.
- **Output**: Enhanced NetCDF and GeoTIFF files for each band and composite.

---

## Composite Products

| Composite Type       | Bands Used (R, G, B)         | Purpose                                      |
|----------------------|------------------------------|----------------------------------------------|
| True Color RGB       | B03, B02, B01                | Natural daylight reflectance                 |
| SWIR Composite       | B06, B05, B04                | Burn scars, vegetation, cloud phase          |
| Dust RGB             | B07, B13, B10                | Surface heat and elevated aerosol structure  |
| ANG Index            | B15, B11, B10                | Thermal gradient and aerosol size            |
| Thermal Infrared     | B07, B13, B15                | Multiscale thermal transitions               |

---

## Validation Summary

- **Visual Evaluation**: Enhanced composites show improved clarity in smoke, cloud, and haze features.
- **Quantitative Metrics**:
  - RMSE across bands: 0.0068–0.0173
  - Correlation (R): >0.98 for all bands
  - STD closely matches RMSE, indicating no bias
- **Taylor Diagram Analysis**: Confirms spectral coherence and structural consistency across regions.

---

## Case Studies

- **NSW Bushfires (10 Dec 2019)**: High-contrast scene with smoke and convective clouds.
- **Hanoi Haze (1 Nov 2024)**: Low-contrast smog event validating neutrality in enhancement.

---

## License

This work is licensed under the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/).

---

## Citation [Under review]

Sowden, M. *Himawari-HD via Δr–NBT: A Generalized Resolution Enhancement Method Using Red Shift and Normalized Brightness Temperature*. Remote Sens. 2025, 17, x. [DOI to be added by editorial staff]

---

## Acknowledgments

This research was conducted using the National Computational Infrastructure (NCI Australia) and Himawari-8/9 data provided by the Bureau of Meteorology. The author thanks both institutions for their support.

---



