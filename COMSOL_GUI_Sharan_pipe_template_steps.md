# COMSOL GUI Template Steps for the Sharan Turbulent Pipe Benchmark

## Goal

Create a clean COMSOL GUI-built benchmark model that verifies air-side
turbulent heat transfer before returning to the full 50 m EAHE soil model.

Save the final GUI model as:

```text
G:\codexproject\COMSOL_GUI_templates\Sharan_pipe_GUI_template.mph
```

The MATLAB runner expects this file path by default.

## Model Wizard

Use these choices in COMSOL GUI:

```text
Space dimension:
  2D Axisymmetric

Physics:
  Nonisothermal Flow
  Turbulent Flow, k-epsilon
  Heat Transfer in Fluids

Study:
  Stationary
```

Use `k-epsilon` first because this benchmark is a high-Re straight pipe and
the wall-function route is usually more robust than SST for this purpose.

## Global Parameters

Add these parameters with exactly these names:

```text
L        = 50[m]
rpi      = 0.05[m]
Dhyd     = 2*rpi
Vdot     = 0.0863[m^3/s]
rho_f    = 0.0975/0.0863[kg/m^3]
cp_f     = 1006[J/(kg*K)]
k_air    = 0.026[W/(m*K)]
mu_f     = 1.85e-5[Pa*s]
mdot     = rho_f*Vdot
u_z      = Vdot/(pi*rpi^2)
Tin_K    = 39.6[degC]
Twall_K  = 26.6[degC]
I_turb   = 0.05
Lt_turb  = 0.07*Dhyd
Pr_turb  = 0.85
```

## Geometry

Create one rectangle:

```text
Width  = rpi
Height = L
Position = (0, 0)
```

In 2D axisymmetry:

```text
x = r
y = z
```

## Materials

Assign air to the rectangle:

```text
Density:            rho_f
Heat capacity:      cp_f
Thermal conductivity: k_air
Dynamic viscosity:  mu_f
```

Do not add pipe wall or soil in this benchmark.

## Boundary Conditions

Boundary names to keep clear:

```text
x = 0:       Axis
y = 0:       Inlet
y = L:       Outlet
x = rpi:     Wall
```

Turbulent flow:

```text
Inlet:
  Average velocity or normal inflow velocity = u_z
  Turbulence intensity = I_turb
  Turbulence length scale = Lt_turb

Outlet:
  Pressure = 0 Pa

Wall:
  No slip
  Wall functions enabled
```

Heat transfer:

```text
Inlet:
  Temperature = Tin_K

Wall:
  Temperature = Twall_K

Outlet:
  Convective flux / outflow
```

Multiphysics:

```text
Nonisothermal Flow coupling must be active.
Turbulent heat transfer must be active.
Turbulent Prandtl number must be Pr_turb or 0.85.
Thermal wall function must be active.
```

## Mesh

For the wall-function route, target:

```text
30 < y+ < 100
```

A practical starting mesh:

```text
Mapped quadrilateral mesh
Axial elements: 150-200
Radial elements: 20-40
First near-wall cell center target: y+ around 30-100
```

If y+ is below 30, make the first near-wall cell thicker or reduce radial
resolution near the wall. If y+ is above 100, refine near the wall.

## Required GUI Checks Before Saving

After solving, confirm in COMSOL:

```text
Velocity profile is turbulent-like.
y+ is mostly between 30 and 100 on the wall.
Wall heat flux is nonzero and physically large.
Outlet bulk temperature is close to 26.65 degC for this benchmark.
```

The expected result from Gnielinski is:

```text
h = 34.50 W/(m2 K)
Nu = 132.69
Tout_bulk = 26.65 degC
```

The template passes if:

```text
0.7 <= h_COMSOL/h_Gnielinski <= 1.3
```

## Export/Save

Save the GUI-built model as:

```text
G:\codexproject\COMSOL_GUI_templates\Sharan_pipe_GUI_template.mph
```

Optional but recommended:

```text
File > Save As > Model File for MATLAB
```

Save the exported MATLAB file as:

```text
G:\codexproject\COMSOL_GUI_templates\Sharan_pipe_GUI_template_exported.m
```

The exported MATLAB file reveals the exact COMSOL API keys. Those keys should
replace the guessed LiveLink physics-property names in the generated scripts.
