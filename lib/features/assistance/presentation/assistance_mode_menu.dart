import 'package:flutter/material.dart';

import '../../../shared/i18n/i18n.dart';

class AssistanceModeMenu extends StatelessWidget {
  const AssistanceModeMenu({
    super.key,
    required this.onRecognize,
    required this.onFind,
    required this.onRead,
  });

  final VoidCallback onRecognize;
  final VoidCallback onFind;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Semantics(
              header: true,
              child: Text(
                l10n.chooseAssistanceMode,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _ModeTile(
            title: l10n.modeRecognize,
            description: l10n.recognizeDescription,
            icon: Icons.center_focus_weak_rounded,
            emphasized: true,
            onPressed: onRecognize,
          ),
          const SizedBox(height: 10),
          _ModeTile(
            title: l10n.modeFind,
            description: l10n.findDescription,
            icon: Icons.search_rounded,
            onPressed: onFind,
          ),
          const SizedBox(height: 10),
          _ModeTile(
            title: l10n.modeRead,
            description: l10n.readDescription,
            icon: Icons.menu_book_rounded,
            onPressed: onRead,
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = emphasized ? colors.primary : colors.surfaceContainer;
    final foreground = emphasized ? colors.onPrimary : colors.onSurface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: emphasized ? BorderSide.none : BorderSide(color: colors.outline),
    );
    return Semantics(
      button: true,
      child: Material(
        color: background,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          focusColor: foreground.withValues(alpha: 0.20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox.square(
                      dimension: 42,
                      child: Icon(icon, color: colors.onPrimaryContainer),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: Icon(Icons.chevron_right, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
