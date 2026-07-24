%% run_all_tests.m
% Runs and tests both LSB and DCT watermark embedding.
%
% HOW TO RUN (from MATLAB):
%   1. Open MATLAB
%   2. Navigate to the project root folder (Hidden-image-watermarking/)
%   3. Run:  run('tests/run_all_tests.m')
%
% Or from the command line (if you have MATLAB on PATH):
%   matlab -batch "run('tests/run_all_tests.m')"
%
% WHAT IT DOES:
%   - Embeds a watermark using LSB (spatial domain)
%   - Embeds a watermark using DCT (transform domain)
%   - Verifies output files are created
%   - Computes PSNR and MSE between original and watermarked images
%   - Extracts the LSB watermark back and checks accuracy
%   - Reports PASS/FAIL for each check

clc;
clear;
close all;

fprintf('==============================================\n');
fprintf('  Hidden Image Watermarking - Test Suite\n');
fprintf('==============================================\n\n');

%% Setup paths
testFolder = fileparts(mfilename('fullpath'));
projectRoot = fullfile(testFolder, '..');

% Add source folders to path so MATLAB can find the functions
addpath(fullfile(projectRoot, 'src', 'lsb_embedding'));
addpath(fullfile(projectRoot, 'src', 'transform_embedding'));

% Input files
inputImagePath = fullfile(projectRoot, 'data', 'input', 'original.png');
watermarkPath = fullfile(projectRoot, 'data', 'input', 'watermark.png');

% Output files (use a test-specific subfolder to avoid overwriting)
testOutputFolder = fullfile(projectRoot, 'data', 'output', 'test_results');
if ~exist(testOutputFolder, 'dir')
    mkdir(testOutputFolder);
end

lsbOutputPath = fullfile(testOutputFolder, 'lsb_watermarked.png');
lsbMetadataPath = fullfile(testOutputFolder, 'lsb_metadata.json');
dctOutputPath = fullfile(testOutputFolder, 'dct_watermarked.png');
dctMetadataPath = fullfile(testOutputFolder, 'dct_metadata.json');

% Track results
numPassed = 0;
numFailed = 0;

%% Verify input files exist
fprintf('--- Checking input files ---\n');
if exist(inputImagePath, 'file')
    fprintf('  [PASS] Original image found: %s\n', inputImagePath);
    numPassed = numPassed + 1;
else
    fprintf('  [FAIL] Original image NOT found: %s\n', inputImagePath);
    numFailed = numFailed + 1;
    error('Cannot continue without input image.');
end

if exist(watermarkPath, 'file')
    fprintf('  [PASS] Watermark image found: %s\n', watermarkPath);
    numPassed = numPassed + 1;
else
    fprintf('  [FAIL] Watermark image NOT found: %s\n', watermarkPath);
    numFailed = numFailed + 1;
    error('Cannot continue without watermark image.');
end

%% Read original image for later comparison
originalImg = imread(inputImagePath);
fprintf('\n');

%% ============================================================
%  TEST 1: LSB Embedding
%  ============================================================
fprintf('==============================================\n');
fprintf('  TEST 1: LSB Embedding\n');
fprintf('==============================================\n');

numBitsUsed = 1;

try
    lsb_embed(inputImagePath, watermarkPath, lsbOutputPath, lsbMetadataPath, numBitsUsed);
    fprintf('  [PASS] LSB embedding executed without error\n');
    numPassed = numPassed + 1;
catch e
    fprintf('  [FAIL] LSB embedding error: %s\n', e.message);
    numFailed = numFailed + 1;
end

% Check output file exists
if exist(lsbOutputPath, 'file')
    fprintf('  [PASS] LSB watermarked image created\n');
    numPassed = numPassed + 1;
else
    fprintf('  [FAIL] LSB watermarked image NOT created\n');
    numFailed = numFailed + 1;
end

% Check metadata file exists
if exist(lsbMetadataPath, 'file')
    fprintf('  [PASS] LSB metadata file created\n');
    numPassed = numPassed + 1;
else
    fprintf('  [FAIL] LSB metadata file NOT created\n');
    numFailed = numFailed + 1;
end

