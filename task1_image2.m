%% TASK 1 - IMAGE 2
% Segment only the 3 people, then make them golden
% File: task1_img2.m

clc;
clear;
close all;

%% Load image
I = imread('MakeUsGolden.jpg');
I_double = im2double(I);
[rows, cols, ~] = size(I);

%% STEP 1: Polygon masks for each person
% These are normalized coordinates based on this image,
% so they scale correctly if the image size changes.

leftPts = [ ...
    0.1367 0.9993
    0.1392 0.8203
    0.1465 0.7031
    0.1562 0.5859
    0.1660 0.4948
    0.1855 0.4036
    0.2246 0.3516
    0.2734 0.3255
    0.3320 0.3385
    0.3711 0.4036
    0.4004 0.5339
    0.4199 0.6771
    0.4395 0.8594
    0.4541 0.9993
];

centerPts = [ ...
    0.2734 0.9993
    0.2832 0.8854
    0.3027 0.7552
    0.3320 0.6185
    0.3711 0.4688
    0.4199 0.3906
    0.4688 0.3516
    0.5273 0.3385
    0.5957 0.3516
    0.6445 0.3906
    0.6836 0.4688
    0.7129 0.5990
    0.7373 0.7552
    0.7568 0.8854
    0.7715 0.9993
];

rightPts = [ ...
    0.6543 0.9993
    0.6641 0.8464
    0.6836 0.7161
    0.7031 0.5599
    0.7227 0.4427
    0.7617 0.3776
    0.8105 0.3646
    0.8594 0.3776
    0.8984 0.4297
    0.9277 0.5339
    0.9570 0.7031
    0.9814 0.8594
    0.9912 0.9993
];

% Convert normalized points to pixel coordinates
leftX   = round(leftPts(:,1)   * cols);
leftY   = round(leftPts(:,2)   * rows);
centerX = round(centerPts(:,1) * cols);
centerY = round(centerPts(:,2) * rows);
rightX  = round(rightPts(:,1)  * cols);
rightY  = round(rightPts(:,2)  * rows);

% Create masks
maskLeft   = poly2mask(leftX, leftY, rows, cols);
maskCenter = poly2mask(centerX, centerY, rows, cols);
maskRight  = poly2mask(rightX, rightY, rows, cols);

%% STEP 2: Combine masks
finalMask = maskLeft | maskCenter | maskRight;

%% STEP 3: Smooth and refine mask
finalMask = imclose(finalMask, strel('disk', 18));
finalMask = imfill(finalMask, 'holes');
finalMask = imopen(finalMask, strel('disk', 4));

% Slight dilation so edges of hair / shoulders are not cut
finalMask = imdilate(finalMask, strel('disk', 3));

%% STEP 4: Feather mask for smoother blending
featherMask = imgaussfilt(double(finalMask), 8);

%% STEP 5: Detected people only preview
maskRGB = repmat(finalMask, [1 1 3]);
I_detected = I;
I_detected(~maskRGB) = 0;

%% STEP 6: Make only the people golden
I_gold = I_double;

goldR = min(I_double(:,:,1) + 0.28, 1);
goldG = min(I_double(:,:,2) + 0.18, 1);
goldB = max(I_double(:,:,3) - 0.10, 0);

I_gold(:,:,1) = (1 - featherMask).*I_double(:,:,1) + featherMask.*goldR;
I_gold(:,:,2) = (1 - featherMask).*I_double(:,:,2) + featherMask.*goldG;
I_gold(:,:,3) = (1 - featherMask).*I_double(:,:,3) + featherMask.*goldB;

%% STEP 7: Convert outputs
mask_uint8 = uint8(finalMask) * 255;
I_gold_uint8 = im2uint8(I_gold);

%% STEP 8: Show results
figure('Name', 'TASK 1 - IMAGE 2', 'NumberTitle', 'off');

subplot(2,3,1);
imshow(I);
title('Original');

subplot(2,3,2);
imshow(maskLeft | maskCenter | maskRight);
title('Person Masks');

subplot(2,3,3);
imshow(finalMask);
title('Final People Mask');

subplot(2,3,4);
imshow(I_detected);
title('Detected People Only');

subplot(2,3,5);
imshow(mask_uint8);
title('Binary Mask');

subplot(2,3,6);
imshow(I_gold_uint8);
title('Golden People Only');

%% STEP 9: Save outputs
imwrite(I_detected, 'task1_img2_detected_people.jpg');
imwrite(mask_uint8, 'task1_img2_mask.jpg');
imwrite(I_gold_uint8, 'task1_img2_golden_people.jpg');

%% Console output
fprintf('==============================================\n');
fprintf('         PROJECT IN IMAGE PROCESSING\n');
fprintf('==============================================\n');
fprintf(' Task       : Task 1 - Image 2\n');
fprintf(' Process    : Polygon-based people segmentation + golden recolor\n');
fprintf(' Output     : Completed successfully\n');
fprintf('==============================================\n');
fprintf(' Applied Processing:\n');
fprintf(' - 3 person polygon masks\n');
fprintf(' - Mask smoothing and filling\n');
fprintf(' - Edge feathering\n');
fprintf(' - Golden recoloring of people only\n');
fprintf('==============================================\n');