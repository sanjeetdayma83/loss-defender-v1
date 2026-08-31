import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:loss_defender_v1/main.dart";

void main() {
  testWidgets("app boots", (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LossDefenderApp()));
    await tester.pump();
    expect(find.textContaining("LOSS DEFENDER"), findsWidgets);
  });
}