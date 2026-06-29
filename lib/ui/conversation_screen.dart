import 'package:flutter/material.dart';

import '../conversation/conversation_controller.dart';
import '../conversation/conversation_message.dart';
import '../conversation/conversation_settings.dart';
import '../conversation/language.dart';
import '../models/model_inventory.dart';
import '../models/offline_model.dart';
import '../release/app_release.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.controller});

  final ConversationController controller;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  ConversationController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppRelease.name),
        actions: [
          IconButton(
            tooltip: 'About release',
            onPressed: () => _showAboutRelease(context),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: controller.messages.isEmpty
                ? null
                : controller.clearHistory,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Swap languages',
            onPressed: controller.toggleDirection,
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _LanguageHeader(settings: settings),
              const SizedBox(height: 16),
              _ModeSelector(
                selectedMode: settings.mode,
                onChanged: controller.setMode,
              ),
              const SizedBox(height: 12),
              _SettingsPanel(
                settings: settings,
                onSourceChanged: controller.setSourceLanguage,
                onTargetChanged: controller.setTargetLanguage,
                onModelChanged: controller.setSpeechModel,
                onVoicePlaybackChanged: controller.setVoicePlaybackEnabled,
              ),
              const SizedBox(height: 16),
              _ReadinessPanel(inventory: controller.modelInventory),
              const SizedBox(height: 16),
              _StatusPanel(status: controller.status, phase: controller.phase),
              const SizedBox(height: 16),
              _MessageList(messages: controller.messages),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: controller.isStreamingMode
              ? FilledButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : (controller.isStreaming
                          ? controller.stopStreaming
                          : controller.startStreaming),
                  style: FilledButton.styleFrom(
                    backgroundColor: controller.isStreaming
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: controller.isStreaming
                        ? Theme.of(context).colorScheme.onError
                        : Theme.of(context).colorScheme.onPrimary,
                  ),
                  icon: Icon(controller.isStreaming ? Icons.stop : Icons.mic),
                  label: Text(
                    controller.isStreaming
                        ? 'Stop continuous interpreting'
                        : 'Start continuous interpreting',
                  ),
                )
              : FilledButton.icon(
                  onPressed: controller.isBusy ? null : controller.startPushToTalk,
                  icon: Icon(controller.isBusy ? Icons.hearing : Icons.mic),
                  label: Text(
                    controller.isBusy ? controller.phase.label : 'Hold to interpret',
                  ),
                ),
        ),
      ),
    );
  }

  void _showAboutRelease(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppRelease.name,
      applicationVersion:
          '${AppRelease.version}+${AppRelease.buildNumber} ${AppRelease.channel}',
      applicationLegalese: AppRelease.summary,
      children: const [
        SizedBox(height: 12),
        Text(
          'v1.0.0 includes the Flutter app shell, EN-VI mock translation flow, '
          'offline model readiness checks, mode controls, and release tests. '
          'Native Whisper.cpp, Argos Translate, microphone streaming, and '
          'platform TTS adapters are integration points for the next build.',
        ),
      ],
    );
  }
}

class _LanguageHeader extends StatelessWidget {
  const _LanguageHeader({required this.settings});

