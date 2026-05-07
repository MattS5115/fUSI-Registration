function landmarkReg2()
% LANDMARKREG  Interactive 3D landmark-based image registration GUI
%
% USAGE:
%   landmarkReg()
%
% Load two volumetric images (.mat or .tif), pick matching landmark points
% on both, then run Procrustes linear registration.
%
% Volume convention: [Z, X, Y]  (same as angioReg)
%   - MAT files: first variable in file, must be [Z x X x Y]
%   - TIF files: each page = one Z slice
%
% CONTROLS:
%   Left/Right arrow  : scroll Image 1 frames
%   Up/Down arrow     : scroll Image 2 frames
%   Click image       : add or remove point (depending on mode)
%
% REQUIREMENTS: Statistics and Machine Learning Toolbox (for procrustes)

%% ── Figure ────────────────────────────────────────────────────────────────
hFig = figure( ...
    'Name',        'Landmark Registration', ...
    'NumberTitle', 'off', ...
    'Position',    [30 30 1460 900], ...
    'Color',       [0.11 0.11 0.11], ...
    'MenuBar',     'none', ...
    'ToolBar',     'none', ...
    'KeyPressFcn', @onKeyPress, ...
    'CloseRequestFcn', @onClose);

%% ── Menu bar ──────────────────────────────────────────────────────────────
mFile = uimenu(hFig, 'Label', 'File');
uimenu(mFile, 'Label', 'Load Image 1 …',  'Callback', @(~,~)loadVol(hFig,1));
uimenu(mFile, 'Label', 'Load Image 2 …',  'Callback', @(~,~)loadVol(hFig,2));
uimenu(mFile, 'Label', 'Save Points …',   'Separator','on', 'Callback', @(~,~)savePoints(hFig));
uimenu(mFile, 'Label', 'Load Points …',   'Callback', @(~,~)loadPoints(hFig));
uimenu(mFile, 'Label', 'Save Transform …','Callback', @(~,~)saveTransform(hFig));

mEdit = uimenu(hFig, 'Label', 'Edit');
uimenu(mEdit, 'Label', 'Clear All Points', 'Callback', @(~,~)clearPoints(hFig));

%% ── State ─────────────────────────────────────────────────────────────────
st.vol1    = [];  st.vol2    = [];
st.pts1    = zeros(0,3);   % rows: [z, x, y]
st.pts2    = zeros(0,3);
st.plane1  = 'XY';  st.plane2  = 'XY';
st.frame1  = 1;     st.frame2  = 1;
st.addMode = true;          % true = add, false = remove-last
st.Transform = [];
guidata(hFig, st);

%% ── Colour palette ────────────────────────────────────────────────────────
BG  = [0.11 0.11 0.11];
BTN = [0.22 0.22 0.22];
TXT = [0.90 0.90 0.90];
ACC = [0.20 0.48 0.80];
FS  = 9;

%% ── Axes ──────────────────────────────────────────────────────────────────
ax1 = axes('Parent', hFig, 'Position', [0.03 0.20 0.445 0.73], ...
    'Color','k','XColor','w','YColor','w','FontSize',8);
ax2 = axes('Parent', hFig, 'Position', [0.525 0.20 0.445 0.73], ...
    'Color','k','XColor','w','YColor','w','FontSize',8);

%% ── Controls row – Image 1 ────────────────────────────────────────────────
yC = 148;

uicontrol('Style','text','String','Image 1 ─', ...
    'Position',[10 yC+5 65 18],'BackgroundColor',BG,'ForegroundColor',ACC, ...
    'FontSize',FS,'FontWeight','bold','HorizontalAlignment','left');

