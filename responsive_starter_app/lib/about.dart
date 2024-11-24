import 'dart:async';

import 'package:flutter/material.dart';
import 'package:responsive_starter_app/app_state_model.dart';
import 'package:provider/provider.dart';
// import 'package:easter_egg_trigger/easter_egg_trigger.dart';


class AboutPageWidget extends StatefulWidget {
  const AboutPageWidget({super.key});

  @override
  State<AboutPageWidget> createState() => _AboutPageWidgetState();
}

class _AboutPageWidgetState extends State<AboutPageWidget> {
  // Then call the async function in initState with then
  String appversion = "UNKNOWN";
  String appname = "UNKNOWN";
  @override
  void initState() {
    super.initState();

    final appState = Provider.of<AppState>(context, listen: false);
    
    appState.initAppInfo().then((_) {
        appversion = appState.getAppVersion();
        appname = appState.getAppName();
        setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    
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
          children: [
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
                // appState.app_screen = "terms";

                // Navigator.of(context).push(
                //   MaterialPageRoute(
                //     builder: (context) => const AboutPageWidget(),
                //   ),
                // );
                
              },
            )
          ],
        ),
      ),
        body: Center(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[       
            // Image(image: AssetImage('assets/images/halo_headset_b.png')),
            Text('App v${appversion}  \nCopyright IoTone Japan 2024', textAlign: TextAlign.center ,style: TextStyle(color: Color(0xFF1B68AF),
                    fontSize: 28, 
            ),
           )
          ],
        ),
      ),
    );
  }
}