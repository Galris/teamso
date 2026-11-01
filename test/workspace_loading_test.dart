import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamup_app/widgets/app_widgets.dart';

void main() {
  testWidgets('Workspace loading skeleton fits inside its scrolling page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              Text('Workspace'),
              SkeletonList(count: 3, itemHeight: 120),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(SkeletonBox), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
