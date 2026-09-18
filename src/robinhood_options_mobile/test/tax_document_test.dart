import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/tax_document.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('AccountDocument Model Tests', () {
    test('parses Form 1099 tax document correctly', () {
      final json = {
        'id': 'doc_1099_2025',
        'account_number': 'ACCT12345',
        'type': '1099',
        'title': '2025 Consolidated Form 1099',
        'date': '2026-02-15T08:00:00Z',
        'year': 2025,
        'download_url':
            'https://api.robinhood.com/documents/doc_1099_2025/download/',
        'file_size': 458752,
        'state': 'ready',
        'created_at': '2026-02-15T08:00:00Z',
        'updated_at': '2026-02-15T08:00:00Z',
      };

      final doc = AccountDocument.fromJson(json);
      expect(doc.id, 'doc_1099_2025');
      expect(doc.accountNumber, 'ACCT12345');
      expect(doc.type, '1099');
      expect(doc.title, '2025 Consolidated Form 1099');
      expect(doc.taxYear, 2025);
      expect(doc.year, 2025);
      expect(doc.is1099, isTrue);
      expect(doc.isAccountStatement, isFalse);
      expect(doc.isTradeConfirmation, isFalse);
      expect(doc.typeLabel, 'Tax Form (1099)');
      expect(doc.formattedFileSize, '448 KB');
      expect(doc.state, 'ready');
      expect(doc.downloadUrl, contains('doc_1099_2025'));
    });

    test('parses monthly account statement correctly', () {
      final json = {
        'id': 'doc_stmt_2026_08',
        'account_number': 'ACCT12345',
        'type': 'account_statement',
        'title': 'August 2026 Account Statement',
        'date': '2026-08-31',
        'year': 2026,
        'download_url':
            'https://api.robinhood.com/documents/doc_stmt_2026_08/download/',
        'file_size': 184320,
        'state': 'ready',
      };

      final doc = AccountDocument.fromJson(json);
      expect(doc.id, 'doc_stmt_2026_08');
      expect(doc.isAccountStatement, isTrue);
      expect(doc.is1099, isFalse);
      expect(doc.typeLabel, 'Account Statement');
      expect(doc.formattedDate, 'August 2026');
      expect(doc.formattedFileSize, '180 KB');
    });

    test('parses trade confirmation correctly', () {
      final json = {
        'id': 'doc_conf_1',
        'type': 'trade_confirmation',
        'title': 'Trade Confirmation - NVDA Equity Buy',
        'date': '2026-09-08',
        'file_size': 65536,
      };

      final doc = AccountDocument.fromJson(json);
      expect(doc.isTradeConfirmation, isTrue);
      expect(doc.typeLabel, 'Trade Confirmation');
      expect(doc.formattedFileSize, '64 KB');
    });

    test('roundtrips to and from json', () {
      final original = AccountDocument(
        id: 'doc_rt_1',
        accountNumber: 'ACC_RT',
        type: '1099',
        title: '2024 Consolidated 1099',
        date: DateTime(2025, 2, 10),
        year: 2024,
        downloadUrl: 'https://example.com/doc.pdf',
        fileSize: 1024 * 1024 * 2, // 2MB
        state: 'ready',
      );

      final json = original.toJson();
      final parsed = AccountDocument.fromJson(json);
      expect(parsed.id, original.id);
      expect(parsed.title, original.title);
      expect(parsed.year, original.year);
      expect(parsed.fileSize, original.fileSize);
      expect(parsed.formattedFileSize, '2.0 MB');
    });

    test('handles empty and invalid json gracefully', () {
      final doc = AccountDocument.fromJson(null);
      expect(doc.id, '');
      expect(doc.title, 'Account Document');
      expect(doc.formattedFileSize, '');
    });
  });

  group('AdrFee Model Tests', () {
    test('parses ADR custody fee correctly', () {
      final json = {
        'id': 'adr_fee_01',
        'account_number': 'ACCT12345',
        'instrument_id': 'inst_baba',
        'symbol': 'baba',
        'amount': '4.50',
        'rate': '0.02',
        'quantity': '225',
        'currency_code': 'USD',
        'date': '2026-06-15T12:00:00Z',
        'fee_type': 'custody_fee',
        'description': 'Alibaba Group ADR Annual Custody Fee',
      };

      final fee = AdrFee.fromJson(json);
      expect(fee.id, 'adr_fee_01');
      expect(fee.symbol, 'BABA');
      expect(fee.amount, 4.50);
      expect(fee.rate, 0.02);
      expect(fee.quantity, 225.0);
      expect(fee.feeType, 'custody_fee');
      expect(fee.feeTypeLabel, 'ADR Custody Fee');
      expect(fee.formattedAmount, '\$4.50');
      expect(fee.formattedRate, '\$0.020 / sh');
      expect(fee.formattedQuantity, '225');
      expect(fee.formattedDate, contains('Jun 15'));
    });

    test('roundtrips to and from json', () {
      final original = AdrFee(
        id: 'adr_rt_1',
        symbol: 'TSM',
        amount: 3.0,
        rate: 0.015,
        quantity: 200.0,
        currencyCode: 'USD',
        date: DateTime(2026, 5, 18),
        feeType: 'pass_through',
        description: 'TSMC Pass-Through Fee',
      );

      final json = original.toJson();
      final parsed = AdrFee.fromJson(json);
      expect(parsed.id, original.id);
      expect(parsed.symbol, 'TSM');
      expect(parsed.amount, 3.0);
      expect(parsed.rate, 0.015);
      expect(parsed.quantity, 200.0);
    });

    test('handles empty and invalid json gracefully', () {
      final fee = AdrFee.fromJson(null);
      expect(fee.id, '');
      expect(fee.symbol, '');
      expect(fee.amount, 0.0);
    });
  });

  group('TaxWithholdingStatus Model Tests', () {
    test('parses exempt UK dividend status correctly', () {
      final json = {
        'instrument_id': 'inst_bti',
        'symbol': 'bti',
        'country': 'gb',
        'country_name': 'United Kingdom',
        'withholding_rate': 0.0,
        'treaty_rate': 0.0,
        'status': 'exempt',
        'description': 'No UK withholding tax under US-UK treaty.',
      };

      final status = TaxWithholdingStatus.fromJson(json);
      expect(status.symbol, 'BTI');
      expect(status.country, 'GB');
      expect(status.countryName, 'United Kingdom');
      expect(status.withholdingRate, 0.0);
      expect(status.isExempt, isTrue);
      expect(status.statusLabel, 'Exempt (0%)');
      expect(status.formattedWithholdingRate, '0%');
    });

    test('parses treaty reduced Netherlands dividend status correctly', () {
      final json = {
        'instrument_id': 'inst_asml',
        'symbol': 'ASML',
        'country': 'NL',
        'country_name': 'Netherlands',
        'withholding_rate': 0.15,
        'treaty_rate': 0.15,
        'status': 'reduced',
      };

      final status = TaxWithholdingStatus.fromJson(json);
      expect(status.isExempt, isFalse);
      expect(status.formattedWithholdingRate, '15%');
      expect(status.statusLabel, 'Standard (15%)');
    });

    test('roundtrips to and from json', () {
      final original = const TaxWithholdingStatus(
        instrumentId: 'inst_tw',
        symbol: 'TSM',
        country: 'TW',
        countryName: 'Taiwan',
        withholdingRate: 0.21,
        treatyRate: 0.21,
        status: 'standard',
        description: 'Standard 21% non-resident rate.',
      );

      final json = original.toJson();
      final parsed = TaxWithholdingStatus.fromJson(json);
      expect(parsed.instrumentId, original.instrumentId);
      expect(parsed.symbol, 'TSM');
      expect(parsed.withholdingRate, 0.21);
      expect(parsed.country, 'TW');
    });
  });

  group('TaxDocumentsSummary Aggregation Tests', () {
    test('computes totals, available years, and counts accurately', () {
      final docs = [
        AccountDocument(
          id: 'd1',
          type: '1099',
          title: '2025 Consolidated Form 1099',
          year: 2025,
          date: DateTime(2026, 2, 15),
        ),
        AccountDocument(
          id: 'd2',
          type: '1099',
          title: '2024 Consolidated Form 1099',
          year: 2024,
          date: DateTime(2025, 2, 12),
        ),
        AccountDocument(
          id: 'd3',
          type: 'account_statement',
          title: 'August 2026 Account Statement',
          date: DateTime(2026, 8, 31),
        ),
        AccountDocument(
          id: 'd4',
          type: 'trade_confirmation',
          title: 'Trade Confirmation - AAPL',
          date: DateTime(2026, 9, 1),
        ),
      ];

      final adrFees = [
        const AdrFee(id: 'a1', symbol: 'BABA', amount: 4.50),
        const AdrFee(id: 'a2', symbol: 'TSM', amount: 3.00),
      ];

      final withholdings = [
        const TaxWithholdingStatus(
          instrumentId: 'i1',
          symbol: 'BTI',
          withholdingRate: 0.0,
        ),
      ];

      final summary = TaxDocumentsSummary(
        documents: docs,
        adrFees: adrFees,
        withholdings: withholdings,
      );

      expect(summary.totalDocuments, 4);
      expect(summary.form1099Documents.length, 2);
      expect(summary.statementDocuments.length, 1);
      expect(summary.confirmationDocuments.length, 1);
      expect(summary.totalAdrFeesAmount, 7.50);
      expect(summary.formattedTotalAdrFees, '\$7.50');
      expect(summary.availableTaxYears, [2025, 2024]);
      expect(summary.latestTaxYear, 2025);
    });
  });

  group('DemoService Tax Documents Integration Tests', () {
    final user = BrokerageUser(
      BrokerageSource.demo,
      'demo_user',
      null,
      null,
    );
    final demoService = DemoService();

    test('returns demo 1099s and account statements', () async {
      final allDocs = await demoService.getAccountDocumentsModel(user);
      expect(allDocs.isNotEmpty, isTrue);
      expect(allDocs.any((d) => d.is1099), isTrue);
      expect(allDocs.any((d) => d.isAccountStatement), isTrue);
      expect(allDocs.any((d) => d.isTradeConfirmation), isTrue);

      final only1099 =
          await demoService.getAccountDocumentsModel(user, type: '1099');
      expect(only1099.every((d) => d.type == '1099'), isTrue);
      expect(only1099.length, 3);
    });

    test('returns demo ADR pass-through fees', () async {
      final adrFees = await demoService.getAdrFeesModel(user);
      expect(adrFees.length, 4);
      expect(adrFees.any((f) => f.symbol == 'BABA'), isTrue);
      expect(adrFees.any((f) => f.symbol == 'TSM'), isTrue);
      expect(adrFees.any((f) => f.symbol == 'BTI'), isTrue);
      expect(adrFees.any((f) => f.symbol == 'ASML'), isTrue);
    });

    test('returns foreign tax withholding status for BTI and ASML', () async {
      final btiStatus = await demoService.getTaxWithholdingStatusModel(
        user,
        'BTI',
        symbol: 'BTI',
      );
      expect(btiStatus, isNotNull);
      expect(btiStatus!.country, 'GB');
      expect(btiStatus.isExempt, isTrue);

      final asmlStatus = await demoService.getTaxWithholdingStatusModel(
        user,
        'ASML',
        symbol: 'ASML',
      );
      expect(asmlStatus, isNotNull);
      expect(asmlStatus!.country, 'NL');
      expect(asmlStatus.withholdingRate, 0.15);
    });
  });
}
