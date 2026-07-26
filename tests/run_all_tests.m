%% run_all_tests.m
% Functional tests for the LSB and DCT watermark embedding code.
%
% This suite deliberately does not calculate MSE, PSNR, BER, or NC and
% does not recover a watermark. Run src/evaluation/run_evaluation.m for
% image-quality and watermark-recovery evaluation.

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

generatedFiles = {
    lsbOutputPath, lsbMetadataPath, ...
    dctOutputPath, dctMetadataPath, ...
    lsb2OutputPath, lsb2MetadataPath
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
