import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:responsive_toolkit/responsive_toolkit.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:responsive_starter_app/about.dart';
import 'package:provider/provider.dart';
import 'package:responsive_starter_app/app_state_model.dart';
import 'package:responsive_starter_app/router.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // runApp(MyApp());
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((value) {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AppState()),
        ],
        child: const MaterialApp(
          home: MyApp(), // make this const
          initialRoute: '/',
          onGenerateRoute: RouterClass.generateRoute,
        ),
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // This is needed to help above initialization

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Responsive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Responsive Mobile App Starter'),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                child: Text('Responsive Menu'),
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
              ),
              ListTile(
                leading: Icon(Icons.abc_rounded),
                title: Text('About'),
                onTap: () {
                  // Update the state of the app
                  // Then close the drawer
                  
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/about');
                  /* Navigator.push(context, new MaterialPageRoute(
                    builder: (context) => new AboutPageWidget())
                  ); */
                },
              ),
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                onTap: () {
                  // Update the state of the app
                  // Then close the drawer
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ],
          ),
        ),
        body: Center(
          child: MyHomePage(),
        ),
      ),
      /*
      initialRoute: '/',
      onGenerateRoute: RouterClass.generateRoute,
      */
      /*
      routes: {
        '/home': (context) => MyHomePage(),
        '/about': (context) => AboutPageWidget()
        // '/about': (context) => AboutPage(),
        // '/settings': (context) => SettingsPage(),
        // Add other routes here
      },
      */
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key});

  @override
  State<StatefulWidget> createState() => _MyHomePageWidgetState();
}

class _MyHomePageWidgetState extends State<MyHomePage> {
  @override
  State<StatefulWidget> createState() => _MyHomePageWidgetState();

  @override
  void initState() {
    super.initState();
    initialization();
  }

