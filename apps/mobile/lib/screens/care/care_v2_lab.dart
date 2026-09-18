import 'package:flutter/material.dart';

import '../../features/care/domain/care_mode.dart';
import '../../features/care/presentation/care_motion_flow.dart';
import '../../features/care/presentation/prototype_scene_painter.dart';
import '../../features/care/presentation/v2/care_v2_scene.dart';

/// Developer-only Care V2 lab.
///
/// This screen is not reachable from the normal app entry path: it is opened
/// through the separate `lib/care_v2_lab_main.dart` entrypoint
/// (`flutter run -t lib/care_v2_lab_main.dart`). V1 stays untouched and is
/// launched here side by side for comparison.
class CareV2Lab extends StatefulWidget {
  const CareV2Lab({super.key});

  @override
  State<CareV2Lab> createState() => _CareV2LabState();
}

enum CareLabVersion { v1, v2 }

class _CareV2LabState extends State<CareV2Lab> {
  CareLabVersion _version = CareLabVersion.v2;
  CareMode _mode = CareMode.explode;

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _version == CareLabVersion.v1
            ? CareBreakFlow(
                mode: _mode,
                onBack: () => Navigator.of(context).maybePop(),
                onCompleted: () => Navigator.of(context).maybePop(),
                onDone: () => Navigator.of(context).maybePop(),
                sceneVariant: CareSceneVariant.productionHybrid,
              )
            : CareSceneV2(
                mode: _mode,
                onBack: () => Navigator.of(context).maybePop(),
                onCheckIn: () => Navigator.of(context).maybePop(),
                onDone: () => Navigator.of(context).maybePop(),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Care lab — V1 / V2')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            const Text(
              'Developer-only comparison surface. V1 is the preserved baseline; '
              'V2 is the new interaction kernel for Explode and Heavy.',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 20),
            const Text(
              'Version',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _LabChoice(
                    choiceKey: const Key('care-lab-version-v1'),
                    label: 'V1 baseline',
                    selected: _version == CareLabVersion.v1,
                    onPressed: () =>
                        setState(() => _version = CareLabVersion.v1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LabChoice(
                    choiceKey: const Key('care-lab-version-v2'),
                    label: 'V2 prototype',
                    selected: _version == CareLabVersion.v2,
                    onPressed: () =>
                        setState(() => _version = CareLabVersion.v2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Scene',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _LabChoice(
                    choiceKey: const Key('care-lab-mode-explode'),
                    label: 'Explode',
                    selected: _mode == CareMode.explode,
                    onPressed: () => setState(() => _mode = CareMode.explode),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LabChoice(
                    choiceKey: const Key('care-lab-mode-heavy'),
                    label: 'Heavy',
                    selected: _mode == CareMode.heavy,
                    onPressed: () => setState(() => _mode = CareMode.heavy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('care-lab-open'),
              onPressed: _open,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Open scene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabChoice extends StatelessWidget {
  const _LabChoice({
    required this.choiceKey,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Key choiceKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      key: choiceKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : null,
        side: BorderSide(
          color: selected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
