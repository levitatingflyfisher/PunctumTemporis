import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import '../theme/app_theme.dart';
import '../utils/location_util.dart';
import '../widgets/crt_effects.dart';

enum _FilterType { all, photos, videos }

/// Result type for media picker display item indexing.
/// [assetIndex] is non-null for asset items (index into target, nearby, or other list).
/// [separatorLabel] is non-null for separator items.
/// [matchesTarget] is true when the item is from the target-date asset list.
/// [isNearbyAsset] is true when the item is from the nearby-dates asset list.
class MediaPickerItem {
  final int? assetIndex;
  final bool matchesTarget;
  final String? separatorLabel;
  final bool isTargetAsset;
  final bool isNearbyAsset;

  const MediaPickerItem({
    this.assetIndex,
    this.matchesTarget = false,
    this.separatorLabel,
    this.isTargetAsset = false,
    this.isNearbyAsset = false,
  });
}

/// Pure function for computing display-item at a given flat index.
/// Used by the widget and testable in isolation.
/// Structure: [target] [NEARBY hdr] [nearby] [OTHER MEDIA hdr] [other] [loading?]
MediaPickerItem getMediaPickerItemAt({
  required int index,
  required int targetAssetCount,
  int nearbyAssetCount = 0,
  required int otherAssetCount,
  required String noMediaLabel,
  required bool hasMore,
}) {
  int offset = 0;

  if (targetAssetCount > 0) {
    if (index < targetAssetCount) {
      return MediaPickerItem(
          assetIndex: index, matchesTarget: true, isTargetAsset: true);
    }
    offset += targetAssetCount;

    // NEARBY section (only when nearby assets exist)
    if (nearbyAssetCount > 0) {
      if (index == offset) {
        return const MediaPickerItem(separatorLabel: 'NEARBY');
      }
      offset += 1;

      if (index < offset + nearbyAssetCount) {
        return MediaPickerItem(
            assetIndex: index - offset, isNearbyAsset: true);
      }
      offset += nearbyAssetCount;
    }

    if (index == offset) {
      return const MediaPickerItem(separatorLabel: 'OTHER MEDIA');
    }
    offset += 1;
  } else {
    if (index == 0) {
      return MediaPickerItem(separatorLabel: noMediaLabel);
    }
    offset += 1;
  }

  final otherIndex = index - offset;
  if (otherIndex < otherAssetCount) {
    return MediaPickerItem(assetIndex: otherIndex, matchesTarget: false);
  }

  // Loading indicator
  return const MediaPickerItem();
}

/// Total number of display items for the media picker flat list.
int getMediaPickerItemCount({
  required int targetAssetCount,
  int nearbyAssetCount = 0,
  required int otherAssetCount,
  required bool hasMore,
}) {
  int count = 0;
  if (targetAssetCount > 0) {
    count += targetAssetCount;
    if (nearbyAssetCount > 0) {
      count += 1; // "NEARBY" separator
      count += nearbyAssetCount;
    }
    count += 1; // "OTHER MEDIA" separator
  } else {
    count += 1; // "NO MEDIA FROM..." separator
  }
  count += otherAssetCount;
  if (hasMore) count += 1;
  return count;
}

class MediaPickerScreen extends StatefulWidget {
  final String targetDate;
  final bool crtEnabled;

  const MediaPickerScreen({
    super.key,
    required this.targetDate,
    this.crtEnabled = true,
  });

  @override
  State<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends State<MediaPickerScreen> {
  _FilterType _filter = _FilterType.all;
  List<AssetEntity> _targetDateAssets = [];
  List<AssetEntity> _nearbyAssets = [];
  List<AssetEntity> _otherAssets = [];
  Set<String> _targetDateIds = {};
  Set<String> _nearbyAssetIds = {};
  int _dateShift = 0;
  bool _loading = true;
  bool _hasPermission = false;
  int _currentPage = 0;
  bool _hasMore = true;
  static const _pageSize = 80;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    if (result.isAuth || result == PermissionState.limited) {
      setState(() => _hasPermission = true);
      await _loadAssets();
    } else {
      setState(() {
        _hasPermission = false;
        _loading = false;
      });
    }
  }

  RequestType get _requestType {
    switch (_filter) {
      case _FilterType.all:
        return RequestType.common;
      case _FilterType.photos:
        return RequestType.image;
      case _FilterType.videos:
        return RequestType.video;
    }
  }

