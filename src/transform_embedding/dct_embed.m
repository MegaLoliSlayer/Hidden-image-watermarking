%definition of dct_embed function
function dct_embed(inputImagePath, watermarkPath, outputImagePath, metadataPath, strength)

%DCT-based transform-domain watermark embedding
%input:
%inputImagePath: original image path
%watermarkPath: binary watermark image path
%outputImagePath: output watermarked image path
%metadataPath: metadata output path
%strength: embedding strength
%main idea:
%1.Read original image
%2.Convert image from RGB to YCbCr
%3.Use the Y brightness channel
%4.Split the Y channel into 8x8 blocks
%5.Apply DCT to each block
%6.Hide one watermark bit in each block
%7.Use two mid-frequency DCT coefficients
%8.If bit = 1, make coefficient 1 larger than coefficient 2
%9.If bit = 0, make coefficient 2 larger than coefficient 1
%10.Apply inverse DCT
%11.Rebuild and save the watermarked image
%12.Save metadata for retrieval

%check whether the strength is provided or not(input provided < 5)
%if not provided, default set to 20
if nargin < 5
    strength = 20;
end

%DCT block size
%The image will be divided into 8x8 blocks, each block stores one watermark
%bit
blockSize = 8;

%Read the original image
%reads the original image and stores in img
img = imread(inputImagePath);

%check whether the image has 3 color channels
%check the third dimension of the image
if size(img, 3) ~= 3
    error('Input image must be an RGB image.');
end

%convert RGB color space to YCbCr color space
%Y = brightness
%Cb = blue color difference
%Cr = red color difference
%used YCbCr because we are watermarking the brightness channel
%This extract the Y channel and converts the pixel values to double
%precision numbers
imgDouble = double(img);

R = imgDouble(:, :, 1);
G = imgDouble(:, :, 2);
B = imgDouble(:, :, 3);

Y  = 0.299 * R + 0.587 * G + 0.114 * B;
Cb = 128 - 0.168736 * R - 0.331264 * G + 0.5 * B;
Cr = 128 + 0.5 * R - 0.418688 * G - 0.081312 * B;

%This gets the height and width of the Y channel
%originalH = image height
%orignialW = imaghe width
[originalH, originalW] = size(Y);

%Pad the image
%calculates how many extra rows and columns are needed so the image size
%becomes divisible by 8(since the DCT block is 8x8)
padH = mod(blockSize - mod(originalH, blockSize), blockSize);
padW = mod(blockSize - mod(originalW, blockSize), blockSize);

%Pads the Y channel by copying the last row and last column
paddedH = originalH + padH;
paddedW = originalW + padW;

paddedY = zeros(paddedH, paddedW);

paddedY(1:originalH, 1:originalW) = Y;

if padH > 0
    paddedY(originalH+1:paddedH, 1:originalW) = repmat(Y(end, :), padH, 1);
end

if padW > 0
    paddedY(:, originalW+1:paddedW) = repmat(paddedY(:, originalW), 1, padW);
end


%calculate how many 8x8 blocks the image has
%number of blocks vertically
numBlocksH = paddedH / blockSize;
%number of blocks horizontaly
numBlocksW = paddedW / blockSize;
%maximum number of watermark bits this image can store
maxBits = numBlocksH * numBlocksW;

%Read the watermark
watermark = imread(watermarkPath);

%If the watermark is RGB, convert to grayscale
%because we only need binary watermark bits(0 or 1/black or white)
if size(watermark, 3) == 3
    watermarkDouble = double(watermark);
    watermarkGray = 0.299 * watermarkDouble(:, :, 1) + ...
                    0.587 * watermarkDouble(:, :, 2) + ...
                    0.114 * watermarkDouble(:, :, 3);
else
    watermarkGray = double(watermark);
end

%This converts the grayscale watermark into a binary image
%if pixel > 128, make it 1
%if pixel <=128, make it 0
watermarkBinary = watermarkGray > 128;

%This turns the 2D watermark image into a 1D list of bits
watermarkBits = watermarkBinary(:);

%This counts how many bits the watermark has
numBits = length(watermarkBits);

%check whether the watermark can fit inside the original image
%watermark cannot be larger than the number of blocks
if numBits > maxBits
    error('Watermark is too large for this image.');
end

%Choose DCT coefficients
%these are two mid-frequency coefficient positions inside each 8x8 DCT block
%low-frequency coefficients affect image quality too much
%high-frequency coefficients are easily destroyed by compression/noise
%mid-frequency coefficients are a balance between inivibility and robustness
%row 4, column 5
coeff1 = [4,5];
%row 5, column 4
coeff2 = [5,4];
%DCT matrix
D = create_dct_matrix(blockSize);

% Select block positions spread evenly across the whole image
selectedBlockIndices = round(linspace(1, maxBits, numBits));

