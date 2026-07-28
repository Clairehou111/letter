import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_mobile/api/generated/letter_api_client.dart';

void main() {
  test('generated client parses the operational status contract', () async {
    final transport = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/status');
      return http.Response(
        '{"status":"ok","service":"letter-api","api_version":"0.1.0"}',
        200,
        request: request,
      );
    });
    final client = LetterApiClient(
      baseUri: Uri.parse('https://api.example.test'),
      httpClient: transport,
    );

    final status = await client.getStatus();

    expect(status.status, 'ok');
    expect(status.service, 'letter-api');
    expect(status.apiVersion, '0.1.0');
    client.close();
  });
}
