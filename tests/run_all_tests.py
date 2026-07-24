#!/usr/bin/env python3
"""
run_all_tests.py - Test both LSB and DCT watermark embedding.

HOW TO RUN:
    1. Install dependencies:  pip install numpy Pillow
    2. From the project root:  python tests/run_all_tests.py

This is a Python port of the MATLAB LSB and DCT embedding logic,
used to test both methods without requiring a MATLAB license.
"""

import os
import sys
import json
import math
import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# Path setup
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.join(SCRIPT_DIR, "..")

INPUT_IMAGE = os.path.join(PROJECT_ROOT, "data", "input", "original.png")
WATERMARK_IMAGE = os.path.join(PROJECT_ROOT, "data", "input", "watermark.png")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "data", "output", "test_results")

os.makedirs(OUTPUT_DIR, exist_ok=True)

passed = 0
failed = 0


def report(ok, msg):
    global passed, failed
    if ok:
        print(f"  [PASS] {msg}")
        passed += 1
    else:
        print(f"  [FAIL] {msg}")
        failed += 1


# ---------------------------------------------------------------------------
# Helper: binarize watermark
# ---------------------------------------------------------------------------
def load_watermark_bits(path):
    """Load watermark image and return binary bits array plus dimensions."""
    wm = np.array(Image.open(path))
    if wm.ndim == 3:
        wm_gray = 0.299 * wm[:, :, 0] + 0.587 * wm[:, :, 1] + 0.114 * wm[:, :, 2]
    else:
        wm_gray = wm.astype(float)
    wm_binary = (wm_gray > 128).astype(np.uint8)
    return wm_binary, wm_binary.flatten()


# ---------------------------------------------------------------------------
# LSB Embedding (Python port)
# ---------------------------------------------------------------------------
def lsb_embed(input_path, watermark_path, output_path, metadata_path, num_bits=1):
    """Embed watermark using LSB method in the blue channel."""
    if num_bits < 1 or num_bits > 4:
        raise ValueError("numBitsUsed must be between 1 and 4.")

    img = np.array(Image.open(input_path))
    if img.ndim != 3 or img.shape[2] < 3:
        raise ValueError("Input image must be an RGB image.")
    img_h, img_w = img.shape[:2]

    wm_binary, wm_bits = load_watermark_bits(watermark_path)
    wm_h, wm_w = wm_binary.shape
    num_wm_bits = len(wm_bits)

    max_capacity = img_h * img_w * num_bits
    if num_wm_bits > max_capacity:
        raise ValueError("Watermark is too large for this image.")

    # Work on blue channel
    blue = img[:, :, 2].astype(np.int32).flatten()
    clear_mask = 256 - (2 ** num_bits)

    bit_index = 0
    for px in range(img_h * img_w):
        if bit_index >= num_wm_bits:
            break
        pixel_val = int(blue[px]) & clear_mask
        bits_to_embed = 0
        for b in range(num_bits):
            if bit_index < num_wm_bits:
                bits_to_embed += int(wm_bits[bit_index]) * (2 ** (num_bits - 1 - b))
                bit_index += 1
        blue[px] = pixel_val + bits_to_embed

    watermarked = img.copy()
    watermarked[:, :, 2] = blue.reshape(img_h, img_w).astype(np.uint8)
    Image.fromarray(watermarked).save(output_path)

    metadata = {
        "method": "LSB spatial-domain watermarking",
        "inputImage": input_path,
        "watermarkImage": watermark_path,
        "outputImage": output_path,
        "imageHeight": img_h,
        "imageWidth": img_w,
        "watermarkHeight": wm_h,
        "watermarkWidth": wm_w,
        "numWatermarkBits": num_wm_bits,
        "numBitsUsed": num_bits,
        "embeddingChannel": "Blue (channel 3)",
        "embeddingOrder": "Raster order (row-major)",
    }
    with open(metadata_path, "w") as f:
        json.dump(metadata, f)

    print(f"  LSB embedding complete -> {output_path}")
    return watermarked


