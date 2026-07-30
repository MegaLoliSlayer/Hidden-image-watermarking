function lsb_retrieve(inputImagePath, outputWatermarkPath, ...
                      numBitsUsed, jsonInputFilePath)

metadataLength = 64;

if numBitsUsed < 1 || numBitsUsed > 4
    error('numBitsUsed must be between 1 and 4.');
end

% Read attacked/watermarked image
img = imread(inputImagePath);

if size(img, 3) ~= 3
    error('Input image must be an RGB image.');
end

[imgH, imgW, ~] = size(img);

% Extract blue channel
blueChannel = img(:, :, 3);

% Extract every embedded LSB in the same order used during embedding
maxExtractableBits = imgH * imgW * numBitsUsed;
allBits = zeros(maxExtractableBits, 1, 'uint8');

bitIndex = 1;

for pixelIndex = 1:(imgH * imgW)

    pixelValue = blueChannel(pixelIndex);

    for b = 1:numBitsUsed

        % Embedding placed the first bit in the highest used LSB
        bitPosition = numBitsUsed - b + 1;

        allBits(bitIndex) = bitget(pixelValue, bitPosition);
        bitIndex = bitIndex + 1;
    end
end

if length(allBits) < metadataLength
    error('Image does not contain enough pixels for the 64-bit header.');
end

%% Decode embedded header
%
% The embedding script stores:
%   bits 1-16  = watermark width
%   bits 17-32 = watermark height
%   bits 33-64 = number of watermark bits

wmW = bin2dec(char(allBits(1:16).' + '0'));
wmH = bin2dec(char(allBits(17:32).' + '0'));
numWatermarkBits = bin2dec(char(allBits(33:64).' + '0'));

%% Check whether embedded header is valid

headerValid = true;

if wmH < 1 || wmW < 1
    headerValid = false;
end

if numWatermarkBits ~= wmH * wmW
    headerValid = false;
end

if metadataLength + numWatermarkBits > length(allBits)
    headerValid = false;
end

%% Fall back to JSON metadata

if ~headerValid

    warning('Embedded LSB header is corrupted. Using JSON metadata.');

    if ~isfile(jsonInputFilePath)
        error('JSON metadata file does not exist: %s', ...
            jsonInputFilePath);
    end

    jsonText = fileread(jsonInputFilePath);
    metadata = jsondecode(jsonText);

    requiredFields = {
        'watermarkHeight'
        'watermarkWidth'
        'numWatermarkBits'
    };

    for fieldIndex = 1:length(requiredFields)
        if ~isfield(metadata, requiredFields{fieldIndex})
            error('JSON metadata is missing field "%s".', ...
                requiredFields{fieldIndex});
        end
    end

    wmH = double(metadata.watermarkHeight);
    wmW = double(metadata.watermarkWidth);
    numWatermarkBits = double(metadata.numWatermarkBits);

    if isfield(metadata, 'numBitsUsed') && ...
            double(metadata.numBitsUsed) ~= numBitsUsed

        warning(['numBitsUsed input does not match the JSON value. ' ...
                 'Using the JSON value.']);

        numBitsUsed = double(metadata.numBitsUsed);

        % Re-extract bits using the JSON numBitsUsed value
        maxExtractableBits = imgH * imgW * numBitsUsed;
        allBits = zeros(maxExtractableBits, 1, 'uint8');

        bitIndex = 1;

        for pixelIndex = 1:(imgH * imgW)

            pixelValue = blueChannel(pixelIndex);

            for b = 1:numBitsUsed
                bitPosition = numBitsUsed - b + 1;

                allBits(bitIndex) = ...
                    bitget(pixelValue, bitPosition);

                bitIndex = bitIndex + 1;
            end
        end
    end

    % Validate JSON values
    if wmH < 1 || wmW < 1 || ...
            numWatermarkBits ~= wmH * wmW
        error('JSON watermark metadata is invalid.');
    end

    if metadataLength + numWatermarkBits > length(allBits)
        error(['Watermark requires %d bits, but only %d payload bits ' ...
               'can be extracted from the image.'], ...
               numWatermarkBits, ...
               length(allBits) - metadataLength);
    end
end

%% Retrieve watermark data

watermarkStart = metadataLength + 1;
watermarkEnd = metadataLength + numWatermarkBits;

watermarkBits = allBits(watermarkStart:watermarkEnd);

%% Reconstruct and save watermark

reconstructedWatermark = reshape( ...
    logical(watermarkBits), [wmH, wmW]);

imwrite(uint8(reconstructedWatermark) * 255, ...
    outputWatermarkPath);

fprintf('LSB watermark retrieval complete.\n');
fprintf('Recovered watermark: %d x %d (%d bits).\n', ...
    wmW, wmH, numWatermarkBits);

if headerValid
    fprintf('Metadata source: embedded header.\n');
else
    fprintf('Metadata source: JSON file.\n');
end

end