  void initialization() async {
    // This is where you can initialize the resources needed by your app while
    // the splash screen is displayed.  Remove the following example because
    // delaying the user experience is a bad design practice!
    // ignore_for_file: avoid_print
    print('ready in 3...');
    await Future.delayed(const Duration(seconds: 1));
    print('ready in 2...');
    await Future.delayed(const Duration(seconds: 1));
    print('ready in 1...');
    await Future.delayed(const Duration(seconds: 1));
    print('go!');
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    Widget container(
            {Color? color,
            Widget? child,
            String? text,
            double? width,
            double? height}) =>
        Container(
          height: 50,
          width: width,
          decoration: BoxDecoration(
              color: color ?? Colors.blueGrey[100],
              border: Border.all(color: Colors.blueGrey.shade600)),
          child: child ?? (text == null ? null : Center(child: Text(text))),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Responsive'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('FluidText',
                    style:
                        TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FluidText(
                    'This text scales from 16 to 36 font size between 375-1024 pixel screen width.',
                    minFontSize: 16,
                    maxFontSize: 36,
                    minWidth: 375,
                    maxWidth: 1024,
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 48.0),
                child: FluidText.rich(
                  TextSpan(
                    text: 'This rich text',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      const TextSpan(
                        text: ' scales in the',
                        style: const TextStyle(color: Colors.blue),
                      ),
                      const TextSpan(
                        text: ' same way',
                        style: const TextStyle(fontWeight: FontWeight.w100),
                      ),
                    ],
                  ),
                  minFontSize: 16,
                  maxFontSize: 36,
                  minWidth: 375,
                  maxWidth: 1024,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('Responsive layout',
                    style:
                        TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('ResponsiveLayout widget',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                    'Change widget based on breakpoint. Swap individual widgets all the way to entire page layouts based on screen size.'),
              ),
              Container(
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ResponsiveLayout(Breakpoints(
                  xs: ElevatedButton(
                      onPressed: () {}, child: Text('Elevated button on xs')),
                  md: TextButton(
                      onPressed: () {}, child: Text('Text button on md+')),
                )),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('ResponsiveLayout.value utility',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('Change any value based on breakpoint'),
              ),
              Container(
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(bottom: 48.0),
                child: ElevatedButton.icon(
                  label: Text('Button icon changes'),
                  onPressed: () {},
                  icon: Icon(
                    ResponsiveLayout.value(
                      context,
                      Breakpoints(
                        xs: Icons.access_alarm_outlined,
                        sm: Icons.add_circle_outline_outlined,
                        md: Icons.accessible_forward_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('Responsive grid',
                    style:
                        TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('Column layout reference',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              GridLines(
                children: [
                  ResponsiveRow(
                    columns: List.generate(
                        12,
                        (i) => ResponsiveColumn.span(
                            span: 1, child: container(text: 'Span 1'))),
                  ),
                  ...List.generate(
                    6,
                    (i) => ResponsiveRow(
                      columns: [
                        ResponsiveColumn.span(
                            span: i + 1,
                            child: container(text: 'Span ${i + 1}')),
                        ResponsiveColumn.span(
                            span: 11 - i,
                            child: container(text: 'Span ${11 - i}'))
                      ],
                    ),
                  ),
                  ResponsiveRow(
                    columns: [
                      ResponsiveColumn.span(
                          span: 3,
                          offset: 1,
                          child: container(text: 'Span 3, Offset 1')),
                      ResponsiveColumn.span(
                          span: 3,
                          offset: 3,
                          child: container(text: 'Span 3, Offset 3')),
                    ],
                  ),
                  ResponsiveRow(
                    columns: [
                      ResponsiveColumn.span(
                          span: 4, child: container(text: 'Span 4')),
                      ResponsiveColumn.span(
                          span: 4, child: container(text: 'Span 4')),
                      ResponsiveColumn.span(
                          span: 5, child: container(text: 'Span 5 Wraps')),
                    ],
                  ),
                  ResponsiveRow(
                    columns: [
                      ResponsiveColumn.auto(
                          child: container(
                              child: Center(
                                  widthFactor: 1.3,
                                  child: Text('Auto column')))),
                      ResponsiveColumn.fill(
                          child: container(text: 'Fill column')),
                    ],
                  ),
                  ResponsiveRow(
                    columns: [
                      ResponsiveColumn.fill(
                          child: container(text: 'Fill column')),
                      ResponsiveColumn.fill(
                          child: container(text: 'Fill column')),
                      ResponsiveColumn.fill(
                          child: container(text: 'Fill column')),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('Using breakpoints',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child:
                    Text('1 (xs), 2 (md), 3 (lg), 4 (xl) equal-width columns'),
              ),
              Builder(
                builder: (context) {
                  final span = ResponsiveLayout.value(
                      context, Breakpoints(xs: 12, md: 6, lg: 4, xl: 3));
                  return GridLines(
                    children: [
                      ResponsiveRow(
                        columns: List.generate(
                          4,
                          (i) => ResponsiveColumn.span(
                            span: span,
                            child: container(text: 'Span $span'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('Changing order (column 4 moves to front >md)'),
              ),
              Builder(
                builder: (context) {
                  final order = ResponsiveLayout.value(
                      context, Breakpoints(xs: 2, md: 0));
                  return GridLines(
                    children: [
                      ResponsiveRow(
                        columns: [
                          ...List.generate(
                            3,
                            (i) => ResponsiveColumn.span(
                              span: 3,
                              order: 1,
                              child:
                                  container(text: 'Column ${i + 1}, Order 1'),
                            ),
                          ),
                          ResponsiveColumn.span(
                            span: 3,
                            order: order,
                            child: container(
                                text: 'Column 4, Order $order',
                                color: Colors.blue[200]),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('Control multiple properties with breakpoints'),
              ),
              Builder(
                builder: (context) {
                  return GridLines(
                    children: [
                      ResponsiveRow(
                        columns: [
                          ResponsiveColumn(
                            Breakpoints(
                              xs: ResponsiveColumnConfig(
                                span: 3,
                                offset: 4,
                              ),
                              md: ResponsiveColumnConfig(
                                span: 6,
                                offset: 0,
                                order: 2,
                              ),
                            ),
                            child: container(
                              color: Colors.blue[200],
                              child: Center(
                                child: ResponsiveLayout(
                                  Breakpoints(
                                    xs: Text('xs: Span 3, Offset 4'),
                                    md: Text('md: Span 6, Offset 0, Order 2'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ResponsiveColumn.span(
                              span: 2,
                              order: 1,
                              child: container(text: 'Span 2, Order 1')),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GridLines extends StatelessWidget {
  final List<Widget> children;

  const GridLines({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => ResponsiveRow(
                columns: List.generate(
                  12,
                  (i) => ResponsiveColumn.span(
                    span: 1,
                    child: Container(
                      height: constraints.maxHeight,
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          end: BorderSide(color: Colors.blue.shade200),
                          start: i == 0
                              ? BorderSide(color: Colors.blue.shade200)
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
                .map(
                  (c) => Padding(
                    padding: EdgeInsets.only(
                        bottom: c == children.last ? 0.0 : 16.0),
                    child: c,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
