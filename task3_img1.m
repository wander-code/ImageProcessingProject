%% TASK 3 - IMAGE 1

clc;
clear;
close all;

%% STEP 1: Load image
I = imread('IMG_8236.jpg');
I_double = im2double(I);
[rows, cols, ~] = size(I);

I_gray = rgb2gray(I);
G = imgaussfilt(I_gray, 1.4);

HSV = rgb2hsv(I_double);
S = HSV(:,:,2);
V = HSV(:,:,3);

Lab = rgb2lab(I_double);
Lch = Lab(:,:,1);
Ach = Lab(:,:,2);
Bch = Lab(:,:,3);

%% STEP 2: Edge-based initial mask
roi = false(rows, cols);
roi(round(rows*0.08):round(rows*0.98), ...
    round(cols*0.20):round(cols*0.72)) = true;

E1 = edge(G, 'Canny', [0.04 0.15]);
E2 = edge(V, 'Canny', [0.03 0.12]);
E = (E1 | E2) & roi;

E = imdilate(E, strel('disk', 2));
E = imclose(E, strel('disk', 8));

initMask = imfill(E, 'holes');
initMask = initMask & roi;
initMask = bwareaopen(initMask, 700);
initMask = selectBestCatComponent(initMask, rows, cols);

initMask = imclose(initMask, strel('disk', 8));
initMask = imfill(initMask, 'holes');
initMask = bwareaopen(initMask, 1000);

%% STEP 3: Build cat-shaped envelope
stats = regionprops(initMask, 'BoundingBox');
if isempty(stats)
    error('Initial cat mask could not be formed.');
end

bb = stats(1).BoundingBox; % [x y w h]
catEnvelope = makeCatEnvelopeFromBBox(bb, rows, cols) & roi;

%% STEP 4: Build fur color models from initial mask
seedMask = imerode(initMask, strel('disk', 2));
if nnz(seedMask) < 200
    seedMask = initMask;
end

seedL = Lch(seedMask);
medL = median(seedL);

lightSeed = seedMask & (Lch >= medL);
darkSeed  = seedMask & (Lch <  medL);

if nnz(lightSeed) < 50
    lightSeed = seedMask;
end
if nnz(darkSeed) < 50
    darkSeed = seedMask;
end

muLight = [mean(Lch(lightSeed)), mean(Ach(lightSeed)), mean(Bch(lightSeed))];
sgLight = [std(Lch(lightSeed))+1e-6, std(Ach(lightSeed))+1e-6, std(Bch(lightSeed))+1e-6];

Dlight = sqrt( ...
    ((Lch - muLight(1))./sgLight(1)).^2 + ...
    ((Ach - muLight(2))./sgLight(2)).^2 + ...
    ((Bch - muLight(3))./sgLight(3)).^2 );

muDark = [mean(Lch(darkSeed)), mean(Ach(darkSeed)), mean(Bch(darkSeed))];
sgDark = [std(Lch(darkSeed))+1e-6, std(Ach(darkSeed))+1e-6, std(Bch(darkSeed))+1e-6];

Ddark = sqrt( ...
    ((Lch - muDark(1))./sgDark(1)).^2 + ...
    ((Ach - muDark(2))./sgDark(2)).^2 + ...
    ((Bch - muDark(3))./sgDark(3)).^2 );

%% STEP 5: Recover missing cat body
lightCandidate = catEnvelope & ...
    (Dlight < 4.8) & ...
    (S < 0.30) & ...
    (V > 0.35) & ...
    (V < 0.98);

darkCandidate = catEnvelope & ...
    (Ddark < 4.8) & ...
    (S < 0.42) & ...
    (V > 0.08) & ...
    (V < 0.65);

% Remove obvious colorful clutter
lightCandidate(S > 0.48) = 0;
darkCandidate(S > 0.50) = 0;

% Marker for normal growth
marker1 = imdilate(initMask, strel('disk', 4)) & catEnvelope;

