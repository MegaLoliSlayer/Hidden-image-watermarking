# Transform-Domain Embedding

This folder contains the **DCT transform-domain embedding** part of our hidden image watermarking project.

The main idea is simple: instead of directly changing image pixels like LSB embedding, we first convert small image blocks into frequency values using DCT, then hide the watermark by slightly changing some of those frequency values.


## Folder structure

The project should look like this:

```text
Hidden-image-watermarking
├── data
│   ├── input
│   │   ├── original.png
│   │   └── watermark.png
│   │
│   └── output
│
├── src
│   ├── lsb_embedding
│   ├── transform_embedding
│   │   ├── dct_embed.m
│   │   ├── run_dct_embed.m
│   │   └── README.md
│   │
│   ├── retrieval
│   └── evaluation
│
├── results
├── docs
└── tests
```

For this part, the important files are:

```text
src/transform_embedding/dct_embed.m
src/transform_embedding/run_dct_embed.m
```

## Input files

Before running the DCT embedding code, make sure these two files exist:

```text
data/input/original.png
data/input/watermark.png
```

`original.png` is the image we want to hide the watermark inside.

`watermark.png` is the watermark image. It should be a small black-and-white image. A `32 × 32` or `64 × 64` watermark is a good size for testing.

## How to run DCT embedding

Open MATLAB and go to the project root folder:

```matlab
cd('D:\Hidden-image-watermarking')
```

Add the transform embedding folder to the MATLAB path:

```matlab
addpath('src/transform_embedding')
```

Run the embedding script:

```matlab
run('src/transform_embedding/run_dct_embed.m')
```

After running, the code should create these files:

```text
data/output/dct_watermarked.png
data/output/dct_metadata.json
```

`dct_watermarked.png` is the image after the watermark has been embedded.

`dct_metadata.json` stores the information needed for retrieval.


## Embedding strength

The embedding strength is set in `run_dct_embed.m`:

```matlab
strength = 20;
```

This value controls how strongly the watermark is embedded.

| Strength | Meaning                                        |
|----------|------------------------------------------------|
| `20`     | Good default value                             |
| `50`     | Stronger watermark                             |
| `100+`   | More robust, but may make the image look worse |

A higher strength makes the watermark easier to retrieve, but it may create more visible distortion.

A lower strength keeps the image closer to the original, but the watermark may be easier to damage.


## What the DCT embedding code does

The embedding process is:

1. Read `original.png`.
2. Convert the RGB image into brightness information.
3. Use the brightness channel as the embedding area.
4. Pad the image so the height and width are divisible by `8`.
5. Divide the image into `8 × 8` blocks.
6. Read `watermark.png`.
7. Convert the watermark into binary bits, where each pixel becomes either `0` or `1`.
8. Select DCT blocks spread across the whole image.
9. Apply DCT to each selected block.
10. Embed one watermark bit into each selected block.
11. Apply inverse DCT to rebuild the image block.
12. Convert the image back to RGB.
13. Save the watermarked image.
14. Save metadata for retrieval.


## Why we use DCT

DCT stands for **Discrete Cosine Transform**.

In normal pixel form, the image is stored as color/brightness values. After DCT, each `8 × 8` block is represented as frequency coefficients.

In simple words:

- Low-frequency coefficients control the main shape and brightness of the block.
- High-frequency coefficients control small details and noise.
- Mid-frequency coefficients are in between.

For watermarking, we use **mid-frequency coefficients** because they are a good balance:

- Changing low-frequency coefficients can make the image look obviously different.
- Changing high-frequency coefficients may be removed easily by compression or noise.
- Mid-frequency coefficients are less visible but still more robust than high-frequency coefficients.


## Exact embedding rule

This is the most important part for the retrieval.

Each selected `8 × 8` block stores **one watermark bit**.

Inside each DCT block, we use two coefficient positions:

```matlab
coeff1 = [4, 5];
coeff2 = [5, 4];
```

That means:

```matlab
c1 = dctBlock(4, 5);
c2 = dctBlock(5, 4);
```

The code embeds the bit by changing the relationship between `c1` and `c2`.

For watermark bit `1`:

```text
c1 > c2
```

For watermark bit `0`:

```text
c2 > c1
```

So retrieval should reverse this rule:

```matlab
if c1 > c2
    extractedBit = 1;
else
    extractedBit = 0;
end
```

Use the same coefficient positions saved in metadata.


## Why the watermark is spread across the image

The code does not just start at the top-left corner and embed every bit one by one.

Instead, it spreads the selected blocks across the whole image using:

```matlab
selectedBlockIndices = round(linspace(1, maxBits, numBits));
```

This prevents all watermark changes from appearing only at the top of the image.

For example, if the image has 30,000 available blocks but the watermark only has 4,096 bits, the code selects 4,096 block positions spread across the full image.

This means the retrieval process must use the same selected block positions.


## Metadata saved for retrieval

After embedding, the code saves this file:

```text
data/output/dct_metadata.json
```

This file saves the important information might be needed for retrival.

Important fields inside the metadata:

```text
blockSize
coeff1
coeff2
selectedBlockIndices
watermarkHeight
watermarkWidth
numEmbeddedBits
paddedHeight
paddedWidth
strength
```

The most important values are:

```text
blockSize = 8
coeff1 = [4, 5]
coeff2 = [5, 4]
selectedBlockIndices = exact block locations used for embedding
```

The retrieval code must use the same values, especially `selectedBlockIndices`.


## Direction for the retrieval 

The retrieval code should do the reverse of embedding.

Basic retrieval process:

1. Read `data/output/dct_watermarked.png`.
2. Read `data/output/dct_metadata.json`.
3. Convert the watermarked RGB image into the same brightness channel `Y`.
4. Pad the `Y` channel to the same size using `paddedHeight` and `paddedWidth`.
5. Read `selectedBlockIndices` from metadata.
6. For each selected block:
   - Convert the selected block index into block row and block column.
   - Extract the same `8 × 8` block.
   - Apply DCT using the same DCT matrix.
   - Read `dctBlock(4,5)` and `dctBlock(5,4)`.
   - If `dctBlock(4,5) > dctBlock(5,4)`, extract bit `1`.
   - Otherwise, extract bit `0`.
7. After all bits are extracted, reshape the bit sequence back into the original watermark size.

The reshape step should use:

```matlab
extractedWatermark = reshape(extractedBits, watermarkHeight, watermarkWidth);
```

This matters because the embedding code converts the watermark into bits using:

```matlab
watermarkBits = watermarkBinary(:);
```

MATLAB stores arrays in column-major order, so retrieval should reshape in the same MATLAB way.

## How to check if embedding worked

You can vary the strength value to like 1000, if you see a obvious distortion on the image, it is embedded.

But the recommended way to check is:

1. Run DCT embedding.
2. Run DCT retrieval.
3. Compare the extracted watermark with the original `watermark.png`.


## To get the same result on different computers

Everyone should use the same:

- `data/input/original.png`
- `data/input/watermark.png`
- `strength` value
- `dct_embed.m`
- `run_dct_embed.m`
