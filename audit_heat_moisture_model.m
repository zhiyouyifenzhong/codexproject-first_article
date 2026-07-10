% Audit checks for the heat-moisture coupled EAHE model.
% This script uses small grids and short runs to catch obvious logic errors.

clear; clc; close all;

common = struct();
common.t_end = 6 * 3600;
common.dt = 600;
common.Nx_pipe = 4;
common.Ntheta = 4;
common.Nr = 3;
common.snapshot_times = [0, 6] * 3600;
common.Tin_mode = 'constant';
common.Tin_const = 38.0;
common.T_air_mean = 17.0;
common.T_deep = 17.0;
common.T_air_amp_year = 0.0;
common.T_air_amp_day = 0.0;
common.m_dot = 154 / 3600 * 1.20;

fprintf('Audit 1: latent heat switch...\n');
offCase = run_eahe_simulation(struct_merge(common, struct( ...
    'moisture_model', 'diffusion', ...
    'include_latent_heat', false, ...
    'theta_soil', 0.20 * ones(1, 3), ...
    'theta_ref', 0.20 * ones(1, 3))));
onCase = run_eahe_simulation(struct_merge(common, struct( ...
    'moisture_model', 'diffusion', ...
    'include_latent_heat', true, ...
    'theta_soil', 0.20 * ones(1, 3), ...
    'theta_ref', 0.20 * ones(1, 3))));
assert_no_nan(onCase, 'latent-on case');
assert_theta_bounds(onCase);
check_moisture_storage(onCase, 1.0e-8);
maxToutDiff = max(abs(onCase.Tout - offCase.Tout));
fprintf('  max |Tout_latent_on - Tout_latent_off| = %.4f K\n', maxToutDiff);
if maxToutDiff > 10
    warning('Latent heat effect is very large for the audit case. Check D_theta_v and D_T_v.');
end

fprintf('Audit 2: Liu 60/30 operation duty cycle...\n');
modeCase = run_eahe_simulation(struct_merge(common, struct( ...
    'moisture_model', 'diffusion', ...
    'include_latent_heat', true, ...
    'operation_mode', 'liu_60_30', ...
    'theta_soil', 0.20 * ones(1, 3), ...
    'theta_ref', 0.20 * ones(1, 3))));
operatingFraction = mean(modeCase.is_operating);
fprintf('  operating fraction = %.3f\n', operatingFraction);
if abs(operatingFraction - 2/3) > 0.08
    warning('Unexpected operating fraction for liu_60_30 mode.');
end
assert(all(abs(modeCase.Q(~modeCase.is_operating)) < 1.0e-9), ...
    'Heat transfer rate should be zero during off periods.');

fprintf('Audit 3: moisture-dependent thermal property trend...\n');
dryCase = run_eahe_simulation(struct_merge(common, struct( ...
    'moisture_model', 'property_only', ...
    'theta_soil', 0.10 * ones(1, 3), ...
    'theta_ref', 0.20 * ones(1, 3))));
wetCase = run_eahe_simulation(struct_merge(common, struct( ...
    'moisture_model', 'property_only', ...
    'theta_soil', 0.30 * ones(1, 3), ...
    'theta_ref', 0.20 * ones(1, 3))));
lastDry = mean(dryCase.Tout(end-2:end));
lastWet = mean(wetCase.Tout(end-2:end));
fprintf('  dry last outlet mean = %.3f degC\n', lastDry);
fprintf('  wet last outlet mean = %.3f degC\n', lastWet);
if lastWet >= lastDry
    warning('Wet-soil outlet temperature is not lower than dry-soil outlet temperature.');
end

fprintf('\nHeat-moisture audit complete.\n');

function assert_no_nan(result, name)
    fields = {'Tout', 'Q', 'Tsoil_near_mid_mean', 'theta_near_mid_mean'};
    for k = 1:numel(fields)
        value = result.(fields{k});
        assert(all(isfinite(value)), 'Non-finite value found in %s: %s', name, fields{k});
    end
end

function assert_theta_bounds(result)
    p = result.param;
    theta = result.X_final((p.nThermalState + 1):p.nState);
    assert(all(theta >= p.theta_min - 1.0e-12), 'Water content below theta_min.');
    assert(all(theta <= p.theta_max + 1.0e-12), 'Water content above theta_max.');
end

function check_moisture_storage(result, tol)
    p = result.param;
    if ~p.use_moisture_state || isempty(result.snapshots.X)
        return
    end
    theta0 = result.snapshots.X((p.nThermalState + 1):p.nState, 1);
    theta1 = result.X_final((p.nThermalState + 1):p.nState);
    volume = moisture_node_volumes(result);
    storage0 = sum(theta0 .* volume);
    storage1 = sum(theta1 .* volume);
    relErr = abs(storage1 - storage0) / max(abs(storage0), eps);
    fprintf('  moisture storage relative error = %.3e\n', relErr);
    if relErr > tol
        warning('Moisture storage is not conserved in the closed near-soil domain.');
    end
end

function volume = moisture_node_volumes(result)
    p = result.param;
    g = result.geom;
    volume = zeros(p.nMoistNode, 1);
    id = 0;
    for i = 1:p.Nx_pipe
        for m = 1:p.Ntheta
            for r = 1:p.Nr
                id = id + 1;
                rin = g.r_edges(r);
                rout = g.r_edges(r+1);
                volume(id) = 0.5 * (rout^2 - rin^2) * p.dtheta * p.dx_pipe;
            end
        end
    end
end

function out = struct_merge(a, b)
    out = a;
    names = fieldnames(b);
    for k = 1:numel(names)
        out.(names{k}) = b.(names{k});
    end
end
