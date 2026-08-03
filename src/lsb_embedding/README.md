# `lsb_embed.m` — Strict Tiled LSB Embedding

## 1. Purpose

This document explains only the embedding algorithm implemented by
`lsb_embed.m`. The function converts a watermark to binary data, whitens and
spatially repeats that data, and writes it into actual low-order green-channel
bit positions with MATLAB `bitset`.

The implementation extends ordinary LSB replacement with:

- deterministic xorshift32 whitening;
- a normalized 3 × 3 tiled watermark layout;
- repetition of each encoded bit across many host pixels;
- optional replacement of one through six LSB positions;
- external JSON metadata for deterministic reconstruction.

This document concerns only literal spatial-domain bit replacement.

## 2. Files

| File | MATLAB function | Responsibility |
|---|---|---|
| `lsb_embed.m` | `lsb_embed` | Prepare, whiten, tile, and embed the watermark |

MATLAB requires the function name and filename to match. Therefore this
declaration:

```matlab
function lsb_embed(...)
```

must be saved as `lsb_embed.m`.

## 3. High-level algorithm

```text
host image + watermark
        ↓
validate inputs
        ↓
convert watermark to grayscale and binary
        ↓
flatten in MATLAB column-major order
        ↓
XOR with deterministic whitening bits
        ↓
repeat encoded watermark in a normalized 3 × 3 layout
        ↓
replace green-channel bit positions 1..numBitsUsed
        ↓
save watermarked image and JSON metadata
```

## 4. Requirements

- Host image must be an 8-bit unsigned RGB image.
- Watermark must be grayscale or RGB.
- `numBitsUsed` must be an integer from 1 through 6.
- `outputImagePath` should normally use a lossless format such as PNG.
- The generated JSON metadata must be kept with the watermarked image.

---

# Detailed embedding algorithm

## 5. Function interface

```matlab
lsb_embed(inputImagePath, watermarkPath, ...
    outputImagePath, metadataPath, numBitsUsed);
```

| Parameter | Description |
|---|---|
| `inputImagePath` | Path to the original 8-bit RGB host image |
| `watermarkPath` | Path to the watermark image |
| `outputImagePath` | Destination for the watermarked image |
| `metadataPath` | Destination for the JSON metadata |
| `numBitsUsed` | Number of literal low-order positions to replace, 1–6 |

If the fifth parameter is omitted, the embedder uses one LSB:

```matlab
if nargin < 5
    numBitsUsed = 1;
end
```

## 6. Validate `numBitsUsed`

```matlab
if ~isscalar(numBitsUsed) || ~isfinite(numBitsUsed) || ...
        numBitsUsed ~= floor(numBitsUsed) || ...
        numBitsUsed < 1 || numBitsUsed > 6
    error('numBitsUsed must be an integer between 1 and 6.');
end
```

The conditions reject:

| Invalid input | Reason |
|---|---|
| `[1 2]` | Not a scalar |
| `NaN` or `Inf` | Not finite |
| `2.5` | Not an integer |
| `0` | Below the allowed range |
| `7` | Above the allowed range |

## 7. Read and validate the host image

```matlab
img = imread(inputImagePath);
```

The next checks require exactly three channels and `uint8` storage:

```matlab
if ndims(img) ~= 3 || size(img, 3) ~= 3
    error('Input image must be an RGB image.');
end

if ~isa(img, 'uint8')
    error('Input image must use 8-bit unsigned RGB samples.');
end
```

A `uint8` channel value contains eight positions:

```text
Position: 8   7   6   5   4   3   2   1
Weight:   128 64  32  16  8   4   2   1
```

Position 1 is the least significant bit.

## 8. Read and convert the watermark

```matlab
watermark = imread(watermarkPath);
```

An RGB watermark is converted to grayscale manually:

```matlab
watermarkGray = 0.299 * watermarkRed + ...
                0.587 * watermarkGreen + ...
                0.114 * watermarkBlue;
```

The coefficients are standard luminance weights. An already-grayscale image is
converted directly to `double`.

## 9. Select the binary threshold

For an integer watermark:

```matlab
watermarkMaximum = double(intmax(class(watermark)));
watermarkThreshold = watermarkMaximum / 2;
```

Examples:

| Type | Maximum | Threshold |
|---|---:|---:|
| `uint8` | 255 | 127.5 |
| `uint16` | 65535 | 32767.5 |

