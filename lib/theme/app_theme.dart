import 'package:flutter/material.dart';

/// Colores con significado en Finza (ingreso, gasto, alerta). Cambian según
/// el tema para que se lean bien en claro y en oscuro.
///
/// Uso: `final colores = ColoresFinza.de(context);` y luego `colores.ingreso`.
@immutable
class ColoresFinza extends ThemeExtension<ColoresFinza> {
  const ColoresFinza({
    required this.ingreso,
    required this.gasto,
    required this.alerta,
  });

  final Color ingreso;
  final Color gasto;
  final Color alerta;

  static ColoresFinza de(BuildContext context) =>
      Theme.of(context).extension<ColoresFinza>()!;

  @override
  ColoresFinza copyWith({Color? ingreso, Color? gasto, Color? alerta}) {
    return ColoresFinza(
      ingreso: ingreso ?? this.ingreso,
      gasto: gasto ?? this.gasto,
      alerta: alerta ?? this.alerta,
    );
  }

  @override
  ColoresFinza lerp(ColoresFinza? other, double t) {
    if (other == null) return this;
    return ColoresFinza(
      ingreso: Color.lerp(ingreso, other.ingreso, t)!,
      gasto: Color.lerp(gasto, other.gasto, t)!,
      alerta: Color.lerp(alerta, other.alerta, t)!,
    );
  }
}

/// Tema de Finza. La marca es el degradado índigo → violeta del logo
/// (assets/branding/logo.svg); ingreso (verde menta) y gasto (rosa) se
/// eligieron para contrastar con él y entre sí en ambos modos.
class AppTheme {
  AppTheme._();

  // Marca (mismos colores del logo).
  static const Color indigo = Color(0xFF4F46E5);
  static const Color violeta = Color(0xFF8B5CF6);
  static const Color menta = Color(0xFF10B981);

  /// Degradado de la tarjeta de saldo y otros elementos destacados.
  static const LinearGradient degradadoMarca = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo, violeta],
  );

  // Fondos: lavanda muy suave en claro, azul noche en oscuro.
  static const Color fondoClaro = Color(0xFFF6F5FC);
  static const Color superficieClara = Colors.white;
  static const Color fondoOscuro = Color(0xFF0D0C17);
  static const Color superficieOscura = Color(0xFF17152A);
  static const Color superficieOscuraAlta = Color(0xFF221F3B);

  static const double radio = 20;

  static ThemeData get claro {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: indigo,
      brightness: Brightness.light,
    ).copyWith(
      primary: indigo,
      secondary: violeta,
      surface: superficieClara,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF1F0FA),
      surfaceContainerHigh: const Color(0xFFEAE8F7),
      outlineVariant: const Color(0xFFE3E1F2),
    );

    return _base(
      colorScheme: colorScheme,
      fondo: fondoClaro,
      colores: const ColoresFinza(
        ingreso: Color(0xFF059669),
        gasto: Color(0xFFE11D48),
        alerta: Color(0xFFD97706),
      ),
    );
  }

  static ThemeData get oscuro {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: indigo,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFA5B4FC),
      secondary: const Color(0xFFC4B5FD),
      surface: superficieOscura,
      surfaceContainerLowest: fondoOscuro,
      surfaceContainerLow: superficieOscura,
      surfaceContainer: superficieOscura,
      surfaceContainerHigh: superficieOscuraAlta,
      surfaceContainerHighest: const Color(0xFF2B2748),
      outlineVariant: const Color(0xFF2E2A4A),
    );

    return _base(
      colorScheme: colorScheme,
      fondo: fondoOscuro,
      colores: const ColoresFinza(
        ingreso: Color(0xFF34D399),
        gasto: Color(0xFFFB7185),
        alerta: Color(0xFFFBBF24),
      ),
    );
  }

  static ThemeData _base({
    required ColorScheme colorScheme,
    required Color fondo,
    required ColoresFinza colores,
  }) {
    final esOscuro = colorScheme.brightness == Brightness.dark;
    final bordeTarjeta = BorderSide(color: colorScheme.outlineVariant);
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radio),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
    );

    return base.copyWith(
      scaffoldBackgroundColor: fondo,
      extensions: [colores],
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: forma.copyWith(side: bordeTarjeta),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: esOscuro ? superficieOscura : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: esOscuro ? 0.22 : 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            color: estados.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => TextStyle(
            fontSize: 12,
            fontWeight: estados.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: estados.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: esOscuro ? colorScheme.primary : indigo,
        foregroundColor: esOscuro ? const Color(0xFF1E1B4B) : Colors.white,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esOscuro ? superficieOscuraAlta : const Color(0xFFF3F2FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    );
  }
}
