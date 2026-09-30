import 'dart:io';

// Flutter's icon fonts are tree-shaken per release. Give each release a new
// asset base so returning browsers cannot reuse an older cached font subset.
void main() {
  final web = Directory('build/web');
  final bootstrap = File('${web.path}/flutter_bootstrap.js');
  final source = bootstrap.readAsStringSync();
  const loader = '_flutter.loader.load({';
  if (!source.contains(loader) || source.contains('assetBase:')) {
    throw StateError('Expected a fresh Flutter web build.');
  }
  final version = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  final target = '${web.path}/releases/$version';
  for (final entity in Directory(
    '${web.path}/assets',
  ).listSync(recursive: true)) {
    if (entity is! File) continue;
    final relative = entity.path.substring(web.path.length + 1);
    final copy = File('$target/$relative');
    copy.parent.createSync(recursive: true);
    entity.copySync(copy.path);
  }
  File('${web.path}/main.dart.js').copySync('$target/main.dart.js');
  final versionedSource = source.replaceAll(
    '"mainJsPath":"main.dart.js"',
    '"mainJsPath":"releases/$version/main.dart.js"',
  );
  bootstrap.writeAsStringSync(
    versionedSource.replaceFirst(
      loader,
      "$loader\n  config: {assetBase: new URL('releases/$version/', document.baseURI).href},",
    ),
  );
  stdout.writeln('Versioned web assets: $version');
}
