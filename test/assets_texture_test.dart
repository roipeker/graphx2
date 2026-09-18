import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphx/graphx.dart';

void main() {
  test('GAssets deduplicates in-flight loads', () async {
    final assets = GAssets();
    var loads = 0;

    Future<Uint8List> load() => assets.load<Uint8List>('data', () async {
      loads++;
      return Uint8List.fromList(<int>[1, 2, 3]);
    });

    final a = load();
    final b = load();
    expect(await a, same(await b));
    expect(loads, 1);
    expect(assets.get<Uint8List>('data'), isNotNull);

    assets.dispose();
  });

  test('GAssets delegates URL bytes to the configured loader', () async {
    final expectedUri = Uri.parse('https://example.test/model.glb');
    var loads = 0;
    final assets = GAssets(
      urlLoader: (uri) async {
        expect(uri, expectedUri);
        loads++;
        return Uint8List.fromList(<int>[4, 5, 6]);
      },
    );

    expect(
      await assets.bytesUrl(expectedUri.toString()),
      orderedEquals(<int>[4, 5, 6]),
    );
    expect(
      await assets.bytesUrl(expectedUri.toString()),
      orderedEquals(<int>[4, 5, 6]),
    );
    expect(loads, 1);

    assets.dispose();
  });

  test('GRuntime forwards its URL loader to shared assets', () async {
    final runtime = GRuntime(
      urlLoader: (_) async => Uint8List.fromList(<int>[7, 8, 9]),
    );

    expect(
      await runtime.assets.bytesUrl('https://example.test/data.bin'),
      orderedEquals(<int>[7, 8, 9]),
    );

    runtime.dispose();
  });
}
