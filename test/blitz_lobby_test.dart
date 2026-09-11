import 'package:flutter_test/flutter_test.dart';
import 'package:vinerox_mobile/arena/blitz_screen.dart';

void main() {
  test('buildBlitzLobby stays usable when one API call fails', () {
    final lobby = buildBlitzLobby([
      {'cards': [
        {'card_id': 'volatility'},
      ]},
      {'cards': [
        {'id': 'volatility', 'name': 'Volatility'},
      ]},
      {'club_name': 'The Dock'},
    ]);

    expect(lobby.inventory['cards'], hasLength(1));
    expect(lobby.catalog, hasLength(1));
    expect(lobby.profile['club_name'], 'The Dock');
    expect(lobby.ownedCards, hasLength(1));
  });
}
