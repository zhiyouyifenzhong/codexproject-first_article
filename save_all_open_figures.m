function save_all_open_figures(outputFolder, prefix, clearExisting)
%SAVE_ALL_OPEN_FIGURES Save all open MATLAB figures as PNG and FIG files.
%
%   save_all_open_figures('figures', 'baseline')
%   save_all_open_figures('figures', 'baseline', false)

    if nargin < 1 || isempty(outputFolder)
        outputFolder = 'figures';
    end
    if nargin < 2 || isempty(prefix)
        prefix = 'figure';
    end
    if nargin < 3
        clearExisting = true;
    end

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    elseif clearExisting
        delete_existing_figure_files(outputFolder);
    end

    figs = findall(0, 'Type', 'figure');
    figs = flipud(figs);

    for i = 1:numel(figs)
        fig = figs(i);
        name = get(fig, 'Name');
        if isempty(name)
            name = sprintf('%s_%02d', prefix, i);
        else
            name = sprintf('%s_%02d_%s', prefix, i, name);
        end
        name = regexprep(name, '[^\w\-\s]', '');
        name = regexprep(strtrim(name), '\s+', '_');

        pngPath = fullfile(outputFolder, [name, '.png']);
        figPath = fullfile(outputFolder, [name, '.fig']);

        try
            exportgraphics(fig, pngPath, 'Resolution', 300);
        catch
            saveas(fig, pngPath);
        end
        savefig(fig, figPath);
    end

    fprintf('Saved %d figures to %s\n', numel(figs), outputFolder);
end

function delete_existing_figure_files(outputFolder)
    oldPng = dir(fullfile(outputFolder, '*.png'));
    oldFig = dir(fullfile(outputFolder, '*.fig'));
    oldFiles = [oldPng; oldFig];
    for k = 1:numel(oldFiles)
        delete(fullfile(oldFiles(k).folder, oldFiles(k).name));
    end
    if ~isempty(oldFiles)
        fprintf('Deleted %d old figure files from %s\n', numel(oldFiles), outputFolder);
    end
end
