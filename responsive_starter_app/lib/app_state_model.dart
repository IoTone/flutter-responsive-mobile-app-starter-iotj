import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppState extends ChangeNotifier {
  static late PackageInfo packageInfo;
  static String appversion = "UNKNOWN";
  static String fullappname = "UNKNOWN";

  AppState() {
    initAppInfo();
  }

  Future<void> initAppInfo() async {
    packageInfo = await PackageInfo.fromPlatform();

    String appName = packageInfo.appName;
    String packageName = packageInfo.packageName;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;
    appversion = version + "." + buildNumber;
    fullappname = appName + appversion;
  }

  //
  // This will send you to the active_screen
  // if it has changed
  void changeToNewScreen() {
    notifyListeners();
  }

  String getAppVersion() {
    return appversion;
  }

  String getAppName() {
    return fullappname;
  }
}
