import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../experience/components/interaction_controls.dart';
import '../../../experience/components/record_option_scale.dart';
import '../../../experience/degree/degree_graphics.dart';
import '../../../experience/theme/experience_foundation.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../domain/record_hub_facts.dart';
import '../domain/record_interventions.dart';

Future<bool?> showRecordInterventionsManager(
  BuildContext context, {
  ProductFamily? family,
  required LocalDate date,
  required RecordInterventionsRepository repository,
  VoidCallback? onChanged,
  DateTime Function()? clock,
}) => _push(
  context,
  RecordInterventionsManager(
    family: family,
    date: date,
    repository: repository,
    onChanged: onChanged,
    clock: clock,
  ),
);

Future<bool?> _push(
  BuildContext context,
  Widget child,
) => Navigator.of(context).push<bool>(
  Theme.of(context).platform == TargetPlatform.iOS
      ? CupertinoPageRoute<bool>(builder: (_) => child, fullscreenDialog: true)
      : MaterialPageRoute<bool>(builder: (_) => child, fullscreenDialog: true),
);

String _familyLabel(ProductFamily? family) => switch (family) {
  ProductFamily.medication => 'Medication',
  ProductFamily.supplement => 'Supplement',
  ProductFamily.birthControl => 'Birth control',
  null => 'What I tried',
};
String _dateLabel(BuildContext context, LocalDate date) =>
    MaterialLocalizations.of(context).formatMediumDate(date.asLocalDateTime);

enum _ProductManagementAction { edit, end, archive }

