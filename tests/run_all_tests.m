%% run_all_tests.m
% Functional tests for the LSB and DCT watermark embedding code.
%
% This suite deliberately does not calculate MSE, PSNR, BER, or NC and
% does not recover a watermark. Run src/evaluation/run_evaluation.m for
% image-quality and watermark-recovery evaluation.
%
% The successful LSB and DCT tests also open and save diagnostic figures
% showing the original image, embedded image, visible difference maps, and
% the exact host pixels or DCT blocks assigned to the watermark payload.

clc;
clear;
close all;

fprintf('==============================================\n');
fprintf('  Hidden Image Watermarking - Test Suite\n');
fprintf('==============================================\n\n');

%% Setup
testFolder = fileparts(mfilename('fullpath'));
projectRoot = fullfile(testFolder, '..');

lsbSourceFolder = fullfile(projectRoot, 'src', 'lsb_embedding');
dctSourceFolder = fullfile(projectRoot, 'src', 'transform_embedding');
addpath(lsbSourceFolder);
addpath(dctSourceFolder);

inputImagePath = fullfile(projectRoot, 'data', 'input', 'original.png');
watermarkPath = fullfile(projectRoot, 'data', 'input', 'watermark.png');

testOutputFolder = fullfile(projectRoot, 'data', 'output', 'test_results');
if ~exist(testOutputFolder, 'dir')
    mkdir(testOutputFolder);
end

lsbOutputPath = fullfile(testOutputFolder, 'lsb_watermarked.png');
lsbMetadataPath = fullfile(testOutputFolder, 'lsb_metadata.json');
dctOutputPath = fullfile(testOutputFolder, 'dct_watermarked.png');
dctMetadataPath = fullfile(testOutputFolder, 'dct_metadata.json');
lsb2OutputPath = fullfile(testOutputFolder, 'lsb_2bit_watermarked.png');
lsb2MetadataPath = fullfile(testOutputFolder, 'lsb_2bit_metadata.json');
lsbVisualizationPath = fullfile(testOutputFolder, ...
    'lsb_embedding_visualization.png');
dctVisualizationPath = fullfile(testOutputFolder, ...
    'dct_embedding_visualization.png');

generatedFiles = {
    lsbOutputPath, lsbMetadataPath, ...
    dctOutputPath, dctMetadataPath, ...
    lsb2OutputPath, lsb2MetadataPath, ...
    lsbVisualizationPath, dctVisualizationPath
};
for fileIndex = 1:numel(generatedFiles)
    if exist(generatedFiles{fileIndex}, 'file')
        delete(generatedFiles{fileIndex});
    end
end

numPassed = 0;
numFailed = 0;

%% Check inputs
fprintf('--- Checking input files ---\n');
[numPassed, numFailed] = check_condition( ...
    exist(inputImagePath, 'file') == 2, ...
    'Original image found', 'Original image not found', ...
    numPassed, numFailed);
[numPassed, numFailed] = check_condition( ...
    exist(watermarkPath, 'file') == 2, ...
    'Watermark image found', 'Watermark image not found', ...
    numPassed, numFailed);

if ~exist(inputImagePath, 'file') || ~exist(watermarkPath, 'file')
    rmpath(lsbSourceFolder);
    rmpath(dctSourceFolder);
    error('Cannot continue without both input images.');
end

originalImage = imread(inputImagePath);

%% TEST 1: LSB embedding
fprintf('\n==============================================\n');
fprintf('  TEST 1: LSB Embedding\n');
fprintf('==============================================\n');

try
    lsb_embed(inputImagePath, watermarkPath, ...
        lsbOutputPath, lsbMetadataPath, 1);
    [numPassed, numFailed] = check_condition(true, ...
        'LSB embedding executed without error', '', ...
        numPassed, numFailed);
catch exception
    [numPassed, numFailed] = check_condition(false, '', ...
        ['LSB embedding error: ', exception.message], ...
        numPassed, numFailed);
end

[numPassed, numFailed] = check_condition( ...
    exist(lsbOutputPath, 'file') == 2, ...
    'LSB watermarked image created', ...
    'LSB watermarked image not created', ...
    numPassed, numFailed);
[numPassed, numFailed] = check_condition( ...
    exist(lsbMetadataPath, 'file') == 2, ...
    'LSB metadata file created', ...
    'LSB metadata file not created', ...
    numPassed, numFailed);

if exist(lsbOutputPath, 'file')
    lsbImage = imread(lsbOutputPath);
    [numPassed, numFailed] = check_condition( ...
        isequal(size(originalImage), size(lsbImage)), ...
        'LSB output dimensions match the original image', ...
        'LSB output dimensions do not match the original image', ...
        numPassed, numFailed);
