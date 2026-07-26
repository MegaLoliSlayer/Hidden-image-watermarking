function metrics = image_quality_metrics(originalImagePath, testImagePath)
%IMAGE_QUALITY_METRICS Compare image quality between two images.
%
% Used for:
%   original image vs DCT watermarked image
%   original image vs LSB watermarked image
%   original image vs attacked watermarked images
%
% Output:
%   MSE
%   PSNR

original = imread(originalImagePath);
testImg = imread(testImagePath);

original = to_rgb_double(original);
testImg = to_rgb_double(testImg);

% If the images are not the same size, crop both to the common area.
h = min(size(original, 1), size(testImg, 1));
w = min(size(original, 2), size(testImg, 2));

original = original(1:h, 1:w, :);
testImg = testImg(1:h, 1:w, :);

diff = original - testImg;

mseValue = mean(diff(:).^2);

if mseValue == 0
    psnrValue = Inf;
else
    maxPixel = 255;
    psnrValue = 10 * log10((maxPixel^2) / mseValue);
end

metrics.MSE = mseValue;
metrics.PSNR = psnrValue;

fprintf('MSE  = %.4f\n', mseValue);
fprintf('PSNR = %.4f dB\n', psnrValue);

end


function imgDouble = to_rgb_double(img)
% Convert image to RGB double format.
% If the image is grayscale, copy it into 3 channels.

imgDouble = double(img);

if size(imgDouble, 3) == 1
    imgDouble = repmat(imgDouble, 1, 1, 3);
end

end