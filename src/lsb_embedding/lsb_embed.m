function lsb_embed(inputImagePath, watermarkPath, ...
        outputImagePath, metadataPath, numBitsUsed)
%LSB_EMBED Embed a tiled watermark by literal LSB replacement.
%   This is a technically strict LSB implementation.  It keeps the whitening,
%   3-by-3 spatial repetition, and external metadata, but it stores data only
%   with BITSET in the lowest one-to-six bit positions.

% Use one replaced LSB when the caller does not provide the fifth argument.
if nargin < 5
    numBitsUsed = 1;
end

% Require an integer number of replaced LSB positions from one through six.
if ~isscalar(numBitsUsed) || ~isfinite(numBitsUsed) || ...
        numBitsUsed ~= floor(numBitsUsed) || numBitsUsed < 1 || numBitsUsed > 6
    error('numBitsUsed must be an integer between 1 and 6.');
end

% Read the original host image.
img = imread(inputImagePath);

% Require exactly three RGB channels.
if ndims(img) ~= 3 || size(img, 3) ~= 3
    error('Input image must be an RGB image.');
end

% Require the 8-bit samples expected by BITSET and BITGET.
if ~isa(img, 'uint8')
    error('Input image must use 8-bit unsigned RGB samples.');
end

% Read the watermark image.
watermark = imread(watermarkPath);

% Convert an RGB watermark into grayscale luminance values.
if ndims(watermark) == 3 && size(watermark, 3) == 3
    % Convert the red watermark channel to double precision.
    watermarkRed = double(watermark(:, :, 1));
    % Convert the green watermark channel to double precision.
    watermarkGreen = double(watermark(:, :, 2));
    % Convert the blue watermark channel to double precision.
    watermarkBlue = double(watermark(:, :, 3));
    % Combine the RGB channels using standard grayscale weights.
    watermarkGray = 0.299 * watermarkRed + 0.587 * watermarkGreen + ...
        0.114 * watermarkBlue;
% Accept an already-grayscale watermark.
elseif ismatrix(watermark)
    % Convert grayscale samples to double precision.
    watermarkGray = double(watermark);
% Reject unsupported watermark channel layouts.
else
    error('Watermark must be a grayscale or RGB image.');
end

% Select the midpoint of an integer image's complete numeric range.
if isinteger(watermark)
    % Find the maximum value supported by the watermark integer class.
    watermarkMaximum = double(intmax(class(watermark)));
    % Use half of that maximum as the black/white threshold.
    watermarkThreshold = watermarkMaximum / 2;
% Select a threshold for floating-point watermark images.
else
    % Find the largest actual floating-point watermark value.
    watermarkMaximum = max(watermarkGray(:));
    % Use 0.5 for normalized data and 128 for 8-bit-like data.
    watermarkThreshold = 0.5 + 127.5 * double(watermarkMaximum > 1);
end

% Convert the grayscale watermark into logical black/white values.
watermarkBinary = watermarkGray > watermarkThreshold;

% Read the host image dimensions.
[imgH, imgW, ~] = size(img);

% Read the watermark dimensions.
[wmH, wmW] = size(watermarkBinary);

% Count the binary watermark payload bits.
numWatermarkBits = numel(watermarkBinary);

% Reject an empty watermark.
if numWatermarkBits < 1
    error('Watermark must contain at least one pixel.');
end

% Repeat the complete encoded watermark three times vertically.
tileRows = 3;

% Repeat the complete encoded watermark three times horizontally.
tileColumns = 3;

% Store the replaced LSBs in the green channel.
embeddingChannelIndex = 2;

% Use the same fixed xorshift32 seed during embedding and retrieval.
whiteningSeed = uint32(19088743);

% Generate one deterministic whitening bit for every watermark bit.
whiteningBits = make_whitening_bits(numWatermarkBits, whiteningSeed);

% Flatten the watermark using MATLAB column-major order.
watermarkBits = watermarkBinary(:);

% Whiten the payload to produce a balanced synchronization pattern.
encodedBits = xor(watermarkBits, whiteningBits);

% Restore the whitened payload to its two-dimensional watermark shape.
encodedWatermark = reshape(encodedBits, [wmH, wmW]);

% Locate every host row at the centre of its normalized pixel interval.
normalizedRows = ((0:(imgH - 1)) + 0.5) / imgH;

% Map each host row to a row in the vertically repeated watermark.
rowBitIndices = mod(floor(normalizedRows * tileRows * wmH), wmH) + 1;

% Locate every host column at the centre of its normalized pixel interval.
normalizedColumns = ((0:(imgW - 1)) + 0.5) / imgW;

% Map each host column to a column in the horizontally repeated watermark.
columnBitIndices = mod(floor(normalizedColumns * tileColumns * wmW), wmW) + 1;

% Ensure that every watermark row is assigned to at least one host row.
if numel(unique(rowBitIndices)) ~= wmH
    error('Host image is too short to represent every watermark row.');
end

% Ensure that every watermark column is assigned to at least one host column.
if numel(unique(columnBitIndices)) ~= wmW
    error('Host image is too narrow to represent every watermark column.');
end

% Estimate the guaranteed complete-cell host samples assigned to every bit.
minimumSamplesPerBit = tileRows * tileColumns * ...
    floor(imgH / (tileRows * wmH)) * floor(imgW / (tileColumns * wmW));

% Require at least nine spatial samples for useful majority voting.
if minimumSamplesPerBit < 9
    error(['Host image is too small for tiled LSB embedding. Each watermark ' ...
        'bit needs at least 9 host samples, but only %d are guaranteed.'], ...
        minimumSamplesPerBit);
end

% Expand the repeated encoded watermark to one assigned bit per host pixel.
embeddedBitPlane = encodedWatermark(rowBitIndices, columnBitIndices);

