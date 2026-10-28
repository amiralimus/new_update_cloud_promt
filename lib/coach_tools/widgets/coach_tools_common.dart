import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../core/network/api_config.dart';

class CoachPageFrame extends StatelessWidget {
  const CoachPageFrame({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.padding,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget body;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 600;
          final tablet = constraints.maxWidth < 1050;
          final outerMargin = mobile ? 10.0 : 20.0;
          final contentPadding =
              padding ??
              EdgeInsets.fromLTRB(
                mobile
                    ? 14
                    : tablet
                    ? 20
                    : 28,
                mobile ? 16 : 24,
                mobile
                    ? 14
                    : tablet
                    ? 20
                    : 28,
                mobile ? 14 : 24,
              );

          return SafeArea(
            top: false,
            bottom: false,
            child: Container(
              margin: EdgeInsets.all(outerMargin),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(mobile ? 16 : 20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.045),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(mobile ? 16 : 20),
                child: Theme(
                  data: _coachToolsTheme(context),
                  child: Padding(
                    padding: contentPadding,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CoachPageHeader(
                              title: title,
                              subtitle: subtitle,
                              onBack: onBack,
                              actions: actions,
                              compact: mobile,
                            ),
                            SizedBox(height: mobile ? 16 : 22),
                            Expanded(child: body),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CoachPageHeader extends StatelessWidget {
  const _CoachPageHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.actions,
    required this.compact,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textPrimaryColor,
            fontSize: compact ? 20 : 26,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: compact ? 12 : 13.5,
              height: 1.65,
            ),
          ),
        ],
      ],
    );
    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          Material(
            color: surfaceMutedColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.arrow_forward_rounded, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(child: heading),
      ],
    );

    if (compact && actions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleRow,
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleRow),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 16),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }
}

class CoachSurface extends StatelessWidget {
  const CoachSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.outlineColor = borderColor,
    this.color = surfaceColor,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color outlineColor;
  final Color color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: outlineColor),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

InputDecoration coachInputDecoration({
  String? labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? suffixText,
  bool dense = false,
}) {
  final radius = BorderRadius.circular(12);
  final placeholder = labelText ?? hintText;
  return InputDecoration(
    labelText: placeholder,
    hintText: null,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    suffixText: suffixText,
    isDense: dense,
    filled: true,
    fillColor: textfildColor,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    labelStyle: const TextStyle(
      color: textPrimaryColor,
      fontWeight: FontWeight.w600,
    ),
    floatingLabelStyle: const TextStyle(
      color: textPrimaryColor,
      fontWeight: FontWeight.w600,
    ),
    contentPadding: EdgeInsets.symmetric(
      horizontal: 15,
      vertical: dense ? 13 : 17,
    ),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: dangerFgColor, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: dangerFgColor, width: 1.4),
    ),
  );
}

class CoachSectionHeading extends StatelessWidget {
  const CoachSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: primeColor, size: 21),
          ),
          const SizedBox(width: 11),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: textMutedColor,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class CoachNetworkImage extends StatelessWidget {
  const CoachNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.fitness_center_rounded,
    this.iconSize = 30,
    this.preferHtmlElement = false,
  });

  final String? url;
  final BoxFit fit;
  final IconData placeholderIcon;
  final double iconSize;
  final bool preferHtmlElement;

  @override
  Widget build(BuildContext context) {
    final raw = url?.trim() ?? '';
    final resolved = raw.isEmpty ? '' : ApiConfig.resolveMediaUrl(raw);
    if (resolved.isEmpty) return _fallback();
    return Image.network(
      resolved,
      fit: fit,
      gaplessPlayback: true,
      webHtmlElementStrategy: preferHtmlElement
          ? WebHtmlElementStrategy.prefer
          : WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _fallback(broken: true),
    );
  }

  Widget _fallback({bool broken = false}) {
    return ColoredBox(
      color: surfaceMutedColor,
      child: Center(
        child: Icon(
          broken ? Icons.broken_image_outlined : placeholderIcon,
          color: textFaintColor,
          size: iconSize,
        ),
      ),
    );
  }
}

ThemeData _coachToolsTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: textfildColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      labelStyle: const TextStyle(
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primeColor,
        foregroundColor: onPrimaryColor,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primeColor,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: borderStrongColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

class CoachLoadingState extends StatelessWidget {
  const CoachLoadingState({super.key, this.label = 'در حال بارگذاری...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: textMutedColor)),
        ],
      ),
    );
  }
}

class CoachEmptyState extends StatelessWidget {
  const CoachEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: infoBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: infoFgColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textMutedColor, height: 1.6),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

class CoachErrorState extends StatelessWidget {
  const CoachErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CoachEmptyState(
      title: 'بارگذاری انجام نشد',
      message: message,
      icon: Icons.error_outline_rounded,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('تلاش دوباره'),
      ),
    );
  }
}

class HoverActionCard extends StatefulWidget {
  const HoverActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = primeColor,
    this.trailing,
    this.featured = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Widget? trailing;
  final bool featured;

  @override
  State<HoverActionCard> createState() => _HoverActionCardState();
}

class _HoverActionCardState extends State<HoverActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: _hovered ? 1.015 : 1,
        child: Material(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.all(widget.featured ? 22 : 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    widget.color.withValues(alpha: 0.08),
                    surfaceColor,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                border: Border.all(
                  color: _hovered
                      ? widget.color.withValues(alpha: 0.48)
                      : borderColor,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(
                      alpha: _hovered ? 0.13 : 0.05,
                    ),
                    blurRadius: _hovered ? 24 : 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: widget.featured ? 58 : 46,
                    height: widget.featured ? 58 : 46,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: widget.featured ? 30 : 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: widget.featured ? 18 : 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (widget.subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textMutedColor,
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  widget.trailing ??
                      Icon(
                        Icons.arrow_back_rounded,
                        color: _hovered ? widget.color : textFaintColor,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
