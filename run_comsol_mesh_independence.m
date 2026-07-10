%RUN_COMSOL_MESH_INDEPENDENCE Mesh independence check for COMSOL EAHE model.
%
% Requires an active COMSOL LiveLink server connection. The script runs three
% mapped-mesh levels for delta = 0.5 mm in short_test mode and summarizes the
% outlet-temperature differences against the finest mesh.

clear; clc;

baseOutput = 'COMSOL_EAHE_mesh_independence';
if ~exist(baseOutput, 'dir')
    mkdir(baseOutput);
end

cases = struct([]);
cases(1).name = 'coarse';
cases(1).mesh_axial_max = 1.00;
cases(1).mesh_air_radial_elems = 4;
cases(1).mesh_pipe_radial_elems = 3;
cases(1).mesh_gap_radial_elems_min = 3;
cases(1).mesh_soil_radial_elems = 24;

cases(2).name = 'default';
cases(2).mesh_axial_max = 0.50;
cases(2).mesh_air_radial_elems = 6;
cases(2).mesh_pipe_radial_elems = 5;
cases(2).mesh_gap_radial_elems_min = 5;
cases(2).mesh_soil_radial_elems = 36;

cases(3).name = 'fine';
cases(3).mesh_axial_max = 0.25;
cases(3).mesh_air_radial_elems = 8;
cases(3).mesh_pipe_radial_elems = 7;
cases(3).mesh_gap_radial_elems_min = 7;
cases(3).mesh_soil_radial_elems = 54;

for i = 1:numel(cases)
    outDir = fullfile(baseOutput, cases(i).name);
    fprintf('\nRunning mesh case: %s\n', cases(i).name);
    comsol_eahe_airgap_model(struct( ...
        'output_dir', outDir, ...
        'model_type', 'both', ...
        'delta_mm_list', 0.5, ...
        'study_mode', 'short_test', ...
        'run_solver', true, ...
        'save_mph', false, ...
        'mesh_axial_max', cases(i).mesh_axial_max, ...
        'mesh_air_radial_elems', cases(i).mesh_air_radial_elems, ...
        'mesh_pipe_radial_elems', cases(i).mesh_pipe_radial_elems, ...
        'mesh_gap_radial_elems_min', cases(i).mesh_gap_radial_elems_min, ...
        'mesh_soil_radial_elems', cases(i).mesh_soil_radial_elems));

    postprocess_comsol_eahe(struct('output_dir', outDir));
end

summary = build_mesh_summary(baseOutput, cases);
writetable(summary, fullfile(baseOutput, 'COMSOL_mesh_independence_summary.csv'));
disp(summary);

function summary = build_mesh_summary(baseOutput, cases)
    refDir = fullfile(baseOutput, cases(end).name);
    refTout = readtable(fullfile(refDir, 'COMSOL_Tout_delta_sweep.csv'), ...
        'VariableNamingRule', 'preserve');
    refPerf = readtable(fullfile(refDir, 'COMSOL_performance_summary.csv'), ...
        'VariableNamingRule', 'preserve');

    summary = table();
    for i = 1:numel(cases)
        outDir = fullfile(baseOutput, cases(i).name);
        tout = readtable(fullfile(outDir, 'COMSOL_Tout_delta_sweep.csv'), ...
            'VariableNamingRule', 'preserve');
        perf = readtable(fullfile(outDir, 'COMSOL_performance_summary.csv'), ...
            'VariableNamingRule', 'preserve');

        for modelType = ["explicit", "resistance"]
            col = sprintf('Tout_%s_delta_0p5mm_C', modelType);
            y = interp1(tout.t_day, tout.(col), refTout.t_day, 'linear');
            diff = y - refTout.(col);

            fullModelType = modelType + "_gap";
            p = perf(string(perf.model_type) == fullModelType & perf.delta_mm == 0.5, :);
            pref = refPerf(string(refPerf.model_type) == fullModelType & refPerf.delta_mm == 0.5, :);
            relEabs = 100 * (p.Eabs_kWh(1) - pref.Eabs_kWh(1)) / pref.Eabs_kWh(1);

            row = table(string(cases(i).name), fullModelType, ...
                cases(i).mesh_axial_max, cases(i).mesh_air_radial_elems, ...
                cases(i).mesh_pipe_radial_elems, cases(i).mesh_gap_radial_elems_min, ...
                cases(i).mesh_soil_radial_elems, ...
                sqrt(mean(diff.^2, 'omitnan')), mean(abs(diff), 'omitnan'), ...
                max(abs(diff), [], 'omitnan'), p.Eabs_kWh(1), relEabs, ...
                'VariableNames', {'mesh_case','model_type','mesh_axial_max_m', ...
                'air_radial_elems','pipe_radial_elems','gap_radial_elems_min', ...
                'soil_radial_elems','Tout_RMSE_vs_fine_C','Tout_MAE_vs_fine_C', ...
                'Tout_MaxAbs_vs_fine_C','Eabs_kWh','Eabs_rel_error_vs_fine_percent'});
            summary = [summary; row]; %#ok<AGROW>
        end
    end
end
