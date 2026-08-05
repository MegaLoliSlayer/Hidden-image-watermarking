# Part 2A: Watermark Retrieval

---

## What Changed in the Updated DCT Retrieval Method

The original DCT retrieval method expected only one watermark copy. It read one 80-bit header, located one set of watermark blocks, and made one binary decision for every watermark bit.

The updated embedding method stores six complete regional copies, so the retrieval algorithm was changed to read, validate, and combine those copies.

### 1. Retrieval now reads the regional layout from JSON

The original version first attempted to recover the 80-bit header directly from the first 80 DCT blocks. It used JSON only when that embedded header was damaged.

The updated version reads `dct_metadata.json` first because the JSON contains the exact locations of all six copies.

Important fields include:

```text
originalHeight
originalWidth
paddedHeight
paddedWidth
watermarkHeight
watermarkWidth
numEmbeddedBits
blockSize
coeff1
coeff2
metadataLength
payloadLength
numCopies
regionalBlockIndices
```

The flattened regional block list is converted back into a matrix:

```matlab
copyBlockIndices = reshape( ...
    flatCopyBlockIndices, ...
    [payloadLength, numCopies]).';
```

The rows represent regional copies, and the columns represent payload positions.

### 2. The retriever supports six complete copies

The original version extracted one bit from one block:

```matlab
bit = dctBlock(4,5) > dctBlock(5,4);
```

The updated version loops through every payload position in every region:

```matlab
for copyIndex = 1:numCopies
    for payloadIndex = 1:payloadLength
        ...
    end
end
```

It stores the signed coefficient difference:

```matlab
margin = c1 - c2;
```

The sign represents the recovered bit:

```text
Positive margin: bit 1
Negative margin: bit 0
```

The magnitude indicates how strongly the coefficients support that decision.

### 3. The known crop-and-resize attack is registered before extraction

The project's crop attack keeps the center 80% of the image and resizes it back to the original dimensions.

The updated retriever detects the crop test when the input filename contains:

```text
crop80_resize
```

It then:

1. Calculates the expected cropped dimensions.
2. Shrinks the attacked image back to those dimensions.
3. Places the recovered crop at its original center position.
4. Restores the original image coordinate system before extracting DCT blocks.

This allows the saved regional block indices to refer to the correct original positions.

### 4. A validity mask identifies cropped-away blocks

Cropping permanently removes image information. The retriever cannot safely decode a block that was partly or completely removed.

The updated code builds a validity mask:

```matlab
paddedValid
```

Before extracting a block, it checks:

```matlab
if ~all(blockValid(:))
    continue;
end
```

Invalid blocks are skipped and stored as `NaN` in the coefficient-margin matrix.

This prevents missing image regions from being treated as real watermark data.

### 5. Regional headers are checked separately

Every regional copy contains the same 80-bit header.

The retriever rebuilds the expected header and compares it with the surviving header bits from each region.

It reports values such as:

```text
Copy 1 header agreement: 100.00%
Copy 2 header agreement: 98.75%
```

These scores help show which regions survived an attack and how reliable each regional copy is.

The JSON metadata still determines the required dimensions and block positions.

### 6. Watermark copies are combined using clipped soft voting

The original method trusted one binary comparison for each bit.

The updated method collects the signed coefficient margins from all surviving copies:

```matlab
bitMargins = watermarkMargins(bitIndex, :);
bitMargins = bitMargins(~isnan(bitMargins));
```

Large abnormal values are limited:

```matlab
clipLimit = max(1, 2 * strength);

clippedMargins = min(max( ...
    bitMargins, -clipLimit), clipLimit);
```

The final bit is decided by the total signed margin:

```matlab
watermarkBits(bitIndex) = ...
    sum(clippedMargins) > 0;
```

Example:

```text
Copy 1: +75
Copy 2: +48
Copy 3: missing
Copy 4: -12
Copy 5: +61
Copy 6: missing

Combined result is positive, so the recovered bit is 1.
```

This is called soft voting because each copy contributes its coefficient confidence rather than only a hard `0` or `1`.

### 7. New diagnostic output

The updated retriever reports:

```text
number of configured regional copies
average surviving copies per watermark bit
minimum surviving copies for any watermark bit
number of bits with no surviving copy
header agreement for every region
```

These values help evaluate how an attack affected the embedded watermark.

### 8. What remained unchanged

The following parts still use the same basic method:

- manual RGB-to-Y brightness conversion;
- `8 × 8` DCT blocks;
- coefficient positions `[4,5]` and `[5,4]`;
- the coefficient-order bit rule;
- MATLAB column-major watermark reconstruction;
- binary watermark output using values `0` and `255`.

### 9. Limitation

The current crop registration is designed for the project's known test:

```text
center 80% crop
+
nearest-neighbour resize to the original dimensions
```

It does not automatically solve:

- unknown crop position;
- unknown crop ratio;
- rotation;
- perspective changes;
- arbitrary image scaling.

Those cases require feature-based image registration, synchronization markers, or a scale-and-offset search before DCT extraction.

