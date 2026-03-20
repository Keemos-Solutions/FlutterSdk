import '../client.dart';
import '../models_household.dart';

class HouseholdsApi {
  final KeemosClient client;

  HouseholdsApi(this.client);

  Future<List<Household>> listHouseholds() async {
    final resp = await client.get('/api/v1/households');
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => Household.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Household> createHousehold(Map<String, dynamic> payload) async {
    final resp = await client.post('/api/v1/households', data: payload);
    final body = resp.data as Map<String, dynamic>;
    return Household.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Household> getHousehold(String householdId) async {
    final resp = await client.get('/api/v1/households/$householdId');
    final body = resp.data as Map<String, dynamic>;
    final payload = body['data'] as Map<String, dynamic>? ?? body;
    return Household.fromJson(payload);
  }

  Future<List<dynamic>> listDevices(String householdId) async {
    final resp = await client.get('/api/v1/households/$householdId/devices');
    final body = resp.data as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? [];
  }
}