% Compute PSNR and MSE for LSB
if exist(lsbOutputPath, 'file')
    lsbImg = imread(lsbOutputPath);

    % MSE
    mseVal = mean((double(originalImg(:)) - double(lsbImg(:))).^2);
    fprintf('  LSB MSE:  %.4f\n', mseVal);

    % PSNR
    if mseVal > 0
        psnrVal = 10 * log10(255^2 / mseVal);
    else
        psnrVal = Inf;
    end
    fprintf('  LSB PSNR: %.2f dB\n', psnrVal);

    % PSNR should be high for 1-bit LSB (typically > 40 dB)
    if psnrVal > 30
        fprintf('  [PASS] LSB PSNR is acceptable (> 30 dB)\n');
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] LSB PSNR is too low (%.2f dB)\n', psnrVal);
        numFailed = numFailed + 1;
    end

    % Verify image dimensions match
    if isequal(size(originalImg), size(lsbImg))
        fprintf('  [PASS] LSB output dimensions match original\n');
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] LSB output dimensions do not match original\n');
        numFailed = numFailed + 1;
    end

    % Basic LSB extraction test: read back the watermark from the blue channel
    watermarkOrig = imread(watermarkPath);
    if size(watermarkOrig, 3) == 3
        wmDouble = double(watermarkOrig);
        wmGray = 0.299 * wmDouble(:,:,1) + 0.587 * wmDouble(:,:,2) + 0.114 * wmDouble(:,:,3);
    else
        wmGray = double(watermarkOrig);
    end
    wmBinary = wmGray > 128;
    [wmH, wmW] = size(wmBinary);
    wmBits = wmBinary(:);
    numWmBits = length(wmBits);

    blueChannel = lsbImg(:,:,3);
    extractedBits = zeros(numWmBits, 1);
    bitIdx = 1;
    for px = 1:numel(blueChannel)
        if bitIdx > numWmBits
            break;
        end
        extractedBits(bitIdx) = bitand(uint8(blueChannel(px)), uint8(1));
        bitIdx = bitIdx + 1;
    end

    % Bit accuracy
    correctBits = sum(extractedBits == wmBits);
    bitAccuracy = correctBits / numWmBits * 100;
    fprintf('  LSB Extraction Bit Accuracy: %.2f%%\n', bitAccuracy);

    if bitAccuracy > 99
        fprintf('  [PASS] LSB watermark extraction accuracy > 99%%\n');
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] LSB watermark extraction accuracy too low (%.2f%%)\n', bitAccuracy);
        numFailed = numFailed + 1;
    end
end

% Validate metadata content
if exist(lsbMetadataPath, 'file')
    fid = fopen(lsbMetadataPath, 'r');
    metaText = fread(fid, '*char')';
    fclose(fid);
    metaData = jsondecode(metaText);

    if strcmp(metaData.method, 'LSB spatial-domain watermarking')
        fprintf('  [PASS] LSB metadata method field is correct\n');
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] LSB metadata method field is incorrect\n');
        numFailed = numFailed + 1;
    end
end

fprintf('\n');

%% ============================================================
%  TEST 2: DCT Embedding
%  ============================================================
fprintf('==============================================\n');
fprintf('  TEST 2: DCT Embedding\n');
fprintf('==============================================\n');

strength = 20;

try
    dct_embed(inputImagePath, watermarkPath, dctOutputPath, dctMetadataPath, strength);
    fprintf('  [PASS] DCT embedding executed without error\n');
    numPassed = numPassed + 1;
catch e
    fprintf('  [FAIL] DCT embedding error: %s\n', e.message);
    numFailed = numFailed + 1;
end

% Check output file exists
if exist(dctOutputPath, 'file')
    fprintf('  [PASS] DCT watermarked image created\n');
    numPassed = numPassed + 1;
else
    fprintf('  [FAIL] DCT watermarked image NOT created\n');
    numFailed = numFailed + 1;
end

% Check metadata file exists
if exist(dctMetadataPath, 'file')
    fprintf('  [PASS] DCT metadata file created\n');
    numPassed = numPassed + 1;
else
    fprintf('  [FAIL] DCT metadata file NOT created\n');
    numFailed = numFailed + 1;
end

