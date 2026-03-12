%% CS0057 - Image Processing Project Pipeline
% This script processes input images for 3 required tasks:
% 1) Color the Cat        -> turn a gray cat orange
% 2) Segment Landscape    -> classify sky / vegetation / man-made areas
% 3) Blur the Background  -> keep cat sharp, blur surroundings
%
% Configure input files in the sections below. The script is set up for
% two images per task, but you can add more file names if needed.

clc; clear; close all;

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

outputDir = 'outputs';
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
    if ~isfile(inFile)
        warning('Skipped (file not found): %s', inFile);
        continue;
    end

    I = imread(inFile);
    Iout = colorCatOrange(I);

    [~, name, ~] = fileparts(inFile);
    outFile = fullfile(outputDir, sprintf('%s_COLOR_OUTPUT.jpg', name));
    safeImwrite(Iout, outFile);

    figure('Name', sprintf('Color Cat #%d', i), 'NumberTitle', 'off');
    subplot(1,2,1); imshow(I);    title(sprintf('Input: %s', inFile), 'Interpreter', 'none');
    subplot(1,2,2); imshow(Iout); title(sprintf('Output: %s', outFile), 'Interpreter', 'none');

    fprintf('[DONE] Color Cat: %s -> %s\n', inFile, outFile);
end

%% 2) SEGMENT LANDSCAPE (2 images)
for i = 1:numel(landscapeInputs)
    inFile = landscapeInputs{i};
    if ~isfile(inFile)
        warning('Skipped (file not found): %s', inFile);
        continue;
    end

    I = imread(inFile);
    [segRGB, masks] = segmentLandscape(I);

    [~, name, ~] = fileparts(inFile);
    outFile = fullfile(outputDir, sprintf('%s_SEGMENT_OUTPUT.jpg', name));
    safeImwrite(segRGB, outFile);

    figure('Name', sprintf('Landscape Segment #%d', i), 'NumberTitle', 'off');
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
    if ~isfile(inFile)
        warning('Skipped (file not found): %s', inFile);
        continue;
    end

    I = imread(inFile);
    Iout = blurBackgroundKeepCat(I);

    [~, name, ~] = fileparts(inFile);
    outFile = fullfile(outputDir, sprintf('%s_BLUR_OUTPUT.jpg', name));
    safeImwrite(Iout, outFile);

    figure('Name', sprintf('Blur Background #%d', i), 'NumberTitle', 'off');
    subplot(1,2,1); imshow(I);    title(sprintf('Input: %s', inFile), 'Interpreter', 'none');
    subplot(1,2,2); imshow(Iout); title(sprintf('Output: %s', outFile), 'Interpreter', 'none');

    fprintf('[DONE] Blur Background: %s -> %s\n', inFile, outFile);
end

fprintf('\nAll available tasks finished. Check "%s" folder.\n', outputDir);

%% =========================== FUNCTIONS =============================== %%
function Iout = colorCatOrange(I)
% Detect mostly gray cat pixels then recolor with orange tone.

I = im2uint8(I);
R = I(:,:,1); G = I(:,:,2); B = I(:,:,3);

% Grayness detector + brightness constraints
grayLike = abs(int16(R)-int16(G)) < 18 & ...
           abs(int16(R)-int16(B)) < 28 & ...
           abs(int16(G)-int16(B)) < 28;

brightness = rgb2gray(I) > 40 & rgb2gray(I) < 230;

% Reject highly saturated wood/floor colors (usually red-dominant)
notFloor = (int16(R) - int16(B)) < 40;

mask0 = grayLike & brightness & notFloor;

% Keep coherent object, clean noise, fill holes
mask = bwareaopen(mask0, 600);
mask = imclose(mask, strel('disk', 8));
mask = imfill(mask, 'holes');
mask = bwareafilt(mask, 1);

% Refine edge with active contour when possible
try
    mask = activecontour(rgb2gray(I), mask, 50, 'edge');
catch
    % If activecontour unavailable in some MATLAB versions/toolboxes,
    % continue with morphology-only mask.
end

% Feather edge for natural blend
alpha = imgaussfilt(double(mask), 8);
alpha = max(0, min(alpha, 1));

Id = im2double(I);
J = Id;

% Orange grading: boost red, slight green, reduce blue
J(:,:,1) = min(1, Id(:,:,1) * 1.35 + 0.16 * alpha);
J(:,:,2) = min(1, Id(:,:,2) * 1.10 + 0.08 * alpha);
J(:,:,3) = max(0, Id(:,:,3) * 0.55 - 0.04 * alpha);

