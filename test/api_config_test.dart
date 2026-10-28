import 'package:chegher_1/core/network/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authentication endpoint uses the live HTTPS API by default', () {
    expect(
      ApiConfig.uri('/auth/login/').toString(),
      'https://chagher.ir/api/auth/login/',
    );
  });

  test('absolute HTTPS media URLs remain unchanged', () {
    const mediaUrl = 'https://chagher.ir/media/exercise_library/0001.gif';

    expect(ApiConfig.resolveMediaUrl(mediaUrl), mediaUrl);
  });

  test('same-host HTTP media URLs are upgraded to HTTPS', () {
    expect(
      ApiConfig.resolveMediaUrl('http://chagher.ir/media/gym/logo.jpg'),
      'https://chagher.ir/media/gym/logo.jpg',
    );
  });

  test('relative media URLs use the live server origin', () {
    expect(
      ApiConfig.resolveMediaUrl('/media/exercise_library/0001.gif'),
      'https://chagher.ir/media/exercise_library/0001.gif',
    );
  });
}
