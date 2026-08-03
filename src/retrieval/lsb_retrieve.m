function lsb_retrieve(inputImagePath, ...
        outputWatermarkPath, numBitsUsed, jsonInputFilePath)
%LSB_RETRIEVE Recover the tiled literal-LSB watermark.
%   The decoder reads actual low-order bit positions with BITGET, combines
%   repeated bit-plane and spatial votes, estimates a centered crop ratio,
%   removes whitening, and writes the reconstructed binary watermark.

% Require an integer caller-supplied LSB count from one through six.
if ~isscalar(numBitsUsed) || ~isfinite(numBitsUsed) || ...
        numBitsUsed ~= floor(numBitsUsed) || numBitsUsed < 1 || numBitsUsed > 6
    error('numBitsUsed must be an integer between 1 and 6.');
end

% Require the external metadata needed for dimensions and synchronization.
if ~isfile(jsonInputFilePath)
    error('LSB retrieval metadata file does not exist: %s', jsonInputFilePath);
end

% Read the complete metadata document.
jsonText = fileread(jsonInputFilePath);

% Decode the JSON document into a MATLAB structure.
metadata = jsondecode(jsonText);

% List every field required by this strict LSB decoder.
requiredFields = {'embeddingMode', 'watermarkHeight', 'watermarkWidth', ...
    'numWatermarkBits', 'numBitsUsed', 'embeddingChannelIndex', ...
    'tileRows', 'tileColumns', 'whiteningSeed', ...
    'minimumSupportedCropRatio'};

% Validate the presence of every required metadata field.
for fieldIndex = 1:numel(requiredFields)
    % Select the current required field name.
    fieldName = requiredFields{fieldIndex};
    % Stop when the current field is absent.
    if ~isfield(metadata, fieldName)
        error('JSON metadata is missing required field "%s".', fieldName);
    end
end

% Reject metadata produced by a different embedding format.
if ~strcmp(metadata.embeddingMode, ...
        'tiled-whitened-lsb-bit-replacement')
    error(['Metadata was not produced by the matching lsb_embed.m. ' ...
        'Use the retrieval function that matches the embedding format.']);
end

% Read the watermarked or attacked RGB image.
img = imread(inputImagePath);

% Require exactly three RGB channels.
if ndims(img) ~= 3 || size(img, 3) ~= 3
    error('Input image must be an RGB image.');
end

% Require the 8-bit samples expected by BITGET.
if ~isa(img, 'uint8')
    error('Input image must use 8-bit unsigned RGB samples.');
end

% Read the attacked image dimensions.
[imgH, imgW, ~] = size(img);

% Read the watermark height.
wmH = double(metadata.watermarkHeight);

% Read the watermark width.
wmW = double(metadata.watermarkWidth);

% Read the original watermark bit count.
numWatermarkBits = double(metadata.numWatermarkBits);

% Read the selected one-based RGB channel index.
embeddingChannelIndex = double(metadata.embeddingChannelIndex);

% Read the number of actual LSB positions written during embedding.
embeddedBitsUsed = double(metadata.numBitsUsed);

% Read the vertical tile count.
tileRows = double(metadata.tileRows);

% Read the horizontal tile count.
tileColumns = double(metadata.tileColumns);

% Read the deterministic whitening seed.
whiteningSeed = uint32(metadata.whiteningSeed);

% Read the smallest centered crop ratio searched by synchronization.
minimumCropRatio = double(metadata.minimumSupportedCropRatio);

% Validate the watermark dimensions.
if wmH < 1 || wmW < 1 || wmH ~= floor(wmH) || wmW ~= floor(wmW)
    error('JSON watermark dimensions are invalid.');
end

% Validate the relationship between dimensions and payload length.
if numWatermarkBits ~= wmH * wmW
    error('JSON payload length does not match the watermark dimensions.');
end

% Validate the selected RGB channel.
if embeddingChannelIndex < 1 || embeddingChannelIndex > 3 || ...
        embeddingChannelIndex ~= floor(embeddingChannelIndex)
    error('JSON embeddingChannelIndex must be 1, 2, or 3.');
end

% Validate the number of literal LSB positions used by embedding.
if embeddedBitsUsed < 1 || embeddedBitsUsed > 6 || ...
        embeddedBitsUsed ~= floor(embeddedBitsUsed)
    error('JSON numBitsUsed must be an integer between 1 and 6.');