  final ConversationSettings settings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LanguageTile(
            label: 'From',
            value: settings.sourceLanguage.label,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.arrow_forward),
        ),
        Expanded(
          child: _LanguageTile(
            label: 'To',
            value: settings.targetLanguage.label,
          ),
        ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selectedMode, required this.onChanged});

  final InterpreterMode selectedMode;
  final ValueChanged<InterpreterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<InterpreterMode>(
      selected: {selectedMode},
      onSelectionChanged: (selection) => onChanged(selection.first),
      segments: InterpreterMode.values
          .map(
            (mode) => ButtonSegment<InterpreterMode>(
              value: mode,
              label: Text(mode.label),
            ),
          )
          .toList(),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.settings,
    required this.onSourceChanged,
    required this.onTargetChanged,
    required this.onModelChanged,
    required this.onVoicePlaybackChanged,
  });

  final ConversationSettings settings;
  final ValueChanged<SupportedLanguage> onSourceChanged;
  final ValueChanged<SupportedLanguage> onTargetChanged;
  final ValueChanged<SpeechModelProfile> onModelChanged;
  final ValueChanged<bool> onVoicePlaybackChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _LanguageDropdown(
                    label: 'Source',
                    value: settings.sourceLanguage,
                    onChanged: onSourceChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LanguageDropdown(
                    label: 'Target',
                    value: settings.targetLanguage,
                    onChanged: onTargetChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SpeechModelProfile>(
              initialValue: settings.speechModel,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Speech model',
              ),
              items: SpeechModelProfile.values
                  .map(
                    (model) => DropdownMenuItem(
                      value: model,
                      child: Text('${model.label} - ${model.description}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onModelChanged(value);
                }
              },
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Translated voice playback'),
              subtitle: const Text('Used in conversation mode'),
              value: settings.voicePlaybackEnabled,
              onChanged: onVoicePlaybackChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final SupportedLanguage value;
  final ValueChanged<SupportedLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<SupportedLanguage>(
      initialValue: value,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
      ),
      items: SupportedLanguage.values
          .map(
            (language) =>
                DropdownMenuItem(value: language, child: Text(language.label)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.inventory});

  final ModelInventory inventory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  inventory.isReady ? Icons.offline_pin : Icons.error_outline,
                  color: inventory.isReady
                      ? colorScheme.primary
                      : colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    inventory.isReady
                        ? 'Offline pack ready'
                        : 'Offline pack incomplete',
                    style: textTheme.titleMedium,
                  ),
                ),
                Text('${inventory.installedSizeMb} MB'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: inventory.models
                  .map((model) => _ModelChip(model: model))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.model});

  final OfflineModel model;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReady = model.isReady;

    return Tooltip(
      message: '${model.type.label} - ${model.status.label}',
      child: Chip(
        avatar: Icon(
          isReady ? Icons.check_circle : Icons.error,
          size: 18,
          color: isReady ? colorScheme.primary : colorScheme.error,
        ),
        label: Text(model.name),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    );
  }
}

class _AudioWaveformVisualizer extends StatefulWidget {
  const _AudioWaveformVisualizer({required this.isActive});

  final bool isActive;

  @override
  State<_AudioWaveformVisualizer> createState() => _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<_AudioWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            const double baseHeight = 4.0;
            final double progress = (_controller.value + (index * 0.2)) % 1.0;
            final double heightFactor = (0.5 - (progress - 0.5).abs()) * 2.0;
            final double height = widget.isActive ? baseHeight + (heightFactor * 16.0) : baseHeight;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3.0,
              height: height,
              decoration: BoxDecoration(
                color: widget.isActive ? colorScheme.primary : colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status, required this.phase});

  final String status;
  final InterpreterPhase phase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: phase == InterpreterPhase.idle
                    ? Icon(Icons.lock_outline, color: colorScheme.outline)
                    : _AudioWaveformVisualizer(isActive: phase != InterpreterPhase.idle),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phase.label),
                  const SizedBox(height: 2),
                  Text(status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<ConversationMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('Start interpreting to see local subtitles here.'),
        ),
      );
    }

    return Column(
      children: [
        for (final message in messages) ...[
          _MessageTile(message: message),
          if (message != messages.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final ConversationMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${message.sourceLanguage.label} transcript',
              style: textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            Text(message.transcript),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${message.targetLanguage.label} translation',
                    style: textTheme.labelMedium,
                  ),
                ),
                Text(
                  '${message.latency.inMilliseconds} ms',
                  style: textTheme.labelSmall,
                ),
                if (message.spoken) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.volume_up, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(message.translation, style: textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
