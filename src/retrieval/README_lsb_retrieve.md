# `lsb_retrieve.m` — Strict Tiled LSB Retrieval

## 1. Purpose

This document explains only the retrieval algorithm implemented by
`lsb_retrieve.m`. The function reads actual low-order green-channel bit
positions with MATLAB `bitget`, estimates a supported centered crop, combines
repeated votes, removes deterministic whitening, and reconstructs the binary
watermark.

The implementation extends ordinary LSB replacement with:

- deterministic xorshift32 whitening;
- a normalized 3 × 3 tiled watermark layout;
- repetition of each encoded bit across many host pixels;
- reading one through six embedded LSB positions;
- centered-crop synchronization;
- majority voting across bit positions and spatial copies;
- external JSON metadata for deterministic reconstruction.

This README documents only strict bit-replacement retrieval.

## 2. Files

| File | MATLAB function | Responsibility |
|---|---|---|
| `lsb_retrieve.m` | `lsb_retrieve` | Align, extract, vote, de-whiten, and reconstruct the watermark |

MATLAB requires the function name and filename to match. Therefore this
declaration:

```matlab
function lsb_retrieve(...)
```

must be saved as `lsb_retrieve.m`.

## 3. High-level algorithm

```text
watermarked/attacked image + JSON metadata
        ↓
validate metadata and image
        ↓
read bit positions 1..numBitsUsed
        ↓
estimate centered crop ratio from repeated-pattern agreement
        ↓
map every received pixel to its encoded watermark bit
        ↓
combine bit-plane and spatial votes
        ↓
regenerate and remove whitening
        ↓
reshape and save recovered watermark
```

## 4. Requirements

- Host image must be an 8-bit unsigned RGB image.
- `numBitsUsed` must be an integer from 1 through 6.
- The JSON file produced during embedding must be kept for retrieval.
- Automatic geometric alignment assumes a centered crop retaining at least 50%
  of each image axis.

---

# Detailed retrieval algorithm

## 5. Function interface

```matlab
lsb_retrieve(inputImagePath, outputWatermarkPath, ...
    numBitsUsed, jsonInputFilePath);
```

| Parameter | Description |
|---|---|
| `inputImagePath` | Watermarked or attacked image to decode |
| `outputWatermarkPath` | Destination for the recovered watermark |
| `numBitsUsed` | Expected replaced-position count, 1–6 |
| `jsonInputFilePath` | Metadata created by `lsb_embed.m` |

## 6. Load metadata

```matlab
jsonText = fileread(jsonInputFilePath);
metadata = jsondecode(jsonText);
```

Required fields are validated before use. Retrieval also verifies:

```matlab
strcmp(metadata.embeddingMode, ...
    'tiled-whitened-lsb-bit-replacement')
```

This prevents an unrelated metadata format from being silently interpreted as
this algorithm.

## 7. Metadata values are authoritative

```matlab
embeddedBitsUsed = double(metadata.numBitsUsed);
```

If the caller passes a different value, retrieval warns:

```matlab
if numBitsUsed ~= embeddedBitsUsed
    warning(['numBitsUsed does not match the JSON value. Retrieval will ' ...
        'read the exact LSB positions recorded in JSON.']);
end
```

The code continues with `embeddedBitsUsed`, because it describes how the image
was actually generated. Do not edit the JSON manually to silence the warning;
re-embed with the intended value instead.

## 8. Extract the embedded bit positions

```matlab
embeddedChannel = img(:, :, embeddingChannelIndex);
pixelVotes = zeros(imgH, imgW);

for bitPosition = 1:embeddedBitsUsed
    bitPlane = double(bitget(embeddedChannel, bitPosition));
    pixelVotes = pixelVotes + (2 * bitPlane - 1);
end
```

`bitget` returns zero or one. The transformation:

```matlab
2 * bitPlane - 1
```

creates signed votes:

| Extracted bit | Vote |
|---:|---:|
| 0 | -1 |
| 1 | +1 |

With four positions, received bits `1,1,1,0` produce:

```text
+1 +1 +1 -1 = +2
```

The pixel therefore favors encoded one.

## 9. Synchronization sampling

```matlab
syncStride = max(1, floor(min(imgH, imgW) / 256));
sampleRows = 1:syncStride:imgH;
sampleColumns = 1:syncStride:imgW;
sampleVotes = pixelVotes(sampleRows, sampleColumns);
```

Sampling reduces the cost of testing many candidate crop ratios while retaining
enough observations to measure repeated-pattern consistency.

## 10. Candidate centered crops

```matlab
candidateCropRatios = minimumCropRatio:0.005:1.0;
```

With `minimumCropRatio = 0.50`, retrieval tests:

