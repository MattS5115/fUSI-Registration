%% Extract PDI_allBlocks_avg_rs from prereg file and save as its own .mat
% Loads prereg_PDI_params_50um.mat and extracts PDI_allBlocks_avg_rs
% into a standalone .mat file for easier access.

%% Select and load the prereg file
[prereg_FilePathFN, prereg_FilePath] = uigetfile('*.mat', ...
    'Select the prereg file (prereg_PDI_params_50um.mat)');

if isequal(prereg_FilePathFN, 0)
    error('No file selected. Exiting.')
end

prereg_FilePath = [prereg_FilePath, prereg_FilePathFN];

fprintf('Loading: %s\n', prereg_FilePath)
load(prereg_FilePath)

%% Check that the expected variables exist
if ~exist('PDI_allBlocks_avg_rs', 'var')
    error('PDI_allBlocks_avg_rs not found in the selected file.')
end
fprintf('PDI_allBlocks_avg_rs loaded. Size: [%s]\n', num2str(size(PDI_allBlocks_avg_rs)))

if ~exist('prereg_params', 'var')
    warning('prereg_params not found in the selected file. Saving without it.')
end

%% Select output directory and save
save_dirpath = uigetdir(prereg_FilePath, 'Select the save directory for the .mat file');

if isequal(save_dirpath, 0)
    error('No save directory selected. Exiting.')
end

save_filepath = fullfile(save_dirpath, 'PDI_allBlocks_avg_rs.mat');

fprintf('Saving to: %s\n', save_filepath)
if exist('prereg_params', 'var')
    save(save_filepath, 'PDI_allBlocks_avg_rs', 'prereg_params', '-v7.3')
else
    save(save_filepath, 'PDI_allBlocks_avg_rs', '-v7.3')
end
fprintf('Done.\n')
%% 
%% 
PDI = PDI_allBlocks_avg_rs;

lo = prctile(PDI(:), 0.1);
hi = prctile(PDI(:), 99.9);
PDI_display = mat2gray(PDI, [lo, hi]);

%% Save the processed/display PDI as its own .mat file
[save_file, save_path] = uiputfile('PDI_display.mat', ...
    'Save processed PDI as');

if isequal(save_file, 0)
    warning('User canceled save. Skipping save step.');
else
    save(fullfile(save_path, save_file), 'PDI_display', '-v7.3');
    fprintf('Saved processed PDI to: %s\n', fullfile(save_path, save_file));
end

%% View volume
volumeViewer(PDI_display);