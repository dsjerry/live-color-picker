import 'package:flutter_test/flutter_test.dart';
import 'package:live_color_picker/main.dart';
import 'package:live_color_picker/providers/locale_provider.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    final lp = LocaleProvider();
    await tester.pumpWidget(LiveColorPickerApp(localeProvider: lp));
    expect(find.byType(LiveColorPickerApp), findsOneWidget);
  });
}
