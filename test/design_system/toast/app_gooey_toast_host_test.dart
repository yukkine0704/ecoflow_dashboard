import 'package:ecoflow_dashboard/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    appGooeyToast.dismissAll();
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: AppGooeyToasterHost(
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('expands only when tapping leader toast', (tester) async {
    await pumpHost(tester);

    appGooeyToast.show(
      'Leader',
      config: const AppToastConfig(description: 'Leader body'),
    );
    appGooeyToast.show(
      'Second',
      config: const AppToastConfig(description: 'Second body'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second body'), findsNothing);

    await tester.tap(find.text('Second').first);
    await tester.pumpAndSettle();

    expect(find.text('Second body'), findsOneWidget);
  });

  testWidgets('swipe dismiss requires dynamic threshold', (tester) async {
    await pumpHost(tester);

    appGooeyToast.show('Swipe me');
    await tester.pumpAndSettle();

    final toastTitle = find.text('Swipe me').first;
    await tester.drag(toastTitle, const Offset(30, 0));
    await tester.pumpAndSettle();

    expect(find.text('Swipe me'), findsOneWidget);

    await tester.drag(toastTitle, const Offset(420, 0));
    await tester.pumpAndSettle();

    expect(find.text('Swipe me'), findsNothing);
  });

  testWidgets('pauses auto-dismiss while stack is expanded', (tester) async {
    await pumpHost(tester);

    appGooeyToast.show(
      'Timer leader',
      config: const AppToastConfig(
        description: 'Body',
        duration: Duration(milliseconds: 600),
      ),
    );
    appGooeyToast.show(
      'Timer second',
      config: const AppToastConfig(
        description: 'Second body',
        duration: Duration(milliseconds: 600),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Timer second').first);
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Timer second'), findsOneWidget);

    await tester.tap(find.text('Timer second').first);
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Timer second'), findsNothing);
  });

  testWidgets('renders spread body layout meta and description', (
    tester,
  ) async {
    await pumpHost(tester);

    appGooeyToast.show(
      'Layout',
      config: const AppToastConfig(
        description: 'Description text',
        meta: 'META',
        bodyLayout: AppToastBodyLayout.spread,
      ),
    );
    appGooeyToast.show('Expand leader');

    await tester.pumpAndSettle();
    await tester.tap(find.text('Expand leader').first);
    await tester.pumpAndSettle();

    expect(find.text('Description text'), findsOneWidget);
    expect(find.text('META'), findsOneWidget);
  });
}
