// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: contracts/openapi/letter-api.json

import 'dart:convert';

import 'package:http/http.dart' as http;

final class StatusResponse {
  const StatusResponse({
    required this.status,
    required this.service,
    required this.apiVersion,
  });

  factory StatusResponse.fromJson(Map<String, Object?> json) {
    return StatusResponse(
      status: json['status']! as String,
      service: json['service']! as String,
      apiVersion: json['api_version']! as String,
    );
  }

  final String status;
  final String service;
  final String apiVersion;
}

final class LetterApiClient {
  LetterApiClient({required this.baseUri, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final Uri baseUri;
  final http.Client _httpClient;

  Future<StatusResponse> getStatus() async {
    final response = await _httpClient.get(baseUri.resolve('/v1/status'));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Letter API status request failed with ${response.statusCode}.',
        response.request?.url,
      );
    }
    final payload = jsonDecode(response.body) as Map<String, Object?>;
    return StatusResponse.fromJson(payload);
  }

  void close() => _httpClient.close();
}
