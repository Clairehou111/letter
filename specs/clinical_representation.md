You are a Senior Full-Stack Engineer with deep experience in clinical data compliance and native file export pipelines for the North American medical market (OB-GYN and psychiatric clinical standards).

Your task is to implement the core export adapter and layout generator that converts local behavioral data into an objective, doctor-ready clinical report. 

CLINICAL & TECHNICAL REQUIREMENTS:
1. MEDICAL REPORT COMPATIBILITY: The layout must strictly map to the 11 core clinical domains of the Daily Record of Severity of Problems (DRSP) used to diagnose PMDD and severe PMS in North America.
2. PRIVACY COCOON: The report must completely omit and strip the user's raw text journal logs to preserve absolute psychological privacy. It must only export anonymized, quantified clinical metrics (severity, symptom codes, medication intervals).
3. PROVENANCE LEGEND: The footer must feature a clear legal provenance notice stating that all data is generated via deterministic local logs with zero cloud interception.

REPORT STRUCTURE & PDF LAYOUT SPECIFICATION:
- Header: Minimalist typography. "Patient Cyclical Symptom Standard Log (DRSP-Compatible)". Includes metadata blocks for Cycle IDs, target monitoring duration (e.g., Last 3 Cycles), and export timestamp.
- Main Section (The Twin Matrix Graph): A clean, high-density, black-and-white horizontal grid.
  - X-Axis: Left of Center represents Days -14 to -1 (Luteal/Pre-menses); Right of Center represents Days 1 to 14 (Menses/Follicular).
  - Y-Axis: The 4 major clinical PMDD clusters: 1. Irritability/Anger, 2. Depressed Mood/Anxiety, 3. Social Withdrawal, 4. Physical Cramps/Pain.
  - Bars: Render ultra-thin, low-ink gray or black bar markers showing the aggregated daily severity scores (scaled 1 to 6 per DRSP standard) derived from the local behavior-to-data mapping engine (e.g., crash-out screen taps mapped to anger severity).
- Footer Section: 
  - "Medication Logs": Display a strict temporal timeline of self-reported painkiller intakes (e.g., Ibuprofen) mapped against the peak physical pain coordinates.
  - "Provenance Legend": "verified authentic: logged locally via device cryptographic key. zero cloud transit."

Implement this export pipeline using native platform rendering or a clean local file writer (e.g., using `reportlab` logic if python, or a clean `share_plus` backed native file adapter in Dart). The final asset must be an un-editable, clean, grid-aligned document optimized for a 10-second glance review by a busy North American physician.
