import '/global/store.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/client.dart';
import '../models/supervisor_data.dart';

class AuthController extends GetxController {
  static AuthController instance = Get.find();
  var userSession = Rxn<Client>();
  var supervisorElements = <ElementModel>[].obs;
  var supervisorSites = <SiteModel>[].obs;
  var selectedSupervisorAgents = <AgentModel>[].obs;
  var isLoading = false.obs;

  Map<int, List<ElementModel>> agentElementsMap = {};
  RxInt selectedAgentId = 0.obs;
  var supervisedAgent = <int>[].obs;
  var pendingSupervisionMap = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    refreshUser();
  }

  Future<Client?> refreshUser() async {
    var userObject = localStorage.read('cache');
    if (userObject != null) {
      userSession.value = Client.fromJson(userObject);
      return userSession.value!;
    } else {
      return null;
    }
  }

  Future<void> refreshPendingSupervisionMap() async {
    var data = localStorage.read("pending_supervision");
    if (data != null) {
      if (kDebugMode) {
        print(data);
      }
      pendingSupervisionMap.value = data as Map<String, dynamic>;
    } else {
      pendingSupervisionMap.value = {};
      agentElementsMap = {};
    }
  }
}
