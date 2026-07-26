function metrics = watermark_recovery_metrics(originalWatermarkPath, extractedWatermarkPath)
%WATERMARK_RECOVERY_METRICS Compare original watermark and extracted watermark.
%
% Used for:
%   original watermark vs DCT extracted watermark
%   original watermark vs LSB extracted watermark
%   original watermark vs extracted watermark after attack
%
% Output:
%   Accuracy
%   BER
%   NC

original = imread(originalWatermarkPath);
extracted = imread(extractedWatermarkPath);

originalGray = to_gray_manual(original);
extractedGray = to_gray_manual(extracted);

originalBinary = originalGray > 128;
extractedBinary = extractedGray > 128;

% If sizes do not match, crop to common size.
% Ideally, retrieval should output the exact same size as the original watermark.
h = min(size(originalBinary, 1), size(extractedBinary, 1));
w = min(size(originalBinary, 2), size(extractedBinary, 2));

originalBinary = originalBinary(1:h, 1:w);
extractedBinary = extractedBinary(1:h, 1:w);

originalBits = originalBinary(:);
extractedBits = extractedBinary(:);

totalBits = numel(originalBits);
correctBits = sum(originalBits == extractedBits);
wrongBits = totalBits - correctBits;

accuracy = correctBits / totalBits * 100;
ber = wrongBits / totalBits;

origDouble = double(originalBits);
extDouble = double(extractedBits);

denominator = sqrt(sum(origDouble.^2) * sum(extDouble.^2));

if denominator == 0
    nc = 0;
else
    nc = sum(origDouble .* extDouble) / denominator;
end

metrics.TotalBits = totalBits;
metrics.CorrectBits = correctBits;
metrics.WrongBits = wrongBits;
metrics.Accuracy = accuracy;
metrics.BER = ber;
metrics.NC = nc;

fprintf('Total bits   = %d\n', totalBits);
fprintf('Correct bits = %d\n', correctBits);
fprintf('Wrong bits   = %d\n', wrongBits);
fprintf('Accuracy     = %.2f%%\n', accuracy);
fprintf('BER          = %.4f\n', ber);
fprintf('NC           = %.4f\n', nc);

end


function gray = to_gray_manual(img)
% Convert RGB image to grayscale manually.
% This avoids using rgb2gray from Image Processing Toolbox.

img = double(img);

if size(img, 3) == 3
    gray = 0.299 * img(:, :, 1) + ...
           0.587 * img(:, :, 2) + ...
           0.114 * img(:, :, 3);
else
    gray = img;
end

end