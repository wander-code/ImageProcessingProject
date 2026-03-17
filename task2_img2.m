%% TASK 2 - IMAGE 2
clc;
clear;
close all;

%% STEP 1: Load image
I = imread('SegmentUs.jpg');
I_double = im2double(I);
[rows, cols, ~] = size(I);

%% STEP 2: Basic features
HSV = rgb2hsv(I_double);
H = HSV(:,:,1);
S = HSV(:,:,2);
V = HSV(:,:,3);

Lab = rgb2lab(I_double);
LabL = Lab(:,:,1);

I_gray = rgb2gray(I);

edgeMask = edge(I_gray, 'canny');
edgeMask = imdilate(edgeMask, strel('disk', 1));
edgeDensity = imboxfilt(double(edgeMask), 19);

localStd = stdfilt(I_gray, true(5));
localStd = mat2gray(localStd);

[Y, X] = ndgrid(1:rows, 1:cols);
yNorm = Y / rows;

%% STEP 3: Sky detection
topHalf = false(rows, cols);
topHalf(1:round(rows*0.62), :) = true;

blueSky  = (H > 0.50 & H < 0.72) & (V > 0.25) & (S > 0.08) & (S < 0.55);
warmSky  = (H > 0.04 & H < 0.16) & (V > 0.45) & (S > 0.10) & (S < 0.65);
neutralSky = (V > 0.35) & (S < 0.38) & (LabL > 35);

skyCandidate = (blueSky | warmSky | neutralSky) & topHalf & (localStd < 0.22);

topSeed = false(rows, cols);
topBand = max(2, round(rows * 0.08));
topSeed(1:topBand, :) = skyCandidate(1:topBand, :);

skyMask = imreconstruct(topSeed, skyCandidate);
skyMask = logical(skyMask);

skyMask = imclose(skyMask, strel('disk', 8));
skyMask = imfill(skyMask, 'holes');
skyMask = bwareaopen(skyMask, 4000);

%% STEP 4: Horizon estimation
horizon = ones(1, cols) * round(rows * 0.35);

for c = 1:cols
    r = find(skyMask(:, c), 1, 'last');
    if ~isempty(r)
        horizon(c) = r;
    end
end

horizon = round(movmean(horizon, 31));

aboveHorizon = false(rows, cols);
belowHorizon = false(rows, cols);

for c = 1:cols
    aboveHorizon(1:horizon(c), c) = true;
    if horizon(c) < rows
        belowHorizon(horizon(c)+1:end, c) = true;
    end
end

skyMask = skyMask & aboveHorizon;
skyMask = imclose(skyMask, strel('disk', 6));
skyMask = imfill(skyMask, 'holes');

%% STEP 5: Superpixels
numSuperpixels = 900;
[spLabels, numLabels] = superpixels(I, numSuperpixels);
labelIdx = label2idx(spLabels);
adj = buildSuperpixelAdjacency(spLabels, numLabels);

%% STEP 6: Per-superpixel classification
greenish = (H > 0.18 & H < 0.45) & (S > 0.10);
neutralLike = (S < 0.28) | (H < 0.10) | (H > 0.48);
darkBuilt = (V < 0.42) & (S < 0.45);
brightBuilt = (LabL > 55) & (S < 0.30);

greenCandidateLabel = false(numLabels, 1);
greenSeedLabel = false(numLabels, 1);

for k = 1:numLabels
    pix = labelIdx{k};

    meanSky = mean(skyMask(pix));
    if meanSky > 0.45
        continue;
    end

    meanGreen = mean(greenish(pix));
    meanNeutral = mean(neutralLike(pix));
    meanEdge = mean(edgeDensity(pix));
    meanStd = mean(localStd(pix));
    meanDarkBuilt = mean(darkBuilt(pix));
    meanBrightBuilt = mean(brightBuilt(pix));
    meanY = mean(yNorm(pix));

    % Natural score
    naturalScore = ...
        1.45 * meanGreen + ...
        0.35 * meanStd + ...
        0.18 * meanEdge + ...
        0.12 * max(0, 0.95 - meanY) - ...
        0.85 * meanNeutral - ...
        0.55 * meanDarkBuilt - ...
        0.45 * meanBrightBuilt;

    % Man-made score
    manmadeScore = ...
        1.00 * meanNeutral + ...
        0.90 * meanEdge + ...
        0.60 * meanStd + ...
        0.75 * meanDarkBuilt + ...
        0.70 * meanBrightBuilt + ...
        0.35 * max(0, meanY - 0.45) - ...
        1.15 * meanGreen;

    % Strong green seed
    if naturalScore > manmadeScore + 0.12 && meanGreen > 0.16
        greenSeedLabel(k) = true;
    end

    % Green candidate
    if naturalScore > manmadeScore - 0.03 && ...
       (meanGreen > 0.08 || (meanStd > 0.10 && meanNeutral < 0.55))
        greenCandidateLabel(k) = true;
    end
