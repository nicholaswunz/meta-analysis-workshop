"""Build the Activity 1 Excel templates and worked solutions from the simulated CSVs.

Run from the project root:  python3 scripts/make_excel_workbooks.py
Solutions contain live Excel formulas (with cached results so they can also be
read by readxl::read_excel() without opening Excel first).
"""
import csv
import math
from pathlib import Path

import xlsxwriter

root = Path(__file__).resolve().parents[1]
out = root / "excel"
out.mkdir(exist_ok=True)


def read_csv(name):
    with open(root / "data" / name, newline="") as f:
        rows = list(csv.DictReader(f))
    return rows


def col(n):  # 0-based index -> Excel column letter
    s = ""
    n += 1
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def num(x):
    try:
        v = float(x)
        return int(v) if v.is_integer() and "." not in x else v
    except ValueError:
        return x


def build(rows, data_cols, new_cols, formulas, values, instructions, path, solution):
    wb = xlsxwriter.Workbook(path)
    head = wb.add_format({"bold": True, "bg_color": "#16324F", "font_color": "white", "border": 1})
    newh = wb.add_format({"bold": True, "bg_color": "#E69F00", "border": 1})
    todo = wb.add_format({"bg_color": "#FFF4D6", "border": 1})
    calc = wb.add_format({"bg_color": "#EAF4EC", "num_format": "0.000000", "border": 1})
    wrap = wb.add_format({"text_wrap": True, "valign": "top"})
    title = wb.add_format({"bold": True, "font_size": 14})

    ws = wb.add_worksheet("data")
    for j, c in enumerate(data_cols):
        ws.write(0, j, c, head)
    for j, c in enumerate(new_cols):
        ws.write(0, len(data_cols) + j, c, newh)
    for i, r in enumerate(rows, start=1):
        for j, c in enumerate(data_cols):
            ws.write(i, j, num(r[c]))
        for j, c in enumerate(new_cols):
            cj = len(data_cols) + j
            if solution:
                f = formulas[c].replace("{r}", str(i + 1))
                ws.write_formula(i, cj, f, calc, values[c](r))
            else:
                ws.write_blank(i, cj, None, todo)
    ws.freeze_panes(1, 0)
    ws.set_column(0, len(data_cols) - 1, 13)
    ws.set_column(3, 4, 24)
    ws.set_column(len(data_cols), len(data_cols) + len(new_cols) - 1, 15)

    ins = wb.add_worksheet("instructions")
    ins.set_column(0, 0, 110)
    ins.write(0, 0, instructions[0], title)
    for k, line in enumerate(instructions[1:], start=2):
        ins.write(k, 0, line, wrap)
    if solution:
        ins.write(len(instructions) + 2, 0, "SOLUTION: the orange columns on the 'data' sheet contain the formulas.", title)
    ins.activate()
    wb.close()


# ---------------------------------------------------------------- correlation
corr = read_csv("sim_correlation.csv")
corr_cols = list(corr[0].keys())
corr_new = ["Zr_excel", "v_Zr_excel", "se_Zr_excel"]
ci = {c: col(i) for i, c in enumerate(corr_cols + corr_new)}
corr_f = {
    "Zr_excel": f"=0.5*LN((1+{ci['r']}{{r}})/(1-{ci['r']}{{r}}))",
    "v_Zr_excel": f"=1/({ci['sample_size']}{{r}}-3)",
    "se_Zr_excel": f"=SQRT({ci['v_Zr_excel']}{{r}})",
}
corr_v = {
    "Zr_excel": lambda r: 0.5 * math.log((1 + float(r["r"])) / (1 - float(r["r"]))),
    "v_Zr_excel": lambda r: 1 / (float(r["sample_size"]) - 3),
    "se_Zr_excel": lambda r: math.sqrt(1 / (float(r["sample_size"]) - 3)),
}
corr_ins = [
    "Activity 1 · Task 1 · Fisher's Zr from correlation coefficients",
    "Each row is one correlation (column 'r') between metabolic rate and a performance trait, measured on 'sample_size' animals.",
    "1. In column Zr_excel calculate Fisher's z: Zr = 0.5 * ln((1 + r) / (1 - r)). In Excel: =0.5*LN((1+I2)/(1-I2)) or =FISHER(I2).",
    "2. In column v_Zr_excel calculate the sampling variance: v = 1 / (n - 3).",
    "3. In column se_Zr_excel calculate the standard error: SE = sqrt(v).",
    "4. Drag the formulas down to the last row (row 51). Do NOT sort or delete rows.",
    "5. Save as .xlsx and read the file into R with readxl::read_excel(path, sheet = 'data') to compare with metafor::escalc().",
]
build(corr, corr_cols, corr_new, corr_f, corr_v, corr_ins, out / "correlation_template.xlsx", False)
build(corr, corr_cols, corr_new, corr_f, corr_v, corr_ins, out / "correlation_solution.xlsx", True)

