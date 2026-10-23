import '../../../core/utils/app_time_zone.dart';
import '../../sync/data/finance_repository.dart';

class TimeZonePreferencesRepository {
  final FinanceRepository source;
  const TimeZonePreferencesRepository(this.source);

  AppTimeZone get selected {
    final saved = source.state['display_time_zone'];
    if (saved is! Map ||
        saved['schema'] != 1 ||
        saved['user_id'] != source.userId) {
      return AppTimeZone.device;
    }
    return AppTimeZone.values.firstWhere(
      (zone) => zone.name == saved['selection'],
      orElse: () => AppTimeZone.device,
    );
  }

  void save(AppTimeZone zone) => source.atomic(() {
    source.state['display_time_zone'] = {
      'schema': 1,
      'user_id': source.userId,
      'selection': zone.name,
    };
  });
}