end

%% STEP 7: Connected natural growth
greenKeep = growConnectedLabels(greenCandidateLabel, greenSeedLabel, adj);

naturalMask = false(rows, cols);

for k = 1:numLabels
    if greenKeep(k)
        naturalMask(labelIdx{k}) = true;
    end
end

naturalMask = naturalMask & ~skyMask;

naturalMask = imclose(naturalMask, strel('disk', 5));
naturalMask = imopen(naturalMask, strel('disk', 2));
naturalMask = imfill(naturalMask, 'holes');
naturalMask = bwareaopen(naturalMask, 1200);

%% STEP 8: Man-made mask
manmadeMask = ~skyMask & ~naturalMask;

manmadeMask = imclose(manmadeMask, strel('disk', 3));
manmadeMask = imopen(manmadeMask, strel('disk', 1));
manmadeMask = imfill(manmadeMask, 'holes');
manmadeMask = bwareaopen(manmadeMask, 1500);

%% STEP 9: Final exclusivity
skyMask = logical(skyMask);
naturalMask = logical(naturalMask);
manmadeMask = logical(manmadeMask);

naturalMask = naturalMask & ~skyMask;
manmadeMask = manmadeMask & ~skyMask & ~naturalMask;

unlabeled = ~(skyMask | naturalMask | manmadeMask);
manmadeMask(unlabeled & ~skyMask) = 1;

%% STEP 10: Create output image
out = zeros(rows, cols, 3, 'uint8');

% Red = man-made
out(:,:,1) = uint8(manmadeMask) * 255;

% Green = natural
out(:,:,2) = uint8(naturalMask) * 255;

% Blue = sky
out(:,:,3) = uint8(skyMask) * 255;

%% STEP 11: Preview
figure('Name', 'TASK 2 - IMAGE 2', 'NumberTitle', 'off');

subplot(2,3,1);
imshow(I);
title('Original');

subplot(2,3,2);
imshow(skyMask);
title('Sky Mask');

subplot(2,3,3);
imshow(naturalMask);
title('Natural Mask');

subplot(2,3,4);
imshow(manmadeMask);
title('Man-Made Mask');

subplot(2,3,5);
imshow(labeloverlay(I, uint8(skyMask) + 2*uint8(naturalMask) + 3*uint8(manmadeMask)));
title('Overlay Preview');

subplot(2,3,6);
imshow(out);
title('Final Segmented Output');

%% STEP 12: Save outputs
imwrite(skyMask, 'task2_img2_sky_mask.jpg');
imwrite(naturalMask, 'task2_img2_natural_mask.jpg');
imwrite(manmadeMask, 'task2_img2_manmade_mask.jpg');
imwrite(out, 'task2_img2_segmented_output.jpg');

fprintf('==============================================\n');
fprintf('         PROJECT IN IMAGE PROCESSING\n');
fprintf('==============================================\n');
fprintf(' Task       : Task 2 - Image 2\n');
fprintf(' Process    : Sky / natural / man-made segmentation\n');
fprintf(' Output     : Completed successfully\n');
fprintf('==============================================\n');
fprintf(' Regions:\n');
fprintf(' - Blue  : Sky\n');
fprintf(' - Green : Natural / vegetation\n');
fprintf(' - Red   : Man-made\n');
fprintf('==============================================\n');

%% ============================================================
%% LOCAL FUNCTIONS
%% ============================================================

function adj = buildSuperpixelAdjacency(L, numLabels)
    adj = false(numLabels, numLabels);

    A = L(:, 1:end-1);
    B = L(:, 2:end);
    diffMask = A ~= B;
    p1 = A(diffMask);
    p2 = B(diffMask);

    for i = 1:numel(p1)
        adj(p1(i), p2(i)) = true;
        adj(p2(i), p1(i)) = true;
    end

    A = L(1:end-1, :);
    B = L(2:end, :);
    diffMask = A ~= B;
    p1 = A(diffMask);
    p2 = B(diffMask);

    for i = 1:numel(p1)
        adj(p1(i), p2(i)) = true;
        adj(p2(i), p1(i)) = true;
    end
end

function keep = growConnectedLabels(candidate, seed, adj)
    n = numel(candidate);
    keep = false(n, 1);

    startNodes = find(seed);
    if isempty(startNodes)
        return;
    end

    queue = startNodes(:)';
    keep(queue) = true;

    while ~isempty(queue)
        current = queue(1);
        queue(1) = [];

        neighbors = find(adj(current, :));
        for j = 1:numel(neighbors)
            nb = neighbors(j);
            if candidate(nb) && ~keep(nb)
                keep(nb) = true;
                queue(end+1) = nb; 
            end
        end
    end
end