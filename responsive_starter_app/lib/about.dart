// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:meshmore_sns_app/app_state_model.dart';
import 'package:provider/provider.dart';

class AboutPageWidget extends StatefulWidget {
  const AboutPageWidget({super.key});

  @override
  State<AboutPageWidget> createState() => _AboutPageWidgetState();
}

class _AboutPageWidgetState extends State<AboutPageWidget> {
  String appversion = 'UNKNOWN';
  String appname = 'UNKNOWN';

  @override
  void initState() {
    super.initState();
    final AppState appState = Provider.of<AppState>(context, listen: false);
    appState.initAppInfo().then((_) {
      if (!mounted) return;
      setState(() {
        appversion = appState.getAppVersion();
        appname = appState.getAppName();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4bb0c9),
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 80,
        backgroundColor: const Color(0xFF4bb0c9),
        title: Image.asset('assets/images/icon-192.png'),
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            ListTile(
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/');
              },
            ),
            ListTile(
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              title: const Text('Terms'),
              onTap: () {
                Navigator.pop(context);
                // TODO(meshmore): wire up Terms route.
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Text(
              'App v$appversion\nCopyright IoTone Japan 2026',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1B68AF),
                fontSize: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}