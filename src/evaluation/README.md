# Evaluation and Retrieval File Instructions

This README explains the file locations and naming format

Please keep the file names exactly the same. The evaluation code automatically looks for these file names when calculating image quality, Accuracy, BER, and NC.

---

## Project folder

The project root should be:

```text
D:/Hidden-image-watermarking
```

Most commands should be run from the project root:

```matlab
cd('D:\Hidden-image-watermarking')
```

---

# Part 1: Instructions for the retrieval

The retrieval part should extract the hidden watermark from the watermarked images and save the extracted watermark images into:

```text
data/output/retrieved
```

If this folder does not exist, please create it.

---

## Important rule for attacked images

For attacked images, the retrieval algorithm does **not** change.

Use the same DCT retrieval rule for DCT attacked images.

Use the same LSB retrieval rule for LSB attacked images.

The only difference is the input image. Instead of using the normal watermarked image, use the attacked watermarked image.

For example:

```text
Normal DCT input:
data/output/dct_watermarked.png

Attacked DCT input:
data/output/attacks/dct/dct_jpeg_q50.png
```

The DCT algebra is still the same. If the embedding rule was:

```matlab
bit 1: dctBlock(4,5) > dctBlock(5,4)
bit 0: dctBlock(5,4) > dctBlock(4,5)
```

Then retrieval should still use:

```matlab
if dctBlock(4,5) > dctBlock(5,4)
    extractedBit = 1;
else
    extractedBit = 0;
end
```

For LSB, the extraction rule is also the same. The input image is just changed to the attacked version.

---

## DCT retrieval input files

For normal DCT retrieval, use:

```text
data/output/dct_watermarked.png
data/output/dct_metadata.json
```

The metadata file is required because it contains the DCT embedding information, including block positions and coefficient positions.

The output should be saved as:

```text
data/output/retrieved/dct_no_attack_extracted_watermark.png
```

---

## LSB retrieval input files

For normal LSB retrieval, use:

```text
data/output/lsb_watermarked.png
data/output/lsb_metadata.json
```

The output should be saved as:

```text
data/output/retrieved/lsb_no_attack_extracted_watermark.png
```


---

## DCT attacked image retrieval

Use these DCT attacked images as inputs:

```text
data/output/attacks/dct/dct_no_attack.png
data/output/attacks/dct/dct_jpeg_q50.png
data/output/attacks/dct/dct_gaussian_noise.png
data/output/attacks/dct/dct_blur_3x3.png
data/output/attacks/dct/dct_crop80_resize.png
```

There is also a JPEG file:

```text
data/output/attacks/dct/dct_jpeg_q50.jpg
```

Use the `.png` version for consistency with the evaluation code:

```text
data/output/attacks/dct/dct_jpeg_q50.png
```

Save the extracted DCT watermarks as:

```text
data/output/retrieved/dct_no_attack_extracted_watermark.png
data/output/retrieved/dct_jpeg_q50_extracted_watermark.png
data/output/retrieved/dct_gaussian_noise_extracted_watermark.png
data/output/retrieved/dct_blur_3x3_extracted_watermark.png
data/output/retrieved/dct_crop80_resize_extracted_watermark.png
```

---

## LSB attacked image retrieval

Use these LSB attacked images as inputs:

```text
data/output/attacks/lsb/lsb_no_attack.png
data/output/attacks/lsb/lsb_jpeg_q50.png
data/output/attacks/lsb/lsb_gaussian_noise.png
data/output/attacks/lsb/lsb_blur_3x3.png
data/output/attacks/lsb/lsb_crop80_resize.png
```

There is also a JPEG file:

```text
data/output/attacks/lsb/lsb_jpeg_q50.jpg
```

Use the `.png` version for consistency with the evaluation code:

```text
data/output/attacks/lsb/lsb_jpeg_q50.png
```

Save the extracted LSB watermarks as:

```text
data/output/retrieved/lsb_no_attack_extracted_watermark.png
data/output/retrieved/lsb_jpeg_q50_extracted_watermark.png
data/output/retrieved/lsb_gaussian_noise_extracted_watermark.png
data/output/retrieved/lsb_blur_3x3_extracted_watermark.png
data/output/retrieved/lsb_crop80_resize_extracted_watermark.png
```

