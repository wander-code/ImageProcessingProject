%% CS0057 - Image Processing Project Pipeline
% This script processes input images for 3 required tasks:
% 1) Color the Cat        -> turn a gray cat orange
% 2) Segment Landscape    -> classify sky / vegetation / man-made areas
% 3) Blur the Background  -> keep cat sharp, blur surroundings
%
% Configure input files in the sections below. The script is set up for
% two images per task, but you can add more file names if needed.

clc; clear; close all;

% Use script folder as stable base path (works even if Current Folder differs).
scriptDir = getScriptDir();

%% ---------------------- USER CONFIGURATION ---------------------------- %%
catColorInputs = { ...
    'IMG_8274.jpg', ...
    'MakeUsGolden.jpg' ...
};

landscapeInputs = { ...
    'IMG_8870.jpg', ...
    'SegmentUs.jpg' ...
};

blurInputs = { ...
    'IMG_8236.jpg', ...
    'BlurUs.jpg' ...
};

outputDir = fullfile(scriptDir, 'outputs');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
%% --------------------------------------------------------------------- %%

fprintf('==============================================\n');
fprintf('     IMAGE PROCESSING PROJECT PIPELINE\n');
fprintf('==============================================\n\n');

%% 1) COLOR THE CAT (2 images)
for i = 1:numel(catColorInputs)
    inFile = catColorInputs{i};
    inPath = resolveInputPath(inFile, scriptDir);
    if isempty(inPath)
        warning('Skipped (file not found): %s', inFile);
        continue;
    end

    I = imread(inPath);
    Iout = colorCatOrange(I);

    [~, name, ~] = fileparts(inFile);
    outFile = fullfile(outputDir, sprintf('%s_COLOR_OUTPUT.jpg', name));
    safeImwrite(Iout, outFile);

    figure('Name', sprintf('Task 1 - Color Subject #%d', i), 'NumberTitle', 'off');
    subplot(1,2,1); imshow(I);    title(sprintf('Input: %s', inFile), 'Interpreter', 'none');
    subplot(1,2,2); imshow(Iout); title(sprintf('Output: %s', outFile), 'Interpreter', 'none');

    fprintf('[DONE] Color Cat: %s -> %s\n', inFile, outFile);
end

%% 2) SEGMENT LANDSCAPE (2 images)
for i = 1:numel(landscapeInputs)
    inFile = landscapeInputs{i};
    inPath = resolveInputPath(inFile, scriptDir);
    if isempty(inPath)
        warning('Skipped (file not found): %s', inFile);
        continue;
    end

    I = imread(inPath);
    [segRGB, masks] = segmentLandscape(I);

    [~, name, ~] = fileparts(inFile);
    outFile = fullfile(outputDir, sprintf('%s_SEGMENT_OUTPUT.jpg', name));
    safeImwrite(segRGB, outFile);

    figure('Name', sprintf('Task 2 - Landscape Segmentation #%d', i), 'NumberTitle', 'off');
    subplot(2,3,1); imshow(I); title(sprintf('Input: %s', inFile), 'Interpreter', 'none');
    subplot(2,3,2); imshow(masks.sky); title('Sky Mask');
    subplot(2,3,3); imshow(masks.vegetation); title('Vegetation Mask');
    subplot(2,3,4); imshow(masks.manmade); title('Man-made Mask');
    subplot(2,3,[5 6]); imshow(segRGB); title(sprintf('Output: %s', outFile), 'Interpreter', 'none');

    fprintf('[DONE] Segment Landscape: %s -> %s\n', inFile, outFile);
end

%% 3) BLUR THE BACKGROUND (2 images)
for i = 1:numel(blurInputs)
    inFile = blurInputs{i};
    inPath = resolveInputPath(inFile, scriptDir);
    if isempty(inPath)
        warning('Skipped (file not found): %s', inFile);
        continue;
    end

    I = imread(inPath);
    Iout = blurBackgroundKeepCat(I);

    [~, name, ~] = fileparts(inFile);
    outFile = fullfile(outputDir, sprintf('%s_BLUR_OUTPUT.jpg', name));
    safeImwrite(Iout, outFile);

    figure('Name', sprintf('Task 3 - Background Blur #%d', i), 'NumberTitle', 'off');
    subplot(1,2,1); imshow(I);    title(sprintf('Input: %s', inFile), 'Interpreter', 'none');
    subplot(1,2,2); imshow(Iout); title(sprintf('Output: %s', outFile), 'Interpreter', 'none');

    fprintf('[DONE] Blur Background: %s -> %s\n', inFile, outFile);
