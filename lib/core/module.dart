import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_modular/flutter_modular.dart' show Module, Modular, Injector;
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'local_db/app_database.dart';
import 'local_db/bible_import_service.dart';
import 'local_db/bible_repository.dart';
import 'repositories/media_repository.dart';
import 'repositories/organization_repository.dart';
import 'repositories/template_repository.dart';
import 'services/app_prefs_service.dart';
import 'services/bible_download_service.dart';
import 'services/introduce_api_service.dart';
import 'services/supabase_service.dart';

class CoreModule extends Module {
  @override
  void exportedBinds(Injector i) {
    i.addLazySingleton<AppPrefsService>(AppPrefsService.new);
    i.addLazySingleton<SupabaseService>(() => SupabaseService(Modular.get<AppPrefsService>()));
    i.addLazySingleton<Dio>(() => _createDio());
    i.addInstance<AppDatabase>(AppDatabase.instance);
    i.addLazySingleton<BibleImportService>(BibleImportService.new);
    i.addLazySingleton<BibleRepository>(BibleRepository.new);
    i.addLazySingleton<OrganizationRepository>(OrganizationRepository.new);
    i.addLazySingleton<TemplateRepository>(TemplateRepository.new);
    i.addLazySingleton<IntroduceApiService>(() => IntroduceApiService(Modular.get<Dio>()));
    i.addLazySingleton<MediaRepository>(
      () => MediaRepository(Modular.get<SupabaseService>(), Modular.get<IntroduceApiService>()),
    );
    i.addLazySingleton<BibleDownloadService>(
      () => BibleDownloadService(Modular.get<Dio>(), Modular.get<AppDatabase>()),
    );
  }

  static Dio _createDio() {
    const timeout = Duration(seconds: 60);

    final dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_URL'] ?? '',
        connectTimeout: timeout,
        receiveTimeout: timeout,
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      PrettyDioLogger(
        requestBody: true,
        requestHeader: false,
        responseHeader: false,
        responseBody: true,
        error: true,
        enabled: AppEnvX.isDev,
        filter: (options, args) {
          // silenciar uploads de imágenes/storage
          if (options.path.contains('/storage/')) return false;
          return true;
        },
      ),
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // 401 → token expirado, en el futuro: refresh + retry
          handler.next(error);
        },
      ),
    ]);

    return dio;
  }
}
