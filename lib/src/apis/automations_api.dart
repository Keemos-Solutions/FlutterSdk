import '../client.dart';

class AutomationsApi {
  final KeemosClient client;

  AutomationsApi(this.client);

  Future<List<Map<String, dynamic>>> listAutomations() async {
    final resp = await client.get('/api/v1/automations');
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<bool> triggerAutomation(String automationId) async {
    final resp = await client.post('/api/v1/automations/$automationId/trigger');
    // assume success when 200/204
    return resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300;
  }
}
