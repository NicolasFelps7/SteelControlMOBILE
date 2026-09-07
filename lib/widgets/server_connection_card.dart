import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';

class ServerConnectionCard extends StatefulWidget {
  const ServerConnectionCard({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final AppController controller;
  final bool compact;

  @override
  State<ServerConnectionCard> createState() => _ServerConnectionCardState();
}

class _ServerConnectionCardState extends State<ServerConnectionCard> {
  late final TextEditingController _url;
  bool _testing = false;
  bool? _ok;
  String? _status;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    if (_testing) return;
    final strings = AppStrings.of(context);
    setState(() {
      _testing = true;
      _ok = null;
      _status = strings.get('testingServer');
    });

    final previousUrl = ApiConfig.baseUrl;

    try {
      await widget.controller.updateApiUrl(_url.text);
      final savedUrl = ApiConfig.baseUrl;
      await widget.controller.testApiConnection();
      _url.text = savedUrl;
      if (!mounted) return;
      setState(() {
        _ok = true;
        _status = strings.get('serverConnectionOk');
      });
    } on FormatException catch (exception) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _status = exception.message;
      });
    } on ApiException catch (exception) {
      await widget.controller.updateApiUrl(previousUrl);
      if (!mounted) return;
      setState(() {
        _ok = false;
        _status = exception.message;
      });
    } catch (_) {
      try {
        await widget.controller.updateApiUrl(previousUrl);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _ok = false;
        _status = strings.get('serverConnectionFailed');
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final padding = widget.compact ? 14.0 : 18.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: .42),
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SteelColors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dns_outlined, color: SteelColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.get('serverConnection'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.get('serverConnectionCaption'),
                      style: const TextStyle(
                        color: SteelColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: strings.get('serverAddress'),
              hintText: 'http://192.168.15.9:3000',
              prefixIcon: const Icon(Icons.lan_outlined),
            ),
            onSubmitted: (_) => _saveAndTest(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _status ?? strings.get('serverSavedOnTablet'),
                  style: TextStyle(
                    color: _ok == true
                        ? SteelColors.success
                        : _ok == false
                            ? SteelColors.danger
                            : SteelColors.muted,
                    fontSize: 11,
                    fontWeight: _ok == null ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _testing ? null : _saveAndTest,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: Text(strings.get('saveAndTest')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
