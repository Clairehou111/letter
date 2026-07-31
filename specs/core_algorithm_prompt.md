
You are a Principal Software Architect specializing in local-first, privacy-safe biomedical algorithms and diagnostic tracking systems compliant with North American medical logging standards.

Your task is to refactor the current Dart cycle prediction and pattern learning architecture into a deterministic, auditable, and production-ready engine inside `lib/features/cycle/domain/cycle_prediction.dart` and `lib/features/patterns/domain/personal_pattern_engine.dart`.


ALGORITHM 1: REFACTOR `CyclePredictionEngine` WITH OUTLIER FILTERING & LUTEAL PHASE DETECTION
- Step 1 (Outlier Filter): Scan the last 7 menses start intervals. Calculate the baseline median. Automatically drop and skip any outlier cycle interval that is < 21 days or > 45 days, or deviates from the median by more than 1.5x, to prevent historical anomalies (e.g., illness, high stress) from corrupting future predictions.
- Step 2 (Luteal Phase Detection): Implement a precise gynecological phase deduction framework. Based on the hard clinical invariant that the luteal phase (post-ovulation to pre-menses) is relatively constant at 14 days (±2 days) across adult women, calculate the `predictedLutealStart` and `predictedLutealEnd` using a strict countdown from the calculated `predictedMensesStartMin` and `predictedMensesStartMax`.
- Output Model: Expand the prediction output to explicitly expose:
  - `predictedMensesStart` (DateTime range)
  - `predictedLutealStart` (DateTime window)
  - `predictedLutealEnd` (DateTime window)
  - `confidenceLevel` (Low/Medium/Higher based on stable interval counts)

ALGORITHM 2: REFACTOR `PersonalPatternEngine` WITH REVERSE COUNTDOWN MATRIX (DAYS BEFORE MENSES)
- Step 1: Shift the structural symptom aggregation paradigm away from absolute `Cycle Day` (days since cycle started). 
- Step 2: Implement a reverse alignment timeline calculation: `Days Before Menses` = `Date of Symptom Record` minus `Date of Actual Subsequent Menses Start`. Represent this as a negative index (e.g., Day -3 means 3 days before the next period).
- Step 3: Map all local `HealthRecord` and `CareRecord` entries into this negative matrix array. Aggregate symptom severity, locations, and coping efficacy (e.g., "rage peaks exactly at Day -3 across 80% of cycles"). This preserves accurate behavioral pattern mapping across varying cycle lengths (e.g., 28-day vs. 35-day cycles).

Write the clean, fully typed, performance-optimized Dart domain code. Include complete unit test hooks verifying outlier exclusion and negative-index mapping.
