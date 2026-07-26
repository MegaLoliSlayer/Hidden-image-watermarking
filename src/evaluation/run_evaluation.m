clc;
clear;
close all;

% Main evaluation script for the watermarking project.

% This evaluates:
% 1. DCT embedding image quality
% 2. LSB embedding image quality
% 3. DCT retrieved watermark quality
% 4. LSB retrieved watermark quality
% 5. Attacked watermarked images

% This file evaluates output files if they already exist.

scriptFolder = fileparts(mfilename('fullpath'));
projectRoot = fullfile(scriptFolder, '..', '..');

addpath(scriptFolder);

inputFolder = fullfile(projectRoot, 'data', 'input');
outputFolder = fullfile(projectRoot, 'data', 'output');
resultsFolder = fullfile(projectRoot, 'results', 'tables');

if ~exist(resultsFolder, 'dir')
    mkdir(resultsFolder);
end

originalImagePath = fullfile(inputFolder, 'original.png');
originalWatermarkPath = fullfile(inputFolder, 'watermark.png');

if exist(originalImagePath, 'file') ~= 2
    error('Original image not found: %s', originalImagePath);
end

if exist(originalWatermarkPath, 'file') ~= 2
    error('Original watermark not found: %s', originalWatermarkPath);
end

% Method format:
% method key, method display name, watermarked image path, extracted watermark path
methods = {
    'dct', 'DCT Transform-Domain', ...
    fullfile(outputFolder, 'dct_watermarked.png'), ...
    fullfile(outputFolder, 'retrieved', 'dct_no_attack_extracted_watermark.png');

    'lsb', 'LSB Spatial-Domain', ...
    fullfile(outputFolder, 'lsb_watermarked.png'), ...
    fullfile(outputFolder, 'retrieved', 'lsb_no_attack_extracted_watermark.png')
};

% Table storage
Method = {};
Category = {};
Attack = {};
ImageFile = {};
WatermarkFile = {};

MSE = [];
PSNR = [];
Accuracy = [];
BER = [];
NC = [];

row = 0;

fprintf('========================================\n');
fprintf('Watermark Project Evaluation\n');
fprintf('========================================\n\n');

