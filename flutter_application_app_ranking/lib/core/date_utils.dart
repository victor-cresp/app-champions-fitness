extension DateFormatting on DateTime {
  /// Formata como "dd/MM/yyyy"
  String get formatted => "${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year";

  /// Formata como "dd/MM" (apenas dia e mês)
  String get shortFormatted => "${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}";
}
