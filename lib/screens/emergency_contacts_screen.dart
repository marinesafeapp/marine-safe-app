import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';
import '../services/emergency_contact_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<EmergencyContact> contacts = [];

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final list = await EmergencyContactService.loadContacts();
      if (!mounted) return;
      setState(() {
        contacts = list.asMap().entries.map((e) => EmergencyContact(
          name: e.value.name,
          phone: e.value.phone,
          isPrimary: e.key == 0,
        )).toList();
      });
    } catch (_) {
      if (mounted) setState(() => contacts = []);
    }
  }

  Future<void> _saveContacts() async {
    await EmergencyContactService.saveContacts(contacts);
  }

  void addContact() {
    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;

    setState(() {
      contacts.add(EmergencyContact(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        isPrimary: contacts.isEmpty,
      ));
      _saveContacts();
    });

    nameCtrl.clear();
    phoneCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _input("Name", nameCtrl),
            _input("Phone", phoneCtrl),
            const SizedBox(height: 8),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: addContact,
              child: const Text("Add Contact"),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, i) {
                  final c = contacts[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF11161C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${c.name} — ${c.phone}${c.isPrimary ? " (Primary)" : ""}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              contacts.removeAt(i);
                              if (contacts.isNotEmpty && i == 0) {
                                contacts[0] = EmergencyContact(
                                  name: contacts[0].name,
                                  phone: contacts[0].phone,
                                  isPrimary: true,
                                );
                              }
                              _saveContacts();
                            });
                          },
                        )
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF11161C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