end

if exist(lsbMetadataPath, 'file')
    lsbMetadata = read_json_file(lsbMetadataPath);
    [numPassed, numFailed] = check_condition( ...
        strcmp(lsbMetadata.method, 'LSB spatial-domain watermarking'), ...
        'LSB metadata method is correct', ...
        'LSB metadata method is incorrect', ...
        numPassed, numFailed);
    [numPassed, numFailed] = check_condition( ...
        lsbMetadata.numBitsUsed == 1, ...
        'LSB metadata bit depth is correct', ...
        'LSB metadata bit depth is incorrect', ...
        numPassed, numFailed);
end

if exist(lsbOutputPath, 'file')
    try
        create_lsb_visualization(originalImage, lsbImage, ...
            watermarkPath, 1, lsbVisualizationPath);
        [numPassed, numFailed] = check_condition( ...
            exist(lsbVisualizationPath, 'file') == 2, ...
            'LSB comparison and mapping visualization created', ...
            'LSB comparison and mapping visualization not created', ...
            numPassed, numFailed);
    catch exception
        [numPassed, numFailed] = check_condition(false, '', ...
            ['LSB visualization error: ', exception.message], ...
            numPassed, numFailed);
    end
end

%% TEST 2: DCT embedding
fprintf('\n==============================================\n');
fprintf('  TEST 2: DCT Embedding\n');
fprintf('==============================================\n');

strength = 20;
try
    dct_embed(inputImagePath, watermarkPath, ...
        dctOutputPath, dctMetadataPath, strength);
    [numPassed, numFailed] = check_condition(true, ...
        'DCT embedding executed without error', '', ...
        numPassed, numFailed);
catch exception
    [numPassed, numFailed] = check_condition(false, '', ...
        ['DCT embedding error: ', exception.message], ...
        numPassed, numFailed);
end

[numPassed, numFailed] = check_condition( ...
    exist(dctOutputPath, 'file') == 2, ...
    'DCT watermarked image created', ...
    'DCT watermarked image not created', ...
    numPassed, numFailed);
[numPassed, numFailed] = check_condition( ...
    exist(dctMetadataPath, 'file') == 2, ...
    'DCT metadata file created', ...
    'DCT metadata file not created', ...
    numPassed, numFailed);

if exist(dctOutputPath, 'file')
    dctImage = imread(dctOutputPath);
    [numPassed, numFailed] = check_condition( ...
        isequal(size(originalImage), size(dctImage)), ...
        'DCT output dimensions match the original image', ...
        'DCT output dimensions do not match the original image', ...
        numPassed, numFailed);
end

if exist(dctMetadataPath, 'file')
    dctMetadata = read_json_file(dctMetadataPath);
    [numPassed, numFailed] = check_condition( ...
        strcmp(dctMetadata.method, 'DCT transform-domain watermarking'), ...
        'DCT metadata method is correct', ...
        'DCT metadata method is incorrect', ...
        numPassed, numFailed);
    [numPassed, numFailed] = check_condition( ...
        dctMetadata.strength == strength, ...
        'DCT metadata strength is correct', ...
        'DCT metadata strength is incorrect', ...
        numPassed, numFailed);
end

if exist(dctOutputPath, 'file') && exist(dctMetadataPath, 'file')
    try
        create_dct_visualization(originalImage, dctImage, ...
            watermarkPath, dctMetadata, dctVisualizationPath);
        [numPassed, numFailed] = check_condition( ...
            exist(dctVisualizationPath, 'file') == 2, ...
            'DCT comparison and mapping visualization created', ...
            'DCT comparison and mapping visualization not created', ...
            numPassed, numFailed);
    catch exception
        [numPassed, numFailed] = check_condition(false, '', ...
            ['DCT visualization error: ', exception.message], ...
            numPassed, numFailed);
    end
end

%% TEST 3: LSB multi-bit embedding
fprintf('\n==============================================\n');
fprintf('  TEST 3: LSB Multi-Bit Embedding\n');
fprintf('==============================================\n');

try
    lsb_embed(inputImagePath, watermarkPath, ...
        lsb2OutputPath, lsb2MetadataPath, 2);
    [numPassed, numFailed] = check_condition(true, ...
        'Two-bit LSB embedding executed without error', '', ...
        numPassed, numFailed);
catch exception
    [numPassed, numFailed] = check_condition(false, '', ...
        ['Two-bit LSB embedding error: ', exception.message], ...
        numPassed, numFailed);
end

