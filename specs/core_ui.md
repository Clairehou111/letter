
You are a Staff UI/UX Engineer at Apple and Bang & Olufsen, recognized for crafting hyper-minimalist, high-end somatic interfaces that soothe health anxiety.

Your task is to write a Flutter frontend UI implementation (`CustomPainter` and specialized widgets) to visually manifest the cycle prediction and local pattern data without using traditional, sterile, industrial grid charts or steep line graphs.

DESIGN TOKENS (STRICTLY ENFORCED):
- Base Canvas: Deep Charcoal Obsidian Black (`#0B0C10`). Zero borders, zero card boxes, zero childish pink accents.
- Typography: Pure lowercase (`lowercase`) across all text indicators. Ultra-thin and regular fonts only.
- Cadence: Buttery smooth 60fps transitions, prioritizing breathing organic negative space.

COMPONENT 1: THE GRAVITY HORIZON (HOME/TODAY VIEW)
- Implement a custom-drawn, razor-thin, glowing Bezier Curve across the bottom third of the screen using `CustomPainter`.
- The curve represents the cycle's energy topography: flat and serene during the follicular phase, dipping into a gentle, soft downward valley during the predicted Luteal window (computed from `predictedLutealStart`), representing the increased pull of hormonal gravity and PMS/PMDD danger windows.
- Render a single, soft, glowing circular dot (the user's today indicator) sitting quietly on the curve. 
- Underneath, display an elegant, low-contrast, lowercase string: "current tide: entering the luteal valley. gravity feels heavier today. you are safe to slow down."

COMPONENT 2: THE SPECTRUM LOG (INSIGHTS VIEW)
- Replace all line graphs with an elegant "Hormonal Spectrum Strip". Draw a single horizontal bar representing the 14-day luteal phase countdown (from Day -14 to Day -1).
- Instead of blocky charts, use a specialized radial/linear gradient blur (`ui.Gradient.radial`) to paint blurred "nebulas of color" directly onto the strip based on data from `PersonalPatternEngine`.
- If the local algorithm detects high rage concentration at Day -3, blur a soft, deep, bleeding velvet-crimson fog onto that specific segment of the timeline. It must look like an organic cosmic spectrum, allowing adult women to intuitively visualize their recurring danger windows without text or statistical stress.

Write the production-ready Flutter code using Dart `CustomPainter` or clean custom components. Ensure all rendering code relies on a simple, mockable view-state object passing the calculated day coordinates.
