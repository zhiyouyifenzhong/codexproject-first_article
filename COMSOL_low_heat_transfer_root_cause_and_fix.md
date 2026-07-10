# Why the COMSOL SST CFD effective heat-transfer coefficient remains too low

## 1. Key observation

The corrected Sharan 50 m SST CFD run still gives:

```text
h_eq ≈ 2.3-2.4 W/(m2 K)
```

For the same Sharan parameters:

```text
D = 0.1 m
Vdot = 0.0863 m3/s
u_mean ≈ 10.99 m/s
Re ≈ 6.7e4
h_Gnielinski ≈ 34.5 W/(m2 K)
```

So the CFD effective heat transfer is still about one order of magnitude too low.

Changing from area-mean outlet temperature to mass-flow weighted outlet temperature did not solve the problem. Therefore, the main problem is not outlet averaging.

## 2. Most likely root cause

The current COMSOL model is probably solving the velocity field with SST turbulence, but the heat-transfer equation is not receiving the corresponding turbulent thermal diffusivity or thermal wall function correctly.

In practice, that means:

```text
flow turbulence exists,
but thermal transport behaves close to molecular-conduction-only heat transfer near the wall.
```

This explains why the global h is around 2 W/(m2 K). That value is consistent with heat having to cross a comparatively thick near-wall numerical layer using only air molecular conductivity, instead of using turbulent wall heat transfer.

## 3. Evidence from the current script

### 3.1 Nonisothermal coupling is created through fragile try/catch logic

In `comsol_eahe_airgap_model.m`:

```matlab
nitf = comp.multiphysics.create('nitf1', 'NonIsothermalFlow', 'geom1');
nitf.set('Fluid_physics', flowTag);
nitf.set('Heat_physics', 'ht');
try_set_any(nitf, {'ThermalTurbType'}, 'KaysCrawford');
try_set_any(nitf, {'ThermalWallFunction'}, 'Standard');
try_set_any(nitf, {'Prt'}, 'Pr_turb');
```

If a COMSOL API property name is wrong, `try_set_any` silently fails. The model may still solve, but without the intended turbulent heat transfer model. This should not be allowed for validation runs.

### 3.2 Boundary-layer mesh settings are not actually used in mapped mesh mode

The Sharan corrected config sets:

```matlab
cfg.cfd_boundary_layer_layers = 16;
cfg.cfd_first_layer_thickness = 5.0e-5;
```

But when:

```matlab
cfg.use_mapped_mesh = true;
```

the code goes to `add_mapped_mesh`, where these boundary-layer settings are never used. The air radial mesh is only controlled by:

```matlab
cfg.cfd_air_radial_elems = 40;
```

For a radius of 0.05 m, that gives a uniform radial spacing of about:

```text
dr ≈ 0.00125 m
```

This is too coarse for low-Re resolved SST thermal boundary layers and not explicitly configured as a wall-function mesh either.

### 3.3 Velocity variable ambiguity is still present

During the corrected run, COMSOL warned:

```text
spf.v undefined
```

The fallback likely found another velocity variable, probably `w`, but this confirms that the script is still guessing velocity variable names. For a validation-grade CFD model, the axial velocity variable must be explicitly confirmed in the COMSOL model.

### 3.4 The model has not passed a constant-wall-temperature pipe benchmark

Before comparing with Sharan soil experiments, the CFD model must reproduce a simple turbulent pipe heat-transfer benchmark. That has not yet been done.

Without this benchmark, a conjugate soil-pipe-air model can hide air-side errors behind soil and transient effects.

## 4. Is the COMSOL turbulence model itself wrong?

Probably not in the sense of “COMSOL SST is broken.”

The more likely issue is:

```text
the LiveLink-created model does not configure SST + heat transfer coupling
and near-wall thermal treatment correctly.
```

COMSOL's SST model can predict turbulent pipe heat transfer if:

- the wall treatment is appropriate,
- y+ is in the valid range,
- turbulent thermal diffusivity is active,
- heat transfer and turbulent flow are coupled correctly,
- outlet temperature is mass-flow weighted,
- wall heat flux is integrated correctly.