---

# Part 2: Instructions for the analysis/evaluation 

The evaluation part checks both image quality and watermark recovery quality.

It evaluates:

```text
DCT embedding image quality
LSB embedding image quality
DCT attacked image quality
LSB attacked image quality
DCT retrieved watermark quality
LSB retrieved watermark quality
DCT retrieved watermark quality after attacks
LSB retrieved watermark quality after attacks
```

---

## Evaluation code location

The evaluation code is located in:

```text
src/evaluation
```

Current evaluation files:

```text
src/evaluation/attack_images.m
src/evaluation/image_quality_metrics.m
src/evaluation/run_evaluation.m
src/evaluation/watermark_recovery_metrics.m
```

---

## Files needed before running evaluation

The original input files should be:

```text
data/input/original.png
data/input/watermark.png
```

The embedded/watermarked image files should be:

```text
data/output/dct_watermarked.png
data/output/lsb_watermarked.png
```

The metadata files are:

```text
data/output/dct_metadata.json
data/output/lsb_metadata.json
```

The DCT metadata is especially important for retrieval. The evaluation code itself mainly needs the images and extracted watermark outputs.

---

## How to run the evaluation

Open MATLAB and go to the project root:

```matlab
cd('D:\Hidden-image-watermarking')
```

Run:

```matlab
run('src/evaluation/run_evaluation.m')
```

Do not run this command from inside `src/evaluation` using the full relative path. If MATLAB is already inside:

```text
D:\Hidden-image-watermarking\src\evaluation
```

then either go back to the project root first:

```matlab
cd('D:\Hidden-image-watermarking')
run('src/evaluation/run_evaluation.m')
```

or run only:

```matlab
run('run_evaluation.m')
```

---

## Workflow

Use this order:

```matlab
cd('D:\Hidden-image-watermarking')

run('src/transform_embedding/run_dct_embed.m')
run('src/lsb_embedding/run_lsb_embed.m')

run('src/evaluation/run_evaluation.m')
```

The first evaluation run creates attacked images and evaluates image quality.

Then the retrieval person should extract watermarks from the normal and attacked watermarked images.

After the retrieval outputs are saved in:

```text
data/output/retrieved
```

run the evaluation again:

```matlab
run('src/evaluation/run_evaluation.m')
```

The second evaluation run will calculate Accuracy, BER, and NC for the extracted watermarks.

---

## Evaluation output files

The final evaluation results are saved in:

```text
results/tables/evaluation_summary.csv
results/tables/evaluation_summary.mat
```

Use the CSV file for the report:

```text
results/tables/evaluation_summary.csv
```


---

# Part 3: How to analyze the results

The evaluation table has these main columns:

```text
Method
Category
Attack
ImageFile
WatermarkFile
MSE
PSNR
Accuracy
BER
NC
```

---

## Image quality analysis

Rows with this category:

```text
Embedding image quality
```

compare the original image with the normal watermarked image.

Rows with this category:

```text
Attacked image quality
```

compare the original image with attacked watermarked images.

For image quality, use:

```text
MSE
PSNR
```

Interpretation:

```text
Lower MSE is better.
Higher PSNR is better.
```

A high PSNR means the watermarked image looks very close to the original image.

Usually:

```text
PSNR above 40 dB: very good visual quality
PSNR around 30 dB: noticeable but still acceptable
PSNR below 20 dB: strong visible distortion
```

For this project, LSB usually has better no-attack PSNR because it changes only the least significant bits. DCT may have slightly lower PSNR, but it is usually more robust after attacks.

---

## Retrieval quality analysis

Rows with this category:

```text
Retrieved watermark quality
```

compare the original watermark with the extracted watermark from the normal watermarked image.

Rows with this category:

```text
Retrieved watermark after attack
```

compare the original watermark with the extracted watermark from attacked watermarked images.

For retrieval quality, use:

```text
Accuracy
BER
NC
```