% Compute PSNR and MSE for DCT
if exist(dctOutputPath, 'file')
    dctImg = imread(dctOutputPath);

    % MSE
    mseVal = mean((double(originalImg(:)) - double(dctImg(:))).^2);
    fprintf('  DCT MSE:  %.4f\n', mseVal);

    % PSNR
    if mseVal > 0
        psnrVal = 10 * log10(255^2 / mseVal);
    else
        psnrVal = Inf;
    end
    fprintf('  DCT PSNR: %.2f dB\n', psnrVal);

    % DCT PSNR should be reasonable (typically > 25 dB)
    if psnrVal > 25
        fprintf('  [PASS] DCT PSNR is acceptable (> 25 dB)\n');
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] DCT PSNR is too low (%.2f dB)\n', psnrVal);
        numFailed = numFailed + 1;
    end

    % Verify image dimensions match
    if isequal(size(originalImg), size(dctImg))
        fprintf('  [PASS] DCT output dimensions match original\n');
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] DCT output dimensions do not match original\n');
        numFailed = numFailed + 1;
    end
end

% Validate metadata content
if exist(dctMetadataPath, 'file')
    fid = fopen(dctMetadataPath, 'r');
    metaText = fread(fid, '*char')';
    fclose(fid);
    metaData = jsondecode(metaText);

    if strcmp(metaData.method, 'DCT transform-domain watermarking')
        fprintf('  [PASS] DCT metadata method field is correct\n');
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] DCT metadata method field is incorrect\n');
        numFailed = numFailed + 1;
    end

    if metaData.strength == strength
        fprintf('  [PASS] DCT metadata strength value is correct\n');
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] DCT metadata strength value is incorrect\n');
        numFailed = numFailed + 1;
    end
end

fprintf('\n');

%% ============================================================
%  TEST 3: LSB with multiple bit depths
%  ============================================================
fprintf('==============================================\n');
fprintf('  TEST 3: LSB Multi-Bit Embedding (2-bit)\n');
fprintf('==============================================\n');

lsb2OutputPath = fullfile(testOutputFolder, 'lsb_2bit_watermarked.png');
lsb2MetadataPath = fullfile(testOutputFolder, 'lsb_2bit_metadata.json');

try
    lsb_embed(inputImagePath, watermarkPath, lsb2OutputPath, lsb2MetadataPath, 2);
    fprintf('  [PASS] LSB 2-bit embedding executed without error\n');
    numPassed = numPassed + 1;

    if exist(lsb2OutputPath, 'file')
        lsb2Img = imread(lsb2OutputPath);
        mseVal = mean((double(originalImg(:)) - double(lsb2Img(:))).^2);
        psnrVal = 10 * log10(255^2 / mseVal);
        fprintf('  LSB 2-bit PSNR: %.2f dB\n', psnrVal);

        if psnrVal > 25
            fprintf('  [PASS] LSB 2-bit PSNR is acceptable (> 25 dB)\n');
            numPassed = numPassed + 1;
        else
            fprintf('  [FAIL] LSB 2-bit PSNR is too low (%.2f dB)\n', psnrVal);
            numFailed = numFailed + 1;
        end
    end
catch e
    fprintf('  [FAIL] LSB 2-bit embedding error: %s\n', e.message);
    numFailed = numFailed + 1;
end

fprintf('\n');

%% ============================================================
%  TEST 4: Edge case - invalid numBitsUsed
%  ============================================================
fprintf('==============================================\n');
fprintf('  TEST 4: Edge Cases\n');
fprintf('==============================================\n');

try
    lsb_embed(inputImagePath, watermarkPath, lsbOutputPath, lsbMetadataPath, 5);
    fprintf('  [FAIL] LSB should reject numBitsUsed=5 but did not\n');
    numFailed = numFailed + 1;
catch e
    fprintf('  [PASS] LSB correctly rejected numBitsUsed=5: %s\n', e.message);
    numPassed = numPassed + 1;
end

try
    lsb_embed(inputImagePath, watermarkPath, lsbOutputPath, lsbMetadataPath, 0);
    fprintf('  [FAIL] LSB should reject numBitsUsed=0 but did not\n');
    numFailed = numFailed + 1;
catch e
    fprintf('  [PASS] LSB correctly rejected numBitsUsed=0: %s\n', e.message);
    numPassed = numPassed + 1;
end

fprintf('\n');

%% ============================================================
%  TEST 5: Visual Watermark Mapping Verification
%  ============================================================
fprintf('==============================================\n');
fprintf('  TEST 5: Visual Watermark Mapping Verification\n');
fprintf('==============================================\n');

visualFolder = fullfile(testOutputFolder, 'visual_verification');
if ~exist(visualFolder, 'dir')
    mkdir(visualFolder);
end