[numPassed, numFailed] = check_condition( ...
    exist(lsb2OutputPath, 'file') == 2, ...
    'Two-bit LSB watermarked image created', ...
    'Two-bit LSB watermarked image not created', ...
    numPassed, numFailed);

if exist(lsb2MetadataPath, 'file')
    lsb2Metadata = read_json_file(lsb2MetadataPath);
    [numPassed, numFailed] = check_condition( ...
        lsb2Metadata.numBitsUsed == 2, ...
        'Two-bit LSB metadata is correct', ...
        'Two-bit LSB metadata is incorrect', ...
        numPassed, numFailed);
end

%% TEST 4: Invalid LSB bit depths
fprintf('\n==============================================\n');
fprintf('  TEST 4: Invalid LSB Bit Depths\n');
fprintf('==============================================\n');

try
    lsb_embed(inputImagePath, watermarkPath, ...
        lsbOutputPath, lsbMetadataPath, 0);
    rejectedZero = false;
catch
    rejectedZero = true;
end
[numPassed, numFailed] = check_condition( ...
    rejectedZero, ...
    'LSB rejected numBitsUsed = 0', ...
    'LSB did not reject numBitsUsed = 0', ...
    numPassed, numFailed);

try
    lsb_embed(inputImagePath, watermarkPath, ...
        lsbOutputPath, lsbMetadataPath, 5);
    rejectedFive = false;
catch
    rejectedFive = true;
end
[numPassed, numFailed] = check_condition( ...
    rejectedFive, ...
    'LSB rejected numBitsUsed = 5', ...
    'LSB did not reject numBitsUsed = 5', ...
    numPassed, numFailed);

%% Summary
fprintf('\n==============================================\n');
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

rmpath(lsbSourceFolder);
rmpath(dctSourceFolder);

function [numPassed, numFailed] = check_condition( ...
    condition, passMessage, failMessage, numPassed, numFailed)
if condition
    fprintf('  [PASS] %s\n', passMessage);
    numPassed = numPassed + 1;
else
    fprintf('  [FAIL] %s\n', failMessage);
    numFailed = numFailed + 1;
end
end

function data = read_json_file(filePath)
fileId = fopen(filePath, 'r');
if fileId == -1
    error('Could not open metadata file: %s', filePath);
end
cleaner = onCleanup(@() fclose(fileId));
jsonText = fread(fileId, '*char')';
data = jsondecode(jsonText);
end

function create_lsb_visualization(originalImage, embeddedImage, ...
    watermarkPath, numBitsUsed, visualizationPath)
[watermarkBinary, watermarkBits] = read_binary_watermark(watermarkPath);
[imageHeight, imageWidth, ~] = size(originalImage);

numMappedPixels = ceil(numel(watermarkBits) / numBitsUsed);
if numMappedPixels > imageHeight * imageWidth
    error('LSB mapping exceeds the available image pixels.');
end

% lsb_embed.m uses linear MATLAB indexing. Linear indices advance down each
% column before moving to the next column, so this map intentionally shows
% the actual column-major host locations used by the current implementation.
mappedBits = nan(imageHeight, imageWidth);
for pixelIndex = 1:numMappedPixels
    firstBitIndex = (pixelIndex - 1) * numBitsUsed + 1;
    mappedBits(pixelIndex) = double(watermarkBits(firstBitIndex));
end

mappingImage = build_mapping_image(originalImage, mappedBits);
mappingTitle = sprintf([ ...
    'Mapping overlay (orange = 1, blue = 0, grayscale = unused)\n' ...
    'MATLAB column-major order; %d host pixels used'], numMappedPixels);

create_comparison_figure('LSB embedding (blue channel)', ...
    originalImage, embeddedImage, watermarkBinary, mappingImage, ...
    mappingTitle, visualizationPath);
end

function create_dct_visualization(originalImage, embeddedImage, ...
    watermarkPath, metadata, visualizationPath)
[watermarkBinary, watermarkBits] = read_binary_watermark(watermarkPath);
[imageHeight, imageWidth, ~] = size(originalImage);

blockSize = double(metadata.blockSize);
numBlocksWide = double(metadata.paddedWidth) / blockSize;
selectedBlocks = double(metadata.selectedBlockIndices(:));

if numel(selectedBlocks) ~= numel(watermarkBits)
    error('DCT metadata block count does not match the watermark bit count.');
end

