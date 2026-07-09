# Hidden Image Watermarking

This project develops a hidden digital image watermarking system. The system embeds ownership information into an image with minimal visible change, retrieves the hidden watermark, and evaluates image quality and robustness under common image attacks.

## Project Scope

The project compares two watermarking methods:

1. Spatial-domain watermarking using LSB embedding.
2. Transform-domain watermarking using DCT or DWT.

The project evaluates performance using:

- MSE
- PSNR
- Bit Error Rate, BER
- Normalized correlation, NC

The project tests robustness against:

- JPEG compression
- Gaussian noise
- Resizing
- Cropping

