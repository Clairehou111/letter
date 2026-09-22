import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/patterns/domain/patterns_experience_data.dart';

// Kimi-authored Patterns presentation, connected to a factual local snapshot.
//
// Bleeding consistency contract held throughout this file:
//  * A period's recorded start/end define which days were bleeding days.
//  * A saved flow entry only enriches one of those already-recorded days.
//  * A period day without a flow entry is an honest unknown — never "none",
//    never "light", and never an absent period day.
//  * Flow degrees reuse Today's exact bleeding colors and teardrop
//    silhouette, drawn locally as one segmented droplet (see FlowDrop) so
//    compact day cells keep the 1/2/3/4 degree readable at 16 px.
//
// Evidence-language contract: findings lead; missingness is explained once
// per view in a quiet subordinate line — never repeated as a per-cycle
// logging score, and never implying an unrecorded day was easy, good, or
// symptom-free.

// ---------------------------------------------------------------------------
// Design tokens — Letter Within's shared warm-paper world. These alias the
// ExperienceFoundation palette (warm cream canvas, white cards, ember coral
// primary, raspberry/lilac/teal chart accents) so Patterns reads as the same
// product as Today and Cycle — no competing editorial palette.
// ---------------------------------------------------------------------------
class T {
  static const bg = ExperienceColors.canvas;
  static const surface = ExperienceColors.surface;
  static const ink = ExperienceColors.ink;
  static const inkSoft = ExperienceColors.inkSoft;
  static const line = ExperienceColors.hairline;
  static const coral = ExperienceColors.ember;
  static const coralDeep = ExperienceColors.emberDeep;
  static const coralSoft = Color(0xFFF6DCD2);
  static const berry = ExperienceColors.phasePeriod;
  static const lake = ExperienceColors.phaseFollicular;
  static const violet = ExperienceColors.phaseLuteal;
  static const lilac = Color(0xFFC5B2E3);
  static const teal = ExperienceColors.accentSpectrum;
  static const green = ExperienceColors.phaseOvulation;
  static const sand = ExperienceColors.surfaceWarm;
}

// The shared serif — identical to the ExperienceType display voice.
const _serif = 'Georgia';

class _S {
  static const display = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: ['serif'],
    fontSize: 32,
    height: 1.05,
    fontWeight: FontWeight.w700,
    color: T.ink,
  );
  static const headline = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: ['serif'],
    fontSize: 25,
    height: 1.16,
    fontWeight: FontWeight.w700,
    color: T.ink,
  );
  static const titleL = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: ['serif'],
    fontSize: 20,
    height: 1.22,
    color: T.ink,
  );
  static const titleM = TextStyle(
    color: T.ink,
    fontWeight: FontWeight.w700,
    fontSize: 14.5,
    height: 1.25,
  );
  static const bodyL = TextStyle(fontSize: 16, height: 1.55, color: T.ink);
  static const bodyM = TextStyle(color: T.inkSoft, height: 1.5, fontSize: 14);
  static const bodyS = TextStyle(color: T.inkSoft, height: 1.4, fontSize: 12.5);
  static const eyebrow = TextStyle(
    fontSize: 12,
    letterSpacing: 2.2,
    fontWeight: FontWeight.w700,
    color: T.coral,
  );
}

const _mo = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _moFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// ---------------------------------------------------------------------------
// Date + label helpers (epoch-day based; no domain types beyond the contract)
// ---------------------------------------------------------------------------
DateTime _dt(int epochDay) => DateTime.fromMillisecondsSinceEpoch(
  epochDay * Duration.millisecondsPerDay,
  isUtc: true,
);

int _epochOf(int year, int month, int day) =>
    DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

String fmtDate(int epochDay) {
  final d = _dt(epochDay);
  return '${_wd[d.weekday - 1]}, ${_mo[d.month - 1]} ${d.day}';
}

String fmtShort(int epochDay) {
  final d = _dt(epochDay);
  return '${_mo[d.month - 1]} ${d.day}';
}

String _cap(String s) {
  if (s.isEmpty) return s;
  final clean = s.replaceAll('_', ' ');
  return clean[0].toUpperCase() + clean.substring(1);
}

String _plural(int n, String one, [String? many]) =>
    n == 1 ? '$n $one' : '$n ${many ?? '${one}s'}';

int _minOf(List<int> v) => v.reduce((a, b) => a < b ? a : b);
int _maxOf(List<int> v) => v.reduce((a, b) => a > b ? a : b);
int _median(List<int> v) {
  final s = [...v]..sort();
  return s[s.length ~/ 2];
}

// Flow, outcome, tone and category presentation — keyed off factual names so
// nothing is invented beyond the saved record.
String flowName(String key) => switch (key) {
  'spotting' => 'Spotting',
  'light' => 'Light',
  'medium' => 'Medium',
  'heavy' => 'Heavy',
  _ => _cap(key),
};

/// The canonical flow colour is Today's phase-period raspberry. Degrees are
/// distinguished by the segmented glyph's band count and shape — never by a
/// second alpha-coded palette.
Color flowColor(String key) => ExperienceColors.phasePeriod;

int _flowRank(String key) => switch (key) {
  'spotting' => 0,
  'light' => 1,
  'medium' => 2,
  'heavy' => 3,
  _ => 2,
};

String outcomeLabel(String key) => switch (key) {
  'better' => 'Better',
  'same' => 'Same',
  'worse' => 'Worse',
  _ => _cap(key),
};

Color outcomeColor(String key) => switch (key) {
  'better' => T.green,
  'same' => T.lake,
  'worse' => T.coral,
  _ => T.inkSoft,
};

String catName(PatternsSymptomCategory c) => switch (c) {
  PatternsSymptomCategory.pain => 'Pain & discomfort',
  PatternsSymptomCategory.emotions => 'Difficult emotions',
  PatternsSymptomCategory.energyAndSleep => 'Energy & sleep',
  PatternsSymptomCategory.digestion => 'Digestive',
  PatternsSymptomCategory.otherBody => 'Other body experiences',
};

Color catColor(PatternsSymptomCategory c) => switch (c) {
  PatternsSymptomCategory.pain => T.berry,
  PatternsSymptomCategory.emotions => T.violet,
  PatternsSymptomCategory.energyAndSleep => T.lake,
  PatternsSymptomCategory.digestion => T.green,
  PatternsSymptomCategory.otherBody => T.teal,
};

String toneLabel(PatternsMoodTone t) => switch (t) {
  PatternsMoodTone.positive => 'Positive',
  PatternsMoodTone.steady => 'Steady',
  PatternsMoodTone.difficult => 'Difficult',
};

Color toneColor(PatternsMoodTone t) => switch (t) {
  PatternsMoodTone.positive => T.green,
  PatternsMoodTone.steady => T.lake,
  PatternsMoodTone.difficult => T.violet,
};

// ---------------------------------------------------------------------------
// Derived queries — everything reads the same supplied snapshot and range
// ---------------------------------------------------------------------------
int? cycleIndexFor(PatternsExperienceData d, int epochDay) {
  for (var i = 0; i < d.completedCycles.length; i++) {
    final c = d.completedCycles[i];
    if (epochDay >= c.startDate.epochDay &&
        epochDay < c.nextStartDate.epochDay) {
      return i;
    }
  }
  return null;
}

/// Whether [epochDay] is a recorded bleeding day — decided solely by period
/// start/end records, never by the presence of a flow entry.
bool isPeriodDay(PatternsExperienceData d, int epochDay) {
  final date = LocalDate.fromDateTime(_dt(epochDay));
  for (final c in d.completedCycles) {
    if (c.isBleedingDate(date)) return true;
  }
  final cur = d.currentCycle;
  if (cur != null && cur.isBleedingDate(date, displayedDay: d.today)) {
    return true;
  }
  return false;
}

String phaseLabel(PatternsExperienceData d, int epochDay) {
  final ci = cycleIndexFor(d, epochDay);
  if (ci != null) {
    final c = d.completedCycles[ci];
    final dayN = epochDay - c.startDate.epochDay + 1;
    final isBleedingDay = c.isBleedingDate(
      LocalDate.fromDateTime(_dt(epochDay)),
    );
    final before = c.nextStartDate.epochDay - epochDay;
    final String phase;
    if (isBleedingDay) {
      phase = 'Bleeding day $dayN';
    } else if (before <= 7) {
      phase = before == 1
          ? '1 day before bleeding'
          : '$before days before bleeding';
    } else {
      phase = 'Mid-cycle · day $dayN';
    }
    return '$phase · Cycle ${ci + 1}';
  }
  final cur = d.currentCycle;
  if (cur != null &&
      epochDay >= cur.startDate.epochDay &&
      epochDay <= d.today.epochDay) {
    final dayN = epochDay - cur.startDate.epochDay + 1;
    final isBleedingDay = cur.isBleedingDate(
      LocalDate.fromDateTime(_dt(epochDay)),
      displayedDay: d.today,
    );
    return isBleedingDay
        ? 'This cycle so far · bleeding day $dayN'
        : 'This cycle so far · day $dayN';
  }
  return 'Outside the saved cycles in this report';
}

Set<int> savedEpochsIn(PatternsExperienceData d, PatternsCompletedCycle c) {
  final lo = c.startDate.epochDay, hi = c.nextStartDate.epochDay;
  bool inside(int e) => e >= lo && e < hi;
  final out = <int>{
    for (final f in c.flowDays)
      if (inside(f.date.epochDay)) f.date.epochDay,
  };
  for (final r in d.symptoms) {
    if (inside(r.date.epochDay)) out.add(r.date.epochDay);
  }
  for (final r in d.moods) {
    if (inside(r.date.epochDay)) out.add(r.date.epochDay);
  }
  for (final r in d.care) {
    if (inside(r.date.epochDay)) out.add(r.date.epochDay);
  }
  return out;
}

/// A harder day is any day with a directly saved symptom, difficult feeling,
/// or explicit Physical check-in. Flow is deliberately separate: it describes
/// bleeding but does not say that the day felt hard.
Set<int> harderEpochsIn(PatternsExperienceData d, PatternsCompletedCycle c) {
  final lo = c.startDate.epochDay, hi = c.nextStartDate.epochDay;
  return {
    for (final r in d.symptoms)
      if (r.date.epochDay >= lo && r.date.epochDay < hi) r.date.epochDay,
    for (final mood in d.moods)
      if (mood.isHarder && mood.date.epochDay >= lo && mood.date.epochDay < hi)
        mood.date.epochDay,
  };
}