% Marker for right-side growth (to recover the cat's back)
marker2 = imdilate(initMask, strel('line', 35, 0)) & catEnvelope;

recoveredLight = imreconstruct(marker1, lightCandidate | marker1);
recoveredDark  = imreconstruct(marker2, darkCandidate  | marker2);

catMask = initMask | recoveredLight | recoveredDark;

%% STEP 6: Solidify mask into one cat shape
catMask = catMask & catEnvelope;
catMask = imfill(catMask, 'holes');
catMask = imclose(catMask, strel('disk', 10));
catMask = imopen(catMask, strel('disk', 1));
catMask = bwareaopen(catMask, 1400);

% Recover small remaining gaps without creating a big block
catMask = imfill(catMask, 'holes');
catMask = imclose(catMask, strel('disk', 6));

catMask = selectBestCatComponent(catMask, rows, cols);

%% STEP 7: Feather mask
featherMask = imgaussfilt(double(catMask), 5);

%% STEP 8: Strong background blur
blurredBG = zeros(size(I_double));
for c = 1:3
    blurredBG(:,:,c) = imgaussfilt(I_double(:,:,c), 20);
end

%% STEP 9: Composite sharp cat + blurred background
I_portrait = zeros(size(I_double));
for c = 1:3
    I_portrait(:,:,c) = featherMask .* I_double(:,:,c) + ...
                        (1 - featherMask) .* blurredBG(:,:,c);
end

%% STEP 10: Preview
maskRGB = repmat(catMask, [1 1 3]);

I_detected = I;
I_detected(~maskRGB) = 0;

catMask_uint8 = uint8(catMask) * 255;
I_portrait_uint8 = im2uint8(I_portrait);

figure('Name', 'TASK 3 - IMAGE 1', 'NumberTitle', 'off');

subplot(2,3,1);
imshow(I);
title('Original');

subplot(2,3,2);
imshow(initMask);
title('Solid Initial Mask');

subplot(2,3,3);
imshow(catMask);
title('Final Cat Mask');

subplot(2,3,4);
imshow(I_detected);
title('Detected Cat Only');

subplot(2,3,5);
imshow(blurredBG);
title('Blurred Background');

subplot(2,3,6);
imshow(I_portrait_uint8);
title('Portrait Blur Output');

%% STEP 11: Save outputs
imwrite(I_detected, 'task3_img1_detected_cat.jpg');
imwrite(catMask_uint8, 'task3_img1_cat_mask.jpg');
imwrite(I_portrait_uint8, 'task3_img1_portrait_blur.jpg');

fprintf('==============================================\n');
fprintf('         PROJECT IN IMAGE PROCESSING\n');
fprintf('==============================================\n');
fprintf(' Task       : Task 3 - Image 1\n');
fprintf(' Process    : Edge-based cat segmentation + Gaussian background blur\n');
fprintf(' Output     : Completed successfully\n');
fprintf('==============================================\n');

function BW = selectBestCatComponent(BW, rows, cols)
    CC = bwconncomp(BW);

    if CC.NumObjects == 0
        BW = false(rows, cols);
        return;
    end

    stats = regionprops(CC, 'Area', 'Centroid', 'BoundingBox');
    scores = -inf(CC.NumObjects, 1);

    targetX = cols * 0.46;
    targetY = rows * 0.58;

    for k = 1:CC.NumObjects
        areaVal = stats(k).Area;
        cx = stats(k).Centroid(1);
        cy = stats(k).Centroid(2);
        bb = stats(k).BoundingBox;
        h = bb(4);
        w = bb(3);

        centerPenalty = ((cx - targetX)/cols)^2 + ((cy - targetY)/rows)^2;
        tallness = h / (w + eps);

        scores(k) = ...
            0.00025 * areaVal + ...
            40 * tallness + ...
            0.20 * h - ...
            900 * centerPenalty;
    end

    [~, bestIdx] = max(scores);

    out = false(rows, cols);
    out(CC.PixelIdxList{bestIdx}) = true;
    BW = out;
end

function env = makeCatEnvelopeFromBBox(bb, rows, cols)
    x = bb(1);
    y = bb(2);
    w = bb(3);
    h = bb(4);

    % Head
    headCx = x + 0.48*w;
    headCy = y + 0.16*h;
    headRx = 0.22*w;
    headRy = 0.18*h;

    % Front torso
    body1Cx = x + 0.48*w;
    body1Cy = y + 0.54*h;
    body1Rx = 0.22*w;
    body1Ry = 0.34*h;

    % Back / right side body
    body2Cx = x + 0.72*w;
    body2Cy = y + 0.62*h;
    body2Rx = 0.34*w;
    body2Ry = 0.30*h;

    % Lower body / paws
    legMask = false(rows, cols);
    x1 = max(1, round(x + 0.22*w));
    x2 = min(cols, round(x + 0.82*w));
    y1 = max(1, round(y + 0.62*h));
    y2 = min(rows, round(y + 1.03*h));
    legMask(y1:y2, x1:x2) = true;

    headMask  = ellipseMaskGlobal(headCx, headCy, headRx, headRy, rows, cols);
    body1Mask = ellipseMaskGlobal(body1Cx, body1Cy, body1Rx, body1Ry, rows, cols);
    body2Mask = ellipseMaskGlobal(body2Cx, body2Cy, body2Rx, body2Ry, rows, cols);

    env = headMask | body1Mask | body2Mask | legMask;
    env = imclose(env, strel('disk', 14));
    env = imfill(env, 'holes');
end

function BW = ellipseMaskGlobal(cx, cy, rx, ry, rows, cols)
    [X, Y] = meshgrid(1:cols, 1:rows);
    BW = ((X - cx).^2 ./ (rx.^2 + eps) + (Y - cy).^2 ./ (ry.^2 + eps)) <= 1;
end