  Future<void> _loadTargetDateAssets() async {
    final targetDate = DateTime.parse(widget.targetDate);
    final dayStart =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final filterOption = FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: dayStart,
        max: dayEnd,
      ),
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );

    final paths = await PhotoManager.getAssetPathList(
      type: _requestType,
      filterOption: filterOption,
    );

    if (paths.isEmpty) {
      _targetDateAssets = [];
      _targetDateIds = {};
    } else {
      final allPath = paths.first;
      final count = await allPath.assetCountAsync;
      if (count == 0) {
        _targetDateAssets = [];
        _targetDateIds = {};
      } else {
        final assets = await allPath.getAssetListRange(start: 0, end: count);
        final filtered = assets
            .where((a) =>
                a.relativePath == null ||
                !a.relativePath!.contains('OneSecondADay'))
            .toList();
        _targetDateAssets = filtered;
        _targetDateIds = filtered.map((a) => a.id).toSet();
      }
    }

    // Nearby: day before and day after targetDate (adjusted by _dateShift)
    final nearbyStart = DateTime(
        targetDate.year, targetDate.month, targetDate.day - 1 + _dateShift);
    final nearbyEnd = DateTime(
        targetDate.year, targetDate.month, targetDate.day + 2 + _dateShift);

    final nearbyFilterOption = FilterOptionGroup(
      createTimeCond: DateTimeCond(min: nearbyStart, max: nearbyEnd),
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );

    final nearbyPaths = await PhotoManager.getAssetPathList(
      type: _requestType,
      filterOption: nearbyFilterOption,
    );

    if (nearbyPaths.isEmpty) {
      _nearbyAssets = [];
      _nearbyAssetIds = {};
      return;
    }

    final nearbyAllPath = nearbyPaths.first;
    final nearbyCount = await nearbyAllPath.assetCountAsync;
    if (nearbyCount == 0) {
      _nearbyAssets = [];
      _nearbyAssetIds = {};
      return;
    }

    final nearbyRaw =
        await nearbyAllPath.getAssetListRange(start: 0, end: nearbyCount);
    final nearbyFiltered = nearbyRaw
        .where((a) =>
            (a.relativePath == null ||
                !a.relativePath!.contains('OneSecondADay')) &&
            !_targetDateIds.contains(a.id))
        .toList();
    _nearbyAssets = nearbyFiltered;
    _nearbyAssetIds = nearbyFiltered.map((a) => a.id).toSet();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _loading = true;
      _currentPage = 0;
      _targetDateAssets = [];
      _nearbyAssets = [];
      _otherAssets = [];
      _targetDateIds = {};
      _nearbyAssetIds = {};
      _hasMore = true;
    });

    // First load target date assets
    await _loadTargetDateAssets();

    // Then load all assets (paginated), excluding target-date ones
    final paths = await PhotoManager.getAssetPathList(
      type: _requestType,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false)
        ],
      ),
    );

    if (paths.isEmpty) {
      setState(() {
        _loading = false;
        _hasMore = false;
      });
      return;
    }

    final allPath = paths.first;
    final assets = await allPath.getAssetListPaged(page: 0, size: _pageSize);

    final filtered = assets
        .where((a) =>
            (a.relativePath == null ||
                !a.relativePath!.contains('OneSecondADay')) &&
            !_targetDateIds.contains(a.id) &&
            !_nearbyAssetIds.contains(a.id))
        .toList();

    setState(() {
      _otherAssets = filtered;
      _currentPage = 1;
      _hasMore = assets.length >= _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;

    setState(() => _loading = true);

    final paths = await PhotoManager.getAssetPathList(
      type: _requestType,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false)
        ],
      ),
    );

    if (paths.isEmpty) {
      setState(() {
        _loading = false;
        _hasMore = false;
      });
      return;
    }

    final allPath = paths.first;
    final assets =
        await allPath.getAssetListPaged(page: _currentPage, size: _pageSize);

    final filtered = assets
        .where((a) =>
            (a.relativePath == null ||
                !a.relativePath!.contains('OneSecondADay')) &&
            !_targetDateIds.contains(a.id) &&
            !_nearbyAssetIds.contains(a.id))
        .toList();

    setState(() {
      _otherAssets.addAll(filtered);
      _currentPage++;
      _hasMore = assets.length >= _pageSize;
      _loading = false;
    });
  }

  void _setFilter(_FilterType filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _loadAssets();
  }

  String _nearbyWindowLabel(DateTime targetDate) {
    final from = DateTime(
        targetDate.year, targetDate.month, targetDate.day - 1 + _dateShift);
    final to = DateTime(
        targetDate.year, targetDate.month, targetDate.day + 1 + _dateShift);
    final fmt = DateFormat('MMM d');
    return '${fmt.format(from).toUpperCase()} — ${fmt.format(to).toUpperCase()}';
  }

  // Build a flat list of display items: target assets, separator, other assets
  // Returns (item, isAsset, isSeparator, separatorLabel, matchesTarget)
  int get _totalItemCount {
    int count = 0;
    if (_targetDateAssets.isNotEmpty) {
      count += _targetDateAssets.length; // target assets
      count += 1; // "OTHER MEDIA" separator
    } else {
      count += 1; // "NO MEDIA FROM [DATE]" separator
    }
    count += _otherAssets.length;
    if (_hasMore) count += 1; // loading indicator
    return count;
  }

  // Returns null for separator, AssetEntity for asset
  // Also returns (matchesTarget, separatorLabel)
  ({AssetEntity? asset, bool matchesTarget, String? separatorLabel}) _getItemAt(
      int index) {
    int offset = 0;

    if (_targetDateAssets.isNotEmpty) {
      // Target date assets
      if (index < _targetDateAssets.length) {
        return (
          asset: _targetDateAssets[index],
          matchesTarget: true,
          separatorLabel: null
        );
      }
      offset += _targetDateAssets.length;

      // Separator after target assets
      if (index == offset) {
        return (
          asset: null,
          matchesTarget: false,
          separatorLabel: 'OTHER MEDIA'
        );
      }
      offset += 1;
    } else {
      // No target-date matches separator
      if (index == 0) {
        final targetDate = DateTime.parse(widget.targetDate);
        final label =
            'NO MEDIA FROM ${DateFormat('MMM d').format(targetDate).toUpperCase()}';
        return (asset: null, matchesTarget: false, separatorLabel: label);
      }
      offset += 1;
    }

    // Other assets
    final otherIndex = index - offset;
    if (otherIndex < _otherAssets.length) {
      return (
        asset: _otherAssets[otherIndex],
        matchesTarget: false,
        separatorLabel: null
      );
    }

    // Loading indicator (shouldn't be reached as separator)
    return (asset: null, matchesTarget: false, separatorLabel: null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetDateTime = DateTime.parse(widget.targetDate);
    final targetLabel =
        DateFormat('MMM d, yyyy').format(targetDateTime).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SELECT MEDIA',
          style: AppTheme.pixelFont(fontSize: 12),
        ),
      ),
      body: CrtOverlay(
        enabled: widget.crtEnabled,
        child: Column(
          children: [
            // Target date banner + nearby shift controls
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom:
                      BorderSide(color: theme.colorScheme.primary, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'UPLOADING TO: $targetLabel',
                      style: AppTheme.monoFont(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left,
                            size: 18, color: theme.colorScheme.onSurface),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                        onPressed: () => setState(() {
                          _dateShift--;
                          _loadAssets();
                        }),
                      ),
                      Expanded(
                        child: Text(
                          _nearbyWindowLabel(targetDateTime),
                          style: AppTheme.monoFont(
                            fontSize: 10,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_dateShift != 0)
                        GestureDetector(
                          onTap: () => setState(() {
                            _dateShift = 0;
                            _loadAssets();
                          }),
                          child: Icon(Icons.close,
                              size: 14,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      IconButton(
                        icon: Icon(Icons.chevron_right,
                            size: 18, color: theme.colorScheme.onSurface),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                        onPressed: () => setState(() {
                          _dateShift++;
                          _loadAssets();
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filter tabs
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _FilterTab(
                    label: 'ALL',
                    selected: _filter == _FilterType.all,
                    onTap: () => _setFilter(_FilterType.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    label: 'PHOTOS',
                    selected: _filter == _FilterType.photos,
                    onTap: () => _setFilter(_FilterType.photos),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    label: 'VIDEOS',
                    selected: _filter == _FilterType.videos,
                    onTap: () => _setFilter(_FilterType.videos),
                  ),
                ],
              ),
            ),

            // Grid
            Expanded(
              child: !_hasPermission && !_loading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'MEDIA PERMISSION REQUIRED',
                          style: AppTheme.pixelFont(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : (_targetDateAssets.isEmpty &&
                          _otherAssets.isEmpty &&
                          !_loading)
                      ? Center(
                          child: Text(
                            'NO MEDIA FOUND',
                            style: AppTheme.pixelFont(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        )
                      : CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            // Target date assets grid
                            if (_targetDateAssets.isNotEmpty)
                              SliverPadding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _MediaTile(
                                      asset: _targetDateAssets[index],
                                      matchesTarget: true,
                                      onTap: () => Navigator.pop(
                                          context, _targetDateAssets[index]),
                                    ),
                                    childCount: _targetDateAssets.length,
                                  ),
                                ),
                              ),

                            // NEARBY section (only when nearby assets exist)
                            if (_nearbyAssets.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'NEARBY — ${_nearbyWindowLabel(targetDateTime)}',
                                    style: AppTheme.pixelFont(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _MediaTile(
                                      asset: _nearbyAssets[index],
                                      matchesTarget: false,
                                      onTap: () => Navigator.pop(
                                          context, _nearbyAssets[index]),
                                    ),
                                    childCount: _nearbyAssets.length,
                                  ),
                                ),
                              ),
                            ],

                            // OTHER MEDIA separator
                            SliverToBoxAdapter(
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: Text(
                                  _targetDateAssets.isNotEmpty
                                      ? 'OTHER MEDIA'
                                      : 'NO MEDIA FROM ${DateFormat('MMM d').format(DateTime.parse(widget.targetDate)).toUpperCase()}',
                                  style: AppTheme.pixelFont(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),

                            // Other assets grid
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _MediaTile(
                                    asset: _otherAssets[index],
                                    matchesTarget: false,
                                    onTap: () => Navigator.pop(
                                        context, _otherAssets[index]),
                                  ),
                                  childCount: _otherAssets.length,
                                ),
                              ),
                            ),

                            // Loading indicator
                            if (_hasMore)
                              const SliverToBoxAdapter(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(selected ? 1.0 : 0.5),
          ),
        ),
        child: Text(
          label,
          style: AppTheme.monoFont(
            fontSize: 12,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _MediaTile extends StatefulWidget {
  final AssetEntity asset;
  final bool matchesTarget;
  final VoidCallback onTap;

  const _MediaTile({
    required this.asset,
    required this.matchesTarget,
    required this.onTap,
  });

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  Uint8List? _thumbData;
  String? _locationLabel;
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
    _loadLocation();
  }

  Future<void> _loadThumbnail() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
    if (mounted && data != null) {
      setState(() => _thumbData = data);
    }
  }

  Future<void> _loadLocation() async {
    final latLng = await widget.asset.latlngAsync();
    if (latLng != null && latLng.latitude != 0 && latLng.longitude != 0) {
      final label = await LocationUtil.reverseGeocodeLabel(
          latLng.latitude, latLng.longitude);
      if (mounted) {
        setState(() {
          _locationLabel = label;
          _locationLoaded = true;
        });
      }
    } else {
      if (mounted) {
        setState(() => _locationLoaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('M/d').format(widget.asset.createDateTime);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.matchesTarget ? Colors.green : Colors.amber,
            width: widget.matchesTarget ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            if (_thumbData != null)
              Image.memory(
                _thumbData!,
                fit: BoxFit.cover,
              )
            else
              const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),

            // Date label bottom-left
            Positioned(
              left: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                color: Colors.black.withOpacity(0.7),
                child: Text(
                  dateLabel,
                  style: AppTheme.monoFont(fontSize: 11, color: Colors.white),
                ),
              ),
            ),

            // Location label bottom-right
            if (_locationLoaded)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  color: Colors.black.withOpacity(0.7),
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    _locationLabel?.split(',').first ?? '?',
                    style:
                        AppTheme.monoFont(fontSize: 9, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),

            // Duration badge top-right for videos
            if (widget.asset.type == AssetType.video)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  color: Colors.black.withOpacity(0.7),
                  child: Text(
                    _formatDuration(widget.asset.duration),
                    style: AppTheme.monoFont(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) {
      return '${mins}:${secs.toString().padLeft(2, '0')}';
    }
    return '${secs}s';
  }
}