```text
0.500, 0.505, 0.510, ..., 0.995, 1.000
```

For candidate ratio $\rho$, an attacked normalized coordinate $u_a$ maps to:

$$
u_s=u_a\rho+\frac{1-\rho}{2}
$$

For a centered 80% crop:

$$
u_s=0.8u_a+0.1
$$

The mapped coordinates are converted to watermark row and column indices with
the same formulas used by embedding.

## 11. Linear payload indices

```matlab
payloadIndices = rowBitIndices(:) + ...
    (columnBitIndices(:).' - 1) * wmH;
```

For watermark row `r`, column `c`, and height `wmH`, MATLAB's column-major
linear index is:

$$
k=r+(c-1)H_w
$$

The expression produces one payload index for every sampled image location.

## 12. Accumulate repeated votes

```matlab
voteSums = accumarray(payloadIndices(:), sampleVotes(:), ...
    [numWatermarkBits, 1], @sum, 0);

voteCounts = accumarray(payloadIndices(:), 1, ...
    [numWatermarkBits, 1], @sum, 0);
```

`accumarray` groups all observations assigned to the same encoded watermark bit.

## 13. Crop synchronization score

```matlab
cropScores(candidateIndex) = ...
    mean(abs(voteSums(representedBits)) ./ ...
    (voteCounts(representedBits) * embeddedBitsUsed));
```

The score is:

$$
S(\rho)=\frac{1}{N}\sum_{k=1}^{N}
\frac{|V_k(\rho)|}{C_k(\rho)B}
$$

where:

- $V_k$ is the signed vote sum for encoded watermark bit `k`;
- $C_k$ is its sample count;
- $B$ is the number of embedded positions;
- $N$ is the number of represented watermark bits.

The correct crop ratio groups copies of the same whitened bit, producing high
agreement. An incorrect ratio mixes unrelated bits and reduces the score.

## 14. Select or reject the crop estimate

```matlab
[bestCropScore, bestCandidateIndex] = max(cropScores);
bestCropRatio = candidateCropRatios(bestCandidateIndex);
```

If the score is below 0.40:

```matlab
bestCropRatio = 1.0;
```

The low score indicates that the LSB pattern is too damaged for trustworthy
geometric estimation. Assuming no crop is safer than applying a random crop
transformation.

## 15. Full-resolution mapping and voting

After selecting the crop ratio, retrieval reconstructs row and column mappings
for every received pixel and combines the full `pixelVotes` array:

```matlab
voteSums = accumarray(payloadIndices(:), pixelVotes(:), ...
    [numWatermarkBits, 1], @sum, 0);
```

It also counts observations and rejects a case where any watermark bit receives
zero votes.

## 16. Make encoded-bit decisions

```matlab
recoveredEncodedBits = voteSums > 0;
```

- Positive combined vote becomes encoded one.
- Zero or negative combined vote becomes encoded zero.

## 17. Remove whitening

```matlab
whiteningBits = make_whitening_bits( ...
    numWatermarkBits, whiteningSeed);

watermarkBits = xor(recoveredEncodedBits, whiteningBits);
```

The same seed regenerates the same sequence, so the second XOR restores the
original binary watermark bits.

### Whitening helper

The local `make_whitening_bits` function must perform the same xorshift32
sequence used during embedding:

```matlab
state = uint32(seed);

if state == 0
    state = uint32(2463534242);
end

whiteningBits = false(numberOfBits, 1);

for bitIndex = 1:numberOfBits
    state = bitxor(state, bitshift(state, 13));
    state = bitxor(state, bitshift(state, -17));
    state = bitxor(state, bitshift(state, 5));
    whiteningBits(bitIndex) = ...
        logical(bitand(state, uint32(1)));
end
```

- `uint32(seed)` gives the bit operations a fixed 32-bit state.
- The all-zero state is replaced because xorshift32 cannot leave zero.
- `false(numberOfBits, 1)` preallocates one logical bit per payload bit.
- The three shift/XOR statements advance the deterministic generator.
- `bitand(...,1)` extracts the least significant state bit.
- Using the stored seed produces exactly the sequence needed to undo whitening.

## 18. Reconstruct and save the watermark

```matlab
reconstructedWatermark = reshape( ...
    watermarkBits, [wmH, wmW]);

imwrite(uint8(reconstructedWatermark) * 255, ...
    outputWatermarkPath);
```

Logical zero is written as black (`0`) and logical one as white (`255`).

## 19. Confidence value

```matlab
bitConfidence = abs(voteSums) ./ ...
    (voteCounts * embeddedBitsUsed);
```

This normalizes the absolute vote margin by the maximum possible vote magnitude.
A value near one means strong agreement; a value near zero means disagreement or
heavy corruption.

---

