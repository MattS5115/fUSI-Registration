%% applyTransform.m
% Apply a landmarkReg saved transform to a source volume.
% Edit the three lines in the SET PATHS section, then press Run.
%
% Output variables saved to disk:
%   volWarped  [Z x X x Y]  — after affine (linear) warp only
%   volNL      [Z x X x Y]  — after affine + nonlinear warp (if NL was saved)

%% ── SET THESE PATHS ───────────────────────────────────────────────────────

vol1_path      = 'PDI_display.mat';          % source volume to warp (.mat or .tif)
transform_path = 'Transformation1.mat';  % saved from landmarkReg
output_name    = 'result1.mat';          % output file name (saved in same folder as vol1)

% Only needed if your transform has NO displacement field (linear-only save).
% If you ran NL warp before saving, leave this as ''.
vol2_path      = '';

%% ══════════════════════════════════════════════════════════════════════════

%% Load source volume
fprintf('Loading source volume: %s\n', vol1_path);
[~,~,ext] = fileparts(vol1_path);
if strcmpi(ext, '.mat')
    tmp  = load(vol1_path);
    fn   = fieldnames(tmp);
    vol1 = double(tmp.(fn{1}));
    if ismatrix(vol1)
        vol1 = reshape(vol1', [1 size(vol1,2) size(vol1,1)]);
    end
else
    info = imfinfo(vol1_path);
    nz   = numel(info);
    tmp0 = imread(vol1_path, 1);
    vol1 = zeros(nz, size(tmp0,1), size(tmp0,2));
    vol1(1,:,:) = tmp0;
    for k = 2:nz
        vol1(k,:,:) = imread(vol1_path, k);
    end
    vol1 = double(vol1);
end
[Sz1, Sx1, Sy1] = size(vol1);
fprintf('  Size: [%d x %d x %d]  (Z x X x Y)\n', Sz1, Sx1, Sy1);

%% Load transform
fprintf('Loading transform: %s\n', transform_path);
T         = load(transform_path);
AffineMat = T.AffineMat;
hasNL     = isfield(T,'DispField') && ~isempty(T.DispField);
if hasNL
    fprintf('  Found: AffineMat + DispField (linear + NL)\n');
else
    fprintf('  Found: AffineMat only (linear)\n');
end

%% Determine output grid size (vol2 space)
if hasNL
    Sz2 = size(T.DispField,1);
    Sx2 = size(T.DispField,2);
    Sy2 = size(T.DispField,3);
else
    if isempty(vol2_path)
        error('No DispField in transform — set vol2_path at the top of the script.');
    end
    fprintf('Loading vol2 for output grid: %s\n', vol2_path);
    [~,~,ext2] = fileparts(vol2_path);
    if strcmpi(ext2, '.mat')
        tmp2 = load(vol2_path);
        fn2  = fieldnames(tmp2);
        vol2 = double(tmp2.(fn2{1}));
    else
        info2 = imfinfo(vol2_path);
        nz2   = numel(info2);
        tmp02 = imread(vol2_path, 1);
        vol2  = zeros(nz2, size(tmp02,1), size(tmp02,2));
        vol2(1,:,:) = tmp02;
        for k = 2:nz2
            vol2(k,:,:) = imread(vol2_path, k);
        end
        vol2 = double(vol2);
    end
    [Sz2, Sx2, Sy2] = size(vol2);
    clear vol2;
end
fprintf('  Output grid: [%d x %d x %d]  (Z x X x Y)\n', Sz2, Sx2, Sy2);

%% Apply affine transform
fprintf('Applying affine transform...\n');
AffInv        = inv(AffineMat);
[gx, gy, gz]  = meshgrid(1:Sy2, 1:Sx2, 1:Sz2);
coords2       = [gz(:)'; gy(:)'; gx(:)'; ones(1, numel(gz))];
coords1       = AffInv * coords2;
vol1_perm     = permute(vol1, [2 3 1]);  % [X,Y,Z] for interp3
volWarped     = interp3(1:Sy1, 1:Sx1, 1:Sz1, vol1_perm, ...
                    coords1(3,:), coords1(2,:), coords1(1,:), 'linear', 0);
volWarped     = permute(reshape(volWarped, [Sx2, Sy2, Sz2]), [3 1 2]); % [Z,X,Y]
fprintf('  Done.\n');

%% Apply nonlinear displacement field (if present)
if hasNL
    fprintf('Applying nonlinear displacement field...\n');
    dFZ = T.DispField(:,:,:,1);  % [Z x X x Y]
    dFX = T.DispField(:,:,:,2);
    dFY = T.DispField(:,:,:,3);

    % Build meshgrid — same convention as landmarkReg (Y-fast element ordering)
    [gX2, gY2, gZ2] = meshgrid(1:Sx2, 1:Sy2, 1:Sz2);
    allZ = gZ2(:);  allX = gX2(:);  allY = gY2(:);

    % Permute dispField from [Z,X,Y] back to meshgrid ordering [Sy2,Sx2,Sz2]
    % so that (:) element ordering matches allZ/allX/allY
    toMesh = @(v) permute(v, [3 2 1]);
    dFZ_m  = toMesh(dFZ);  srcZ = allZ - dFZ_m(:);
    dFX_m  = toMesh(dFX);  srcX = allX - dFX_m(:);
    dFY_m  = toMesh(dFY);  srcY = allY - dFY_m(:);

    volW_perm = permute(volWarped, [2 3 1]);  % [X,Y,Z] for interp3
    volNL     = interp3(1:Sy2, 1:Sx2, 1:Sz2, volW_perm, srcY, srcX, srcZ, 'linear', 0);
    volNL     = permute(reshape(volNL, [Sy2, Sx2, Sz2]), [3 2 1]); % [Z,X,Y]
    fprintf('  Done.\n');
end

%% Save output
%% Save output
% Resolve to absolute path so we always know exactly where it goes
if isempty(fileparts(vol1_path))
    % vol1_path was a bare filename — save next to it in current folder
    save_dir = pwd;
else
    save_dir = fileparts(vol1_path);
end
output_path = fullfile(save_dir, output_name);

fprintf('Saving to:\n  %s\n', output_path);

% Save as single to halve file size and ensure volumeViewer compatibility
volWarped = single(volWarped);
volWarped(~isfinite(volWarped)) = 0;

if hasNL
    volNL = single(volNL);
    volNL(~isfinite(volNL)) = 0;
    save(output_path, 'volWarped', 'volNL');
else
    save(output_path, 'volWarped');
end

% Verify the file actually saved and show what's inside
if exist(output_path, 'file')
    info = whos('-file', output_path);
    fprintf('File saved OK. Contents:\n');
    for k = 1:numel(info)
        fprintf('  %-15s  [%s]  %s\n', info(k).name, ...
            num2str(info(k).size), info(k).class);
    end
else
    error('Save failed — file not found at:\n  %s', output_path);
end

fprintf('Done.\n');

%% Open in volumeViewer
if hasNL
    fprintf('Opening volNL in volumeViewer...\n');
    volumeViewer(volNL);
else
    fprintf('Opening volWarped in volumeViewer...\n');
    volumeViewer(volWarped);
end