class _ProductCatalogChoice<T> {
  const _ProductCatalogChoice(this.value);
  final T? value;
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class RecordInterventionsManager extends StatefulWidget {
  const RecordInterventionsManager({
    required this.date,
    required this.repository,
    this.family,
    this.onChanged,
    this.clock,
    super.key,
  });
  final LocalDate date;
  final RecordInterventionsRepository repository;
  final ProductFamily? family;
  final VoidCallback? onChanged;
  final DateTime Function()? clock;
  @override
  State<RecordInterventionsManager> createState() =>
      _RecordInterventionsManagerState();
}

class _RecordInterventionsManagerState
    extends State<RecordInterventionsManager> {
  List<ProductEpisode> _episodes = [];
  List<ProductUseRecord> _uses = [];
  List<TriedActionRecord> _actions = [];
  List<ActionCheckbackRecord> _outcomes = [];
  List<TriedActionMemoryGroup> _memory = [];
  bool _loading = true;
  bool _busy = false;
  bool _presentingProduct = false;
  bool _productsInitialized = false;
  bool _pastExpanded = false;
  String? _expandedProductId;
  final _recordDetailsExpanded = <String>{};
  String? _productAck;
  String? _error;
  @override
  void reassemble() {
    super.reassemble();
    // Refresh source reads during a resident preview without replacing routes
    // or the separate editor's draft. No records are written here.
    unawaited(_load());
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      if (widget.family != null) {
        final episodes = await widget.repository.getEpisodes(
          includeArchived: true,
        );
        final familyEpisodes = episodes
            .where((episode) => episode.family == widget.family)
            .toList();
        final useGroups = await Future.wait(
          familyEpisodes.map(
            (episode) => widget.repository.getUses(episodeId: episode.id),
          ),
        );
        if (!mounted) return;
        setState(() {
          _episodes = familyEpisodes;
          _uses = useGroups.expand((uses) => uses).toList()
            ..sort(
              (a, b) =>
                  b.value.experiencedDate.compareTo(a.value.experiencedDate),
            );
          final available = _episodes.where(
            (episode) => !episode.archived && episode.includes(widget.date),
          );
          if (!_productsInitialized) {
            _expandedProductId = available.firstOrNull?.id;
            _productsInitialized = true;
          } else if (!_pastExpanded &&
              !available.any((episode) => episode.id == _expandedProductId)) {
            _expandedProductId = null;
          }
        });
      } else {
        final allActions = await widget.repository.getActions();
        final actions = allActions
            .where((action) => action.experiencedDate == widget.date)
            .toList();
        final outcomes = await widget.repository.getCheckbacks();
        if (!mounted) return;
        setState(() {
          _actions = actions;
          _outcomes = outcomes;
          _memory = factualTriedActionMemory(allActions, outcomes);
        });
      }
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } on RecordHubException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.userMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Your private records could not be loaded. Try again.';
        });
      }
    }
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      widget.onChanged?.call();
      await _load();
    } on RecordHubException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your private record could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _productEditor({ProductEpisode? episode}) async {
    if (_presentingProduct || _busy) return;
    _presentingProduct = true;
    try {
      final changed = await _push(
        context,
        RecordProductEditor(
          date: widget.date,
          family: widget.family!,
          repository: widget.repository,
          episode: episode,
          clock: widget.clock,
          onChanged: widget.onChanged,
        ),
      );
      if (changed == true && mounted) await _load();
    } finally {
      _presentingProduct = false;
    }
  }

  Future<void> _actionEditor({TriedActionRecord? action}) async {
    final changed = await _push(
      context,
      RecordActionEditor(
        date: widget.date,
        repository: widget.repository,
        initial: action,
        clock: widget.clock,
        onChanged: widget.onChanged,
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _checkback(TriedActionRecord action) async {
    final matching = _outcomes.where(
      (value) => value.value.actionId == action.id,
    );
    final changed = await _push(
      context,
      RecordActionCheckbackEditor(
        date: matching.firstOrNull?.experiencedDate ?? widget.date,
        repository: widget.repository,
        action: action,
        initial: matching.firstOrNull,
        clock: widget.clock,
        onChanged: widget.onChanged,
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _archive(ProductEpisode episode) async {
    if (_presentingProduct || _busy) return;
    _presentingProduct = true;
    try {
      final uses = await widget.repository.getUses(episodeId: episode.id);
      if (!mounted) return;
      if (await _confirm(
        context,
        'Archive this use period?',
        'This use period will move out of daily recording. All ${uses.length} saved records and every dose and name version will remain in history. The actual start and end dates stay unchanged. You cannot add new entries to this archived period.',
        'Archive use period',
      )) {
        await _perform(() async {
          await widget.repository.archiveEpisode(episode.id);
          if (mounted) {
            setState(
              () => _productAck =
                  'Use period archived. Your records are kept in history.',
            );
          }
        });
      }
    } finally {
      _presentingProduct = false;
    }
  }

  Future<void> _stop(ProductEpisode episode) async {
    if (_presentingProduct || _busy) return;
    _presentingProduct = true;
    try {
      final date = await _chooseDate(
        context,
        initial: episode.endDate ?? widget.date,
        clock: widget.clock,
      );
      if (date == null || !mounted) return;
      final uses = await widget.repository.getUses(episodeId: episode.id);
      if (!mounted) return;
      final beyond = uses
          .where((use) => use.value.experiencedDate.isAfter(date))
          .length;
      if (await _confirm(
        context,
        'End use on ${_dateLabel(context, date)}?',
        'All ${uses.length} saved records remain available.${beyond == 0 ? '' : ' $beyond are dated after this end date and remain as saved history.'}',
        'Save end date',
      )) {
        await _perform(() async {
          await widget.repository.stopEpisode(episode.id, date);
          if (mounted) {
            setState(
              () =>
                  _productAck = 'Actual end date saved. Your records are kept.',
            );
          }
        });
      }
    } finally {
      _presentingProduct = false;
    }
  }

  Future<void> _anotherUse(ProductEpisode episode) async {
    if (_presentingProduct ||
        _busy ||
        episode.archived ||
        !episode.includes(widget.date)) {
      return;
    }
    _presentingProduct = true;
    try {
      final changed = await _push(
        context,
        _AdditionalProductUseEditor(
          date: widget.date,
          episode: episode,
          existingEntries: _productDayUses(episode),
          repository: widget.repository,
          clock: widget.clock,
          onChanged: widget.onChanged,
        ),
      );
      if (changed == true && mounted) {
        setState(
          () => _productAck =
              'Additional entry saved. Your existing entries stay as they were.',
        );
        await _load();
      }
    } finally {
      _presentingProduct = false;
    }
  }

  @override
  Widget build(BuildContext context) => _scaffold(
    context,
    title: _familyLabel(widget.family),
    date: widget.date,
    onClose: _busy ? null : () => Navigator.of(context).pop(),
    children: [
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(ExperienceSpacing.md),
          child: Center(
            child: EmberLoadingIndicator(
              semanticLabel: 'Loading your saved records',
            ),
          ),
        ),
      if (_busy)
        Semantics(
          liveRegion: true,
          child: Text(
            'Saving on this device…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      if (_error != null) _errorText(context, _error!),
      if (!_loading && widget.family != null) ..._productContent(),
      if (!_loading && widget.family == null) ..._actionContent(),
    ],
  );

  List<Widget> _productContent() {
    final available = _episodes
        .where((episode) => !episode.archived && episode.includes(widget.date))
        .toList();
    final past = _episodes
        .where((episode) => episode.archived || !episode.includes(widget.date))
        .toList();
    return [
      Text(
        'Record what happened on this date.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      if (_productAck != null)
        Padding(
          padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _productAck!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      const SizedBox(height: ExperienceSpacing.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('product-add'),
          onPressed: _busy ? null : () => _productEditor(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('Add ${_familyLabel(widget.family).toLowerCase()}'),
        ),
      ),
      if (available.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.md),
          child: Text(
            _episodes.isEmpty
                ? 'Add ${widget.family == ProductFamily.birthControl ? 'birth control' : 'a ${_familyLabel(widget.family).toLowerCase()}'} to record your use.'
                : 'No use period covers this date. Your past records are below.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      for (final episode in available) _productRow(episode),
      if (past.isNotEmpty) ...[
        const SizedBox(height: ExperienceSpacing.md),
        InteractionSurface(
          key: const Key('product-past-toggle'),
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.sm),
          semanticLabel:
              'Past and archived, ${past.length} use periods, ${_pastExpanded ? 'expanded' : 'collapsed'}',
          onTap: _busy
              ? null
              : () => setState(() {
                  _pastExpanded = !_pastExpanded;
                  if (!_pastExpanded &&
                      past.any((episode) => episode.id == _expandedProductId)) {
                    _expandedProductId = null;
                  }
                }),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Past and archived (${past.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _productChevron(_pastExpanded),
            ],
          ),
        ),
        _productPane(
          _pastExpanded,
          Column(children: [for (final episode in past) _productRow(episode)]),
        ),
      ],
    ];
  }

  Duration get _productMotion => ExperienceMotion.reducedMotion(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);

  Widget _productChevron(bool expanded) => AnimatedRotation(
    turns: expanded ? .5 : 0,
    duration: _productMotion,
    curve: Curves.easeOutCubic,
    child: const Icon(Icons.expand_more_rounded, size: 20),
  );

  Widget _productPane(bool expanded, Widget child) => AnimatedSize(
    duration: _productMotion,
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: expanded ? 1 : 0,
        child: IgnorePointer(
          ignoring: !expanded || _busy,
          child: ExcludeSemantics(excluding: !expanded, child: child),
        ),
      ),
    ),
  );

  List<ProductUseRecord> _productUses(ProductEpisode episode) =>
      _uses.where((use) => use.value.episodeId == episode.id).toList();
  List<ProductUseRecord> _productDayUses(ProductEpisode episode) =>
      _productUses(
        episode,
      ).where((use) => use.value.experiencedDate == widget.date).toList();
  ProductUseRecord? _productDailyUse(ProductEpisode episode) =>
      _productDayUses(episode).where((use) => use.dailyShortcut).firstOrNull;
  ProductDetails _displayedDetails(ProductEpisode episode) {
    final daily = _productDailyUse(episode);
    if (daily != null) {
      return episode.versions
          .firstWhere((version) => version.id == daily.versionId)
          .details;
    }
    return episode.includes(widget.date)
        ? episode.versionAt(widget.date).details
        : episode.currentDetails;
  }

  String _productRange(ProductEpisode episode) {
    final local = MaterialLocalizations.of(context);
    return '${local.formatShortDate(episode.startDate.asLocalDateTime)} – ${episode.endDate == null
        ? episode.archived
              ? 'No end date'
              : 'Ongoing'
        : local.formatShortDate(episode.endDate!.asLocalDateTime)}${episode.archived ? ' · Archived' : ''}';
  }

  Widget _productRow(ProductEpisode episode) {
    final theme = Theme.of(context);
    final details = _displayedDetails(episode);
    final expanded = _expandedProductId == episode.id;
    final daily = _productDailyUse(episode);
    final dayUses = _productDayUses(episode);
    final additional = dayUses.where((use) => !use.dailyShortcut).length;
    final canRecord = !episode.archived && episode.includes(widget.date);
    final status = daily == null
        ? 'Daily status not recorded'
        : '${daily.value.status.label} on this date';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InteractionSurface(
                key: Key('product-row-${episode.id}'),
                color: Colors.transparent,
                borderRadius: BorderRadius.zero,
                semanticLabel:
                    '${details.displayName}. ${_productRange(episode)}. $status${additional == 0 ? '' : '. $additional additional entries'}. ${expanded ? 'Collapse' : 'Expand'}',
                padding: const EdgeInsets.symmetric(vertical: 14),
                onTap: _busy
                    ? null
                    : () => setState(
                        () => _expandedProductId = expanded ? null : episode.id,
                      ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            details.displayName,
                            maxLines: expanded ? null : 2,
                            overflow: expanded ? null : TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _productRange(episode),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_doseLabel(details).isNotEmpty)
                            Text(
                              _doseLabel(details),
                              maxLines: expanded ? null : 1,
                              overflow: expanded ? null : TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '$status${additional == 0 ? '' : ' · $additional additional ${additional == 1 ? 'entry' : 'entries'}'}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _productChevron(expanded),
                  ],
                ),
              ),
            ),
            if (!episode.archived)
              IconButton(
                key: Key('product-manage-${episode.id}'),
                tooltip: 'Manage ${details.displayName}',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: _busy ? null : () => _manageProduct(episode),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
          ],
        ),
        _productPane(
          expanded,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canRecord) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in _statuses(episode.family))
                      ChoiceChip(
                        key: Key('product-status-${episode.id}-${status.name}'),
                        label: Text(status.label),
                        selected: daily?.value.status == status,
                        showCheckmark: true,
                        checkmarkColor: theme.colorScheme.onSurface,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: _busy
                            ? null
                            : (_) => _perform(() async {
                                await widget.repository.saveUse(
                                  ProductUseDraft(
                                    experiencedDate: widget.date,
                                    episodeId: episode.id,
                                    status: status,
                                  ),
                                  dailyShortcut:
                                      status != ProductUseStatus.emergency,
                                );
                                if (mounted) {
                                  setState(
                                    () => _productAck =
                                        '${status.label} saved for this date.',
                                  );
                                }
                              }),
                      ),
                  ],
                ),
              ] else
                Text(
                  episode.archived
                      ? 'Archived · saved records are kept. New entries are unavailable.'
                      : 'This date is outside the actual use period.',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              InteractionSurface(
                key: Key('product-records-toggle-${episode.id}'),
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                semanticLabel: 'Records and details for ${details.displayName}',
                onTap: _busy
                    ? null
                    : () => setState(() {
                        if (!_recordDetailsExpanded.add(episode.id)) {
                          _recordDetailsExpanded.remove(episode.id);
                        }
                      }),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Records and details (${_productUses(episode).length})',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    _productChevron(
                      _recordDetailsExpanded.contains(episode.id),
                    ),
                  ],
                ),
              ),
              _productPane(
                _recordDetailsExpanded.contains(episode.id),
                _productRecords(episode, canRecord: canRecord),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _productRecords(ProductEpisode episode, {required bool canRecord}) {
    final uses = _productUses(episode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canRecord)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('product-additional-${episode.id}'),
              onPressed: _busy ? null : () => _anotherUse(episode),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Record another use'),
            ),
          ),
        if (uses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No saved entries for this use period.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final use in uses) _productUseRow(episode, use),
        ExpansionTile(
          key: Key('product-versions-${episode.id}'),
          tilePadding: EdgeInsets.zero,
          title: Text(
            'Saved detail versions (${episode.versions.length})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            for (final version in episode.versions)
              ListTile(
                key: Key('product-version-${version.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(version.details.displayName),
                subtitle: Text(
                  'Effective ${MaterialLocalizations.of(context).formatShortDate(version.effectiveFrom.asLocalDateTime)}\n${_doseLabel(version.details)}',
                ),
                isThreeLine: _doseLabel(version.details).isNotEmpty,
              ),
          ],
        ),
      ],
    );
  }

  Widget _productUseRow(ProductEpisode episode, ProductUseRecord use) {
    final snapshot = episode.versions
        .firstWhere((version) => version.id == use.versionId)
        .details;
    return ListTile(
      key: Key('product-use-${use.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text('${use.value.status.label} · ${snapshot.displayName}'),
      subtitle: Text(
        '${MaterialLocalizations.of(context).formatShortDate(use.value.experiencedDate.asLocalDateTime)} · ${use.dailyShortcut ? 'Daily entry' : 'Additional entry'}\n${_doseLabel(snapshot)}${_doseLabel(snapshot).isEmpty ? '' : ' · '}${use.metadata.provenance.label}',
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: 'Delete use record',
        onPressed: _busy
            ? null
            : () async {
                if (await _confirm(
                  context,
                  'Delete this use record?',
                  'Only this entry will be removed. The use period and all other saved entries remain.',
                  'Delete',
                )) {
                  await _perform(() => widget.repository.deleteUse(use.id));
                }
              },
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }

  Future<void> _manageProduct(ProductEpisode episode) async {
    if (_presentingProduct || _busy || episode.archived) return;
    _presentingProduct = true;
    _ProductManagementAction? action;
    try {
      final options = <(_ProductManagementAction, String)>[
        (_ProductManagementAction.edit, 'Edit details'),
        (
          _ProductManagementAction.end,
          episode.endDate == null ? 'End use' : 'Change end date',
        ),
        (_ProductManagementAction.archive, 'Archive use period'),
      ];
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        action = await showCupertinoModalPopup<_ProductManagementAction>(
          context: context,
          builder: (context) => CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(context).brightness,
              primaryColor: Theme.of(context).colorScheme.primary,
            ),
            child: CupertinoActionSheet(
              title: Text(episode.currentDetails.displayName),
              actions: [
                for (final option in options)
                  CupertinoActionSheetAction(
                    isDestructiveAction:
                        option.$1 == _ProductManagementAction.archive,
                    onPressed: () => Navigator.pop(context, option.$1),
                    child: Text(option.$2),
                  ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ),
        );
      } else {
        action = await showExperienceSheet<_ProductManagementAction>(
          context,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    episode.currentDetails.displayName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final option in options)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option.$2,
                        style: TextStyle(
                          color: option.$1 == _ProductManagementAction.archive
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, option.$1),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } finally {
      _presentingProduct = false;
    }
    if (!mounted || action == null) return;
    switch (action) {
      case _ProductManagementAction.edit:
        await _productEditor(episode: episode);
      case _ProductManagementAction.end:
        await _stop(episode);
      case _ProductManagementAction.archive:
        await _archive(episode);
    }
  }

  List<Widget> _actionContent() => [
    const Text('Your actions and check-backs are self-reported observations.'),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: _busy ? null : () => _actionEditor(),
      child: const Text('Record what I tried'),
    ),
    if (_actions.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('No saved actions on this date.'),
      ),
    for (final action in _actions) ...[
      const SizedBox(height: 24),
      _heading(
        context,
        action.value.actions.map((value) => value.label).join(' + '),
      ),
      Text(
        '${action.value.bundle ? 'Bundle · ' : ''}${action.value.status == TriedActionStatus.completed ? 'Completed' : 'Couldn’t try'} · ${action.metadata.provenance.label}',
      ),
      if (action.value.target != null) Text('For ${action.value.target}'),
      if (action.value.duration != null) Text(action.value.duration!.label),
      for (final outcome in _outcomes.where(
        (value) => value.value.actionId == action.id,
      ))
        Text(
          '${outcome.value.outcome.label} · ${outcome.metadata.provenance.label}${outcome.value.targetDegree == null ? '' : ' · Target now ${outcome.value.targetDegree}'}',
        ),
      if (!_outcomes.any((value) => value.value.actionId == action.id))
        const Text('No check-back saved'),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: _busy ? null : () => _actionEditor(action: action),
            child: const Text('Edit action'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _checkback(action),
            child: const Text('Check back'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    if (await _confirm(
                      context,
                      'Delete this action?',
                      'Its action set and linked check-back will be deleted together.',
                      'Delete',
                    )) {
                      await _perform(
                        () => widget.repository.deleteAction(action.id),
                      );
                    }
                  },
            child: const Text('Delete'),
          ),
        ],
      ),
    ],
    if (_memory.isNotEmpty) ...[
      const SizedBox(height: 24),
      _heading(context, 'History across saved dates'),
      const Text(
        'Self-reported observations, grouped by the exact actions and target.',
      ),
      for (final group in _memory) ...[
        const SizedBox(height: 16),
        _heading(
          context,
          '${group.bundle ? 'Bundle · ' : ''}${group.actions.map((action) => action.label).join(' + ')}',
        ),
        Text(
          group.target == null ? 'Target not specified' : 'For ${group.target}',
        ),
        Text(
          '${group.total} recorded attempts · ${group.uncheckedCount} without check-back',
        ),
        Text(
          [
            for (final outcome in ActionOutcome.values)
              '${outcome.label}: ${group.outcomes[outcome]}',
          ].join(' · '),
        ),
      ],
    ],
  ];
}

