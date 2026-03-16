%% %% TASK 3 - IMAGE 2
clc;
clear;
close all;

%% STEP 1: Load image
I = imread('BlurUs.jpg');
I_double = im2double(I);
[rows, cols, ~] = size(I);

I_gray = rgb2gray(I);
G = imgaussfilt(I_gray, 1.2);

Lab = rgb2lab(I_double);
Lch = Lab(:,:,1);
Ach = Lab(:,:,2);
Bch = Lab(:,:,3);

YCbCr = rgb2ycbcr(I);
Yc  = YCbCr(:,:,1);
Cb  = YCbCr(:,:,2);
Cr  = YCbCr(:,:,3);

skinLike = (Cb >= 77 & Cb <= 127) & (Cr >= 133 & Cr <= 173) & (Yc >= 55);

%% STEP 2: Build seeds and envelopes
roi = false(rows, cols);
roi(round(rows*0.34):round(rows*0.98), ...
    round(cols*0.18):round(cols*0.78)) = true;

people = struct([]);

% LEFT
people(1).seed = false(rows, cols);

people(1).headSeed = headStackMask(cols*0.343, rows*0.547, 1.04, rows, cols);
people(1).headTopSeed = ellipseMask(cols*0.340, rows*0.514, cols*0.024, rows*0.034, rows, cols);
people(1).faceSeed = rectMask(round(cols*0.292), round(rows*0.500), ...
                              round(cols*0.365), round(rows*0.610), rows, cols);

people(1).bodySeed = ellipseMask(cols*0.345, rows*0.745, cols*0.064, rows*0.170, rows, cols);
people(1).shoulderSeed = rectMask(round(cols*0.258), round(rows*0.620), ...
                                  round(cols*0.418), round(rows*0.805), rows, cols);
people(1).legsSeed = rectMask(round(cols*0.288), round(rows*0.73), ...
                              round(cols*0.408), round(rows*0.97), rows, cols);
people(1).sleeveSeed = rectMask(round(cols*0.218), round(rows*0.655), ...
                                round(cols*0.368), round(rows*0.945), rows, cols);
people(1).armSeed = rectMask(round(cols*0.192), round(rows*0.725), ...
                             round(cols*0.345), round(rows*0.955), rows, cols);

people(1).seed = people(1).headSeed | people(1).headTopSeed | people(1).faceSeed | ...
                 people(1).bodySeed | people(1).shoulderSeed | people(1).legsSeed | ...
                 people(1).sleeveSeed | people(1).armSeed;

people(1).headEnv = headStackMask(cols*0.343, rows*0.542, 1.62, rows, cols);
people(1).headTopEnv = ellipseMask(cols*0.340, rows*0.505, cols*0.042, rows*0.060, rows, cols);
people(1).faceEnv = rectMask(round(cols*0.272), round(rows*0.470), ...
                             round(cols*0.382), round(rows*0.635), rows, cols);

people(1).bodyEnv = ellipseMask(cols*0.350, rows*0.755, cols*0.102, rows*0.218, rows, cols);
people(1).shoulderEnv = rectMask(round(cols*0.228), round(rows*0.592), ...
                                 round(cols*0.438), round(rows*0.845), rows, cols);
people(1).legsEnv = rectMask(round(cols*0.248), round(rows*0.71), ...
                             round(cols*0.432), round(rows*0.985), rows, cols);
people(1).sleeveEnv = rectMask(round(cols*0.175), round(rows*0.620), ...
                               round(cols*0.402), round(rows*0.970), rows, cols);
people(1).armEnv = rectMask(round(cols*0.175), round(rows*0.700), ...
                            round(cols*0.360), round(rows*0.972), rows, cols);

people(1).env = people(1).headEnv | people(1).headTopEnv | people(1).faceEnv | ...
                people(1).bodyEnv | people(1).shoulderEnv | people(1).legsEnv | ...
                people(1).sleeveEnv | people(1).armEnv;
people(1).seed = people(1).seed & roi;
people(1).env  = people(1).env & roi;

% CENTER
people(2).seed = false(rows, cols);

people(2).headSeed = headStackMask(cols*0.500, rows*0.555, 0.76, rows, cols);
people(2).bodySeed = ellipseMask(cols*0.500, rows*0.748, cols*0.052, rows*0.160, rows, cols);
people(2).legsSeed = rectMask(round(cols*0.455), round(rows*0.73), ...
                              round(cols*0.545), round(rows*0.97), rows, cols);