for bitIndex = 1:numBits

    % Convert selected 1D block index into block row and block column
    blockIndex = selectedBlockIndices(bitIndex);

    blockRow = floor((blockIndex - 1) / numBlocksW) + 1;
    blockCol = mod(blockIndex - 1, numBlocksW) + 1;

    % Calculate the starting pixel position of the selected block
    rowStart = (blockRow - 1) * blockSize + 1;
    colStart = (blockCol - 1) * blockSize + 1;

    % Extract one 8x8 block from the padded Y channel
    block = paddedY(rowStart:rowStart+blockSize-1, ...
                    colStart:colStart+blockSize-1);

    %Apply DCT
    %This applies the 2D Discrete Cosine Transform to the 8x8 block
    %before DCT, the block contains pixel brightness values
    %after DCT, the block contains frequency coefficients
    dctBlock = D * block * D';

    % Get the current watermark bit
    bit = watermarkBits(bitIndex);

    % Read the two selected DCT coefficients
    c1 = dctBlock(coeff1(1), coeff1(2));
    c2 = dctBlock(coeff2(1), coeff2(2));

    % Embed bit by forcing a coefficient relationship
    %embed bit 1
    if bit == 1
        %if the watermark bit is 1, we want c1 > c2
        %check whether c1 is not large enough compared to c2
        %c1 should be greater than c2 by about strength to make the
        %watermakr more robust
        if c1 <= c2 + strength
            %calculates the average of the two coefficients
            avg = (c1 + c2) / 2;
            %modifies the two DCT coefficients 
            %for bit 1, it forces coeff1 > coeff2
            %specifically coeff1 = average + strength/2
            %coeff2 = average - strength/2
            %so the distance between them becomes about strength
            dctBlock(coeff1(1), coeff1(2)) = avg + strength / 2;
            dctBlock(coeff2(1), coeff2(2)) = avg - strength / 2;
        end
    %embed bit 0
    else
        %For bit 0: coeff2 should be greater than coeff1 by about
        %strength
        if c2 <= c1 + strength
            %calculate the average
            avg = (c1 + c2) / 2;
            %force coeff2 > coeff1
            dctBlock(coeff1(1), coeff1(2)) = avg - strength / 2;
            dctBlock(coeff2(1), coeff2(2)) = avg + strength / 2;
        end
    end

    % Apply manual inverse 2D DCT
    %converts the modified DCT coefficients back into pixel values
    %which the blocks now contains the hidden watermark information
    modifiedBlock = D' * dctBlock * D;

    % Put the modified block back into the Y channel
    paddedY(rowStart:rowStart+blockSize-1, ...
            colStart:colStart+blockSize-1) = modifiedBlock;
end

%Crop image back to original size
%since we padded the image to make it divisible by 8
%now we remove the extra padding to keep only the original image size
modifiedY = paddedY(1:originalH, 1:originalW);

%put the modified Y channel back and make sure the pixel values are within
%the range of 0:255 and converts the image from YCbCr color space back to RGB color space
newR = modifiedY + 1.402 * (Cr - 128);
newG = modifiedY - 0.344136 * (Cb - 128) - 0.714136 * (Cr - 128);
newB = modifiedY + 1.772 * (Cb - 128);

watermarkedImg = zeros(originalH, originalW, 3);
watermarkedImg(:, :, 1) = newR;
watermarkedImg(:, :, 2) = newG;
watermarkedImg(:, :, 3) = newB;

watermarkedImg = uint8(min(max(watermarkedImg, 0), 255));

%save the final watermarked image
imwrite(watermarkedImg, outputImagePath);

%save metadata
metadata.method = 'DCT transform-domain watermarking';
metadata.inputImage = inputImagePath;
metadata.watermarkImage = watermarkPath;
metadata.outputImage = outputImagePath;
metadata.originalHeight = originalH;
metadata.originalWidth = originalW;
metadata.paddedHeight = paddedH;
metadata.paddedWidth = paddedW;
metadata.watermarkHeight = size(watermarkBinary,1);
metadata.watermarkWidth = size(watermarkBinary,2);
metadata.numEmbeddedBits = numBits;
metadata.strength = strength;
metadata.blockSize = blockSize;
metadata.coeff1 = coeff1;
metadata.coeff2 = coeff2;
metadata.selectedBlockIndices = selectedBlockIndices;
metadata.channel = 'Manual Y channel from RGB to YCbCr conversion';

%converts the matlab metadata structure into JSON text
jsonText = jsonencode(metadata);

%open the meta data file for writing
fid = fopen(metadataPath, 'w');

%writes the JSON text into the metadata file
fprintf(fid, '%s', jsonText);

%close the metadata file
fclose(fid);

fprintf('DCT watermark embedding complete.\n');
fprintf('Output image saved to: %s\n', outputImagePath);
fprintf('Metadata saved to: %s\n', metadataPath);

end

function D = create_dct_matrix(N)
% Create an NxN DCT transform matrix manually

D = zeros(N, N);

for k = 0:N-1
    for n = 0:N-1
        if k == 0
            alpha = sqrt(1 / N);
        else
            alpha = sqrt(2 / N);
        end

        D(k+1, n+1) = alpha * cos(((2*n + 1) * k * pi) / (2 * N));
    end
end

end



