For floating-point input:

```matlab
watermarkMaximum = max(watermarkGray(:));
watermarkThreshold = 0.5 + ...
    127.5 * double(watermarkMaximum > 1);
```

This selects:

- `0.5` when the data appears normalized to `[0,1]`;
- `128` when the data appears to use an 8-bit-like range.

Binarization is then:

```matlab
watermarkBinary = watermarkGray > watermarkThreshold;
```

Values above the threshold become logical one; other values become logical
zero.

## 10. Read dimensions

```matlab
[imgH, imgW, ~] = size(img);
[wmH, wmW] = size(watermarkBinary);
numWatermarkBits = numel(watermarkBinary);
```

For a 64 × 64 watermark:

```text
numWatermarkBits = 64 × 64 = 4096
```

## 11. Core parameters

```matlab
tileRows = 3;
tileColumns = 3;
embeddingChannelIndex = 2;
whiteningSeed = uint32(19088743);
```

| Variable | Value | Meaning |
|---|---:|---|
| `tileRows` | 3 | Repeat the complete encoded watermark vertically three times |
| `tileColumns` | 3 | Repeat it horizontally three times |
| `embeddingChannelIndex` | 2 | Modify the green RGB channel |
| `whiteningSeed` | 19088743 | Reproduce the same whitening sequence during retrieval |

The spatial layout is:

```text
copy 1   copy 2   copy 3
copy 4   copy 5   copy 6
copy 7   copy 8   copy 9
```

## 12. Flatten the watermark

```matlab
watermarkBits = watermarkBinary(:);
```

MATLAB uses column-major order. For:

```matlab
watermarkBinary = [1 0 1; 0 1 0];
```

the flattened vector is:

```text
1, 0, 0, 1, 1, 0
```

This fixed order makes the payload vector reproducible across runs.

## 13. Whitening

```matlab
whiteningBits = make_whitening_bits( ...
    numWatermarkBits, whiteningSeed);

encodedBits = xor(watermarkBits, whiteningBits);
encodedWatermark = reshape(encodedBits, [wmH, wmW]);
```

Whitening converts large constant regions into a deterministic, balanced
pattern. XOR is reversible:

```text
(watermark XOR whitening) XOR whitening = watermark
```

### Xorshift32 helper

Each loop iteration updates a 32-bit state:

```matlab
state = bitxor(state, bitshift(state, 13));
state = bitxor(state, bitshift(state, -17));
state = bitxor(state, bitshift(state, 5));
```

This corresponds to:

```text
x = x XOR (x << 13)
x = x XOR (x >> 17)
x = x XOR (x << 5)
```

The output bit is the least significant state bit:

```matlab
whiteningBits(bitIndex) = ...
    logical(bitand(state, uint32(1)));
```

A zero state is replaced because xorshift cannot escape from all zeros.
Whitening is pattern randomization, not encryption.

## 14. Normalized row mapping

```matlab
normalizedRows = ((0:(imgH - 1)) + 0.5) / imgH;
```

The expression creates the normalized center coordinate of each host row.

For one-based host row `r`:

$$
u_r=\frac{r-0.5}{H}
$$

The assigned watermark row is:

```matlab
rowBitIndices = mod( ...
    floor(normalizedRows * tileRows * wmH), wmH) + 1;
```

Equivalent formula:

$$
i_r=\operatorname{mod}
\left(\left\lfloor u_r T_r H_w\right\rfloor,H_w\right)+1
$$

The operations mean:

1. Multiply by `tileRows * wmH` to create all watermark-row bands.
2. Use `floor` to select a discrete band.
3. Use `mod(...,wmH)` to wrap each tile back to watermark rows `0..wmH-1`.
4. Add one for MATLAB indexing.

## 15. Normalized column mapping

```matlab
normalizedColumns = ((0:(imgW - 1)) + 0.5) / imgW;

columnBitIndices = mod( ...
    floor(normalizedColumns * tileColumns * wmW), wmW) + 1;
```

This is the horizontal equivalent of the row mapping.

## 16. Coverage validation

```matlab
if numel(unique(rowBitIndices)) ~= wmH
    error('Host image is too short to represent every watermark row.');
end

if numel(unique(columnBitIndices)) ~= wmW
    error('Host image is too narrow to represent every watermark column.');
end
```