Map<PatternsSymptomCategory, Set<int>> categoryDays(PatternsExperienceData d) {
  final map = <PatternsSymptomCategory, Set<int>>{
    for (final c in PatternsSymptomCategory.values) c: {},
  };
  for (final s in d.symptoms) {
    map[s.category]!.add(s.date.epochDay);
  }
  for (final mood in d.moods) {
    final category = mood.harderCategory;
    if (category != null) map[category]!.add(mood.date.epochDay);
  }
  return map;
}

Map<String, Set<int>> itemDays(
  PatternsExperienceData d,
  PatternsSymptomCategory cat,
) {
  final map = <String, Set<int>>{};
  for (final s in d.symptoms) {
    if (s.category == cat) {
      map.putIfAbsent(s.label, () => {}).add(s.date.epochDay);
    }
  }
  for (final mood in d.moods) {
    if (mood.harderCategory == cat) {
      map.putIfAbsent(mood.label, () => {}).add(mood.date.epochDay);
    }
  }
  return map;
}

final class _HarderRecord {
  const _HarderRecord._({
    required this.id,
    required this.date,
    required this.category,
    required this.label,
    this.symptom,
    this.mood,
  });

  factory _HarderRecord.symptom(PatternsSymptomRecord value) => _HarderRecord._(
    id: value.id,
    date: value.date,
    category: value.category,
    label: value.label,
    symptom: value,
  );

  factory _HarderRecord.mood(PatternsMoodRecord value) => _HarderRecord._(
    id: value.id,
    date: value.date,
    category: value.harderCategory!,
    label: value.label,
    mood: value,
  );

  final String id;
  final LocalDate date;
  final PatternsSymptomCategory category;
  final String label;
  final PatternsSymptomRecord? symptom;
  final PatternsMoodRecord? mood;

  bool get isSymptom => symptom != null;
}

List<_HarderRecord> _harderRecordsInCompletedCycles(
  PatternsExperienceData data,
) {
  final records =
      <_HarderRecord>[
        for (final symptom in data.symptoms)
          if (cycleIndexFor(data, symptom.date.epochDay) != null)
            _HarderRecord.symptom(symptom),
        for (final mood in data.moods)
          if (mood.isHarder && cycleIndexFor(data, mood.date.epochDay) != null)
            _HarderRecord.mood(mood),
      ]..sort((left, right) {
        final byDate = left.date.compareTo(right.date);
        return byDate != 0 ? byDate : left.label.compareTo(right.label);
      });
  return records;
}

List<_HarderRecord> _harderRecordsForCategory(
  PatternsExperienceData data,
  PatternsSymptomCategory category,
) {
  final records = <_HarderRecord>[
    for (final symptom in data.symptoms)
      if (symptom.category == category) _HarderRecord.symptom(symptom),
    for (final mood in data.moods)
      if (mood.harderCategory == category) _HarderRecord.mood(mood),
  ]..sort((left, right) => right.date.compareTo(left.date));
  return records;
}

String? _rangeLabel(PatternsExperienceData d) {
  final first = d.firstIncludedDate;
  final last = d.lastIncludedDate;
  if (first == null || last == null) return null;
  final a = _dt(first.epochDay), b = _dt(last.epochDay);
  if (a.year == b.year && a.month == b.month) {
    return '${_mo[a.month - 1]} ${a.day} – ${b.day}, ${b.year}';
  }
  if (a.year == b.year) {
    return '${_mo[a.month - 1]} ${a.day} – '
        '${_mo[b.month - 1]} ${b.day}, ${b.year}';
  }
  return '${_mo[a.month - 1]} ${a.day}, ${a.year} – '
      '${_mo[b.month - 1]} ${b.day}, ${b.year}';
}

// ---------------------------------------------------------------------------
// Public screen — three peer tabs over one factual snapshot
// ---------------------------------------------------------------------------
class PatternsExperienceScreen extends StatefulWidget {
  const PatternsExperienceScreen({
    required this.data,
    this.onBack,
    this.onEditHealthRecord,
    super.key,
  });

  final PatternsExperienceData data;
  final VoidCallback? onBack;
  final ValueChanged<String>? onEditHealthRecord;

  @override
  State<PatternsExperienceScreen> createState() =>
      _PatternsExperienceScreenState();
}

class _PatternsExperienceScreenState extends State<PatternsExperienceScreen> {
  int _view = 1; // Mood & patterns is the default consumer analysis

  static const _tabs = ['Cycles & bleeding', 'Mood & patterns', 'What helped'];
  static const _tabKeys = [
    ValueKey('patterns-tab-cycles'),
    ValueKey('patterns-tab-mood'),
    ValueKey('patterns-tab-helped'),
  ];

  String get _subtitle {
    final d = widget.data;
    final n = d.completedCycleCount;
    if (!d.hasAnyPeriodHistory) {
      return 'Nothing gathered yet — the days you save will settle into patterns here.';
    }
    if (n == 0) {
      return 'Your current cycle is under way. What you save now will begin to gather into patterns — nothing is guessed in the meantime.';
    }
    final lead = n == 1 ? 'One completed cycle' : '$n completed cycles';
    return '$lead, read from the days you saved. What they are beginning to show comes first — the dates underneath are always one tap away.';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final range = _rangeLabel(data);
    return Scaffold(
      key: const ValueKey('patterns-experience-screen'),
      backgroundColor: T.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: LayoutBuilder(
              builder: (context, cons) {
                final pad = cons.maxWidth > 860 ? 42.0 : 22.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, 22, pad, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.onBack != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: widget.onBack,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_back,
                                        size: 15,
                                        color: T.inkSoft,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Back',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: T.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const Text('PATTERNS', style: _S.eyebrow),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  'Patterns, held gently.',
                                  style: _S.display.copyWith(
                                    fontSize: cons.maxWidth > 860 ? 38 : 32,
                                  ),
                                ),
                              ),
                              if (range != null) ...[
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: T.sand,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    range,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: T.inkSoft,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Text(_subtitle, style: _S.bodyL),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: _SegmentedNav(
                        labels: _tabs,
                        keys: _tabKeys,
                        index: _view,
                        onChanged: (i) => setState(() => _view = i),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(height: 1, color: T.line),
                    Expanded(
                      child: !data.hasAnyPeriodHistory
                          ? const _Scroll(children: [_EmptyStart()])
                          : IndexedStack(
                              index: _view,
                              children: [
                                CyclesView(
                                  data: data,
                                  onEdit: widget.onEditHealthRecord,
                                ),
                                MoodView(
                                  data: data,
                                  onEdit: widget.onEditHealthRecord,
                                ),
                                HelpedView(data: data),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedNav extends StatelessWidget {
  final List<String> labels;
  final List<Key> keys;
  final int index;
  final ValueChanged<int> onChanged;
  const _SegmentedNav({
    required this.labels,
    required this.keys,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: index == i,
              label: labels[i],
              child: InkWell(
                key: keys[i],
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: index == i
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: index == i ? T.ink : T.inkSoft,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      AnimatedContainer(
                        duration: MediaQuery.of(context).disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        height: 3,
                        width: index == i ? 34 : 0,
                        decoration: BoxDecoration(
                          color: T.coral,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------
class _Scroll extends StatelessWidget {
  final List<Widget> children;
  const _Scroll({required this.children});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final pad = cons.maxWidth > 860 ? 42.0 : 22.0;
        return ListView(
          key: const ValueKey('patterns-experience-scroll'),
          padding: EdgeInsets.fromLTRB(pad, 34, pad, 72),
          children: children,
        );
      },
    );
  }
}

class _EmptyStart extends StatelessWidget {
  const _EmptyStart();
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('patterns-empty-state'),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(ExperienceRadius.card),
        border: Border.all(color: T.line),
        boxShadow: ExperienceShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.water_drop_outlined, color: T.coral, size: 30),
          const SizedBox(height: 16),
          Text('Patterns begin with a first record.', style: _S.titleL),
          const SizedBox(height: 10),
          Text(
            'Record a period start and this page will begin holding your cycles, moods and care — exactly as you save them, never averaged or guessed.',
            style: _S.bodyM,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String number;
  final String question;
  final String? note;
  final List<Widget> children;
  const _Section({
    required this.number,
    required this.question,
    this.note,
    required this.children,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontFamily: _serif,
                  fontSize: 15,
                  color: T.coral,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(question, style: _S.headline)),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note!, style: _S.bodyM),
          ],
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }
}

class _Takeaway extends StatelessWidget {
  final String text;
  const _Takeaway(this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 46,
          margin: const EdgeInsets.only(top: 3, right: 14),
          decoration: BoxDecoration(
            color: T.coral,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: _S.bodyL.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _Scope extends StatelessWidget {
  final String text;
  const _Scope(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 13, color: T.inkSoft),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: T.inkSoft,
                letterSpacing: 0.2,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietInfo extends StatefulWidget {
  final String label;
  final String body;
  const _QuietInfo(this.label, this.body);
  @override
  State<_QuietInfo> createState() => _QuietInfoState();
}

class _QuietInfoState extends State<_QuietInfo> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 16,
                  color: T.inkSoft,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: T.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 6),
            child: Text(widget.body, style: _S.bodyM),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _Chip(this.label, this.color, {this.filled = true});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: filled ? 0.0 : 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: filled ? color : T.inkSoft,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets (read-only factual drill-downs)
// ---------------------------------------------------------------------------
void openSheet(BuildContext context, Widget child) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: h * 0.84),
        child: Container(
          decoration: const BoxDecoration(
            color: T.surface,
            borderRadius: ExperienceRadius.sheetRadius,
          ),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: T.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String? sub;
  const _SheetHeader(this.title, [this.sub]);
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _S.titleL),
        if (sub != null) ...[
          const SizedBox(height: 5),
          Text(sub!, style: _S.bodyM),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 16),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: _serif,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: T.ink,
      ),
    ),
  );
}

class _EvidenceRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String trailing;
  final Color color;
  final String? note;
  final String? meta;
  final String? emptyNote;
  final VoidCallback? onTap;
  const _EvidenceRow({
    required this.leading,
    required this.title,
    required this.trailing,
    required this.color,
    this.note,
    this.meta,
    this.emptyNote,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 3), child: leading),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: T.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (meta != null)
                Text(
                  meta!,
                  style: const TextStyle(fontSize: 12, color: T.inkSoft),
                ),
              if (note != null)
                Text(
                  '“$note”',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: T.inkSoft,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                )
              else if (emptyNote != null)
                Text(
                  emptyNote!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: T.inkSoft,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        _Chip(trailing, color),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: onTap == null
          ? row
          : InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(padding: const EdgeInsets.all(4), child: row),
            ),
    );
  }
}

/// One recorded bleeding day inside a cycle sheet: flow degree when saved,
/// otherwise the honest "period day, flow not recorded" state. Tapping always
/// opens the full date sheet.
Widget _bleedingDayEvidenceRow(
  BuildContext context,
  PatternsExperienceData data,
  PatternsCompletedCycle cycle,
  LocalDate date,
  ValueChanged<String>? onEdit,
) {
  final f = cycle.flowFor(date);
  final dayN = date.epochDay - cycle.startDate.epochDay + 1;
  return _EvidenceRow(
    leading: f != null
        ? FlowDrop(flowKey: f.flow.name, size: 16)
        : const _PeriodDayMark(size: 14),
    title: '${fmtDate(date.epochDay)} · day $dayN',
    trailing: f != null ? flowName(f.flow.name) : 'No flow recorded',
    color: f != null ? flowColor(f.flow.name) : T.inkSoft,
    meta: f != null
        ? (f.color == null ? null : 'Color saved: ${_cap(f.color!.name)}')
        : 'A recorded period day — flow detail was not saved.',
    onTap: () => openDaySheet(context, data, date.epochDay, onEdit),
  );
}

void openCycleSheet(
  BuildContext context,
  PatternsExperienceData data,
  int index,
  ValueChanged<String>? onEdit,
) {
  final c = data.completedCycles[index];
  final records =
      data.symptoms
          .where((s) => cycleIndexFor(data, s.date.epochDay) == index)
          .toList()
        ..sort((a, b) => a.date.epochDay.compareTo(b.date.epochDay));
  final moods =
      data.moods
          .where((m) => cycleIndexFor(data, m.date.epochDay) == index)
          .toList()
        ..sort((a, b) => a.date.epochDay.compareTo(b.date.epochDay));
  openSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          'Cycle ${index + 1}',
          '${fmtDate(c.startDate.epochDay)} – ${fmtShort(c.nextStartDate.epochDay - 1)} · ${_plural(c.lengthDays, 'day')} · completed',
        ),
        const _Chip('Source record', T.teal),
        const _Label('Bleeding days'),
        if (c.flowDays.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'These dates come from your saved period start and end. No flow detail was saved for them — unknown, never assumed light.',
              style: _S.bodyS.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        for (final date in c.bleedingDates)
          _bleedingDayEvidenceRow(context, data, c, date, onEdit),
        if (records.isNotEmpty) const _Label('Saved experiences'),
        for (final s in records)
          _EvidenceRow(
            leading: Icon(Icons.circle, size: 10, color: catColor(s.category)),
            title: '${s.label} · ${fmtShort(s.date.epochDay)}',
            trailing: _cap(s.severity.name),
            color: s.isHeavier ? T.berry : T.violet,
            onTap: () => openSymptomSheet(context, data, s, onEdit),
          ),
        if (moods.isNotEmpty) const _Label('Saved moods'),
        for (final m in moods)
          _EvidenceRow(
            leading: Icon(Icons.circle, size: 10, color: toneColor(m.tone)),
            title: '${m.label} · ${fmtShort(m.date.epochDay)}',
            trailing: toneLabel(m.tone),
            color: toneColor(m.tone),
          ),
      ],
    ),
  );
}

void openFlowDaySheet(
  BuildContext context,
  PatternsExperienceData data,
  PatternsFlowDay day,
) {
  openSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          fmtDate(day.date.epochDay),
          phaseLabel(data, day.date.epochDay),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(flowName(day.flow.name), flowColor(day.flow.name)),
            if (day.color != null)
              _Chip(
                'Color: ${_cap(day.color!.name)}',
                T.coralDeep,
                filled: false,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'A flow record describes that day exactly as you saved it.',
          style: _S.bodyS.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    ),
  );
}

