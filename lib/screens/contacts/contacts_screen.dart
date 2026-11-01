import 'package:flutter/material.dart';

import '../../core/app_store.dart';
import '../../shared/widgets/app_widgets.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _filter = 'Tous';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final contacts = widget.store.contacts.where((contact) {
      final roleFilter = switch (_filter) {
        'Clients' => 'Client',
        'Fournisseurs' => 'Fournisseur',
        _ => null,
      };
      final matchesFilter =
          roleFilter == null ||
          contact.roles.any(
            (role) => role.toLowerCase().contains(roleFilter.toLowerCase()),
          );
      final matchesQuery =
          '${contact.reference} ${contact.name} ${contact.city} '
                  '${contact.phone} ${contact.email}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      return matchesFilter && matchesQuery;
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        PageHeading(eyebrow: 'Répertoire', title: 'Clients & fournisseurs'),
        PrimaryButton(
          label: 'Nouveau contact',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: _addContact,
        ),
        const SizedBox(height: 14),
        TextField(
          decoration: fieldDecoration(
            'Rechercher un contact',
          ).copyWith(prefixIcon: const Icon(Icons.search)),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ['Tous', 'Fournisseurs', 'Clients']
              .map(
                (filter) => ChoiceChip(
                  label: Text(filter),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        if (contacts.isEmpty)
          const AppPanel(
            child: Text('Aucun contact ne correspond à votre recherche.'),
          )
        else ...[
          AppPanel(
            padding: 8,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                headingRowHeight: 48,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                columns: const [
                  DataColumn(label: Text('N°')),
                  DataColumn(label: Text('Référence')),
                  DataColumn(label: Text('Nom complet')),
                  DataColumn(label: Text('Ville')),
                  DataColumn(label: Text('Téléphone')),
                  DataColumn(label: Text('Type')),
                ],
                rows: [
                  for (var index = 0; index < contacts.length; index++)
                    DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(contacts[index].reference)),
                        DataCell(
                          InkWell(
                            onTap: () => _showContactDetails(contacts[index]),
                            child: Text(
                              contacts[index].name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(contacts[index].city)),
                        DataCell(Text(contacts[index].phone)),
                        DataCell(
                          Text(
                            contacts[index].roles.join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _addContact() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final city = TextEditingController();
    final email = TextEditingController();
    final notes = TextEditingController();
    final roles = <String>{};
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: fieldDecoration('Nom complet'),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  decoration: fieldDecoration('Téléphone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: city,
                  decoration: fieldDecoration('Ville'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: fieldDecoration('Adresse e-mail'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: fieldDecoration('Observations'),
                ),
                const SizedBox(height: 8),
                for (final role in [
                  'Fournisseur d’or',
                  'Client d’or',
                  'Fournisseur d’échange',
                  'Client d’échange',
                  'Partenaire',
                ])
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(role, style: const TextStyle(fontSize: 13)),
                    value: roles.contains(role),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        roles.add(role);
                      } else {
                        roles.remove(role);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: name.text.trim().isEmpty || roles.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    if (added == true) {
      widget.store.addContact(
        Contact(
          name: name.text.trim(),
          phone: phone.text.trim().isEmpty
              ? 'Téléphone non renseigné'
              : phone.text.trim(),
          city: city.text.trim().isEmpty
              ? 'Ville non renseignée'
              : city.text.trim(),
          email: email.text.trim(),
          notes: notes.text.trim(),
          roles: roles,
        ),
      );
      setState(() {});
      _message('Contact ajouté au répertoire.');
    }
    name.dispose();
    phone.dispose();
    city.dispose();
    email.dispose();
    notes.dispose();
  }

  Future<void> _showContactDetails(Contact contact) async {
    final history = widget.store.operations
        .where(
          (entry) =>
              entry.subtitle.toLowerCase().contains(contact.name.toLowerCase()),
        )
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contact.name),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _contactDetail('Référence', contact.reference),
                _contactDetail('Téléphone', contact.phone),
                _contactDetail('E-mail', contact.email),
                _contactDetail('Ville', contact.city),
                _contactDetail('Rôles', contact.roles.join(', ')),
                _contactDetail(
                  'Observations',
                  contact.notes.isEmpty ? 'Aucune' : contact.notes,
                ),
                const Divider(height: 24),
                const Text(
                  'Historique des opérations',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Aucune opération enregistrée pour ce contact.'),
                  )
                else
                  ...history.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.title),
                      subtitle: Text('${entry.subtitle} · ${entry.date}'),
                      trailing: Text('${entry.amount.toStringAsFixed(0)} FCFA'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _contactDetail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text('$label : ${value.isEmpty ? 'Non renseigné' : value}'),
  );

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