% 5a. Amplified difference image (LSB)
if exist(lsbOutputPath, 'file')
    lsbImg = imread(lsbOutputPath);
    diff = abs(double(originalImg) - double(lsbImg));
    diffAmplified = uint8(min(diff * 50, 255));
    diffPath = fullfile(visualFolder, 'lsb_difference_amplified.png');
    imwrite(diffAmplified, diffPath);
    if exist(diffPath, 'file')
        fprintf('  [PASS] LSB amplified difference image saved: %s\n', diffPath);
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] LSB amplified difference image NOT saved\n');
        numFailed = numFailed + 1;
    end

    % Verify changes only in blue channel
    redDiff = sum(sum(diff(:,:,1)));
    greenDiff = sum(sum(diff(:,:,2)));
    blueDiff = sum(sum(diff(:,:,3)));
    if redDiff == 0 && greenDiff == 0 && blueDiff > 0
        fprintf('  [PASS] LSB changes only in blue channel (R=%d, G=%d, B=%d)\n', redDiff, greenDiff, blueDiff);
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] LSB changes not isolated to blue channel (R=%d, G=%d, B=%d)\n', redDiff, greenDiff, blueDiff);
        numFailed = numFailed + 1;
    end
end

% 5b. Amplified difference image (DCT)
if exist(dctOutputPath, 'file')
    dctImg = imread(dctOutputPath);
    diff = abs(double(originalImg) - double(dctImg));
    diffAmplified = uint8(min(diff * 50, 255));
    diffPath = fullfile(visualFolder, 'dct_difference_amplified.png');
    imwrite(diffAmplified, diffPath);
    if exist(diffPath, 'file')
        fprintf('  [PASS] DCT amplified difference image saved: %s\n', diffPath);
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] DCT amplified difference image NOT saved\n');
        numFailed = numFailed + 1;
    end
end

% 5c. Extract and display watermark from LSB
if exist(lsbOutputPath, 'file')
    lsbImg = imread(lsbOutputPath);
    watermarkOrig = imread(watermarkPath);
    if size(watermarkOrig, 3) == 3
        wmDouble = double(watermarkOrig);
        wmGray = 0.299 * wmDouble(:,:,1) + 0.587 * wmDouble(:,:,2) + 0.114 * wmDouble(:,:,3);
    else
        wmGray = double(watermarkOrig);
    end
    wmBinary = wmGray > 128;
    [wmH, wmW] = size(wmBinary);
    wmBits = wmBinary(:);
    numWmBits = length(wmBits);

    blueChannel = lsbImg(:,:,3);
    extractedBits = zeros(numWmBits, 1);
    for px = 1:numWmBits
        extractedBits(px) = bitand(uint8(blueChannel(px)), uint8(1));
    end
    extractedWm = reshape(extractedBits, [wmH, wmW]);

    % Save original watermark (binarized)
    origWmPath = fullfile(visualFolder, 'watermark_original.png');
    imwrite(uint8(wmBinary * 255), origWmPath);

    % Save extracted watermark
    extractedWmPath = fullfile(visualFolder, 'watermark_extracted_lsb.png');
    imwrite(uint8(extractedWm * 255), extractedWmPath);
    if exist(extractedWmPath, 'file')
        fprintf('  [PASS] Extracted LSB watermark image saved: %s\n', extractedWmPath);
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] Extracted LSB watermark image NOT saved\n');
        numFailed = numFailed + 1;
    end

    % Check pixel-perfect match
    if isequal(extractedWm, wmBinary)
        fprintf('  [PASS] Extracted LSB watermark is pixel-perfect match to original\n');
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] Extracted LSB watermark does NOT match original\n');
        numFailed = numFailed + 1;
    end
end

