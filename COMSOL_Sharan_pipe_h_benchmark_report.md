# COMSOL Sharan Pipe Turbulent Heat-Transfer Benchmark Report

## Purpose

This benchmark isolates the air-side turbulent heat transfer from the full
50 m EAHE soil-coupled model. It uses the Sharan pipe geometry and flow rate
with a constant wall temperature. The benchmark is intentionally simple:

- 2D axisymmetric air domain only
- Length: 50 m
- Inner radius: 0.05 m
- Flow rate: 0.0863 m3/s
- Inlet air temperature: 39.6 degC
- Wall temperature: 26.6 degC
- SST turbulent flow interface
- Heat-transfer coefficient inferred from the mass-flow weighted outlet
  temperature:

```text
Tout = Twall + (Tin - Twall) exp(-h P L / (mdot cp))
```

The expected turbulent-pipe reference is the Gnielinski correlation.

## Generated Files

Native COMSOL nonisothermal coupling benchmark:

```text
COMSOL_Sharan_pipe_h_benchmark/
  Sharan_pipe_h_benchmark_summary.csv
  Sharan_pipe_h_benchmark_axial_profile.csv
  Sharan_pipe_h_benchmark_mesh_yplus.csv
  Sharan_pipe_h_benchmark_variable_probe.csv
  Sharan_pipe_h_benchmark_radial_variable_profile.csv
  Sharan_pipe_h_benchmark_solved_20260706_164759.mph
```

Explicit k-omega thermal-diffusivity benchmark:

```text
COMSOL_Sharan_pipe_h_benchmark_explicit_keff/
  Sharan_pipe_h_benchmark_summary.csv
  Sharan_pipe_h_benchmark_axial_profile.csv
  Sharan_pipe_h_benchmark_mesh_yplus.csv
  Sharan_pipe_h_benchmark_solved_20260706_170816.mph
```

The MATLAB scripts are:

```text
run_comsol_sharan_pipe_h_benchmark.m
diagnose_sharan_pipe_benchmark_variables.m
```

## Reference Values

For the Sharan parameters:

```text
Re = 6.7103e4
Pr = 0.7158
u_mean = 10.988 m/s
mdot = 0.0975 kg/s
h_Gnielinski = 34.50 W/(m2 K)
Nu_Gnielinski = 132.69
Tout_Gnielinski = 26.65 degC
Qair_Gnielinski = 1270 W
```

## Benchmark Results

### Native COMSOL nonisothermal coupling

```text
Tout_bulk = 35.72 degC
h_COMSOL = 2.21 W/(m2 K)
Nu_COMSOL = 8.51
h_COMSOL / h_Gnielinski = 0.064
Qair_COMSOL = 380 W
```

This fails the benchmark by a large margin. The result is close to a weak
molecular/laminar heat-transfer response, not a turbulent pipe response.

### Explicit k-omega thermal diffusivity

The second run forced the heat-transfer material conductivity to include:

```text
k_eff = k_air + rho_f*k/omega*cp_f/Pr_t
```

Result:

```text
Tout_bulk = 33.08 degC
h_COMSOL = 4.35 W/(m2 K)
Nu_COMSOL = 16.73
h_COMSOL / h_Gnielinski = 0.126
Qair_COMSOL = 640 W
```

This improves the heat transfer but still fails the benchmark. Therefore the
problem is not only the heat equation missing turbulent diffusivity; the
generated SST flow/wall treatment is also not producing a physically valid
near-wall turbulent heat-transfer response.

## Variable Diagnostics

The solved native benchmark was probed at z = 25 m.

Important findings:

```text
Axial velocity variable: w
Turbulence variables: k and om
COMSOL-prefixed k/omega variables such as spf.k and spf.om were unavailable.
spf.muT and spf.nuT were essentially zero across the pipe radius.
ht.k_eff / ht.keff / ht.kteff were unavailable.
```

The radial profile shows nonzero k and omega, but `spf.muT` remains zero. This
means the current script should not rely on `spf.muT` as evidence of active
turbulent transport, and the nonisothermal coupling is still not producing a
validated turbulent heat-transfer model.

## Conclusion

The low effective heat-transfer coefficient in the 50 m Sharan CFD model is
not caused by the soil domain, pipe wall, initial soil temperature, or outlet
temperature averaging. The simplified pipe benchmark fails before any of those
effects are included.

The current LiveLink-generated COMSOL turbulence/heat-transfer setup is
therefore not yet a valid CFD reference model for the Sharan comparison.

## Required Fixes Before Re-running the Full 50 m Soil Model

1. Build the same pipe benchmark once in the COMSOL GUI using the predefined
   nonisothermal turbulent-flow interface, then export the Java/MATLAB API.
   The exported API keys should replace the guessed LiveLink property names.

2. Verify that the wall treatment is explicit and valid:

```text
Wall-function route:
  30 < y+ < 100
  thermal wall function enabled

Low-Re resolved SST route:
  y+ about 1
  first layer thickness about 3e-5 to 5e-5 m
  15-25 boundary-layer elements
```

3. Export and check these quantities from the COMSOL model:

```text
k
omega
turbulent viscosity actually used by the flow equations
turbulent thermal conductivity or turbulent thermal diffusivity
y+
wall heat flux
mass-flow weighted Tin/Tout
```

4. The benchmark acceptance condition remains:

```text
0.7 <= h_COMSOL / h_Gnielinski <= 1.3
energy closure error < 5-10%
```

Only after this pipe benchmark passes should the 50 m pipe-wall-soil model be
used for comparison with Sharan data or the Minaei-G reduced model.

## GUI Template Validation Result

The COMSOL GUI-built template saved as:

```text
G:\codexproject\COMSOL_GUI_templates\Sharan_pipe_GUI_template.mph
```

was loaded and solved by:

```text
run_comsol_gui_template_sharan_pipe_benchmark.m
```

This GUI template uses the official nonisothermal turbulent-flow setup rather
than creating the turbulent physics from guessed LiveLink property names.

Result:

```text
Re = 6.7103e4
Pr = 0.7158
Tout_bulk = 26.662 degC
h_COMSOL = 33.413 W/(m2 K)
h_Gnielinski = 34.500 W/(m2 K)
h_COMSOL / h_Gnielinski = 0.969
Nu_COMSOL = 128.51
Nu_Gnielinski = 132.69
Qair_COMSOL = 1269.06 W
Qair_Gnielinski = 1270.02 W
```

The benchmark therefore passes the acceptance criterion:

```text
0.7 <= h_COMSOL / h_Gnielinski <= 1.3
```

Important variable diagnostics from the GUI template:

```text
Axial velocity variable: w
k-epsilon variables: k and ep
spf.muT = 7.21e-4 Pa*s at r = 0.95*rpi, z = 25 m
```

This confirms that the previously low heat-transfer coefficient was not due to
the Sharan velocity, pipe length, or air properties. It was caused by the
script-generated SST/heat-transfer coupling failing to produce an effective
turbulent wall heat-transfer response. The next model should therefore use the
GUI-validated k-epsilon wall-function route, or a full GUI-built EAHE template
whose API is exported after verification.
