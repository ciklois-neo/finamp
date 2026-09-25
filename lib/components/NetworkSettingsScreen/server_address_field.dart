import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// A displayed edit must not depend on the keyboard's Done button to be saved.
class ServerAddressField extends StatefulWidget {
  const ServerAddressField({super.key, required this.address, required this.onCommit, this.enabled = true});
  final String address;
  final Future<void> Function(String address) onCommit;
  final bool enabled;
  @override
  State<ServerAddressField> createState() => ServerAddressFieldState();
}

class ServerAddressFieldState extends State<ServerAddressField> {
  late final _controller = TextEditingController(text: widget.address);
  final _focusNode = FocusNode();
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  late String _committed;
  Future<void>? _pendingCommit;

  @override
  void initState() {
    super.initState();
    _committed = widget.address;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) commitIfChanged();
    });
  }

  @override
  void didUpdateWidget(ServerAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect resets without overwriting an edit when another setting changes.
    if (widget.address != oldWidget.address && _controller.text.trim() == _committed) {
      _controller.text = widget.address;
      _committed = widget.address;
    }
  }

  bool validate() => !widget.enabled || (_fieldKey.currentState?.validate() ?? false);

  Future<bool> commitIfChanged() async {
    // Save must also wait for a commit triggered by focus loss.
    if (_pendingCommit != null) await _pendingCommit;
    if (!mounted) return false;
    if (!validate()) return false;
    if (!widget.enabled) return true;
    final value = _controller.text.trim();
    if (value == _committed) return true;
    final previous = _committed;
    // Focus loss and an explicit Save can occur in the same frame.
    _committed = value;
    try {
      _pendingCommit = widget.onCommit(value);
      await _pendingCommit;
      return true;
    } catch (_) {
      _committed = previous;
      rethrow;
    } finally {
      _pendingCommit = null;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: _fieldKey,
    enabled: widget.enabled,
    controller: _controller,
    focusNode: _focusNode,
    style: TextTheme.of(context).bodyMedium,
    textAlign: TextAlign.center,
    keyboardType: TextInputType.url,
    autocorrect: false,
    textInputAction: TextInputAction.done,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (value) => isValidServerAddress(value ?? '') ? null : AppLocalizations.of(context)!.invalidServerAddress,
    onFieldSubmitted: (_) => commitIfChanged(),
  );
}

bool isValidServerAddress(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || RegExp(r'\s').hasMatch(trimmed)) return false;
  return (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.port > 0 &&
      uri.port <= 65535;
}