% Blend only on detected cat region
for c = 1:3
    Id(:,:,c) = (1 - alpha) .* Id(:,:,c) + alpha .* J(:,:,c);
end

% Optional gentle denoising only in changed region
Iout = im2uint8(Id);
Iout = imbilatfilt(Iout, 10, 25);
Iout(~repmat(mask,[1 1 3])) = I(~repmat(mask,[1 1 3]));
end

function safeImwrite(I, outFile)
% Always ensure parent output directory exists before writing.
% This avoids errors when running script sections out-of-order.

[parentDir, ~, ~] = fileparts(outFile);
if ~isempty(parentDir) && ~exist(parentDir, 'dir')
    mkdir(parentDir);
end
imwrite(I, outFile);
end

function [segRGB, masks] = segmentLandscape(I)
% Segment landscape into classes approximating sample output:
% sky = blue, vegetation = green, man-made/other = red

I = im2uint8(I);
HSV = rgb2hsv(I);
H = HSV(:,:,1); S = HSV(:,:,2); V = HSV(:,:,3);

R = I(:,:,1); G = I(:,:,2); B = I(:,:,3);

% Sky: bright, low-to-medium saturation, often in blue/cyan hue.
sky = ((H > 0.50 & H < 0.72) & S < 0.45 & V > 0.45) | ...
      (V > 0.70 & S < 0.20);

% Restrict sky to upper image to avoid false positives
upperMask = false(size(sky));
upperMask(1:round(size(sky,1)*0.65), :) = true;
sky = sky & upperMask;
sky = imclose(sky, strel('disk', 5));
sky = imopen(sky, strel('disk', 3));
sky = imfill(sky, 'holes');
sky = bwareaopen(sky, 800);

% Vegetation: green dominant regions
vegetation = (G > R + 8) & (G > B + 8) & (S > 0.18) & ~sky;
vegetation = imopen(vegetation, strel('disk', 3));
vegetation = imclose(vegetation, strel('disk', 4));
vegetation = bwareaopen(vegetation, 200);

% Remaining regions -> man-made/other
manmade = ~(sky | vegetation);
manmade = bwareaopen(manmade, 100);

% Color-coded output map
segRGB = zeros(size(I), 'uint8');
segRGB(:,:,1) = uint8(manmade) * 255;     % red
segRGB(:,:,2) = uint8(vegetation) * 255;  % green
segRGB(:,:,3) = uint8(sky) * 255;         % blue

masks.sky = sky;
masks.vegetation = vegetation;
masks.manmade = manmade;
end

function Iout = blurBackgroundKeepCat(I)
% Keep cat in focus and blur background for portrait effect.

I = im2uint8(I);
HSV = rgb2hsv(I);
H = HSV(:,:,1); S = HSV(:,:,2); V = HSV(:,:,3);
R = I(:,:,1); G = I(:,:,2); B = I(:,:,3);

% Gray-ish fur detector + moderate brightness
grayFur = abs(int16(R)-int16(G)) < 20 & ...
          abs(int16(R)-int16(B)) < 34 & ...
          abs(int16(G)-int16(B)) < 34 & ...
          V > 0.15 & V < 0.95 & S < 0.35;

% Focus center prior (cat usually near center in sample)
[h, w, ~] = size(I);
[X, Y] = meshgrid(1:w, 1:h);
cx = w * 0.5; cy = h * 0.6;
rad = ((X - cx).^2)/(0.35*w)^2 + ((Y - cy).^2)/(0.45*h)^2;
centerPrior = rad < 1.4;

mask0 = grayFur & centerPrior;
mask = bwareaopen(mask0, 500);
mask = imclose(mask, strel('disk', 9));
mask = imfill(mask, 'holes');
mask = bwareafilt(mask, 1);

% Slight active contour refinement (fallback if unavailable)
try
    mask = activecontour(rgb2gray(I), mask, 40, 'edge');
catch
end

% Soft transition on edge
alpha = imgaussfilt(double(mask), 10);
alpha = max(0, min(alpha, 1));
alpha3 = repmat(alpha, [1 1 3]);

% Build blurred background (combine Gaussian + bilateral for smoother bokeh)
Ib = im2double(I);
bg1 = imgaussfilt(Ib, 6);
bg2 = imbilatfilt(im2uint8(bg1), 15, 30);
bg = im2double(bg2);

% Composite: subject sharp, background blurred
J = alpha3 .* Ib + (1 - alpha3) .* bg;

% Mild unsharp on subject region only
sharp = imsharpen(J, 'Radius', 1.2, 'Amount', 0.8);
J = alpha3 .* sharp + (1 - alpha3) .* J;

Iout = im2uint8(J);
end
