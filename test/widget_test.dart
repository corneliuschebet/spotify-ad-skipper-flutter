import 'package:flutter_test/flutter_test.dart';

import 'package:spotify_ad_skipper/main.dart';

void main() {
  testWidgets('Spotify Ad Skipper dashboard loads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SpotifyAdSkipperApp());

    expect(find.byType(SpotifyAdSkipperApp), findsOneWidget);

    expect(find.text('Spotify Ad Skipper'), findsOneWidget);
  });
}
