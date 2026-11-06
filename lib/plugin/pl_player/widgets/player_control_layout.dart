import 'package:PiliPlus/plugin/pl_player/models/player_control_layout.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

/// Rebuild only the controls when the saved layout changes, keeping playback alive.
class PlayerControlLayoutBuilder extends StatefulWidget {
  const PlayerControlLayoutBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, PlayerControlLayout layout)
  builder;

  @override
  State<PlayerControlLayoutBuilder> createState() =>
      _PlayerControlLayoutBuilderState();
}

class _PlayerControlLayoutBuilderState
    extends State<PlayerControlLayoutBuilder> {
  late final Stream<BoxEvent> _changes = GStorage.setting.watch(
    key: SettingBoxKey.playerControlLayout,
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<BoxEvent>(
    stream: _changes,
    builder: (context, _) => widget.builder(context, Pref.playerControlLayout),
  );
}

/// The upstream arrangement keeps the seek rail above the action row.
class UpstreamPlayerControls extends StatelessWidget {
  const UpstreamPlayerControls({
    super.key,
    required this.progress,
    required this.controls,
  });

  final Widget progress;
  final Widget controls;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
          child: progress,
        ),
        controls,
      ],
    ),
  );
}
