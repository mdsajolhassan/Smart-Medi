import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../constants/baust_constants.dart';

/// Central Material 3 theme. Every screen inherits these component styles, so
/// buttons, cards, inputs, dialogs, sheets and snackbars look consistent and modern.
class AppTheme {
  AppTheme._();

  static const _radius = 14.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BaustColors.primaryArmyGreen,
      primary: BaustColors.primaryPurple,
      secondary: BaustColors.armyOlive,
      tertiary: BaustColors.purpleAccent,
      error: BaustColors.emergencyRed,
      surface: Colors.white,
    );

    final roundedShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius));
    const buttonText = TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, letterSpacing: 0.2);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(color: c, width: w),
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: BaustColors.surfaceBg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: base.textTheme
          .apply(
            bodyColor: BaustColors.textDark,
            displayColor: BaustColors.textDark,
            fontFamilyFallback: const ['NotoSansBengali'],
          )
          .copyWith(
            titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
            titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BaustColors.primaryArmyGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.1),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE9E3F5)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: roundedShape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: roundedShape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: roundedShape,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: const BorderSide(color: Color(0xFFD4C8EC)),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: roundedShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: BaustColors.primaryArmyGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border(const Color(0xFFE2E8F0)),
        enabledBorder: border(const Color(0xFFDCD3EE)),
        focusedBorder: border(BaustColors.primaryArmyGreen, 2),
        errorBorder: border(BaustColors.emergencyRed),
        focusedErrorBorder: border(BaustColors.emergencyRed, 2),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
        labelStyle: const TextStyle(color: BaustColors.textMuted),
        floatingLabelStyle: const TextStyle(color: BaustColors.primaryArmyGreen, fontWeight: FontWeight.w600),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        side: const BorderSide(color: Color(0xFFDCD3EE)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        selectedColor: BaustColors.primaryArmyGreen.withValues(alpha: 0.12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        contentTextStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: BaustColors.textDark),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        indicatorColor: BaustColors.primaryArmyGreen.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? BaustColors.primaryArmyGreen : BaustColors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? BaustColors.primaryArmyGreen : BaustColors.textMuted,
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
        dividerColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        iconColor: BaustColors.primaryArmyGreen,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEDE7F6), thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BaustColors.primaryArmyGreen,
        linearTrackColor: Color(0xFFE2E8F0),
      ),
      checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: BaustColors.textDark, borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Branded full-screen loader with a gentle breathing animation.
class BrandedLoader extends StatefulWidget {
  final String message;
  const BrandedLoader({super.key, this.message = 'Authenticating with BAUST Portal...'});

  @override
  State<BrandedLoader> createState() => _BrandedLoaderState();
}

class _BrandedLoaderState extends State<BrandedLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3EEFF), BaustColors.surfaceBg],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.05).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [BaustColors.armyGreenDark, BaustColors.armyGreenLight]),
                    boxShadow: [
                      BoxShadow(
                        color: BaustColors.primaryArmyGreen.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Smart Medi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BaustColors.armyGreenDark),
              ),
              const SizedBox(height: 6),
              Text(
                widget.message,
                style: const TextStyle(color: BaustColors.textMuted, fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                  child: LinearProgressIndicator(minHeight: 4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
