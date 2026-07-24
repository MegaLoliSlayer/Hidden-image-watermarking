# Part 1A: LSB Embedding

## Overview

This module implements spatial-domain watermarking using Least Significant Bit (LSB) embedding. The watermark is embedded directly into the pixel values of the image without any frequency transform.

## How It Works

1. Read the original RGB image.
2. Read the watermark image and convert it to binary (black/white).
3. Flatten the binary watermark into a 1D bit stream.
4. Embed the watermark bits into the least significant bit(s) of the blue channel.
5. Traverse pixels in raster order (row by row, left to right).
6. For each pixel, clear the lowest LSB(s) and replace them with watermark bits.
7. Save the watermarked image and metadata.

## Why the Blue Channel?

Human eyes are least sensitive to changes in the blue channel compared to red and green. Embedding in the blue channel minimizes visible distortion.

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `inputImagePath` | Path to the original RGB image | Required |
| `watermarkPath` | Path to the watermark image | Required |
| `outputImagePath` | Path for the output watermarked image | Required |
| `metadataPath` | Path for the JSON metadata file | Required |
| `numBitsUsed` | Number of LSBs to use (1-4) | 1 |

## Usage

```matlab
% Run the default configuration
run_lsb_embed

% Or call the function directly
lsb_embed('input.png', 'watermark.png', 'output.png', 'metadata.json', 1);
```

## Trade-offs

- **1 LSB**: Most invisible, lowest capacity.
- **2 LSBs**: Slightly more visible, double the capacity.
- **3-4 LSBs**: Higher capacity but more visible distortion.

## Output

- `lsb_watermarked.png`: The watermarked image (saved in `data/output/`).
- `lsb_metadata.json`: Metadata needed for watermark retrieval.
