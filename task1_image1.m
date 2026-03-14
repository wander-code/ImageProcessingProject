%% TASK 1 - IMAGE 1
% Color the gray cat orange
% File: task1_img1_color_cat.m

clc;
clear;
close all;

%% Load image
I = imread('IMG_8274.jpg');
I_double = im2double(I);

% Extract RGB channels
R = I_double(:,:,1);
G = I_double(:,:,2);
B = I_double(:,:,3);

%% STEP 1: Initial gray-cat detection
% Detect gray-ish pixels
grayMask = abs(R - G) < 0.05 & ...
           abs(R - B) < 0.35 & ...
           abs(G - B) < 0.25;

% Brightness filter
% Removes very dark pixels and weak detections
brightnessMask = R > 0.06 & G > 0.12 & B > 0.04;

% Reject some floor/background regions
% Keeps areas where red is not too dominant over blue
floorRejectMask = (R - B) < 0.35;

% Initial mask
Mask = grayMask & brightnessMask & floorRejectMask;

%% STEP 2: Clean up mask
% Remove tiny noisy regions
Mask = bwareaopen(Mask, 800);

% Keep largest connected object
Mask = bwareafilt(Mask, 1);

%% STEP 3: Morphological refinement
se = strel('disk', 15);
Mask = imclose(Mask, se);   % close small gaps
Mask = imopen(Mask, se);    % smooth edges

%% STEP 4: Active contour refinement
I_gray = rgb2gray(I);
Mask_refined = activecontour(I_gray, Mask, 80, 'edge');

%% STEP 5: Feather mask for smooth blending
featherMask = imgaussfilt(double(Mask_refined), 12);

%% STEP 6: Preview detected region
MaskArray = repmat(Mask_refined, [1 1 3]);
I_detected = I;
I_detected(MaskArray) = 0;

%% STEP 7: Recolor cat to orange
I_orange = I_double;

% Adjust channels only inside feathered mask
I_orange(:,:,1) = min(I_orange(:,:,1) + 0.35 .* featherMask, 1); % increase red
I_orange(:,:,2) = min(I_orange(:,:,2) + 0.12 .* featherMask, 1); % slight green
I_orange(:,:,3) = max(I_orange(:,:,3) - 0.20 .* featherMask, 0); % reduce blue

%% STEP 8: Optional enhanced original for comparison
I_before = I_double;

%% STEP 9: Convert final output
I_orange_uint8 = im2uint8(I_orange);
I_before_uint8 = im2uint8(I_before);
Mask_uint8 = uint8(Mask_refined) * 255;

%% STEP 10: Display results
figure('NumberTitle', 'off', 'Name', 'CS0057_FINALPROJECT_TASK1_IMAGE1');

subplot(2,3,1);
imshow(I);
title('Original');

subplot(2,3,2);
imshow(Mask);
title('Initial Mask');

subplot(2,3,3);
imshow(Mask_refined);
title('Refined Mask');

subplot(2,3,4);
imshow(I_detected);
title('Detected Cat Region');

subplot(2,3,5);
imshow(I_before_uint8);
title('Original (Reference)');

subplot(2,3,6);
imshow(I_orange_uint8);
title('Final Orange Cat');

%% STEP 11: Save outputs
imwrite(I_detected, 'task1_img1_detected_region.jpg');
imwrite(Mask_uint8, 'task1_img1_refined_mask.jpg');
imwrite(I_before_uint8, 'task1_img1_original_reference.jpg');
imwrite(I_orange_uint8, 'task1_img1_final_orange_cat.jpg');

%% Console output
fprintf('==============================================\n');
fprintf('         PROJECT IN IMAGE PROCESSING\n');
fprintf('==============================================\n');
fprintf(' Task       : Task 1 - Image 1\n');
fprintf(' Process    : Gray Cat to Orange Cat\n');
fprintf(' Output     : Completed successfully\n');
fprintf('==============================================\n');
fprintf(' Applied Improvements:\n');
fprintf(' - Initial gray pixel detection\n');
fprintf(' - Noise removal\n');
fprintf(' - Morphological refinement\n');
fprintf(' - Active contour edge refinement\n');
fprintf(' - Feathered mask blending\n');
fprintf(' - Natural orange recoloring\n');
fprintf('==============================================\n');