# ---------------------------------------------------------------------------
# DCT Embedding (Python port)
# ---------------------------------------------------------------------------
def create_dct_matrix(n):
    """Create an NxN DCT transform matrix."""
    D = np.zeros((n, n))
    for k in range(n):
        for nn in range(n):
            alpha = math.sqrt(1.0 / n) if k == 0 else math.sqrt(2.0 / n)
            D[k, nn] = alpha * math.cos(((2 * nn + 1) * k * math.pi) / (2 * n))
    return D


def dct_embed(input_path, watermark_path, output_path, metadata_path, strength=20):
    """Embed watermark using DCT method in the Y channel."""
    block_size = 8

    img = np.array(Image.open(input_path))
    if img.ndim != 3 or img.shape[2] < 3:
        raise ValueError("Input image must be an RGB image.")

    img_double = img.astype(np.float64)
    R, G, B = img_double[:, :, 0], img_double[:, :, 1], img_double[:, :, 2]

    Y = 0.299 * R + 0.587 * G + 0.114 * B
    Cb = 128 - 0.168736 * R - 0.331264 * G + 0.5 * B
    Cr = 128 + 0.5 * R - 0.418688 * G - 0.081312 * B

    orig_h, orig_w = Y.shape

    pad_h = (block_size - (orig_h % block_size)) % block_size
    pad_w = (block_size - (orig_w % block_size)) % block_size
    padded_h = orig_h + pad_h
    padded_w = orig_w + pad_w

    padded_y = np.zeros((padded_h, padded_w))
    padded_y[:orig_h, :orig_w] = Y
    if pad_h > 0:
        padded_y[orig_h:, :orig_w] = np.tile(Y[-1, :], (pad_h, 1))
    if pad_w > 0:
        padded_y[:, orig_w:] = np.tile(padded_y[:, orig_w - 1 : orig_w], (1, pad_w))

    num_blocks_h = padded_h // block_size
    num_blocks_w = padded_w // block_size
    max_bits = num_blocks_h * num_blocks_w

    wm_binary, wm_bits = load_watermark_bits(watermark_path)
    wm_h, wm_w = wm_binary.shape
    num_bits = len(wm_bits)

    if num_bits > max_bits:
        raise ValueError("Watermark is too large for this image.")

    # DCT coefficient positions (0-indexed: [3,4] and [4,3] = MATLAB [4,5] and [5,4])
    coeff1 = (3, 4)
    coeff2 = (4, 3)
    D = create_dct_matrix(block_size)

    # Spread blocks evenly
    selected = np.round(np.linspace(0, max_bits - 1, num_bits)).astype(int)

    for i in range(num_bits):
        block_idx = selected[i]
        block_row = block_idx // num_blocks_w
        block_col = block_idx % num_blocks_w
        r_start = block_row * block_size
        c_start = block_col * block_size
        block = padded_y[r_start : r_start + block_size, c_start : c_start + block_size]

        dct_block = D @ block @ D.T

        bit = wm_bits[i]
        c1 = dct_block[coeff1]
        c2 = dct_block[coeff2]

        if bit == 1:
            if c1 <= c2 + strength:
                avg = (c1 + c2) / 2
                dct_block[coeff1] = avg + strength / 2
                dct_block[coeff2] = avg - strength / 2
        else:
            if c2 <= c1 + strength:
                avg = (c1 + c2) / 2
                dct_block[coeff1] = avg - strength / 2
                dct_block[coeff2] = avg + strength / 2

        modified_block = D.T @ dct_block @ D
        padded_y[r_start : r_start + block_size, c_start : c_start + block_size] = modified_block

    modified_y = padded_y[:orig_h, :orig_w]

    new_r = modified_y + 1.402 * (Cr - 128)
    new_g = modified_y - 0.344136 * (Cb - 128) - 0.714136 * (Cr - 128)
    new_b = modified_y + 1.772 * (Cb - 128)

    watermarked = np.stack([new_r, new_g, new_b], axis=2)
    watermarked = np.clip(watermarked, 0, 255).astype(np.uint8)
    Image.fromarray(watermarked).save(output_path)

    metadata = {
        "method": "DCT transform-domain watermarking",
        "inputImage": input_path,
        "watermarkImage": watermark_path,
        "outputImage": output_path,
        "originalHeight": orig_h,
        "originalWidth": orig_w,
        "paddedHeight": padded_h,
        "paddedWidth": padded_w,
        "watermarkHeight": wm_h,
        "watermarkWidth": wm_w,
        "numEmbeddedBits": num_bits,
        "strength": strength,
        "blockSize": block_size,
        "coeff1": list(coeff1),
        "coeff2": list(coeff2),
        "channel": "Manual Y channel from RGB to YCbCr conversion",
    }
    with open(metadata_path, "w") as f:
        json.dump(metadata, f)

    print(f"  DCT embedding complete -> {output_path}")
    return watermarked


