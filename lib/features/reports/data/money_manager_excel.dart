import 'dart:convert';

import 'financial_export_repository.dart';

const moneyManagerExcelHeaders = [
  'Date',
  'Account',
  'Category',
  'Subcategory',
  'Note',
  'IDR',
  'Income/Expense',
  'Description',
  'Amount',
  'Currency',
  'Account',
];

/// The reference .xls is an Excel HTML workbook, rather than a BIFF workbook.
String moneyManagerExcel(FinancialExport snapshot) {
  final accounts = {for (final a in snapshot.accounts) a['id']: a};
  final categories = {for (final c in snapshot.categories) c['id']: c};
  final html = StringBuffer(
    '<html xmlns:x="urn:schemas-microsoft-com:office:excel"><head><meta http-equiv="Content-Type" content="text/html; charset=utf-8"><meta name="ProgId" content="Excel.Sheet"><style>td,th{border:1px solid #a6a6a6;font-family:Calibri;white-space:pre-wrap}th{background:#c2c2c2}.text{mso-number-format:"\\@"}.amount{mso-number-format:"0.00"}</style></head><body><table><tr>',
  );
  final headers = [...moneyManagerExcelHeaders]..[5] = snapshot.currency;
  for (final h in headers) {
    html.write('<th>${const HtmlEscape().convert(h)}</th>');
  }
  html.write('</tr>');
  for (final t in moneyManagerExcelRows(snapshot)) {
    final amount = financialMinor('${t['amount']}');
    final type = '${t['type']}';
    final account = accounts[t['account_id']];
    final category = categories[t['category_id']];
    final local = snapshot.timeZone.at(DateTime.parse('${t['transacted_at']}'));
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
    final movement = type == 'TRANSFER'
        ? (amount.isNegative ? 'Transfer-Out' : 'Transfer-In')
        : (type == 'EXPENSE' || type == 'INVESTMENT_BUY'
              ? 'Expense'
              : 'Income');
    final values = [
      date,
      account?['name'] ?? '',
      type == 'TRANSFER'
          ? (accounts[t['export_peer_account_id']]?['name'] ?? '')
          : (category?['name'] ?? ''),
      '', // Vesper categories are flat; preserve the reference's column.
      t['description'] ?? '',
      financialDecimal(amount.abs()),
      movement,
      '',
      financialDecimal(amount.abs()),
      snapshot.currency,
      financialDecimal(
        amount.abs(),
      ), // Reference's final Account = account amount.
    ];
    html.write('<tr>');
    for (var i = 0; i < values.length; i++) {
      // Excel supports 15 significant digits. Retain larger amounts as text.
      final numeric =
          (i == 5 || i == 8 || i == 10) && amount.abs().toString().length <= 15;
      var value = '${values[i]}';
      if (!numeric && RegExp(r'^[\s\u0000-\u001f]*[=+@-]').hasMatch(value)) {
        value = "'$value";
      }
      final text = const HtmlEscape().convert(value).replaceAll('\n', '<br>');
      html.write(
        '<td class="${numeric ? 'amount' : 'text'}"${numeric ? '' : ' x:str'}>$text</td>',
      );
    }
    html.write('</tr>');
  }
  html.write('</table></body></html>');
  return html.toString();
}

Iterable<Map<String, dynamic>> moneyManagerExcelRows(
  FinancialExport snapshot,
) sync* {
  final outgoing = {
    for (final t in snapshot.transactions)
      if (t['type'] == 'TRANSFER' &&
          financialMinor('${t['amount']}').isNegative &&
          t['transfer_id'] != null)
        t['transfer_id'],
  };
  for (final t in snapshot.transactions) {
    if (t['type'] == 'TRANSFER' &&
        !financialMinor('${t['amount']}').isNegative &&
        outgoing.contains(t['transfer_id'])) {
      continue;
    }
    yield t;
  }
}
