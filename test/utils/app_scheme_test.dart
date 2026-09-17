import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PiliScheme.videoIdFromUri', () {
    test('parses an aid from a story path', () {
      expect(
        PiliScheme.videoIdFromUri(
          Uri.parse('bilibili://story/123456?cid=654321'),
        ),
        (aid: 123456, bvid: null),
      );
    });

    test('parses a bvid carried by a story URI', () {
      expect(
        PiliScheme.videoIdFromUri(
          Uri.parse('bilibili://story/BV1xx411c7mD'),
        ),
        (aid: null, bvid: 'BV1xx411c7mD'),
      );
      expect(
        PiliScheme.videoIdFromUri(
          Uri.parse('bilibili://story/?bvid=BV1xx411c7mD'),
        ),
        (aid: null, bvid: 'BV1xx411c7mD'),
      );
    });

    test('rejects a story URI without a video identifier', () {
      expect(
        PiliScheme.videoIdFromUri(Uri.parse('bilibili://story/')),
        isNull,
      );
    });
  });
}
