import 'package:flutter_test/flutter_test.dart';
import 'package:live_color_picker/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const LiveColorPickerApp());
    expect(find.byType(LiveColorPickerApp), findsOneWidget);
  });
}
