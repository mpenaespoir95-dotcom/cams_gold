import 'package:flutter/material.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final contacts = store.contactsWithAppointments;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const PageHeading(eyebrow: 'Agenda', title: 'Rendez-vous'),
            AppPanel(
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    color: AppTheme.gold,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${contacts.length}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'rendez-vous fixé${contacts.length == 1 ? '' : 's'}',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _chooseContact(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouveau RDV'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionHeading(
              'Rendez-vous fixés',
              icon: Icons.calendar_month_outlined,
            ),
            const SizedBox(height: 10),
            if (contacts.isEmpty)
              const AppPanel(
                child: Text('Aucun rendez-vous fixé pour le moment.'),
              )
            else
              for (final contact in contacts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppPanel(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.paper,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.event_available_outlined,
                            color: AppTheme.gold,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${contact.appointment} · ${contact.city}',
                                style: const TextStyle(color: AppTheme.muted),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                contact.phone,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Modifier le rendez-vous',
                          onPressed: () =>
                              showAppointmentEditor(context, store, contact),
                          icon: const Icon(
                            Icons.edit_calendar_outlined,
                            color: AppTheme.gold,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Supprimer le rendez-vous',
                          onPressed: () => _removeAppointment(context, contact),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _chooseContact(BuildContext context) async {
    final availableContacts = store.contacts;
    if (availableContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez d’abord un contact.')),
      );
      return;
    }

    Contact? selectedContact = availableContacts.first;
    final contact = await showDialog<Contact>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau rendez-vous'),
          content: DropdownButtonFormField<Contact>(
            initialValue: selectedContact,
            decoration: fieldDecoration('Choisir un contact'),
            items: [
              for (final contact in availableContacts)
                DropdownMenuItem(value: contact, child: Text(contact.name)),
            ],
            onChanged: (value) => setDialogState(() => selectedContact = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedContact),
              child: const Text('Continuer'),
            ),
          ],
        ),
      ),
    );
    if (contact != null && context.mounted) {
      await showAppointmentEditor(context, store, contact);
    }
  }

  Future<void> _removeAppointment(BuildContext context, Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le rendez-vous ?'),
        content: Text('Le rendez-vous de ${contact.name} sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      store.removeAppointment(contact);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rendez-vous supprimé.')));
      }
    }
  }
}

Future<void> showAppointmentEditor(
  BuildContext context,
  AppStore store,
  Contact contact,
) async {
  final subject = TextEditingController();
  var selectedDate = DateTime.now().add(const Duration(days: 1));
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Rendez-vous — ${contact.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: dialogContext,
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (date != null) setDialogState(() => selectedDate = date);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subject,
              decoration: fieldDecoration('Heure ou objet du rendez-vous'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
  if (saved == true) {
    store.saveAppointment(
      contact,
      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} · ${subject.text.trim().isEmpty ? 'Rendez-vous' : subject.text.trim()}',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rendez-vous enregistré.')));
    }
  }
  subject.dispose();
}
