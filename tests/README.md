# Functional Tests

This directory contains the MATLAB functional tests for the Hidden Image
Watermarking project.

The test suite checks that the LSB and DCT embedding implementations run
correctly, create their expected output files, preserve image dimensions,
write valid metadata, and reject invalid LSB bit depths.

Quality and recovery metrics are intentionally not calculated here. Run the
separate evaluation script in [`src/evaluation`](../src/evaluation/README.md)
for MSE, PSNR, BER, and NC results.

## Run the tests

From the project root, run:

```matlab
run('tests/run_all_tests.m')
```

Or use the MATLAB command line:

```bash
matlab -batch "run('tests/run_all_tests.m')"
```

## Test groups

1. **LSB embedding**
   - Runs one-bit LSB embedding.
   - Checks the watermarked image and metadata files.
   - Checks output dimensions and metadata fields.
2. **DCT embedding**
   - Runs DCT embedding.
   - Checks the watermarked image and metadata files.
   - Checks output dimensions and metadata fields.
3. **Multi-bit LSB embedding**
   - Runs two-bit LSB embedding.
   - Checks the output image and recorded bit depth.
4. **Invalid LSB bit depths**
   - Confirms that values below 1 or above 4 are rejected.

## Generated files

Test outputs are written to `data/output/test_results/`:

```text
lsb_watermarked.png
lsb_metadata.json
dct_watermarked.png
dct_metadata.json
lsb_2bit_watermarked.png
lsb_2bit_metadata.json
```

The Python test port has been removed. MATLAB is the single source of truth
for testing the MATLAB implementation.
