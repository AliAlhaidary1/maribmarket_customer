import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand_config.dart';
import 'brand_service.dart';

final brandProvider =
    StateNotifierProvider<BrandNotifier, BrandConfig>((ref) => BrandNotifier());

class BrandNotifier extends StateNotifier<BrandConfig> {
  BrandNotifier() : super(BrandConfig.defaults);

  Future<void> load(String apiUrl) async {
    final service = BrandService(apiUrl);
    state = await service.load();
  }
}
