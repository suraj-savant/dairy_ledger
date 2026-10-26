import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../accounts/models/account.dart';

/// Shows the account's QR code and lets the admin share the link. The farmer
/// scans the code with the normal phone camera, which opens the link.
Future<void> showAccountQrDialog(
  BuildContext context, {
  required Account account,
  required String link,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(account.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(data: link, size: 220),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask the farmer to scan this code with the phone camera to see their milk records.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(link, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        TextButton.icon(
          icon: const Icon(Icons.share),
          label: const Text('Share link'),
          onPressed: () => SharePlus.instance.share(ShareParams(
            text: 'View your milk records at ${account.dairyName.isEmpty ? 'our dairy' : account.dairyName}: $link',
          )),
        ),
      ],
    ),
  );
}
