import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_transition.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:material_ui/material_ui.dart';

class RecentHistoryItem extends StatefulWidget {
  const RecentHistoryItem({super.key, required this.item});

  final HistoryItemModel item;

  @override
  State<RecentHistoryItem> createState() => _RecentHistoryItemState();
}

class _RecentHistoryItemState extends State<RecentHistoryItem> {
  late String _heroTag;

  HistoryItemModel get _item => widget.item;

  @override
  void initState() {
    super.initState();
    _heroTag = _makeHeroTag();
  }

  @override
  void didUpdateWidget(covariant RecentHistoryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.item, _item)) _heroTag = _makeHeroTag();
  }

  String _makeHeroTag() => Utils.makeHeroTag(
    _item.history.cid ?? _item.history.bvid ?? _item.history.oid,
  );

  Future<void> _openVideo() async {
    final aid = _item.history.oid;
    if (aid == null) return;
    final bvid = _item.history.bvid ?? IdUtils.av2bv(aid);
    var cid = _item.history.cid;
    Dimension? dimension;
    if (cid == null) {
      final result = await SearchHttp.ab2cWithDimension(
        aid: aid,
        bvid: bvid,
        part: _item.history.page,
      );
      cid = result?.cid;
      dimension = result?.dimension;
    }
    if (cid == null || !mounted) return;
    PageUtils.toVideoPage(
      aid: aid,
      bvid: bvid,
      cid: cid,
      cover: _item.cover,
      title: _item.title,
      dimension: dimension,
      progress: _item.playbackProgress,
      heroTag: _heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _item.duration;
    final progress = _item.progress;
    final progressText = duration == null || duration == 0
        ? null
        : progress == -1
        ? '已看完'
        : '${DurationUtils.formatDuration(progress)}/${DurationUtils.formatDuration(duration)}';
    return SizedBox(
      width: 180,
      child: VideoCardHero(
        tag: _heroTag,
        surfaceColor: theme.colorScheme.surfaceContainer,
        child: Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openVideo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: Style.aspectRatio,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      fit: StackFit.expand,
                      children: [
                        NetworkImgLayer(
                          src: _item.cover?.isNotEmpty == true
                              ? _item.cover
                              : _item.covers?.firstOrNull ?? '',
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                        ),
                        if (progressText != null)
                          PBadge(
                            text: progressText,
                            right: 6,
                            bottom: 6,
                            size: PBadgeSize.small,
                            type: PBadgeType.gray,
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.title ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        const Spacer(),
                        if (_item.authorName?.isNotEmpty == true)
                          Text(
                            _item.authorName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
