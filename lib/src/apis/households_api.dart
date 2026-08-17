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
    // Invalidate cached household lists/details after a write.
    await client.invalidateCacheByPrefix('/api/v1/households');
    return Household.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Household> getHousehold(String householdId) async {
    final resp = await client.get('/api/v1/households/$householdId');
    final body = resp.data as Map<String, dynamic>;
    final payload = body['data'] as Map<String, dynamic>? ?? body;
    return Household.fromJson(payload);
  }

  Future<Household> updateHousehold(
    String householdId, {
    required String name,
    String? address,
    String? city,
    HouseholdType? type,
    double? latitude,
    double? longitude,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('name must be at least 1 character.');
    }

    final payload = <String, dynamic>{
      'name': name,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (type != null) 'type': type.wireValue,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };

    // Backend enforces Owner/Admin permissions for this endpoint.
    final resp = await client.put('/api/v1/households/$householdId', data: payload);
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;

    await client.invalidateCacheByPrefix('/api/v1/households');
    return Household.fromJson(data);
  }

  Future<List<dynamic>> listDevices(String householdId) async {
    final resp = await client.get('/api/v1/households/$householdId/devices');
    final body = resp.data as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? [];
  }

  Future<List<HouseholdMember>> listMembers(String householdId) async {
    final resp = await client.get('/api/v1/households/$householdId/members');
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => HouseholdMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> inviteMember(String householdId, {required String email, String role = 'member'}) async {
    await client.post('/api/v1/households/$householdId/members', data: {
      'email': email,
      'role': role,
    });
    await client.invalidateCacheByPrefix('/api/v1/households/$householdId/members');
  }

  Future<void> removeMember(String householdId, String userId) async {
    await client.delete('/api/v1/households/$householdId/members/$userId');
    await client.invalidateCacheByPrefix('/api/v1/households/$householdId/members');
  }

  Future<InvitationCodeResponse> createInvitationCode(String householdId) async {
    final resp = await client.post('/api/v1/households/$householdId/invitations/codes');
    final body = resp.data as Map<String, dynamic>;
    final payload = body['data'] as Map<String, dynamic>? ?? body;
    return InvitationCodeResponse.fromJson(payload);
  }

  Future<Map<String, dynamic>> joinByInvitationCode(String code) async {
    final resp = await client.get('/api/v1/households/join/$code');
    final body = resp.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? body;
  }
}
