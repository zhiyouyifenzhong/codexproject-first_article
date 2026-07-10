function clean_figure_outputs(rootFolder)
%CLEAN_FIGURE_OUTPUTS Delete old PNG/FIG outputs under the figure root.
%
%   clean_figure_outputs('figures')

    if nargin < 1 || isempty(rootFolder)
        rootFolder = 'figures';
    end

    if ~exist(rootFolder, 'dir')
        mkdir(rootFolder);
        fprintf('Created figure folder: %s\n', rootFolder);
        return
    end

    oldPng = dir(fullfile(rootFolder, '**', '*.png'));
    oldFig = dir(fullfile(rootFolder, '**', '*.fig'));
    oldFiles = [oldPng; oldFig];

    for k = 1:numel(oldFiles)
        delete(fullfile(oldFiles(k).folder, oldFiles(k).name));
    end

    fprintf('Deleted %d old PNG/FIG files under %s\n', numel(oldFiles), rootFolder);
end