end

% Validate positive integer tile counts.
if tileRows < 1 || tileColumns < 1 || tileRows ~= floor(tileRows) || ...
        tileColumns ~= floor(tileColumns)
    error('JSON tile counts must be positive integers.');
end

% Validate the crop search range.
if ~isfinite(minimumCropRatio) || minimumCropRatio <= 0 || ...
        minimumCropRatio > 1
    error('JSON minimumSupportedCropRatio must be in the interval (0, 1].');
end

% Warn if the caller supplies a different LSB count from the metadata.
if numBitsUsed ~= embeddedBitsUsed
    warning(['numBitsUsed does not match the JSON value. Retrieval will ' ...
        'read the exact LSB positions recorded in JSON.']);
end

% Extract the selected host channel without converting away its integer bits.
embeddedChannel = img(:, :, embeddingChannelIndex);

% Preallocate signed votes accumulated across all embedded LSB positions.
pixelVotes = zeros(imgH, imgW);

% Read every literal LSB position written by the embedder.
for bitPosition = 1:embeddedBitsUsed
    % Extract zeros and ones from this exact low-order bit position.
    bitPlane = double(bitget(embeddedChannel, bitPosition));
    % Convert zero to -1 and one to +1, then add the votes per pixel.
    pixelVotes = pixelVotes + (2 * bitPlane - 1);
end

% Select a stride that keeps approximately 256 synchronization samples per axis.
syncStride = max(1, floor(min(imgH, imgW) / 256));

% Select evenly spaced rows for crop synchronization.
sampleRows = 1:syncStride:imgH;

% Select evenly spaced columns for crop synchronization.
sampleColumns = 1:syncStride:imgW;

% Read the combined bit-position votes at synchronization samples.
sampleVotes = pixelVotes(sampleRows, sampleColumns);

% Search centered crop ratios from the supported minimum through no crop.
candidateCropRatios = minimumCropRatio:0.005:1.0;

% Ensure that the exact no-crop candidate is included.
if isempty(candidateCropRatios) || candidateCropRatios(end) < 1.0
    candidateCropRatios(end + 1) = 1.0;
end

% Preallocate one repeated-pattern consistency score per candidate.
cropScores = zeros(size(candidateCropRatios));

