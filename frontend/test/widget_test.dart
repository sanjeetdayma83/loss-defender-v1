import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:loss_defender_v1/core/router/app_root.dart";

void main() {
  testWidgets("Loss Defender app boots", (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AppRoot(),
      ),
    );

    await tester.pumpAndSettle(
      const Duration(seconds: 2),
    );

    expect(
      find.textContaining("LOSS DEFENDER"),
      findsWidgets,
    );
  });
}