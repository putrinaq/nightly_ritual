import 'package:flutter/material.dart';

import '../widgets/controls.dart';
import '../widgets/playlists.dart';

class ListenStep extends StatelessWidget {
  final String uid;
  const ListenStep({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Put on something slow',
            subtitle: const Text('Open a playlist, let it start, then come back and continue.'),
            trailing: PillButton(
              label: 'Add',
              onPressed: () => showAddPlaylistSheet(context, uid),
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ShaderMask(
              // Soft fade where the list meets the button, not a hard edge.
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.88, 1],
              ).createShader(r),
              child: PlaylistList(uid: uid, padding: const EdgeInsets.only(bottom: 24)),
            ),
          ),
        ],
      ),
    );
  }
}
