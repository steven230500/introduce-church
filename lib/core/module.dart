import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart' show Module, Modular, Injector;

import 'api/api_client.dart';
import 'api/bootstrap.dart';
import 'api/presentation_socket.dart';
import 'history/projection_recorder.dart';
import 'local_db/app_database.dart';
import 'local_db/bible_import_service.dart';
import 'local_db/bible_repository.dart';
import 'repositories/media_repository.dart';
import 'repositories/organization_repository.dart';
import 'repositories/template_repository.dart';
import 'services/app_prefs_service.dart';
import 'services/locale_controller.dart';
import 'services/bible_download_service.dart';
import 'services/update_checker.dart';

class CoreModule extends Module {
  @override
  void exportedBinds(Injector i) {
    i.addLazySingleton<AppPrefsService>(AppPrefsService.new);
    i.addSingleton<LocaleController>(() => LocaleController(Modular.get<AppPrefsService>()));
    i.addLazySingleton<Dio>(buildDio);

    // One client for the whole app: it owns the session, so a second instance
    // would refresh tokens the first one is still using.
    i.addLazySingleton<ApiClient>(
      () => ApiClient(Modular.get<Dio>(), Modular.get<AppPrefsService>()),
    );
    // One outbox for the process: two would each think the other's file was
    // theirs, and the same service would be sent twice.
    i.addLazySingleton<ProjectionOutbox>(ProjectionOutbox.new);
    i.addLazySingleton<HistoryRepository>(() => HistoryRepository(Modular.get<ApiClient>()));
    i.addLazySingleton<PresentationSocket>(
      () => PresentationSocket(Modular.get<ApiClient>(), apiBaseUrl),
    );

    i.addInstance<AppDatabase>(AppDatabase.instance);
    i.addLazySingleton<BibleImportService>(BibleImportService.new);
    i.addLazySingleton<BibleRepository>(BibleRepository.new);
    i.addLazySingleton<BibleDownloadService>(
      () => BibleDownloadService(Modular.get<Dio>(), Modular.get<AppDatabase>()),
    );

    i.addLazySingleton<OrganizationRepository>(
      () => OrganizationRepository(Modular.get<ApiClient>()),
    );
    i.addLazySingleton<TemplateRepository>(() => TemplateRepository(Modular.get<ApiClient>()));
    i.addLazySingleton<MediaRepository>(() => MediaRepository(Modular.get<ApiClient>()));

    // One for the process, so the sidebar and the settings see the same answer
    // and GitHub is asked once, not once per screen.
    i.addLazySingleton<UpdateChecker>(() => UpdateChecker());
  }
}
