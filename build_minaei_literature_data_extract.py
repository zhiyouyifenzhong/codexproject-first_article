from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "Minaei_literature_data_extract"
OUT.mkdir(exist_ok=True)


def main():
    table1 = pd.DataFrame(
        [
            ("Air", 1.225, 1006.0, 0.0242, "Minaei Table 1 / Vaz validation properties"),
            ("Soil", 1800.0, 1780.0, 2.1, "Minaei Table 1 / Vaz validation properties"),
        ],
        columns=[
            "material",
            "density_kg_m3",
            "specific_heat_J_kgK",
            "thermal_conductivity_W_mK",
            "source_note",
        ],
    )

    table2 = pd.DataFrame(
        [
            ("pipe_inside_diameter", 110.0, "mm"),
            ("pipe_thickness", None, "not reported / shown as dash in extracted text"),
            ("pipe_length", 25.77, "m"),
            ("buried_depth", 1.6, "m"),
            ("air_velocity", 3.3, "m/s"),
            ("undisturbed_soil_temperature", 18.55, "degC"),
            ("Asurf", 6.28, "degC"),
        ],
        columns=["parameter", "value", "unit"],
    )

    validation_bc = pd.DataFrame(
        [
            (
                "ground_surface_temperature",
                "Ts(t) = 18.55 + 6.28 sin(2*pi*t/P + 26.4)",
                "degC",
                "Eq. 24; PDF extraction has symbol/phase formatting noise, verify visually before final typesetting",
            ),
            (
                "EAHE_inlet_air_temperature",
                "Ta(t) = 20.34 + 5.66 sin(2*pi*t/P - 5.30)",
                "degC",
                "Eq. 25; PDF extraction has symbol/phase formatting noise, verify visually before final typesetting",
            ),
            ("period", "P = 365 days", "s or day-normalized in equation", "annual sinusoidal boundary"),
            ("simulation_length", "two consecutive years; second year reported", "-", "Section 3.1 validation"),
        ],
        columns=["item", "expression_or_value", "unit", "note"],
    )

    validation_metrics = pd.DataFrame(
        [
            ("present_vs_fitted_experimental_measurements", 1.98, "degC", "annual RMSD, Eq. 26"),
            ("present_vs_full_numerical_model", 0.48, "degC", "annual RMSD, Eq. 27"),
        ],
        columns=["comparison", "RMSD", "unit", "source_note"],
    )

    table3 = pd.DataFrame(
        [
            ("soil_density", 1285.0, "kg/m3"),
            ("soil_specific_heat_capacity", 1285.0, "J/kgK"),
            ("soil_thermal_conductivity", 2.1, "W/mK"),
            ("pipe_inside_diameter", 110.0, "mm"),
            ("pipe_thickness", 2.5, "mm"),
            ("pipe_length", 50.0, "m"),
            ("buried_depth_range", "2-8", "m"),
            ("air_velocity_range", "2-5", "m/s"),
            ("undisturbed_soil_temperature", 18.0, "degC"),
            ("Asurf", 14.0, "degC"),
            ("t0", 18.0, "day or phase parameter"),
        ],
        columns=["parameter", "value", "unit"],
    )

    figure_data = pd.DataFrame(
        [
            (
                "Fig. 4",
                "annual validation comparison with experimental data, full numerical model, simplified/reduced models",
                "not tabulated",
                "requires curve digitization or original Vaz/Brum data",
            ),
            (
                "Fig. 5",
                "effect of air velocity on annual outlet temperature and heat transfer",
                "not tabulated",
                "requires curve digitization if numerical points are needed",
            ),
            (
                "Fig. 6",
                "effect of installation depth on annual outlet temperature and heat transfer",
                "not tabulated",
                "requires curve digitization if numerical points are needed",
            ),
            (
                "Fig. 7",
                "intermittent operation 180-190 day outlet temperature and heat transfer",
                "not tabulated",
                "requires curve digitization if numerical points are needed",
            ),
        ],
        columns=["figure", "content", "data_status", "extraction_method"],
    )

    references = pd.DataFrame(
        [
            (
                9,
                "J. Vaz, M.A. Sattler, D. Elizaldo, L.A. Isoldi",
                "Experimental and numerical analysis of an earth-air heat exchanger",
                "Energy and Buildings 43 (2011) 2476-2482",
                "10.1016/j.enbuild.2011.06.003",
                "main experimental validation source used by Minaei",
            ),
            (
                10,
                "R.S. Brum, L.A.O. Rocha, J. Vaz, E.D. dos Santos, L.A. Isoldi",
                "Development of simplified numerical model for evaluation of the influence of soil-air heat exchanger installation depth over its thermal potential",
                "International Journal of Advanced Renewable Energy Research 1 (2012) 505-514",
                "",
                "simplified numerical model compared in Fig. 4",
            ),
            (
                11,
                "S. Brum, J. Vaz, L.A.O. Rocha, E.D. dos Santos, L.A. Isoldi",
                "A new computational modeling to predict the behavior of Earth-Air Heat Exchangers",
                "Energy and Buildings 64 (2013) 395-402",
                "10.1016/j.enbuild.2013.05.032",
                "reduced numerical model compared in Fig. 4",
            ),
            (
                12,
                "V.F. Hermes et al.",
                "Further realistic annual simulations of earth-air heat exchangers installations in a coastal city",
                "Sustainable Energy Technologies and Assessments 37 (2020) 100603",
                "10.1016/j.seta.2019.100603",
                "annual simulation reference cited by Minaei",
            ),
        ],
        columns=["ref_no", "authors", "title", "venue", "doi", "note"],
    )

    outputs = {
        "Minaei_Table1_validation_material_properties.csv": table1,
        "Minaei_Table2_validation_case_parameters.csv": table2,
        "Minaei_validation_boundary_conditions.csv": validation_bc,
        "Minaei_validation_RMSD_metrics.csv": validation_metrics,
        "Minaei_Table3_parametric_study_parameters.csv": table3,
        "Minaei_figures_data_availability.csv": figure_data,
        "Minaei_key_references_for_validation_data.csv": references,
    }

    for name, df in outputs.items():
        df.to_csv(OUT / name, index=False, encoding="utf-8-sig")

    lines = []
    lines.append("# Minaei Literature Data Extract\n")
    lines.append("## What Can Be Extracted Directly\n")
    lines.append("- Table 1: validation material properties for air and soil.")
    lines.append("- Table 2: Vaz-validation case geometry and operating parameters.")
    lines.append("- Eqs. 24-25: annual ground-surface and inlet-air temperature functions.")
    lines.append("- Eqs. 26-27: annual RMSD metrics.")
    lines.append("- Table 3: parametric-study properties and parameter ranges.\n")
    lines.append("## What Cannot Be Extracted As Raw Data From Minaei Alone\n")
    lines.append(
        "Minaei does not provide tabulated annual outlet-temperature time series for Fig. 4, Fig. 5, Fig. 6, or Fig. 7. "
        "Those curves can only be digitized approximately from the figure images, unless the original Vaz/Brum data are obtained."
    )
    lines.append("\n## Validation Data Meaning\n")
    lines.append(
        "For annual validation, Minaei reports RMSD = 1.98 degC against fitted experimental measurements and "
        "RMSD = 0.48 degC against the full numerical model. These are valid literature-level benchmarks, but they are "
        "not a replacement for a point-by-point annual experimental CSV."
    )
    lines.append("\n## Recommended Use\n")
    lines.append(
        "Use the extracted tables and RMSD values directly in the paper. If a curve-level comparison is required, "
        "digitize Fig. 4 and clearly label the points as digitized from the published figure."
    )
    (OUT / "Minaei_literature_data_extract_report.md").write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote Minaei data extract to {OUT}")


if __name__ == "__main__":
    main()