Because the indices are restricted to valid watermark coordinates, finding
exactly `wmH` unique row values and `wmW` unique column values proves that every
watermark coordinate can be assigned.

## 17. Minimum samples per bit

```matlab
minimumSamplesPerBit = tileRows * tileColumns * ...
    floor(imgH / (tileRows * wmH)) * ...
    floor(imgW / (tileColumns * wmW));
```

For a 1097 × 1697 host and 64 × 64 watermark:

```text
vertical samples per cell   = floor(1097 / (3 × 64)) = 5
horizontal samples per cell = floor(1697 / (3 × 64)) = 8
guaranteed samples per bit  = 3 × 3 × 5 × 8 = 360
```

The function requires at least nine samples so that majority voting has useful
redundancy.

## 18. Expand the bit plane

```matlab
embeddedBitPlane = encodedWatermark( ...
    rowBitIndices, columnBitIndices);
```

`embeddedBitPlane` has the same height and width as the host image. Each element
contains the encoded watermark bit assigned to the corresponding host pixel.

## 19. Literal LSB replacement

```matlab
modifiedChannel = img(:, :, embeddingChannelIndex);

for bitPosition = 1:numBitsUsed
    modifiedChannel = bitset(modifiedChannel, bitPosition, ...
        uint8(embeddedBitPlane));
end
```

The same assigned watermark bit is written into every selected low-order
position.

### Example with four positions

Original green value:

```text
100 decimal = 01100100 binary
```

After writing encoded zero into positions 1–4:

```text
01100000 = 96
```

After writing encoded one into positions 1–4:

```text
01101111 = 111
```

Higher positions remain unchanged.

## 20. Parameter range and distortion

| `numBitsUsed` | Replaced positions | Maximum channel change |
|---:|---|---:|
| 1 | 1 | 1 |
| 2 | 1–2 | 3 |
| 3 | 1–3 | 7 |
| 4 | 1–4 | 15 |
| 5 | 1–5 | 31 |
| 6 | 1–6 | 63 |

The maximum possible change is:

$$
2^{\texttt{numBitsUsed}}-1
$$

Increasing the number of replaced positions strengthens the repeated binary
pattern but also increases visible distortion.

## 21. Construct the watermarked image

```matlab
watermarkedImg = img;
watermarkedImg(:, :, embeddingChannelIndex) = modifiedChannel;
imwrite(watermarkedImg, outputImagePath);
```

Only the green channel is replaced. Red and blue remain identical to the host.

The diagnostic count:

```matlab
changedPixelCount = nnz(modifiedChannel ~= ...
    img(:, :, embeddingChannelIndex));
```

counts green-channel samples changed by one or more replaced positions.

## 22. Save metadata

The embedder builds a MATLAB structure, converts it with `jsonencode`, and
writes it with `fprintf`.

```matlab
jsonText = jsonencode(metadata);
fid = fopen(metadataPath, 'w');
bytesWritten = fprintf(fid, '%s', jsonText);
closeStatus = fclose(fid);
```

It rejects an unavailable output file, incomplete write, or failed close.

---

## 23. Metadata field reference

| Field | Value recorded by the embedder |
|---|---|
| `method` | Broad spatial-domain LSB method label |
| `methodDetail` | Tiled, whitened, literal bit-replacement variant |
| `algorithmVersion` | Metadata format version |
| `embeddingMode` | Machine-readable format identifier |
| `strictLSB` | Confirms that actual low-order positions were replaced |
| `inputImage` | Original host-image path |
| `watermarkImage` | Source watermark path |
| `outputImage` | Generated watermarked-image path |
| `imageHeight`, `imageWidth` | Original host dimensions |
| `watermarkHeight`, `watermarkWidth` | Binary watermark dimensions |
| `numWatermarkBits` | Total binary payload length |
| `numBitsUsed` | Number of replaced low-order positions, 1–6 |
| `bitPositions` | Exact one-based positions, `1:numBitsUsed` |
| `embeddingChannelIndex` | MATLAB RGB channel index, normally `2` |
| `embeddingChannel` | Human-readable channel name |
| `tileRows`, `tileColumns` | Vertical and horizontal repetition counts |
| `whiteningSeed` | Seed needed to regenerate whitening bits |
| `minimumSupportedCropRatio` | Smallest centered crop the retriever searches |
| `minimumSamplesPerBit` | Guaranteed spatial repetition lower bound |
| `maximumChannelChange` | `2^numBitsUsed - 1` |
| `changedPixelCount` | Number of modified green-channel samples |
| `embeddingOrder` | Normalized tiled coordinate convention |

