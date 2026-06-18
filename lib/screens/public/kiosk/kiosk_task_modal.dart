import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import '/screens/public/modals/media_modal.dart';
import '/global/controllers.dart';
import '/kernel/models/task.dart';
import '/kernel/services/http_manager.dart';
import 'kiosk_components.dart';

class KioskTaskModal extends StatefulWidget {
  final String matricule;
  final XFile? capturedImage;
  const KioskTaskModal({super.key, required this.matricule, this.capturedImage});

  @override
  State<KioskTaskModal> createState() => _KioskTaskModalState();
}

class _KioskTaskModalState extends State<KioskTaskModal> {
  final HttpManager _http = HttpManager();
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Utilisation d'un délai minime pour s'assurer que le BottomSheet est bien rendu avant de lancer le loader
    Future.delayed(Duration.zero, _loadTasks);
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final stationId = tagsController.activeStation.value?['id'];
      final fetchedTasks = await _http.getTasks(stationId, widget.matricule);
      
      if (mounted) {
        setState(() {
          _tasks = fetchedTasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHeader(scale),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? _buildEmptyState(scale)
                    : ListView.separated(
                        padding: EdgeInsets.all(20 * scale),
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => SizedBox(height: 16 * scale),
                        itemBuilder: (context, index) => _TaskCard(
                          task: _tasks[index],
                          matricule: widget.matricule,
                          onRefresh: _loadTasks,
                        ),
                      ),
          ),
          _buildGlobalFooter(scale),
        ],
      ),
    );
  }

  Widget _buildHeader(double scale) {
    return Padding(
      padding: EdgeInsets.all(20 * scale),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Missions & Tâches", style: kioskSubtitle(context)),
              Text("Suivi d'intervention", style: kioskCaption(context)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(double scale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 64 * scale, color: Colors.grey.shade300),
          SizedBox(height: 16 * scale),
          Text("Aucune tâche en attente", style: kioskBody(context)),
          Text("Vous pouvez clôturer l'intervention", style: kioskCaption(context)),
        ],
      ),
    );
  }

  Widget _buildGlobalFooter(double scale) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 30 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 55 * scale,
        child: ElevatedButton.icon(
          onPressed: () => Get.back(result: 'confirm-closure'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          icon: const Icon(Icons.lock_reset_rounded),
          label: const Text("CLÔTURER ET RE-SCANNER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final String matricule;
  final VoidCallback onRefresh;

  const _TaskCard({required this.task, required this.matricule, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    final isCompleted = task.status == 'completed';

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PriorityBadge(priority: task.priority),
              const Spacer(),
              Text("${(task.progress * 100).toInt()}%",
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.blue, fontSize: 12)),
            ],
          ),
          SizedBox(height: 12 * scale),
          Text(task.title, style: kioskSubtitle(context).copyWith(fontSize: 16 * scale)),
          SizedBox(height: 16 * scale),
          LinearProgressIndicator(
            value: task.progress,
            backgroundColor: Colors.grey.shade100,
            color: task.status == 'completed' ? Colors.green : Colors.blue,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          if (!isCompleted) ...[
            SizedBox(height: 16 * scale),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: const Text("Mettre à jour"),
                icon: const Icon(Icons.edit_document, size: 18),
                onPressed: () => _showCompletionSheet(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCompletionSheet(BuildContext context) {
    Get.bottomSheet(
      _TaskCompletionSheet(task: task, matricule: matricule, onSuccess: onRefresh),
      isScrollControlled: true,
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    Color color = Colors.grey;
    if (priority == 'high') color = Colors.red;
    if (priority == 'medium') color = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10 * scale),
      ),
    );
  }
}

class _TaskCompletionSheet extends StatefulWidget {
  final Task task;
  final String matricule;
  final VoidCallback onSuccess;

  const _TaskCompletionSheet({required this.task, required this.matricule, required this.onSuccess});

  @override
  State<_TaskCompletionSheet> createState() => _TaskCompletionSheetState();
}

class _TaskCompletionSheetState extends State<_TaskCompletionSheet> {
  final List<int> _selectedSubtasks = [];
  final List<File> _images = [];
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(scale),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24 * scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Sous-tâches effectuées", style: kioskSubtitle(context).copyWith(fontSize: 15 * scale)),
                    SizedBox(height: 12 * scale),
                    ...widget.task.subtasks.map((st) => CheckboxListTile(
                          title: Text(st.title, style: kioskBody(context)),
                          value: st.isCompleted || _selectedSubtasks.contains(st.id),
                          enabled: !st.isCompleted,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) _selectedSubtasks.add(st.id);
                              else _selectedSubtasks.remove(st.id);
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Colors.green,
                        )),
                    SizedBox(height: 24 * scale),
                    Text("Preuves photos", style: kioskSubtitle(context).copyWith(fontSize: 15 * scale)),
                    SizedBox(height: 12 * scale),
                    _buildImagePicker(scale),
                    SizedBox(height: 24 * scale),
                    Text("Notes d'intervention", style: kioskSubtitle(context).copyWith(fontSize: 15 * scale)),
                    SizedBox(height: 12 * scale),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Détails...",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(scale),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double scale) {
    return Padding(
      padding: EdgeInsets.all(20 * scale),
      child: Row(
        children: [
          Text("Mise à jour tâche", style: kioskSubtitle(context)),
          const Spacer(),
          IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32)),
        ],
      ),
    );
  }

  Widget _buildImagePicker(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => showMediaCaptureModal(context, onMediaCaptured: (file) {
            setState(() => _images.add(file));
          }),
          child: Container(
            width: double.infinity,
            height: 100 * scale,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20 * scale),
              border: Border.all(color: Colors.blue.withOpacity(0.2), style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_a_photo_rounded, color: Colors.blue, size: 32),
                SizedBox(height: 4 * scale),
                Text("Prendre une photo", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700, fontSize: 13 * scale)),
              ],
            ),
          ),
        ),
        if (_images.isNotEmpty) ...[
          SizedBox(height: 16 * scale),
          SizedBox(
            height: 80 * scale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => SizedBox(width: 12 * scale),
              itemBuilder: (context, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12 * scale),
                    child: Image.file(_images[index], width: 80 * scale, height: 80 * scale, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 4, top: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.removeAt(index)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(double scale) {
    return Container(
      padding: EdgeInsets.all(24 * scale),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? "Envoi..." : "Valider cette tâche"),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final success = await HttpManager().completeTask(
      taskId: widget.task.id,
      matricule: widget.matricule,
      subtaskIds: _selectedSubtasks,
      images: _images,
      note: _noteController.text,
    );
    if (success) {
      widget.onSuccess();
      Get.back();
    }
    setState(() => _isSubmitting = false);
  }
}