# ------------------------------------------------------------------- contrast
con = read_csv("sim_contrast.csv")
con_cols = list(con[0].keys())
con_new = ["lnRR_excel", "v_lnRR_excel", "sd_pooled", "J_correction", "SMD_excel", "v_SMD_excel"]
cc = {c: col(i) for i, c in enumerate(con_cols + con_new)}
mC, sC, nC = cc["control_mean"], cc["control_sd"], cc["control_n"]
mT, sT, nT = cc["treatment_mean"], cc["treatment_sd"], cc["treatment_n"]
con_f = {
    "lnRR_excel": f"=LN({mT}{{r}}/{mC}{{r}})",
    "v_lnRR_excel": f"={sT}{{r}}^2/({nT}{{r}}*{mT}{{r}}^2)+{sC}{{r}}^2/({nC}{{r}}*{mC}{{r}}^2)",
    "sd_pooled": f"=SQRT((({nT}{{r}}-1)*{sT}{{r}}^2+({nC}{{r}}-1)*{sC}{{r}}^2)/({nT}{{r}}+{nC}{{r}}-2))",
    "J_correction": f"=1-3/(4*({nT}{{r}}+{nC}{{r}}-2)-1)",
    "SMD_excel": f"=({mT}{{r}}-{mC}{{r}})/{cc['sd_pooled']}{{r}}*{cc['J_correction']}{{r}}",
    "v_SMD_excel": f"=({nT}{{r}}+{nC}{{r}})/({nT}{{r}}*{nC}{{r}})+{cc['SMD_excel']}{{r}}^2/(2*({nT}{{r}}+{nC}{{r}}))",
}


def _smd(r):
    nt, nc = float(r["treatment_n"]), float(r["control_n"])
    st, sc = float(r["treatment_sd"]), float(r["control_sd"])
    sp = math.sqrt(((nt - 1) * st**2 + (nc - 1) * sc**2) / (nt + nc - 2))
    J = 1 - 3 / (4 * (nt + nc - 2) - 1)
    return (float(r["treatment_mean"]) - float(r["control_mean"])) / sp * J, sp, J


con_v = {
    "lnRR_excel": lambda r: math.log(float(r["treatment_mean"]) / float(r["control_mean"])),
    "v_lnRR_excel": lambda r: float(r["treatment_sd"]) ** 2 / (float(r["treatment_n"]) * float(r["treatment_mean"]) ** 2)
    + float(r["control_sd"]) ** 2 / (float(r["control_n"]) * float(r["control_mean"]) ** 2),
    "sd_pooled": lambda r: _smd(r)[1],
    "J_correction": lambda r: _smd(r)[2],
    "SMD_excel": lambda r: _smd(r)[0],
    "v_SMD_excel": lambda r: (float(r["treatment_n"]) + float(r["control_n"])) / (float(r["treatment_n"]) * float(r["control_n"]))
    + _smd(r)[0] ** 2 / (2 * (float(r["treatment_n"]) + float(r["control_n"]))),
}
con_ins = [
    "Activity 1 · Task 2 · log response ratio (lnRR) from means, SDs and sample sizes",
    "Each row compares warmed animals (treatment) with controls. Rows with the same comparison_ID share the same control group.",
    "1. lnRR_excel = ln(treatment_mean / control_mean). In Excel: =LN(L2/I2)",
    "2. v_lnRR_excel = treatment_sd^2/(treatment_n*treatment_mean^2) + control_sd^2/(control_n*control_mean^2)",
    "EXTENSION (Hedges' g):",
    "3. sd_pooled = sqrt(((nT-1)*sdT^2 + (nC-1)*sdC^2) / (nT + nC - 2))",
    "4. J_correction = 1 - 3 / (4*(nT + nC - 2) - 1)",
    "5. SMD_excel = (treatment_mean - control_mean) / sd_pooled * J_correction",
    "6. v_SMD_excel = (nT + nC)/(nT*nC) + SMD^2/(2*(nT + nC))",
    "7. Drag formulas down to row 51, save as .xlsx, and compare with metafor::escalc(measure = 'ROM') and escalc(measure = 'SMD') in R.",
]
build(con, con_cols, con_new, con_f, con_v, con_ins, out / "contrast_template.xlsx", False)
build(con, con_cols, con_new, con_f, con_v, con_ins, out / "contrast_solution.xlsx", True)
print("Workbooks written to", out)
