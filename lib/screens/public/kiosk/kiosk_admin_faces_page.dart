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
  List<FacePicture> _faces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    if (mounted) setState(() => _isLoading = true);

    final faces = await _db.getAllFaces();

    if (!mounted) return;
    setState(() {
      _faces = faces;
      _isLoading = false;
    });
  }

  Future<void> _deleteFace(String matricule) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              "Supprimer ?",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Ubuntu',
                color: KioskColors.textHigh,
              ),
            ),
            content: Text(
              "Voulez-vous supprimer l'empreinte de l'agent $matricule ?",
              style: const TextStyle(
                fontFamily: 'Ubuntu',
                color: KioskColors.textMid,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("ANNULER", style: TextStyle(color: KioskColors.textLow)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: KioskColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text("SUPPRIMER"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await _db.deleteFace(matricule);
    await _loadFaces();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Visage supprimé avec succès"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KioskColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: KioskScaffold(
        padding: EdgeInsets.fromLTRB(
          18 * scale,
          14 * scale,
          18 * scale,
          10 * scale,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: Get.back,
                  icon: Icon(
                    Icons.close_rounded,
                    color: KioskColors.textHigh,
                    size: 22 * scale,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: KioskColors.surface.withOpacity(0.9),
                    side: BorderSide(
                      color: KioskColors.outline.withOpacity(0.85),
                    ),
                  ),
                ),
                const Spacer(),
                const KioskBadge(label: "ADMIN CONSOLE"),
              ],
            ),
            SizedBox(height: 10 * scale),
            _AdminHeroCard(
              facesCount: _faces.length,
              onRefresh: _loadFaces,
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            Expanded(child: _buildContent(context, scale)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double scale) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: KioskColors.primary),
      );
    }

    if (_faces.isEmpty) {
      return Center(
        child: KioskCard(
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 20 * scale,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56 * scale,
                height: 56 * scale,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: KioskColors.primarySoftBg,
                ),
                child: Icon(
                  Icons.face_retouching_off_rounded,
                  color: KioskColors.primary,
                  size: 28 * scale,
                ),
              ),
              SizedBox(height: 10 * scale),
              Text(
                "Aucun agent enrôlé localement",
                textAlign: TextAlign.center,
                style: kioskBody(context).copyWith(
                  color: KioskColors.textHigh,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _faces.length,
      separatorBuilder: (_, __) => SizedBox(height: 10 * scale),
      itemBuilder: (context, index) {
        final face = _faces[index];
        return _FaceCard(
          face: face,
          scale: scale,
          onDelete: () => _deleteFace(face.matricule),
        );
      },
    );
  }
}

class _AdminHeroCard extends StatelessWidget {
  const _AdminHeroCard({
    required this.facesCount,
    required this.onRefresh,
    required this.scale,
  });

  final int facesCount;
  final VoidCallback onRefresh;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KioskColors.primary, KioskColors.accent],
        ),
        borderRadius: BorderRadius.circular(24 * scale),
        boxShadow: [
          BoxShadow(
            color: KioskColors.primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46 * scale,
                height: 46 * scale,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14 * scale),
                ),
                child: Icon(
                  Icons.face_retouching_natural_rounded,
                  color: Colors.white,
                  size: 24 * scale,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.refresh_rounded, size: 22 * scale),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.16),
                ), onPressed:onRefresh,
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Text(
            "Administration Biométrique",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Ubuntu',
              fontWeight: FontWeight.w800,
              fontSize: 22 * scale,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            "Gestion locale des empreintes faciales",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontFamily: 'Ubuntu',
              fontWeight: FontWeight.w500,
              fontSize: 13 * scale,
            ),
          ),
          SizedBox(height: 14 * scale),
          _CounterPill(
            icon: Icons.groups_rounded,
            label:
                "$facesCount agent${facesCount > 1 ? 's' : ''} enregistré${facesCount > 1 ? 's' : ''}",
            scale: scale,
          ),
        ],
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({
    required this.icon,
    required this.label,
    required this.scale,
  });

  final IconData icon;
  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16 * scale),
          SizedBox(width: 8 * scale),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Ubuntu',
                fontWeight: FontWeight.w700,
                fontSize: 12 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceCard extends StatelessWidget {
  const _FaceCard({
    required this.face,
    required this.scale,
    required this.onDelete,
  });

  final FacePicture face;
  final double scale;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imagePath = face.imagePath;
    final hasPhoto =
        imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync();

    return Container(
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: KioskColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: KioskColors.outline.withOpacity(0.72)),
        boxShadow: [
          BoxShadow(
            color: KioskColors.primaryDark.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56 * scale,
            height: 56 * scale,
            decoration: BoxDecoration(
              color: KioskColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14 * scale),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14 * scale),
              child: hasPhoto
                  ? Image.file(File(imagePath), fit: BoxFit.cover)
                  : Icon(
                      Icons.face_retouching_natural_rounded,
                      color: KioskColors.textLow,
                      size: 28 * scale,
                    ),
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  face.matricule,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Ubuntu',
                    color: KioskColors.textHigh,
                    fontSize: 16 * scale,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: KioskColors.primarySoftBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    "Empreinte biométrique",
                    style: TextStyle(
                      fontSize: 11 * scale,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Ubuntu',
                      color: KioskColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: KioskColors.danger,
              size: 22 * scale,
            ),
            style: IconButton.styleFrom(
              backgroundColor: KioskColors.danger.withOpacity(0.09),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12 * scale),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