% Test every centered crop candidate.
for candidateIndex = 1:numel(candidateCropRatios)
    % Read the current candidate crop ratio.
    candidateRatio = candidateCropRatios(candidateIndex);
    % Map sampled attacked rows into centered original normalized coordinates.
    sourceRows = ((double(sampleRows) - 0.5) / imgH) * candidateRatio + ...
        (1 - candidateRatio) / 2;
    % Map source rows into repeated watermark row indices.
    rowBitIndices = mod(floor(sourceRows * tileRows * wmH), wmH) + 1;
    % Map sampled attacked columns into centered original normalized coordinates.
    sourceColumns = ((double(sampleColumns) - 0.5) / imgW) * ...
        candidateRatio + (1 - candidateRatio) / 2;
    % Map source columns into repeated watermark column indices.
    columnBitIndices = mod(floor(sourceColumns * tileColumns * wmW), wmW) + 1;
    % Build MATLAB linear payload indices for every synchronization sample.
    payloadIndices = rowBitIndices(:) + ...
        (columnBitIndices(:).' - 1) * wmH;
    % Sum signed LSB votes assigned to each encoded watermark bit.
    voteSums = accumarray(payloadIndices(:), sampleVotes(:), ...
        [numWatermarkBits, 1], @sum, 0);
    % Count sampled host pixels assigned to every encoded watermark bit.
    voteCounts = accumarray(payloadIndices(:), 1, ...
        [numWatermarkBits, 1], @sum, 0);
    % Identify encoded bits represented by at least one sample.
    representedBits = voteCounts > 0;
    % Normalize agreement by both spatial samples and embedded bit positions.
    cropScores(candidateIndex) = mean(abs(voteSums(representedBits)) ./ ...
        (voteCounts(representedBits) * embeddedBitsUsed));
end

% Select the crop candidate with the strongest repeated-pattern consistency.
[bestCropScore, bestCandidateIndex] = max(cropScores);

% Read the automatically estimated centered crop ratio.
bestCropRatio = candidateCropRatios(bestCandidateIndex);

% Reject an unconvincing geometric estimate when literal LSBs look random.
if bestCropScore < 0.40
    warning(['LSB synchronization confidence is low. Compression, noise, ' ...
        'blur, or unsupported geometry may have destroyed the replaced bits. ' ...
        'Retrieval will assume that no crop occurred.']);
    % Avoid applying an arbitrary crop transformation to a random LSB pattern.
    bestCropRatio = 1.0;
end

% Map every attacked row through the estimated centered crop transformation.
sourceRows = ((1:imgH) - 0.5) / imgH * bestCropRatio + ...
    (1 - bestCropRatio) / 2;

% Convert every mapped row into a repeated watermark row index.
rowBitIndices = mod(floor(sourceRows * tileRows * wmH), wmH) + 1;

% Map every attacked column through the estimated centered crop transformation.
sourceColumns = ((1:imgW) - 0.5) / imgW * bestCropRatio + ...
    (1 - bestCropRatio) / 2;

% Convert every mapped column into a repeated watermark column index.
columnBitIndices = mod(floor(sourceColumns * tileColumns * wmW), wmW) + 1;

% Build one linear payload index for every attacked-image pixel.
payloadIndices = rowBitIndices(:) + (columnBitIndices(:).' - 1) * wmH;

% Combine all spatial and bit-position votes for every encoded watermark bit.
voteSums = accumarray(payloadIndices(:), pixelVotes(:), ...
    [numWatermarkBits, 1], @sum, 0);

% Count surviving spatial samples assigned to every encoded watermark bit.
voteCounts = accumarray(payloadIndices(:), 1, ...
    [numWatermarkBits, 1], @sum, 0);

% Stop if an extreme crop leaves any watermark bit without a spatial vote.
if any(voteCounts == 0)
    error('The attacked image does not contain samples for every watermark bit.');
end

% Decode a positive combined majority as one and all other sums as zero.
recoveredEncodedBits = voteSums > 0;

% Regenerate the deterministic whitening sequence.
whiteningBits = make_whitening_bits(numWatermarkBits, whiteningSeed);

% Remove whitening to recover the original binary watermark vector.
watermarkBits = xor(recoveredEncodedBits, whiteningBits);

% Restore the original two-dimensional watermark shape.
reconstructedWatermark = reshape(watermarkBits, [wmH, wmW]);

% Read the requested output directory.
outputFolder = fileparts(outputWatermarkPath);

% Create the output directory when it does not already exist.
if ~isempty(outputFolder) && exist(outputFolder, 'dir') ~= 7
    mkdir(outputFolder);
end

% Save logical zero as black and logical one as white.
imwrite(uint8(reconstructedWatermark) * 255, outputWatermarkPath);

% Calculate normalized confidence across spatial and bit-position votes.
bitConfidence = abs(voteSums) ./ (voteCounts * embeddedBitsUsed);

% Report successful strict LSB retrieval.
fprintf('Tiled literal-LSB watermark retrieval complete.\n');

% Report the recovered watermark dimensions.
fprintf('Recovered watermark: %d x %d (%d bits).\n', ...
    wmW, wmH, numWatermarkBits);

% Report the automatically estimated centered crop ratio.
fprintf('Estimated centered crop ratio: %.3f.\n', bestCropRatio);

% Report crop synchronization confidence.
fprintf('Synchronization confidence: %.3f.\n', bestCropScore);

% Report average majority-vote confidence.
fprintf('Mean bit confidence: %.3f.\n', mean(bitConfidence));

% Report the generated watermark path.
fprintf('Recovered watermark saved to: %s\n', outputWatermarkPath);

% End the public strict LSB retrieval function.
end


function whiteningBits = make_whitening_bits(numberOfBits, seed)
%MAKE_WHITENING_BITS Regenerate deterministic logical bits with xorshift32.

% Convert the stored seed into a 32-bit unsigned state.
state = uint32(seed);

% Replace the forbidden all-zero generator state.
if state == 0
    state = uint32(2463534242);
end

% Preallocate the output logical column.
whiteningBits = false(numberOfBits, 1);

% Generate one whitening bit for every payload bit.
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
