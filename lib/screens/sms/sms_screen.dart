import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/gold_price_service.dart';
import '../../shared/widgets/app_widgets.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _goldPriceService = GoldPriceService();
  final _exchangeRateService = ExchangeRateService();
  GoldPriceQuote? _goldQuote;
  ExchangeRateSnapshot? _exchangeRates;
  Timer? _refreshTimer;
  bool _isRefreshingRates = false;
  String? _ratesError;
  Contact? _recipient;
  final List<String> _preparedMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshRates();
    _refreshTimer = Timer.periodic(
      GoldPriceService.refreshInterval,
      (_) => _refreshRates(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _messageController.dispose();
    _goldPriceService.close();
    _exchangeRateService.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshRates();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.store.contacts
        .where((contact) => _hasPhone(contact.phone))
        .toList();
    final selectedRecipient = contacts.contains(_recipient) ? _recipient : null;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const PageHeading(eyebrow: 'Communication', title: 'SMS'),
        const AppPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppTheme.gold),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Préparez un message pour un contact. Votre application SMS '
                  's’ouvrira pour vérifier et envoyer le message.',
                  style: TextStyle(height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nouveau message',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _buildMarketRates(),
              const SizedBox(height: 16),
              DropdownButtonFormField<Contact>(
                initialValue: selectedRecipient,
                isExpanded: true,
                decoration: fieldDecoration('Choisir un contact'),
                items: [
                  for (final contact in contacts)
                    DropdownMenuItem(
                      value: contact,
                      child: Text(
                        '${contact.name} · ${contact.phone}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (contact) => setState(() => _recipient = contact),
              ),
              if (contacts.isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Aucun contact avec un numéro de téléphone valide.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              _buildConversation(),
              const SizedBox(height: 10),
              TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 4,
                maxLength: 1600,
                onChanged: (_) => setState(() {}),
                decoration: fieldDecoration('Écrire un message…').copyWith(
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.chat_bubble_outline),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isRefreshingRates || _goldQuote == null
                    ? null
                    : _appendMarketRates,
                icon: const Icon(Icons.trending_up),
                label: const Text('Ajouter les cours actuels au message'),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Ouvrir l’application SMS',
                icon: Icons.sms_outlined,
                onPressed:
                    selectedRecipient == null ||
                        _messageController.text.trim().isEmpty
                    ? null
                    : () => _openSms(selectedRecipient),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      selectedRecipient == null ||
                          _messageController.text.trim().isEmpty
                      ? null
                      : () => _openWhatsApp(selectedRecipient),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Ouvrir WhatsApp'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasPhone(String phone) =>
      phone.trim().isNotEmpty && phone != 'Téléphone non renseigné';

  Widget _buildConversation() {
    return Container(
      height: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: _preparedMessages.isEmpty
          ? Align(
              alignment: Alignment.topLeft,
              child: _chatBubble(
                'Bonjour ! Rédigez votre message ci-dessous. '
                'Il sera transféré à votre application SMS pour confirmation.',
                isOutgoing: false,
              ),
            )
          : ListView(
              reverse: true,
              children: [
                for (final message in _preparedMessages.reversed)
                  _chatBubble(
                    message,
                    isOutgoing: true,
                    status: 'SMS ouvert · envoi à confirmer',
                  ),
                _chatBubble(
                  'Conversation avec ${_recipient?.name ?? 'votre contact'}',
                  isOutgoing: false,
                ),
              ],
            ),
    );
  }

  Widget _chatBubble(String text, {required bool isOutgoing, String? status}) {
    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isOutgoing ? AppTheme.forest : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isOutgoing ? null : Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isOutgoing ? Colors.white : AppTheme.forest,
                fontSize: 13,
              ),
            ),
            if (status != null) ...[
              const SizedBox(height: 4),
              Text(
                status,
                style: const TextStyle(color: Color(0xFFD7E4DB), fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarketRates() {
    final goldQuote = _goldQuote;
    final usdToXaf = _exchangeRates?.rate('USD', 'XAF');
    final gold24k = goldQuote == null || usdToXaf == null
        ? null
        : goldQuote.pricePerKaratGramUsd(24) * usdToXaf;
    final gold18k = goldQuote == null || usdToXaf == null
        ? null
        : goldQuote.pricePerKaratGramUsd(18) * usdToXaf;
    final updatedAt = goldQuote?.updatedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cours en direct pour vos messages',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Actualiser les cours',
                visualDensity: VisualDensity.compact,
                onPressed: _isRefreshingRates ? null : _refreshRates,
                icon: _isRefreshingRates
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          Text(
            gold24k == null
                ? 'Or 24K : indisponible'
                : 'Or 24K : ${_formatXaf(gold24k)} XAF/g',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            gold18k == null
                ? 'Or 18K : indisponible'
                : 'Or 18K : ${_formatXaf(gold18k)} XAF/g',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            usdToXaf == null
                ? 'USD/XAF : indisponible'
                : '1 USD = ${_formatXaf(usdToXaf)} XAF',
            style: const TextStyle(fontSize: 12),
          ),
          if (updatedAt != null)
            Text(
              'Cours de l’or relevé le ${_dateTime(updatedAt)}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 10),
            ),
          if (_ratesError != null)
            Text(
              'Actualisation incomplète : $_ratesError',
              style: const TextStyle(color: AppTheme.red, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Future<void> _refreshRates() async {
    if (_isRefreshingRates) return;
    setState(() {
      _isRefreshingRates = true;
      _ratesError = null;
    });

    GoldPriceQuote? goldQuote;
    ExchangeRateSnapshot? exchangeRates;
    String? goldError;
    String? exchangeError;
    try {
      goldQuote = await _goldPriceService.fetchGoldUsd();
    } catch (error) {
      goldError = error.toString();
    }
    try {
      exchangeRates = await _exchangeRateService.fetchRates();
    } catch (error) {
      exchangeError = error.toString();
    }

    if (!mounted) return;
    setState(() {
      if (goldQuote != null) _goldQuote = goldQuote;
      if (exchangeRates != null) _exchangeRates = exchangeRates;
      final errors = [
        if (goldError != null) 'GoldAPI : $goldError',
        if (exchangeError != null) 'USD/XAF : $exchangeError',
      ];
      _ratesError = errors.isEmpty ? null : errors.join(' · ');
      _isRefreshingRates = false;
    });
  }

  void _appendMarketRates() {
    final quote = _goldQuote;
    final usdToXaf = _exchangeRates?.rate('USD', 'XAF');
    if (quote == null || usdToXaf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les cours de l’or et USD/XAF ne sont pas disponibles.',
          ),
        ),
      );
      return;
    }

    final ratesMessage = [
      'Cours indicatifs actualisés le ${_dateTime(quote.updatedAt)} :',
      'Or 24K : ${_formatXaf(quote.pricePerKaratGramUsd(24) * usdToXaf)} XAF/g',
      'Or 18K : ${_formatXaf(quote.pricePerKaratGramUsd(18) * usdToXaf)} XAF/g',
      '1 USD = ${_formatXaf(usdToXaf)} XAF',
    ].join('\n');
    final currentMessage = _messageController.text.trimRight();
    final updatedMessage = currentMessage.isEmpty
        ? ratesMessage
        : '$currentMessage\n\n$ratesMessage';
    _messageController.value = TextEditingValue(
      text: updatedMessage,
      selection: TextSelection.collapsed(offset: updatedMessage.length),
    );
    setState(() {});
  }

  Future<void> _openSms(Contact recipient) async {
    final uri = Uri(
      scheme: 'sms',
      path: recipient.phone,
      queryParameters: {'body': _messageController.text.trim()},
    );
    final opened = await launchUrl(uri);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’ouvrir une application SMS sur cet appareil.',
          ),
        ),
      );
    } else {
      setState(() {
        _preparedMessages.insert(0, _messageController.text.trim());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message transféré à l’application SMS. Confirmez son envoi là-bas.',
          ),
        ),
      );
    }
  }

  Future<void> _openWhatsApp(Contact recipient) async {
    final phone = recipient.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.https('wa.me', '/$phone', {
      'text': _messageController.text.trim(),
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir WhatsApp sur cet appareil.'),
        ),
      );
    } else {
      setState(() {
        _preparedMessages.insert(0, _messageController.text.trim());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message transféré à WhatsApp. Confirmez son envoi là-bas.',
          ),
        ),
      );
    }
  }

  static String _formatXaf(double value) => money(value).replaceAll(',', ' ');

  static String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
