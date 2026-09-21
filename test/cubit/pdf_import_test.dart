import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/services/pdf_import_service.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

/// Stands in for the drawing of the pages, which needs a real PDF and the
/// engine behind it.
class _FakePdf implements PdfImportService {
  _FakePdf(this.pages);

  final List<String> pages;
  String? asked;

  @override
  Future<List<String>> renderPages(String filePath) async {
    asked = filePath;
    return pages;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('the announcements arrive as a PDF', () {
    late ControlCubit control;
    late _FakePdf pdf;

    Future<void> open({List<String> pages = const []}) async {
      pdf = _FakePdf(pages);
      control = ControlCubit(
        FakeControlRepository(
          rows: [collectionRow(id: 'c1', name: 'Domingo', items: [])],
        ),
        FakeTemplateRepository(),
        FakePrefsService(),
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
        pdfImport: pdf,
      );
      await control.load();
      final model = (control.state as ControlLoadedState).model;
      control.selectCollection(model.collections.first);
    }

    tearDown(() => control.close());

    test('every page lands in one element, in order', () async {
      await open(pages: ['/tmp/anuncios/page-001.png', '/tmp/anuncios/page-002.png']);

      final pages = await control.importPdfAsImages('/tmp/anuncios.pdf');

      expect(pages, 2);
      expect(pdf.asked, '/tmp/anuncios.pdf');
      final items = (control.state as ControlLoadedState).model.activeCollection!.items;
      expect(items.length, 1, reason: 'a presentation, not one element per page');
      expect(items.single.type, CollectionItemType.imageSlide);
      expect(items.single.slides.length, 2);
      expect(items.single.displayTitle, 'anuncios');
    });

    test('a PDF that draws nothing adds nothing', () async {
      await open(pages: const []);

      final pages = await control.importPdfAsImages('/tmp/vacio.pdf');

      expect(pages, 0);
      expect((control.state as ControlLoadedState).model.activeCollection!.items, isEmpty);
    });
  });
}
