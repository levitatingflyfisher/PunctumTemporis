import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/media_picker_screen.dart';

void main() {
  group('getMediaPickerItemCount', () {
    test('with target and other assets', () {
      final count = getMediaPickerItemCount(
        targetAssetCount: 2,
        otherAssetCount: 3,
        hasMore: false,
      );
      // 2 target + 1 separator + 3 other = 6
      expect(count, 6);
    });

    test('with no target assets', () {
      final count = getMediaPickerItemCount(
        targetAssetCount: 0,
        otherAssetCount: 5,
        hasMore: false,
      );
      // 1 separator + 5 other = 6
      expect(count, 6);
    });

    test('with hasMore adds loading indicator', () {
      final count = getMediaPickerItemCount(
        targetAssetCount: 2,
        otherAssetCount: 3,
        hasMore: true,
      );
      // 2 target + 1 separator + 3 other + 1 loading = 7
      expect(count, 7);
    });

    test('empty lists', () {
      final count = getMediaPickerItemCount(
        targetAssetCount: 0,
        otherAssetCount: 0,
        hasMore: false,
      );
      // 1 separator only
      expect(count, 1);
    });
  });

  group('getMediaPickerItemAt', () {
    test('with 2 target assets + 3 other assets', () {
      MediaPickerItem item(int index) => getMediaPickerItemAt(
            index: index,
            targetAssetCount: 2,
            otherAssetCount: 3,
            noMediaLabel: 'NO MEDIA FROM JAN 15',
            hasMore: false,
          );

      // Index 0, 1: target assets
      final i0 = item(0);
      expect(i0.matchesTarget, isTrue);
      expect(i0.isTargetAsset, isTrue);
      expect(i0.assetIndex, 0);
      expect(i0.separatorLabel, isNull);

      final i1 = item(1);
      expect(i1.matchesTarget, isTrue);
      expect(i1.assetIndex, 1);

      // Index 2: separator "OTHER MEDIA"
      final i2 = item(2);
      expect(i2.separatorLabel, 'OTHER MEDIA');
      expect(i2.assetIndex, isNull);

      // Index 3, 4, 5: other assets
      final i3 = item(3);
      expect(i3.matchesTarget, isFalse);
      expect(i3.assetIndex, 0);

      final i4 = item(4);
      expect(i4.assetIndex, 1);

      final i5 = item(5);
      expect(i5.assetIndex, 2);
    });

    test('with 0 target assets shows no-media separator at index 0', () {
      final item = getMediaPickerItemAt(
        index: 0,
        targetAssetCount: 0,
        otherAssetCount: 5,
        noMediaLabel: 'NO MEDIA FROM FEB 10',
        hasMore: false,
      );

      expect(item.separatorLabel, 'NO MEDIA FROM FEB 10');
      expect(item.assetIndex, isNull);
    });

    test('with 0 target assets, other assets start at index 1', () {
      final item = getMediaPickerItemAt(
        index: 1,
        targetAssetCount: 0,
        otherAssetCount: 5,
        noMediaLabel: 'NO MEDIA FROM FEB 10',
        hasMore: false,
      );

      expect(item.matchesTarget, isFalse);
      expect(item.assetIndex, 0);
      expect(item.separatorLabel, isNull);
    });

    test('separator at correct boundary index', () {
      // With 4 target assets, separator should be at index 4
      final item = getMediaPickerItemAt(
        index: 4,
        targetAssetCount: 4,
        otherAssetCount: 2,
        noMediaLabel: 'NO MEDIA FROM JAN 1',
        hasMore: false,
      );

      expect(item.separatorLabel, 'OTHER MEDIA');
    });

    test('loading indicator is returned past all assets', () {
      // 2 target + 1 separator + 1 other = indices 0-3
      // Index 4 would be loading indicator
      final item = getMediaPickerItemAt(
        index: 4,
        targetAssetCount: 2,
        otherAssetCount: 1,
        noMediaLabel: 'NO MEDIA',
        hasMore: true,
      );

      // Loading indicator: no asset, no separator
      expect(item.assetIndex, isNull);
      expect(item.separatorLabel, isNull);
      expect(item.matchesTarget, isFalse);
    });
  });

  group('NEARBY section', () {
    // Structure: [target assets] [NEARBY header] [nearby assets] [OTHER MEDIA header] [other assets]
    test('NEARBY header appears at index targetCount when nearby non-empty', () {
      final item = getMediaPickerItemAt(
        index: 2,
        targetAssetCount: 2,
        nearbyAssetCount: 3,
        otherAssetCount: 4,
        noMediaLabel: 'NO MEDIA',
        hasMore: false,
      );
      expect(item.separatorLabel, 'NEARBY');
    });

    test('nearby assets start after NEARBY header', () {
      final item = getMediaPickerItemAt(
        index: 3,
        targetAssetCount: 2,
        nearbyAssetCount: 3,
        otherAssetCount: 4,
        noMediaLabel: 'NO MEDIA',
        hasMore: false,
      );
      expect(item.isNearbyAsset, isTrue);
      expect(item.assetIndex, 0);
    });

    test('OTHER MEDIA header appears after nearby assets', () {
      // 2 target + 1 NEARBY hdr + 3 nearby = index 6 is OTHER MEDIA
      final item = getMediaPickerItemAt(
        index: 6,
        targetAssetCount: 2,
        nearbyAssetCount: 3,
        otherAssetCount: 4,
        noMediaLabel: 'NO MEDIA',
        hasMore: false,
      );
      expect(item.separatorLabel, 'OTHER MEDIA');
    });

    test('other assets start after OTHER MEDIA header when nearby present', () {
      // 2 target + 1 NEARBY hdr + 3 nearby + 1 OTHER hdr = index 7 is other[0]
      final item = getMediaPickerItemAt(
        index: 7,
        targetAssetCount: 2,
        nearbyAssetCount: 3,
        otherAssetCount: 4,
        noMediaLabel: 'NO MEDIA',
        hasMore: false,
      );
      expect(item.matchesTarget, isFalse);
      expect(item.isNearbyAsset, isFalse);
      expect(item.assetIndex, 0);
    });

    test('getMediaPickerItemCount includes nearby header and assets', () {
      final count = getMediaPickerItemCount(
        targetAssetCount: 2,
        nearbyAssetCount: 3,
        otherAssetCount: 4,
        hasMore: false,
      );
      // 2 target + 1 NEARBY hdr + 3 nearby + 1 OTHER hdr + 4 other = 11
      expect(count, 11);
    });

    test('no NEARBY section when nearbyAssetCount is zero', () {
      // With 0 nearby, index 2 should be OTHER MEDIA (same as before)
      final item = getMediaPickerItemAt(
        index: 2,
        targetAssetCount: 2,
        nearbyAssetCount: 0,
        otherAssetCount: 4,
        noMediaLabel: 'NO MEDIA',
        hasMore: false,
      );
      expect(item.separatorLabel, 'OTHER MEDIA');
    });
  });
}