end

fprintf('\nAll available tasks finished. Check output folder:\n%s\n', outputDir);

%% =========================== FUNCTIONS =============================== %%
function scriptDir = getScriptDir()
% Return folder containing this script.

scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    % Fallback for Live Editor/section execution contexts.
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptPath);
end
end

function fullPath = resolveInputPath(inFile, scriptDir)
% Resolve input by checking absolute path, current folder, then script folder.

if isfile(inFile)
    fullPath = inFile;
    return;
end

candidate = fullfile(scriptDir, inFile);
if isfile(candidate)
    fullPath = candidate;
    return;
end

fullPath = '';
end

function Iout = colorCatOrange(I)
% Apply a golden/orange tone to the primary foreground subject.
% This works for the cat samples and the renamed MakeUsGolden.jpg input.

I = im2uint8(I);
subjectMask = getPrimarySubjectMask(I);

% Fallback: if subject detection fails, use neutral gray detector.
if nnz(subjectMask) < 0.01 * numel(subjectMask)
    G = rgb2gray(I);
    subjectMask = abs(double(I(:,:,1)) - double(I(:,:,2))) < 24 & ...
                  abs(double(I(:,:,1)) - double(I(:,:,3))) < 30 & ...
                  abs(double(I(:,:,2)) - double(I(:,:,3))) < 30 & ...
                  G > 35 & G < 240;
    subjectMask = bwareaopen(subjectMask, 500);
    if nnz(subjectMask) > 0
        subjectMask = bwareafilt(subjectMask, 1);
    end
end

subjectMask = imclose(subjectMask, strel('disk', 7));
subjectMask = imfill(subjectMask, 'holes');
alpha = imgaussfilt(double(subjectMask), 6);
alpha = max(0, min(alpha, 1));

Id = im2double(I);
J = Id;

% Golden grade with stronger red/green and controlled blue reduction.
J(:,:,1) = min(1, Id(:,:,1) * 1.28 + 0.18 * alpha);
J(:,:,2) = min(1, Id(:,:,2) * 1.12 + 0.08 * alpha);
J(:,:,3) = max(0, Id(:,:,3) * 0.70 - 0.03 * alpha);

for c = 1:3
    Id(:,:,c) = (1 - alpha) .* Id(:,:,c) + alpha .* J(:,:,c);
end

Iout = im2uint8(Id);
end

function safeImwrite(I, outFile)
% Ensure output folder exists before saving.

[parentDir, ~, ~] = fileparts(outFile);
if ~isempty(parentDir) && ~exist(parentDir, 'dir')
    [ok, msg, msgID] = mkdir(parentDir);
    if ~ok
        error('safeImwrite:mkdirFailed', ...
              'Failed to create output folder: %s (%s: %s)', ...
              parentDir, msgID, msg);
    end
end
imwrite(I, outFile);
end

function [segRGB, masks] = segmentLandscape(I)
% Segment landscape into sky (blue), vegetation (green), man-made (red).

I = im2uint8(I);
[h, w, ~] = size(I);
Id = im2double(I);
HSV = rgb2hsv(I);
H = HSV(:,:,1); S = HSV(:,:,2); V = HSV(:,:,3);

% Sky detection: blue/cyan or bright low-saturation clouds in upper area.
upper = false(h, w);
upper(1:round(0.68*h), :) = true;
sky = (((H > 0.52 & H < 0.74) & S < 0.55 & V > 0.35) | ...
       (V > 0.72 & S < 0.23)) & upper;