for i = 1:size(methods, 1)

    methodKey = methods{i, 1};
    methodName = methods{i, 2};
    watermarkedImagePath = methods{i, 3};
    extractedWatermarkPath = methods{i, 4};

    fprintf('----------------------------------------\n');
    fprintf('Method: %s\n', methodName);
    fprintf('----------------------------------------\n');

    % ============================================================
    % Part 1: embedding evaluation
    % original image vs watermarked image
    % ============================================================

    if exist(watermarkedImagePath, 'file') == 2

        fprintf('\nEmbedding image quality:\n');

        imageMetrics = image_quality_metrics(originalImagePath, watermarkedImagePath);

        row = row + 1;
        Method{row, 1} = methodName;
        Category{row, 1} = 'Embedding image quality';
        Attack{row, 1} = 'No attack';
        ImageFile{row, 1} = watermarkedImagePath;
        WatermarkFile{row, 1} = '';
        MSE(row, 1) = imageMetrics.MSE;
        PSNR(row, 1) = imageMetrics.PSNR;
        Accuracy(row, 1) = NaN;
        BER(row, 1) = NaN;
        NC(row, 1) = NaN;

        % ========================================================
        % Part 2: create attacked images and evaluate attacked image quality
        % ========================================================

        fprintf('\nCreating attacked images:\n');

        attackFolder = fullfile(outputFolder, 'attacks', methodKey);
        attackList = attack_images(watermarkedImagePath, attackFolder, methodKey);

        for a = 1:length(attackList)

            attackName = attackList(a).name;
            attackedImagePath = attackList(a).path;

            % Do not evaluate the no_attack copy here.
            % The original watermarked image was already evaluated above as
            % "Embedding image quality / No attack".
            if strcmp(attackName, 'no_attack')
                continue;
            end

            fprintf('\nImage quality after attack: %s\n', attackName);

            attackImageMetrics = image_quality_metrics(originalImagePath, attackedImagePath);

            row = row + 1;
            Method{row, 1} = methodName;
            Category{row, 1} = 'Attacked image quality';
            Attack{row, 1} = attackName;
            ImageFile{row, 1} = attackedImagePath;
            WatermarkFile{row, 1} = '';
            MSE(row, 1) = attackImageMetrics.MSE;
            PSNR(row, 1) = attackImageMetrics.PSNR;
            Accuracy(row, 1) = NaN;
            BER(row, 1) = NaN;
            NC(row, 1) = NaN;
        end

    else
        fprintf('\nWatermarked image not found. Skipping embedding image quality.\n');
        fprintf('Missing file:\n%s\n', watermarkedImagePath);
    end

    % ============================================================
    % Part 3: retrieved watermark evaluation
    % original watermark vs extracted watermark
    % ============================================================

    fprintf('\nRetrieved watermark quality:\n');

    extractedCandidates = {
        extractedWatermarkPath;
        fullfile(outputFolder, [methodKey '_extracted_watermark.png']);
        fullfile(outputFolder, 'retrieved', [methodKey '_extracted_watermark.png'])
    };

    existingExtractedPath = find_existing_file(extractedCandidates);

    if ~isempty(existingExtractedPath)

        watermarkMetrics = watermark_recovery_metrics(originalWatermarkPath, existingExtractedPath);

        row = row + 1;
        Method{row, 1} = methodName;
        Category{row, 1} = 'Retrieved watermark quality';
        Attack{row, 1} = 'No attack';
        ImageFile{row, 1} = '';
        WatermarkFile{row, 1} = existingExtractedPath;
        MSE(row, 1) = NaN;
        PSNR(row, 1) = NaN;
        Accuracy(row, 1) = watermarkMetrics.Accuracy;
        BER(row, 1) = watermarkMetrics.BER;
        NC(row, 1) = watermarkMetrics.NC;

    else
        fprintf('No extracted watermark found yet for %s.\n', methodName);
        fprintf('Expected one of these:\n');
        for c = 1:length(extractedCandidates)
            fprintf('%s\n', extractedCandidates{c});
        end
    end

    % ============================================================
    % Part 4: retrieved watermark after attacks
    % This only works after retrieval person extracts from attacked images.
    % ============================================================

    fprintf('\nRetrieved watermark quality after attacks:\n');

    attackFolder = fullfile(outputFolder, 'attacks', methodKey);

    if exist(attackFolder, 'dir') == 7

        attackFiles = dir(fullfile(attackFolder, '*.png'));

        for a = 1:length(attackFiles)

            attackedImagePath = fullfile(attackFolder, attackFiles(a).name);

            attackName = attackFiles(a).name;
            attackName = strrep(attackName, [methodKey '_'], '');
            attackName = strrep(attackName, '.png', '');

            % Do not evaluate no_attack here.
            % The no-attack extracted watermark was already evaluated above as
            % "Retrieved watermark quality / No attack".
            if strcmp(attackName, 'no_attack')
                continue;
            end

            attackedExtractedCandidates = {
                fullfile(outputFolder, 'retrieved', [methodKey '_' attackName '_extracted_watermark.png']);
                fullfile(outputFolder, [methodKey '_' attackName '_extracted_watermark.png'])
            };

            attackedExtractedPath = find_existing_file(attackedExtractedCandidates);

            if ~isempty(attackedExtractedPath)

                fprintf('\nWatermark recovery after attack: %s\n', attackName);

                attackedWatermarkMetrics = watermark_recovery_metrics( ...
                    originalWatermarkPath, attackedExtractedPath);

                row = row + 1;
                Method{row, 1} = methodName;
                Category{row, 1} = 'Retrieved watermark after attack';
                Attack{row, 1} = attackName;
                ImageFile{row, 1} = attackedImagePath;
                WatermarkFile{row, 1} = attackedExtractedPath;
                MSE(row, 1) = NaN;
                PSNR(row, 1) = NaN;
                Accuracy(row, 1) = attackedWatermarkMetrics.Accuracy;
                BER(row, 1) = attackedWatermarkMetrics.BER;
                NC(row, 1) = attackedWatermarkMetrics.NC;
            end
        end
    else
        fprintf('No attack folder found yet for %s.\n', methodName);
    end

    fprintf('\nFinished method: %s\n\n', methodName);
end

% ============================================================
% Save result table
% ============================================================

resultsTable = table( ...
    Method, ...
    Category, ...
    Attack, ...
    ImageFile, ...
    WatermarkFile, ...
    MSE, ...
    PSNR, ...
    Accuracy, ...
    BER, ...
    NC);

csvPath = fullfile(resultsFolder, 'evaluation_summary.csv');
matPath = fullfile(resultsFolder, 'evaluation_summary.mat');

writetable(resultsTable, csvPath);
save(matPath, 'resultsTable');

fprintf('========================================\n');
fprintf('Evaluation complete.\n');
fprintf('CSV saved to:\n%s\n', csvPath);
fprintf('MAT saved to:\n%s\n', matPath);
fprintf('========================================\n');


function existingPath = find_existing_file(candidatePaths)
% Return the first path that exists.

existingPath = '';

for k = 1:length(candidatePaths)
    if exist(candidatePaths{k}, 'file') == 2
        existingPath = candidatePaths{k};
        return;
    end
end

end