import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/kernel/models/face.dart';
import '/kernel/services/database_helper.dart';
import 'kiosk_components.dart';

class KioskAdminFacesPage extends StatefulWidget {
  const KioskAdminFacesPage({super.key});

  @override
  State<KioskAdminFacesPage> createState() => _KioskAdminFacesPageState();
}

class _KioskAdminFacesPageState extends State<KioskAdminFacesPage> {
  final DatabaseHelper _db = DatabaseHelper();
  List<FacePicture> _faces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    setState(() => _isLoading = true);
    final faces = await _db.getAllFaces();
    setState(() {
      _faces = faces;
      _isLoading = false;
    });
  }

  Future<void> _deleteFace(String matricule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ?", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        content: Text("Voulez-vous supprimer l'empreinte de l'agent $matricule ?", style: const TextStyle(fontFamily: 'Poppins')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SUPPRIMER", style: TextStyle(color: KioskColors.danger, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteFace(matricule);
      _loadFaces();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Visage supprimé avec succès")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskColors.background,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        elevation: 0,
        leading: IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close_rounded, color: Colors.white)),
        title: const Text("ADMIN - AGENTS ENRÔLÉS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontFamily: 'Poppins', fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _faces.isEmpty
              ? const Center(child: Text("Aucun agent enrôlé localement", style: TextStyle(fontFamily: 'Poppins', color: KioskColors.textMid)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
                  itemCount: _faces.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final face = _faces[index];
                    return KioskCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: KioskColors.lightGray,
                          backgroundImage: face.imagePath != null ? FileImage(File(face.imagePath!)) : null,
                          child: face.imagePath == null ? const Icon(Icons.person, color: KioskColors.textLow) : null,
                        ),
                        title: Text(face.matricule, style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Poppins', fontSize: 16)),
                        subtitle: Text("Empreinte biométrique", style: TextStyle( fontSize: 10, fontWeight: FontWeight.w400, fontFamily: 'Poppins')),
                        trailing: IconButton(
                          onPressed: () => _deleteFace(face.matricule),
                          icon: const Icon(Icons.delete_outline_rounded, color: KioskColors.danger),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
