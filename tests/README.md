# Tests

This directory contains the test suite for the Hidden Image Watermarking project. Tests are available in both MATLAB and Python.

## How to Run

### Python (no MATLAB license required)

```bash
# Install dependencies
pip install numpy Pillow

# Run from the project root
python tests/run_all_tests.py
```

### MATLAB

```matlab
% From the MATLAB command window, navigate to the project root
run('tests/run_all_tests.m')
```

Or from the command line:

```bash
matlab -batch "run('tests/run_all_tests.m')"
```

## Test Structure

The test suite consists of 5 test groups:

### TEST 1: LSB Embedding (1-bit)

- Embeds a watermark using 1-bit LSB in the blue channel
- Verifies output file and metadata are created
- Computes PSNR and MSE (expects PSNR > 30 dB)
- Extracts the watermark back and checks bit accuracy (expects > 99%)
- Validates metadata content

### TEST 2: DCT Embedding

- Embeds a watermark using DCT transform-domain method
- Verifies output file and metadata are created
- Computes PSNR and MSE (expects PSNR > 25 dB)
- Validates metadata content and strength value

### TEST 3: LSB Multi-Bit Embedding (2-bit)

- Tests LSB embedding with 2 bits per pixel
- Verifies acceptable PSNR (> 25 dB)

### TEST 4: Edge Cases

- Verifies that invalid `numBitsUsed` values (0 and 5) are correctly rejected

### TEST 5: Visual Watermark Mapping Verification

This test generates visual outputs to confirm the watermark is mapped correctly:

| Output File | Description |
|-------------|-------------|
| `lsb_difference_amplified.png` | Amplified (50x) pixel difference between original and LSB-watermarked image. Should show changes only in the blue channel. |
| `dct_difference_amplified.png` | Amplified (50x) pixel difference between original and DCT-watermarked image. Shows block-shaped artifacts spread across the image. |
| `watermark_original.png` | The binarized original watermark for reference. |
| `watermark_extracted_lsb.png` | The watermark extracted from the LSB-watermarked image. Should be pixel-perfect match to original. |
| `dct_block_heatmap.png` | A heatmap showing which 8×8 blocks were used for DCT embedding. White blocks = used, black = unused. |
| `lsb_side_by_side.png` | Original and LSB-watermarked image side by side (should look identical). |
| `dct_side_by_side.png` | Original and DCT-watermarked image side by side (should look identical). |

#### How to Interpret Visual Outputs

- **Difference images**: If the watermark is mapped correctly, the LSB difference should be confined to the blue channel only. The DCT difference should show evenly distributed block patterns.
- **Extracted watermark**: A pixel-perfect match confirms bits are stored and retrieved in the correct order.
- **Block heatmap**: Confirms the DCT method spreads watermark bits evenly across the full image rather than clustering them in one area.
- **Side-by-side**: Both watermarked images should be visually indistinguishable from the original.

## Output Location

All test outputs are saved to:

```
data/output/test_results/
├── lsb_watermarked.png
├── lsb_metadata.json
├── dct_watermarked.png
├── dct_metadata.json
├── lsb_2bit_watermarked.png
├── lsb_2bit_metadata.json
└── visual_verification/
    ├── lsb_difference_amplified.png
    ├── dct_difference_amplified.png
    ├── watermark_original.png
    ├── watermark_extracted_lsb.png
    ├── dct_block_heatmap.png
    ├── lsb_side_by_side.png
    └── dct_side_by_side.png
```

## Pass/Fail Criteria

The test suite reports PASS/FAIL for each check and provides a summary at the end. A non-zero exit code is returned if any test fails (Python only).
