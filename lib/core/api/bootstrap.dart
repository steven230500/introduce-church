import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/env.dart';
import '../services/app_prefs_service.dart';
import 'api_client.dart';
import 'presentation_socket.dart';

/// The base URL every window talks to.
String get apiBaseUrl => dotenv.env['API_URL'] ?? '';

/// Builds a Dio configured for the Introduce API.
Dio buildDio() {
  const timeout = Duration(seconds: 30);
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: timeout,
      receiveTimeout: timeout,
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    PrettyDioLogger(
      requestBody: true,
      requestHeader: false,
      responseHeader: false,
      responseBody: true,
      error: true,
      enabled: AppEnvX.isDev,
      filter: (options, args) {
        // Uploads are megabytes of binary; logging them helps nobody.
        if (options.path.contains('/media/upload')) return false;
        return true;
      },
    ),
  );

  return dio;
}

/// What a secondary window needs to follow the operator.
typedef WindowClients = ({ApiClient api, PresentationSocket socket});

/// Builds an API client and socket for the projector or stage window.
///
/// Those windows run in their own engine with no access to the main window's
/// objects, so each one reads the session the operator already signed in with
/// and opens its own connection.
Future<WindowClients> bootstrapWindowClients() async {
  final prefs = AppPrefsService();
  final api = ApiClient(buildDio(), prefs);
  await api.restore();
  final socket = PresentationSocket(api, apiBaseUrl);
  return (api: api, socket: socket);
}