List<ProductUseStatus> _statuses(ProductFamily family) =>
    family == ProductFamily.birthControl
    ? [
        ProductUseStatus.taken,
        ProductUseStatus.missed,
        ProductUseStatus.late,
        ProductUseStatus.emergency,
      ]
    : [
        ProductUseStatus.taken,
        ProductUseStatus.skipped,
        ProductUseStatus.asNeeded,
      ];
String _doseLabel(ProductDetails details) => [
  if (details.dose != null) details.dose!,
  if (details.unit != null)
    details.unit == DoseUnit.other ? details.customUnit! : details.unit!.label,
  if (details.route != null)
    details.route == ProductRoute.other
        ? details.customRoute!
        : details.route!.label,
  if (details.target != null) 'For ${details.target}',
].join(' · ');

abstract class _GuardedEditorState<T extends StatefulWidget> extends State<T> {
  bool dirty = false;
  bool busy = false;
  bool allowPop = false;
  bool asking = false;
  String? error;
  VoidCallback? get onChanged;
  void change(VoidCallback action) {
    if (!busy) {
      setState(() {
        action();
        dirty = true;
        error = null;
      });
    }
  }

  Future<void> save(Future<void> Function() operation) async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      onChanged?.call();
      await close(true);
    } on _InputError catch (failure) {
      if (mounted) {
        setState(() {
          busy = false;
          error = failure.message;
        });
      }
    } on RecordHubException catch (failure) {
      if (mounted) {
        setState(() {
          busy = false;
          error = failure.userMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Your private record could not be saved. Try again.';
        });
      }
    }
  }

  Future<void> close(bool saved) async {
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(saved);
  }

  Future<void> requestClose() async {
    if (busy || asking) return;
    if (!dirty) {
      await close(false);
      return;
    }
    asking = true;
    final discard = await _confirm(
      context,
      'Leave without saving?',
      'Your changes have not been saved.',
      'Discard changes',
    );
    asking = false;
    if (discard && mounted) await close(false);
  }

  Widget guarded(Widget child) => PopScope<bool>(
    canPop: allowPop || !dirty && !busy,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(requestClose());
    },
    child: child,
  );
  Widget field(
    TextEditingController controller,
    String label, {
    bool number = false,
    int lines = 1,
    int? maxLength,
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      key: key,
      controller: controller,
      readOnly: busy,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: false, signed: false)
          : lines == 1
          ? TextInputType.text
          : TextInputType.multiline,
      textInputAction: lines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      minLines: lines,
      maxLength: maxLength,
      maxLines: lines == 1 ? 1 : 6,
      onChanged: (_) => change(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: const OutlineInputBorder(
          borderRadius: ExperienceRadius.cardRadius,
        ),
      ),
    ),
  );
  Widget choices<V>(
    String label,
    Iterable<V> values,
    V? selected,
    String Function(V) name,
    ValueChanged<V?> select,
  ) => _section(
    context,
    label,
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            checkmarkColor: Theme.of(context).colorScheme.onSurface,
            showCheckmark: true,
            label: Text(name(value)),
            selected: value == selected,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: busy
                ? null
                : (_) => change(() => select(selected == value ? null : value)),
          ),
      ],
    ),
  );
  List<Widget> footer(String label, Future<void> Function() operation) => [
    if (error != null) _errorText(context, error!),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: busy ? null : () => save(operation),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const RoundedRectangleBorder(
          borderRadius: ExperienceRadius.cardRadius,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(busy ? 'Saving on this device…' : label),
      ),
    ),
  ];
}

