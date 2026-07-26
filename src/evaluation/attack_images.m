function attackList = attack_images(inputImagePath, outputFolder, methodKey)
%ATTACK_IMAGES Create attacked versions of a watermarked image.
%
% Works for both:
%   DCT watermarked image
%   LSB watermarked image
%
% Attacks:
%   no attack copy
%   JPEG compression
%   Gaussian noise
%   3x3 blur
%   center crop 80% then resize back

if nargin < 3
    methodKey = 'method';
end

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

img = imread(inputImagePath);
imgDouble = double(img);

attackList = struct('name', {}, 'path', {});

% ============================================================
% Attack 0: no attack copy
% ============================================================

attackName = 'no_attack';
outputPath = fullfile(outputFolder, [methodKey '_' attackName '.png']);

imwrite(img, outputPath);

attackList(end+1).name = attackName;
attackList(end).path = outputPath;

% ============================================================
% Attack 1: JPEG compression
% ============================================================

attackName = 'jpeg_q50';

jpegPath = fullfile(outputFolder, [methodKey '_' attackName '.jpg']);
outputPath = fullfile(outputFolder, [methodKey '_' attackName '.png']);

imwrite(img, jpegPath, 'Quality', 50);
jpegImg = imread(jpegPath);
imwrite(jpegImg, outputPath);

attackList(end+1).name = attackName;
attackList(end).path = outputPath;

% ============================================================
% Attack 2: Gaussian noise
% ============================================================

attackName = 'gaussian_noise';

rng(1);
noiseSigma = 10;

noisyImg = imgDouble + noiseSigma * randn(size(imgDouble));
noisyImg = uint8(min(max(noisyImg, 0), 255));

outputPath = fullfile(outputFolder, [methodKey '_' attackName '.png']);
imwrite(noisyImg, outputPath);

attackList(end+1).name = attackName;
attackList(end).path = outputPath;

% ============================================================
% Attack 3: 3x3 average blur
% ============================================================

attackName = 'blur_3x3';

kernel = ones(3, 3) / 9;

blurredImg = zeros(size(imgDouble));

for ch = 1:size(imgDouble, 3)
    blurredImg(:, :, ch) = conv2(imgDouble(:, :, ch), kernel, 'same');
end

blurredImg = uint8(min(max(blurredImg, 0), 255));

outputPath = fullfile(outputFolder, [methodKey '_' attackName '.png']);
imwrite(blurredImg, outputPath);

attackList(end+1).name = attackName;
attackList(end).path = outputPath;

% ============================================================
% Attack 4: center crop 80%, then resize back
% ============================================================

attackName = 'crop80_resize';

cropRatio = 0.80;

[h, w, ~] = size(img);

cropH = round(h * cropRatio);
cropW = round(w * cropRatio);

rowStart = floor((h - cropH) / 2) + 1;
colStart = floor((w - cropW) / 2) + 1;

croppedImg = img(rowStart:rowStart+cropH-1, ...
                 colStart:colStart+cropW-1, :);

resizedBack = nearest_resize(croppedImg, h, w);

outputPath = fullfile(outputFolder, [methodKey '_' attackName '.png']);
imwrite(resizedBack, outputPath);

attackList(end+1).name = attackName;
attackList(end).path = outputPath;

fprintf('Attack images saved to:\n%s\n', outputFolder);

end


function out = nearest_resize(img, newH, newW)
% Resize image using nearest-neighbor method.
% This avoids imresize because imresize may need Image Processing Toolbox.

[oldH, oldW, channels] = size(img);

out = zeros(newH, newW, channels, 'uint8');

for r = 1:newH

    oldR = round((r - 0.5) * oldH / newH + 0.5);
    oldR = min(max(oldR, 1), oldH);

    for c = 1:newW

        oldC = round((c - 0.5) * oldW / newW + 0.5);
        oldC = min(max(oldC, 1), oldW);

        out(r, c, :) = img(oldR, oldC, :);
    end
end

end