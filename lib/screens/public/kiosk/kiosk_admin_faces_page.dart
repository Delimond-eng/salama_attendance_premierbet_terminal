import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Map<String, List<FacePicture>> _groupedFaces = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    if (mounted) setState(() => _isLoading = true);

    final faces = await _db.getAllFaces();
    final Map<String, List<FacePicture>> grouped = {};
    for (var face in faces) {
      if (!grouped.containsKey(face.matricule)) {
        grouped[face.matricule] = [];
      }
      grouped[face.matricule]!.add(face);
    }

    if (!mounted) return;
    setState(() {
      _groupedFaces = grouped;
      _isLoading = false;
    });
  }

  Future<void> _deleteAgent(String matricule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Supprimer l'agent ?", style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Ubuntu')),
        content: Text("Voulez-vous supprimer définitivement l'agent $matricule et toutes ses empreintes associées ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: KioskColors.danger),
            child: const Text("TOUT SUPPRIMER"),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;
    await _db.deleteFace(matricule);
    await _loadFaces();
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Icons noires sur fond clair
        statusBarBrightness: Brightness.light,
      ),
      child: KioskScaffold(
        padding: EdgeInsets.fromLTRB(18 * scale, 14 * scale, 18 * scale, 10 * scale),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.9)),
                ),
                const Spacer(),
                const KioskBadge(label: "ADMIN CONSOLE"),
              ],
            ),
            SizedBox(height: 10 * scale),
            _AdminHeroCard(agentsCount: _groupedFaces.length, onRefresh: _loadFaces, scale: scale),
            SizedBox(height: 12 * scale),
            Expanded(child: _buildContent(context, scale)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double scale) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_groupedFaces.isEmpty) return const Center(child: Text("Aucun agent enrôlé localement"));

    final matricules = _groupedFaces.keys.toList();
    return ListView.separated(
      itemCount: matricules.length,
      separatorBuilder: (_, __) => SizedBox(height: 10 * scale),
      itemBuilder: (context, index) {
        final matricule = matricules[index];
        final agentFaces = _groupedFaces[matricule]!;
        return _AgentCard(
          matricule: matricule,
          face: agentFaces.first,
          count: agentFaces.length,
          scale: scale,
          onDelete: () => _deleteAgent(matricule),
        );
      },
    );
  }
}

// ... (Les widgets _AdminHeroCard, _AgentCard, _CounterPill restent identiques)
class _AdminHeroCard extends StatelessWidget {
  final int agentsCount;
  final VoidCallback onRefresh;
  final double scale;
  const _AdminHeroCard({required this.agentsCount, required this.onRefresh, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [KioskColors.primary, KioskColors.accent]),
        borderRadius: BorderRadius.circular(24 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.face_retouching_natural_rounded, color: Colors.white),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: onRefresh),
            ],
          ),
          const SizedBox(height: 12),
          const Text("Administration", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 14),
          _CounterPill(icon: Icons.groups_rounded, label: "$agentsCount agents", scale: scale),
        ],
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final double scale;
  const _CounterPill({required this.icon, required this.label, required this.scale});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white))]),
  );
}

class _AgentCard extends StatelessWidget {
  final String matricule;
  final FacePicture face;
  final int count;
  final double scale;
  final VoidCallback onDelete;
  const _AgentCard({required this.matricule, required this.face, required this.count, required this.scale, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = face.imagePath != null && File(face.imagePath!).existsSync();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: 56, height: 56, child: hasPhoto ? Image.file(File(face.imagePath!), fit: BoxFit.cover) : const Icon(Icons.person)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(matricule, style: const TextStyle(fontWeight: FontWeight.bold)), Text("Empreintes: $count")])),
          IconButton(icon: const Icon(Icons.delete_forever_rounded, color: Colors.red), onPressed: onDelete),
        ],
      ),
    );
  }
}