## 20. Metadata fields used by retrieval

| Required field | How retrieval uses it |
|---|---|
| `embeddingMode` | Rejects metadata from a different format |
| `watermarkHeight`, `watermarkWidth` | Defines the reconstructed matrix shape |
| `numWatermarkBits` | Expected binary payload length |
| `numBitsUsed` | Selects exact positions `1:numBitsUsed` for `bitget` |
| `embeddingChannelIndex` | Selects the embedded RGB channel |
| `tileRows`, `tileColumns` | Recreates the repeated spatial mapping |
| `whiteningSeed` | Regenerates the whitening sequence |
| `minimumSupportedCropRatio` | Sets the lower bound of crop search |

The JSON can contain additional diagnostic fields, but the fields above are
required. Retrieval must use the metadata generated for the same watermarked
image.

## 21. Direct usage

Place `lsb_retrieve.m` on the MATLAB path:

```matlab
addpath('path/to/retrieval/folder');
```

Retrieve using the matching value and JSON:

```matlab
lsb_retrieve('lsb_watermarked.png', ...
    'recovered_watermark.png', 4, 'lsb_metadata.json');
```

For an attacked image, use the metadata belonging to the original watermarked
image:

```matlab
lsb_retrieve('attacked_watermarked.png', ...
    'recovered_after_attack.png', 4, 'lsb_metadata.json');
```

To inspect the authoritative stored position count before calling retrieval:

```matlab
metadata = jsondecode(fileread('lsb_metadata.json'));
disp(metadata.numBitsUsed);
```

## 22. Expected behavior under attacks

| Input condition | Expected behavior |
|---|---|
| No attack, lossless PNG | Exact or near-exact recovery |
| Centered crop plus nearest-neighbor resize | Tiling and crop search can recover |
| Small minority of bit errors | Majority voting can correct |
| Strong Gaussian noise | Low-order parity may approach random |
| JPEG compression | Recalculated pixel values may destroy literal LSBs |
| Blur | Averaging may destroy literal LSBs |
| Rotation or perspective | Unsupported coordinate transformation |

Increasing `numBitsUsed` adds repeated bit-position votes but does not guarantee
survival under attacks that systematically recalculate pixel intensities.

## 23. Limitations

1. Retrieval is blind and does not compare against the original host image.
2. Geometric synchronization supports centered crops only.
3. Crop ratios below the metadata minimum are not searched.
4. Rotation, translation, perspective, and arbitrary off-center crops are not
   registered.
5. Literal LSBs are inherently fragile under lossy processing.
6. Replacing five or six positions can create substantial visual distortion.
7. Whitening is deterministic and is not cryptographic protection.
8. The external JSON file is required for dimensions and decoding parameters.

## 24. Troubleshooting

### `numBitsUsed must be an integer between 1 and 6`

Use one scalar integer:

```matlab
numBitsUsed = 4;
```

### `numBitsUsed does not match the JSON value`

The image and JSON were created with a different setting from the retrieval
argument. Read the stored value:

```matlab
metadata = jsondecode(fileread('lsb_metadata.json'));
disp(metadata.numBitsUsed);
```

Pass that value, or re-embed the image with the desired value. Do not manually
change JSON parameters without re-embedding.

### Metadata format error

Use the JSON produced by the matching `lsb_embed.m` call.

### Low synchronization confidence

The extracted low-order positions no longer form a convincing repeated pattern.
The retriever assumes no crop and continues with majority voting, but recovery
quality may be poor.

## 25. Variable reference

| Variable | Meaning |
|---|---|
| `whiteningBits` | Deterministic pseudo-random logical vector |
| `rowBitIndices` | Host-row to watermark-row mapping |
| `columnBitIndices` | Host-column to watermark-column mapping |
| `embeddedChannel` | Green channel read by retrieval |
| `pixelVotes` | Signed votes combined across bit positions |
| `candidateCropRatios` | Centered crop fractions tested |
| `cropScores` | Agreement score for each candidate ratio |
| `bestCropRatio` | Selected centered crop fraction |
| `payloadIndices` | Linear watermark index assigned to each host pixel |
| `voteSums` | Combined spatial vote for every encoded bit |
| `voteCounts` | Number of host samples assigned to every encoded bit |
| `recoveredEncodedBits` | Decisions before whitening removal |
| `watermarkBits` | Recovered logical vector after whitening removal |
| `reconstructedWatermark` | Final two-dimensional logical watermark |

## 26. Summary

```text
load JSON → bitget positions → crop alignment → majority vote
→ remove whitening → reshape → save watermark
```

`lsb_retrieve.m` accepts integer `numBitsUsed` values from 1 through 6. The
stored JSON value remains authoritative because it records the bit positions
actually written into the image.
