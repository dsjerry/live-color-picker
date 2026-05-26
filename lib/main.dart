import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'providers/locale_provider.dart';
import 'generated/app_localizations.dart';
import 'screens/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final localeProvider = LocaleProvider();
  await localeProvider.load();

  runApp(LiveColorPickerApp(localeProvider: localeProvider));
}

class LiveColorPickerApp extends StatefulWidget {
  final LocaleProvider localeProvider;

  const LiveColorPickerApp({super.key, required this.localeProvider});

  @override
  State<LiveColorPickerApp> createState() => _LiveColorPickerAppState();
}

class _LiveColorPickerAppState extends State<LiveColorPickerApp> {
  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      notifier: widget.localeProvider,
      child: ListenableBuilder(
        listenable: widget.localeProvider,
        builder: (context, _) {
          return MaterialApp(
            locale: widget.localeProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
            ),
            home: const CameraScreen(),
          );
        },
      ),
    );
  }
}