The current scripted model does not yet prove these conditions.

## 5. Required improvements

### 5.1 Stop silent failures in turbulence heat coupling

For Sharan validation, replace silent `try_set_any` with hard checks. If these properties cannot be set, stop the run:

```matlab
assert_set(nitf, 'Fluid_physics', flowTag)
assert_set(nitf, 'Heat_physics', 'ht')
assert_one_of_set(nitf, {'ThermalTurbType', ...}, 'KaysCrawford')
assert_one_of_set(nitf, {'ThermalWallFunction', ...}, 'Standard')
assert_one_of_set(nitf, {'Prt', ...}, 'Pr_turb')
```

The model should not continue if the thermal turbulence model is not confirmed.

### 5.2 Build a constant-wall-temperature turbulent pipe benchmark

Before any soil model:

1. Air domain only.
2. Same Sharan pipe radius and flow rate.
3. SST turbulence.
4. Wall temperature fixed, e.g. `Tw = 26.6 C`.
5. Inlet temperature fixed or time-table.
6. Export:
   - mass-flow weighted outlet temperature,
   - wall heat-flux integral,
   - `h_CFD`,
   - `Nu_CFD`,
   - y+.

Acceptance:

```text
h_CFD / h_Gnielinski = 0.7-1.3
Q_air and Q_wall closure error < 5-10%
```

If this benchmark still gives `h ≈ 2`, the air-side thermal turbulence setup is definitely wrong.

### 5.3 Use a real boundary-layer mesh or a valid wall-function mesh

Current mapped mesh does not apply `cfd_first_layer_thickness`.

Two acceptable options:

Option A: low-Re resolved SST

```text
y+ ≈ 1
first layer thickness ≈ 3e-5 to 5e-5 m
15-25 boundary layers
growth rate 1.15-1.25
```

Option B: wall-function mode

```text
30 < y+ < 100
thermal wall function explicitly active
```

Do not leave the model in an unknown intermediate state.

### 5.4 Use integration operators for mass-flow weighted temperatures

Instead of radial sampling fallback, create outlet and 25 m cross-section integration operators and compute:

```text
Tbulk = int_A(rho*cp*w*T*2*pi*r dA) / int_A(rho*cp*w*2*pi*r dA)
```

In the current COMSOL 2D axisymmetric model, logs indicate `w` is more likely the axial velocity than `v`.

### 5.5 Use COMSOL heat-flux variables for wall heat flux

Do not infer wall heat flux from two nearby point temperatures. Use COMSOL's boundary heat-flux variable or a boundary integration of normal conductive heat flux on the inner pipe wall.

Required closure:

```text
Q_air = mdot*cp*(Tin_bulk - Tout_bulk)
Q_wall = int_inner_wall(q'' dA)
```

For steady wall-temperature benchmark:

```text
Q_air ≈ Q_wall
```

For transient conjugate soil model:

```text
Q_air ≈ Q_wall + air storage
```

## 6. Recommended implementation path

1. Create `run_comsol_sharan_pipe_h_benchmark.m`.
2. Build only the air pipe, with constant wall temperature.
3. Verify `h_CFD` against Gnielinski.
4. Only after that passes, return to pipe-wall-soil conjugate geometry.
5. Then run Sharan May and January cases.
6. Report:
   - benchmark h validation,
   - energy closure,
   - Sharan T25/Tout comparison,
   - `.mph` files.

## 7. Bottom line

The persistent low effective heat-transfer coefficient is not evidence that COMSOL's SST turbulence model is inherently wrong. It is evidence that the current scripted COMSOL model has not correctly configured or verified the turbulent thermal coupling and near-wall heat-transfer treatment.

The next meaningful correction is not another soil-coupled Sharan run. The next correction must be a constant-wall-temperature turbulent pipe benchmark that proves the COMSOL model can reproduce `h ≈ 34.5 W/(m2 K)` under Sharan flow conditions.