Do not edit these values manually after embedding. The matching retriever uses
them to reconstruct the watermark layout and whitening sequence.

## 24. Direct usage

Place `lsb_embed.m` on the MATLAB path:

```matlab
addpath('path/to/embedding/folder');
```

Embed with the lowest-distortion one-bit setting:

```matlab
lsb_embed('original.png', 'watermark.png', ...
    'lsb_watermarked_1bit.png', ...
    'lsb_metadata_1bit.json', 1);
```

Embed with four repeated bit positions:

```matlab
lsb_embed('original.png', 'watermark.png', ...
    'lsb_watermarked_4bit.png', ...
    'lsb_metadata_4bit.json', 4);
```

Embed with the maximum supported six positions only when a possible
green-channel change of up to 63 is acceptable:

```matlab
lsb_embed('original.png', 'watermark.png', ...
    'lsb_watermarked_6bit.png', ...
    'lsb_metadata_6bit.json', 6);
```

Omitting the fifth argument selects one position:

```matlab
lsb_embed('original.png', 'watermark.png', ...
    'lsb_watermarked.png', 'lsb_metadata.json');
```

## 25. Choosing `numBitsUsed`

- Choose `1` when visual fidelity is the priority.
- Choose `2` or `3` for a moderate increase in redundant bit-plane votes.
- Choose `4` when greater redundancy is worth a possible value change of 15.
- Choose `5` or `6` only when strong visible distortion is acceptable.

Writing the same encoded bit into more bit positions adds retrieval votes. It
does not make literal low-order bits intrinsically resistant to processing that
recalculates pixel intensities, such as lossy compression or strong filtering.

## 26. Limitations

1. The host must be an 8-bit RGB image.
2. The output modifies only the green channel, but replacing many positions can
   still produce visible color changes.
3. Each watermark bit needs sufficient spatial coverage in the host.
4. The fixed 3 × 3 layout is designed for the matching retrieval mapping.
5. Whitening is deterministic; it is not encryption.
6. The JSON metadata is external and must remain paired with the output image.
7. Literal low-order bits are fragile when another operation recomputes pixel
   values.

## 27. Troubleshooting

### `numBitsUsed must be an integer between 1 and 6`

Pass one finite scalar integer, for example:

```matlab
numBitsUsed = 4;
```

Values such as `0`, `7`, `2.5`, `NaN`, and vectors are rejected.

### Host image is too short or too narrow

Every watermark row and column must map to at least one host row and column.
Use a larger host image or a smaller watermark.

### Host image is too small for tiled embedding

Every encoded watermark bit needs at least nine guaranteed spatial samples.
The error reports the calculated lower bound. Increase the host dimensions or
reduce the watermark dimensions.

### Watermarked image looks visibly different

Reduce `numBitsUsed`. The maximum possible selected-channel change rises from
1 at the one-bit setting to 63 at the six-bit setting.

### Metadata file cannot be written

Check that the destination folder exists and that MATLAB has permission to
write there. The function reports the path that failed.

## 28. Embedding variable reference

| Variable | Meaning |
|---|---|
| `watermarkGray` | Grayscale watermark samples |
| `watermarkBinary` | Thresholded logical watermark |
| `watermarkBits` | Column-major watermark vector |
| `whiteningBits` | Deterministic pseudo-random logical vector |
| `encodedBits` | Whitened watermark vector |
| `encodedWatermark` | Whitened watermark matrix |
| `rowBitIndices` | Host-row to watermark-row mapping |
| `columnBitIndices` | Host-column to watermark-column mapping |
| `embeddedBitPlane` | Encoded bit assigned to every host pixel |
| `modifiedChannel` | Green channel after literal replacement |
| `minimumSamplesPerBit` | Guaranteed repetition count per payload bit |
| `changedPixelCount` | Number of altered green-channel pixels |

## 29. Summary

```text
binarize watermark → whiten → reshape → map normalized 3 × 3 tiles
→ bitset positions 1..numBitsUsed → save image and JSON metadata
```

`lsb_embed.m` accepts integer `numBitsUsed` values from 1 through 6. Its output
must be decoded with the matching metadata and retrieval implementation.