% Copy the selected green channel before modifying its low-order bits.
modifiedChannel = img(:, :, embeddingChannelIndex);

% Write the assigned bit into every requested low-order bit position.
for bitPosition = 1:numBitsUsed
    % Replace this exact LSB position without changing higher bit positions.
    modifiedChannel = bitset(modifiedChannel, bitPosition, ...
        uint8(embeddedBitPlane));
end

% Copy the complete original image so unselected channels remain unchanged.
watermarkedImg = img;

% Replace only the selected green channel with its LSB-modified version.
watermarkedImg(:, :, embeddingChannelIndex) = modifiedChannel;

% Count green-channel samples changed by at least one replaced LSB.
changedPixelCount = nnz(modifiedChannel ~= ...
    img(:, :, embeddingChannelIndex));

% Write the watermarked image to the requested output path.
imwrite(watermarkedImg, outputImagePath);

% Record a broad method label compatible with the repository terminology.
metadata.method = 'LSB spatial-domain watermarking';

% Record a precise description of this strict bit-replacement variant.
metadata.methodDetail = 'Tiled whitened literal LSB bit replacement';

% Record the format version used by the matching retrieval function.
metadata.algorithmVersion = 1;

% Record a machine-readable mode identifier.
metadata.embeddingMode = 'tiled-whitened-lsb-bit-replacement';

% Explicitly state that this version replaces actual least significant bits.
metadata.strictLSB = true;

% Record the original host image path.
metadata.inputImage = inputImagePath;

% Record the source watermark image path.
metadata.watermarkImage = watermarkPath;

% Record the generated watermarked image path.
metadata.outputImage = outputImagePath;

% Record the original host height.
metadata.imageHeight = imgH;

% Record the original host width.
metadata.imageWidth = imgW;

% Record the watermark height required for reconstruction.
metadata.watermarkHeight = wmH;

% Record the watermark width required for reconstruction.
metadata.watermarkWidth = wmW;

% Record the number of original binary watermark bits.
metadata.numWatermarkBits = numWatermarkBits;

% Record the number of literal LSB positions replaced at each host pixel.
metadata.numBitsUsed = numBitsUsed;

% Record the exact one-based bit positions replaced by BITSET.
metadata.bitPositions = 1:numBitsUsed;

% Record the selected one-based MATLAB RGB channel index.
metadata.embeddingChannelIndex = embeddingChannelIndex;

% Record a human-readable selected-channel description.
metadata.embeddingChannel = 'Green (channel 2)';

% Record the number of vertical watermark repetitions.
metadata.tileRows = tileRows;

% Record the number of horizontal watermark repetitions.
metadata.tileColumns = tileColumns;

% Store the whitening seed as a JSON-safe numeric value.
metadata.whiteningSeed = double(whiteningSeed);

% Record the smallest centered crop ratio searched during retrieval.
metadata.minimumSupportedCropRatio = 0.50;

% Record the guaranteed spatial samples available for every payload bit.
metadata.minimumSamplesPerBit = minimumSamplesPerBit;

% Record the greatest possible change from replacing the selected LSBs.
metadata.maximumChannelChange = 2^numBitsUsed - 1;

% Record how many selected-channel host samples actually changed.
metadata.changedPixelCount = changedPixelCount;

% Explain the normalized coordinate mapping used for tiled embedding.
metadata.embeddingOrder = 'Normalized 3-by-3 tiled watermark coordinates';

% Convert the metadata structure into JSON text.
jsonText = jsonencode(metadata);

% Open the requested metadata file for writing.
fid = fopen(metadataPath, 'w');

% Stop if the metadata file cannot be created.
if fid == -1
    error('Could not open metadata output file: %s', metadataPath);
end

% Write the complete JSON document.
bytesWritten = fprintf(fid, '%s', jsonText);

% Close the metadata file.
closeStatus = fclose(fid);

% Detect a short write or a failed close operation.
if bytesWritten < numel(jsonText) || closeStatus ~= 0
    error('Could not completely write metadata file: %s', metadataPath);
end

% Report successful strict LSB embedding.
fprintf('Tiled literal-LSB watermark embedding complete.\n');

% Report the generated image path.
fprintf('Output image saved to: %s\n', outputImagePath);

% Report the generated metadata path.
fprintf('Metadata saved to: %s\n', metadataPath);

% Report the number of actual low-order bit positions replaced.
fprintf('Replaced LSB positions per selected-channel pixel: %d.\n', ...
    numBitsUsed);

% Report the binary watermark dimensions and bit count.
fprintf('Watermark size: %d x %d (%d bits total).\n', ...
    wmW, wmH, numWatermarkBits);

% End the public strict LSB embedding function.
end


function whiteningBits = make_whitening_bits(numberOfBits, seed)
%MAKE_WHITENING_BITS Generate deterministic logical bits with xorshift32.

% Convert the supplied seed to a 32-bit unsigned state.
state = uint32(seed);

% Replace the forbidden all-zero generator state.
if state == 0
    state = uint32(2463534242);
end

% Preallocate the output logical column.
whiteningBits = false(numberOfBits, 1);

% Generate exactly one whitening bit for every payload bit.
for bitIndex = 1:numberOfBits
    % Apply the first xorshift32 mixing stage.
    state = bitxor(state, bitshift(state, 13));
    % Apply the second xorshift32 mixing stage.
    state = bitxor(state, bitshift(state, -17));
    % Apply the third xorshift32 mixing stage.
    state = bitxor(state, bitshift(state, 5));
    % Extract the least significant generator-state bit.
    whiteningBits(bitIndex) = logical(bitand(state, uint32(1)));
end

% End the whitening helper.
end
