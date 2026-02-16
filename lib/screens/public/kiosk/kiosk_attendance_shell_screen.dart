import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/global/controllers.dart';
import 'kiosk_admin_faces_page.dart';
import 'kiosk_components.dart';

class KioskAttendanceShellScreen extends StatelessWidget {
  const KioskAttendanceShellScreen({
    super.key,
    required this.onCheckAction,
    required this.onEnrollAction,
    required this.onBack,
  });

  final Function(String) onCheckAction;
  final VoidCallback onEnrollAction;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return KioskScaffold(
      padding: EdgeInsets.zero,
      topSafeArea: false,
      child: Obx(() {
        final station = tagsController.activeStation.value;
        final stationName = (station?['name'] ?? 'Station principale')
            .toString();
        final topInset = MediaQuery.paddingOf(context).top;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              stretch: true,
              expandedHeight: topInset + 248 * scale,
              collapsedHeight: topInset + 56 * scale,
              toolbarHeight: 56 * scale,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: KioskColors.primaryDark,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: _StationHeroSliverHeader(
                  scale: scale,
                  stationName: stationName,
                  topInset: topInset,
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24 * scale,
                  20 * scale,
                  24 * scale,
                  12 * scale,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 420 * scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        KioskActionButton(
                          title: 'CHECK-IN',
                          subtitle: 'Enregistrer une entrée',
                          icon: Icons.login_rounded,
                          color: KioskColors.success,
                          onPressed: () => onCheckAction('check-in'),
                        ),

                        SizedBox(height: 10 * scale),

                        KioskActionButton(
                          title: 'CONFIRMATION',
                          subtitle: 'Contrôle intermédiaire',
                          icon: Icons.verified_user,
                          color: KioskColors.accent,
                          onPressed: () => onCheckAction('confirmation'),
                        ),

                        SizedBox(height: 10 * scale),

                        KioskActionButton(
                          title: 'CHECK-OUT',
                          subtitle: 'Enregistrer une sortie',
                          icon: Icons.login_rounded,
                          color: KioskColors.danger,
                          onPressed: () => onCheckAction('check-out'),
                        ),
                        const Spacer(),
                        KioskOutlineButton(
                          label: "Enrôler le visage d'un agent",
                          icon: Icons.face_retouching_natural_rounded,
                          height: 70,
                          onPressed: onEnrollAction,
                        ),
                        SizedBox(height: 14 * scale),
                        Center(
                          child: KioskGhostButton(
                            label: 'Retour au scan station',
                            icon: Icons.arrow_back_ios_new_rounded,
                            onPressed: onBack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StationHeroSliverHeader extends StatelessWidget {
  const _StationHeroSliverHeader({
    required this.scale,
    required this.stationName,
    required this.topInset,
  });

  final double scale;
  final String stationName;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => Get.to(() => const KioskAdminFacesPage()),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KioskColors.primary, KioskColors.accent],
          ),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: KioskColors.primary.withValues(alpha: 0.26),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -60,
              top: -40,
              child: Container(
                width: 200 * scale,
                height: 200 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -36,
              bottom: -52,
              child: Container(
                width: 160 * scale,
                height: 160 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24 * scale,
                topInset + (10 * scale),
                24 * scale,
                24 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Align(
                    alignment: Alignment.topCenter,
                    child: KioskBrandHeader(
                      blueMode: true,
                      enableAdminShortcut: false,
                    ),
                  ),
                  SizedBox(height: 14 * scale),
                  Text(
                    'STATION ${stationName.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Ubuntu',
                      fontWeight: FontWeight.w900,
                      fontSize: 24 * scale,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 6 * scale),
                  Text(
                    'Mode pointage actif. Selectionnez check-in ou check-out.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.93),
                      fontFamily: 'Ubuntu',
                      fontWeight: FontWeight.w500,
                      fontSize: 12 * scale,
                    ),
                  ),
                  SizedBox(height: 14 * scale),
                  _WhitePill(
                    scale: scale,
                    icon: Icons.verified_rounded,
                    label: 'Station identifiée et prête',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill({
    required this.scale,
    required this.icon,
    required this.label,
  });

  final double scale;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
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
                fontWeight: FontWeight.w700,
                fontFamily: 'Ubuntu',
                fontSize: 12 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
