function dct_retrieval(inputImagePath, outputWatermarkPath, jsonInputFilePath)

blockSize = 8;
coeff1 = [4, 5];
coeff2 = [5, 4];
metadataLength = 80;

img = imread(inputImagePath);

if size(img, 3) ~= 3
    error('Input image must be an RGB image.');
end

% Convert RGB image to Y brightness channel
imgDouble = double(img);

Y = 0.299 * imgDouble(:, :, 1) + ...
    0.587 * imgDouble(:, :, 2) + ...
    0.114 * imgDouble(:, :, 3);

[imgH, imgW] = size(Y);

% Recalculate padding
calculatedPadH = mod(blockSize - mod(imgH, blockSize), blockSize);
calculatedPadW = mod(blockSize - mod(imgW, blockSize), blockSize);

paddedH = imgH + calculatedPadH;
paddedW = imgW + calculatedPadW;

% Rebuild padded Y channel
paddedY = zeros(paddedH, paddedW);
paddedY(1:imgH, 1:imgW) = Y;

if calculatedPadH > 0
    paddedY(imgH+1:paddedH, 1:imgW) = ...
        repmat(Y(end, :), calculatedPadH, 1);
end

if calculatedPadW > 0
    paddedY(:, imgW+1:paddedW) = ...
        repmat(paddedY(:, imgW), 1, calculatedPadW);
end

% Calculate block grid
numBlocksH = paddedH / blockSize;
numBlocksW = paddedW / blockSize;
maxBits = numBlocksH * numBlocksW;

if maxBits < metadataLength
    error('Image does not contain enough 8x8 blocks for metadata.');
end

D = create_dct_matrix(blockSize);

%% Extract the embedded 80-bit header

metadataBits = zeros(metadataLength, 1);

for bitIndex = 1:metadataLength
    metadataBits(bitIndex) = extract_bit( ...
        paddedY, bitIndex, numBlocksW, ...
        blockSize, coeff1, coeff2, D);
end

wmH = bin2dec(char(metadataBits(1:16).' + '0'));
wmW = bin2dec(char(metadataBits(17:32).' + '0'));
numBits = bin2dec(char(metadataBits(33:64).' + '0'));
storedPadH = bin2dec(char(metadataBits(65:72).' + '0'));
storedPadW = bin2dec(char(metadataBits(73:80).' + '0'));

%% Check whether the embedded header is valid

headerValid = true;

if storedPadH ~= calculatedPadH || storedPadW ~= calculatedPadW
    headerValid = false;
end

if wmH < 1 || wmW < 1 || numBits ~= wmH * wmW
    headerValid = false;
end

if metadataLength + numBits > maxBits
    headerValid = false;
end

%% Read metadata from JSON if the header is corrupted

jsonMetadata = [];

if ~headerValid
    warning('Embedded header is corrupted. Using JSON metadata instead.');

    fid = fopen(jsonInputFilePath, 'r');

    if fid == -1
        error('Could not open JSON metadata file: %s', jsonInputFilePath);
    end

    jsonText = fread(fid, '*char').';
    fclose(fid);

    jsonMetadata = jsondecode(jsonText);

    wmH = double(jsonMetadata.watermarkHeight);
    wmW = double(jsonMetadata.watermarkWidth);
    numBits = double(jsonMetadata.numEmbeddedBits);

    storedPadH = double(jsonMetadata.paddedHeight) - ...
                 double(jsonMetadata.originalHeight);

    storedPadW = double(jsonMetadata.paddedWidth) - ...
                 double(jsonMetadata.originalWidth);

    % Validate JSON metadata
    if wmH < 1 || wmW < 1 || numBits ~= wmH * wmW
        error('JSON watermark metadata is invalid.');
    end
end

%% Determine the watermark block locations

if ~headerValid && isfield(jsonMetadata, 'selectedBlockIndices')

    % JSON contains the complete payload indices:
    % first 80 are header, remaining indices contain watermark bits
    payloadBlockIndices = ...
        double(jsonMetadata.selectedBlockIndices(:).');

    if length(payloadBlockIndices) < metadataLength + numBits
        error('JSON does not contain enough block indices.');
    end

    watermarkBlockIndices = ...
        payloadBlockIndices(metadataLength + 1:metadataLength + numBits);

else
    % Recreate the block indices normally
    watermarkBlockIndices = round( ...
        linspace(metadataLength + 1, maxBits, numBits));
end

if any(watermarkBlockIndices < 1) || ...
        any(watermarkBlockIndices > maxBits)
    error('One or more watermark block indices are outside the image.');
end

%% Extract watermark bits

watermarkBits = zeros(numBits, 1);

for bitIndex = 1:numBits
    blockIndex = watermarkBlockIndices(bitIndex);

    watermarkBits(bitIndex) = extract_bit( ...
        paddedY, blockIndex, numBlocksW, ...
        blockSize, coeff1, coeff2, D);
end

%% Reconstruct and save watermark

reconstructedWatermark = reshape( ...
    logical(watermarkBits), [wmH, wmW]);

imwrite(uint8(reconstructedWatermark) * 255, ...
    outputWatermarkPath);

fprintf('DCT watermark retrieval complete.\n');
fprintf('Recovered watermark: %d x %d (%d bits).\n', ...
    wmW, wmH, numBits);
fprintf('Stored padding: %d row(s), %d column(s).\n', ...
    storedPadH, storedPadW);

if headerValid
    fprintf('Metadata source: embedded header.\n');
else
    fprintf('Metadata source: JSON file.\n');
end

end

function bit = extract_bit(Y, blockIndex, numBlocksW, ...
                           blockSize, coeff1, coeff2, D)

blockRow = floor((blockIndex - 1) / numBlocksW) + 1;
blockCol = mod(blockIndex - 1, numBlocksW) + 1;

rowStart = (blockRow - 1) * blockSize + 1;
colStart = (blockCol - 1) * blockSize + 1;

block = Y(rowStart:rowStart+blockSize-1, ...
          colStart:colStart+blockSize-1);

dctBlock = D * block * D';

bit = dctBlock(coeff1(1), coeff1(2)) > ...
      dctBlock(coeff2(1), coeff2(2));

end

function D = create_dct_matrix(N)

D = zeros(N, N);

for k = 0:N-1
    for n = 0:N-1
        if k == 0
            alpha = sqrt(1 / N);
        else
            alpha = sqrt(2 / N);
        end

        D(k+1, n+1) = alpha * ...
            cos(((2*n + 1) * k * pi) / (2 * N));
    end
end

end
