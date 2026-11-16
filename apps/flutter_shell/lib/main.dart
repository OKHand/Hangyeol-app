import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/demo/demo_app.dart';
import 'src/serverless/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const bool.fromEnvironment('OFFLINE_DEMO')
      ? const OfflineDemoApp()
      : const bool.fromEnvironment('SERVERLESS')
          ? const ServerlessApp(apiUrl:String.fromEnvironment('APPS_SCRIPT_API_URL'))
          : const HangyeolApp());
}
