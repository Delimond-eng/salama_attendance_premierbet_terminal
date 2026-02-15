import '/constants/styles.dart';
import '/global/store.dart';
import '/kernel/controllers/face_recognition_controller.dart';
import '/kernel/controllers/tag_controller.dart';
import '/screens/public/attendance_shell.dart';
import '/screens/public/welcome_screen.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import '../themes/app_theme.dart';
import 'package:flutter/material.dart';

// Fonction pour vérifier et demander la permission de localisation
class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  late final Future<Widget> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _initApp(); // ← créé UNE fois
  }

  Future<Widget> _initApp() async {
    final userSession = localStorage.read("cache");
    return (userSession != null)
        ? const WelcomeScreen()
        : const AttendanceShell();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Salama Attendance',
      initialBinding: InitialBinding(),

      theme: AppTheme.lightTheme(context),
      themeMode: ThemeMode.light,
      builder: EasyLoading.init(),
      home: FutureBuilder<Widget>(
        future: _startupFuture, // ← réutilisé
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF3F6FC),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: primaryMaterialColor),
                    SizedBox(height: 14),
                    Text(
                      "Chargement de l'application...",
                      style: TextStyle(
                        color: blackColor60,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Erreur : ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          } else {
            return snapshot.data!;
          }
        },
      ),
    );
  }
}

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(TagsController());
    Get.put(FaceRecognitionController());
  }
}
