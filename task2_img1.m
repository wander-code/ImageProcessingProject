%% TASK 2 - IMAGE 1
clc;
clear;
close all;

I = imread('IMG_8870.jpg');
I_double = im2double(I);
[rows, cols, ~] = size(I);

HSV = rgb2hsv(I_double);
H = HSV(:,:,1);
S = HSV(:,:,2);
V = HSV(:,:,3);

Lab = rgb2lab(I_double);
LabL = Lab(:,:,1);

I_gray = rgb2gray(I);

edgeMask = edge(I_gray, 'canny');
edgeMask = imdilate(edgeMask, strel('disk', 1));
edgeDensity = imboxfilt(double(edgeMask), 21);

localStd = stdfilt(I_gray, true(5));
localStd = mat2gray(localStd);

[Y, X] = ndgrid(1:rows, 1:cols);
yNorm = Y / rows;
xNorm = X / cols;

%% ------------------------------------------------------------
%% STEP 1: SKY DETECTION

skyCandidate = ...
    (V > 0.45) & ...
    (S < 0.35) & ...
    (LabL > 45);

topSeed = false(rows, cols);
topBand = max(2, round(rows * 0.08));
topSeed(1:topBand, :) = skyCandidate(1:topBand, :);

skyConnected = imreconstruct(topSeed, skyCandidate);
skyConnected = logical(skyConnected);

skyConnected = imclose(skyConnected, strel('disk', 8));
skyConnected = imfill(skyConnected, 'holes');
skyConnected = bwareaopen(skyConnected, 5000);

%% ------------------------------------------------------------
%% STEP 2: SMOOTHED HORIZON
horizon = ones(1, cols) * round(rows * 0.35);

for c = 1:cols
    r = find(skyConnected(:, c), 1, 'last');
    if ~isempty(r)
        horizon(c) = r;
    end
end

horizon = round(movmean(horizon, 41));

aboveHorizon = false(rows, cols);
belowHorizon = false(rows, cols);

for c = 1:cols
    aboveHorizon(1:horizon(c), c) = true;
    if horizon(c) < rows
        belowHorizon(horizon(c)+1:end, c) = true;
    end
end

skyMask = aboveHorizon;

%% ------------------------------------------------------------
%% STEP 3: GREEN BAND AND RED BASE

greenBandDepth = round(rows * 0.20);
redBase = horizon + greenBandDepth;
redBase = min(redBase, rows);

greenBand = false(rows, cols);
belowRedBase = false(rows, cols);

for c = 1:cols
    h = horizon(c);
    r = redBase(c);

    if h < r
        greenBand(h+1:r, c) = true;
    end
    if r < rows
        belowRedBase(r+1:end, c) = true;
    end
end

%% ------------------------------------------------------------
%% STEP 4: SUPERPIXELS
numSuperpixels = 700;
[spLabels, numLabels] = superpixels(I, numSuperpixels);
labelIdx = label2idx(spLabels);
adj = buildSuperpixelAdjacency(spLabels, numLabels);

%% ------------------------------------------------------------
%% STEP 5: FEATURE CUES

greenish = (H > 0.18 & H < 0.42) & (S > 0.10);
neutralLike = (S < 0.28) | (H < 0.12) | (H > 0.45);
darkRoof = (V < 0.42) & (S < 0.45);
brightWall = (LabL > 58) & (S < 0.28);

leftSlopeBias = (xNorm < 0.24) & (yNorm > 0.60);

redCandidateLabel   = false(numLabels, 1);
redSeedLabel        = false(numLabels, 1);
redProtrusionLabel  = false(numLabels, 1);

greenCandidateLabel = false(numLabels, 1);
greenSeedLabel      = false(numLabels, 1);