class RecordProductEditor extends StatefulWidget {
  const RecordProductEditor({
    required this.date,
    required this.family,
    required this.repository,
    this.episode,
    this.onChanged,
    this.clock,
    super.key,
  });
  final LocalDate date;
  final ProductFamily family;
  final RecordInterventionsRepository repository;
  final ProductEpisode? episode;
  final VoidCallback? onChanged;
  final DateTime Function()? clock;
  @override
  State<RecordProductEditor> createState() => _RecordProductEditorState();
}

class _RecordProductEditorState
    extends _GuardedEditorState<RecordProductEditor> {
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _customUnit = TextEditingController();
  final _customRoute = TextEditingController();
  final _target = TextEditingController();
  MedicationType? _medication;
  SupplementType? _supplement;
  BirthControlMethod? _method;
  DoseUnit? _unit;
  ProductRoute? _route;
  late LocalDate _start;
  LocalDate? _end;
  bool _choosingProductOption = false;
  @override
  VoidCallback? get onChanged => widget.onChanged;
  @override
  void initState() {
    super.initState();
    _start = widget.date;
    final details = widget.episode?.currentDetails;
    if (details != null) {
      _name.text = details.exactName ?? '';
      _dose.text = details.dose ?? '';
      _customUnit.text = details.customUnit ?? '';
      _customRoute.text = details.customRoute ?? '';
      _target.text = details.target ?? '';
      _medication = details.medicationType;
      _supplement = details.supplementType;
      _method = details.birthControlMethod;
      _unit = details.unit;
      _route = details.route;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _dose,
      _customUnit,
      _customRoute,
      _target,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text;
  Future<void> _persist() async {
    _eligible(_start, widget.clock);
    if (_end != null) _eligible(_end!, widget.clock);
    if (widget.family != ProductFamily.birthControl &&
        _name.text.trim().isEmpty) {
      throw const _InputError('Enter the exact product name.');
    }
    if (widget.family == ProductFamily.birthControl && _method == null) {
      throw const _InputError('Choose a birth-control method.');
    }
    final details = ProductDetails(
      family: widget.family,
      exactName: _optional(_name),
      medicationType: _medication,
      supplementType: _supplement,
      birthControlMethod: _method,
      dose: _optional(_dose),
      unit: _unit,
      customUnit: _unit == DoseUnit.other ? _optional(_customUnit) : null,
      route: _route,
      customRoute: _route == ProductRoute.other
          ? _optional(_customRoute)
          : null,
      target: _optional(_target),
    );
    if (widget.episode == null) {
      await widget.repository.createEpisode(
        ProductEpisodeDraft(startDate: _start, endDate: _end, details: details),
      );
    } else {
      await widget.repository.reviseEpisode(
        widget.episode!.id,
        details,
        effectiveFrom: _start,
      );
    }
  }

  Future<void> _pick(bool end) async {
    final picked = await _chooseDate(
      context,
      initial: end ? _end ?? _start : _start,
      clock: widget.clock,
    );
    if (picked != null && mounted) {
      change(() {
        if (end) {
          _end = picked;
        } else {
          _start = picked;
        }
      });
    }
  }

  Widget _productChoice<T>(
    String label,
    Iterable<T> values,
    T? selected,
    String Function(T) name,
    ValueChanged<T?> select,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: ExperienceSpacing.md),
    child: InteractionSurface(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      semanticLabel:
          '$label, ${selected == null ? 'Not chosen' : name(selected)}',
      padding: const EdgeInsets.all(ExperienceSpacing.sm),
      onTap: busy
          ? null
          : () async {
              if (_choosingProductOption) return;
              _choosingProductOption = true;
              try {
                final choice =
                    await showExperienceSheet<_ProductCatalogChoice<T>>(
                      context,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(
                          ExperienceSpacing.screenMargin,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: ExperienceSpacing.sm),
                            for (final value in values)
                              ListTile(
                                title: Text(name(value)),
                                trailing: selected == value
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      )
                                    : null,
                                selected: selected == value,
                                selectedColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                onTap: () => Navigator.pop(
                                  context,
                                  _ProductCatalogChoice(value),
                                ),
                              ),
                            if (selected != null)
                              TextButton(
                                onPressed: () => Navigator.pop(
                                  context,
                                  _ProductCatalogChoice<T>(null),
                                ),
                                child: const Text('Clear selection'),
                              ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    );
                if (choice != null && mounted) {
                  change(() => select(choice.value));
                }
              } finally {
                _choosingProductOption = false;
              }
            },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  selected == null ? 'Not chosen' : name(selected),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: ExperienceSpacing.sm),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => guarded(
    _scaffold(
      context,
      title: widget.episode == null
          ? 'Add ${_familyLabel(widget.family).toLowerCase()}'
          : 'Edit details',
      date: widget.date,
      onClose: busy ? null : requestClose,
      children: [
        Text(
          widget.episode == null
              ? 'Add the product and the actual dates you used it. Daily entries are recorded separately.'
              : 'Changes start on the effective date you choose. Saved entries keep their original dose and name.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        field(
          _name,
          widget.family == ProductFamily.birthControl
              ? 'Product or other method name (optional)'
              : 'Exact product name',
        ),
        _section(
          context,
          widget.episode == null
              ? 'Actual use dates'
              : 'When this change starts',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.episode != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: ExperienceSpacing.sm),
                  child: Text(
                    'Actual use: ${MaterialLocalizations.of(context).formatShortDate(widget.episode!.startDate.asLocalDateTime)} – ${widget.episode!.endDate == null ? 'Ongoing' : MaterialLocalizations.of(context).formatShortDate(widget.episode!.endDate!.asLocalDateTime)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              _dateControl(
                context,
                label:
                    '${widget.episode == null ? 'Actual start' : 'Change effective'}: ${_dateLabel(context, _start)}',
                onTap: busy ? null : () => _pick(false),
              ),
              if (widget.episode == null) ...[
                const SizedBox(height: ExperienceSpacing.sm),
                _dateControl(
                  context,
                  label: _end == null
                      ? 'Add actual stop (optional)'
                      : 'Actual stop: ${_dateLabel(context, _end!)}',
                  onTap: busy ? null : () => _pick(true),
                ),
                if (_end != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: busy ? null : () => change(() => _end = null),
                      child: const Text('Clear stop'),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (widget.family == ProductFamily.birthControl)
          _productChoice(
            'Method',
            BirthControlMethod.values,
            _method,
            (value) => value.label,
            (value) => _method = value,
          ),
        if (widget.family == ProductFamily.medication)
          _productChoice(
            'Medication type (optional)',
            MedicationType.values,
            _medication,
            (value) => value.label,
            (value) => _medication = value,
          ),
        if (widget.family == ProductFamily.supplement)
          _productChoice(
            'Supplement type (optional)',
            SupplementType.values,
            _supplement,
            (value) => value.label,
            (value) => _supplement = value,
          ),
        _section(
          context,
          'Dose and details',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field(_dose, 'Dose (optional)'),
              _productChoice(
                'Unit (optional)',
                DoseUnit.values,
                _unit,
                (value) => value.label,
                (value) => _unit = value,
              ),
              if (_unit == DoseUnit.other)
                field(_customUnit, 'Unit in your words'),
              _productChoice(
                'Route (optional)',
                ProductRoute.values,
                _route,
                (value) => value.label,
                (value) => _route = value,
              ),
              if (_route == ProductRoute.other)
                field(_customRoute, 'Route in your words'),
              field(_target, 'What is it for? (optional)'),
            ],
          ),
        ),
        ...footer(
          widget.episode == null
              ? 'Save ${_familyLabel(widget.family).toLowerCase()}'
              : 'Save dated change',
          _persist,
        ),
      ],
    ),
  );
}

class _AdditionalProductUseEditor extends StatefulWidget {
  const _AdditionalProductUseEditor({
    required this.date,
    required this.episode,
    required this.existingEntries,
    required this.repository,
    this.clock,
    this.onChanged,
  });
  final LocalDate date;
  final ProductEpisode episode;
  final List<ProductUseRecord> existingEntries;
  final RecordInterventionsRepository repository;
  final DateTime Function()? clock;
  final VoidCallback? onChanged;
  @override
  State<_AdditionalProductUseEditor> createState() =>
      _AdditionalProductUseEditorState();
}

class _AdditionalProductUseEditorState
    extends _GuardedEditorState<_AdditionalProductUseEditor> {
  ProductUseStatus? _status;
  @override
  VoidCallback? get onChanged => widget.onChanged;
  String _existingEntryLabel(ProductUseRecord entry) {
    final snapshot = widget.episode.versions
        .firstWhere((version) => version.id == entry.versionId)
        .details;
    final dose = _doseLabel(snapshot);
    return '${entry.value.status.label} · ${snapshot.displayName}\n${dose.isEmpty ? '' : '$dose · '}${entry.dailyShortcut ? 'Daily entry' : 'Additional entry'}';
  }

  Future<void> _persist() async {
    _eligible(widget.date, widget.clock);
    if (_status == null) {
      throw const _InputError('Choose the status of this additional entry.');
    }
    await widget.repository.saveUse(
      ProductUseDraft(
        experiencedDate: widget.date,
        episodeId: widget.episode.id,
        status: _status!,
      ),
      dailyShortcut: false,
    );
  }

  @override
  Widget build(BuildContext context) => guarded(
    _scaffold(
      context,
      title: 'Record another use',
      date: widget.date,
      onClose: busy ? null : requestClose,
      children: [
        Text(
          widget.episode.versionAt(widget.date).details.displayName,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (_doseLabel(
          widget.episode.versionAt(widget.date).details,
        ).isNotEmpty)
          Text(
            _doseLabel(widget.episode.versionAt(widget.date).details),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'This adds a separate entry for this date. Your existing entries stay as they were.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        Text(
          widget.existingEntries.isEmpty
              ? 'No entries saved on this date yet.'
              : 'Already recorded on this date',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final entry in widget.existingEntries)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _existingEntryLabel(entry),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: ExperienceSpacing.lg),
        choices(
          'Status of this entry',
          _statuses(widget.episode.family),
          _status,
          (value) => value.label,
          (value) => _status = value,
        ),
        ...footer('Save additional entry', _persist),
      ],
    ),
  );
}

class RecordActionEditor extends StatefulWidget {
  const RecordActionEditor({
    required this.date,
    required this.repository,
    this.initial,
    this.onChanged,
    this.clock,
    super.key,
  });
  final LocalDate date;
  final RecordInterventionsRepository repository;
  final TriedActionRecord? initial;
  final VoidCallback? onChanged;
  final DateTime Function()? clock;
  @override
  State<RecordActionEditor> createState() => _RecordActionEditorState();
}

class _RecordActionEditorState extends _GuardedEditorState<RecordActionEditor> {
  final _selected = <TriedActionKind>{};
  final _custom = TextEditingController();
  final _additionalCustom = <TextEditingController>[];
  final _retiredCustom = <TextEditingController>[];
  final _target = TextEditingController();
  final _minutes = TextEditingController();
  TriedActionStatus? _status;
  DurationBucket? _bucket;
  bool _exact = false;
  @override
  VoidCallback? get onChanged => widget.onChanged;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial?.value;
    if (initial != null) {
      for (final action in initial.actions) {
        _selected.add(action.kind);
        if (action.customName != null) {
          if (_custom.text.isEmpty) {
            _custom.text = action.customName!;
          } else {
            _additionalCustom.add(
              TextEditingController(text: action.customName),
            );
          }
        }
      }
      _target.text = initial.target ?? '';
      _status = initial.status;
      _bucket = initial.duration?.bucket;
      _exact = initial.duration?.exactMinutes != null;
      _minutes.text = initial.duration?.exactMinutes?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    for (final controller in [..._additionalCustom, ..._retiredCustom]) {
      controller.dispose();
    }
    _target.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    _eligible(widget.date, widget.clock);
    if (_selected.isEmpty || _status == null) {
      throw const _InputError('Choose an action and its status.');
    }
    RecordedDuration? duration;
    if (_exact) {
      final minutes = int.tryParse(_minutes.text.trim());
      if (minutes == null || minutes <= 0) {
        throw const _InputError('Enter positive exact minutes.');
      }
      duration = RecordedDuration.exact(minutes);
    } else if (_bucket != null) {
      duration = RecordedDuration.bucket(_bucket);
    }
    final initial = widget.initial?.value;
    final actions = [
      for (final kind in _selected)
        TriedActionSelection(
          kind,
          customName: kind == TriedActionKind.other ? _custom.text : null,
        ),
      if (_selected.contains(TriedActionKind.other))
        for (final controller in _additionalCustom)
          TriedActionSelection(
            TriedActionKind.other,
            customName: controller.text,
          ),
    ];
    await widget.repository.saveAction(
      TriedActionDraft(
        experiencedDate: widget.date,
        actions: actions,
        bundle: initial?.bundle == true || actions.length > 1,
        status: _status!,
        target: _target.text.trim().isEmpty ? null : _target.text,
        duration: duration,
        source: initial?.source ?? TriedActionSource.outsideApp,
        completionToken: initial?.completionToken,
        careSourceId: initial?.careSourceId,
        completionOccurredAt: initial?.completionOccurredAt,
        completionUtcOffsetMinutes: initial?.completionUtcOffsetMinutes,
      ),
      id: widget.initial?.id,
    );
  }

  @override
  Widget build(BuildContext context) => guarded(
    _scaffold(
      context,
      title: 'What I tried',
      date: widget.date,
      onClose: busy ? null : requestClose,
      children: [
        Text(
          'Select actions you actually tried together. A combination has one check-back.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        _section(
          context,
          'Actions',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in TriedActionKind.values)
                FilterChip(
                  checkmarkColor: Theme.of(context).colorScheme.onSurface,
                  showCheckmark: true,
                  label: Text(kind.label),
                  selected: _selected.contains(kind),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: busy
                      ? null
                      : (_) => change(() {
                          if (!_selected.add(kind)) _selected.remove(kind);
                        }),
                ),
            ],
          ),
        ),
        if (_selected.contains(TriedActionKind.other))
          field(_custom, 'Action in your words'),
        if (_selected.contains(TriedActionKind.other)) ...[
          for (var index = 0; index < _additionalCustom.length; index++)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field(_additionalCustom[index], 'Own action ${index + 2}'),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => change(() {
                          _retiredCustom.add(_additionalCustom.removeAt(index));
                        }),
                  child: Text('Remove own action ${index + 2}'),
                ),
              ],
            ),
          TextButton(
            onPressed: busy
                ? null
                : () => change(
                    () => _additionalCustom.add(TextEditingController()),
                  ),
            child: const Text('Add another own action'),
          ),
        ],
        choices(
          'Status',
          TriedActionStatus.values,
          _status,
          (value) => value == TriedActionStatus.completed
              ? 'Completed'
              : 'Couldn’t try',
          (value) => _status = value,
        ),
        _section(
          context,
          'Duration (optional)',
          RecordDurationPicker<DurationBucket>(
            options: [
              for (final bucket in DurationBucket.values.where(
                (value) => value.family == DurationFamily.careAction,
              ))
                RecordScaleOption(
                  value: bucket,
                  label: bucket.label,
                  key: Key('record-action-duration-${bucket.name}'),
                ),
            ],
            selected: _bucket,
            exact: _exact,
            onSelected: busy
                ? null
                : (bucket) => change(() {
                    _bucket = !_exact && _bucket == bucket ? null : bucket;
                    _exact = false;
                  }),
            onExactChanged: busy
                ? null
                : (exact) => change(() {
                    _exact = exact;
                    _bucket = null;
                  }),
            exactInput: field(
              _minutes,
              'Exact minutes',
              number: true,
              key: const Key('record-action-exact-minutes'),
            ),
          ),
        ),
        field(_target, 'Target in your words (optional)'),
        ...footer('Save action', _persist),
      ],
    ),
  );
}