people(2).seed = people(2).headSeed | people(2).bodySeed | people(2).legsSeed;

people(2).headEnv = headStackMask(cols*0.500, rows*0.552, 1.12, rows, cols);
people(2).bodyEnv = ellipseMask(cols*0.500, rows*0.758, cols*0.078, rows*0.205, rows, cols);
people(2).legsEnv = rectMask(round(cols*0.440), round(rows*0.71), ...
                             round(cols*0.560), round(rows*0.985), rows, cols);

people(2).env = people(2).headEnv | people(2).bodyEnv | people(2).legsEnv;
people(2).seed = people(2).seed & roi;
people(2).env  = people(2).env & roi;

% RIGHT
people(3).seed = false(rows, cols);

people(3).headSeed = headStackMask(cols*0.655, rows*0.555, 0.82, rows, cols);
people(3).bodySeed = ellipseMask(cols*0.655, rows*0.745, cols*0.060, rows*0.164, rows, cols);
people(3).legsSeed = rectMask(round(cols*0.600), round(rows*0.73), ...
                              round(cols*0.713), round(rows*0.97), rows, cols);

% Expanded right exposed hand / forearm seeds
people(3).handSeed = rectMask(round(cols*0.588), round(rows*0.748), ...
                              round(cols*0.646), round(rows*0.935), rows, cols);
people(3).armSkinSeed = rectMask(round(cols*0.590), round(rows*0.640), ...
                                 round(cols*0.652), round(rows*0.928), rows, cols);

people(3).seed = people(3).headSeed | people(3).bodySeed | people(3).legsSeed | ...
                 people(3).handSeed | people(3).armSkinSeed;

people(3).headEnv = headStackMask(cols*0.655, rows*0.552, 1.18, rows, cols);
people(3).bodyEnv = ellipseMask(cols*0.655, rows*0.755, cols*0.090, rows*0.206, rows, cols);
people(3).legsEnv = rectMask(round(cols*0.588), round(rows*0.71), ...
                             round(cols*0.726), round(rows*0.985), rows, cols);

% Expanded right hand / forearm envelopes
people(3).handEnv = rectMask(round(cols*0.580), round(rows*0.730), ...
                             round(cols*0.660), round(rows*0.955), rows, cols);
people(3).armSkinEnv = rectMask(round(cols*0.582), round(rows*0.620), ...
                                round(cols*0.672), round(rows*0.948), rows, cols);

people(3).env = people(3).headEnv | people(3).bodyEnv | people(3).legsEnv | ...
                people(3).handEnv | people(3).armSkinEnv;
people(3).seed = people(3).seed & roi;
people(3).env  = people(3).env & roi;

foremask = people(1).seed | people(2).seed | people(3).seed;

backmask = false(rows, cols);
backmask(1:round(rows*0.38), :) = true;
backmask(:, 1:round(cols*0.12)) = true;
backmask(:, round(cols*0.84):end) = true;
backmask(round(rows*0.74):end, 1:round(cols*0.22)) = true;
backmask(round(rows*0.74):end, round(cols*0.76):end) = true;
backmask(round(rows*0.42):end, round(cols*0.17):round(cols*0.23)) = true;
backmask(round(rows*0.42):end, round(cols*0.74):round(cols*0.80)) = true;
backmask(foremask) = false;

%% STEP 3: Build background model
bgModels = buildLabModelsFromMask(Lch, Ach, Bch, backmask);
dBG = minLabDistance(bgModels, Lch, Ach, Bch);

%% STEP 4: Edge barrier
edgeBarrier = edge(G, 'Canny', [0.08 0.20]);
edgeBarrier = imdilate(edgeBarrier, strel('disk', 2));
edgeBarrier(foremask) = false;

%% STEP 5: Per-person mask growth
BW_all = false(rows, cols);