for k = 1:numLabels
    pix = labelIdx{k};

    meanBelowHorizon = mean(belowHorizon(pix));
    if meanBelowHorizon < 0.25
        continue;
    end

    meanAboveHorizon = mean(aboveHorizon(pix));
    meanGreenBand = mean(greenBand(pix));
    meanBelowRedBase = mean(belowRedBase(pix));

    meanEdge = mean(edgeDensity(pix));
    meanStd = mean(localStd(pix));
    meanY = mean(yNorm(pix));
    meanGreen = mean(greenish(pix));
    meanNeutral = mean(neutralLike(pix));
    meanDarkRoof = mean(darkRoof(pix));
    meanBrightWall = mean(brightWall(pix));
    meanLeftSlope = mean(leftSlopeBias(pix));
    meanS = mean(S(pix));
    meanV = mean(V(pix));

    hazeNatural = ...
        (meanS < 0.32) && ...
        (meanV < 0.72) && ...
        (meanEdge < 0.12) && ...
        (meanStd < 0.20);

    greenScore = ...
        1.30 * meanGreen + ...
        0.40 * (1 - meanNeutral) + ...
        0.30 * (1 - meanEdge) + ...
        0.22 * (1 - meanStd) + ...
        0.40 * meanGreenBand + ...
        0.35 * meanLeftSlope + ...
        0.35 * double(hazeNatural);

    redScore = ...
        1.35 * meanEdge + ...
        0.95 * meanStd + ...
        0.85 * meanDarkRoof + ...
        0.85 * meanBrightWall + ...
        0.40 * meanNeutral + ...
        0.60 * meanBelowRedBase + ...
        0.40 * max(0, meanY - 0.62) - ...
        1.40 * meanGreen - ...
        0.75 * meanLeftSlope - ...
        0.50 * meanGreenBand - ...
        0.30 * double(hazeNatural);

    if (meanGreenBand > 0.18 && greenScore >= redScore - 0.02) || ...
       (meanLeftSlope > 0.25 && meanBelowHorizon > 0.45) || ...
       (hazeNatural && meanY < 0.80 && redScore < greenScore + 0.10)
        greenSeedLabel(k) = true;
    end

    if meanBelowHorizon > 0.30 && ...
       (greenScore >= redScore - 0.08) && ...
       (meanGreen > 0.08 || hazeNatural || meanGreenBand > 0.08 || meanLeftSlope > 0.15)
        greenCandidateLabel(k) = true;
    end

    if meanBelowRedBase > 0.22 && ...
       meanEdge > 0.04 && ...
       redScore > greenScore + 0.14
        redCandidateLabel(k) = true;
    end

    if meanBelowRedBase > 0.72 && ...
       redScore > greenScore + 0.22 && ...
       (meanEdge > 0.08 || meanStd > 0.16)
        redSeedLabel(k) = true;
    end

    if meanBelowHorizon > 0.55 && ...
       meanBelowRedBase > 0.04 && ...
       redScore > greenScore + 0.30 && ...
       (meanEdge > 0.10 || meanDarkRoof > 0.20 || meanBrightWall > 0.20)
        redProtrusionLabel(k) = true;
    end

    if meanLeftSlope > 0.30 && meanGreen > 0.18 && meanEdge < 0.12
        redCandidateLabel(k) = false;
        redSeedLabel(k) = false;
        redProtrusionLabel(k) = false;
        greenSeedLabel(k) = true;
        greenCandidateLabel(k) = true;
    end
end

%% ------------------------------------------------------------
%% STEP 6: CONNECTED GREEN MOUNTAIN GROWTH
greenLabelKeep = growConnectedLabels(greenCandidateLabel, greenSeedLabel, adj);

%% ------------------------------------------------------------
%% STEP 7: CONNECTED RED REGION GROWTH

redLabelKeep = growConnectedLabels(redCandidateLabel, redSeedLabel, adj);
protrusionKeep = growConnectedLabels(redProtrusionLabel, redLabelKeep, adj);
finalRedLabelKeep = redLabelKeep | protrusionKeep;

%% ------------------------------------------------------------
%% STEP 8: BUILD PIXEL MASKS
manmadeMask = false(rows, cols);
mountainSeedMask = false(rows, cols);

