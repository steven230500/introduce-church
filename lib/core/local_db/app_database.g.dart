// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BibleVersionsTable extends BibleVersions with TableInfo<$BibleVersionsTable, BibleVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BibleVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBundledMeta = const VerificationMeta('isBundled');
  @override
  late final GeneratedColumn<bool> isBundled = GeneratedColumn<bool>(
    'is_bundled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_bundled" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDownloadedMeta = const VerificationMeta('isDownloaded');
  @override
  late final GeneratedColumn<bool> isDownloaded = GeneratedColumn<bool>(
    'is_downloaded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_downloaded" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta('downloadedAt');
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [code, name, isBundled, isDownloaded, downloadedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bible_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<BibleVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(_codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_bundled')) {
      context.handle(
        _isBundledMeta,
        isBundled.isAcceptableOrUnknown(data['is_bundled']!, _isBundledMeta),
      );
    }
    if (data.containsKey('is_downloaded')) {
      context.handle(
        _isDownloadedMeta,
        isDownloaded.isAcceptableOrUnknown(data['is_downloaded']!, _isDownloadedMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(data['downloaded_at']!, _downloadedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  BibleVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BibleVersion(
      code: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      isBundled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bundled'],
      )!,
      isDownloaded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_downloaded'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      ),
    );
  }

  @override
  $BibleVersionsTable createAlias(String alias) {
    return $BibleVersionsTable(attachedDatabase, alias);
  }
}

class BibleVersion extends DataClass implements Insertable<BibleVersion> {
  final String code;
  final String name;
  final bool isBundled;
  final bool isDownloaded;
  final DateTime? downloadedAt;
  const BibleVersion({
    required this.code,
    required this.name,
    required this.isBundled,
    required this.isDownloaded,
    this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['is_bundled'] = Variable<bool>(isBundled);
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    return map;
  }

  BibleVersionsCompanion toCompanion(bool nullToAbsent) {
    return BibleVersionsCompanion(
      code: Value(code),
      name: Value(name),
      isBundled: Value(isBundled),
      isDownloaded: Value(isDownloaded),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
    );
  }

  factory BibleVersion.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BibleVersion(
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      isBundled: serializer.fromJson<bool>(json['isBundled']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'isBundled': serializer.toJson<bool>(isBundled),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
    };
  }

  BibleVersion copyWith({
    String? code,
    String? name,
    bool? isBundled,
    bool? isDownloaded,
    Value<DateTime?> downloadedAt = const Value.absent(),
  }) => BibleVersion(
    code: code ?? this.code,
    name: name ?? this.name,
    isBundled: isBundled ?? this.isBundled,
    isDownloaded: isDownloaded ?? this.isDownloaded,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
  );
  BibleVersion copyWithCompanion(BibleVersionsCompanion data) {
    return BibleVersion(
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      isBundled: data.isBundled.present ? data.isBundled.value : this.isBundled,
      isDownloaded: data.isDownloaded.present ? data.isDownloaded.value : this.isDownloaded,
      downloadedAt: data.downloadedAt.present ? data.downloadedAt.value : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BibleVersion(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('isBundled: $isBundled, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, name, isBundled, isDownloaded, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BibleVersion &&
          other.code == this.code &&
          other.name == this.name &&
          other.isBundled == this.isBundled &&
          other.isDownloaded == this.isDownloaded &&
          other.downloadedAt == this.downloadedAt);
}

class BibleVersionsCompanion extends UpdateCompanion<BibleVersion> {
  final Value<String> code;
  final Value<String> name;
  final Value<bool> isBundled;
  final Value<bool> isDownloaded;
  final Value<DateTime?> downloadedAt;
  final Value<int> rowid;
  const BibleVersionsCompanion({
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.isBundled = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BibleVersionsCompanion.insert({
    required String code,
    required String name,
    this.isBundled = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : code = Value(code),
       name = Value(name);
  static Insertable<BibleVersion> custom({
    Expression<String>? code,
    Expression<String>? name,
    Expression<bool>? isBundled,
    Expression<bool>? isDownloaded,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (isBundled != null) 'is_bundled': isBundled,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BibleVersionsCompanion copyWith({
    Value<String>? code,
    Value<String>? name,
    Value<bool>? isBundled,
    Value<bool>? isDownloaded,
    Value<DateTime?>? downloadedAt,
    Value<int>? rowid,
  }) {
    return BibleVersionsCompanion(
      code: code ?? this.code,
      name: name ?? this.name,
      isBundled: isBundled ?? this.isBundled,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isBundled.present) {
      map['is_bundled'] = Variable<bool>(isBundled.value);
    }
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BibleVersionsCompanion(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('isBundled: $isBundled, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BibleBooksTable extends BibleBooks with TableInfo<$BibleBooksTable, BibleBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BibleBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _versionCodeMeta = const VerificationMeta('versionCode');
  @override
  late final GeneratedColumn<String> versionCode = GeneratedColumn<String>(
    'version_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIndexMeta = const VerificationMeta('bookIndex');
  @override
  late final GeneratedColumn<int> bookIndex = GeneratedColumn<int>(
    'book_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _abbrevMeta = const VerificationMeta('abbrev');
  @override
  late final GeneratedColumn<String> abbrev = GeneratedColumn<String>(
    'abbrev',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterCountMeta = const VerificationMeta('chapterCount');
  @override
  late final GeneratedColumn<int> chapterCount = GeneratedColumn<int>(
    'chapter_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, versionCode, bookIndex, abbrev, name, chapterCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bible_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BibleBook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('version_code')) {
      context.handle(
        _versionCodeMeta,
        versionCode.isAcceptableOrUnknown(data['version_code']!, _versionCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_versionCodeMeta);
    }
    if (data.containsKey('book_index')) {
      context.handle(
        _bookIndexMeta,
        bookIndex.isAcceptableOrUnknown(data['book_index']!, _bookIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIndexMeta);
    }
    if (data.containsKey('abbrev')) {
      context.handle(_abbrevMeta, abbrev.isAcceptableOrUnknown(data['abbrev']!, _abbrevMeta));
    } else if (isInserting) {
      context.missing(_abbrevMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('chapter_count')) {
      context.handle(
        _chapterCountMeta,
        chapterCount.isAcceptableOrUnknown(data['chapter_count']!, _chapterCountMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BibleBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BibleBook(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      versionCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_code'],
      )!,
      bookIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_index'],
      )!,
      abbrev: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abbrev'],
      )!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      chapterCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_count'],
      )!,
    );
  }

  @override
  $BibleBooksTable createAlias(String alias) {
    return $BibleBooksTable(attachedDatabase, alias);
  }
}

class BibleBook extends DataClass implements Insertable<BibleBook> {
  final int id;
  final String versionCode;
  final int bookIndex;
  final String abbrev;
  final String name;
  final int chapterCount;
  const BibleBook({
    required this.id,
    required this.versionCode,
    required this.bookIndex,
    required this.abbrev,
    required this.name,
    required this.chapterCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['version_code'] = Variable<String>(versionCode);
    map['book_index'] = Variable<int>(bookIndex);
    map['abbrev'] = Variable<String>(abbrev);
    map['name'] = Variable<String>(name);
    map['chapter_count'] = Variable<int>(chapterCount);
    return map;
  }

  BibleBooksCompanion toCompanion(bool nullToAbsent) {
    return BibleBooksCompanion(
      id: Value(id),
      versionCode: Value(versionCode),
      bookIndex: Value(bookIndex),
      abbrev: Value(abbrev),
      name: Value(name),
      chapterCount: Value(chapterCount),
    );
  }

  factory BibleBook.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BibleBook(
      id: serializer.fromJson<int>(json['id']),
      versionCode: serializer.fromJson<String>(json['versionCode']),
      bookIndex: serializer.fromJson<int>(json['bookIndex']),
      abbrev: serializer.fromJson<String>(json['abbrev']),
      name: serializer.fromJson<String>(json['name']),
      chapterCount: serializer.fromJson<int>(json['chapterCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'versionCode': serializer.toJson<String>(versionCode),
      'bookIndex': serializer.toJson<int>(bookIndex),
      'abbrev': serializer.toJson<String>(abbrev),
      'name': serializer.toJson<String>(name),
      'chapterCount': serializer.toJson<int>(chapterCount),
    };
  }

  BibleBook copyWith({
    int? id,
    String? versionCode,
    int? bookIndex,
    String? abbrev,
    String? name,
    int? chapterCount,
  }) => BibleBook(
    id: id ?? this.id,
    versionCode: versionCode ?? this.versionCode,
    bookIndex: bookIndex ?? this.bookIndex,
    abbrev: abbrev ?? this.abbrev,
    name: name ?? this.name,
    chapterCount: chapterCount ?? this.chapterCount,
  );
  BibleBook copyWithCompanion(BibleBooksCompanion data) {
    return BibleBook(
      id: data.id.present ? data.id.value : this.id,
      versionCode: data.versionCode.present ? data.versionCode.value : this.versionCode,
      bookIndex: data.bookIndex.present ? data.bookIndex.value : this.bookIndex,
      abbrev: data.abbrev.present ? data.abbrev.value : this.abbrev,
      name: data.name.present ? data.name.value : this.name,
      chapterCount: data.chapterCount.present ? data.chapterCount.value : this.chapterCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BibleBook(')
          ..write('id: $id, ')
          ..write('versionCode: $versionCode, ')
          ..write('bookIndex: $bookIndex, ')
          ..write('abbrev: $abbrev, ')
          ..write('name: $name, ')
          ..write('chapterCount: $chapterCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, versionCode, bookIndex, abbrev, name, chapterCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BibleBook &&
          other.id == this.id &&
          other.versionCode == this.versionCode &&
          other.bookIndex == this.bookIndex &&
          other.abbrev == this.abbrev &&
          other.name == this.name &&
          other.chapterCount == this.chapterCount);
}

class BibleBooksCompanion extends UpdateCompanion<BibleBook> {
  final Value<int> id;
  final Value<String> versionCode;
  final Value<int> bookIndex;
  final Value<String> abbrev;
  final Value<String> name;
  final Value<int> chapterCount;
  const BibleBooksCompanion({
    this.id = const Value.absent(),
    this.versionCode = const Value.absent(),
    this.bookIndex = const Value.absent(),
    this.abbrev = const Value.absent(),
    this.name = const Value.absent(),
    this.chapterCount = const Value.absent(),
  });
  BibleBooksCompanion.insert({
    this.id = const Value.absent(),
    required String versionCode,
    required int bookIndex,
    required String abbrev,
    required String name,
    required int chapterCount,
  }) : versionCode = Value(versionCode),
       bookIndex = Value(bookIndex),
       abbrev = Value(abbrev),
       name = Value(name),
       chapterCount = Value(chapterCount);
  static Insertable<BibleBook> custom({
    Expression<int>? id,
    Expression<String>? versionCode,
    Expression<int>? bookIndex,
    Expression<String>? abbrev,
    Expression<String>? name,
    Expression<int>? chapterCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versionCode != null) 'version_code': versionCode,
      if (bookIndex != null) 'book_index': bookIndex,
      if (abbrev != null) 'abbrev': abbrev,
      if (name != null) 'name': name,
      if (chapterCount != null) 'chapter_count': chapterCount,
    });
  }

  BibleBooksCompanion copyWith({
    Value<int>? id,
    Value<String>? versionCode,
    Value<int>? bookIndex,
    Value<String>? abbrev,
    Value<String>? name,
    Value<int>? chapterCount,
  }) {
    return BibleBooksCompanion(
      id: id ?? this.id,
      versionCode: versionCode ?? this.versionCode,
      bookIndex: bookIndex ?? this.bookIndex,
      abbrev: abbrev ?? this.abbrev,
      name: name ?? this.name,
      chapterCount: chapterCount ?? this.chapterCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (versionCode.present) {
      map['version_code'] = Variable<String>(versionCode.value);
    }
    if (bookIndex.present) {
      map['book_index'] = Variable<int>(bookIndex.value);
    }
    if (abbrev.present) {
      map['abbrev'] = Variable<String>(abbrev.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (chapterCount.present) {
      map['chapter_count'] = Variable<int>(chapterCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BibleBooksCompanion(')
          ..write('id: $id, ')
          ..write('versionCode: $versionCode, ')
          ..write('bookIndex: $bookIndex, ')
          ..write('abbrev: $abbrev, ')
          ..write('name: $name, ')
          ..write('chapterCount: $chapterCount')
          ..write(')'))
        .toString();
  }
}

class $BibleChaptersTable extends BibleChapters with TableInfo<$BibleChaptersTable, BibleChapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BibleChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _versionCodeMeta = const VerificationMeta('versionCode');
  @override
  late final GeneratedColumn<String> versionCode = GeneratedColumn<String>(
    'version_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIndexMeta = const VerificationMeta('bookIndex');
  @override
  late final GeneratedColumn<int> bookIndex = GeneratedColumn<int>(
    'book_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterMeta = const VerificationMeta('chapter');
  @override
  late final GeneratedColumn<int> chapter = GeneratedColumn<int>(
    'chapter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versesJsonMeta = const VerificationMeta('versesJson');
  @override
  late final GeneratedColumn<String> versesJson = GeneratedColumn<String>(
    'verses_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, versionCode, bookIndex, chapter, versesJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bible_chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<BibleChapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('version_code')) {
      context.handle(
        _versionCodeMeta,
        versionCode.isAcceptableOrUnknown(data['version_code']!, _versionCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_versionCodeMeta);
    }
    if (data.containsKey('book_index')) {
      context.handle(
        _bookIndexMeta,
        bookIndex.isAcceptableOrUnknown(data['book_index']!, _bookIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIndexMeta);
    }
    if (data.containsKey('chapter')) {
      context.handle(_chapterMeta, chapter.isAcceptableOrUnknown(data['chapter']!, _chapterMeta));
    } else if (isInserting) {
      context.missing(_chapterMeta);
    }
    if (data.containsKey('verses_json')) {
      context.handle(
        _versesJsonMeta,
        versesJson.isAcceptableOrUnknown(data['verses_json']!, _versesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_versesJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BibleChapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BibleChapter(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      versionCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_code'],
      )!,
      bookIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_index'],
      )!,
      chapter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter'],
      )!,
      versesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verses_json'],
      )!,
    );
  }

  @override
  $BibleChaptersTable createAlias(String alias) {
    return $BibleChaptersTable(attachedDatabase, alias);
  }
}

class BibleChapter extends DataClass implements Insertable<BibleChapter> {
  final int id;
  final String versionCode;
  final int bookIndex;
  final int chapter;
  final String versesJson;
  const BibleChapter({
    required this.id,
    required this.versionCode,
    required this.bookIndex,
    required this.chapter,
    required this.versesJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['version_code'] = Variable<String>(versionCode);
    map['book_index'] = Variable<int>(bookIndex);
    map['chapter'] = Variable<int>(chapter);
    map['verses_json'] = Variable<String>(versesJson);
    return map;
  }

  BibleChaptersCompanion toCompanion(bool nullToAbsent) {
    return BibleChaptersCompanion(
      id: Value(id),
      versionCode: Value(versionCode),
      bookIndex: Value(bookIndex),
      chapter: Value(chapter),
      versesJson: Value(versesJson),
    );
  }

  factory BibleChapter.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BibleChapter(
      id: serializer.fromJson<int>(json['id']),
      versionCode: serializer.fromJson<String>(json['versionCode']),
      bookIndex: serializer.fromJson<int>(json['bookIndex']),
      chapter: serializer.fromJson<int>(json['chapter']),
      versesJson: serializer.fromJson<String>(json['versesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'versionCode': serializer.toJson<String>(versionCode),
      'bookIndex': serializer.toJson<int>(bookIndex),
      'chapter': serializer.toJson<int>(chapter),
      'versesJson': serializer.toJson<String>(versesJson),
    };
  }

  BibleChapter copyWith({
    int? id,
    String? versionCode,
    int? bookIndex,
    int? chapter,
    String? versesJson,
  }) => BibleChapter(
    id: id ?? this.id,
    versionCode: versionCode ?? this.versionCode,
    bookIndex: bookIndex ?? this.bookIndex,
    chapter: chapter ?? this.chapter,
    versesJson: versesJson ?? this.versesJson,
  );
  BibleChapter copyWithCompanion(BibleChaptersCompanion data) {
    return BibleChapter(
      id: data.id.present ? data.id.value : this.id,
      versionCode: data.versionCode.present ? data.versionCode.value : this.versionCode,
      bookIndex: data.bookIndex.present ? data.bookIndex.value : this.bookIndex,
      chapter: data.chapter.present ? data.chapter.value : this.chapter,
      versesJson: data.versesJson.present ? data.versesJson.value : this.versesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BibleChapter(')
          ..write('id: $id, ')
          ..write('versionCode: $versionCode, ')
          ..write('bookIndex: $bookIndex, ')
          ..write('chapter: $chapter, ')
          ..write('versesJson: $versesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, versionCode, bookIndex, chapter, versesJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BibleChapter &&
          other.id == this.id &&
          other.versionCode == this.versionCode &&
          other.bookIndex == this.bookIndex &&
          other.chapter == this.chapter &&
          other.versesJson == this.versesJson);
}

class BibleChaptersCompanion extends UpdateCompanion<BibleChapter> {
  final Value<int> id;
  final Value<String> versionCode;
  final Value<int> bookIndex;
  final Value<int> chapter;
  final Value<String> versesJson;
  const BibleChaptersCompanion({
    this.id = const Value.absent(),
    this.versionCode = const Value.absent(),
    this.bookIndex = const Value.absent(),
    this.chapter = const Value.absent(),
    this.versesJson = const Value.absent(),
  });
  BibleChaptersCompanion.insert({
    this.id = const Value.absent(),
    required String versionCode,
    required int bookIndex,
    required int chapter,
    required String versesJson,
  }) : versionCode = Value(versionCode),
       bookIndex = Value(bookIndex),
       chapter = Value(chapter),
       versesJson = Value(versesJson);
  static Insertable<BibleChapter> custom({
    Expression<int>? id,
    Expression<String>? versionCode,
    Expression<int>? bookIndex,
    Expression<int>? chapter,
    Expression<String>? versesJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versionCode != null) 'version_code': versionCode,
      if (bookIndex != null) 'book_index': bookIndex,
      if (chapter != null) 'chapter': chapter,
      if (versesJson != null) 'verses_json': versesJson,
    });
  }

  BibleChaptersCompanion copyWith({
    Value<int>? id,
    Value<String>? versionCode,
    Value<int>? bookIndex,
    Value<int>? chapter,
    Value<String>? versesJson,
  }) {
    return BibleChaptersCompanion(
      id: id ?? this.id,
      versionCode: versionCode ?? this.versionCode,
      bookIndex: bookIndex ?? this.bookIndex,
      chapter: chapter ?? this.chapter,
      versesJson: versesJson ?? this.versesJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (versionCode.present) {
      map['version_code'] = Variable<String>(versionCode.value);
    }
    if (bookIndex.present) {
      map['book_index'] = Variable<int>(bookIndex.value);
    }
    if (chapter.present) {
      map['chapter'] = Variable<int>(chapter.value);
    }
    if (versesJson.present) {
      map['verses_json'] = Variable<String>(versesJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BibleChaptersCompanion(')
          ..write('id: $id, ')
          ..write('versionCode: $versionCode, ')
          ..write('bookIndex: $bookIndex, ')
          ..write('chapter: $chapter, ')
          ..write('versesJson: $versesJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BibleVersionsTable bibleVersions = $BibleVersionsTable(this);
  late final $BibleBooksTable bibleBooks = $BibleBooksTable(this);
  late final $BibleChaptersTable bibleChapters = $BibleChaptersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [bibleVersions, bibleBooks, bibleChapters];
}

typedef $$BibleVersionsTableCreateCompanionBuilder =
    BibleVersionsCompanion Function({
      required String code,
      required String name,
      Value<bool> isBundled,
      Value<bool> isDownloaded,
      Value<DateTime?> downloadedAt,
      Value<int> rowid,
    });
typedef $$BibleVersionsTableUpdateCompanionBuilder =
    BibleVersionsCompanion Function({
      Value<String> code,
      Value<String> name,
      Value<bool> isBundled,
      Value<bool> isDownloaded,
      Value<DateTime?> downloadedAt,
      Value<int> rowid,
    });

class $$BibleVersionsTableFilterComposer extends Composer<_$AppDatabase, $BibleVersionsTable> {
  $$BibleVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isBundled =>
      $composableBuilder(column: $table.isBundled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded =>
      $composableBuilder(column: $table.isDownloaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get downloadedAt =>
      $composableBuilder(column: $table.downloadedAt, builder: (column) => ColumnFilters(column));
}

class $$BibleVersionsTableOrderingComposer extends Composer<_$AppDatabase, $BibleVersionsTable> {
  $$BibleVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isBundled =>
      $composableBuilder(column: $table.isBundled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded =>
      $composableBuilder(column: $table.isDownloaded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get downloadedAt =>
      $composableBuilder(column: $table.downloadedAt, builder: (column) => ColumnOrderings(column));
}

class $$BibleVersionsTableAnnotationComposer extends Composer<_$AppDatabase, $BibleVersionsTable> {
  $$BibleVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isBundled =>
      $composableBuilder(column: $table.isBundled, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded =>
      $composableBuilder(column: $table.isDownloaded, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt =>
      $composableBuilder(column: $table.downloadedAt, builder: (column) => column);
}

class $$BibleVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BibleVersionsTable,
          BibleVersion,
          $$BibleVersionsTableFilterComposer,
          $$BibleVersionsTableOrderingComposer,
          $$BibleVersionsTableAnnotationComposer,
          $$BibleVersionsTableCreateCompanionBuilder,
          $$BibleVersionsTableUpdateCompanionBuilder,
          (BibleVersion, BaseReferences<_$AppDatabase, $BibleVersionsTable, BibleVersion>),
          BibleVersion,
          PrefetchHooks Function()
        > {
  $$BibleVersionsTableTableManager(_$AppDatabase db, $BibleVersionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$BibleVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BibleVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BibleVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isBundled = const Value.absent(),
                Value<bool> isDownloaded = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BibleVersionsCompanion(
                code: code,
                name: name,
                isBundled: isBundled,
                isDownloaded: isDownloaded,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String code,
                required String name,
                Value<bool> isBundled = const Value.absent(),
                Value<bool> isDownloaded = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BibleVersionsCompanion.insert(
                code: code,
                name: name,
                isBundled: isBundled,
                isDownloaded: isDownloaded,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BibleVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BibleVersionsTable,
      BibleVersion,
      $$BibleVersionsTableFilterComposer,
      $$BibleVersionsTableOrderingComposer,
      $$BibleVersionsTableAnnotationComposer,
      $$BibleVersionsTableCreateCompanionBuilder,
      $$BibleVersionsTableUpdateCompanionBuilder,
      (BibleVersion, BaseReferences<_$AppDatabase, $BibleVersionsTable, BibleVersion>),
      BibleVersion,
      PrefetchHooks Function()
    >;
typedef $$BibleBooksTableCreateCompanionBuilder =
    BibleBooksCompanion Function({
      Value<int> id,
      required String versionCode,
      required int bookIndex,
      required String abbrev,
      required String name,
      required int chapterCount,
    });
typedef $$BibleBooksTableUpdateCompanionBuilder =
    BibleBooksCompanion Function({
      Value<int> id,
      Value<String> versionCode,
      Value<int> bookIndex,
      Value<String> abbrev,
      Value<String> name,
      Value<int> chapterCount,
    });

class $$BibleBooksTableFilterComposer extends Composer<_$AppDatabase, $BibleBooksTable> {
  $$BibleBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get versionCode =>
      $composableBuilder(column: $table.versionCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bookIndex =>
      $composableBuilder(column: $table.bookIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get abbrev =>
      $composableBuilder(column: $table.abbrev, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterCount =>
      $composableBuilder(column: $table.chapterCount, builder: (column) => ColumnFilters(column));
}

class $$BibleBooksTableOrderingComposer extends Composer<_$AppDatabase, $BibleBooksTable> {
  $$BibleBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get versionCode =>
      $composableBuilder(column: $table.versionCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bookIndex =>
      $composableBuilder(column: $table.bookIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get abbrev =>
      $composableBuilder(column: $table.abbrev, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterCount =>
      $composableBuilder(column: $table.chapterCount, builder: (column) => ColumnOrderings(column));
}

class $$BibleBooksTableAnnotationComposer extends Composer<_$AppDatabase, $BibleBooksTable> {
  $$BibleBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get versionCode =>
      $composableBuilder(column: $table.versionCode, builder: (column) => column);

  GeneratedColumn<int> get bookIndex =>
      $composableBuilder(column: $table.bookIndex, builder: (column) => column);

  GeneratedColumn<String> get abbrev =>
      $composableBuilder(column: $table.abbrev, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get chapterCount =>
      $composableBuilder(column: $table.chapterCount, builder: (column) => column);
}

class $$BibleBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BibleBooksTable,
          BibleBook,
          $$BibleBooksTableFilterComposer,
          $$BibleBooksTableOrderingComposer,
          $$BibleBooksTableAnnotationComposer,
          $$BibleBooksTableCreateCompanionBuilder,
          $$BibleBooksTableUpdateCompanionBuilder,
          (BibleBook, BaseReferences<_$AppDatabase, $BibleBooksTable, BibleBook>),
          BibleBook,
          PrefetchHooks Function()
        > {
  $$BibleBooksTableTableManager(_$AppDatabase db, $BibleBooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$BibleBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$BibleBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BibleBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> versionCode = const Value.absent(),
                Value<int> bookIndex = const Value.absent(),
                Value<String> abbrev = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
              }) => BibleBooksCompanion(
                id: id,
                versionCode: versionCode,
                bookIndex: bookIndex,
                abbrev: abbrev,
                name: name,
                chapterCount: chapterCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String versionCode,
                required int bookIndex,
                required String abbrev,
                required String name,
                required int chapterCount,
              }) => BibleBooksCompanion.insert(
                id: id,
                versionCode: versionCode,
                bookIndex: bookIndex,
                abbrev: abbrev,
                name: name,
                chapterCount: chapterCount,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BibleBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BibleBooksTable,
      BibleBook,
      $$BibleBooksTableFilterComposer,
      $$BibleBooksTableOrderingComposer,
      $$BibleBooksTableAnnotationComposer,
      $$BibleBooksTableCreateCompanionBuilder,
      $$BibleBooksTableUpdateCompanionBuilder,
      (BibleBook, BaseReferences<_$AppDatabase, $BibleBooksTable, BibleBook>),
      BibleBook,
      PrefetchHooks Function()
    >;
typedef $$BibleChaptersTableCreateCompanionBuilder =
    BibleChaptersCompanion Function({
      Value<int> id,
      required String versionCode,
      required int bookIndex,
      required int chapter,
      required String versesJson,
    });
typedef $$BibleChaptersTableUpdateCompanionBuilder =
    BibleChaptersCompanion Function({
      Value<int> id,
      Value<String> versionCode,
      Value<int> bookIndex,
      Value<int> chapter,
      Value<String> versesJson,
    });

class $$BibleChaptersTableFilterComposer extends Composer<_$AppDatabase, $BibleChaptersTable> {
  $$BibleChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get versionCode =>
      $composableBuilder(column: $table.versionCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bookIndex =>
      $composableBuilder(column: $table.bookIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapter =>
      $composableBuilder(column: $table.chapter, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get versesJson =>
      $composableBuilder(column: $table.versesJson, builder: (column) => ColumnFilters(column));
}

class $$BibleChaptersTableOrderingComposer extends Composer<_$AppDatabase, $BibleChaptersTable> {
  $$BibleChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get versionCode =>
      $composableBuilder(column: $table.versionCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bookIndex =>
      $composableBuilder(column: $table.bookIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapter =>
      $composableBuilder(column: $table.chapter, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get versesJson =>
      $composableBuilder(column: $table.versesJson, builder: (column) => ColumnOrderings(column));
}

class $$BibleChaptersTableAnnotationComposer extends Composer<_$AppDatabase, $BibleChaptersTable> {
  $$BibleChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get versionCode =>
      $composableBuilder(column: $table.versionCode, builder: (column) => column);

  GeneratedColumn<int> get bookIndex =>
      $composableBuilder(column: $table.bookIndex, builder: (column) => column);

  GeneratedColumn<int> get chapter =>
      $composableBuilder(column: $table.chapter, builder: (column) => column);

  GeneratedColumn<String> get versesJson =>
      $composableBuilder(column: $table.versesJson, builder: (column) => column);
}

class $$BibleChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BibleChaptersTable,
          BibleChapter,
          $$BibleChaptersTableFilterComposer,
          $$BibleChaptersTableOrderingComposer,
          $$BibleChaptersTableAnnotationComposer,
          $$BibleChaptersTableCreateCompanionBuilder,
          $$BibleChaptersTableUpdateCompanionBuilder,
          (BibleChapter, BaseReferences<_$AppDatabase, $BibleChaptersTable, BibleChapter>),
          BibleChapter,
          PrefetchHooks Function()
        > {
  $$BibleChaptersTableTableManager(_$AppDatabase db, $BibleChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$BibleChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BibleChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BibleChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> versionCode = const Value.absent(),
                Value<int> bookIndex = const Value.absent(),
                Value<int> chapter = const Value.absent(),
                Value<String> versesJson = const Value.absent(),
              }) => BibleChaptersCompanion(
                id: id,
                versionCode: versionCode,
                bookIndex: bookIndex,
                chapter: chapter,
                versesJson: versesJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String versionCode,
                required int bookIndex,
                required int chapter,
                required String versesJson,
              }) => BibleChaptersCompanion.insert(
                id: id,
                versionCode: versionCode,
                bookIndex: bookIndex,
                chapter: chapter,
                versesJson: versesJson,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BibleChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BibleChaptersTable,
      BibleChapter,
      $$BibleChaptersTableFilterComposer,
      $$BibleChaptersTableOrderingComposer,
      $$BibleChaptersTableAnnotationComposer,
      $$BibleChaptersTableCreateCompanionBuilder,
      $$BibleChaptersTableUpdateCompanionBuilder,
      (BibleChapter, BaseReferences<_$AppDatabase, $BibleChaptersTable, BibleChapter>),
      BibleChapter,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BibleVersionsTableTableManager get bibleVersions =>
      $$BibleVersionsTableTableManager(_db, _db.bibleVersions);
  $$BibleBooksTableTableManager get bibleBooks =>
      $$BibleBooksTableTableManager(_db, _db.bibleBooks);
  $$BibleChaptersTableTableManager get bibleChapters =>
      $$BibleChaptersTableTableManager(_db, _db.bibleChapters);
}