class RecordActionCheckbackEditor extends StatefulWidget {
  const RecordActionCheckbackEditor({
    required this.date,
    required this.repository,
    required this.action,
    this.initial,
    this.onChanged,
    this.clock,
    super.key,
  });
  final LocalDate date;
  final RecordInterventionsRepository repository;
  final TriedActionRecord action;
  final ActionCheckbackRecord? initial;
  final VoidCallback? onChanged;
  final DateTime Function()? clock;
  @override
  State<RecordActionCheckbackEditor> createState() =>
      _RecordActionCheckbackEditorState();
}

class _RecordActionCheckbackEditorState
    extends _GuardedEditorState<RecordActionCheckbackEditor> {
  final _reflection = TextEditingController();
  ActionOutcome? _outcome;
  int? _degree;
  UnexpectedObservation? _unexpected;
  @override
  VoidCallback? get onChanged => widget.onChanged;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial?.value;
    _outcome = initial?.outcome;
    _degree = initial?.targetDegree;
    _unexpected = initial?.unexpected;
    _reflection.text = initial?.reflection ?? '';
  }

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    _eligible(widget.date, widget.clock);
    if (_outcome == null) {
      throw const _InputError('Choose your check-back outcome.');
    }
    if (_reflection.text.length > actionCheckbackReflectionMaximumCharacters) {
      throw const _InputError('Keep the reflection within 280 characters.');
    }
    await widget.repository.saveCheckback(
      ActionCheckbackDraft(
        experiencedDate: widget.date,
        actionId: widget.action.id,
        outcome: _outcome!,
        targetDegree: _degree,
        unexpected: _unexpected,
        reflection: _reflection.text.trim().isEmpty ? null : _reflection.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => guarded(
    _scaffold(
      context,
      title: 'Check back',
      date: widget.date,
      onClose: busy ? null : requestClose,
      children: [
        _heading(
          context,
          widget.action.value.actions.map((value) => value.label).join(' + '),
        ),
        if (widget.action.value.target != null)
          Text('For ${widget.action.value.target}'),
        const SizedBox(height: 16),
        choices(
          'How did it feel?',
          ActionOutcome.values,
          _outcome,
          (value) => value.label,
          (value) => _outcome = value,
        ),
        if (widget.action.value.target != null)
          _section(
            context,
            'Target degree now (optional)',
            RecordOptionScale<int>(
              options: [
                for (final severity in SymptomSeverity.orderedDegrees)
                  RecordScaleOption(
                    value: severity.score,
                    label: '${severity.score} ${severity.label}',
                    semanticLabel:
                        'Target degree now, ${severity.score} ${severity.label}, ${severity.score} of 5',
                    key: Key('record-checkback-degree-${severity.score}'),
                    marker: DegreeGraphics.severity(severity, showWord: false),
                  ),
              ],
              selected: _degree,
              onSelected: busy
                  ? null
                  : (value) =>
                        change(() => _degree = _degree == value ? null : value),
            ),
          ),
        choices(
          'Anything unexpected or uncomfortable? (optional)',
          UnexpectedObservation.values,
          _unexpected,
          (value) => switch (value) {
            UnexpectedObservation.no => 'No',
            UnexpectedObservation.yes => 'Yes',
            UnexpectedObservation.notSure => 'Not sure',
          },
          (value) => _unexpected = value,
        ),
        field(
          _reflection,
          'Reflection (optional)',
          lines: 3,
          maxLength: actionCheckbackReflectionMaximumCharacters,
        ),
        ...footer('Save check-back', _persist),
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  if (!dirty ||
                      await _confirm(
                        context,
                        'Skip without saving?',
                        'Your recorded action remains available.',
                        'Skip',
                      )) {
                    if (mounted) await close(false);
                  }
                },
          child: Text(
            widget.initial == null
                ? 'Skip — keep the action only'
                : 'Keep saved check-back',
          ),
        ),
        if (widget.initial != null)
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (await _confirm(
                      context,
                      'Delete this check-back?',
                      'The recorded action remains available.',
                      'Delete',
                    )) {
                      await save(
                        () =>
                            widget.repository.deleteCheckback(widget.action.id),
                      );
                    }
                  },
            child: const Text('Delete check-back'),
          ),
      ],
    ),
  );
}

