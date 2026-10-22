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

class AppTheme {
  AppTheme._();

  static const Color verde = Color(0xFF1B8A5A);
  static const Color fondoClaro = Color(0xFFF5F7F5);
  static const Color fondoOscuro = Color(0xFF0F1412);
  static const Color superficieOscura = Color(0xFF18201C);
  static const Color superficieOscuraAlta = Color(0xFF212B26);

  static ThemeData get claro {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: verde,
      brightness: Brightness.light,
    );

    return _base(
      colorScheme: colorScheme,
      fondo: fondoClaro,
      colores: const ColoresFinza(
        ingreso: Color(0xFF1E8E3E),
        gasto: Color(0xFFD93025),
        alerta: Color(0xFFE37400),
      ),
    );
  }

  static ThemeData get oscuro {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: verde,
      brightness: Brightness.dark,
      surface: superficieOscura,
    ).copyWith(surfaceContainerHighest: superficieOscuraAlta);

    return _base(
      colorScheme: colorScheme,
      fondo: fondoOscuro,
      colores: const ColoresFinza(
        ingreso: Color(0xFF6DD58C),
        gasto: Color(0xFFFF8A80),
        alerta: Color(0xFFFFB74D),
      ),
    );
  }

  static ThemeData _base({
    required ColorScheme colorScheme,
    required Color fondo,
    required ColoresFinza colores,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: fondo,
      extensions: [colores],
      appBarTheme: AppBarTheme(
        backgroundColor: fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