void openSymptomSheet(
  BuildContext context,
  PatternsExperienceData data,
  PatternsSymptomRecord s,
  ValueChanged<String>? onEdit,
) {
  openSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          s.label,
          '${fmtDate(s.date.epochDay)} · ${phaseLabel(data, s.date.epochDay)}',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(catName(s.category), catColor(s.category)),
            _Chip(_cap(s.severity.name), s.isHeavier ? T.berry : T.violet),
            if (s.isHeavier) const _Chip('Heavier day', T.berry, filled: false),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          s.isHeavier
              ? '“Heavier” is only a display threshold on the severity you saved. It counts once per day, however many things you recorded.'
              : 'A lighter saved record. Missing days are blank — never assumed to be good days.',
          style: _S.bodyS.copyWith(fontStyle: FontStyle.italic, height: 1.5),
        ),
        if (onEdit != null) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onEdit(s.id);
              },
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Edit record'),
              style: TextButton.styleFrom(
                foregroundColor: T.inkSoft,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

void openCareLogSheet(
  BuildContext context,
  PatternsExperienceData data,
  String name,
) {
  final recs = data.care.where((c) => c.actionLabel == name).toList()
    ..sort((a, b) => a.date.epochDay.compareTo(b.date.epochDay));
  int count(String key) => recs.where((r) => r.outcome.name == key).length;
  final better = count('better'), same = count('same'), worse = count('worse');
  openSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          name,
          'Tried ${_plural(recs.length, 'time')} · outcomes exactly as you recorded them',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (better > 0) _Chip('Better ×$better', T.green),
            if (same > 0) _Chip('Same ×$same', T.lake),
            if (worse > 0) _Chip('Worse ×$worse', T.coral),
          ],
        ),
        const _Label('Your records'),
        for (final r in recs)
          _EvidenceRow(
            leading: Icon(
              Icons.spa_outlined,
              size: 14,
              color: outcomeColor(r.outcome.name),
            ),
            title:
                '${fmtDate(r.date.epochDay)} · ${phaseLabel(data, r.date.epochDay)}',
            trailing: outcomeLabel(r.outcome.name),
            color: outcomeColor(r.outcome.name),
            note: r.reflection,
            emptyNote: r.reflection == null ? 'No reflection saved' : null,
          ),
      ],
    ),
  );
}

void openCategorySheet(
  BuildContext context,
  PatternsExperienceData data,
  PatternsSymptomCategory cat,
  ValueChanged<String>? onEdit,
) {
  final items = itemDays(data, cat).entries.toList()
    ..sort((a, b) {
      final d = b.value.length.compareTo(a.value.length);
      return d != 0 ? d : a.key.compareTo(b.key);
    });
  final maxDays = items.isEmpty ? 1 : items.first.value.length;
  final evidence = _harderRecordsForCategory(data, cat);
  openSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          catName(cat),
          '${_plural(categoryDays(data)[cat]!.length, 'saved day')} across this report',
        ),
        const _Label('What took the most room'),
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => openItemSheet(context, data, cat, e.key, onEdit),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: T.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (e.value.length / maxDays).clamp(
                          0.08,
                          1.0,
                        ),
                        child: Container(
                          height: 9,
                          decoration: BoxDecoration(
                            color: catColor(cat).withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.value.length}d',
                    style: const TextStyle(
                      fontSize: 12,
                      color: T.inkSoft,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const _Label('Recent evidence'),
        for (final record in evidence.take(6))
          _EvidenceRow(
            leading: Icon(
              Icons.circle,
              size: 10,
              color: catColor(record.category),
            ),
            title: '${record.label} · ${fmtDate(record.date.epochDay)}',
            trailing: record.symptom == null
                ? 'Mood'
                : _cap(record.symptom!.severity.name),
            color: catColor(record.category),
            onTap: () => record.symptom != null
                ? openSymptomSheet(context, data, record.symptom!, onEdit)
                : openDaySheet(context, data, record.date.epochDay, onEdit),
          ),
        const SizedBox(height: 8),
        const _QuietInfo(
          'How this is counted',
          'A calendar day counts toward a category once, even if you saved several things in it. Categories overlap by design — one hard day often holds pain and feelings together.',
        ),
      ],
    ),
  );
}

void openItemSheet(
  BuildContext context,
  PatternsExperienceData data,
  PatternsSymptomCategory cat,
  String item,
  ValueChanged<String>? onEdit,
) {
  final recs = _harderRecordsForCategory(
    data,
    cat,
  ).where((record) => record.label == item).toList();
  final days = recs.map((r) => r.date.epochDay).toSet().length;
  openSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(item, '${_plural(days, 'saved day')} · ${catName(cat)}'),
        for (final record in recs.take(12))
          _EvidenceRow(
            leading: Icon(
              Icons.circle,
              size: 10,
              color: catColor(record.category),
            ),
            title:
                '${fmtDate(record.date.epochDay)} · ${phaseLabel(data, record.date.epochDay)}',
            trailing: record.symptom == null
                ? 'Mood'
                : _cap(record.symptom!.severity.name),
            color: catColor(record.category),
            onTap: () => record.symptom != null
                ? openSymptomSheet(context, data, record.symptom!, onEdit)
                : openDaySheet(context, data, record.date.epochDay, onEdit),
          ),
        if (recs.length > 12)
          Text('+ ${recs.length - 12} earlier saved records', style: _S.bodyS),
      ],
    ),
  );
}

