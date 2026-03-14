%% TASK 1 - IMAGE 2
% Make only the 3 people in front golden
% File: task1_img2.m

clc;
clear;
close all;

%% Load image
I = imread('MakeUsGolden.jpg');
[rows, cols, ~] = size(I);
I_double = im2double(I);

%% STEP 1: Build superpixels for GrabCut
% grabcut needs a label matrix L
L = superpixels(I, 1200);

%% STEP 2: ROI covering the 3 people
% Everything outside this ROI is treated as background
roi = false(rows, cols);
roi(round(rows*0.20):round(rows*0.99), ...
    round(cols*0.01):round(cols*0.99)) = true;

%% STEP 3: Sure foreground mask
% Smaller boxes inside each person so the algorithm knows
% these regions definitely belong to the subjects

foremask = false(rows, cols);

% LEFT person - inner torso + face/head
foremask(round(rows*0.49):round(rows*0.86), ...
         round(cols*0.05):round(cols*0.22)) = true;
foremask(round(rows*0.41):round(rows*0.57), ...
         round(cols*0.06):round(cols*0.19)) = true;

% CENTER person - inner torso + face/head
foremask(round(rows*0.50):round(rows*0.91), ...
         round(cols*0.31):round(cols*0.50)) = true;
foremask(round(rows*0.35):round(rows*0.56), ...
         round(cols*0.30):round(cols*0.48)) = true;

% RIGHT person - inner torso + face/head
foremask(round(rows*0.49):round(rows*0.85), ...
         round(cols*0.68):round(cols*0.82)) = true;
foremask(round(rows*0.39):round(rows*0.56), ...
         round(cols*0.67):round(cols*0.82)) = true;

%% STEP 4: Sure background mask
% Mark obvious background so the result does not spread too much

backmask = false(rows, cols);

% Top band: sky/building/trees
backmask(1:round(rows*0.22), :) = true;

% Very thin left/right borders
backmask(:, 1:round(cols*0.01)) = true;
backmask(:, round(cols*0.99):end) = true;

% Upper-right tree/building edge
backmask(round(rows*0.18):round(rows*0.45), ...
         round(cols*0.88):cols) = true;

% Keep foreground seeds from being overwritten
backmask(foremask) = false;

%% STEP 5: GrabCut segmentation
BW = grabcut(I, L, roi, foremask, backmask, 'MaximumIterations', 5);

%% STEP 6: Cleanup
BW = imfill(BW, 'holes');
BW = bwareaopen(BW, 2500);
BW = imclose(BW, strel('disk', 11));
BW = imopen(BW, strel('disk', 3));

%% STEP 7: Keep only components that overlap the foreground seeds
cc = bwconncomp(BW);
finalMask = false(size(BW));

for k = 1:cc.NumObjects
    pix = cc.PixelIdxList{k};
    if any(foremask(pix))
        finalMask(pix) = true;
    end
end

%% STEP 8: Final face/hair-friendly refinement
finalMask = imfill(finalMask, 'holes');
finalMask = imclose(finalMask, strel('disk', 9));   % closes hair gaps
finalMask = imdilate(finalMask, strel('disk', 2));  % recovers edges
finalMask = imfill(finalMask, 'holes');

%% STEP 9: Feather for smoother color blending
featherMask = imgaussfilt(double(finalMask), 8);

%% STEP 10: Preview detected people only
maskRGB = repmat(finalMask, [1 1 3]);
I_detected = I;
I_detected(~maskRGB) = 0;

%% STEP 11: Golden recolor only on the masked people
I_gold = I_double;

goldR = min(I_double(:,:,1) + 0.28, 1);
goldG = min(I_double(:,:,2) + 0.18, 1);
goldB = max(I_double(:,:,3) - 0.10, 0);

I_gold(:,:,1) = (1 - featherMask).*I_double(:,:,1) + featherMask.*goldR;
I_gold(:,:,2) = (1 - featherMask).*I_double(:,:,2) + featherMask.*goldG;
I_gold(:,:,3) = (1 - featherMask).*I_double(:,:,3) + featherMask.*goldB;

I_gold_uint8 = im2uint8(I_gold);
mask_uint8 = uint8(finalMask) * 255;
seedPreview = uint8(foremask | backmask) * 255;

%% STEP 12: Show results
figure('Name', 'TASK 1 - IMAGE 2', 'NumberTitle', 'off');

subplot(2,3,1);
imshow(I);
title('Original');

subplot(2,3,2);
imshow(foremask);
title('Foreground Seeds');

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

%% STEP 13: Save outputs
imwrite(I_detected, 'task1_img2_detected_people.jpg');
imwrite(mask_uint8, 'task1_img2_mask.jpg');
imwrite(I_gold_uint8, 'task1_img2_golden_people.jpg');

%% Console output
fprintf('==============================================\\n');
fprintf('         PROJECT IN IMAGE PROCESSING\\n');
fprintf('==============================================\\n');
fprintf(' Task       : Task 1 - Image 2\\n');
fprintf(' Process    : GrabCut People Segmentation + Golden Recolor\\n');
fprintf(' Output     : Completed successfully\\n');
fprintf('==============================================\\n');
fprintf(' Applied Processing:\\n');
fprintf(' - Superpixel-based GrabCut segmentation\\n');
fprintf(' - Foreground and background seeding\\n');
fprintf(' - Morphological cleanup\\n');
fprintf(' - Face/hair-friendly mask refinement\\n');
fprintf(' - Feathered golden recoloring\\n');
fprintf('==============================================\\n');