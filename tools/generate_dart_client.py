#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path
from typing import Any

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = REPOSITORY_ROOT / "contracts" / "openapi" / "letter-api.json"
CLIENT_PATH = (
    REPOSITORY_ROOT
    / "apps"
    / "mobile"
    / "lib"
    / "api"
    / "generated"
    / "letter_api_client.dart"
)

CLIENT_TEMPLATE = """// GENERATED CODE - DO NOT MODIFY BY HAND.
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
"""


def _validate_contract(contract: dict[str, Any]) -> None:
    status_operation = contract.get("paths", {}).get("/v1/status", {}).get("get")
    schemas = contract.get("components", {}).get("schemas", {})
    if status_operation is None or "StatusResponse" not in schemas:
        raise ValueError(
            "Contract must expose GET /v1/status with StatusResponse before generation"
        )


def render_client() -> str:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    _validate_contract(contract)
    return CLIENT_TEMPLATE


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail instead of writing when the committed client is stale.",
    )
    args = parser.parse_args()
    rendered = render_client()

    if args.check:
        if not CLIENT_PATH.exists() or CLIENT_PATH.read_text() != rendered:
            print(
                "Generated Dart client is stale. Run tools/generate_dart_client.py.",
                file=sys.stderr,
            )
            return 1
        return 0

    CLIENT_PATH.parent.mkdir(parents=True, exist_ok=True)
    CLIENT_PATH.write_text(rendered, encoding="utf-8")
    print(f"Wrote {CLIENT_PATH.relative_to(REPOSITORY_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
