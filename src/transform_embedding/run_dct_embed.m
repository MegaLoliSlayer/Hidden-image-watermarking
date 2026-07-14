clc;
clear;
close all;

% Get the folder where this script is located:
% D:\Hidden-image-watermarking\src\transform_embedding
scriptFolder = fileparts(mfilename('fullpath'));

% Go two folders up to project root:
% D:\Hidden-image-watermarking
projectRoot = fullfile(scriptFolder, '..', '..');

% Create full absolute paths
inputImagePath = fullfile(projectRoot, 'data', 'input', 'original.png');
watermarkPath = fullfile(projectRoot, 'data', 'input', 'watermark.png');
outputImagePath = fullfile(projectRoot, 'data', 'output', 'dct_watermarked.png');
metadataPath = fullfile(projectRoot, 'data', 'output', 'dct_metadata.json');

% Make sure output folder exists
outputFolder = fullfile(projectRoot, 'data', 'output');
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Debug check
disp(inputImagePath)
disp(exist(inputImagePath, 'file'))

strength = 20;

dct_embed(inputImagePath, watermarkPath, outputImagePath, metadataPath, strength);