# ---------------------------------------------------------------------------
# Quality metrics
# ---------------------------------------------------------------------------
def compute_mse(img1, img2):
    return np.mean((img1.astype(float) - img2.astype(float)) ** 2)


def compute_psnr(img1, img2):
    mse = compute_mse(img1, img2)
    if mse == 0:
        return float("inf")
    return 10 * math.log10(255**2 / mse)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
def main():
    global passed, failed

    print("=" * 50)
    print("  Hidden Image Watermarking - Python Test Suite")
    print("=" * 50)
    print()

    # Check inputs
    print("--- Checking input files ---")
    report(os.path.isfile(INPUT_IMAGE), f"Original image found: {INPUT_IMAGE}")
    report(os.path.isfile(WATERMARK_IMAGE), f"Watermark image found: {WATERMARK_IMAGE}")

    if not os.path.isfile(INPUT_IMAGE) or not os.path.isfile(WATERMARK_IMAGE):
        print("\nCannot continue without input files.")
        sys.exit(1)

    original = np.array(Image.open(INPUT_IMAGE))
    print()

    # ---- TEST 1: LSB Embedding ----
    print("=" * 50)
    print("  TEST 1: LSB Embedding (1-bit)")
    print("=" * 50)
    lsb_out = os.path.join(OUTPUT_DIR, "lsb_watermarked.png")
    lsb_meta = os.path.join(OUTPUT_DIR, "lsb_metadata.json")

    try:
        lsb_embed(INPUT_IMAGE, WATERMARK_IMAGE, lsb_out, lsb_meta, 1)
        report(True, "LSB embedding executed without error")
    except Exception as e:
        report(False, f"LSB embedding error: {e}")

    report(os.path.isfile(lsb_out), "LSB watermarked image created")
    report(os.path.isfile(lsb_meta), "LSB metadata file created")

    if os.path.isfile(lsb_out):
        lsb_img = np.array(Image.open(lsb_out))
        mse = compute_mse(original, lsb_img)
        psnr = compute_psnr(original, lsb_img)
        print(f"  LSB MSE:  {mse:.4f}")
        print(f"  LSB PSNR: {psnr:.2f} dB")
        report(psnr > 30, f"LSB PSNR is acceptable (> 30 dB): {psnr:.2f} dB")
        report(original.shape == lsb_img.shape, "LSB output dimensions match original")

        # Extract watermark back
        _, wm_bits = load_watermark_bits(WATERMARK_IMAGE)
        blue = lsb_img[:, :, 2].flatten()
        extracted = np.array([b & 1 for b in blue[: len(wm_bits)]], dtype=np.uint8)
        accuracy = np.sum(extracted == wm_bits) / len(wm_bits) * 100
        print(f"  LSB Extraction Bit Accuracy: {accuracy:.2f}%")
        report(accuracy > 99, f"LSB watermark extraction accuracy > 99%: {accuracy:.2f}%")

    if os.path.isfile(lsb_meta):
        with open(lsb_meta) as f:
            meta = json.load(f)
        report(
            meta.get("method") == "LSB spatial-domain watermarking",
            "LSB metadata method field is correct",
        )

    print()

    # ---- TEST 2: DCT Embedding ----
    print("=" * 50)
    print("  TEST 2: DCT Embedding")
    print("=" * 50)
    dct_out = os.path.join(OUTPUT_DIR, "dct_watermarked.png")
    dct_meta = os.path.join(OUTPUT_DIR, "dct_metadata.json")
    strength = 20

    try:
        dct_embed(INPUT_IMAGE, WATERMARK_IMAGE, dct_out, dct_meta, strength)
        report(True, "DCT embedding executed without error")
    except Exception as e:
        report(False, f"DCT embedding error: {e}")

    report(os.path.isfile(dct_out), "DCT watermarked image created")
    report(os.path.isfile(dct_meta), "DCT metadata file created")

    if os.path.isfile(dct_out):
        dct_img = np.array(Image.open(dct_out))
        mse = compute_mse(original, dct_img)
        psnr = compute_psnr(original, dct_img)
        print(f"  DCT MSE:  {mse:.4f}")
        print(f"  DCT PSNR: {psnr:.2f} dB")
        report(psnr > 25, f"DCT PSNR is acceptable (> 25 dB): {psnr:.2f} dB")
        report(original.shape == dct_img.shape, "DCT output dimensions match original")

    if os.path.isfile(dct_meta):
        with open(dct_meta) as f:
            meta = json.load(f)
        report(
            meta.get("method") == "DCT transform-domain watermarking",
            "DCT metadata method field is correct",
        )
        report(meta.get("strength") == strength, "DCT metadata strength value is correct")

    print()

    # ---- TEST 3: LSB 2-bit ----
    print("=" * 50)
    print("  TEST 3: LSB Multi-Bit Embedding (2-bit)")
    print("=" * 50)
    lsb2_out = os.path.join(OUTPUT_DIR, "lsb_2bit_watermarked.png")
    lsb2_meta = os.path.join(OUTPUT_DIR, "lsb_2bit_metadata.json")

    try:
        lsb_embed(INPUT_IMAGE, WATERMARK_IMAGE, lsb2_out, lsb2_meta, 2)
        report(True, "LSB 2-bit embedding executed without error")
        if os.path.isfile(lsb2_out):
            lsb2_img = np.array(Image.open(lsb2_out))
            psnr = compute_psnr(original, lsb2_img)
            print(f"  LSB 2-bit PSNR: {psnr:.2f} dB")
            report(psnr > 25, f"LSB 2-bit PSNR is acceptable (> 25 dB): {psnr:.2f} dB")
    except Exception as e:
        report(False, f"LSB 2-bit embedding error: {e}")

    print()

    # ---- TEST 4: Edge cases ----
    print("=" * 50)
    print("  TEST 4: Edge Cases")
    print("=" * 50)

    try:
        lsb_embed(INPUT_IMAGE, WATERMARK_IMAGE, lsb_out, lsb_meta, 5)
        report(False, "LSB should reject numBitsUsed=5 but did not")
    except ValueError:
        report(True, "LSB correctly rejected numBitsUsed=5")

    try:
        lsb_embed(INPUT_IMAGE, WATERMARK_IMAGE, lsb_out, lsb_meta, 0)
        report(False, "LSB should reject numBitsUsed=0 but did not")
    except ValueError:
        report(True, "LSB correctly rejected numBitsUsed=0")

    print()

    # ---- Summary ----
    print("=" * 50)
    print("  TEST SUMMARY")
    print("=" * 50)
    print(f"  Passed: {passed}")
    print(f"  Failed: {failed}")
    print(f"  Total:  {passed + failed}")
    print("=" * 50)
    if failed == 0:
        print("  ALL TESTS PASSED!")
    else:
        print("  SOME TESTS FAILED.")
    print("=" * 50)

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
