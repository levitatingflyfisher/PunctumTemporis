import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:openhearth_design/openhearth_design.dart';

import '../models/clip.dart';
import '../services/storage_service.dart';

// The delete policy, in one place (fleet ruling, 2026-09-26):
//
// * A DELIBERATE delete (the Delete button on a clip, the delete on a saved
//   montage, "Remove this entry" on a missing clip) does not ask. It
//   happens at once and offers Undo through the bar below, which never
//   times out: it stays until the person taps Undo, dismisses it, or deletes
//   something else.
// * An EASY gesture that deletes would ask first with showOhConfirm naming
//   the thing. PT has none today (no swipe deletes a clip or a montage).
//
// The delete itself is soft (StorageService.removeClip/removeCompilation):
// the row leaves metadata, the files stay until the offer lapses.

/// The one Undo offer for the whole app.
///
/// A clip's delete closes the screen it happens on (the preview pops back
/// to the day or the calendar), so a bar placed on that screen would vanish
/// with it. The controller lives as long as the app, and [UndoHost] shows
/// its bar below every screen.
class UndoHost extends StatefulWidget {
  const UndoHost({super.key, required this.controller, required this.child});

  final OhUndoController controller;
  final Widget child;

  /// The app's controller, or null outside an [UndoHost] (a screen pumped
  /// alone in a test).
  static OhUndoController? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_UndoScope>()
      ?.controller;

  @override
  State<UndoHost> createState() => _UndoHostState();
}

class _UndoHostState extends State<UndoHost> {
  // The bar's buttons carry tooltips, which need an Overlay; the navigator's
  // own overlay sits below this widget, so the host brings one.
  late final OverlayEntry _entry = OverlayEntry(builder: _buildFrame);

  @override
  void didUpdateWidget(UndoHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child ||
        oldWidget.controller != widget.controller) {
      _entry.markNeedsBuild();
    }
  }

  Widget _buildFrame(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final showing = controller.pending != null;
        return Column(
          children: [
            Expanded(
              // While the bar shows it takes the bottom safe area, so the
              // screen above does not pad for the gesture bar a second time.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: showing,
                child: widget.child,
              ),
            ),
            OhUndoBar(controller: controller, commitOnDispose: false),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _UndoScope(
      controller: widget.controller,
      child: Overlay(initialEntries: [_entry]),
    );
  }
}

class _UndoScope extends InheritedWidget {
  const _UndoScope({required this.controller, required super.child});

  final OhUndoController controller;

  @override
  bool updateShouldNotify(_UndoScope old) => old.controller != controller;
}

/// Deletes [clip] at once and offers Undo in the app-wide bar.
///
/// Read the controller before awaiting anything: the widget that asked
/// usually leaves the tree with the delete. Outside an [UndoHost] (a screen
/// pumped alone) there is no bar to offer Undo in, so the files go at once.
Future<void> deleteClipWithUndo(
    BuildContext context, StorageService storage, Clip clip) async {
  final controller = UndoHost.maybeOf(context);
  final removal = await storage.removeClip(clip.id);
  if (removal == null) return;
  if (controller == null) {
    await storage.purgeRemoved(removal);
    return;
  }
  final day = DateFormat('MMM d, yyyy').format(DateTime.parse(clip.date));
  controller.show(
    message: 'Deleted the clip for $day',
    onUndo: () => storage.restoreClip(removal),
    onCommit: () => storage.purgeRemoved(removal),
  );
}

/// Deletes a saved montage at once and offers Undo in the app-wide bar.
Future<void> deleteCompilationWithUndo(BuildContext context,
    StorageService storage, Compilation compilation) async {
  final controller = UndoHost.maybeOf(context);
  final removal = await storage.removeCompilation(compilation.id);
  if (removal == null) return;
  if (controller == null) {
    await storage.purgeRemovedCompilation(removal);
    return;
  }
  controller.show(
    message: 'Deleted the montage “${compilation.title}”',
    onUndo: () => storage.restoreCompilation(removal),
    onCommit: () => storage.purgeRemovedCompilation(removal),
  );
}
