/// Builds `wss://…/api/v1/ws?token=…&household_id=…` (Keemos IoT WebSocket API).
Uri buildKeemosWebSocketUri({
  required String httpBaseUrl,
  required String token,
  String? householdId,
}) {
  final base = Uri.parse(httpBaseUrl);
  final scheme = base.scheme == 'https' ? 'wss' : 'ws';
  var path = base.path;
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final wsPath = path.isEmpty ? '/api/v1/ws' : '$path/api/v1/ws';
  final query = <String, String>{'token': token};
  if (householdId != null && householdId.isNotEmpty) {
    query['household_id'] = householdId;
  }
  return Uri(
    scheme: scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: wsPath,
    queryParameters: query,
  );
}