for k = 1:numLabels
    pix = labelIdx{k};

    if finalRedLabelKeep(k)
        manmadeMask(pix) = true;
    end

    if greenLabelKeep(k)
        mountainSeedMask(pix) = true;
    end
end

manmadeMask = manmadeMask & belowHorizon;
manmadeMask = imclose(manmadeMask, strel('disk', 3));
manmadeMask = imfill(manmadeMask, 'holes');
manmadeMask = bwareaopen(manmadeMask, 500);

%% ------------------------------------------------------------
%% STEP 9: BUILD MOUNTAIN / GREEN REGION

mountainMask = belowHorizon & ~manmadeMask;
mountainMask = mountainMask | (mountainSeedMask & ~manmadeMask);

mountainMask(greenBand & ~manmadeMask) = 1;

mountainMask(leftSlopeBias & belowHorizon & ~manmadeMask) = 1;

mountainMask = imclose(mountainMask, strel('disk', 6));
mountainMask = imopen(mountainMask, strel('disk', 2));
mountainMask = imfill(mountainMask, 'holes');
mountainMask = bwareaopen(mountainMask, 1200);

%% ------------------------------------------------------------
%% STEP 10: FINAL LABEL ENFORCEMENT
skyMask = logical(skyMask);
mountainMask = logical(mountainMask);
manmadeMask = logical(manmadeMask);

skyMask = skyMask & ~manmadeMask;
mountainMask = mountainMask & ~skyMask & ~manmadeMask;
manmadeMask = manmadeMask & ~skyMask;

unlabeled = ~(skyMask | mountainMask | manmadeMask);
skyMask(unlabeled & aboveHorizon) = 1;

unlabeled = ~(skyMask | mountainMask | manmadeMask);
mountainMask(unlabeled & belowHorizon) = 1;

mountainMask = mountainMask & ~skyMask & ~manmadeMask;
manmadeMask = manmadeMask & ~skyMask;

%% ------------------------------------------------------------
%% STEP 11: CREATE OUTPUT IMAGE
% sky = blue
% mountains / vegetation = green
% man-made = red

out = zeros(rows, cols, 3, 'uint8');
out(:,:,1) = uint8(manmadeMask) * 255;
out(:,:,2) = uint8(mountainMask) * 255;
out(:,:,3) = uint8(skyMask) * 255;

%% ------------------------------------------------------------
%% STEP 12: DISPLAY RESULTS
figure('Name', 'TASK 2 - IMAGE 1', 'NumberTitle', 'off');

subplot(2,3,1);
imshow(I);
title('Original');

subplot(2,3,2);
imshow(skyMask);
title('Sky Mask');

subplot(2,3,3);
imshow(mountainMask);
title('Mountain Mask');

subplot(2,3,4);
imshow(manmadeMask);
title('Man-Made Mask');

subplot(2,3,5);
imshow(labeloverlay(I, uint8(skyMask) + 2*uint8(mountainMask) + 3*uint8(manmadeMask)));
title('Overlay Preview');

subplot(2,3,6);
imshow(out);
title('Final Segmented Output');

%% ------------------------------------------------------------
%% STEP 13: SAVE OUTPUTS
imwrite(skyMask, 'task2_img1_sky_mask.jpg');
imwrite(mountainMask, 'task2_img1_mountain_mask.jpg');
imwrite(manmadeMask, 'task2_img1_manmade_mask.jpg');
imwrite(out, 'task2_img1_segmented_output.jpg');

%% Console output
fprintf('==============================================\n');
fprintf('         PROJECT IN IMAGE PROCESSING\n');
fprintf('==============================================\n');
fprintf(' Task       : Task 2 - Image 1\n');
fprintf(' Process    : Horizon + connected mountain growth + strict lower red\n');
fprintf(' Output     : Completed successfully\n');
fprintf('==============================================\n');
fprintf(' Regions:\n');
fprintf(' - Blue  : Sky\n');
fprintf(' - Green : Mountains / vegetation\n');
fprintf(' - Red   : Man-made areas\n');
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