uicontrol('Style','text','String','Plane:', ...
    'Position',[78 yC+5 38 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS);
hPop1 = uicontrol('Style','popupmenu','String',{'XY','XZ','YZ'}, ...
    'Position',[116 yC 60 24],'FontSize',FS, ...
    'Callback',@(h,~)changePlane(hFig,1,h));

uicontrol('Style','text','String','Min:', ...
    'Position',[184 yC+5 28 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS);
hMin1 = uicontrol('Style','edit','String','0', ...
    'Position',[212 yC 60 24],'FontSize',FS,'Callback',@(~,~)drawAll(hFig));
uicontrol('Style','text','String','Max:', ...
    'Position',[278 yC+5 28 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS);
hMax1 = uicontrol('Style','edit','String','1', ...
    'Position',[306 yC 60 24],'FontSize',FS,'Callback',@(~,~)drawAll(hFig));

uicontrol('Style','text','String','Log:', ...
    'Position',[374 yC+5 28 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS);
hLog1 = uicontrol('Style','checkbox','Value',0, ...
    'Position',[402 yC+6 18 18],'BackgroundColor',BG,'Callback',@(~,~)drawAll(hFig));

%% ── Controls row – Image 2 ────────────────────────────────────────────────
uicontrol('Style','text','String','Image 2 ─', ...
    'Position',[730 yC+5 65 18],'BackgroundColor',BG,'ForegroundColor',ACC, ...
    'FontSize',FS,'FontWeight','bold','HorizontalAlignment','left');

uicontrol('Style','text','String','Plane:', ...
    'Position',[798 yC+5 38 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS);
hPop2 = uicontrol('Style','popupmenu','String',{'XY','XZ','YZ'}, ...
    'Position',[836 yC 60 24],'FontSize',FS, ...
    'Callback',@(h,~)changePlane(hFig,2,h));

uicontrol('Style','text','String','Min:', ...
    'Position',[904 yC+5 28 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS);
hMin2 = uicontrol('Style','edit','String','0', ...
    'Position',[932 yC 60 24],'FontSize',FS,'Callback',@(~,~)drawAll(hFig));
uicontrol('Style','text','String','Max:', ...
    'Position',[998 yC+5 28 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS);
hMax2 = uicontrol('Style','edit','String','1', ...
    'Position',[1026 yC 60 24],'FontSize',FS,'Callback',@(~,~)drawAll(hFig));

uicontrol('Style','text','String','Log:', ...
    'Position',[1094 yC+5 28 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS);
hLog2 = uicontrol('Style','checkbox','Value',0, ...
    'Position',[1122 yC+6 18 18],'BackgroundColor',BG,'Callback',@(~,~)drawAll(hFig));

%% ── Sliders ───────────────────────────────────────────────────────────────
yS = 178;

% Image 1 slider
hSld1 = uicontrol('Style','slider','Min',1,'Max',1+1e-6,'Value',1, ...
    'SliderStep',[1 1], ...
    'Position',[10 yS 595 20],'BackgroundColor',BTN, ...
    'Callback',@(h,~)sliderCB(hFig,1,h));
hFrm1 = uicontrol('Style','edit','String','1', ...
    'Position',[610 yS-2 45 24],'FontSize',FS, ...
    'Callback',@(h,~)frameEditCB(hFig,1,h));
hMax1lbl = uicontrol('Style','text','String','/ –', ...
    'Position',[658 yS+1 50 20], ...
    'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS, ...
    'HorizontalAlignment','left');

% Image 2 slider
hSld2 = uicontrol('Style','slider','Min',1,'Max',1+1e-6,'Value',1, ...
    'SliderStep',[1 1], ...
    'Position',[720 yS 595 20],'BackgroundColor',BTN, ...
    'Callback',@(h,~)sliderCB(hFig,2,h));
hFrm2 = uicontrol('Style','edit','String','1', ...
    'Position',[1320 yS-2 45 24],'FontSize',FS, ...
    'Callback',@(h,~)frameEditCB(hFig,2,h));
hMax2lbl = uicontrol('Style','text','String','/ –', ...
    'Position',[1368 yS+1 50 20], ...
    'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS, ...
    'HorizontalAlignment','left');

%% ── Bottom control bar ────────────────────────────────────────────────────
yB = 110;

% -- Mode buttons
uicontrol('Style','text','String','Click mode:', ...
    'Position',[10 yB+6 72 20], ...
    'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',FS);
hAddBtn = uicontrol('Style','togglebutton','String','Add Point','Value',1, ...
    'Position',[85 yB 95 28], ...
    'BackgroundColor',[0.18 0.48 0.20],'ForegroundColor','w','FontSize',FS, ...
    'Callback',@(h,~)setMode(hFig,'add'));
hRemBtn = uicontrol('Style','togglebutton','String','Remove Last','Value',0, ...
    'Position',[185 yB 100 28], ...
    'BackgroundColor',BTN,'ForegroundColor',TXT,'FontSize',FS, ...
    'Callback',@(h,~)setMode(hFig,'remove'));

% -- Point counter
hPtCount = uicontrol('Style','text','String','Points  Img1: 0   Img2: 0', ...
    'Position',[300 yB+6 200 20], ...
    'BackgroundColor',BG,'ForegroundColor',[1.0 0.80 0.20], ...
    'FontSize',10,'FontWeight','bold','HorizontalAlignment','left');

% -- Register
uicontrol('Style','pushbutton','String','▶  Register (Procrustes)', ...
    'Position',[515 yB 185 30], ...
    'BackgroundColor',[0.15 0.38 0.65],'ForegroundColor','w', ...
    'FontSize',FS,'FontWeight','bold', ...
    'Callback',@(~,~)runRegistration(hFig));

% -- File I/O buttons
uicontrol('Style','pushbutton','String','Save Points', ...
    'Position',[715 yB 95 28], ...
    'BackgroundColor',BTN,'ForegroundColor',TXT,'FontSize',FS, ...
    'Callback',@(~,~)savePoints(hFig));
uicontrol('Style','pushbutton','String','Load Points', ...
    'Position',[815 yB 95 28], ...
    'BackgroundColor',BTN,'ForegroundColor',TXT,'FontSize',FS, ...
    'Callback',@(~,~)loadPoints(hFig));
uicontrol('Style','pushbutton','String','Save Transform', ...
    'Position',[915 yB 110 28], ...
    'BackgroundColor',BTN,'ForegroundColor',TXT,'FontSize',FS, ...
    'Callback',@(~,~)saveTransform(hFig));
uicontrol('Style','pushbutton','String','Clear All Pts', ...
    'Position',[1035 yB 100 28], ...
    'BackgroundColor',[0.45 0.15 0.15],'ForegroundColor','w','FontSize',FS, ...
    'Callback',@(~,~)clearPoints(hFig));

% -- Keyboard hint
uicontrol('Style','text', ...
    'String','← → scroll Img1   ↑ ↓ scroll Img2', ...
    'Position',[10 yB-26 280 18], ...
    'BackgroundColor',BG,'ForegroundColor',[0.55 0.55 0.55],'FontSize',8, ...
    'HorizontalAlignment','left');

% -- Status bar
hStatus = uicontrol('Style','text','String','Use File menu to load images.', ...
    'Position',[10 yB-50 1420 22], ...
    'BackgroundColor',[0.08 0.08 0.08],'ForegroundColor',[0.60 0.90 0.60], ...
    'FontSize',FS,'HorizontalAlignment','left');

%% ── Store all handles in appdata ──────────────────────────────────────────
H.ax1      = ax1;      H.ax2      = ax2;
H.hSld1    = hSld1;    H.hSld2    = hSld2;
H.hFrm1    = hFrm1;    H.hFrm2    = hFrm2;
H.hMax1lbl = hMax1lbl; H.hMax2lbl = hMax2lbl;
H.hPop1    = hPop1;    H.hPop2    = hPop2;
H.hMin1    = hMin1;    H.hMax1    = hMax1;
H.hMin2    = hMin2;    H.hMax2    = hMax2;
H.hLog1    = hLog1;    H.hLog2    = hLog2;
H.hAddBtn  = hAddBtn;  H.hRemBtn  = hRemBtn;
H.hPtCount = hPtCount;
H.hStatus  = hStatus;
setappdata(hFig, 'handles', H);

%% ════════════════════════════════════════════════════════════════════════════
%%  CALLBACKS
%% ════════════════════════════════════════════════════════════════════════════

    %% ── Load volume ───────────────────────────────────────────────────────
    function loadVol(fig, idx)
        [fname, pname] = uigetfile( ...
            {'*.mat;*.tif;*.tiff','Image files (*.mat, *.tif)'}, ...
            sprintf('Select Image %d', idx));
        if isequal(fname, 0), return; end

        setStatus(fig, sprintf('Loading Image %d …', idx));
        drawnow;

        fpath = fullfile(pname, fname);
        [~,~,ext] = fileparts(fname);

        try
            if strcmpi(ext, '.mat')
                tmp = load(fpath);
                fn  = fieldnames(tmp);
                vol = double(tmp.(fn{1}));
                % Handle 2-D case: treat as single Z-slice
                if ismatrix(vol)
                    vol = permute(vol, [3 1 2]);   % → [1 x X x Y]
                    vol = reshape(vol, [1 size(vol,2) size(vol,3)]);
                end
            else
                info = imfinfo(fpath);
                nz   = numel(info);
                tmp0 = imread(fpath, 1);
                vol  = zeros(nz, size(tmp0,1), size(tmp0,2));
                vol(1,:,:) = tmp0;
                for k = 2:nz
                    vol(k,:,:) = imread(fpath, k);
                end
                vol = double(vol);
            end
        catch ME
            setStatus(fig, ['Error loading file: ' ME.message]);
            return;
        end

        H  = getappdata(fig, 'handles');
        st = guidata(fig);

        vmin = min(vol(:));  vmax = max(vol(:));

        if idx == 1
            st.vol1   = vol;
            st.frame1 = 1;
            st.plane1 = 'XY';
            set(H.hPop1, 'Value', 1);
            configSlider(H.hSld1, H.hFrm1, H.hMax1lbl, vol, 'XY');
            set(H.hMin1, 'String', sprintf('%.4g', vmin));
            set(H.hMax1, 'String', sprintf('%.4g', vmax));
        else
            st.vol2   = vol;
            st.frame2 = 1;
            st.plane2 = 'XY';
            set(H.hPop2, 'Value', 1);
            configSlider(H.hSld2, H.hFrm2, H.hMax2lbl, vol, 'XY');
            set(H.hMin2, 'String', sprintf('%.4g', vmin));
            set(H.hMax2, 'String', sprintf('%.4g', vmax));
        end

        guidata(fig, st);
        setStatus(fig, sprintf('Image %d loaded: [%d × %d × %d]  (Z × X × Y)  |  range [%.4g, %.4g]', ...
            idx, size(vol,1), size(vol,2), size(vol,3), vmin, vmax));
        drawAll(fig);
    end

    %% ── Change viewing plane ──────────────────────────────────────────────
    function changePlane(fig, idx, hpop)
        planes = {'XY','XZ','YZ'};
        plane  = planes{get(hpop,'Value')};
        H  = getappdata(fig,'handles');
        st = guidata(fig);

        if idx == 1
            if isempty(st.vol1), return; end
            st.plane1 = plane;
            st.frame1 = 1;
            configSlider(H.hSld1, H.hFrm1, H.hMax1lbl, st.vol1, plane);
        else
            if isempty(st.vol2), return; end
            st.plane2 = plane;
            st.frame2 = 1;
            configSlider(H.hSld2, H.hFrm2, H.hMax2lbl, st.vol2, plane);
        end

        guidata(fig, st);
        drawAll(fig);
    end

    %% ── Slider callback ───────────────────────────────────────────────────
    function sliderCB(fig, idx, hsl)
        H  = getappdata(fig,'handles');
        st = guidata(fig);
        f  = round(get(hsl,'Value'));

        if idx == 1
            if isempty(st.vol1), return; end
            nf = getNFrames(st.vol1, st.plane1);
            f  = clamp(f, 1, nf);
            st.frame1 = f;
            set(H.hFrm1, 'String', num2str(f));
        else
            if isempty(st.vol2), return; end
            nf = getNFrames(st.vol2, st.plane2);
            f  = clamp(f, 1, nf);
            st.frame2 = f;
            set(H.hFrm2, 'String', num2str(f));
        end

        guidata(fig, st);
        drawAll(fig);
    end

    %% ── Frame edit-box callback ───────────────────────────────────────────
    function frameEditCB(fig, idx, hedit)
        H  = getappdata(fig,'handles');
        st = guidata(fig);
        f  = round(str2double(get(hedit,'String')));
        if isnan(f), f = 1; end

        if idx == 1
            if isempty(st.vol1), return; end
            nf = getNFrames(st.vol1, st.plane1);
            f  = clamp(f, 1, nf);
            st.frame1 = f;
            set(H.hSld1, 'Value', f);
            set(H.hFrm1, 'String', num2str(f));
        else
            if isempty(st.vol2), return; end
            nf = getNFrames(st.vol2, st.plane2);
            f  = clamp(f, 1, nf);
            st.frame2 = f;
            set(H.hSld2, 'Value', f);
            set(H.hFrm2, 'String', num2str(f));
        end

        guidata(fig, st);
        drawAll(fig);
    end

    %% ── Mode (add / remove) ───────────────────────────────────────────────
    function setMode(fig, mode)
        H  = getappdata(fig,'handles');
        st = guidata(fig);
        if strcmp(mode,'add')
            st.addMode = true;
            set(H.hAddBtn,'Value',1,'BackgroundColor',[0.18 0.48 0.20]);
            set(H.hRemBtn,'Value',0,'BackgroundColor',[0.22 0.22 0.22]);
        else
            st.addMode = false;
            set(H.hRemBtn,'Value',1,'BackgroundColor',[0.55 0.18 0.18]);
            set(H.hAddBtn,'Value',0,'BackgroundColor',[0.22 0.22 0.22]);
        end
        guidata(fig, st);
    end

    %% ── Image click – Image 1 ─────────────────────────────────────────────
    function ax1Click(~, ~)
        fig = hFig;
        st  = guidata(fig);
        if isempty(st.vol1), return; end
        H   = getappdata(fig,'handles');
        cp  = get(H.ax1, 'CurrentPoint');
        col = round(cp(1,1));
        row = round(cp(1,2));
        pt  = clickToPoint(col, row, st.frame1, st.plane1, st.vol1);
        if isempty(pt), return; end

        if st.addMode
            st.pts1 = [st.pts1; pt];
            setStatus(fig, sprintf('Img1 — added pt %d:  z=%d  x=%d  y=%d', ...
                size(st.pts1,1), pt(1), pt(2), pt(3)));
        else
            if ~isempty(st.pts1)
                st.pts1 = st.pts1(1:end-1,:);
                setStatus(fig, 'Img1 — removed last point.');
            end
        end

        guidata(fig, st);
        updatePtCount(fig);
        drawAll(fig);
    end

    %% ── Image click – Image 2 ─────────────────────────────────────────────
    function ax2Click(~, ~)
        fig = hFig;
        st  = guidata(fig);
        if isempty(st.vol2), return; end
        H   = getappdata(fig,'handles');
        cp  = get(H.ax2, 'CurrentPoint');
        col = round(cp(1,1));
        row = round(cp(1,2));
        pt  = clickToPoint(col, row, st.frame2, st.plane2, st.vol2);
        if isempty(pt), return; end

        if st.addMode
            st.pts2 = [st.pts2; pt];
            setStatus(fig, sprintf('Img2 — added pt %d:  z=%d  x=%d  y=%d', ...
                size(st.pts2,1), pt(1), pt(2), pt(3)));
        else
            if ~isempty(st.pts2)
                st.pts2 = st.pts2(1:end-1,:);
                setStatus(fig, 'Img2 — removed last point.');
            end
        end

        guidata(fig, st);
        updatePtCount(fig);
        drawAll(fig);
    end

    %% ── Run Procrustes registration ───────────────────────────────────────
    function runRegistration(fig)
        st = guidata(fig);
        n1 = size(st.pts1, 1);
        n2 = size(st.pts2, 1);

        if n1 < 3 || n2 < 3
            setStatus(fig, '✗  Need at least 3 point pairs to register.');
            return;
        end
        if n1 ~= n2
            setStatus(fig, sprintf( ...
                '⚠  Point counts differ (%d vs %d). Using first %d pairs.', ...
                n1, n2, min(n1,n2)));
            drawnow;
        end

        S  = min(n1, n2);
        p1 = st.pts1(1:S,:);   % source      (Image 1 coords) [z x y]
        p2 = st.pts2(1:S,:);   % destination (Image 2 coords) [z x y]

        % ── Coplanarity / collinearity check ──────────────────────────────
        % All points on the same slice = the rotation in that axis is
        % unconstrained → the volume warp will look wrong even if points align.
        dimNames = {'Z','X','Y'};
        for dim = 1:3
            if S >= 2 && range(p1(:,dim)) < 2
                setStatus(fig, sprintf( ...
                    ['⚠  WARNING: All Image 1 points share nearly the same %s ' ...
                     'coordinate (range = %.1f vx). Pick landmarks across different ' ...
                     '%s slices — otherwise the 3D rotation is unconstrained and the ' ...
                     'volume warp will be wrong even if the points appear to align.'], ...
                    dimNames{dim}, range(p1(:,dim)), dimNames{dim}));
                drawnow; pause(0.1);
            end
        end

        % procrustes(Y, X): finds T such that  b * X * T.T + c  ≈  Y
        % maps Image-1 coords → Image-2 coords
        [D, ~, T] = procrustes(p2, p1);

        % ── Per-point residuals ────────────────────────────────────────────
        p1_mapped = T.b * p1 * T.T + T.c;
        residuals = sqrt(sum((p1_mapped - p2).^2, 2));

        % ── Build 4×4 affine matrix ────────────────────────────────────────
        % procrustes row-vector form:  x_dst_row = b * x_src_row * T.T + c(1,:)
        % Column-vector equivalent:    x_dst_col = b * T.T.' * x_src_col + c(1,:)'
        % The 3×3 linear block is therefore  b * T.T.'  (note the transpose)
        % Using T.T (no transpose) applies the inverse rotation — that was the bug.
        M3 = T.b * T.T.';
        t  = T.c(1,:)';
        AffineMat = eye(4);
        AffineMat(1:3,1:3) = M3;
        AffineMat(1:3,4)   = t;

        st.Transform             = T;
        st.Transform.SourcePts   = p1;
        st.Transform.DestPts     = p2;
        st.Transform.ProcrustesD = D;
        st.Transform.AffineMat   = AffineMat;
        guidata(fig, st);

        % ── Warp vol1 into vol2's coordinate space ─────────────────────────
        % Strategy: inverse-map (pull interpolation)
        %   For every voxel (z2,x2,y2) in the vol2 grid, compute where it
        %   came from in vol1 space using the inverse affine, then sample.
        %   This is identical in result to what angioReg does with its loop,
        %   but uses MATLAB's interp3 for efficiency.
        setStatus(fig, sprintf( ...
            '✓  Procrustes done (error=%.5f).  Warping vol1 → vol2 space …', D));
        drawnow;

        [Sz2, Sx2, Sy2] = size(st.vol2);
        AffInv = inv(AffineMat);

        % Build grid of all vol2 voxel coordinates [z x y]
        [gx, gy, gz] = meshgrid(1:Sy2, 1:Sx2, 1:Sz2);
        % gx=Y, gy=X, gz=Z  (meshgrid convention)
        coords2 = [gz(:)' ; gy(:)' ; gx(:)' ; ones(1, numel(gz))];  % 4×N

        % Map back to vol1 coords
        coords1 = AffInv * coords2;   % 4×N
        z1q = coords1(1,:);
        x1q = coords1(2,:);
        y1q = coords1(3,:);

        % Sample vol1 — interp3 uses (Y,X,Z) ordering to match meshgrid
        % vol1 is [Z1,X1,Y1]; interp3(V, Yq, Xq, Zq)
        [Sz1, Sx1, Sy1] = size(st.vol1);
        vol1_perm = permute(st.vol1, [2 3 1]);  % → [X1, Y1, Z1] for interp3
        % interp3 grid vectors
        xi = 1:Sy1;  yi = 1:Sx1;  zi = 1:Sz1;
        % Query points: interp3(V, Xq, Yq, Zq) where V is [rows=Y, cols=X, pages=Z]
        % interp3 expects (xi=col, yi=row, zi=page) → (y1q, x1q, z1q)
        volWarped = interp3(xi, yi, zi, vol1_perm, y1q, x1q, z1q, 'linear', 0);
        volWarped = reshape(volWarped, [Sx2, Sy2, Sz2]);
        volWarped = permute(volWarped, [3 1 2]);  % → [Z2, X2, Y2]

        st.volWarped = volWarped;
        guidata(fig, st);

        setStatus(fig, sprintf( ...
            '✓  Registration done.  Procrustes D=%.5f  (%d pairs)  |  opening overlay …', D, S));
        drawnow;
        openOverlay(fig);
    end

    %% ── Overlay viewer ────────────────────────────────────────────────────
    function openOverlay(fig)
        st = guidata(fig);
        if isempty(st.vol1) || isempty(st.vol2)
            setStatus(fig, '✗  Need both volumes loaded to show overlay.');
            return;
        end

        existing = findobj('Name','Registration Overlay');
        if ~isempty(existing), close(existing); end

        oFig = figure( ...
            'Name',       'Registration Overlay', ...
            'NumberTitle','off', ...
            'Position',   [60 50 1320 980], ...
            'Color',      [0.10 0.10 0.10], ...
            'MenuBar',    'none', ...
            'ToolBar',    'none');

        % ── Overlay state ─────────────────────────────────────────────────
        ost.plane      = 'XY';
        ost.frame      = 1;
        ost.vol2       = st.vol2;
        ost.volRaw1    = st.vol1;
        ost.volWarped  = st.volWarped;     % linear-registered vol1
        ost.volNL      = [];               % nonlinear result (filled after NL run)
        ost.pts1       = st.pts1;          % original linear landmark pts (img1 space)
        ost.pts2       = st.pts2;          % original linear landmark pts (img2 space)
        ost.T          = st.Transform;
        ost.showMode   = 'linear';         % 'raw' | 'linear' | 'nl'
        % NL anchor points — all coords in vol2 space (single-click anchors)
        ost.nlAnchors  = zeros(0,3);       % anchor positions (zero-displacement constraints)
        ost.nlMode     = false;            % anchor picking active?
        % ── Surface-mesh phase state ───────────────────────────────────
        ost.surfacePts  = zeros(0,3);      % user-clicked PDI surface pts [z x y]
        ost.surfaceMesh = [];              % struct with verts/faces from buildSurfaceMeshLocal
        % ── Atlas target-mesh phase state ──────────────────────────────
        ost.targetMesh  = [];              % struct with verts/faces from atlas surface extraction
        ost.atlasCrop   = [];              % struct with masks and plane info from segmentation
        guidata(oFig, ost);

        BG2  = [0.10 0.10 0.10];
        TXT2 = [0.90 0.90 0.90];

        % ── Axes ──────────────────────────────────────────────────────────
        oAx = axes('Parent',oFig,'Position',[0.05 0.17 0.90 0.78], ...
            'Color','k','XColor','w','YColor','w','FontSize',8);

        % ── Top controls row ──────────────────────────────────────────────
        yC = 128;

        uicontrol('Parent',oFig,'Style','text','String','Plane:', ...
            'Position',[12 yC+4 42 18],'BackgroundColor',BG2,'ForegroundColor',TXT2,'FontSize',9);
        oPop = uicontrol('Parent',oFig,'Style','popupmenu', ...
            'String',{'XY','XZ','YZ'},'Position',[54 yC 62 24],'FontSize',9, ...
            'Callback',@(h,~)oChangePlane(oFig,h));

        uicontrol('Parent',oFig,'Style','text','String','Img2 α:', ...
            'Position',[130 yC+4 50 18],'BackgroundColor',BG2,'ForegroundColor',TXT2,'FontSize',9);
        oAlpha = uicontrol('Parent',oFig,'Style','slider', ...
            'Min',0,'Max',1,'Value',0.5,'SliderStep',[0.05 0.1], ...
            'Position',[182 yC+2 100 18],'Callback',@(~,~)oDrawAll(oFig));

        % Show mode selector
        uicontrol('Parent',oFig,'Style','text','String','Show:', ...
            'Position',[295 yC+4 36 18],'BackgroundColor',BG2,'ForegroundColor',TXT2,'FontSize',9);
        hShowRaw = uicontrol('Parent',oFig,'Style','togglebutton','String','Raw', ...
            'Value',0,'Position',[332 yC 55 24], ...
            'BackgroundColor',BG2,'ForegroundColor',TXT2,'FontSize',9, ...
            'Callback',@(~,~)oSetShow(oFig,'raw'));
        hShowLin = uicontrol('Parent',oFig,'Style','togglebutton','String','Linear', ...
            'Value',1,'Position',[390 yC 65 24], ...
            'BackgroundColor',[0.18 0.38 0.58],'ForegroundColor','w','FontSize',9, ...
            'Callback',@(~,~)oSetShow(oFig,'linear'));
        hShowNL  = uicontrol('Parent',oFig,'Style','togglebutton','String','NL Warp', ...
            'Value',0,'Position',[458 yC 70 24], ...
            'BackgroundColor',BG2,'ForegroundColor',[0.5 0.5 0.5],'FontSize',9, ...
            'Callback',@(~,~)oSetShow(oFig,'nl'));

        uicontrol('Parent',oFig,'Style','text', ...
            'String','Magenta = Img1    Green = Img2    White = overlap', ...
            'Position',[545 yC+4 370 18],'BackgroundColor',BG2, ...
            'ForegroundColor',[0.65 0.65 0.65],'FontSize',8,'HorizontalAlignment','left');

        % ── NL picking controls row ────────────────────────────────────────
        yN = 98;

        hNLBtn = uicontrol('Parent',oFig,'Style','togglebutton', ...
            'String','● Pick Anchor Points  (single click)', ...
            'Value',0,'Position',[12 yN 230 26], ...
            'BackgroundColor',BG2,'ForegroundColor',[0.6 0.6 0.6],'FontSize',9, ...
            'Callback',@(h,~)oToggleNLMode(oFig,h));

        uicontrol('Parent',oFig,'Style','pushbutton','String','Undo Last Anchor', ...
            'Position',[250 yN 115 26], ...
            'BackgroundColor',BG2,'ForegroundColor',TXT2,'FontSize',9, ...
            'Callback',@(~,~)oUndoNLPair(oFig));

        uicontrol('Parent',oFig,'Style','pushbutton','String','Clear Anchors', ...
            'Position',[372 yN 105 26], ...
            'BackgroundColor',[0.35 0.12 0.12],'ForegroundColor','w','FontSize',9, ...
            'Callback',@(~,~)oClearNLPairs(oFig));

        hNLCount = uicontrol('Parent',oFig,'Style','text', ...
            'String','Anchors: 0  (+ 0 from linear reg)', ...
            'Position',[478 yN+4 230 18],'BackgroundColor',BG2, ...
            'ForegroundColor',[1.0 0.85 0.30],'FontSize',9,'HorizontalAlignment','left');

        uicontrol('Parent',oFig,'Style','pushbutton', ...
            'String','▶  Run Surface Registration', ...
            'Position',[720 yN 240 28], ...
            'BackgroundColor',[0.15 0.42 0.22],'ForegroundColor','w', ...
            'FontSize',9,'FontWeight','bold', ...
            'Callback',@(~,~)oRunNL(oFig));

        % ── Mesh controls row ─────────────────────────────────────────────
        yM = 68;

        uicontrol('Parent',oFig,'Style','pushbutton', ...
            'String','▶  Pick PDI Surface Pts → Build Mesh', ...
            'Position',[12 yM 310 28], ...
            'BackgroundColor',[0.30 0.20 0.55],'ForegroundColor','w', ...
            'FontSize',9,'FontWeight','bold', ...
            'Callback',@(~,~)oRunSurfacePicker(oFig));

        uicontrol('Parent',oFig,'Style','pushbutton', ...
            'String','▶  Segment Atlas → Build Target Mesh', ...
            'Position',[335 yM 310 28], ...
            'BackgroundColor',[0.20 0.40 0.55],'ForegroundColor','w', ...
            'FontSize',9,'FontWeight','bold', ...
            'Callback',@(~,~)oRunAtlasSurface(oFig));

        % ── Slider ────────────────────────────────────────────────────────
        yS = 42;
        oSld = uicontrol('Parent',oFig,'Style','slider','Min',1,'Max',1+1e-6,'Value',1, ...
            'Position',[12 yS 1180 18],'BackgroundColor',[0.22 0.22 0.22], ...
            'Callback',@(h,~)oSliderCB(oFig,h));
        oFrmEdit = uicontrol('Parent',oFig,'Style','edit','String','1', ...
            'Position',[1198 yS-2 46 24],'FontSize',9, ...
            'Callback',@(h,~)oFrameEditCB(oFig,h));
        oMaxLbl = uicontrol('Parent',oFig,'Style','text','String','/ –', ...
            'Position',[1248 yS+1 60 18],'BackgroundColor',BG2,'ForegroundColor',TXT2, ...
            'FontSize',9,'HorizontalAlignment','left');

        % ── Status bar ────────────────────────────────────────────────────
        oStatusLbl = uicontrol('Parent',oFig,'Style','text','String','', ...
            'Position',[12 10 1290 22],'BackgroundColor',[0.07 0.07 0.07], ...
            'ForegroundColor',[0.55 0.90 0.55],'FontSize',8,'HorizontalAlignment','left');

        % Store handles
        oH.oAx       = oAx;
        oH.oSld      = oSld;   oH.oFrmEdit  = oFrmEdit;  oH.oMaxLbl   = oMaxLbl;
        oH.oAlpha    = oAlpha; oH.oPop      = oPop;
        oH.hShowRaw  = hShowRaw; oH.hShowLin = hShowLin; oH.hShowNL  = hShowNL;
        oH.hNLBtn    = hNLBtn; oH.hNLCount  = hNLCount;
        oH.oStatusLbl= oStatusLbl;
        setappdata(oFig,'oHandles',oH);

        sz2 = size(ost.vol2);
        oConfigSlider(oFig, sz2(1));
        oDrawAll(oFig);

        % ══════════════════════════════════════════════════════════════════
        %  OVERLAY NESTED CALLBACKS
        % ══════════════════════════════════════════════════════════════════

        function oChangePlane(ofig, hpop)
            planes = {'XY','XZ','YZ'};
            ost2 = guidata(ofig);
            ost2.plane = planes{get(hpop,'Value')};
            ost2.frame = 1;
            guidata(ofig, ost2);
            oConfigSlider(ofig, getNFrames(ost2.vol2, ost2.plane));
            oDrawAll(ofig);
        end

        % ── Show mode ─────────────────────────────────────────────────────
        function oSetShow(ofig, mode)
            oH2  = getappdata(ofig,'oHandles');
            ost2 = guidata(ofig);
            if strcmp(mode,'nl') && isempty(ost2.volNL)
                oSetStatus(ofig,'✗  Run NL Warp first.');
                set(oH2.hShowNL,'Value',0);
                return;
            end
            ost2.showMode = mode;
            guidata(ofig, ost2);
            % Update button appearances
            set(oH2.hShowRaw,'Value',strcmp(mode,'raw'),   'BackgroundColor', ...
                ternary(strcmp(mode,'raw'),  [0.38 0.25 0.10], BG2), ...
                'ForegroundColor', ternary(strcmp(mode,'raw'),  'w', TXT2));
            set(oH2.hShowLin,'Value',strcmp(mode,'linear'),'BackgroundColor', ...
                ternary(strcmp(mode,'linear'),[0.18 0.38 0.58], BG2), ...
                'ForegroundColor', ternary(strcmp(mode,'linear'),'w', TXT2));
            set(oH2.hShowNL, 'Value',strcmp(mode,'nl'),   'BackgroundColor', ...
                ternary(strcmp(mode,'nl'),   [0.15 0.42 0.22], BG2), ...
                'ForegroundColor', ternary(strcmp(mode,'nl'),   'w', TXT2));
            oDrawAll(ofig);
        end

        % ── NL mode toggle ────────────────────────────────────────────────
        function oToggleNLMode(ofig, h)
            ost2 = guidata(ofig);
            ost2.nlMode = logical(get(h,'Value'));
            guidata(ofig, ost2);
            oH2 = getappdata(ofig,'oHandles');
            if ost2.nlMode
                set(h,'BackgroundColor',[0.60 0.42 0.05],'ForegroundColor','w');
                set(ofig,'WindowButtonDownFcn',@(~,~)oNLClick(ofig));
                oSetStatus(ofig,'Anchor mode ON — click to add zero-displacement anchor points');
            else
                set(h,'BackgroundColor',BG2,'ForegroundColor',[0.6 0.6 0.6]);
                set(ofig,'WindowButtonDownFcn','');
                oSetStatus(ofig,'Anchor mode OFF');
            end
            oDrawAll(ofig);
        end

        % ── NL click handler (alternating src / dst) ──────────────────────
        function oNLClick(ofig)
            ost2 = guidata(ofig);
            if ~ost2.nlMode, return; end
            oH2 = getappdata(ofig,'oHandles');

            cp = get(oH2.oAx, 'CurrentPoint');
            xl = get(oH2.oAx, 'XLim');
            yl = get(oH2.oAx, 'YLim');
            col = cp(1,1);  row = cp(1,2);
            if col < xl(1) || col > xl(2) || row < yl(1) || row > yl(2)
                return;
            end

            col = round(col);  row = round(row);
            pt  = clickToPoint(col, row, ost2.frame, ost2.plane, ost2.vol2);
            if isempty(pt), return; end

            ost2.nlAnchors = [ost2.nlAnchors; pt];
            guidata(ofig, ost2);
            oUpdateNLCount(ofig);
            oDrawAll(ofig);
            oSetStatus(ofig, sprintf( ...
                'Anchor %d added [z=%d x=%d y=%d].  Click next anchor or toggle off.', ...
                size(ost2.nlAnchors,1), pt(1), pt(2), pt(3)));
        end

        % ── Undo / Clear NL pairs ─────────────────────────────────────────
        function oUndoNLPair(ofig)
            ost2 = guidata(ofig);
            if isempty(ost2.nlAnchors)
                oSetStatus(ofig,'No anchors to undo.');
                return;
            end
            ost2.nlAnchors = ost2.nlAnchors(1:end-1,:);
            guidata(ofig, ost2);
            oUpdateNLCount(ofig);
            oDrawAll(ofig);
            oSetStatus(ofig,'Last anchor removed.');
        end

        function oClearNLPairs(ofig)
            ost2 = guidata(ofig);
            ost2.nlAnchors = zeros(0,3);
            guidata(ofig, ost2);
            oUpdateNLCount(ofig);
            oDrawAll(ofig);
            oSetStatus(ofig,'All anchors cleared.');
        end

        % ── Run surface registration ──────────────────────────────────────
        function oRunNL(ofig)
            ost2 = guidata(ofig);

            % ── Check prerequisites ──────────────────────────────────────
            if isempty(ost2.surfaceMesh)
                oSetStatus(ofig, '✗  Build the PDI source mesh first.');
                return;
            end
            if isempty(ost2.targetMesh)
                oSetStatus(ofig, '✗  Build the atlas target mesh first.');
                return;
            end

            % ── Build anchor point list ──────────────────────────────────
            % 1. Linear-reg landmarks: pts1 transformed → vol2 space, paired with pts2
            T2   = ost2.T;
            nLin = size(ost2.pts1,1);
            anchSrc = zeros(nLin,3);
            anchDst = zeros(nLin,3);
            for k = 1:nLin
                tPt = T2.b * ost2.pts1(k,:) * T2.T + T2.c(1,:);
                anchSrc(k,:) = tPt;
                anchDst(k,:) = ost2.pts2(k,:);
            end

            % 2. User-clicked zero-displacement anchors
            nUserAnch = size(ost2.nlAnchors, 1);
            allAnchSrc = [anchSrc; ost2.nlAnchors];
            allAnchDst = [anchDst; ost2.nlAnchors];  % same point = zero displacement

            oSetStatus(ofig, sprintf( ...
                'Running surface registration (%d linear + %d user anchors)…', ...
                nLin, nUserAnch));
            drawnow;

            % ── Run ICP + TPS surface registration ───────────────────────
            try
                [regResult] = registerSurfaceMeshes( ...
                    ost2.surfaceMesh, ost2.targetMesh, ...
                    allAnchSrc, allAnchDst);
            catch ME
                oSetStatus(ofig, ['✗  Registration failed: ' ME.message]);
                return;
            end

            oSetStatus(ofig, sprintf( ...
                'Registration done (rms=%.2f vox). Warping volume…', regResult.finalRMS));
            drawnow;

            % ── Apply displacement field to volWarped → volNL ────────────
            [Sz2, Sx2, Sy2] = size(ost2.vol2);

            % Build vol2-space grid
            [gX, gY, gZ] = meshgrid(1:Sx2, 1:Sy2, 1:Sz2);
            allZ = gZ(:);  allX = gX(:);  allY = gY(:);

            % Evaluate TPS at every voxel
            dispZ = evalRBF3(regResult.tpsZ, [allZ'; allX'; allY'])';
            dispX = evalRBF3(regResult.tpsX, [allZ'; allX'; allY'])';
            dispY = evalRBF3(regResult.tpsY, [allZ'; allX'; allY'])';

            % Clamp
            maxD = [Sz2 Sx2 Sy2] / 2;
            dispZ = max(min(dispZ, maxD(1)), -maxD(1));
            dispX = max(min(dispX, maxD(2)), -maxD(2));
            dispY = max(min(dispY, maxD(3)), -maxD(3));

            % Smooth
            toVol  = @(d) permute(reshape(d,[Sy2,Sx2,Sz2]),[3 2 1]);
            toMesh = @(v) permute(v,[3 2 1]);

            smoothSigma = 2;
            dFZ_vol = imgaussfilt3(toVol(dispZ), smoothSigma);
            dFX_vol = imgaussfilt3(toVol(dispX), smoothSigma);
            dFY_vol = imgaussfilt3(toVol(dispY), smoothSigma);

            dFZ_m = toMesh(dFZ_vol);
            dFX_m = toMesh(dFX_vol);
            dFY_m = toMesh(dFY_vol);

            % Inverse-map: sample volWarped
            srcZ = allZ - dFZ_m(:);
            srcX = allX - dFX_m(:);
            srcY = allY - dFY_m(:);

            volW_perm = permute(ost2.volWarped, [2 3 1]);
            xi = 1:Sy2;  yi = 1:Sx2;  zi = 1:Sz2;
            volNL = interp3(xi, yi, zi, volW_perm, srcY, srcX, srcZ, 'linear', 0);
            volNL = reshape(volNL, [Sy2, Sx2, Sz2]);
            volNL = permute(volNL, [3 2 1]);

            ost2.volNL     = volNL;
            ost2.dispField = cat(4, dFZ_vol, dFX_vol, dFY_vol);
            ost2.nlAnchorSrc = allAnchSrc;
            ost2.nlAnchorDst = allAnchDst;
            ost2.regResult   = regResult;
            guidata(ofig, ost2);

            oSetShow(ofig,'nl');
            oSetStatus(ofig, sprintf( ...
                '✓  Surface registration done.  rms=%.2f vox  |  %d ICP correspondences + %d anchors (%d linear + %d user)', ...
                regResult.finalRMS, size(regResult.corrSrc,1), ...
                nLin + nUserAnch, nLin, nUserAnch));
        end

        % ── Slider / frame ────────────────────────────────────────────────
        function oSliderCB(ofig, hsl)
            oH2  = getappdata(oFig,'oHandles');
            ost2 = guidata(oFig);
            f    = clamp(round(get(hsl,'Value')),1,round(get(hsl,'Max')));
            ost2.frame = f;
            set(oH2.oFrmEdit,'String',num2str(f));
            guidata(oFig, ost2);
            oDrawAll(oFig);
        end

        function oFrameEditCB(ofig2, hedit)
            oH2  = getappdata(ofig2,'oHandles');
            ost2 = guidata(ofig2);
            f    = round(str2double(get(hedit,'String')));
            if isnan(f), f = 1; end
            f = clamp(f,1,round(get(oH2.oSld,'Max')));
            ost2.frame = f;
            set(oH2.oSld,'Value',f);
            set(oH2.oFrmEdit,'String',num2str(f));
            guidata(ofig2, ost2);
            oDrawAll(ofig2);
        end

        function oConfigSlider(ofig2, nf)
            oH2 = getappdata(ofig2,'oHandles');
            nf  = max(nf,1);
            step = ternary(nf>1, [1/(nf-1), min(10/(nf-1),1)], [1 1]);
            set(oH2.oSld,    'Min',1,'Max',max(nf,1+1e-9),'Value',1,'SliderStep',step);
            set(oH2.oFrmEdit,'String','1');
            set(oH2.oMaxLbl, 'String',sprintf('/ %d',nf));
        end

        % ── Draw ──────────────────────────────────────────────────────────
        function oDrawAll(ofig2)
            oH2   = getappdata(ofig2,'oHandles');
            ost2  = guidata(ofig2);
            alpha = get(oH2.oAlpha,'Value');
            f     = ost2.frame;
            plane = ost2.plane;

            % Pick volume to display
            switch ost2.showMode
                case 'raw'
                    vol1disp = ost2.volRaw1;   lbl1 = 'Raw Img1';
                case 'nl'
                    if isempty(ost2.volNL)
                        vol1disp = ost2.volWarped; lbl1 = 'Linear (NL not yet run)';
                    else
                        vol1disp = ost2.volNL;     lbl1 = 'NL Warped Img1';
                    end
                otherwise  % 'linear'
                    vol1disp = ost2.volWarped; lbl1 = 'Linear Img1';
            end

            nf2 = getNFrames(ost2.vol2, plane);
            nf1 = getNFrames(vol1disp,  plane);
            s2  = getSlice(ost2.vol2, clamp(f,1,nf2), plane);
            s1  = getSlice(vol1disp,  clamp(f,1,nf1), plane);
            s1  = normaliseSlice(s1);
            s2  = normaliseSlice(s2);

            r = max(size(s1,1),size(s2,1));
            c = max(size(s1,2),size(s2,2));
            s1p = padarray(s1,[r-size(s1,1), c-size(s1,2)],0,'post');
            s2p = padarray(s2,[r-size(s2,1), c-size(s2,2)],0,'post');

            a1 = 1-alpha*0.4;  a2 = alpha;
            both = s1p.*s2p;
            R  = clamp(s1p*a1 + both*0.6, 0, 1);
            G  = clamp(s2p*a2 + both*0.6, 0, 1);
            B  = clamp(s1p*a1 + both*0.6, 0, 1);
            RGB = cat(3, R, G, B);

            cla(oH2.oAx);
            hImg = image(oH2.oAx, RGB); %#ok<NASGU>
            axis(oH2.oAx,'image');
            set(oH2.oAx,'XColor','w','YColor','w');
            lbs = planeLabels(plane);
            xlabel(oH2.oAx,lbs{1},'Color','w');
            ylabel(oH2.oAx,lbs{2},'Color','w');

            D_str = '';
            if isfield(ost2.T,'ProcrustesD')
                D_str = sprintf('  Procrustes err=%.4f', ost2.T.ProcrustesD);
            end
            title(oH2.oAx, sprintf('%s (mag) vs Img2 (grn)  —  %s  fr %d/%d%s', ...
                lbl1, plane, f, max(nf1,nf2), D_str), ...
                'Color','w','FontSize',8,'FontWeight','normal');

            hold(oH2.oAx,'on');

            % ── Draw anchor points ─────────────────────────────────────
            nAnch = size(ost2.nlAnchors,1);
            for k = 1:nAnch
                anch3 = ost2.nlAnchors(k,:);
                di    = planeDepthIdx(plane);
                if abs(anch3(di)-f) <= 1
                    ad = clickToDisplay(anch3, plane);
                    plot(oH2.oAx, ad(1),ad(2),'d', ...
                        'Color',[0.1 1.0 0.5],'MarkerSize',12,'LineWidth',2);
                    text(oH2.oAx, ad(1)+6,ad(2)-6,sprintf('A%d',k), ...
                        'Color',[0.1 1.0 0.5],'FontSize',8,'FontWeight','bold');
                end
            end

            hold(oH2.oAx,'off');

            set(oH2.oStatusLbl,'String',sprintf( ...
                '%s (magenta)  vs  Img2 (green)  |  frame %d/%d  |  anchors: %d  |  %s', ...
                lbl1, f, max(nf1,nf2), nAnch, ...
                ternary(ost2.nlMode,'ANCHOR PICK MODE — click to add','Click "Pick Anchor Points" to add')));
        end

        % ── Helpers ───────────────────────────────────────────────────────
        function oUpdateNLCount(ofig)
            oH2  = getappdata(ofig,'oHandles');
            ost2 = guidata(ofig);
            nAnch = size(ost2.nlAnchors,1);
            nLin  = size(ost2.pts1,1);
            set(oH2.hNLCount,'String', ...
                sprintf('Anchors: %d  (+ %d from linear reg)', nAnch, nLin));
        end

        function oSetStatus(ofig, msg)
            oH2 = getappdata(ofig,'oHandles');
            set(oH2.oStatusLbl,'String',msg);
            drawnow;
        end

        function annotation_arrow(ax, p1, p2, col)
            % Draw a simple arrow from p1 to p2 on ax
            dx = p2(1)-p1(1);  dy = p2(2)-p1(2);
            if dx==0 && dy==0, return; end
            quiver(ax, p1(1),p1(2), dx,dy, 0, ...
                'Color',col,'LineWidth',1.5,'MaxHeadSize',0.5, ...
                'AutoScale','off');
        end

        function out = ternary(cond, a, b)
            if cond, out = a; else, out = b; end
        end

        % ── Surface-mesh phase: full pipeline launched from button ───────
        function oRunSurfacePicker(ofig)
            ost2 = guidata(ofig);
            oSetStatus(ofig,'Opening PDI surface picker on linearly-warped volume…');
            drawnow;

            % Hand the linear-warped volume to the picker.  pickSurfacePoints
            % blocks via uiwait and returns Nx3 points in [z x y] (vol2 coords)
            % or empty if cancelled.
            pts = pickSurfacePoints(ost2.volWarped, ost2.surfacePts);

            if isempty(pts)
                oSetStatus(ofig,'Surface picking cancelled — no mesh built.');
                return;
            end

            ost2.surfacePts = pts;
            guidata(ofig, ost2);

            oSetStatus(ofig, sprintf( ...
                'Building surface mesh from %d points (TPS smoothing fit)…', size(pts,1)));
            drawnow;

            try
                sMesh = buildSurfaceMeshLocal(pts);
            catch ME
                oSetStatus(ofig, ['✗  Mesh build failed: ' ME.message]);
                return;
            end

            ost2.surfaceMesh = sMesh;
            guidata(ofig, ost2);

            rmsR = sqrt(mean(sMesh.fit_residuals.^2));
            mxR  = max(abs(sMesh.fit_residuals));
            oSetStatus(ofig, sprintf( ...
                ['✓  Surface mesh built: %d verts, %d faces  |  ' ...
                 'residual rms %.2f vox (max %.2f)  |  opening overlay…'], ...
                size(sMesh.verts,1), size(sMesh.faces,1), rmsR, mxR));

            % Validation overlay (separate 3-D figure).
            showSurfaceMeshOverlay(ost2.volWarped, sMesh);
        end

        % ── Atlas target-mesh phase: segment atlas & extract top surface ─
        function oRunAtlasSurface(ofig)
            ost2 = guidata(ofig);

            if isempty(ost2.surfaceMesh)
                oSetStatus(ofig, '✗  Build the PDI source mesh first (previous button).');
                return;
            end

            oSetStatus(ofig, 'Segmenting atlas volume with source mesh plane…');
            drawnow;

            try
                atlasCrop = segmentAtlasWithPlane( ...
                    ost2.vol2, ost2.surfaceMesh);
            catch ME
                oSetStatus(ofig, ['✗  Atlas segmentation failed: ' ME.message]);
                return;
            end

            ost2.atlasCrop = atlasCrop;
            guidata(ofig, ost2);

            oSetStatus(ofig, sprintf( ...
                'Atlas segmented: %d voxels in cropped region. Building target surface mesh…', ...
                nnz(atlasCrop.final_mask)));
            drawnow;

            try
                tMesh = buildAtlasTargetMesh( ...
                    atlasCrop.brain_mask, ...
                    ost2.surfaceMesh.plane_point, ...
                    ost2.surfaceMesh.plane_normal, ...
                    atlasCrop.cut_signed_dist, ...
                    atlasCrop.xy_bbox);
            catch ME
                oSetStatus(ofig, ['✗  Target mesh build failed: ' ME.message]);
                return;
            end

            ost2.targetMesh = tMesh;
            guidata(ofig, ost2);

            oSetStatus(ofig, sprintf( ...
                '✓  Target mesh: %d verts, %d faces. Opening validation overlay…', ...
                size(tMesh.verts,1), size(tMesh.faces,1)));

            showAtlasSurfaceOverlay(ost2.vol2, atlasCrop, tMesh, ost2.surfaceMesh);
        end
    end

    %% ── Save / Load / Clear ───────────────────────────────────────────────
    function savePoints(fig)
        st = guidata(fig);
        Angio1pts = st.pts1;
        Angio2pts = st.pts2;
        [fn, pn] = uiputfile('pts2register.mat', 'Save points as');
        if isequal(fn,0), return; end
        save(fullfile(pn,fn), 'Angio1pts', 'Angio2pts');
        setStatus(fig, ['Points saved → ' fn]);
    end

    function loadPoints(fig)
        [fn, pn] = uigetfile('*.mat', 'Load points file');
        if isequal(fn,0), return; end
        tmp = load(fullfile(pn,fn));
        st  = guidata(fig);
        if isfield(tmp,'Angio1pts'), st.pts1 = tmp.Angio1pts; end
        if isfield(tmp,'Angio2pts'), st.pts2 = tmp.Angio2pts; end
        guidata(fig, st);
        updatePtCount(fig);
        drawAll(fig);
        setStatus(fig, ['Points loaded ← ' fn]);
    end

    function saveTransform(fig)
        st = guidata(fig);
        if isempty(st.Transform)
            setStatus(fig, '✗  No transform computed yet.  Run registration first.');
            return;
        end

        % ── Linear transform (always present) ─────────────────────────────
        Transform = st.Transform;            %#ok<NASGU>
        AffineMat = st.Transform.AffineMat; %#ok<NASGU>
        % AffineMat: 4×4, maps [z;x;y;1] in Image-1 → Image-2 space
        % Apply: dst = AffineMat * [z;x;y;1]

        % ── Nonlinear displacement field (present if surface reg was run) ──
        oFigs  = findobj('Name','Registration Overlay');
        hasNL  = false;
        DispField      = []; %#ok<NASGU>
        NLAnchors      = []; %#ok<NASGU>
        NLAnchorSrcPts = []; %#ok<NASGU>
        NLAnchorDstPts = []; %#ok<NASGU>

        if ~isempty(oFigs)
            ost = guidata(oFigs(1));
            if isfield(ost,'dispField') && ~isempty(ost.dispField)
                hasNL = true;
                DispField      = ost.dispField;      %#ok<NASGU>
                NLAnchors      = ost.nlAnchors;      %#ok<NASGU>  user zero-disp anchors
                NLAnchorSrcPts = ost.nlAnchorSrc;    %#ok<NASGU>  all anchor sources
                NLAnchorDstPts = ost.nlAnchorDst;    %#ok<NASGU>  all anchor dests
            end
        end

        [fn, pn] = uiputfile('Transformation.mat', 'Save transform as');
        if isequal(fn,0), return; end

        if hasNL
            save(fullfile(pn,fn), ...
                'Transform', 'AffineMat', ...
                'DispField', ...
                'NLAnchors', ...
                'NLAnchorSrcPts', 'NLAnchorDstPts');
            setStatus(fig, sprintf( ...
                'Saved → %s  [AffineMat(4×4) + DispField(Z×X×Y×3) + %d anchors]', ...
                fn, size(ost.nlAnchors,1)));
        else
            save(fullfile(pn,fn), 'Transform', 'AffineMat');
            setStatus(fig, sprintf( ...
                'Saved → %s  [AffineMat(4×4) only — run surface registration first to include DispField]', fn));
        end
    end

    function clearPoints(fig)
        answer = questdlg('Clear ALL points from both images?', ...
            'Confirm clear','Yes','No','No');
        if ~strcmp(answer,'Yes'), return; end
        st = guidata(fig);
        st.pts1 = zeros(0,3);
        st.pts2 = zeros(0,3);
        guidata(fig, st);
        updatePtCount(fig);
        drawAll(fig);
        setStatus(fig, 'All points cleared.');
    end

    %% ── Keyboard scrolling ────────────────────────────────────────────────
    function onKeyPress(~, evt)
        fig = hFig;
        st  = guidata(fig);
        H   = getappdata(fig,'handles');
        switch evt.Key
            case 'leftarrow'
                if isempty(st.vol1), return; end
                nf = getNFrames(st.vol1, st.plane1);
                st.frame1 = clamp(st.frame1 - 1, 1, nf);
                set(H.hSld1,'Value',st.frame1);
                set(H.hFrm1,'String',num2str(st.frame1));
                guidata(fig,st); drawAll(fig);
            case 'rightarrow'
                if isempty(st.vol1), return; end
                nf = getNFrames(st.vol1, st.plane1);
                st.frame1 = clamp(st.frame1 + 1, 1, nf);
                set(H.hSld1,'Value',st.frame1);
                set(H.hFrm1,'String',num2str(st.frame1));
                guidata(fig,st); drawAll(fig);
            case 'uparrow'
                if isempty(st.vol2), return; end
                nf = getNFrames(st.vol2, st.plane2);
                st.frame2 = clamp(st.frame2 + 1, 1, nf);
                set(H.hSld2,'Value',st.frame2);
                set(H.hFrm2,'String',num2str(st.frame2));
                guidata(fig,st); drawAll(fig);
            case 'downarrow'
                if isempty(st.vol2), return; end
                nf = getNFrames(st.vol2, st.plane2);
                st.frame2 = clamp(st.frame2 - 1, 1, nf);
                set(H.hSld2,'Value',st.frame2);
                set(H.hFrm2,'String',num2str(st.frame2));
                guidata(fig,st); drawAll(fig);
        end
    end

    function onClose(fig, ~)
        delete(fig);
    end

%% ════════════════════════════════════════════════════════════════════════════
%%  DRAWING
%% ════════════════════════════════════════════════════════════════════════════

    function drawAll(fig)
        H  = getappdata(fig,'handles');
        st = guidata(fig);

        % ── Image 1 ──────────────────────────────────────────────────────
        if ~isempty(st.vol1)
            img = getSlice(st.vol1, st.frame1, st.plane1);
            if get(H.hLog1,'Value')
                img = log1p(img);
            end
            clo = str2double(get(H.hMin1,'String'));
            chi = str2double(get(H.hMax1,'String'));
            if get(H.hLog1,'Value')
                clo = log1p(clo); chi = log1p(chi);
            end
            renderAxis(H.ax1, img, [clo chi], ...
                sprintf('Image 1  —  %s  frame %d / %d', ...
                    st.plane1, st.frame1, getNFrames(st.vol1,st.plane1)), ...
                planeLabels(st.plane1), ...
                @ax1Click, ...
                st.pts1, st.frame1, st.plane1, 'r');
        end

        % ── Image 2 ──────────────────────────────────────────────────────
        if ~isempty(st.vol2)
            img = getSlice(st.vol2, st.frame2, st.plane2);
            if get(H.hLog2,'Value')
                img = log1p(img);
            end
            clo = str2double(get(H.hMin2,'String'));
            chi = str2double(get(H.hMax2,'String'));
            if get(H.hLog2,'Value')
                clo = log1p(clo); chi = log1p(chi);
            end
            renderAxis(H.ax2, img, [clo chi], ...
                sprintf('Image 2  —  %s  frame %d / %d', ...
                    st.plane2, st.frame2, getNFrames(st.vol2,st.plane2)), ...
                planeLabels(st.plane2), ...
                @ax2Click, ...
                st.pts2, st.frame2, st.plane2, 'c');
        end
    end

    function renderAxis(ax, img, clim, ttl, lbls, clickFcn, pts, frame, plane, col)
        cla(ax);
        h = imagesc(ax, img, clim);
        colormap(ax, 'gray');
        axis(ax, 'image');
        set(ax, 'XColor','w','YColor','w');
        xlabel(ax, lbls{1}, 'Color','w');
        ylabel(ax, lbls{2}, 'Color','w');
        title(ax, ttl, 'Color','w','FontSize',9,'FontWeight','normal');
        set(h, 'ButtonDownFcn', clickFcn);

        if isempty(pts), return; end

        % Convert named colour → RGB so we can compute a dim version
        switch col
            case 'r', brightRGB = [1.00 0.35 0.35];  dimRGB = [0.50 0.15 0.15];
            case 'c', brightRGB = [0.20 1.00 1.00];  dimRGB = [0.10 0.45 0.45];
            case 'g', brightRGB = [0.30 1.00 0.30];  dimRGB = [0.10 0.40 0.10];
            otherwise, brightRGB = [1 1 0];           dimRGB = [0.45 0.45 0.10];
        end

        depthDim = planeDepthIdx(plane);   % which coord is the "depth" for this plane

        hold(ax,'on');
        for k = 1:size(pts,1)
            pt3   = pts(k,:);              % [z x y]
            pdsp  = clickToDisplay(pt3, plane);   % [col row] projected onto this plane
            depth = pt3(depthDim);         % depth coord of this point in this plane
            onSlice = (depth == frame);

            if onSlice
                % ── On the exact slice: full bright marker ─────────────
                plot(ax, pdsp(1),pdsp(2), '+', ...
                    'Color',brightRGB,'MarkerSize',14,'LineWidth',2);
                plot(ax, pdsp(1),pdsp(2), 'o', ...
                    'Color',brightRGB,'MarkerSize',8,'LineWidth',1.5);
                text(ax, pdsp(1)+5,pdsp(2)-5, num2str(k), ...
                    'Color',brightRGB,'FontSize',9,'FontWeight','bold');
            else
                % ── Off-slice: dim marker with depth label ─────────────
                % The projected position shows WHERE in this plane,
                % the label shows which depth the point lives on.
                plot(ax, pdsp(1),pdsp(2), '+', ...
                    'Color',dimRGB,'MarkerSize',8,'LineWidth',1);
                text(ax, pdsp(1)+3,pdsp(2)-3, ...
                    sprintf('%d[%d]', k, depth), ...
                    'Color',dimRGB,'FontSize',7);
            end
        end
        hold(ax,'off');
    end

%% ════════════════════════════════════════════════════════════════════════════
%%  HELPER FUNCTIONS
%% ════════════════════════════════════════════════════════════════════════════

    function nf = getNFrames(vol, plane)
        % How many frames to scroll through for this plane?
        % vol = [Z, X, Y]
        sz = size(vol);
        switch plane
            case 'XY',  nf = sz(1);   % scroll Z
            case 'XZ',  nf = sz(3);   % scroll Y
            case 'YZ',  nf = sz(2);   % scroll X
        end
    end

    function img = getSlice(vol, frame, plane)
        % Return 2-D slice.  vol = [Z, X, Y]
        switch plane
            case 'XY',  img = squeeze(vol(frame,:,:));   % [X  × Y]
            case 'XZ',  img = squeeze(vol(:,:,frame));   % [Z  × X]
            case 'YZ',  img = squeeze(vol(:,frame,:));   % [Z  × Y]
        end
    end

    function pt = clickToPoint(col, row, frame, plane, vol)
        % Map 2-D click + frame  →  3-D point [z, x, y]
        % imagesc convention: col = horizontal (x-axis), row = vertical (y-axis)
        sz = size(vol);  Sz=sz(1); Sx=sz(2); Sy=sz(3);
        switch plane
            case 'XY'   % display [X rows, Y cols],  frame = Z
                z=frame; x=row; y=col;
            case 'XZ'   % display [Z rows, X cols],  frame = Y
                z=row; x=col; y=frame;
            case 'YZ'   % display [Z rows, Y cols],  frame = X
                z=row; x=frame; y=col;
        end
        if z<1||z>Sz || x<1||x>Sx || y<1||y>Sy
            pt = [];
        else
            pt = [z, x, y];
        end
    end

    function [dpts, nums] = getPtsOnSlice(pts, frame, plane)
        % Return display (col, row) coordinates for points on current slice
        dpts = zeros(0,2);
        nums = [];
        if isempty(pts), return; end
        for k = 1:size(pts,1)
            z=pts(k,1); x=pts(k,2); y=pts(k,3);
            switch plane
                case 'XY'
                    if z == frame
                        dpts(end+1,:) = [y, x];  % col=Y, row=X
                        nums(end+1)   = k;
                    end
                case 'XZ'
                    if y == frame
                        dpts(end+1,:) = [x, z];  % col=X, row=Z
                        nums(end+1)   = k;
                    end
                case 'YZ'
                    if x == frame
                        dpts(end+1,:) = [y, z];  % col=Y, row=Z
                        nums(end+1)   = k;
                    end
            end
        end
    end

    function lbls = planeLabels(plane)
        % {xlabel, ylabel} for each plane
        switch plane
            case 'XY',  lbls = {'Y →','X ↓'};
            case 'XZ',  lbls = {'X →','Z ↓'};
            case 'YZ',  lbls = {'Y →','Z ↓'};
        end
    end

    function configSlider(hsl, hfrm, hlbl, vol, plane)
        nf = getNFrames(vol, plane);
        if nf > 1
            step = [1/(nf-1), min(10/(nf-1), 1)];
        else
            step = [1, 1];
        end
        set(hsl,  'Min',1,'Max',max(nf, 1+1e-9),'Value',1,'SliderStep',step);
        set(hfrm, 'String','1');
        set(hlbl, 'String',sprintf('/ %d', nf));
    end

    function updatePtCount(fig)
        H  = getappdata(fig,'handles');
        st = guidata(fig);
        set(H.hPtCount, 'String', sprintf('Points  Img1: %d   Img2: %d', ...
            size(st.pts1,1), size(st.pts2,1)));
    end

    function setStatus(fig, msg)
        H = getappdata(fig,'handles');
        set(H.hStatus, 'String', msg);
        drawnow;
    end

    function v = clamp(v, lo, hi)
        v = min(max(v, lo), hi);
    end

    function s = normaliseSlice(s)
        lo = min(s(:));  hi = max(s(:));
        if hi > lo
            s = (s - lo) / (hi - lo);
        else
            s = zeros(size(s));
        end
    end

    function ptdisp = clickToDisplay(pt, plane)
        % pt = [z x y],  returns [col row] for display
        if isempty(pt), ptdisp = []; return; end
        switch plane
            case 'XY',  ptdisp = [pt(3), pt(2)];   % col=Y, row=X
            case 'XZ',  ptdisp = [pt(2), pt(1)];   % col=X, row=Z
            case 'YZ',  ptdisp = [pt(3), pt(1)];   % col=Y, row=Z
        end
    end

    function idx = planeDepthIdx(plane)
        % Which coordinate of [z x y] is the "depth" (frame) for this plane?
        switch plane
            case 'XY',  idx = 1;   % Z
            case 'XZ',  idx = 3;   % Y
            case 'YZ',  idx = 2;   % X
        end
    end

end  % landmarkReg

%% ════════════════════════════════════════════════════════════════════════════
%%  SURFACE-MESH PHASE — local functions (file-scope, called by oRunSurfacePicker)
%% ════════════════════════════════════════════════════════════════════════════

% These three functions implement the surface-mesh phase.  They live as
% file-scope local functions (after landmarkReg's closing end) so they can
% be called from the nested oRunSurfacePicker without polluting landmarkReg's
% nested workspace, and so they each carry their own helpers without name
% clashes against landmarkReg's nested helpers.

%% =========================================================================
%%  pickSurfacePoints — popup window to click PDI surface points across
%%                      XY/XZ/YZ planes; same look as one panel of landmarkReg
%% =========================================================================
function pts = pickSurfacePoints(vol, initialPts)
% PICKSURFACEPOINTS  Open a single-volume picker window on the PDI volume,
% return Nx3 [z x y] surface points (or empty if cancelled).

if nargin < 2 || isempty(initialPts)
    initialPts = zeros(0,3);
end
if isempty(vol) || ndims(vol) ~= 3
    error('pickSurfacePoints: vol must be a non-empty 3D volume.');
end
vol = double(vol);
[Sz, ~, ~] = size(vol);

%% ── Figure ──────────────────────────────────────────────────────────────
hFig = figure( ...
    'Name','Phase 3 — Pick PDI Surface Points', ...
    'NumberTitle','off', ...
    'Position',[80 80 920 820], ...
    'Color',[0.11 0.11 0.11], ...
    'MenuBar','none','ToolBar','none', ...
    'KeyPressFcn',     @pkOnKey, ...
    'CloseRequestFcn', @(f,~) pkCancel(f));

%% ── State ───────────────────────────────────────────────────────────────
pst.vol     = vol;
pst.pts     = initialPts;
pst.plane   = 'XY';
pst.frame   = 1;
pst.addMode = true;
pst.cancel  = false;
guidata(hFig, pst);

BG  = [0.11 0.11 0.11];  BTN = [0.22 0.22 0.22];  TXT = [0.90 0.90 0.90];

%% ── Axes ────────────────────────────────────────────────────────────────
ax = axes('Parent',hFig,'Position',[0.06 0.22 0.90 0.72], ...
    'Color','k','XColor','w','YColor','w','FontSize',8);

%% ── Plane / contrast row ────────────────────────────────────────────────
yC = 145;
uicontrol('Style','text','String','Plane:', ...
    'Position',[10 yC+5 38 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',9);
hPop = uicontrol('Style','popupmenu','String',{'XY','XZ','YZ'}, ...
    'Position',[50 yC 60 24],'FontSize',9, ...
    'Callback',@(h,~) pkChangePlane(hFig,h));

vmin = min(vol(:));  vmax = max(vol(:));
uicontrol('Style','text','String','Min:', ...
    'Position',[120 yC+5 28 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',9);
hMin = uicontrol('Style','edit','String',sprintf('%.4g',vmin), ...
    'Position',[148 yC 60 24],'FontSize',9,'Callback',@(~,~) pkDraw(hFig));
uicontrol('Style','text','String','Max:', ...
    'Position',[214 yC+5 28 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',9);
hMax = uicontrol('Style','edit','String',sprintf('%.4g',vmax), ...
    'Position',[242 yC 60 24],'FontSize',9,'Callback',@(~,~) pkDraw(hFig));

uicontrol('Style','text','String','Log:', ...
    'Position',[310 yC+5 28 18],'BackgroundColor',BG,'ForegroundColor',TXT,'FontSize',9);
hLog = uicontrol('Style','checkbox','Value',0, ...
    'Position',[338 yC+6 18 18],'BackgroundColor',BG,'Callback',@(~,~) pkDraw(hFig));

%% ── Slider ──────────────────────────────────────────────────────────────
yS = 175;
hSld = uicontrol('Style','slider','Min',1,'Max',max(Sz,1+1e-6),'Value',1, ...
    'SliderStep',[1/max(Sz-1,1) min(10/max(Sz-1,1),1)], ...
    'Position',[10 yS 770 20],'BackgroundColor',BTN, ...
    'Callback',@(h,~) pkSlider(hFig,h));
hFrm = uicontrol('Style','edit','String','1', ...
    'Position',[786 yS-2 45 24],'FontSize',9, ...
    'Callback',@(h,~) pkFrameEdit(hFig,h));
hMaxLbl = uicontrol('Style','text','String',sprintf('/ %d',Sz), ...
    'Position',[834 yS+1 60 20],'BackgroundColor',BG,'ForegroundColor',TXT, ...
    'FontSize',9,'HorizontalAlignment','left');

%% ── Bottom controls ─────────────────────────────────────────────────────
yB = 105;
uicontrol('Style','pushbutton','String','Undo Last', ...
    'Position',[10 yB 85 28],'BackgroundColor',[0.55 0.18 0.18], ...
    'ForegroundColor','w','FontSize',9, ...
    'Callback',@(~,~) pkUndoLast(hFig));

hPtCount = uicontrol('Style','text','String',sprintf('Points: %d',size(initialPts,1)), ...
    'Position',[110 yB+6 100 20],'BackgroundColor',BG, ...
    'ForegroundColor',[1.0 0.80 0.20],'FontSize',10,'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol('Style','pushbutton','String','Save Pts', ...
    'Position',[220 yB 75 28],'BackgroundColor',BTN,'ForegroundColor',TXT, ...
    'FontSize',9,'Callback',@(~,~) pkSavePts(hFig));
uicontrol('Style','pushbutton','String','Load Pts', ...
    'Position',[300 yB 75 28],'BackgroundColor',BTN,'ForegroundColor',TXT, ...
    'FontSize',9,'Callback',@(~,~) pkLoadPts(hFig));
uicontrol('Style','pushbutton','String','Clear All', ...
    'Position',[380 yB 75 28],'BackgroundColor',[0.45 0.15 0.15], ...
    'ForegroundColor','w','FontSize',9,'Callback',@(~,~) pkClearPts(hFig));

uicontrol('Style','pushbutton','String','✓ DONE (build mesh)', ...
    'Position',[480 yB 175 32],'BackgroundColor',[0.15 0.42 0.22], ...
    'ForegroundColor','w','FontSize',10,'FontWeight','bold', ...
    'Callback',@(~,~) pkFinish(hFig));
uicontrol('Style','pushbutton','String','Cancel', ...
    'Position',[660 yB 80 32],'BackgroundColor',[0.45 0.20 0.20], ...
    'ForegroundColor','w','FontSize',9, ...
    'Callback',@(~,~) pkCancel(hFig));

uicontrol('Style','text', ...
    'String','← → arrows scroll slices.  Click image to add points.', ...
    'Position',[10 yB-22 500 18],'BackgroundColor',BG, ...
    'ForegroundColor',[0.55 0.55 0.55],'FontSize',8,'HorizontalAlignment','left');

hStatus = uicontrol('Style','text', ...
    'String','Click interior surface points across multiple slices and planes. Press DONE when finished.', ...
    'Position',[10 yB-46 890 22], ...
    'BackgroundColor',[0.08 0.08 0.08], ...
    'ForegroundColor',[0.60 0.90 0.60], ...
    'FontSize',9,'HorizontalAlignment','left');

H_.ax = ax;        H_.hSld = hSld;    H_.hFrm = hFrm;    H_.hMaxLbl = hMaxLbl;
H_.hPop = hPop;    H_.hMin = hMin;    H_.hMax = hMax;    H_.hLog = hLog;
H_.hPtCount = hPtCount; H_.hStatus = hStatus;
setappdata(hFig,'pkHandles',H_);

pkDraw(hFig);
uiwait(hFig);

if ~isvalid(hFig)
    pts = zeros(0,3);  return;
end
pst = guidata(hFig);
if pst.cancel
    pts = zeros(0,3);
else
    pts = pst.pts;
end
delete(hFig);

%% ── Nested callbacks ────────────────────────────────────────────────────

    function pkChangePlane(fig, hp)
        planes = {'XY','XZ','YZ'};
        pst_ = guidata(fig);  hH = getappdata(fig,'pkHandles');
        pst_.plane = planes{get(hp,'Value')};
        pst_.frame = 1;
        pkConfigSlider(hH.hSld, hH.hFrm, hH.hMaxLbl, pst_.vol, pst_.plane);
        guidata(fig, pst_);  pkDraw(fig);
    end

    function pkSlider(fig, hsl)
        pst_ = guidata(fig);  hH = getappdata(fig,'pkHandles');
        nf = pkGetNFrames(pst_.vol, pst_.plane);
        f = pkClamp(round(get(hsl,'Value')), 1, nf);
        pst_.frame = f;
        set(hH.hFrm,'String',num2str(f));
        guidata(fig, pst_);  pkDraw(fig);
    end

    function pkFrameEdit(fig, he)
        pst_ = guidata(fig);  hH = getappdata(fig,'pkHandles');
        f = round(str2double(get(he,'String')));
        if isnan(f), f = 1; end
        nf = pkGetNFrames(pst_.vol, pst_.plane);
        f = pkClamp(f, 1, nf);
        pst_.frame = f;
        set(hH.hSld,'Value',f);  set(hH.hFrm,'String',num2str(f));
        guidata(fig, pst_);  pkDraw(fig);
    end

    function pkUndoLast(fig)
        pst_ = guidata(fig);  hH = getappdata(fig,'pkHandles');
        if isempty(pst_.pts)
            pkStatus(fig, 'No points to undo.');
            return;
        end
        pst_.pts = pst_.pts(1:end-1,:);
        guidata(fig, pst_);
        set(hH.hPtCount,'String',sprintf('Points: %d',size(pst_.pts,1)));
        pkDraw(fig);
        pkStatus(fig, sprintf('Removed last point. %d remaining.', size(pst_.pts,1)));
    end

    function pkAxClick(~, ~)
        fig = hFig;
        pst_ = guidata(fig);  hH = getappdata(fig,'pkHandles');
        cp = get(hH.ax,'CurrentPoint');
        col = round(cp(1,1));  row = round(cp(1,2));
        pt = pkClickToPoint(col, row, pst_.frame, pst_.plane, pst_.vol);
        if isempty(pt), return; end
        pst_.pts = [pst_.pts; pt];
        guidata(fig, pst_);
        set(hH.hPtCount,'String',sprintf('Points: %d',size(pst_.pts,1)));
        pkDraw(fig);
        pkStatus(fig, sprintf('Added pt %d:  z=%d x=%d y=%d', ...
            size(pst_.pts,1), pt(1), pt(2), pt(3)));
    end

    function pkSavePts(fig)
        pst_ = guidata(fig);
        SurfacePts = pst_.pts; %#ok<NASGU>
        [fn,pn] = uiputfile('SurfacePts.mat','Save surface points as');
        if isequal(fn,0), return; end
        save(fullfile(pn,fn),'SurfacePts');
        pkStatus(fig, ['Saved → ' fn]);
    end

    function pkLoadPts(fig)
        [fn,pn] = uigetfile('*.mat','Load surface points');
        if isequal(fn,0), return; end
        tmp = load(fullfile(pn,fn));
        pst_ = guidata(fig);
        if isfield(tmp,'SurfacePts')
            pst_.pts = tmp.SurfacePts;
        else
            fns = fieldnames(tmp);  v = tmp.(fns{1});
            if size(v,2) == 3
                pst_.pts = v;
            else
                pkStatus(fig,'✗ File does not contain Nx3 points.'); return;
            end
        end
        guidata(fig, pst_);
        hH = getappdata(fig,'pkHandles');
        set(hH.hPtCount,'String',sprintf('Points: %d',size(pst_.pts,1)));
        pkDraw(fig);
        pkStatus(fig, sprintf('Loaded %d pts ← %s', size(pst_.pts,1), fn));
    end

    function pkClearPts(fig)
        ans2 = questdlg('Clear all points?','Confirm','Yes','No','No');
        if ~strcmp(ans2,'Yes'), return; end
        pst_ = guidata(fig);  pst_.pts = zeros(0,3);
        guidata(fig, pst_);
        hH = getappdata(fig,'pkHandles');
        set(hH.hPtCount,'String','Points: 0');
        pkDraw(fig);
    end

    function pkFinish(fig)
        pst_ = guidata(fig);
        if size(pst_.pts,1) < 4
            pkStatus(fig,'✗ Need at least 4 points to fit a surface.'); return;
        end
        guidata(fig, pst_);  uiresume(fig);
    end

    function pkCancel(fig)
        pst_ = guidata(fig);  pst_.cancel = true;
        guidata(fig, pst_);  uiresume(fig);
    end

    function pkOnKey(~, evt)
        fig = hFig;
        pst_ = guidata(fig);  hH = getappdata(fig,'pkHandles');
        nf = pkGetNFrames(pst_.vol, pst_.plane);
        switch evt.Key
            case 'leftarrow',  pst_.frame = pkClamp(pst_.frame - 1, 1, nf);
            case 'rightarrow', pst_.frame = pkClamp(pst_.frame + 1, 1, nf);
            otherwise, return;
        end
        set(hH.hSld,'Value',pst_.frame);  set(hH.hFrm,'String',num2str(pst_.frame));
        guidata(fig, pst_);  pkDraw(fig);
    end

    function pkDraw(fig)
        pst_ = guidata(fig);  hH = getappdata(fig,'pkHandles');
        img = pkGetSlice(pst_.vol, pst_.frame, pst_.plane);
        if get(hH.hLog,'Value'), img = log1p(img); end
        clo = str2double(get(hH.hMin,'String'));
        chi = str2double(get(hH.hMax,'String'));
        if get(hH.hLog,'Value'), clo = log1p(clo); chi = log1p(chi); end
        cla(hH.ax);
        h = imagesc(hH.ax, img, [clo chi]);
        colormap(hH.ax,'gray');  axis(hH.ax,'image');
        set(hH.ax,'XColor','w','YColor','w');
        lbs = pkPlaneLabels(pst_.plane);
        xlabel(hH.ax,lbs{1},'Color','w');  ylabel(hH.ax,lbs{2},'Color','w');
        title(hH.ax, sprintf('PDI (volWarped) — %s  frame %d / %d   |   total pts: %d', ...
            pst_.plane, pst_.frame, pkGetNFrames(pst_.vol,pst_.plane), size(pst_.pts,1)), ...
            'Color','w','FontSize',10,'FontWeight','normal');
        set(h,'ButtonDownFcn',@pkAxClick);

        if isempty(pst_.pts), return; end
        depthDim = pkPlaneDepthIdx(pst_.plane);
        bright = [1.0 0.85 0.30];  dim = [0.45 0.38 0.10];
        hold(hH.ax,'on');
        for k = 1:size(pst_.pts,1)
            pt3 = pst_.pts(k,:);
            pdsp = pkClickToDisplay(pt3, pst_.plane);
            if pt3(depthDim) == pst_.frame
                plot(hH.ax,pdsp(1),pdsp(2),'+', ...
                    'Color',bright,'MarkerSize',14,'LineWidth',2);
                plot(hH.ax,pdsp(1),pdsp(2),'o', ...
                    'Color',bright,'MarkerSize',8,'LineWidth',1.5);
                text(hH.ax,pdsp(1)+5,pdsp(2)-5,num2str(k), ...
                    'Color',bright,'FontSize',9,'FontWeight','bold');
            else
                plot(hH.ax,pdsp(1),pdsp(2),'+', ...
                    'Color',dim,'MarkerSize',8,'LineWidth',1);
                text(hH.ax,pdsp(1)+3,pdsp(2)-3, ...
                    sprintf('%d[%d]',k,pt3(depthDim)), ...
                    'Color',dim,'FontSize',7);
            end
        end
        hold(hH.ax,'off');
    end

    function pkStatus(fig, msg)
        hH = getappdata(fig,'pkHandles');
        set(hH.hStatus,'String',msg);  drawnow;
    end

end  % pickSurfacePoints

%% ── pk* helpers (file-scope, prefixed to avoid name clash) ──────────────

function nf = pkGetNFrames(vol, plane)
    sz = size(vol);
    switch plane, case 'XY', nf = sz(1); case 'XZ', nf = sz(3); case 'YZ', nf = sz(2); end
end

function img = pkGetSlice(vol, frame, plane)
    switch plane
        case 'XY', img = squeeze(vol(frame,:,:));
        case 'XZ', img = squeeze(vol(:,:,frame));
        case 'YZ', img = squeeze(vol(:,frame,:));
    end
end

function pt = pkClickToPoint(col, row, frame, plane, vol)
    sz = size(vol);  Sz=sz(1); Sx=sz(2); Sy=sz(3);
    switch plane
        case 'XY', z=frame; x=row;   y=col;
        case 'XZ', z=row;   x=col;   y=frame;
        case 'YZ', z=row;   x=frame; y=col;
    end
    if z<1||z>Sz || x<1||x>Sx || y<1||y>Sy
        pt = [];
    else
        pt = [z, x, y];
    end
end

function ptdisp = pkClickToDisplay(pt, plane)
    switch plane
        case 'XY', ptdisp = [pt(3), pt(2)];
        case 'XZ', ptdisp = [pt(2), pt(1)];
        case 'YZ', ptdisp = [pt(3), pt(1)];
    end
end

function idx = pkPlaneDepthIdx(plane)
    switch plane, case 'XY', idx = 1; case 'XZ', idx = 3; case 'YZ', idx = 2; end
end

function lbls = pkPlaneLabels(plane)
    switch plane
        case 'XY', lbls = {'Y →','X ↓'};
        case 'XZ', lbls = {'X →','Z ↓'};
        case 'YZ', lbls = {'Y →','Z ↓'};
    end
end

function pkConfigSlider(hsl, hfrm, hlbl, vol, plane)
    nf = pkGetNFrames(vol, plane);
    if nf > 1, step = [1/(nf-1), min(10/(nf-1),1)]; else, step = [1, 1]; end
    set(hsl, 'Min',1,'Max',max(nf,1+1e-9),'Value',1,'SliderStep',step);
    set(hfrm,'String','1');
    set(hlbl,'String',sprintf('/ %d',nf));
end

function v = pkClamp(v, lo, hi)
    v = min(max(v,lo),hi);
end

%% =========================================================================
%%  buildSurfaceMeshLocal — convex hull outline + tpaps smooth-average fit
%% =========================================================================
function mesh = buildSurfaceMeshLocal(pts)
% BUILDSURFACEMESHLOCAL  Fit a smooth open surface through interior 3D points.
%
%   1. Best-fit plane via SVD → local (u,v,w) frame
%   2. Convex hull of (u,v) projections defines the outline
%   3. tpaps smoothing thin-plate spline fits  w = f(u,v)
%   4. Sample on a (u,v) grid clipped to the hull, transform back to world
%   5. Triangulate the grid

if size(pts,2) ~= 3
    error('buildSurfaceMeshLocal: pts must be Nx3.');
end
pts = double(pts);

% Dedup (tpaps cannot handle duplicates)
[pts_u, ~, ~] = unique(pts,'rows','stable');
if size(pts_u,1) < size(pts,1)
    warning('buildSurfaceMeshLocal: removed %d duplicate points.', ...
        size(pts,1)-size(pts_u,1));
    pts = pts_u;
end
if size(pts,1) < 4
    error('buildSurfaceMeshLocal: need at least 4 unique points (got %d).', size(pts,1));
end

%% ── Best-fit plane via SVD ──────────────────────────────────────────────
c  = mean(pts,1);
Xc = pts - c;
[~,~,V] = svd(Xc,'econ');
u_axis = V(:,1)';  u_axis = u_axis/norm(u_axis);
v_axis = V(:,2)';  v_axis = v_axis/norm(v_axis);
n_axis = V(:,3)';  n_axis = n_axis/norm(n_axis);
if dot(cross(u_axis,v_axis), n_axis) < 0
    v_axis = -v_axis;
end

%% ── Project to local (u,v,w) ────────────────────────────────────────────
uvw = Xc * [u_axis(:), v_axis(:), n_axis(:)];
u = uvw(:,1);  v = uvw(:,2);  w = uvw(:,3);

%% ── Convex hull → lateral outline ───────────────────────────────────────
try
    K = convhull(u, v);
catch ME
    error(['buildSurfaceMeshLocal: convhull failed (%s). ' ...
        'Points may be collinear in the best-fit plane.'], ME.message);
end
hull_uv = [u(K), v(K)];

%% ── Smoothing TPS  w = f(u,v) ───────────────────────────────────────────
[st_tps, p_used] = tpaps([u'; v'], w');

%% ── Sample (u,v) grid clipped to the hull ──────────────────────────────
gridStep = 1.0;
umin = min(hull_uv(:,1));  umax = max(hull_uv(:,1));
vmin = min(hull_uv(:,2));  vmax = max(hull_uv(:,2));
ug = umin:gridStep:umax;
vg = vmin:gridStep:vmax;
if numel(ug) < 2 || numel(vg) < 2
    error(['buildSurfaceMeshLocal: grid too small (%d x %d). ' ...
        'Pick more spread-out points.'], numel(ug), numel(vg));
end
[Ug,Vg] = meshgrid(ug,vg);
inside = inpolygon(Ug,Vg,hull_uv(:,1),hull_uv(:,2));

Wg = nan(size(Ug));
if any(inside(:))
    Wg(inside) = fnval(st_tps,[Ug(inside)'; Vg(inside)']);
end

%% ── Triangulate (only quads with all 4 corners valid) ──────────────────
[ny,nx] = size(Ug);
keep = inside & isfinite(Wg);
idxMap = nan(ny,nx);
idxMap(keep) = (1:nnz(keep))';

u_v = Ug(keep);  v_v = Vg(keep);  w_v = Wg(keep);
verts_world = c + u_v(:).*u_axis + v_v(:).*v_axis + w_v(:).*n_axis;

[J,I] = ndgrid(1:ny-1, 1:nx-1);
v1 = idxMap(sub2ind([ny nx], J(:),     I(:)));
v2 = idxMap(sub2ind([ny nx], J(:),     I(:)+1));
v3 = idxMap(sub2ind([ny nx], J(:)+1,   I(:)));
v4 = idxMap(sub2ind([ny nx], J(:)+1,   I(:)+1));
valid = isfinite(v1)&isfinite(v2)&isfinite(v3)&isfinite(v4);
v1 = v1(valid); v2 = v2(valid); v3 = v3(valid); v4 = v4(valid);
faces = [v1 v2 v3; v2 v4 v3];

%% ── Per-input residuals (signed distance from fitted surface) ──────────
w_fit = fnval(st_tps,[u'; v'])';
fit_residuals = w - w_fit;

%% ── Pack ───────────────────────────────────────────────────────────────
mesh = struct();
mesh.verts          = verts_world;
mesh.faces          = faces;
mesh.plane_point    = c;
mesh.plane_normal   = n_axis;
mesh.plane_u        = u_axis;
mesh.plane_v        = v_axis;
mesh.uv_hull        = hull_uv;
mesh.input_pts      = pts;
mesh.fit_residuals  = fit_residuals;
mesh.smoothness     = p_used;
mesh.grid_step      = gridStep;

end  % buildSurfaceMeshLocal

%% =========================================================================
%%  showSurfaceMeshOverlay — 3D figure showing PDI vol + fitted surface
%% =========================================================================
function showSurfaceMeshOverlay(vol, mesh)

vol = double(vol);

pos = vol(vol > 0);
if isempty(pos), thr = max(vol(:)) - eps; else, thr = quantile(pos,0.95); end
maxPts = 20000;

fig = figure( ...
    'Name','Phase 5 — Surface Mesh Overlay (validation)', ...
    'Color','w','Position',[100 100 1100 880],'NumberTitle','off');
ax = axes(fig);  hold(ax,'on');

% ── PDI scatter ─────────────────────────────────────────────────────────
mask = vol >= thr;
idx = find(mask);
if numel(idx) > maxPts
    idx = idx(round(linspace(1,numel(idx),maxPts)));
end
[zv,xv,yv] = ind2sub(size(vol),idx);
scatter3(ax, xv, yv, zv, 4, vol(idx), 'filled', ...
    'MarkerFaceAlpha',0.10,'MarkerEdgeAlpha',0.10);
colormap(ax,gray);

% ── Fitted surface (verts are [z x y]; trisurf wants X,Y,Z) ────────────
if ~isempty(mesh.faces)
    trisurf(mesh.faces, ...
        mesh.verts(:,2), mesh.verts(:,3), mesh.verts(:,1), ...
        'Parent',ax,'FaceColor',[1.0 0.45 0.45], ...
        'EdgeColor','none','FaceAlpha',0.55);
end

% ── Best-fit plane patch ───────────────────────────────────────────────
if isfield(mesh,'plane_point')
    c = mesh.plane_point;
    if isfield(mesh,'uv_hull') && ~isempty(mesh.uv_hull)
        rng_u = max(abs(mesh.uv_hull(:,1)));
        rng_v = max(abs(mesh.uv_hull(:,2)));
    else
        rng_u = 30; rng_v = 30;
    end
    s = 1.15;
    [Sg,Tg] = meshgrid([-s*rng_u, s*rng_u],[-s*rng_v, s*rng_v]);
    Pz = c(1) + Sg*mesh.plane_u(1) + Tg*mesh.plane_v(1);
    Px = c(2) + Sg*mesh.plane_u(2) + Tg*mesh.plane_v(2);
    Py = c(3) + Sg*mesh.plane_u(3) + Tg*mesh.plane_v(3);
    surf(ax,Px,Py,Pz, ...
        'FaceColor',[0.30 0.75 0.30],'EdgeColor','none','FaceAlpha',0.12);
end

% ── Convex hull outline on the plane ────────────────────────────────────
if isfield(mesh,'uv_hull') && ~isempty(mesh.uv_hull)
    hu = mesh.uv_hull(:,1);  hv = mesh.uv_hull(:,2);
    c = mesh.plane_point;
    hz = c(1) + hu*mesh.plane_u(1) + hv*mesh.plane_v(1);
    hx = c(2) + hu*mesh.plane_u(2) + hv*mesh.plane_v(2);
    hy = c(3) + hu*mesh.plane_u(3) + hv*mesh.plane_v(3);
    plot3(ax,hx,hy,hz,'-','Color',[0.25 0.65 0.25],'LineWidth',1.5);
end

% ── Input clicks + residual stems ──────────────────────────────────────
if isfield(mesh,'input_pts') && ~isempty(mesh.input_pts)
    p = mesh.input_pts;
    scatter3(ax,p(:,2),p(:,3),p(:,1),90, ...
        [0.10 0.85 0.95],'filled', ...
        'MarkerEdgeColor','k','LineWidth',0.8);
    if isfield(mesh,'fit_residuals')
        for k = 1:size(p,1)
            p_proj = p(k,:) - mesh.fit_residuals(k) * mesh.plane_normal;
            plot3(ax, ...
                [p(k,2) p_proj(2)], [p(k,3) p_proj(3)], [p(k,1) p_proj(1)], ...
                '-','Color',[0.10 0.85 0.95 0.6],'LineWidth',0.8);
        end
    end
end

axis(ax,'equal');  grid(ax,'on');
xlabel(ax,'X');  ylabel(ax,'Y');  zlabel(ax,'Z');
set(ax,'ZDir','reverse');
view(ax,3);
camlight(ax,'headlight');  lighting(ax,'gouraud');

if isfield(mesh,'fit_residuals') && ~isempty(mesh.fit_residuals)
    rms = sqrt(mean(mesh.fit_residuals.^2));
    mxr = max(abs(mesh.fit_residuals));
    title(ax, sprintf( ...
        'PDI vol (gray) + fit (red) + plane (green) + clicked pts (cyan)   |   %d pts, %d faces   |   residual rms %.2f vox (max %.2f)', ...
        size(mesh.input_pts,1), size(mesh.faces,1), rms, mxr), ...
        'FontSize',9);
else
    title(ax, sprintf('Surface mesh overlay   |   %d faces',size(mesh.faces,1)), ...
        'FontSize',9);
end

end  % showSurfaceMeshOverlay

%% =========================================================================
%%  segmentAtlasWithPlane — split atlas using source mesh plane, crop
%% =========================================================================
function atlasCrop = segmentAtlasWithPlane(atlasVol, sourceMesh)
% SEGMENTATLASWITHPLANE  Crop the atlas volume to the relevant hemisphere
% using the source mesh's best-fit plane.
%
% Updated only in the atlas-mask step:
%   1. Build a real brain mask from atlas intensities
%   2. Split by signed distance around the plane
%   3. Pick the smaller half
%   4. Pick the nearest connected component to the source mesh centroid
%   5. Apply the same XY bounding-box crop as before

planeOffset = 3;     % voxels: dead-zone width on each side of the plane
xyMargin    = 25;    % voxels: padding around source mesh bbox

c = sourceMesh.plane_point(:)';    % [z, x, y]
n = sourceMesh.plane_normal(:)';   % [z, x, y]
nNorm = norm(n);
if nNorm == 0
    error('segmentAtlasWithPlane: source mesh plane normal has zero norm.');
end
n = n / nNorm;

[Sz, Sx, Sy] = size(atlasVol);

% ── Real atlas brain mask (replace atlasVol > 0) ────────────────────────
atlasVolN = double(atlasVol);
atlasVolN = atlasVolN - min(atlasVolN(:));
mx = max(atlasVolN(:));
if mx > 0
    atlasVolN = atlasVolN ./ mx;
end

t = max(graythresh(atlasVolN), 0.05);
atlasMask = atlasVolN > t;

atlasMask = imopen(atlasMask, strel('sphere', 1));
atlasMask = imclose(atlasMask, strel('sphere', 2));

for z = 1:Sz
    atlasMask(z,:,:) = imfill(squeeze(atlasMask(z,:,:)), 'holes');
end
for x = 1:Sx
    atlasMask(:,x,:) = imfill(squeeze(atlasMask(:,x,:)), 'holes');
end
for y = 1:Sy
    atlasMask(:,:,y) = imfill(squeeze(atlasMask(:,:,y)), 'holes');
end

cc0 = bwconncomp(atlasMask, 6);
if cc0.NumObjects == 0
    error('segmentAtlasWithPlane: atlas mask is empty after thresholding.');
end
numPix0 = cellfun(@numel, cc0.PixelIdxList);
[~, idx0] = max(numPix0);
atlasMaskLargest = false(size(atlasMask));
atlasMaskLargest(cc0.PixelIdxList{idx0}) = true;
atlasMask = atlasMaskLargest;

[Zg, Xg, Yg] = ndgrid(1:Sz, 1:Sx, 1:Sy);

signedDist = n(1)*(Zg - c(1)) + n(2)*(Xg - c(2)) + n(3)*(Yg - c(3));

halfA = atlasMask & (signedDist >=  planeOffset);
halfB = atlasMask & (signedDist <= -planeOffset);

nA = nnz(halfA);  nB = nnz(halfB);

if nA == 0 && nB == 0
    error('segmentAtlasWithPlane: plane split removed the entire atlas. Adjust planeOffset.');
elseif nA == 0
    chosenHalf = halfB;  cutSignedDist = -planeOffset;
elseif nB == 0
    chosenHalf = halfA;  cutSignedDist =  planeOffset;
elseif nA <= nB
    chosenHalf = halfA;  cutSignedDist =  planeOffset;
else
    chosenHalf = halfB;  cutSignedDist = -planeOffset;
end

fprintf('segmentAtlasWithPlane: threshold=%.4f  halfA=%d  halfB=%d  → chose %s (cut at sd=%.1f)\n', ...
    t, nA, nB, ternary_str(cutSignedDist>0,'halfA','halfB'), cutSignedDist);

cc = bwconncomp(chosenHalf, 6);
if cc.NumObjects == 0
    error('segmentAtlasWithPlane: chosen half has no connected components.');
end

sourceCentroid = mean(sourceMesh.verts, 1);
bestIdx = 1;  bestDist = inf;
for k = 1:cc.NumObjects
    idx = cc.PixelIdxList{k};
    [zv, xv, yv] = ind2sub([Sz, Sx, Sy], idx);
    compCentroid = [mean(zv), mean(xv), mean(yv)];
    d = norm(compCentroid - sourceCentroid);
    if d < bestDist
        bestDist = d;  bestIdx = k;
    end
end

componentMask = false(size(chosenHalf));
componentMask(cc.PixelIdxList{bestIdx}) = true;

fprintf('segmentAtlasWithPlane: %d components, picked #%d (dist=%.1f, %d voxels)\n', ...
    cc.NumObjects, bestIdx, bestDist, nnz(componentMask));

xmin = max(1,  floor(min(sourceMesh.verts(:,2)) - xyMargin));
xmax = min(Sx, ceil( max(sourceMesh.verts(:,2)) + xyMargin));
ymin = max(1,  floor(min(sourceMesh.verts(:,3)) - xyMargin));
ymax = min(Sy, ceil( max(sourceMesh.verts(:,3)) + xyMargin));

xyMask = false(size(componentMask));
xyMask(:, xmin:xmax, ymin:ymax) = true;

finalMask = componentMask & xyMask;
if ~any(finalMask(:))
    warning('segmentAtlasWithPlane: XY crop removed all voxels. Using component without crop.');
    finalMask = componentMask;
end

fprintf('segmentAtlasWithPlane: final mask %d voxels  (xy bbox X=[%d %d] Y=[%d %d])\n', ...
    nnz(finalMask), xmin, xmax, ymin, ymax);

atlasCrop = struct();
atlasCrop.half_mask       = chosenHalf;
atlasCrop.component_mask  = componentMask;
atlasCrop.final_mask      = finalMask;
atlasCrop.xy_bbox         = [xmin xmax; ymin ymax];
atlasCrop.source_centroid = sourceCentroid;
atlasCrop.cut_signed_dist = cutSignedDist;
atlasCrop.plane_point     = c;
atlasCrop.plane_normal    = n;
atlasCrop.plane_offset    = planeOffset; 
atlasCrop.brain_mask      = atlasMask;

    function s = ternary_str(cond, a, b)
        if cond, s = a; else, s = b; end
    end

end  % segmentAtlasWithPlane

function mesh = buildAtlasTargetMesh(brainMask, planePoint, planeNormal, cutSignedDist, xyBbox)
% BUILDATLASTARGETMESH  Isosurface the full brain mask, cut with the source
% mesh plane, and clip to the XY footprint.  The plane cut produces a
% natural open edge rather than a closed surface.

if ~islogical(brainMask)
    brainMask = logical(brainMask);
end
if ~any(brainMask(:))
    error('buildAtlasTargetMesh: input mask is empty.');
end

planeNormal = planeNormal(:).';
nrm = norm(planeNormal);
if nrm == 0, error('buildAtlasTargetMesh: plane normal has zero norm.'); end
planeNormal = planeNormal / nrm;
planePoint  = planePoint(:).';

[Sz, Sx, Sy] = size(brainMask);
[Zg, Xg, Yg] = ndgrid(1:Sz, 1:Sx, 1:Sy);

% ── Full brain isosurface ────────────────────────────────────────────────
fv = isosurface(Xg, Yg, Zg, double(brainMask), 0.5);
if isempty(fv.vertices) || isempty(fv.faces)
    error('buildAtlasTargetMesh: isosurface produced no faces.');
end

% isosurface returns [X Y Z] columns when called with ndgrid args
% convert back to [Z X Y] convention
verts = [fv.vertices(:,3), fv.vertices(:,1), fv.vertices(:,2)];
faces = fv.faces;
nFacesBefore = size(faces,1);

% ── Cut with plane ───────────────────────────────────────────────────────
% Keep faces on the same side as cutSignedDist (same logic as volume cut).
% Use face centroids for the signed distance test.
fc = (verts(faces(:,1),:) + verts(faces(:,2),:) + verts(faces(:,3),:)) / 3;
fcSd = sum(bsxfun(@minus, fc, planePoint) .* planeNormal, 2);

sideSign   = sign(cutSignedDist);
if sideSign == 0, sideSign = 1; end
trimMargin = 3;   % voxels inside the plane to avoid jagged cut edge

keepPlane      = (sideSign * fcSd) >= trimMargin;
nPlaneTrimmed  = nnz(~keepPlane);
faces          = faces(keepPlane, :);

if isempty(faces)
    error('buildAtlasTargetMesh: plane cut removed all faces.');
end

% ── XY bbox clip ─────────────────────────────────────────────────────────
fc2 = (verts(faces(:,1),:) + verts(faces(:,2),:) + verts(faces(:,3),:)) / 3;
xmin = xyBbox(1,1);  xmax = xyBbox(1,2);
ymin = xyBbox(2,1);  ymax = xyBbox(2,2);

insideBbox   = fc2(:,2) >= xmin & fc2(:,2) <= xmax & ...
               fc2(:,3) >= ymin & fc2(:,3) <= ymax;
nBboxTrimmed = nnz(~insideBbox);
faces        = faces(insideBbox, :);

if isempty(faces)
    error('buildAtlasTargetMesh: XY crop removed all faces.');
end

% ── Reindex to used vertices only ────────────────────────────────────────
usedVerts = unique(faces(:));
newIdx    = zeros(size(verts,1), 1);
newIdx(usedVerts) = (1:numel(usedVerts))';
verts = verts(usedVerts, :);
faces = newIdx(faces);

fprintf(['buildAtlasTargetMesh: %d total faces -> %d plane-trimmed, ' ...
         '%d bbox-clipped -> %d faces remain (%d verts)\n'], ...
         nFacesBefore, nPlaneTrimmed, nBboxTrimmed, size(faces,1), size(verts,1));

mesh = struct();
mesh.verts              = verts;
mesh.faces              = faces;
mesh.trimmed_face_count = nPlaneTrimmed + nBboxTrimmed;

end  % buildAtlasTargetMesh

%% =========================================================================
%%  showAtlasSurfaceOverlay — 3D validation of atlas segmentation + target mesh
%% =========================================================================
function showAtlasSurfaceOverlay(atlasVol, atlasCrop, targetMesh, sourceMesh)

fig = figure( ...
    'Name','Phase 4 — Atlas Segmentation & Target Mesh (validation)', ...
    'Color','w','Position',[120 80 1100 880],'NumberTitle','off');
ax = axes(fig);  hold(ax,'on');

mask = atlasCrop.final_mask;
idx  = find(mask);
maxPts = 20000;
if numel(idx) > maxPts
    idx = idx(round(linspace(1, numel(idx), maxPts)));
end
[zv, xv, yv] = ind2sub(size(mask), idx);
scatter3(ax, xv, yv, zv, 4, [0.5 0.7 1.0], 'filled', ...
    'MarkerFaceAlpha', 0.06, 'MarkerEdgeAlpha', 0.06);

if ~isempty(targetMesh.faces)
    trisurf(targetMesh.faces, ...
        targetMesh.verts(:,2), targetMesh.verts(:,3), targetMesh.verts(:,1), ...
        'Parent', ax, ...
        'FaceColor', [0.3 0.7 1.0], ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.60);
end

if ~isempty(sourceMesh) && isfield(sourceMesh,'faces') && ~isempty(sourceMesh.faces)
    trisurf(sourceMesh.faces, ...
        sourceMesh.verts(:,2), sourceMesh.verts(:,3), sourceMesh.verts(:,1), ...
        'Parent', ax, ...
        'FaceColor', [1.0 0.45 0.45], ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.40);
end

c = atlasCrop.plane_point;
n = atlasCrop.plane_normal;
u = null(n(:).');
if size(u, 2) >= 2
    u1 = u(:,1)';  u2 = u(:,2)';
    if ~isempty(sourceMesh) && isfield(sourceMesh,'verts') && ~isempty(sourceMesh.verts)
        scl = max(range(sourceMesh.verts, 1)) * 0.8;
    else
        scl = 40;
    end
    if scl <= 0, scl = 40; end
    [Sg, Tg] = meshgrid([-scl scl], [-scl scl]);
    Pz = c(1) + Sg*u1(1) + Tg*u2(1);
    Px = c(2) + Sg*u1(2) + Tg*u2(2);
    Py = c(3) + Sg*u1(3) + Tg*u2(3);
    surf(ax, Px, Py, Pz, ...
        'FaceColor', [0.2 0.8 0.2], 'EdgeColor', 'none', 'FaceAlpha', 0.12);
end

axis(ax, 'equal');  grid(ax, 'on');
xlabel(ax, 'X');  ylabel(ax, 'Y');  zlabel(ax, 'Z');
set(ax, 'ZDir', 'reverse');
view(ax, 3);
camlight(ax, 'headlight');  lighting(ax, 'gouraud');

title(ax, sprintf( ...
    ['Atlas (blue scatter) + target mesh (blue, %d faces) + ' ...
     'source mesh (red) + cut plane (green)  |  %d cut faces trimmed'], ...
    size(targetMesh.faces,1), targetMesh.trimmed_face_count), ...
    'FontSize', 9);

end  % showAtlasSurfaceOverlay

%% =========================================================================
%%  registerSurfaceMeshes — ICP + normal-only 3D RBF surface registration
%% =========================================================================
function result = registerSurfaceMeshes(sourceMesh, targetMesh, anchSrc, anchDst)

nICP         = 15;
outlierPct   = 90;
anchorWeight = 5;
lambda       = 1e-3;
maxCtrlFinal = 1200;

srcVerts = double(sourceMesh.verts);
tgtVerts = double(targetMesh.verts);
anchSrc  = double(anchSrc);
anchDst  = double(anchDst);

if isempty(anchSrc), anchSrc = zeros(0,3); end
if isempty(anchDst), anchDst = zeros(0,3); end

if size(srcVerts,2) ~= 3, error('sourceMesh.verts must be Nx3'); end
if size(tgtVerts,2) ~= 3, error('targetMesh.verts must be Nx3'); end
if size(anchSrc,2)  ~= 3, error('anchSrc must be Kx3'); end
if size(anchDst,2)  ~= 3, error('anchDst must be Kx3'); end
if size(anchSrc,1)  ~= size(anchDst,1)
    error('anchSrc and anchDst must have the same number of points');
end

nSrc = size(srcVerts,1);

fprintf('registerSurfaceMeshes: %d source verts, %d target verts, %d anchors\n', ...
    nSrc, size(tgtVerts,1), size(anchSrc,1));

currentSrc = srcVerts;

for iter = 1:nICP

    [idxNN, distNN] = knnsearch(tgtVerts, currentSrc);

    distThresh = prctile(distNN, outlierPct);
    keep = distNN <= distThresh;

    corrSrc = currentSrc(keep, :);
    corrDst = tgtVerts(idxNN(keep), :);

    if isempty(corrSrc) && isempty(anchSrc)
        error('No correspondences survived outlier rejection and no anchors provided.');
    end

    % Raw point-to-point displacements — no projection, no normal constraint
    dispCorr = corrDst - corrSrc;

    anchSrcRep = repmat(anchSrc, anchorWeight, 1);
    dispAnch   = repmat(anchDst - anchSrc, anchorWeight, 1);

    allSrc  = [corrSrc;  anchSrcRep];
    dispAll = [dispCorr; dispAnch];

    tpsZ = tpaps3(allSrc', dispAll(:,1)', lambda);
    tpsX = tpaps3(allSrc', dispAll(:,2)', lambda);
    tpsY = tpaps3(allSrc', dispAll(:,3)', lambda);

    dz = evalRBF3(tpsZ, currentSrc')';
    dx = evalRBF3(tpsX, currentSrc')';
    dy = evalRBF3(tpsY, currentSrc')';

    currentSrc = currentSrc + [dz dx dy];

    rms = sqrt(mean(distNN(keep).^2));
    fprintf('  ICP iter %2d: %d/%d pairs kept (thresh=%.3f), rms=%.3f vox\n', ...
        iter, nnz(keep), nSrc, distThresh, rms);
end

[idxFinal, distFinal] = knnsearch(tgtVerts, currentSrc);
distThreshFinal = prctile(distFinal, outlierPct);
keepFinal = distFinal <= distThreshFinal;
finalRMS  = sqrt(mean(distFinal(keepFinal).^2));

fprintf('registerSurfaceMeshes: final rms=%.3f vox (%d/%d pairs)\n', ...
    finalRMS, nnz(keepFinal), nSrc);

corrSrcFinal = currentSrc(keepFinal, :);
corrDstFinal = tgtVerts(idxFinal(keepFinal), :);

dispCorrFinal = corrDstFinal - srcVerts(keepFinal,:);
dispAnchFinal = repmat(anchDst - anchSrc, anchorWeight, 1);

allSrcFinal = [srcVerts(keepFinal,:); repmat(anchSrc, anchorWeight, 1)];
dispFinal   = [dispCorrFinal;         dispAnchFinal];

if size(allSrcFinal,1) > maxCtrlFinal
    idxKeep     = unique(round(linspace(1, size(allSrcFinal,1), maxCtrlFinal)));
    allSrcFinal = allSrcFinal(idxKeep,:);
    dispFinal   = dispFinal(idxKeep,:);
end

tpsZfinal = tpaps3(allSrcFinal', dispFinal(:,1)', lambda);
tpsXfinal = tpaps3(allSrcFinal', dispFinal(:,2)', lambda);
tpsYfinal = tpaps3(allSrcFinal', dispFinal(:,3)', lambda);

dzFinal = evalRBF3(tpsZfinal, srcVerts')';
dxFinal = evalRBF3(tpsXfinal, srcVerts')';
dyFinal = evalRBF3(tpsYfinal, srcVerts')';

deformedVerts = srcVerts + [dzFinal dxFinal dyFinal];

result = struct();
result.tpsZ          = tpsZfinal;
result.tpsX          = tpsXfinal;
result.tpsY          = tpsYfinal;
result.corrSrc       = corrSrcFinal;
result.corrDst       = corrDstFinal;
result.finalRMS      = finalRMS;
result.deformedVerts = deformedVerts;
result.nIterations   = nICP;

end  % registerSurfaceMeshes


function normals = estimateSurfaceNormals(mesh)
    nVerts  = size(mesh.verts, 1);
    normals = zeros(nVerts, 3);

    v1 = mesh.verts(mesh.faces(:,1), :);
    v2 = mesh.verts(mesh.faces(:,2), :);
    v3 = mesh.verts(mesh.faces(:,3), :);
    faceNormals = cross(v2 - v1, v3 - v1, 2);

    for f = 1:size(mesh.faces,1)
        normals(mesh.faces(f,1), :) = normals(mesh.faces(f,1), :) + faceNormals(f,:);
        normals(mesh.faces(f,2), :) = normals(mesh.faces(f,2), :) + faceNormals(f,:);
        normals(mesh.faces(f,3), :) = normals(mesh.faces(f,3), :) + faceNormals(f,:);
    end

    norms = sqrt(sum(normals.^2, 2));
    norms(norms == 0) = 1;
    normals = normals ./ norms;
end  % estimateSurfaceNormals


function tps = tpaps3(coords, values, lambda)
    X = double(coords');
    y = double(values(:));
    N = size(X,1);

    if numel(y) ~= N
        error('tpaps3: number of values must match number of sites');
    end

    D = pdist2(X, X);
    K = D;
    P = [ones(N,1), X];

    L   = [K + lambda*eye(N), P; P', zeros(4,4)];
    rhs = [y; zeros(4,1)];

    params = L \ rhs;

    tps      = struct();
    tps.ctrl = X;
    tps.W    = params(1:N);
    tps.A    = params(N+1:end);
end  % tpaps3


function out = evalRBF3(tps, pts)
    if size(pts,1) ~= 3
        error('evalRBF3: expects points as 3xM');
    end

    Q = double(pts');
    M = size(Q,1);
    outVec = zeros(M,1);
    chunkSize = 10000;

    for i1 = 1:chunkSize:M
        i2 = min(i1 + chunkSize - 1, M);
        Qi = Q(i1:i2,:);
        D  = pdist2(Qi, tps.ctrl);
        K  = D;
        P  = [ones(size(Qi,1),1), Qi];
        outVec(i1:i2) = K * tps.W + P * tps.A;
    end

    out = outVec.';
end  % evalRBF3