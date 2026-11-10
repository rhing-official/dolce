import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:dolce/features/library/models/book.dart';
import 'package:dolce/features/library/models/shelf.dart';
import 'package:dolce/features/library/providers/library_provider.dart';

// 同期(syncAll)で同じファイルが二重登録されないことの回帰テスト
void main() {
  late Directory tmp;
  late Directory library;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dolce_sync_test');
    library = Directory('${tmp.path}/lib')..createSync();
    final support = Directory('${tmp.path}/support')..createSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => support.path);
    Hive.init('${tmp.path}/hive');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(BookAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(BookFormatAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(ShelfAdapter());
    await Hive.openBox<Book>('books');
    await Hive.openBox<Shelf>('shelves');
    for (final n in ['1', '2', '3', '4']) {
      final archive = Archive()..addFile(ArchiveFile('p1.png', 1, [0]));
      File('${library.path}/$n.cbz')
          .writeAsBytesSync(ZipEncoder().encode(archive)!);
    }
    await Hive.box<Shelf>('shelves')
        .put('s1', Shelf(id: 's1', name: 'lib', folderPath: library.path));
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  test('syncAllを並行して何度呼んでも冊数が増えない', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(libraryProvider.notifier);
    await Future.wait([notifier.syncAll(), notifier.syncAll(), notifier.syncAll()]);
    await notifier.syncAll();
    expect(Hive.box<Book>('books').length, 4);
  });

  test('既に重複登録されたBookは進捗の進んだ1冊に畳まれる', () async {
    final box = Hive.box<Book>('books');
    for (var i = 0; i < 3; i++) {
      box.put(
          'd$i',
          Book()
            ..id = 'd$i'
            ..title = '1'
            ..filePath = '${library.path}/1.cbz'
            ..shelfId = 's1'
            ..addedAt = DateTime(2026, 1, 1 + i)
            ..format = BookFormat.cbz
            ..totalPages = 10
            ..lastPage = i == 1 ? 7 : 0
            ..isFinished = false);
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(libraryProvider.notifier).syncAll();
    final books = box.values.toList();
    expect(books.length, 4);
    final one = books.where((b) => b.filePath.endsWith('/1.cbz')).toList();
    expect(one.length, 1);
    expect(one.single.lastPage, 7);
  });
}
