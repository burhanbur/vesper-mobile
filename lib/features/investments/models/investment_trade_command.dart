import 'package:uuid/uuid.dart';

import 'investment_history.dart';
import 'investment_position.dart';
import 'investment_settlement.dart';

/// Prepared push-only command. Construction does not persist or authorize a trade.
/// The repository must atomically persist this envelope and its optimistic state
/// before sending it; retries must reuse the persisted envelope, not prepare again.
class InvestmentTradeCommand {
  final String id;
  final String linkedTransactionId;
  final String accountId;
  final String cashAccountId;
  final String instrumentId;
  final String type;
  final String quantity;
  final String pricePerUnit;
  final String fee;
  final String transactedAt;
  final String? description;
  final InvestmentSettlement settlement;
  final InvestmentPosition positionAfter;
  final String cashBalanceAfter;

  const InvestmentTradeCommand._({
    required this.id,
    required this.linkedTransactionId,
    required this.accountId,
    required this.cashAccountId,
    required this.instrumentId,
    required this.type,
    required this.quantity,
    required this.pricePerUnit,
    required this.fee,
    required this.transactedAt,
    required this.description,
    required this.settlement,
    required this.positionAfter,
    required this.cashBalanceAfter,
  });

  factory InvestmentTradeCommand.prepare({
    required InvestmentHistory history,
    required String accountId,
    required String cashAccountId,
    required String instrumentId,
    required String cashBalance,
    required String type,
    required String quantity,
    required String pricePerUnit,
    required DateTime at,
    String fee = '0',
    String? description,
  }) {
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    for (final value in [accountId, cashAccountId, instrumentId]) {
      final match = uuid.firstMatch(value);
      if (match == null || match.end != value.length) {
        throw const FormatException('Identitas command investasi tidak valid.');
      }
    }
    final note = description?.trim();
    if (history.accountId != accountId ||
        accountId == cashAccountId ||
        (note?.length ?? 0) > 5000) {
      throw const FormatException('Akun atau deskripsi investasi tidak valid.');
    }
    // Reject sub-millisecond input instead of changing its ordering by rounding.
    if (!at.isUtc ||
        at.microsecond != 0 ||
        at.year < 1 ||
        at.year > 9999 ||
        !history.canAppend(instrumentId, at)) {
      throw const FormatException(
        'Waktu trade harus UTC dan lebih baru dari histori.',
      );
    }
    final settlement = InvestmentSettlement.calculate(
      type: type,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      fee: fee,
    );
    final position = type == 'DIVIDEND'
        ? history.position(instrumentId)
        : history
              .position(instrumentId)
              .advance(
                InvestmentPositionTrade(
                  type: type,
                  quantity: quantity,
                  pricePerUnit: pricePerUnit,
                ),
              );
    final balance = _minor(cashBalance);
    final amount = _minor(settlement.amount);
    final next = balance + (type == 'BUY' ? -amount : amount);
    if (next.abs() > BigInt.from(10).pow(20) - BigInt.one) {
      throw const FormatException('Saldo kas melampaui batas maksimum.');
    }
    // Negative balances are permitted by the server; do not add a new rule here.
    final magnitude = next.abs();
    return InvestmentTradeCommand._(
      id: const Uuid().v4(),
      linkedTransactionId: const Uuid().v4(),
      accountId: accountId,
      cashAccountId: cashAccountId,
      instrumentId: instrumentId,
      type: type,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      fee: fee,
      transactedAt: DateTime.fromMillisecondsSinceEpoch(
        at.millisecondsSinceEpoch,
        isUtc: true,
      ).toIso8601String(),
      description: note == null || note.isEmpty ? null : note,
      settlement: settlement,
      positionAfter: position,
      cashBalanceAfter:
          '${next.isNegative ? '-' : ''}${magnitude ~/ BigInt.from(100)}.${(magnitude % BigInt.from(100)).toString().padLeft(2, '0')}',
    );
  }

  static BigInt _minor(String text) {
    final match = RegExp(r'^-?(0|[1-9]\d{0,17})(\.\d{1,2})?$').firstMatch(text);
    if (match == null || match.end != text.length) {
      throw const FormatException('Saldo kas tidak valid.');
    }
    final parts = text.replaceFirst('-', '').split('.');
    final magnitude =
        BigInt.parse(parts.first) * BigInt.from(100) +
        BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    return text.startsWith('-') ? -magnitude : magnitude;
  }

  Map<String, dynamic> toPushItem() => {
    'entity_type': 'investment_transactions',
    'entity_id': id,
    'operation': 'CREATE',
    'client_version': '0',
    'payload': {
      'account_id': accountId,
      'cash_account_id': cashAccountId,
      'instrument_id': instrumentId,
      'linked_transaction_id': linkedTransactionId,
      'type': type,
      'quantity': quantity,
      'price_per_unit': pricePerUnit,
      'fee': fee,
      'transacted_at': transactedAt,
      'description': description,
    },
  };
}
