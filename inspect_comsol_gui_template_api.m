%% inspect_comsol_gui_template_api.m
% Inspect physics feature tags and Java class/type hints from the GUI template.

function inspect_comsol_gui_template_api()
    templatePath = fullfile(pwd, 'COMSOL_GUI_templates', 'Sharan_pipe_GUI_template.mph');
    outDir = fullfile(pwd, 'COMSOL_GUI_template_Sharan_pipe_results');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    addpath('G:\COMSOL\COMSOL63\Multiphysics\mli');
    try
        mphstart('localhost', 2036);
    catch ME
        if ~contains(ME.message, 'Already connected', 'IgnoreCase', true)
            rethrow(ME);
        end
    end

    model = mphload(templatePath);
    comp = model.component('comp1');
    physicsTags = java_string_array_to_cell(comp.physics.tags);
    rows = table();
    for i = 1:numel(physicsTags)
        tag = physicsTags{i};
        ph = comp.physics(tag);
        label = string(safe_call_string(@() ph.label));
        typeHint = string(safe_call_string(@() ph.getType));
        javaClass = string(class(ph));
        rows = [rows; table(string(tag), label, typeHint, javaClass, ...
            'VariableNames', {'tag','label','type_hint','java_class'})]; %#ok<AGROW>

        featureRows = inspect_feature_list(ph, tag);
        if ~isempty(featureRows)
            writetable(featureRows, fullfile(outDir, sprintf('GUI_template_physics_%s_features.csv', tag)));
        end
    end
    writetable(rows, fullfile(outDir, 'GUI_template_physics_api_probe.csv'));
    disp(rows);
end

function rows = inspect_feature_list(ph, physicsTag)
    rows = table();
    try
        featureTags = java_string_array_to_cell(ph.feature.tags);
    catch
        return
    end
    for j = 1:numel(featureTags)
        ftag = featureTags{j};
        feat = ph.feature(ftag);
        rows = [rows; table(string(physicsTag), string(ftag), ...
            string(safe_call_string(@() feat.label)), ...
            string(safe_call_string(@() feat.getType)), ...
            string(class(feat)), ...
            'VariableNames', {'physics_tag','feature_tag','label','type_hint','java_class'})]; %#ok<AGROW>
    end
end

function c = java_string_array_to_cell(a)
    c = cell(numel(a), 1);
    for k = 1:numel(a)
        c{k} = char(a(k));
    end
end

function s = safe_call_string(fn)
    try
        v = fn();
        s = char(v);
    catch ME
        s = ['<failed: ' ME.message '>'];
    end
end