% Color every selected 8x8 host block with the payload bit assigned to it.
% Blocks that extend into padding are clipped to the original image size.
mappedBits = nan(imageHeight, imageWidth);
for bitIndex = 1:numel(selectedBlocks)
    blockIndex = selectedBlocks(bitIndex);
    blockRow = floor((blockIndex - 1) / numBlocksWide) + 1;
    blockColumn = mod(blockIndex - 1, numBlocksWide) + 1;

    rowStart = (blockRow - 1) * blockSize + 1;
    columnStart = (blockColumn - 1) * blockSize + 1;
    rowEnd = min(rowStart + blockSize - 1, imageHeight);
    columnEnd = min(columnStart + blockSize - 1, imageWidth);

    if rowStart <= imageHeight && columnStart <= imageWidth
        mappedBits(rowStart:rowEnd, columnStart:columnEnd) = ...
            double(watermarkBits(bitIndex));
    end
end

mappingImage = build_mapping_image(originalImage, mappedBits);
mappingTitle = sprintf([ ...
    'Mapping overlay (orange = 1, blue = 0, grayscale = unused)\n' ...
    '%d blocks selected across the image'], numel(selectedBlocks));

create_comparison_figure('DCT embedding (Y-channel blocks)', ...
    originalImage, embeddedImage, watermarkBinary, mappingImage, ...
    mappingTitle, visualizationPath);
end

function [watermarkBinary, watermarkBits] = ...
    read_binary_watermark(watermarkPath)
watermark = imread(watermarkPath);
if size(watermark, 3) == 3
    watermarkDouble = double(watermark);
    watermarkGray = 0.299 * watermarkDouble(:, :, 1) + ...
                    0.587 * watermarkDouble(:, :, 2) + ...
                    0.114 * watermarkDouble(:, :, 3);
else
    watermarkGray = double(watermark);
end

watermarkBinary = watermarkGray > 128;
watermarkBits = watermarkBinary(:);
end

function mappingImage = build_mapping_image(originalImage, mappedBits)
originalDouble = double(originalImage) / 255;
grayBackground = 0.299 * originalDouble(:, :, 1) + ...
                 0.587 * originalDouble(:, :, 2) + ...
                 0.114 * originalDouble(:, :, 3);

% Keep an identifiable, dimmed grayscale copy of the host image behind the
% colored payload locations so their position has visual context.
mappingImage = repmat(0.25 + 0.55 * grayBackground, 1, 1, 3);
zeroMask = mappedBits == 0;
oneMask = mappedBits == 1;

redChannel = mappingImage(:, :, 1);
greenChannel = mappingImage(:, :, 2);
blueChannel = mappingImage(:, :, 3);

% Blue identifies a mapped binary 0; orange identifies a mapped binary 1.
redChannel(zeroMask) = 0.05;
greenChannel(zeroMask) = 0.35;
blueChannel(zeroMask) = 1.00;

redChannel(oneMask) = 1.00;
greenChannel(oneMask) = 0.35;
blueChannel(oneMask) = 0.05;

mappingImage(:, :, 1) = redChannel;
mappingImage(:, :, 2) = greenChannel;
mappingImage(:, :, 3) = blueChannel;
end

function create_comparison_figure(methodTitle, originalImage, ...
    embeddedImage, watermarkBinary, mappingImage, mappingTitle, ...
    visualizationPath)
absoluteDifference = abs(double(embeddedImage) - double(originalImage));
maximumDifference = max(absoluteDifference(:));
normalizedDifference = absoluteDifference / max(maximumDifference, 1);
changedPixelMask = any(embeddedImage ~= originalImage, 3);

figureHandle = figure( ...
    'Name', [methodTitle, ' visualization'], ...
    'NumberTitle', 'off', ...
    'Color', 'white', ...
    'Position', [80, 80, 1500, 850]);

subplot(2, 3, 1);
imshow(originalImage);
title('Original image');

subplot(2, 3, 2);
imshow(embeddedImage);
title('Embedded image');

subplot(2, 3, 3);
imshow(normalizedDifference);
title(sprintf([ ...
    'Absolute RGB difference (normalized for visibility)\n' ...
    'Maximum channel change = %.0f'], maximumDifference));

subplot(2, 3, 4);
imshow(changedPixelMask);
title(sprintf([ ...
    'Pixels whose stored RGB value changed\n' ...
    'White = changed; black = unchanged']));

subplot(2, 3, 5);
imshow(watermarkBinary);
title('Binary watermark payload');

subplot(2, 3, 6);
imshow(mappingImage);
title(mappingTitle);

sgtitle([methodTitle, ': original, result, difference, and mapping']);
drawnow;
print(figureHandle, visualizationPath, '-dpng', '-r150');
fprintf('Visualization saved to: %s\n', visualizationPath);
end
