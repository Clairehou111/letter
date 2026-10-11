import 'package:flutter/material.dart';

import '../theme/experience_foundation.dart';

/// A touch-responsive material for short, focused actions. Selection belongs
/// to the caller; this surface never starts a write or claims a save.
class InteractionSurface extends StatefulWidget {
  const InteractionSurface({
    required this.child,
    super.key,
    this.onTap,
    this.selected = false,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final String? semanticLabel;

  @override
  State<InteractionSurface> createState() => _InteractionSurfaceState();
}

class _InteractionSurfaceState extends State<InteractionSurface> {
  bool _pressed = false;
  bool _focused = false;

  @override
  void didUpdateWidget(InteractionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduce = ExperienceMotion.reducedMotion(context);
    final active = widget.onTap != null;
    final base = widget.color ?? theme.colorScheme.surface;
    final tint = widget.selected
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.onSurface.withValues(alpha: _pressed ? 0.08 : 0);
    final surface = Color.alphaBlend(tint, base);
    final border = widget.selected || _focused
        ? theme.colorScheme.primary.withValues(alpha: _focused ? 0.9 : 0.65)
        : Colors.transparent;
    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      button: widget.semanticLabel != null ? true : null,
      enabled: widget.semanticLabel != null ? active : null,
      onTap: widget.semanticLabel != null ? widget.onTap : null,
      selected: widget.selected ? true : null,
      child: AnimatedScale(
        scale: _pressed && active && !reduce ? 0.985 : 1,
        duration: reduce
            ? Duration.zero
            : Duration(milliseconds: _pressed ? 80 : 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : ExperienceMotion.chipSelect,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: widget.borderRadius,
            border: Border.all(color: border),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: widget.borderRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: widget.borderRadius,
              onHighlightChanged: (value) {
                if (_pressed != value) setState(() => _pressed = value);
              },
              onFocusChange: (value) {
                if (_focused != value) setState(() => _focused = value);
              },
              splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: Padding(padding: widget.padding, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