void openDaySheet(
  BuildContext context,
  PatternsExperienceData data,
  int epochDay,
  ValueChanged<String>? onEdit,
) {
  if (epochDay > data.today.epochDay) {
    openSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(fmtDate(epochDay), 'A day still ahead'),
          Text(
            'This day has not happened yet, so there is nothing to recap.',
            style: _S.bodyM,
          ),
        ],
      ),
    );
    return;
  }

  PatternsFlowDay? flow;
  int? flowCycleIndex;
  bool flowCurrent = false;
  for (var i = 0; i < data.completedCycles.length; i++) {
    for (final f in data.completedCycles[i].flowDays) {
      if (f.date.epochDay == epochDay) {
        flow = f;
        flowCycleIndex = i;
      }
    }
  }
  if (flow == null) {
    for (final f in data.currentCycle?.flowDays ?? const <PatternsFlowDay>[]) {
      if (f.date.epochDay == epochDay) {
        flow = f;
        flowCurrent = true;
      }
    }
  }
  // Period dates are the source of truth for bleeding. A period day without
  // a flow entry is an honest unknown, never an empty day.
  final period = isPeriodDay(data, epochDay);
  final syms = data.symptoms.where((s) => s.date.epochDay == epochDay).toList();
  final moods = data.moods.where((m) => m.date.epochDay == epochDay).toList();
  final cares = data.care.where((c) => c.date.epochDay == epochDay).toList();
  final ci = cycleIndexFor(data, epochDay);
  final empty =
      flow == null && !period && syms.isEmpty && moods.isEmpty && cares.isEmpty;

  openSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(fmtDate(epochDay), phaseLabel(data, epochDay)),
        if (empty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.sand.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Nothing saved for this day.\nA blank day is simply an unrecorded one.',
              style: TextStyle(
                fontSize: 13,
                color: T.inkSoft,
                height: 1.55,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (flow != null)
          _EvidenceRow(
            leading: FlowDrop(flowKey: flow.flow.name, size: 16),
            title: 'Bleeding · ${flowName(flow.flow.name)}',
            trailing: flowCurrent
                ? 'This cycle'
                : 'Cycle ${(flowCycleIndex ?? 0) + 1}',
            color: flowColor(flow.flow.name),
            meta: flow.color == null
                ? null
                : 'Color saved: ${_cap(flow.color!.name)}',
          )
        else if (period)
          _EvidenceRow(
            leading: const _PeriodDayMark(size: 14),
            title: 'Period day',
            trailing: 'No flow recorded',
            color: ExperienceColors.phasePeriod,
            meta:
                'A recorded period day — flow detail was not saved. Unknown, never assumed light.',
          ),
        for (final s in syms)
          _EvidenceRow(
            leading: Icon(Icons.circle, size: 10, color: catColor(s.category)),
            title: '${s.label} · ${catName(s.category)}',
            trailing: _cap(s.severity.name),
            color: s.isHeavier ? T.berry : T.violet,
            onTap: () => openSymptomSheet(context, data, s, onEdit),
          ),
        for (final m in moods)
          _EvidenceRow(
            leading: Icon(Icons.circle, size: 10, color: toneColor(m.tone)),
            title: '${m.label} · mood',
            trailing: toneLabel(m.tone),
            color: toneColor(m.tone),
          ),
        for (final c in cares)
          _EvidenceRow(
            leading: Icon(
              Icons.spa_outlined,
              size: 14,
              color: outcomeColor(c.outcome.name),
            ),
            title: c.actionLabel,
            trailing: outcomeLabel(c.outcome.name),
            color: outcomeColor(c.outcome.name),
            note: c.reflection,
            emptyNote: c.reflection == null ? 'No reflection saved' : null,
          ),
        const SizedBox(height: 16),
        if (ci != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: T.berry.withValues(alpha: 0.12),
                foregroundColor: T.berry,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(
                'Open in Cycle ${ci + 1}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                openCycleSheet(context, data, ci, onEdit);
              },
            ),
          )
        else
          Text(
            data.currentCycle != null &&
                    epochDay >= data.currentCycle!.startDate.epochDay
                ? 'Part of this cycle — still being written.'
                : 'Outside the saved cycles in this report.',
            style: _S.bodyS.copyWith(fontStyle: FontStyle.italic),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Flow marks — the segmented droplet is Patterns' compact translation of
// Today's bleeding selector: one fixed 16 x 16 cell holding an ~11 x 14 soft
// teardrop in Today's exact bleeding color (#C95D3A for every degree). The
// droplet is divided
// into four stacked bands by quiet 0.5 px slivers of the surrounding warm
// background — never drawn separator lines. Spotting fills the bottom band,
// Light the bottom two, Medium the bottom three, and each partial state is
// always wrapped in the complete #C95D3A droplet outline so the unfilled
// upper silhouette never collapses into a bowl or bar. Heavy is one solid
// solid mass with a 1.75 px contour — its notches disappear and it never
// reads weaker than Light. _PeriodDayMark is the quiet sibling: a recorded
// period day whose flow was never saved. It is a pale outlined ring — never
// a droplet (so it can never be mistaken for Spotting) and never nothing
// (so a period day never reads as blank).
// ---------------------------------------------------------------------------
class FlowDrop extends StatelessWidget {
  final String flowKey;
  final double size;
  const FlowDrop({super.key, required this.flowKey, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Flow: ${flowName(flowKey)}',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _SegmentedFlowPainter(_flowRank(flowKey) + 1),
      ),
    );
  }
}

/// Paints one soft teardrop divided into four stacked bands, filled from the
/// bottom. [bands] is 1 (Spotting) through 4 (Heavy). The construction is
/// identical at every cell size — 16 px in strips and sheets, 20 px in
/// legends — so the degree reads the same wherever it appears.
class _SegmentedFlowPainter extends CustomPainter {
  final int bands;
  const _SegmentedFlowPainter(this.bands);

  // Today's exact bleeding colors — never the page coral/ember tokens.
  static const _bandColor = Color(0xFFC95D3A);
  static const _heavyColor = Color(0xFFC95D3A);

  /// Quiet gap between bands, left as unpainted background.
  static const _gap = 0.5;

  /// The Today-established soft teardrop: a gently pointed tip tapering into
  /// a full semicircular base, normalized to the supplied rect.
  static Path _droplet(Rect r) {
    final cx = r.center.dx;
    final w = r.width, h = r.height;
    final rad = w / 2;
    final base = Offset(cx, r.bottom - rad);
    return Path()
      ..moveTo(cx, r.top)
      ..cubicTo(
        cx + w * 0.05,
        r.top + h * 0.26,
        cx + rad,
        r.top + h * 0.46,
        cx + rad,
        base.dy,
      )
      ..arcTo(Rect.fromCircle(center: base, radius: rad), 0, math.pi, false)
      ..cubicTo(
        cx - rad,
        r.top + h * 0.46,
        cx - w * 0.05,
        r.top + h * 0.26,
        cx,
        r.top,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dropW = size.width * 11 / 16;
    final dropH = size.height * 14 / 16;
    final rect = Rect.fromLTWH(
      (size.width - dropW) / 2,
      (size.height - dropH) / 2,
      dropW,
      dropH,
    );
    final droplet = _droplet(rect);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    if (bands >= 4) {
      // Heavy — one solid mass with a 1.75 px contour.
      canvas.drawPath(droplet, Paint()..color = _heavyColor);
      canvas.drawPath(
        droplet,
        outline
          ..color = _heavyColor
          ..strokeWidth = 1.75,
      );
      return;
    }

    // Spotting / Light / Medium — segmented bottom fill first…
    final bandH = rect.height / 4;
    canvas.save();
    canvas.clipPath(droplet);
    final fill = Paint()..color = _bandColor;
    for (var i = 0; i < bands; i++) {
      final slot = 3 - i; // fill upward from the bottom band
      canvas.drawRect(
        Rect.fromLTRB(
          rect.left - 1,
          rect.top + slot * bandH + _gap / 2,
          rect.right + 1,
          rect.top + (slot + 1) * bandH - _gap / 2,
        ),
        fill,
      );
    }
    canvas.restore();
    // …then the complete droplet outline around the partial fill, so the
    // unfilled upper silhouette still reads unmistakably as a droplet.
    canvas.drawPath(
      droplet,
      outline
        ..color = _bandColor
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_SegmentedFlowPainter old) => old.bands != bands;
}

class _PeriodDayMark extends StatelessWidget {
  final double size;
  const _PeriodDayMark({this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Period day — flow not recorded',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: ExperienceColors.phasePeriod.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: ExperienceColors.phasePeriod.withValues(alpha: 0.55),
            width: 1.3,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated line chart (chronological, keyed tappable points)
// ---------------------------------------------------------------------------
class TrendLineChart extends StatefulWidget {
  final List<double> values;
  final List<String> xLabels;
  final List<String>? subLabels;
  final List<String> valueLabels;
  final double minY, maxY;
  final List<double> grid;
  final Color lineColor;
  final Color pointColor;
  final double height;
  final String semantics;
  final List<Key> pointKeys;
  final ValueChanged<int>? onPointTap;
  const TrendLineChart({
    super.key,
    required this.values,
    required this.xLabels,
    required this.valueLabels,
    required this.minY,
    required this.maxY,
    required this.grid,
    required this.semantics,
    required this.pointKeys,
    this.subLabels,
    this.lineColor = T.berry,
    this.pointColor = T.coral,
    this.height = 220,
    this.onPointTap,
  });

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();

  /// Point geometry. With one or two observations the anchors are comfortably
  /// inset so a small sample reads as a quiet reading — never stretched
  /// edge-to-edge like a full trend.
  static Offset pointFor(
    int i,
    int n,
    double v,
    double minY,
    double maxY,
    Size s,
  ) {
    const padL = 26.0, padR = 26.0, padT = 32.0, padB = 38.0;
    final usable = s.width - padL - padR;
    final double x;
    if (n <= 1) {
      x = padL + usable / 2;
    } else if (n == 2) {
      x = padL + usable * (i == 0 ? 0.24 : 0.76);
    } else {
      x = padL + i * usable / (n - 1);
    }
    final span = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    final y = padT + (1 - (v - minY) / span) * (s.height - padT - padB);
    return Offset(x, y);
  }
}

class _TrendLineChartState extends State<TrendLineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semantics,
      child: LayoutBuilder(
        builder: (context, cons) {
          final size = Size(cons.maxWidth, widget.height);
          final n = widget.values.length;
          final pts = [
            for (var i = 0; i < n; i++)
              TrendLineChart.pointFor(
                i,
                n,
                widget.values[i],
                widget.minY,
                widget.maxY,
                size,
              ),
          ];
          return SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) => CustomPaint(
                    size: size,
                    painter: _TrendPainter(
                      values: widget.values,
                      xLabels: widget.xLabels,
                      subLabels: widget.subLabels,
                      valueLabels: widget.valueLabels,
                      minY: widget.minY,
                      maxY: widget.maxY,
                      grid: widget.grid,
                      lineColor: widget.lineColor,
                      pointColor: widget.pointColor,
                      progress: Curves.easeOutCubic.transform(_c.value),
                    ),
                  ),
                ),
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: pts[i].dx - 22,
                    top: pts[i].dy - 22,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      key: widget.pointKeys[i],
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onPointTap == null
                          ? null
                          : () => widget.onPointTap!(i),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final List<String> xLabels;
  final List<String>? subLabels;
  final List<String> valueLabels;
  final double minY, maxY;
  final List<double> grid;
  final Color lineColor, pointColor;
  final double progress;
  _TrendPainter({
    required this.values,
    required this.xLabels,
    required this.valueLabels,
    required this.minY,
    required this.maxY,
    required this.grid,
    required this.lineColor,
    required this.pointColor,
    required this.progress,
    this.subLabels,
  });

  void _text(
    Canvas canvas,
    String t,
    Offset at,
    TextStyle style, {
    Alignment align = Alignment.center,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == Alignment.center
        ? at.dx - tp.width / 2
        : (align == Alignment.centerRight ? at.dx - tp.width : at.dx);
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    const gridStyle = TextStyle(fontSize: 10, color: T.inkSoft);

    for (final g in grid) {
      final y = TrendLineChart.pointFor(0, n, g, minY, maxY, size).dy;
      final paint = Paint()
        ..color = T.line
        ..strokeWidth = 1;
      for (double x = 0; x < size.width - 14; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(x + 3.5, y), paint);
      }
      _text(
        canvas,
        g.toStringAsFixed(0),
        Offset(size.width - 2, y - 12),
        gridStyle,
        align: Alignment.centerRight,
      );
    }

    final pts = [
      for (var i = 0; i < n; i++)
        TrendLineChart.pointFor(i, n, values[i], minY, maxY, size),
    ];

    if (n > 1) {
      final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < n; i++) {
        linePath.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }

    // Staggered appearance that always settles: at progress 1 every point —
    // including the final one — and its labels are fully present.
    for (var i = 0; i < n; i++) {
      final appear = (progress * n - i).clamp(0.0, 1.0);
      if (appear <= 0) continue;
      final p = pts[i];
      final r = 5.2 * appear;
      canvas.drawCircle(p, r + 3.2, Paint()..color = T.surface);
      canvas.drawCircle(
        p,
        r + 1.6,
        Paint()..color = pointColor.withValues(alpha: 0.22),
      );
      canvas.drawCircle(p, r, Paint()..color = pointColor);
      _text(
        canvas,
        valueLabels[i],
        Offset(p.dx, p.dy - 27),
        TextStyle(
          fontFamily: _serif,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: T.ink.withValues(alpha: appear),
        ),
      );
      _text(
        canvas,
        xLabels[i],
        Offset(p.dx, size.height - 32),
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: T.inkSoft.withValues(alpha: appear),
        ),
      );
      if (subLabels != null) {
        _text(
          canvas,
          subLabels![i],
          Offset(p.dx, size.height - 17),
          TextStyle(
            fontSize: 9.5,
            color: T.inkSoft.withValues(alpha: appear * 0.85),
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// VIEW 1 — Cycles & bleeding
// ---------------------------------------------------------------------------
class CyclesView extends StatelessWidget {
  final PatternsExperienceData data;
  final ValueChanged<String>? onEdit;
  const CyclesView({super.key, required this.data, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cycles = data.completedCycles;
    final n = cycles.length;
    final current = data.currentCycle;

    final children = <Widget>[];

    if (n >= 2) {
      final lengths = [for (final c in cycles) c.lengthDays];
      final minL = _minOf(lengths), maxL = _maxOf(lengths);
      final longestIdx = lengths.indexOf(maxL);
      final gridSet = <double>{
        minL.toDouble(),
        ((minL + maxL) / 2).roundToDouble(),
        maxL.toDouble(),
      }.toList()..sort();
      final takeaway = minL == maxL
          ? 'Each of your $n completed cycles ran $minL days — steady across the records you saved.'
          : 'Your cycles ran $minL–$maxL days, oldest to newest. '
                '${_moFull[_dt(cycles[longestIdx].startDate.epochDay).month - 1]} was the longest.';
      children.add(
        _Section(
          number: '01',
          question: 'How long were they?',
          children: [
            TrendLineChart(
              values: [for (final l in lengths) l.toDouble()],
              xLabels: [for (final c in cycles) fmtShort(c.startDate.epochDay)],
              valueLabels: [for (final l in lengths) '${l}d'],
              minY: (minL - 2).toDouble(),
              maxY: (maxL + 2).toDouble(),
              // A steady two-or-more-cycle reading already has its factual
              // value on every point. Repeating the same grid label at the
              // far edge creates an orphan number (for example, a lone
              // “36”) without adding evidence.
              grid: minL == maxL ? const <double>[] : gridSet,
              lineColor: T.berry,
              pointColor: T.coral,
              pointKeys: [
                for (final c in cycles)
                  ValueKey('patterns-line-point-${c.periodId}'),
              ],
              semantics:
                  'Line chart of $n completed cycle lengths, oldest to newest, between $minL and $maxL days. Tap a point for its source record.',
              onPointTap: (i) => openCycleSheet(context, data, i, onEdit),
            ),
            const SizedBox(height: 18),
            _Takeaway(takeaway),
            _Scope(
              '${_plural(n, 'completed cycle')} · ${_rangeLabel(data)} · tap any point for its record',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openSheet(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SheetHeader(
                        'All cycle records',
                        '${_plural(n, 'completed cycle')}, oldest first',
                      ),
                      for (var i = 0; i < n; i++)
                        _EvidenceRow(
                          leading: const Icon(
                            Icons.loop,
                            size: 14,
                            color: T.berry,
                          ),
                          title:
                              'Cycle ${i + 1} · ${fmtShort(cycles[i].startDate.epochDay)} – ${fmtShort(cycles[i].nextStartDate.epochDay - 1)}',
                          trailing: _plural(cycles[i].lengthDays, 'day'),
                          color: T.berry,
                          onTap: () => openCycleSheet(context, data, i, onEdit),
                        ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('All cycle records'),
                style: TextButton.styleFrom(
                  foregroundColor: T.berry,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (n == 1) {
      final c = cycles.first;
      children.add(
        _Section(
          number: '01',
          question: 'Your one completed cycle',
          children: [
            _EvidenceRow(
              leading: const Icon(Icons.loop, size: 14, color: T.berry),
              title:
                  'Cycle 1 · ${fmtDate(c.startDate.epochDay)} – ${fmtShort(c.nextStartDate.epochDay - 1)}',
              trailing: _plural(c.lengthDays, 'day'),
              color: T.berry,
              onTap: () => openCycleSheet(context, data, 0, onEdit),
            ),
            Text(
              'A length trend line arrives once a second cycle completes — nothing is averaged or guessed in the meantime.',
              style: _S.bodyS.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (n >= 1) {
      children.add(
        _Section(
          number: '02',
          question: 'How did bleeding compare?',
          note:
              'Each row is one recorded period, start to end. Period dates come from your saved records; flow detail enriches single days within them.',
          children: [
            const _FlowLegend(),
            const SizedBox(height: 18),
            for (var i = 0; i < n; i++)
              _FlowStrip(data: data, index: i, onEdit: onEdit),
            const SizedBox(height: 10),
            _Takeaway(_bleedingTakeaway(cycles)),
            const _Scope(
              'One row per recorded period · tap any day for its full record',
            ),
            const _QuietInfo(
              'How to read a strip',
              'Every marked day is a bleeding day from your saved period start and end. A drop shows the flow you saved that day — spotting, light, medium or heavy, exactly as in Today. A pale ring is a period day with no flow saved: an honest unknown, never assumed light. A coral outline marks the highest recorded day. When you saved a colour for a day, it appears in that day’s record.',
            ),
          ],
        ),
      );
    }

    if (current != null) {
      if (n == 0) {
        children.add(
          _Section(
            number: '01',
            question: 'A first cycle is under way',
            children: [
              Text(
                'One period start, saved on ${fmtDate(current.startDate.epochDay)}. Cycle charts arrive once a second start completes this cycle.',
                style: _S.bodyM,
              ),
              const SizedBox(height: 16),
              _CurrentCycleNote(data: data, hasCompleted: false),
            ],
          ),
        );
      } else {
        children.add(_CurrentCycleNote(data: data, hasCompleted: true));
      }
    }

    return _Scroll(children: children);
  }

  String _bleedingTakeaway(List<PatternsCompletedCycle> cycles) {
    final spans = [for (final c in cycles) c.bleedingDates.length];
    final totalDays = spans.fold<int>(0, (sum, e) => sum + e);
    final flowSaved = cycles.fold<int>(0, (sum, c) => sum + c.flowDays.length);
    final mn = _minOf(spans), mx = _maxOf(spans);
    final parts = <String>[
      mn == mx
          ? 'Each recorded period ran ${_plural(mn, 'day')}.'
          : 'Your recorded periods ran $mn–$mx days, start to end.',
    ];
    if (flowSaved == 0) {
      parts.add(
        'No flow detail was saved — those period days stay honestly unknown, never assumed light.',
      );
    } else if (flowSaved < totalDays) {
      parts.add(
        'Flow detail was saved on $flowSaved of ${_plural(totalDays, 'period day')}; the rest are simply unrecorded.',
      );
    }
    final heavyNums = <int>[];
    for (final c in cycles) {
      for (final f in c.flowDays) {
        if (f.flow.name == 'heavy') {
          heavyNums.add(f.date.epochDay - c.startDate.epochDay + 1);
          break;
        }
      }
    }
    if (heavyNums.isNotEmpty) {
      parts.add(
        'The heaviest saved day was usually around day ${_median(heavyNums)}.',
      );
    }
    final spotting = cycles
        .where((c) => c.flowDays.any((f) => f.flow.name == 'spotting'))
        .length;
    if (spotting > 0) {
      parts.add(
        'Spotting was saved on $spotting of ${_plural(cycles.length, 'period')}.',
      );
    }
    return parts.join(' ');
  }
}

class _FlowLegend extends StatelessWidget {
  const _FlowLegend();
  @override
  Widget build(BuildContext context) {
    Widget item(String key) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlowDrop(flowKey: key, size: 20),
        const SizedBox(width: 5),
        Text(
          flowName(key),
          style: const TextStyle(
            fontSize: 11.5,
            color: T.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item('spotting'),
        item('light'),
        item('medium'),
        item('heavy'),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PeriodDayMark(size: 12),
            SizedBox(width: 5),
            Text(
              'Period · no flow recorded',
              style: TextStyle(
                fontSize: 11.5,
                color: T.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: T.coralSoft,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: T.coral, width: 1.4),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Highest day',
              style: TextStyle(
                fontSize: 11.5,
                color: T.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One recorded period, start to end. Every bleeding date is represented —
/// a saved flow degree as the canonical segmented drop, an unsaved one as
/// the quiet period mark. Every day opens the full date sheet.
class _FlowStrip extends StatelessWidget {
  final PatternsExperienceData data;
  final int index;
  final ValueChanged<String>? onEdit;
  const _FlowStrip({
    required this.data,
    required this.index,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cycle = data.completedCycles[index];
    final dates = cycle.bleedingDates;
    final maxRank = cycle.flowDays.isEmpty
        ? -1
        : cycle.flowDays
              .map((f) => _flowRank(f.flow.name))
              .reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        key: ValueKey('patterns-flow-strip-${cycle.periodId}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => openCycleSheet(context, data, index, onEdit),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: T.line)),
          ),
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mo[_dt(cycle.startDate.epochDay).month - 1],
                      style: const TextStyle(
                        fontFamily: _serif,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: T.ink,
                      ),
                    ),
                    Text(
                      'Started ${fmtShort(cycle.startDate.epochDay)}',
                      style: const TextStyle(fontSize: 11.5, color: T.inkSoft),
                    ),
                    Text(
                      _plural(dates.length, 'bleeding day'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: T.inkSoft,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 8,
                  children: [
                    for (final date in dates)
                      _periodDayMark(context, cycle, date, maxRank),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${cycle.lengthDays}-day cycle',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: T.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodDayMark(
    BuildContext context,
    PatternsCompletedCycle cycle,
    LocalDate date,
    int maxRank,
  ) {
    final f = cycle.flowFor(date);
    final dayN = date.epochDay - cycle.startDate.epochDay + 1;
    final isMax = f != null && _flowRank(f.flow.name) == maxRank;
    return GestureDetector(
      key: ValueKey('patterns-flow-day-${cycle.periodId}-${date.epochDay}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => openDaySheet(context, data, date.epochDay, onEdit),
      child: Tooltip(
        message: f != null
            ? 'Day $dayN · ${flowName(f.flow.name)}'
            : 'Day $dayN · period day, flow not recorded',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isMax
                      ? T.coral.withValues(alpha: 0.85)
                      : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: f != null
                  ? FlowDrop(flowKey: f.flow.name, size: 16)
                  : const _PeriodDayMark(size: 14),
            ),
            const SizedBox(height: 2),
            Text(
              '$dayN',
              style: const TextStyle(fontSize: 9, color: T.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentCycleNote extends StatelessWidget {
  final PatternsExperienceData data;
  final bool hasCompleted;
  const _CurrentCycleNote({required this.data, required this.hasCompleted});
  @override
  Widget build(BuildContext context) {
    final current = data.currentCycle!;
    final day = data.today.epochDay - current.startDate.epochDay + 1;
    final dates = current.bleedingDatesThrough(data.today);
    return Container(
      key: const ValueKey('patterns-current-state'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ExperienceRadius.card),
        border: Border.all(color: T.line, width: 1.2),
        color: T.surface,
        boxShadow: ExperienceShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, size: 16, color: T.inkSoft),
              const SizedBox(width: 6),
              Text('This cycle so far · day $day', style: _S.titleM),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final date in dates)
                Builder(
                  builder: (context) {
                    final f = current.flowFor(date);
                    return GestureDetector(
                      key: ValueKey(
                        'patterns-flow-day-${current.periodId}-${date.epochDay}',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          openDaySheet(context, data, date.epochDay, null),
                      child: Tooltip(
                        message: f != null
                            ? '${fmtShort(date.epochDay)} · ${flowName(f.flow.name)}'
                            : '${fmtShort(date.epochDay)} · period day, flow not recorded',
                        child: f != null
                            ? FlowDrop(flowKey: f.flow.name, size: 16)
                            : const _PeriodDayMark(size: 14),
                      ),
                    );
                  },
                ),
            ],
          ),
          if (current.flowDays.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Period in progress from your saved start. No flow detail saved yet — unknown, never assumed light.',
              style: _S.bodyS.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            hasCompleted
                ? 'Early records only — the completed-cycle views above never include this unfinished cycle.'
                : 'Early records only — comparisons arrive once this cycle completes.',
            style: _S.bodyS.copyWith(fontStyle: FontStyle.italic, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VIEW 2 — Mood & patterns
// ---------------------------------------------------------------------------
class MoodView extends StatelessWidget {
  final PatternsExperienceData data;
  final ValueChanged<String>? onEdit;
  const MoodView({super.key, required this.data, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cycles = data.completedCycles;
    final n = cycles.length;
    final harder = [for (final c in cycles) harderEpochsIn(data, c).length];
    final cats = categoryDays(data);
    final orderedCats = [...PatternsSymptomCategory.values]
      ..sort((a, b) {
        final d = cats[b]!.length.compareTo(cats[a]!.length);
        return d != 0 ? d : a.name.compareTo(b.name);
      });
    final maxCat = cats[orderedCats.first]!.length;
    final harderRecs = _harderRecordsInCompletedCycles(data);

    var sectionNo = 0;
    String nextNo() => '${++sectionNo}'.padLeft(2, '0');

    Widget overall() {
      final totalHarder = harder.fold<int>(0, (sum, e) => sum + e);
      String? takeaway;
      if (n >= 2) {
        if (totalHarder == 0) {
          takeaway =
              'No harder days were saved in these cycles. Blank days stay blank — never assumed easy.';
        } else {
          var near = 0;
          for (final record in harderRecs) {
            final ci = cycleIndexFor(data, record.date.epochDay)!;
            final c = cycles[ci];
            final isFlow = c.isBleedingDate(
              LocalDate.fromDateTime(_dt(record.date.epochDay)),
            );
            final before = c.nextStartDate.epochDay - record.date.epochDay;
            if (isFlow || before <= 7) near++;
          }
          takeaway =
              'Across ${_plural(n, 'cycle')} you saved ${_plural(totalHarder, 'harder day')}'
              '${near * 2 >= totalHarder ? ', mostly around bleeding or the days just before it.' : ', spread through the cycle.'}'
              ' A day counts once, however much it carried.';
        }
      }
      return _Section(
        number: nextNo(),
        question: 'How have recent cycles felt overall?',
        children: [
          if (n >= 2) ...[
            TrendLineChart(
              values: [for (final h in harder) h.toDouble()],
              xLabels: [for (final c in cycles) fmtShort(c.startDate.epochDay)],
              valueLabels: [for (final h in harder) '$h'],
              minY: 0,
              maxY: (harder.isEmpty ? 0 : _maxOf(harder)) + 2 < 4
                  ? 4
                  : (_maxOf(harder) + 2).toDouble(),
              grid: [
                if ((((_maxOf(harder) + 2) < 4
                                ? 4.0
                                : (_maxOf(harder) + 2).toDouble()) /
                            2)
                        .roundToDouble() >
                    0)
                  (((_maxOf(harder) + 2) < 4
                              ? 4.0
                              : (_maxOf(harder) + 2).toDouble()) /
                          2)
                      .roundToDouble(),
              ],
              lineColor: T.violet,
              pointColor: T.berry,
              pointKeys: [
                for (final c in cycles)
                  ValueKey('patterns-line-point-${c.periodId}'),
              ],
              semantics:
                  'Line chart of harder days per completed cycle. Tap a point for the cycle record.',
              onPointTap: (i) => openCycleSheet(context, data, i, onEdit),
            ),
            const SizedBox(height: 18),
            _Takeaway(takeaway!),
          ] else if (n == 1) ...[
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => openCycleSheet(context, data, 0, onEdit),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: T.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: T.line),
                  boxShadow: ExperienceShadows.card,
                ),
                child: Text(
                  'Cycle 1 held ${_plural(harder[0], 'harder day')}.',
                  style: _S.bodyL.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A trend line arrives once two cycles have completed.',
              style: _S.bodyS.copyWith(fontStyle: FontStyle.italic),
            ),
          ] else ...[
            Text(
              'Comparisons between cycles arrive once a completed cycle exists. Anything you save in the current cycle still appears in the calendar and day recaps below.',
              style: _S.bodyM.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (n >= 1)
            _Scope(
              'Days with a saved symptom, difficult feeling, or physical check-in · ${_plural(n, 'completed cycle')} · unrecorded days stay blank — never counted as easy',
            ),
          if (n >= 1)
            const _QuietInfo(
              'What “harder day” means',
              'A harder day has a symptom, difficult feeling, or physical check-in you saved. It counts once even when several records share that date. Blank days are simply unrecorded.',
            ),
        ],
      );
    }

    Widget space() => _Section(
      number: nextNo(),
      question: 'What has been taking up the most space?',
      children: [
        for (final cat in orderedCats)
          if (cats[cat]!.isNotEmpty)
            _CategoryRow(
              data: data,
              cat: cat,
              days: cats[cat]!.length,
              maxDays: maxCat,
              onEdit: onEdit,
            ),
        const SizedBox(height: 12),
        Text(
          'Categories overlap on purpose — one day can hold pain and feelings together, so these don’t add to 100%.',
          style: _S.bodyS.copyWith(fontStyle: FontStyle.italic, height: 1.5),
        ),
        const _Scope(
          'Days with at least one record in each category · symptoms, difficult feelings, and physical check-ins saved anywhere in this report · tap a row for details',
        ),
      ],
    );

    Widget rhythm() => _Section(
      number: nextNo(),
      question: 'What tends to return, and when?',
      children: [
        if (harderRecs.isEmpty)
          Text(
            'No harder days were saved in these cycles, so there is nothing to place yet.',
            style: _S.bodyM.copyWith(fontStyle: FontStyle.italic),
          )
        else
          RhythmPanel(data: data, onEdit: onEdit),
      ],
    );

    Widget calendarInvite() => _Section(
      number: nextNo(),
      question: 'Want the actual dates beside the story?',
      children: [_CalendarInvite(data: data, onEdit: onEdit)],
    );

    Widget evidence() => _Section(
      number: nextNo(),
      question: 'Supporting evidence: ${_plural(n, 'completed cycle')}',
      note: 'The dates underneath the story — kept honest, gaps included.',
      children: [
        _CycleEvidenceStrip(data: data, onEdit: onEdit),
        const _Scope(
          'Each card is one completed cycle: its recorded period start, its true length, and day-by-day records — filled means something was saved that day, a gap means unrecorded · tap a card for the full record',
        ),
      ],
    );

    final secOverall = overall();
    final secSpace = cats.values.any((days) => days.isNotEmpty)
        ? space()
        : null;
    final secRhythm = n >= 1 ? rhythm() : null;
    final secCalendar = calendarInvite();
    final secEvidence = n >= 1 ? evidence() : null;

    return LayoutBuilder(
      builder: (context, cons) {
        final wide = cons.maxWidth > 920;
        return _Scroll(
          children: wide
              ? [
                  if (secSpace != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: secOverall),
                        const SizedBox(width: 46),
                        Expanded(child: secSpace),
                      ],
                    )
                  else
                    secOverall,
                  if (secRhythm != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: secRhythm),
                        const SizedBox(width: 46),
                        Expanded(flex: 4, child: secCalendar),
                      ],
                    )
                  else
                    secCalendar,
                  ?secEvidence,
                ]
              : [secOverall, ?secSpace, ?secRhythm, secCalendar, ?secEvidence],
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final PatternsExperienceData data;
  final PatternsSymptomCategory cat;
  final int days;
  final int maxDays;
  final ValueChanged<String>? onEdit;
  const _CategoryRow({
    required this.data,
    required this.cat,
    required this.days,
    required this.maxDays,
    required this.onEdit,
  });
  @override
  Widget build(BuildContext context) {
    final color = catColor(cat);
    return InkWell(
      key: ValueKey('patterns-category-row-${cat.name}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => openCategorySheet(context, data, cat, onEdit),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: T.line)),
        ),
        padding: const EdgeInsets.fromLTRB(2, 13, 2, 15),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(catName(cat), style: _S.titleM),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (days / (maxDays == 0 ? 1 : maxDays)).clamp(
                        0.06,
                        1.0,
                      ),
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$days',
              style: TextStyle(
                fontFamily: _serif,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: T.inkSoft),
          ],
        ),
      ),
    );
  }
}

// --- Rhythm: whole-cycle placement of harder days --------------------------
class RhythmPanel extends StatefulWidget {
  final PatternsExperienceData data;
  final ValueChanged<String>? onEdit;
  const RhythmPanel({super.key, required this.data, required this.onEdit});
  @override
  State<RhythmPanel> createState() => _RhythmPanelState();
}

class _RhythmPanelState extends State<RhythmPanel> {
  String _selected = 'Everything';

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final cycles = data.completedCycles;
    final harderRecs = _harderRecordsInCompletedCycles(data);
    final counts = <String, int>{};
    for (final r in harderRecs) {
      counts[r.label] = (counts[r.label] ?? 0) + 1;
    }
    final orderedItems = counts.keys.toList()
      ..sort((a, b) {
        final d = counts[b]!.compareTo(counts[a]!);
        return d != 0 ? d : a.compareTo(b);
      });
    final chips = ['Everything', ...orderedItems.take(5)];

    String insightFor(String item) {
      final recs = harderRecs.where((s) => s.label == item).toList();
      if (recs.length < 2) return '';
      var bleed = 0, pre = 0;
      final bleedDays = <int>[];
      for (final r in recs) {
        final ci = cycleIndexFor(data, r.date.epochDay)!;
        final c = cycles[ci];
        if (c.isBleedingDate(LocalDate.fromDateTime(_dt(r.date.epochDay)))) {
          bleed++;
          bleedDays.add(r.date.epochDay - c.startDate.epochDay + 1);
        } else if (c.nextStartDate.epochDay - r.date.epochDay <= 7) {
          pre++;
        }
      }
      if (bleed * 2 >= recs.length && bleedDays.isNotEmpty) {
        return '$item gathered around bleeding day ${_median(bleedDays)}.';
      }
      if (pre * 2 >= recs.length) {
        return '$item showed up mostly in the final few days before bleeding.';
      }
      return '';
    }

    final shown = _selected == 'Everything'
        ? harderRecs
        : harderRecs.where((s) => s.label == _selected).toList();
    const lanes = {
      PatternsSymptomCategory.pain: 0,
      PatternsSymptomCategory.emotions: 1,
      PatternsSymptomCategory.energyAndSleep: 2,
      PatternsSymptomCategory.digestion: 3,
      PatternsSymptomCategory.otherBody: 4,
    };

    final avgLen =
        cycles.fold<int>(0, (s, c) => s + c.lengthDays) / cycles.length;
    final avgBleed =
        cycles.fold<int>(0, (s, c) => s + c.bleedingDates.length) /
        cycles.length;
    final bleedShare = (avgBleed / avgLen).clamp(0.10, 0.30);
    final preShare = (7 / avgLen).clamp(0.14, 0.30);
    final bleedFlex = (bleedShare * 1000).round();
    final preFlex = (preShare * 1000).round();
    final midFlex = (1000 - bleedFlex - preFlex).clamp(1, 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in chips)
              _FilterChip(
                label: chip,
                selected: _selected == chip,
                onTap: () => setState(() => _selected = chip),
              ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, cons) {
            final w = cons.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 26,
                    child: Row(
                      children: [
                        Expanded(
                          flex: bleedFlex,
                          child: Container(color: T.coralSoft),
                        ),
                        Expanded(
                          flex: midFlex,
                          child: Container(color: T.sand),
                        ),
                        Expanded(
                          flex: preFlex,
                          child: Container(
                            color: T.lilac.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        flex: bleedFlex,
                        child: const Text(
                          'Bleeding',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: T.coral,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: midFlex,
                        child: const Text(
                          'Mid-cycle',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: T.inkSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: preFlex,
                        child: const Text(
                          'Days before bleeding',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: T.violet,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 5 * 16.0 + 4,
                  child: Stack(
                    children: [
                      for (final r in shown)
                        Positioned(
                          left: _posOf(data, r) * (w - 14),
                          top: lanes[r.category]! * 16.0,
                          child: GestureDetector(
                            key: ValueKey('patterns-rhythm-point-${r.id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => r.symptom != null
                                ? openSymptomSheet(
                                    context,
                                    data,
                                    r.symptom!,
                                    widget.onEdit,
                                  )
                                : openDaySheet(
                                    context,
                                    data,
                                    r.date.epochDay,
                                    widget.onEdit,
                                  ),
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: catColor(r.category),
                                shape: BoxShape.circle,
                                border: Border.all(color: T.surface, width: 2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        for (final item in orderedItems.take(2))
          _InsightLine(
            color: catColor(
              harderRecs.firstWhere((s) => s.label == item).category,
            ),
            text: insightFor(item),
          ),
        const SizedBox(height: 8),
        Text(
          'Each dot is one harder saved day, placed by where it truly fell in its cycle. Looking back — never looking ahead.',
          style: _S.bodyS.copyWith(fontStyle: FontStyle.italic, height: 1.5),
        ),
        const _QuietInfo(
          'How timing is read',
          'Bleeding-day placement comes from your recorded period starts and ends. “Days before bleeding” counts backward from the following recorded start. Everything else is placed by its real position in its own cycle. Because cycles differ in length, positions are shown as a share of the whole cycle, and the bleeding band is sized by the bleeding days you actually recorded.',
        ),
      ],
    );
  }

  double _posOf(PatternsExperienceData d, _HarderRecord r) {
    final ci = cycleIndexFor(d, r.date.epochDay)!;
    final c = d.completedCycles[ci];
    return ((r.date.epochDay - c.startDate.epochDay) / c.lengthDays).clamp(
      0.0,
      0.985,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? T.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? T.ink : T.line, width: 1.3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? T.surface : T.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _InsightLine extends StatelessWidget {
  final Color color;
  final String text;
  const _InsightLine({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              text,
              style: _S.bodyL.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Calendar invitation + read-only overlay --------------------------------
class _CalendarInvite extends StatelessWidget {
  final PatternsExperienceData data;
  final ValueChanged<String>? onEdit;
  const _CalendarInvite({required this.data, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(ExperienceRadius.card),
        border: Border.all(color: T.line),
        boxShadow: ExperienceShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.calendar_month_outlined, color: T.coral, size: 30),
          const SizedBox(height: 16),
          Text('A read-only calendar for orientation.', style: _S.titleL),
          const SizedBox(height: 8),
          Text(
            'See bleeding, saved moods, body experiences, and honest blanks one month at a time.',
            style: _S.bodyM,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => openCalendarOverlay(context, data, onEdit),
            icon: const Icon(Icons.arrow_outward, size: 18),
            label: const Text('Browse calendar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: T.ink,
              side: const BorderSide(color: T.coral),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

void openCalendarOverlay(
  BuildContext context,
  PatternsExperienceData data,
  ValueChanged<String>? onEdit,
) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close calendar',
    barrierColor: const Color(0x662A1626),
    transitionDuration: MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220),
    pageBuilder: (context, a, b) =>
        _CalendarOverlay(data: data, onEdit: onEdit),
    transitionBuilder: (context, a, b, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _CalendarOverlay extends StatelessWidget {
  final PatternsExperienceData data;
  final ValueChanged<String>? onEdit;
  const _CalendarOverlay({required this.data, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: size.width.clamp(320.0, 820.0),
            height: size.height * 0.88,
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
            decoration: BoxDecoration(
              color: T.bg,
              borderRadius: BorderRadius.circular(ExperienceRadius.hero),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2A2A1626),
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Actual dates, read only', style: _S.titleL),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tap any day for its concise recap and cycle path.',
                    style: _S.bodyM,
                  ),
                ),
                const SizedBox(height: 14),
                const _CalendarLegend(),
                const SizedBox(height: 14),
                Expanded(
                  child: CalendarBrowser(data: data, onEdit: onEdit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayMark {
  /// A recorded bleeding day, from period start/end records alone.
  bool isPeriod = false;

  /// The saved flow degree enriching this period day, when one exists.
  String? flowKey;
  bool heavier = false, lighter = false;
  final Set<PatternsMoodTone> tones = {};
}

Map<int, _DayMark> _buildDayMarks(PatternsExperienceData d) {
  final map = <int, _DayMark>{};
  _DayMark at(int e) => map.putIfAbsent(e, () => _DayMark());
  for (final c in d.completedCycles) {
    for (final date in c.bleedingDates) {
      at(date.epochDay).isPeriod = true;
    }
    for (final f in c.flowDays) {
      final m = at(f.date.epochDay);
      m.isPeriod = true;
      m.flowKey = f.flow.name;
    }
  }
  final cur = d.currentCycle;
  if (cur != null) {
    for (final date in cur.bleedingDatesThrough(d.today)) {
      at(date.epochDay).isPeriod = true;
    }
    for (final f in cur.flowDays) {
      final m = at(f.date.epochDay);
      m.isPeriod = true;
      m.flowKey = f.flow.name;
    }
  }
  for (final s in d.symptoms) {
    final m = at(s.date.epochDay);
    if (s.isHeavier) {
      m.heavier = true;
    } else {
      m.lighter = true;
    }
  }
  for (final mood in d.moods) {
    at(mood.date.epochDay).tones.add(mood.tone);
  }
  return map;
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label, {bool hollow = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hollow ? Colors.transparent : c,
            border: Border.all(color: c, width: hollow ? 1.6 : 0),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: T.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    Widget mark(Widget glyph, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: T.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        mark(const FlowDrop(flowKey: 'light', size: 20), 'Flow saved'),
        mark(const _PeriodDayMark(size: 11), 'Period · no flow recorded'),
        dot(T.berry, 'Heavier symptom'),
        dot(T.lilac, 'Lighter symptom'),
        dot(T.violet, 'Mood · difficult'),
        dot(T.green, 'Mood · positive'),
        dot(T.lake, 'Mood · steady'),
        dot(T.inkSoft, 'Blank · nothing saved', hollow: true),
      ],
    );
  }
}

class CalendarBrowser extends StatefulWidget {
  final PatternsExperienceData data;
  final ValueChanged<String>? onEdit;
  const CalendarBrowser({super.key, required this.data, required this.onEdit});

  @override
  State<CalendarBrowser> createState() => _CalendarBrowserState();
}

class _CalendarBrowserState extends State<CalendarBrowser> {
  late final DateTime _firstMonth = () {
    final first = _dt(widget.data.firstIncludedDate!.epochDay);
    return DateTime(first.year, first.month, 1);
  }();
  late final DateTime _lastMonth = () {
    final t = _dt(widget.data.today.epochDay);
    return DateTime(t.year, t.month, 1);
  }();
  late DateTime _month = _firstMonth;

  void _move(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    if (next.isBefore(_firstMonth) || next.isAfter(_lastMonth)) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final marks = _buildDayMarks(widget.data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _month.isAfter(_firstMonth) ? () => _move(-1) : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
            ),
            Expanded(
              child: Text(
                '${_moFull[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: _S.headline,
              ),
            ),
            IconButton(
              onPressed: _month.isBefore(_lastMonth) ? () => _move(1) : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: _MonthGrid(
              month: _month,
              marks: marks,
              todayEpoch: widget.data.today.epochDay,
              onTap: (epoch) =>
                  openDaySheet(context, widget.data, epoch, widget.onEdit),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<int, _DayMark> marks;
  final int todayEpoch;
  final ValueChanged<int> onTap;
  const _MonthGrid({
    required this.month,
    required this.marks,
    required this.todayEpoch,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month, 1).weekday - 1; // Mon = 0
    final cells = offset + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final w in _wd)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: T.inkSoft,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _cell(r * 7 + col - offset + 1, daysInMonth)),
            ],
          ),
      ],
    );
  }

  Widget _cell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 46);
    final epoch = _epochOf(month.year, month.month, day);
    final mark = marks[epoch];
    final isToday = epoch == todayEpoch;
    final isPeriod = mark?.isPeriod ?? false;
    final flow = mark?.flowKey;

    final dots = <Widget>[];
    if (mark != null) {
      if (mark.heavier) dots.add(_dot(T.berry));
      if (mark.lighter) dots.add(_dot(T.lilac));
      for (final tone in const [
        PatternsMoodTone.difficult,
        PatternsMoodTone.positive,
        PatternsMoodTone.steady,
      ]) {
        if (mark.tones.contains(tone)) dots.add(_dot(toneColor(tone)));
      }
    }

    // Bleeding visuals: a saved flow degree fills the cell with the canonical
    // phase-period raspberry; a recorded period day without flow detail gets
    // a pale outlined treatment — visibly a period day, visibly not a degree.
    final Color? fill;
    Border? border;
    if (flow != null) {
      fill = flowColor(flow).withValues(alpha: 0.85);
    } else if (isPeriod) {
      fill = ExperienceColors.phasePeriod.withValues(alpha: 0.13);
      border = Border.all(
        color: ExperienceColors.phasePeriod.withValues(alpha: 0.5),
        width: 1.2,
      );
    } else {
      fill = null;
    }
    if (isToday) border = Border.all(color: T.ink, width: 1.4);

    return GestureDetector(
      key: ValueKey('patterns-calendar-day-$epoch'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(epoch),
      child: Container(
        height: 46,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(9),
          border: border,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isPeriod ? FontWeight.w800 : FontWeight.w500,
                color: flow != null ? Colors.white : T.ink,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dots.take(3).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 4.5,
    height: 4.5,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

// --- Supporting evidence strip ----------------------------------------------
// Simplified per the bleeding contract: recorded period start, true cycle
// length, and one honest saved/blank time rail. No ordinal labels, no harder
// tally, and a single unambiguous rail meaning — the rail carries the
// coverage story quietly, so no per-cycle logging score is shown.
class _CycleEvidenceStrip extends StatelessWidget {
  final PatternsExperienceData data;
  final ValueChanged<String>? onEdit;
  const _CycleEvidenceStrip({required this.data, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cycles = data.completedCycles;
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cycles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final c = cycles[i];
          final savedSet = savedEpochsIn(data, c);
          return InkWell(
            key: ValueKey('patterns-evidence-${c.periodId}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => openCycleSheet(context, data, i, onEdit),
            child: Container(
              width: 178,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: T.line),
                color: T.surface,
                boxShadow: ExperienceShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fmtShort(c.startDate.epochDay),
                    style: const TextStyle(
                      fontFamily: _serif,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: T.ink,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Period start · ${c.lengthDays}-day cycle',
                    style: _S.bodyS,
                  ),
                  const Spacer(),
                  LayoutBuilder(
                    builder: (context, cons) => CustomPaint(
                      size: Size(cons.maxWidth, 7),
                      painter: _CoveragePainter(
                        lengthDays: c.lengthDays,
                        startEpoch: c.startDate.epochDay,
                        saved: savedSet,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${_plural(c.bleedingDates.length, 'bleeding day')} recorded',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: T.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The true-length time rail: one segment per real day of the cycle. Filled
/// means at least one direct daily observation was saved that day; a gap is
/// simply unrecorded. One colour, one meaning.
class _CoveragePainter extends CustomPainter {
  final int lengthDays;
  final int startEpoch;
  final Set<int> saved;
  _CoveragePainter({
    required this.lengthDays,
    required this.startEpoch,
    required this.saved,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lengthDays <= 0) return;
    final dayW = size.width / lengthDays;
    final gap = dayW > 3 ? 1.5 : 0.0;
    final paint = Paint();
    for (var k = 0; k < lengthDays; k++) {
      final epoch = startEpoch + k;
      paint.color = saved.contains(epoch)
          ? T.green.withValues(alpha: 0.72)
          : T.line;
      canvas.drawRect(
        Rect.fromLTWH(k * dayW, 0, (dayW - gap).clamp(0.5, dayW), size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CoveragePainter old) =>
      old.lengthDays != lengthDays ||
      old.startEpoch != startEpoch ||
      old.saved.length != saved.length;
}

// ---------------------------------------------------------------------------
// VIEW 3 — What helped (compact historical aggregate only)
// ---------------------------------------------------------------------------
class HelpedView extends StatelessWidget {
  final PatternsExperienceData data;
  const HelpedView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<PatternsCareRecord>>{};
    for (final c in data.care) {
      groups.putIfAbsent(c.actionLabel, () => []).add(c);
    }
    final names = groups.keys.toList()
      ..sort((a, b) {
        final d = groups[b]!.length.compareTo(groups[a]!.length);
        return d != 0 ? d : a.compareTo(b);
      });

    String? takeaway;
    if (names.isNotEmpty) {
      final top = names.first;
      final recs = groups[top]!;
      final better = recs.where((r) => r.outcome.name == 'better').length;
      takeaway =
          '“$top” is what you saved most often'
          '${better > 0 ? ' — marked Better on $better of ${_plural(recs.length, 'time')}.' : '.'}'
          ' These are your memories, kept as you saved them.';
    }

    return _Scroll(
      children: [
        _Section(
          number: '01',
          question: 'What you tried, and what you noted after',
          children: [
            if (names.isEmpty)
              Text(
                'No care was saved in this report range yet.',
                style: _S.bodyM.copyWith(fontStyle: FontStyle.italic),
              )
            else ...[
              for (final name in names) _CareRow(data: data, name: name),
              const SizedBox(height: 14),
              _Takeaway(takeaway!),
            ],
            const _Scope(
              'Only care you actually saved · outcomes exactly as you recorded them · tap a row for its records',
            ),
            const _QuietInfo(
              'What this is',
              'Each row counts how often you saved trying something, and the outcome you recorded afterward: Better, Same or Worse. Nothing is checked back on your behalf.',
            ),
          ],
        ),
      ],
    );
  }
}

class _CareRow extends StatelessWidget {
  final PatternsExperienceData data;
  final String name;
  const _CareRow({required this.data, required this.name});
  @override
  Widget build(BuildContext context) {
    final recs = data.care.where((c) => c.actionLabel == name).toList();
    int count(String key) => recs.where((r) => r.outcome.name == key).length;
    final better = count('better');
    final same = count('same');
    final worse = count('worse');
    final total = recs.length;

    Widget seg(int count, Color color) => count == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: count,
            child: Container(color: color.withValues(alpha: 0.75)),
          );

    return InkWell(
      key: ValueKey('patterns-care-row-$name'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => openCareLogSheet(context, data, name),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: T.line)),
        ),
        padding: const EdgeInsets.fromLTRB(2, 13, 2, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: _S.titleM),
                  const SizedBox(height: 3),
                  Text('tried ${_plural(total, 'time')}', style: _S.bodyS),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          seg(better, T.green),
                          seg(same, T.lake),
                          seg(worse, T.coral),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (better > 0) _mini(T.green, 'Better ×$better'),
                      if (same > 0) _mini(T.lake, 'Same ×$same'),
                      if (worse > 0) _mini(T.coral, 'Worse ×$worse'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: T.inkSoft),
          ],
        ),
      ),
    );
  }

  Widget _mini(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          color: T.inkSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
