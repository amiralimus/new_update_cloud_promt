import 'package:flutter/material.dart';

import '../../colors.dart';
import '../models/athlete_model.dart';
import '../widgets/coach_tools_common.dart';
import '../widgets/expired_athletes_carousel.dart';

class CoachToolsDashboardPage extends StatelessWidget {
  const CoachToolsDashboardPage({
    super.key,
    required this.onOpenAthletes,
    required this.onOpenTemplates,
    required this.onCreateProgram,
    required this.onCreateProgramForAthlete,
    required this.onOpenLibrary,
  });

  final VoidCallback onOpenAthletes;
  final VoidCallback onOpenTemplates;
  final VoidCallback onCreateProgram;
  final ValueChanged<CoachAthlete> onCreateProgramForAthlete;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    return CoachPageFrame(
      title: 'داشبورد ساخت برنامه',
      subtitle: 'مسیر مناسب برای ساخت و مدیریت برنامه‌ها را انتخاب کنید.',
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _DashboardActions(
            onCreateProgram: onCreateProgram,
            onOpenAthletes: onOpenAthletes,
            onOpenLibrary: onOpenLibrary,
            onOpenTemplates: onOpenTemplates,
          ),
          const SizedBox(height: 18),
          ExpiredAthletesCarousel(onCreateProgram: onCreateProgramForAthlete),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _DashboardActions extends StatelessWidget {
  const _DashboardActions({
    required this.onCreateProgram,
    required this.onOpenAthletes,
    required this.onOpenLibrary,
    required this.onOpenTemplates,
  });

  final VoidCallback onCreateProgram;
  final VoidCallback onOpenAthletes;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenTemplates;

  @override
  Widget build(BuildContext context) {
    final athletes = _DashboardTool(
      title: 'ورزشکارها',
      subtitle: 'پروفایل و سابقه',
      icon: Icons.groups_2_outlined,
      color: infoFgColor,
      onTap: onOpenAthletes,
    );
    final library = _DashboardTool(
      title: 'حرکات',
      subtitle: 'کتابخانه تمرین',
      icon: Icons.fitness_center_rounded,
      color: okFgColor,
      onTap: onOpenLibrary,
    );
    final templates = _DashboardTool(
      title: 'تمپلیت‌ها',
      subtitle: 'الگوهای آماده برنامه',
      icon: Icons.dashboard_customize_outlined,
      color: warnFgColor,
      onTap: onOpenTemplates,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final hero = _DashboardHero(onTap: onCreateProgram);

        if (constraints.maxWidth >= 900) {
          return SizedBox(
            height: 258,
            child: Row(
              children: [
                Expanded(flex: 12, child: hero),
                const SizedBox(width: gap),
                Expanded(
                  flex: 11,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: athletes),
                            const SizedBox(width: gap),
                            Expanded(child: library),
                          ],
                        ),
                      ),
                      const SizedBox(height: gap),
                      SizedBox(height: 106, child: templates),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (constraints.maxWidth >= 560) {
          return Column(
            children: [
              SizedBox(height: 184, child: hero),
              const SizedBox(height: gap),
              SizedBox(
                height: 104,
                child: Row(
                  children: [
                    Expanded(child: athletes),
                    const SizedBox(width: gap),
                    Expanded(child: library),
                  ],
                ),
              ),
              const SizedBox(height: gap),
              SizedBox(height: 88, width: double.infinity, child: templates),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(height: 172, child: hero),
            const SizedBox(height: gap),
            SizedBox(height: 82, width: double.infinity, child: athletes),
            const SizedBox(height: gap),
            SizedBox(height: 82, width: double.infinity, child: library),
            const SizedBox(height: gap),
            SizedBox(height: 82, width: double.infinity, child: templates),
          ],
        );
      },
    );
  }
}

class _DashboardHero extends StatefulWidget {
  const _DashboardHero({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DashboardHero> createState() => _DashboardHeroState();
}

class _DashboardHeroState extends State<_DashboardHero> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: _hovered ? 1.01 : 1,
        child: Material(
          color: primeColor,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              children: [
                Positioned(
                  left: -36,
                  top: -56,
                  child: _HeroOrb(
                    size: 168,
                    color: onPrimaryColor.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  left: 38,
                  bottom: -78,
                  child: _HeroOrb(
                    size: 168,
                    color: onPrimaryColor.withValues(alpha: 0.07),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: onPrimaryColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'ساخت برنامه دستی',
                          style: TextStyle(
                            color: onPrimaryColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'برنامه‌ای دقیق\nبرای هر ورزشکار',
                        style: TextStyle(
                          color: onPrimaryColor,
                          fontSize: 24,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'تمرین، تغذیه و جزئیات برنامه را یک‌جا تنظیم کنید.',
                        style: TextStyle(
                          color: onPrimaryColor.withValues(alpha: 0.82),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'شروع ساخت برنامه',
                            style: TextStyle(
                              color: onPrimaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_back_rounded,
                            color: onPrimaryColor.withValues(alpha: 0.9),
                            size: 19,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DashboardTool extends StatelessWidget {
  const _DashboardTool({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textMutedColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_back_rounded, size: 18, color: textFaintColor),
            ],
          ),
        ),
      ),
    );
  }
}
