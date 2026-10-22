import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages.dart';
import 'sound.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Store.init();
  Snd.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Store.dark,
      builder: (_, dark, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Neon Arcade',
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF6200EA),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFD6E4FF)),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF00F0FF),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF16103F)),
        ),
        home: const HomePage(),
      ),
    );
  }
}
