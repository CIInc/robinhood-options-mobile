import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _compactCurrencyFormat = NumberFormat.compactSimpleCurrency();
final _dateFormat = DateFormat.yMMMd();
final _monthYearFormat = DateFormat.yMMMM();

/// Represents a tax form (1099), monthly brokerage account statement,
/// or trade confirmation issued by Robinhood.
class AccountDocument {
  final String id;
  final String? accountNumber;
  final String
  type; // '1099', 'account_statement', 'trade_confirmation', 'crypto_statement'
  final String title;
  final DateTime? date;
  final int? year;
  final String? downloadUrl;
  final int? fileSize; // in bytes
  final String state; // 'ready', 'processing', 'available'
  final String fileFormat; // 'PDF', 'CSV'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AccountDocument({
    required this.id,
    this.accountNumber,
    this.type = '1099',
    this.title = '',
    this.date,
    this.year,
    this.downloadUrl,
    this.fileSize,
    this.state = 'ready',
    this.fileFormat = 'PDF',
    this.createdAt,
    this.updatedAt,
  });

  factory AccountDocument.fromJson(dynamic json) {
    if (json is! Map) {
      return const AccountDocument(id: '', title: 'Account Document');
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final id = json['id']?.toString() ?? json['ref_id']?.toString() ?? '';
    final accountNumber =
        json['account_number']?.toString() ?? json['account']?.toString();
    final type = json['type']?.toString().toLowerCase() ?? '1099';
    final date = parseDate(json['date']);
    final fileFormat =
        json['filetype']?.toString().toUpperCase() ??
        json['file_type']?.toString().toUpperCase() ??
        'PDF';

    // Calculate effective tax year:
    // If explicitly provided in JSON, use it.
    // For 1099 forms issued in spring (Jan-May), tax year is the prior calendar year.
    int? year = parseInt(json['year']);
    if (year == null && date != null) {
      if (type.contains('1099') && date.month <= 5) {
        year = date.year - 1;
      } else {
        year = date.year;
      }
    }

    String title =
        json['title']?.toString() ??
        json['name']?.toString() ??
        json['description']?.toString() ??
        '';
    if (title.isEmpty || title == 'Account Document') {
      if (type.contains('1099')) {
        final yearStr = year != null ? ' ($year)' : '';
        title = 'Form 1099 Consolidated$yearStr';
      } else if (type.contains('statement')) {
        if (date != null) {
          title = 'Account Statement - ${_monthYearFormat.format(date)}';
        } else {
          title = 'Account Statement';
        }
      } else if (type.contains('confirm')) {
        if (date != null) {
          title = 'Trade Confirmation - ${_dateFormat.format(date)}';
        } else {
          title = 'Trade Confirmation';
        }
      } else {
        title = 'Account Document';
      }
    }

    final downloadUrl =
        json['download_url']?.toString() ??
        json['url']?.toString() ??
        json['file']?.toString();
    final fileSize =
        parseInt(json['file_size']) ??
        parseInt(json['size']) ??
        parseInt(json['bytes']);
    final state =
        json['state']?.toString().toLowerCase() ??
        json['status']?.toString().toLowerCase() ??
        'ready';
    final createdAt = parseDate(json['created_at']);
    final updatedAt = parseDate(json['updated_at']);

    return AccountDocument(
      id: id,
      accountNumber: accountNumber,
      type: type,
      title: title,
      date: date,
      year: year,
      downloadUrl: downloadUrl,
      fileSize: fileSize,
      state: state,
      fileFormat: fileFormat,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (accountNumber != null) 'account_number': accountNumber,
      'type': type,
      'title': title,
      if (date != null) 'date': date!.toIso8601String(),
      if (year != null) 'year': year,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (fileSize != null) 'file_size': fileSize,
      'state': state,
      'file_format': fileFormat,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  bool get is1099 =>
      type.contains('1099') ||
      type.contains('tax') ||
      title.toLowerCase().contains('1099');

  bool get isAccountStatement =>
      type.contains('statement') || title.toLowerCase().contains('statement');

  bool get isTradeConfirmation =>
      type.contains('confirm') || title.toLowerCase().contains('confirmation');

  int get taxYear {
    if (year != null) return year!;
    if (date != null) {
      if (is1099 && date!.month <= 5) {
        return date!.year - 1;
      }
      return date!.year;
    }
    return DateTime.now().year;
  }

  String get typeLabel {
    if (is1099) return 'Tax Form (1099)';
    if (isTradeConfirmation) return 'Trade Confirmation';
    if (isAccountStatement) return 'Account Statement';
    return type.toUpperCase();
  }

  String get formattedDate {
    if (date != null) {
      if (isAccountStatement) {
        return _monthYearFormat.format(date!);
      }
      return _dateFormat.format(date!);
    }
    if (year != null) {
      return 'Tax Year $year';
    }
    return 'Unknown Date';
  }

  String get formattedFileSize {
    if (fileSize == null || fileSize! <= 0) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get icon {
    if (is1099) return Icons.receipt_long;
    if (isAccountStatement) return Icons.description;
    if (isTradeConfirmation) return Icons.verified;
    return Icons.folder_open;
  }

  Color get badgeColor {
    if (is1099) return Colors.teal;
    if (isAccountStatement) return Colors.blue;
    if (isTradeConfirmation) return Colors.purple;
    return Colors.grey;
  }
}

/// Represents foreign stock American Depositary Receipt (ADR) pass-through fee.
/// Robinhood endpoint: /corp_actions/adr_fees/
class AdrFee {
  final String id;
  final String? accountNumber;
  final String? instrumentId;
  final String symbol;
  final double amount;
  final double rate; // fee per share, e.g. 0.02
  final double quantity; // number of ADR shares
  final String currencyCode;
  final DateTime? date;
  final String feeType; // 'custody_fee', 'pass_through', 'dividend_fee'
  final String? description;

  const AdrFee({
    required this.id,
    this.accountNumber,
    this.instrumentId,
    required this.symbol,
    this.amount = 0.0,
    this.rate = 0.0,
    this.quantity = 0.0,
    this.currencyCode = 'USD',
    this.date,
    this.feeType = 'custody_fee',
    this.description,
  });

  AdrFee copyWith({
    String? id,
    String? accountNumber,
    String? instrumentId,
    String? symbol,
    double? amount,
    double? rate,
    double? quantity,
    String? currencyCode,
    DateTime? date,
    String? feeType,
    String? description,
  }) {
    return AdrFee(
      id: id ?? this.id,
      accountNumber: accountNumber ?? this.accountNumber,
      instrumentId: instrumentId ?? this.instrumentId,
      symbol: symbol ?? this.symbol,
      amount: amount ?? this.amount,
      rate: rate ?? this.rate,
      quantity: quantity ?? this.quantity,
      currencyCode: currencyCode ?? this.currencyCode,
      date: date ?? this.date,
      feeType: feeType ?? this.feeType,
      description: description ?? this.description,
    );
  }

  factory AdrFee.fromJson(dynamic json) {
    if (json is! Map) {
      return const AdrFee(id: '', symbol: '');
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    final id = json['id']?.toString() ?? json['ref_id']?.toString() ?? '';
    final accountNumber =
        json['account_number']?.toString() ?? json['account']?.toString();

    // Extract instrumentId from instrument URL if needed
    String? instrumentId = json['instrument_id']?.toString();
    if (instrumentId == null && json['instrument'] != null) {
      final instStr = json['instrument'].toString();
      instrumentId = instStr
          .replaceAll('https://api.robinhood.com/instruments/', '')
          .replaceAll('/', '');
    }

    final symbol =
        json['symbol']?.toString().toUpperCase() ??
        json['ticker']?.toString().toUpperCase() ??
        '';
    final amount =
        parseDouble(json['amount']) ?? parseDouble(json['fee_amount']) ?? 0.0;
    final rate =
        parseDouble(json['rate']) ??
        parseDouble(json['fee_rate']) ??
        parseDouble(json['rate_per_share']) ??
        0.0;
    final quantity =
        parseDouble(json['quantity']) ??
        parseDouble(json['shares']) ??
        parseDouble(json['position']) ??
        0.0;

    String currencyCode = 'USD';
    if (json['currency_code'] != null) {
      currencyCode = json['currency_code'].toString();
    } else if (json['amount'] is Map &&
        json['amount']['currency_code'] != null) {
      currencyCode = json['amount']['currency_code'].toString();
    } else if (json['rate'] is Map && json['rate']['currency_code'] != null) {
      currencyCode = json['rate']['currency_code'].toString();
    }

    final date =
        parseDate(json['date']) ??
        parseDate(json['paid_at']) ??
        parseDate(json['created_at']);
    final feeType =
        json['fee_type']?.toString().toLowerCase() ??
        json['type']?.toString().toLowerCase() ??
        'custody_fee';
    final description =
        json['description']?.toString() ??
        json['memo']?.toString() ??
        'ADR Pass-Through Fee';

    return AdrFee(
      id: id,
      accountNumber: accountNumber,
      instrumentId: instrumentId,
      symbol: symbol,
      amount: amount.abs(),
      rate: rate,
      quantity: quantity,
      currencyCode: currencyCode,
      date: date,
      feeType: feeType,
      description: description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (accountNumber != null) 'account_number': accountNumber,
      if (instrumentId != null) 'instrument_id': instrumentId,
      'symbol': symbol,
      'amount': amount,
      'rate': rate,
      'quantity': quantity,
      'currency_code': currencyCode,
      if (date != null) 'date': date!.toIso8601String(),
      'fee_type': feeType,
      if (description != null) 'description': description,
    };
  }

  String get formattedAmount => _currencyFormat.format(amount);
  String get formattedRate =>
      rate > 0 ? '\$${rate.toStringAsFixed(3)} / sh' : '';
  String get formattedQuantity => quantity % 1 == 0
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(2);
  String get formattedDate => date != null ? _dateFormat.format(date!) : '—';

  String get feeTypeLabel {
    switch (feeType) {
      case 'custody_fee':
        return 'ADR Custody Fee';
      case 'dividend_fee':
        return 'ADR Dividend Fee';
      case 'pass_through':
        return 'Pass-Through Fee';
      default:
        return 'ADR Service Fee';
    }
  }
}

/// Represents foreign tax withholding classification and tax treaty status for an instrument.
/// Robinhood endpoint: /tax_info/instrument/{instrument_id}/withholding_status/
class TaxWithholdingStatus {
  final String instrumentId;
  final String symbol;
  final String? country; // ISO code, e.g. "GB", "NL", "KY", "JP"
  final String? countryName;
  final double withholdingRate; // e.g. 0.15 for 15%
  final double? treatyRate; // e.g. 0.15 for 15% under US tax treaty
  final String
  status; // 'exempt', 'reduced', 'standard', 'subject_to_withholding'
  final String? description;

  const TaxWithholdingStatus({
    required this.instrumentId,
    required this.symbol,
    this.country,
    this.countryName,
    this.withholdingRate = 0.0,
    this.treatyRate,
    this.status = 'standard',
    this.description,
  });

  factory TaxWithholdingStatus.fromJson(dynamic json, {String? defaultSymbol}) {
    if (json is! Map) {
      return TaxWithholdingStatus(
        instrumentId: '',
        symbol: defaultSymbol ?? '',
      );
    }

    final instrumentId =
        json['instrument_id']?.toString() ??
        json['instrument']?.toString() ??
        '';
    final symbol =
        json['symbol']?.toString().toUpperCase() ??
        defaultSymbol?.toUpperCase() ??
        '';
    final country =
        json['country']?.toString().toUpperCase() ??
        json['country_code']?.toString().toUpperCase();
    final countryName =
        json['country_name']?.toString() ?? json['jurisdiction']?.toString();
    final withholdingRate =
        parseDouble(json['withholding_rate']) ??
        parseDouble(json['rate']) ??
        parseDouble(json['tax_rate']) ??
        0.0;
    final treatyRate =
        parseDouble(json['treaty_rate']) ??
        parseDouble(json['tax_treaty_rate']);
    final status =
        json['status']?.toString().toLowerCase() ??
        (withholdingRate == 0.0 ? 'exempt' : 'standard');
    final description =
        json['description']?.toString() ?? json['notes']?.toString();

    return TaxWithholdingStatus(
      instrumentId: instrumentId,
      symbol: symbol,
      country: country,
      countryName: countryName,
      withholdingRate: withholdingRate,
      treatyRate: treatyRate,
      status: status,
      description: description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instrument_id': instrumentId,
      'symbol': symbol,
      if (country != null) 'country': country,
      if (countryName != null) 'country_name': countryName,
      'withholding_rate': withholdingRate,
      if (treatyRate != null) 'treaty_rate': treatyRate,
      'status': status,
      if (description != null) 'description': description,
    };
  }

  bool get isExempt =>
      withholdingRate == 0.0 || status.contains('exempt') || status == 'none';

  String get formattedWithholdingRate =>
      '${(withholdingRate * 100).toStringAsFixed(1).replaceAll('.0', '')}%';

  String? get formattedTreatyRate => treatyRate != null
      ? '${(treatyRate! * 100).toStringAsFixed(1).replaceAll('.0', '')}%'
      : null;

  String get statusLabel {
    if (isExempt) return 'Exempt (0%)';
    if (treatyRate != null && treatyRate! < withholdingRate) {
      return 'Treaty Reduced ($formattedTreatyRate)';
    }
    return 'Standard ($formattedWithholdingRate)';
  }

  Color get statusColor {
    if (isExempt) return Colors.green;
    if (treatyRate != null && treatyRate! < withholdingRate) return Colors.blue;
    return Colors.orange;
  }
}

/// Aggregates all tax forms, statements, confirmations, ADR fees, and foreign tax data.
class TaxDocumentsSummary {
  final List<AccountDocument> documents;
  final List<AdrFee> adrFees;
  final List<TaxWithholdingStatus> withholdings;

  const TaxDocumentsSummary({
    this.documents = const [],
    this.adrFees = const [],
    this.withholdings = const [],
  });

  int get totalDocuments => documents.length;

  List<AccountDocument> get form1099Documents =>
      documents.where((d) => d.is1099).toList();

  List<AccountDocument> get statementDocuments =>
      documents.where((d) => d.isAccountStatement).toList();

  List<AccountDocument> get confirmationDocuments =>
      documents.where((d) => d.isTradeConfirmation).toList();

  double get totalAdrFeesAmount =>
      adrFees.fold(0.0, (sum, item) => sum + item.amount);

  String get formattedTotalAdrFees =>
      _currencyFormat.format(totalAdrFeesAmount);

  String get formattedCompactTotalAdrFees =>
      _compactCurrencyFormat.format(totalAdrFeesAmount);

  List<int> get availableTaxYears {
    final years = <int>{};
    for (var doc in form1099Documents) {
      years.add(doc.taxYear);
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  int? get latestTaxYear =>
      availableTaxYears.isNotEmpty ? availableTaxYears.first : null;
}
