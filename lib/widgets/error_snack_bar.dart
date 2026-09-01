import 'package:flutter/material.dart';

/// The one way a PT screen reports a failed act in a SnackBar.
///
/// [message] is a plain sentence written for the person holding the phone:
/// what did not happen and what to do next. Never a caught exception's text
/// (log that with debugPrint; `test/screens/no_raw_errors_test.dart` holds
/// the rule). The bar carries the fleet's urgency colour together with an
/// icon and the words, so the failure never rests on colour alone.
void showErrorSnackBar(BuildContext context, String message) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: scheme.error,
      content: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onError),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    ),
  );
}

/// Said when the camera plugin fails to list or open a camera. The person
/// can't fix a platform channel; they can close the app holding the camera,
/// or take the day's second from the gallery instead.
const cameraUnavailableMessage =
    "The camera didn’t start. Close any other app using it and try again, "
    'or import from your gallery.';