for i = 1:3
    seed_i = people(i).seed;
    env_i = people(i).env;

    fgModels = buildLabModelsFromMask(Lch, Ach, Bch, seed_i);
    dFG = minLabDistance(fgModels, Lch, Ach, Bch);

    candidate1 = (dFG < 4.8) & (dFG + 0.28 < dBG) & env_i;
    candidate1(edgeBarrier) = 0;

    BW_i = imreconstruct(seed_i, candidate1 | seed_i);

    grow_i = imdilate(BW_i, strel('disk', 26)) & env_i;
    candidate2 = (dFG < 5.7) & (dFG + 0.10 < dBG) & grow_i;
    candidate2(edgeBarrier) = 0;

    BW_i = imreconstruct(BW_i, candidate2 | BW_i);

    if i == 1
        shoulderGrow = (people(i).shoulderEnv | people(i).sleeveEnv | people(i).armEnv) & ...
                       (dFG < 6.35) & (dFG + 0.02 < dBG);
        shoulderGrow(edgeBarrier) = 0;
        BW_i = imreconstruct(BW_i, shoulderGrow | BW_i);

        headGrow = (people(i).headEnv | people(i).headTopEnv | people(i).faceEnv) & ...
                   (((dFG < 6.10) & (dFG + 0.01 < dBG)) | skinLike);
        headGrow(edgeBarrier) = 0;
        BW_i = imreconstruct(BW_i, headGrow | BW_i);
    end

    if i == 3
        % Stronger right-hand / forearm recovery
        handGrow = (people(i).handEnv | people(i).armSkinEnv) & ...
                   (((dFG < 6.20) & (dFG + 0.02 < dBG)) | skinLike) & ...
                   imdilate(BW_i | people(i).handSeed | people(i).armSkinSeed, strel('disk', 14));
        handGrow(edgeBarrier) = 0;
        BW_i = imreconstruct(BW_i | people(i).handSeed | people(i).armSkinSeed, handGrow | BW_i);

        % Local reinforcement so the exposed arm/hand is not lost
        handPatch = BW_i & people(i).armSkinEnv;
        handPatch = imfill(handPatch, 'holes');
        handPatch = imclose(handPatch, strel('disk', 3));
        handPatch = imdilate(handPatch, strel('disk', 2));
        BW_i = BW_i | (handPatch & people(i).armSkinEnv);
    end

    BW_i = BW_i & env_i;
    BW_i = imfill(BW_i, 'holes');
    BW_i = imclose(BW_i, strel('disk', 8));
    BW_i = imopen(BW_i, strel('disk', 2));
    BW_i = bwareaopen(BW_i, 1200);
    BW_i = keepSeedComponents(BW_i, seed_i);

    if i == 1
        headZone = people(i).headEnv | people(i).headTopEnv | people(i).faceEnv;
    else
        headZone = people(i).headEnv;
    end

    headPart = BW_i & headZone;
    headPart = imfill(headPart, 'holes');
    headPart = imclose(headPart, strel('disk', 5));
    headPart = imopen(headPart, strel('disk', 1));

    BW_i = (BW_i & ~headZone) | headPart;

    BW_all = BW_all | BW_i;
end

%% STEP 6: Final group cleanup
BW = BW_all & roi;
BW = imfill(BW, 'holes');
BW = imclose(BW, strel('disk', 6));
BW = imopen(BW, strel('disk', 1));
BW = bwareaopen(BW, 4000);
BW = keepSeedComponents(BW, foremask);

BW = imdilate(BW, strel('disk', 2));
BW = BW & roi;
BW = imfill(BW, 'holes');

%% STEP 7: Feather mask
featherMask = imgaussfilt(double(BW), 3.2);

%% STEP 8: Blur background
blurredBG = zeros(size(I_double));
for c = 1:3
    blurredBG(:,:,c) = imgaussfilt(I_double(:,:,c), 18);
end

%% STEP 9: Composite
I_portrait = zeros(size(I_double));
for c = 1:3
    I_portrait(:,:,c) = featherMask .* I_double(:,:,c) + ...
                        (1 - featherMask) .* blurredBG(:,:,c);
end

%% STEP 10: Preview
maskRGB = repmat(BW, [1 1 3]);

I_detected = I;
I_detected(~maskRGB) = 0;

BW_uint8 = uint8(BW) * 255;
I_portrait_uint8 = im2uint8(I_portrait);

figure('Name', 'Group Portrait Blur', 'NumberTitle', 'off');

subplot(2,3,1);
imshow(I);
title('Original');

subplot(2,3,2);
imshow(foremask);
title('Foreground Seeds');