% 5d. DCT block usage heatmap
if exist(dctMetadataPath, 'file')
    fid = fopen(dctMetadataPath, 'r');
    metaText = fread(fid, '*char')';
    fclose(fid);
    dctMeta = jsondecode(metaText);

    origH = dctMeta.originalHeight;
    origW = dctMeta.originalWidth;
    paddedH = dctMeta.paddedHeight;
    paddedW = dctMeta.paddedWidth;
    blkSize = dctMeta.blockSize;
    numBlocksW = paddedW / blkSize;
    numBlocksH = paddedH / blkSize;

    watermarkOrig = imread(watermarkPath);
    if size(watermarkOrig, 3) == 3
        wmDouble = double(watermarkOrig);
        wmGray = 0.299 * wmDouble(:,:,1) + 0.587 * wmDouble(:,:,2) + 0.114 * wmDouble(:,:,3);
    else
        wmGray = double(watermarkOrig);
    end
    wmBinary = wmGray > 128;
    numBitsDCT = numel(wmBinary);
    maxBitsDCT = numBlocksH * numBlocksW;
    selectedIndices = round(linspace(1, maxBitsDCT, numBitsDCT));

    % Create heatmap
    heatmap = zeros(origH, origW, 'uint8');
    for i = 1:length(selectedIndices)
        blockIndex = selectedIndices(i);
        blockRow = floor((blockIndex - 1) / numBlocksW) + 1;
        blockCol = mod(blockIndex - 1, numBlocksW) + 1;
        rowStart = (blockRow - 1) * blkSize + 1;
        colStart = (blockCol - 1) * blkSize + 1;
        rowEnd = min(rowStart + blkSize - 1, origH);
        colEnd = min(colStart + blkSize - 1, origW);
        heatmap(rowStart:rowEnd, colStart:colEnd) = 255;
    end

    heatmapPath = fullfile(visualFolder, 'dct_block_heatmap.png');
    imwrite(heatmap, heatmapPath);
    if exist(heatmapPath, 'file')
        fprintf('  [PASS] DCT block usage heatmap saved: %s\n', heatmapPath);
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] DCT block usage heatmap NOT saved\n');
        numFailed = numFailed + 1;
    end

    % Verify blocks are spread evenly across the image
    rowsUsed = unique(floor((selectedIndices - 1) / numBlocksW) + 1);
    colsUsed = unique(mod(selectedIndices - 1, numBlocksW) + 1);
    rowCoverage = length(rowsUsed) / numBlocksH;
    colCoverage = length(colsUsed) / numBlocksW;
    if rowCoverage >= 0.8 && colCoverage >= 0.8
        fprintf('  [PASS] DCT blocks spread evenly (row coverage: %.0f%%, col coverage: %.0f%%)\n', rowCoverage*100, colCoverage*100);
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] DCT blocks not spread evenly (row coverage: %.0f%%, col coverage: %.0f%%)\n', rowCoverage*100, colCoverage*100);
        numFailed = numFailed + 1;
    end
end

% 5e. Side-by-side comparison images
if exist(lsbOutputPath, 'file')
    lsbImg = imread(lsbOutputPath);
    [h, ~, ~] = size(originalImg);
    separator = uint8(128 * ones(h, 10, 3));
    sideBySide = cat(2, originalImg, separator, lsbImg);
    sbsPath = fullfile(visualFolder, 'lsb_side_by_side.png');
    imwrite(sideBySide, sbsPath);
    if exist(sbsPath, 'file')
        fprintf('  [PASS] LSB side-by-side comparison saved: %s\n', sbsPath);
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] LSB side-by-side comparison NOT saved\n');
        numFailed = numFailed + 1;
    end
end

if exist(dctOutputPath, 'file')
    dctImg = imread(dctOutputPath);
    [h, ~, ~] = size(originalImg);
    separator = uint8(128 * ones(h, 10, 3));
    sideBySide = cat(2, originalImg, separator, dctImg);
    sbsPath = fullfile(visualFolder, 'dct_side_by_side.png');
    imwrite(sideBySide, sbsPath);
    if exist(sbsPath, 'file')
        fprintf('  [PASS] DCT side-by-side comparison saved: %s\n', sbsPath);
        numPassed = numPassed + 1;
    else
        fprintf('  [FAIL] DCT side-by-side comparison NOT saved\n');
        numFailed = numFailed + 1;
    end
end

fprintf('\n  Visual verification images saved to: %s\n', visualFolder);
fprintf('\n');

%% ============================================================
%  Summary
%  ============================================================
fprintf('==============================================\n');
fprintf('  TEST SUMMARY\n');
fprintf('==============================================\n');
fprintf('  Passed: %d\n', numPassed);
fprintf('  Failed: %d\n', numFailed);
fprintf('  Total:  %d\n', numPassed + numFailed);
fprintf('==============================================\n');

if numFailed == 0
    fprintf('  ALL TESTS PASSED!\n');
else
    fprintf('  SOME TESTS FAILED.\n');
end

fprintf('==============================================\n');

% Clean up path
rmpath(fullfile(projectRoot, 'src', 'lsb_embedding'));
rmpath(fullfile(projectRoot, 'src', 'transform_embedding'));