void _eligible(LocalDate date, DateTime Function()? clock) {
  if (date.isAfter(
    LocalDate.fromDateTime((clock ?? DateTime.now)().toLocal()),
  )) {
    throw const RecordHubException(RecordHubFailure.futureDate);
  }
}

final class _InputError implements Exception {
  const _InputError(this.message);
  final String message;
}

Widget _heading(BuildContext context, String text) => Semantics(
  header: true,
  child: Text(text, style: Theme.of(context).textTheme.titleMedium),
);
Widget _section(BuildContext context, String label, Widget child) => Padding(
  padding: const EdgeInsets.only(bottom: ExperienceSpacing.lg),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(label, style: Theme.of(context).textTheme.titleSmall),
      ),
      const SizedBox(height: ExperienceSpacing.sm),
      child,
    ],
  ),
);
Widget _errorText(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Semantics(
    liveRegion: true,
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  ),
);
Widget _scaffold(
  BuildContext context, {
  required String title,
  required LocalDate date,
  required VoidCallback? onClose,
  required List<Widget> children,
}) => Scaffold(
  appBar: AppBar(
    title: Text(
      title,
      maxLines: 2,
      style: Theme.of(context).textTheme.titleLarge,
    ),
    toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 26
        ? MediaQuery.textScalerOf(context).scale(64)
        : kToolbarHeight,
    leading: IconButton(
      tooltip: 'Close editor',
      onPressed: onClose,
      icon: const Icon(Icons.close),
    ),
  ),
  body: SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                MaterialLocalizations.of(
                  context,
                ).formatFullDate(date.asLocalDateTime),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: ExperienceSpacing.sm),
              ...children,
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  ),
);

