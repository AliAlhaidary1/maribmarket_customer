import 'json_util.dart';

bool isSingleCityMode(List<Map<String, dynamic>> cities) => cities.length == 1;

Map<String, dynamic>? getSoleCity(List<Map<String, dynamic>> cities) {
  return isSingleCityMode(cities) ? cities.first : null;
}

Map<String, dynamic> normalizeCity(
  dynamic raw, [
  Map<String, dynamic> overrides = const {},
]) {
  final source = J.map(raw);
  final latitude = overrides['latitude'] ?? source['latitude'] ?? source['lat'];
  final longitude =
      overrides['longitude'] ?? source['longitude'] ?? source['lng'];
  return {
    'id': source['id'] ?? source['city_id'],
    'name': source['name'] ?? source['city'] ?? overrides['name'] ?? '',
    'state': source['state'] ?? '',
    'formatted_address':
        overrides['formatted_address'] ??
        source['formatted_address'] ??
        source['address'] ??
        source['name'] ??
        '',
    'latitude': latitude?.toString(),
    'longitude': longitude?.toString(),
    'boundary_points': source['boundary_points'],
    'radius': source['radius'],
    'max_deliverable_distance': source['max_deliverable_distance'],
    'min_amount_for_free_delivery': source['min_amount_for_free_delivery'],
    'delivery_charge_method': source['delivery_charge_method'],
    'fixed_charge': source['fixed_charge'],
    'per_km_charge': source['per_km_charge'],
    'time_to_travel': source['time_to_travel'],
    'distance': source['distance'],
    ...overrides,
  };
}

Map<String, dynamic>? cityFromAddress(
  Map<String, dynamic>? address,
  List<Map<String, dynamic>> cities,
) {
  if (address == null) return null;
  final byId = cities.cast<Map<String, dynamic>?>().firstWhere(
    (city) => '${city?['id']}' == '${address['city_id']}',
    orElse: () => null,
  );
  if (byId != null) {
    return normalizeCity(byId, {
      'formatted_address':
          address['address'] ?? address['formatted_address'] ?? byId['name'],
      'latitude': address['latitude'] ?? byId['latitude'],
      'longitude': address['longitude'] ?? byId['longitude'],
    });
  }
  if (address['latitude'] != null && address['longitude'] != null) {
    return normalizeCity({
      'id': address['city_id'],
      'name': address['city'] ?? address['name'] ?? '',
      'state': address['state'] ?? '',
      'formatted_address': address['address'] ?? '',
      'latitude': address['latitude'],
      'longitude': address['longitude'],
    });
  }
  return null;
}

({double latitude, double longitude})? shopCoordinates(
  Map<String, dynamic>? city,
) {
  final lat = double.tryParse('${city?['latitude']}');
  final lng = double.tryParse('${city?['longitude']}');
  if (lat == null || lng == null) return null;
  return (latitude: lat, longitude: lng);
}

bool canBrowseCitiesFromHeader({
  required bool isLoggedIn,
  required List cities,
}) {
  return !isLoggedIn && cities.length > 1;
}
