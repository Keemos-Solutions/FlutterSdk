import 'package:dio/dio.dart';
import 'auth.dart';
import 'apis/households_api.dart';
import 'apis/devices_api.dart';
import 'apis/rooms_api.dart';
import 'apis/automations_api.dart';
import 'apis/notifications_api.dart';

class KeemosClient {
  final Dio dio;
  final AuthManager authManager;

  KeemosClient({Dio? dio, required this.authManager}) : dio = dio ?? Dio() {
    this.dio.options.baseUrl = 'https://api.keemos.vn';
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await authManager.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    }, onError: (error, handler) async {
      // Basic 401 refresh flow placeholder
      if (error.response?.statusCode == 401) {
        final refreshed = await authManager.tryRefresh();
        if (refreshed) {
          final token = await authManager.getAccessToken();
          if (token != null) {
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final cloneReq = await dio.fetch(opts);
              return handler.resolve(cloneReq);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
      }
      return handler.next(error);
    }));
    // initialize API wrappers for ergonomic usage: client.household.getHousehold(...)
    household = HouseholdsApi(this);
    devices = DevicesApi(this);
    rooms = RoomsApi(this);
    automations = AutomationsApi(this);
    notifications = NotificationsApi(this);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get(path, queryParameters: queryParameters);
  }

  // ergonomic API wrappers
  late final HouseholdsApi household;
  late final DevicesApi devices;
  late final RoomsApi rooms;
  late final AutomationsApi automations;
  late final NotificationsApi notifications;
}