sky = imclose(sky, strel('disk', 6));
sky = imopen(sky, strel('disk', 3));
sky = imfill(sky, 'holes');
if nnz(sky) > 0
    sky = bwareafilt(sky, 1);
end

% Vegetation from excess green index, excluding sky.
R = Id(:,:,1); G = Id(:,:,2); B = Id(:,:,3);
excessGreen = 2*G - R - B;
vegSeed = excessGreen > 0.06 & G > 0.22 & S > 0.15 & ~sky;
vegSeed = imopen(vegSeed, strel('disk', 2));
vegSeed = imclose(vegSeed, strel('disk', 5));
vegSeed = bwareaopen(vegSeed, 120);

% Grow vegetation over textured green neighborhoods.
localGreen = imgaussfilt(double(vegSeed), 4) > 0.05;
vegetation = (vegSeed | (localGreen & G > R & G > B)) & ~sky;
vegetation = imopen(vegetation, strel('disk', 2));
vegetation = imclose(vegetation, strel('disk', 4));
vegetation = bwareaopen(vegetation, 120);

manmade = ~(sky | vegetation);
manmade = imopen(manmade, strel('disk', 1));
manmade = bwareaopen(manmade, 60);

segRGB = zeros(size(I), 'uint8');
segRGB(:,:,1) = uint8(manmade) * 255;
segRGB(:,:,2) = uint8(vegetation) * 255;
segRGB(:,:,3) = uint8(sky) * 255;

masks.sky = sky;
masks.vegetation = vegetation;
masks.manmade = manmade;
end

function Iout = blurBackgroundKeepCat(I)
% Keep the central foreground subject in focus and blur the background.

I = im2uint8(I);
subjectMask = getPrimarySubjectMask(I);
subjectMask = imclose(subjectMask, strel('disk', 8));
subjectMask = imfill(subjectMask, 'holes');
subjectMask = bwareaopen(subjectMask, 1500);
if nnz(subjectMask) > 0
    subjectMask = bwareafilt(subjectMask, 1);
end

alpha = imgaussfilt(double(subjectMask), 9);
alpha = max(0, min(alpha, 1));
alpha3 = repmat(alpha, [1 1 3]);

Id = im2double(I);
% Stronger blur to match requested portrait effect.
bg = imgaussfilt(Id, 9);
bg = im2double(imbilatfilt(im2uint8(bg), 18, 40));

J = alpha3 .* Id + (1 - alpha3) .* bg;
sharp = imsharpen(J, 'Radius', 1.4, 'Amount', 1.0);
J = alpha3 .* sharp + (1 - alpha3) .* J;

Iout = im2uint8(J);
end

function mask = getPrimarySubjectMask(I)
% Estimate main foreground subject using center prior + active contour.

[h, w, ~] = size(I);
G = im2double(rgb2gray(I));

% Center-lower prior works for cat and portrait-like images.
seed = false(h, w);
seed(round(0.24*h):round(0.95*h), round(0.20*w):round(0.80*w)) = true;

% Improve edge contrast before contour evolution.
Gf = imgaussfilt(G, 1.2);
try
    mask = activecontour(Gf, seed, 140, 'edge');
catch
    % Fallback if activecontour is unavailable.
    BW = imbinarize(adapthisteq(Gf), 'adaptive', 'Sensitivity', 0.50);
    BW = imclose(BW, strel('disk', 6));
    mask = BW & seed;
end

mask = imclose(mask, strel('disk', 5));
mask = imfill(mask, 'holes');
mask = bwareaopen(mask, round(0.002 * h * w));

% Keep component nearest image center.
cc = bwconncomp(mask);
if cc.NumObjects > 1
    stats = regionprops(cc, 'Centroid', 'Area');
    cxy = [w/2, h*0.62];
    score = inf(cc.NumObjects, 1);
    for k = 1:cc.NumObjects
        d = norm(stats(k).Centroid - cxy);
        score(k) = d - 0.0008 * stats(k).Area;
    end
    [~, idx] = min(score);
    keep = false(h, w);
    keep(cc.PixelIdxList{idx}) = true;
    mask = keep;
elseif cc.NumObjects == 0
    mask = seed;
end
end

