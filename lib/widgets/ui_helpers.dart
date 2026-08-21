import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_controller.dart';

class BusySpinner extends StatelessWidget {
  const BusySpinner({super.key, this.color = Colors.white});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
}) async {
  final app = appController;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(app.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(app.t('confirm')),
        ),
      ],
    ),
  );
  return ok == true;
}

class LoginRequired extends StatelessWidget {
  const LoginRequired({super.key, this.withScaffold = false});
  final bool withScaffold;

  @override
  Widget build(BuildContext context) {
    final app = appController;
    final body = EmptyState(
      icon: Icons.lock_outline,
      message: app.t('please_login_continue'),
      actionLabel: app.t('login'),
      onAction: () => context.push('/login'),
    );
    if (!withScaffold) return body;
    return Scaffold(appBar: AppBar(), body: body);
  }
}