Interpretation:

```text
Higher Accuracy is better.
Lower BER is better.
Higher NC is better.
```

Accuracy means the percentage of correctly recovered watermark bits.

BER means Bit Error Rate. A BER of 0 means perfect extraction.

NC means Normalized Correlation. A value closer to 1 means the extracted watermark is closer to the original watermark.

---

## What to compare in the final report

The analysis should compare DCT and LSB in two ways.

### 1. Visual quality comparison

Compare the no-attack PSNR and MSE:

```text
DCT Transform-Domain, Embedding image quality, No attack
LSB Spatial-Domain, Embedding image quality, No attack
```

This shows which method changes the original image less.

Expected result:

```text
LSB usually has higher PSNR and lower MSE because it only modifies least significant bits.
```

---

### 2. Robustness comparison

Compare the retrieved watermark quality after attacks:

```text
DCT Transform-Domain, Retrieved watermark after attack, jpeg_q50
DCT Transform-Domain, Retrieved watermark after attack, gaussian_noise
DCT Transform-Domain, Retrieved watermark after attack, blur_3x3
DCT Transform-Domain, Retrieved watermark after attack, crop80_resize

LSB Spatial-Domain, Retrieved watermark after attack, jpeg_q50
LSB Spatial-Domain, Retrieved watermark after attack, gaussian_noise
LSB Spatial-Domain, Retrieved watermark after attack, blur_3x3
LSB Spatial-Domain, Retrieved watermark after attack, crop80_resize
```

This shows which method can still recover the watermark after image processing attacks.

Expected result:

```text
DCT should usually be more robust than LSB after JPEG compression, blur, noise, and crop/resize.
LSB may fail badly after attacks because the least significant bits can be easily changed.
```

---

## Current attack types

The evaluation code currently creates these attacks:

```text
no_attack
jpeg_q50
gaussian_noise
blur_3x3
crop80_resize
```

The actual attacked image locations are:

```text
data/output/attacks/dct
data/output/attacks/lsb
```

---

## Notes for final report

Use the values from:

```text
results/tables/evaluation_summary.csv
```

Recommended report discussion:

```text
1. Compare DCT and LSB no-attack PSNR/MSE.
2. Compare image quality after JPEG, noise, blur, and crop/resize.
3. Compare DCT and LSB extraction Accuracy, BER, and NC before attacks.
4. Compare DCT and LSB extraction Accuracy, BER, and NC after attacks.
5. Explain the trade-off:
   - LSB gives very high visual quality but weak robustness.
   - DCT gives slightly more image change but should be more robust.
```

---

## Quick checklist

Before final analysis, check that these files exist:

```text
data/output/dct_watermarked.png
data/output/lsb_watermarked.png

data/output/attacks/dct/dct_jpeg_q50.png
data/output/attacks/dct/dct_gaussian_noise.png
data/output/attacks/dct/dct_blur_3x3.png
data/output/attacks/dct/dct_crop80_resize.png

data/output/attacks/lsb/lsb_jpeg_q50.png
data/output/attacks/lsb/lsb_gaussian_noise.png
data/output/attacks/lsb/lsb_blur_3x3.png
data/output/attacks/lsb/lsb_crop80_resize.png

data/output/retrieved/dct_no_attack_extracted_watermark.png
data/output/retrieved/dct_jpeg_q50_extracted_watermark.png
data/output/retrieved/dct_gaussian_noise_extracted_watermark.png
data/output/retrieved/dct_blur_3x3_extracted_watermark.png
data/output/retrieved/dct_crop80_resize_extracted_watermark.png

data/output/retrieved/lsb_no_attack_extracted_watermark.png
data/output/retrieved/lsb_jpeg_q50_extracted_watermark.png
data/output/retrieved/lsb_gaussian_noise_extracted_watermark.png
data/output/retrieved/lsb_blur_3x3_extracted_watermark.png
data/output/retrieved/lsb_crop80_resize_extracted_watermark.png
```

If the retrieved watermark files are missing, the evaluation will still run, but Accuracy, BER, and NC will not appear yet.
