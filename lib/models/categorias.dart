/// Catálogos de la app, en un solo lugar para formularios y filtros.
class Categorias {
  Categorias._();

  static const ingresos = ['Salario', 'Freelance', 'Negocio', 'Otros'];

  static const gastos = [
    'Alimentación',
    'Transporte',
    'Vivienda',
    'Servicios',
    'Entretenimiento',
    'Otros',
  ];

  static const facturas = [
    'Servicios',
    'Vivienda',
    'Internet',
    'Telefonía',
    'Suscripciones',
    'Transporte',
    'Otros',
  ];

  static const frecuencias = ['Semanal', 'Mensual', 'Trimestral', 'Anual'];

  static List<String> deMovimiento(String tipo) =>
      tipo == 'Ingreso' ? ingresos : gastos;

  /// Todas las categorías de movimientos, sin repetir (para filtros).
  static List<String> get todasDeMovimientos =>
      {...ingresos, ...gastos}.toList();
}