Widget _dateControl(
  BuildContext context, {
  required String label,
  required VoidCallback? onTap,
}) => InteractionSurface(
  color: Theme.of(context).colorScheme.surfaceContainerHighest,
  semanticLabel: label,
  onTap: onTap,
  padding: const EdgeInsets.symmetric(
    horizontal: ExperienceSpacing.sm,
    vertical: ExperienceSpacing.sm,
  ),
  child: Row(
    children: [
      const Icon(Icons.calendar_month_outlined, size: 18),
      const SizedBox(width: ExperienceSpacing.sm),
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
      const SizedBox(width: ExperienceSpacing.sm),
      const Icon(Icons.expand_more_rounded, size: 18),
    ],
  ),
);

Future<LocalDate?> _chooseDate(
  BuildContext context, {
  required LocalDate initial,
  DateTime Function()? clock,
}) async {
  final today = (clock ?? DateTime.now)().toLocal();
  final initialDate = initial.isAfter(LocalDate.fromDateTime(today))
      ? today
      : initial.asLocalDateTime;
  if (Theme.of(context).platform != TargetPlatform.iOS) {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    return picked == null ? null : LocalDate.fromDateTime(picked);
  }
  var selected = LocalDate.fromDateTime(initialDate);
  return showCupertinoModalPopup<LocalDate>(
    context: context,
    builder: (context) => CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Theme.of(context).brightness,
        primaryColor: Theme.of(context).colorScheme.primary,
      ),
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: DateTime(1900),
                  maximumDate: today,
                  onDateTimeChanged: (value) =>
                      selected = LocalDate.fromDateTime(value),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