subplot(2,3,3);
imshow(BW);
title('Final People Mask');

subplot(2,3,4);
imshow(I_detected);
title('Detected People Only');

subplot(2,3,5);
imshow(blurredBG);
title('Blurred Background');

subplot(2,3,6);
imshow(I_portrait_uint8);
title('Portrait Blur Output');

%% STEP 11: Save outputs
imwrite(I_detected, 'group_detected_people.jpg');
imwrite(BW_uint8, 'group_people_mask.jpg');
imwrite(I_portrait_uint8, 'group_portrait_blur.jpg');

fprintf('==============================================\n');
fprintf('         PROJECT IN IMAGE PROCESSING\n');
fprintf('==============================================\n');
fprintf(' Process    : Per-person seed-driven color scan + edge blur\n');
fprintf(' Output     : Completed successfully\n');
fprintf('==============================================\n');

function models = buildLabModelsFromMask(Lch, Ach, Bch, mask)
    valsL = Lch(mask);

    if isempty(valsL)
        error('Seed mask is empty.');
    end

    if numel(valsL) > 30 && numel(unique(round(valsL))) > 10
        th = multithresh(valsL, 2);
    else
        th = prctile(valsL, [33 66]);
    end

    band1 = mask & (Lch <= th(1));
    band2 = mask & (Lch > th(1)) & (Lch <= th(2));
    band3 = mask & (Lch > th(2));

    bands = {band1, band2, band3};

    mu = [];
    sg = [];

    for i = 1:3
        b = bands{i};
        if nnz(b) < 40
            continue;
        end

        mu_i = [mean(Lch(b)), mean(Ach(b)), mean(Bch(b))];
        sg_i = [std(Lch(b))+1e-6, std(Ach(b))+1e-6, std(Bch(b))+1e-6];

        mu = [mu; mu_i]; 
        sg = [sg; sg_i]; 
    end

    if isempty(mu)
        mu = [mean(Lch(mask)), mean(Ach(mask)), mean(Bch(mask))];
        sg = [std(Lch(mask))+1e-6, std(Ach(mask))+1e-6, std(Bch(mask))+1e-6];
    end

    models.mu = mu;
    models.sg = sg;
end

function dMin = minLabDistance(models, Lch, Ach, Bch)
    dMin = inf(size(Lch));

    for i = 1:size(models.mu, 1)
        mu = models.mu(i, :);
        sg = models.sg(i, :);

        D = sqrt( ...
            ((Lch - mu(1))./sg(1)).^2 + ...
            ((Ach - mu(2))./sg(2)).^2 + ...
            ((Bch - mu(3))./sg(3)).^2 );

        dMin = min(dMin, D);
    end
end

function BW = keepSeedComponents(BW, seedMask)
    CC = bwconncomp(BW);
    out = false(size(BW));

    for k = 1:CC.NumObjects
        pix = CC.PixelIdxList{k};
        if any(seedMask(pix))
            out(pix) = true;
        end
    end

    BW = out;
end

function BW = ellipseMask(cx, cy, rx, ry, rows, cols)
    [X, Y] = meshgrid(1:cols, 1:rows);
    BW = ((X - cx).^2 ./ (rx.^2 + eps) + (Y - cy).^2 ./ (ry.^2 + eps)) <= 1;
end

function BW = rectMask(x1, y1, x2, y2, rows, cols)
    BW = false(rows, cols);
    x1 = max(1, min(cols, x1));
    x2 = max(1, min(cols, x2));
    y1 = max(1, min(rows, y1));
    y2 = max(1, min(rows, y2));

    if x1 <= x2 && y1 <= y2
        BW(y1:y2, x1:x2) = true;
    end
end

function BW = headStackMask(cx, cy, scale, rows, cols)
    top = ellipseMask(cx, cy - rows*0.020, cols*0.019*scale, rows*0.030*scale, rows, cols);
    mid = ellipseMask(cx, cy + rows*0.004, cols*0.026*scale, rows*0.037*scale, rows, cols);
    low = ellipseMask(cx, cy + rows*0.030, cols*0.031*scale, rows*0.032*scale, rows, cols);

    BW = top | mid | low;
    BW = imclose(BW, strel('disk', 3));
    BW = imfill(BW, 'holes');
end