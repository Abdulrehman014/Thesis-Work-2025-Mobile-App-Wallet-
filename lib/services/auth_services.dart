import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/api_constant.dart';
import '../utils/provider.dart';

class ApiClient {
  static runLoader(bool show, BuildContext context) =>
      Provider.of<DataProviders>(
        context,
        listen: false,
      ).isTrueOrFalseFunctionProgressHUD(show);

  static restrictRunLoader(bool show, BuildContext context) =>
      Provider.of<DataProviders>(
        context,
        listen: false,
      ).isTrueOrFalseFunctionProgressHUD(show);

  static final Dio _dio = Dio();

  /// Logs in and persists the session token and full session data.
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
    BuildContext context,
  ) async {
    final payload = {'type': 'email', 'email': email, 'password': password};
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      runLoader(true, context);

      final response = await _dio.post(
        Api.loginPath,
        data: json.encode(payload),
        options: Options(headers: headers),
      );

      final sessionData = response.data as Map<String, dynamic>;

      // Persist sessionData + token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sessionData', json.encode(sessionData));
      if (sessionData.containsKey('token')) {
        await prefs.setString('token', sessionData['token'] as String);
      }

      restrictRunLoader(false, context);
      return {
        'message': sessionData['message'] ?? 'Logged in',
        'sessionData': sessionData,
      };
    } on DioException catch (e) {
      restrictRunLoader(false, context);
      debugPrint('Login error: ${e.response?.data ?? e.message}');
      return {
        'error': e.response?.data ?? {'message': 'Failed to login'},
      };
    }
  }

  /// Registers a new user (type: "email", name, email, password).
  static Future<Map<String, dynamic>> registerUser(
    String name,
    String email,
    String password,
    BuildContext context,
  ) async {
    final payload = {
      'type': 'email',
      'name': name,
      'email': email,
      'password': password,
    };
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      runLoader(true, context);

      final response = await _dio.post(
        Api.registerPath,
        data: json.encode(payload),
        options: Options(headers: headers),
      );

      final data = response.data as Map<String, dynamic>;

      // Optionally persist returned token/session if present
      final prefs = await SharedPreferences.getInstance();
      if (data.containsKey('userInfo')) {
        await prefs.setString('userInfo', json.encode(data['userInfo']));
      }
      if (data['userInfo'] is Map &&
          (data['userInfo'] as Map).containsKey('token')) {
        await prefs.setString('token', (data['userInfo']['token'] as String));
      }

      restrictRunLoader(false, context);
      return {
        'message': data['message'] ?? 'User registered',
        'userInfo': data['userInfo'],
      };
    } on DioError catch (e) {
      restrictRunLoader(false, context);
      debugPrint('Register error: ${e.response?.data ?? e.message}');
      return {
        'error': e.response?.data ?? {'message': 'Failed to register'},
      };
    }
  }

  /// Fetches wallets using the saved token, persists the first walletId.
  static Future<Map<String, dynamic>> getWallets(BuildContext context) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      restrictRunLoader(false, context);
      return {
        'error': {
          'message': 'No authentication token found. Please login first.',
        },
      };
    }

    try {
      final response = await _dio.get(
        Api.retrieveWalletDetails,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final account = data['account'] as String?;
      final wallets = (data['wallets'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final walletId = wallets.isNotEmpty
          ? wallets.first['id'] as String
          : null;

      if (account == null || walletId == null) {
        restrictRunLoader(false, context);
        return {
          'error': {'message': 'No account or wallets found'},
        };
      }

      // Persist account, first walletId, and full wallets list
      await prefs.setString('account', account);
      await prefs.setString('walletId', walletId);
      await prefs.setString('wallets', json.encode(wallets));

      restrictRunLoader(false, context);
      return {
        'message': 'Wallets retrieved successfully',
        'account': account,
        'walletId': walletId,
        'wallets': wallets,
      };
    } on DioException catch (e) {
      restrictRunLoader(false, context);
      debugPrint('GetWallets error: ${e.response?.data ?? e.message}');
      return {
        'error': e.response?.data ?? {'message': 'Failed to get wallets'},
      };
    }
  }

  /// Logs out and clears the stored token
  static Future<Map<String, dynamic>> logOut(BuildContext context) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await _dio.post(
        Api.logOutPath,
        options: Options(headers: headers),
      );

      // Always clear stored session, even if the network call fails below
      await prefs.remove('token');
      await prefs.remove('sessionData');
      await prefs.remove('walletId');

      restrictRunLoader(false, context);

      final data = response.data;
      // If API returned JSON object, return it directly; otherwise wrap string
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        return {'message': data?.toString() ?? 'Logged out successfully'};
      }
    } on DioException catch (e) {
      restrictRunLoader(false, context);
      debugPrint('Logout error: ${e.response?.data ?? e.message}');
      // Clear session data even on error, to avoid locking user out
      await prefs.remove('token');
      await prefs.remove('sessionData');
      await prefs.remove('walletId');
      final errData = e.response?.data;
      if (errData is Map<String, dynamic>) {
        return {'error': errData};
      } else {
        return {
          'error': {'message': errData?.toString() ?? 'Failed to logout'},
        };
      }
    }
  }

  /// Accepts a credential offer by sending its URL to the wallet exchange endpoint.
  static Future<Map<String, dynamic>> acceptCredential(
    String credentialOfferUrl,
    BuildContext context,
  ) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');
    final walletId = prefs.getString('walletId');

    if (token == null ||
        token.isEmpty ||
        walletId == null ||
        walletId.isEmpty) {
      restrictRunLoader(false, context);
      return {
        'error': {
          'message':
              'Missing authentication token or walletId. Please login and retrieve wallets first.',
        },
      };
    }

    try {
      final response = await _dio.post(
        '${Api.baseUrl}/wallet-api/wallet/$walletId/exchange/useOfferRequest',
        // send the raw string
        data: credentialOfferUrl,
        options: Options(
          headers: {
            'Content-Type': 'text/plain',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final credentialData = response.data;

      restrictRunLoader(false, context);
      return {
        'message': 'Credential successfully accepted & stored in wallet',
        'credential': credentialData,
      };
    } on DioException catch (e) {
      restrictRunLoader(false, context);
      debugPrint('AcceptCredential error: ${e.response?.data ?? e.message}');
      return {
        'error':
            e.response?.data ??
            {'message': 'Failed to accept credential offer'},
      };
    }
  }

  /*static Future<Map<String, dynamic>> getCredentials(
    BuildContext context,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final walletId = prefs.getString('walletId');

    print('getCredentials called with:');
    print(' - walletId: $walletId');
    print(
      ' - token: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
    );

    try {
      var timestamp = DateTime.now().millisecondsSinceEpoch;
      final url =
          '${Api.baseUrl}/wallet-api/wallet/$walletId/credentials?cacheBuster=$timestamp';
      print(' - full URL: $url');
      final payload = {'showDeleted': 'false', 'sortBy': 'addedOn'};
      final response = await _dio.get(
        data: json.encode(payload),
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ),
      );

      print(' - response status: ${response.statusCode}');
      return {'credentials': response.data};
    } on DioException catch (e) {
      print(' - error: ${e.message}');
      if (e.response != null) {
        print(' - error response status: ${e.response!.statusCode}');
        print(' - error response data: ${e.response!.data}');
      }
      return {
        'error': e.response?.data ?? {'message': 'Failed to fetch credentials'},
      };
    }
  }*/

  static Future<Map<String, dynamic>> getCredentials(
    BuildContext context,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final walletId = prefs.getString('walletId');

    print('getCredentials called with:');
    print(' - walletId: $walletId');
    print(
      ' - token: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
    );

    try {
      var timestamp = DateTime.now().millisecondsSinceEpoch;

      final url =
          '${Api.baseUrl}/wallet-api/wallet/$walletId/credentials?cacheBuster=$timestamp&showDeleted=false';

      print(' - full URL: $url');

      // Perform GET request with URL and headers
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ),
      );

      print(' - response status: ${response.statusCode}');
      return {'credentials': response.data};
    } on DioException catch (e) {
      print(' - error: ${e.message}');
      if (e.response != null) {
        print(' - error response status: ${e.response!.statusCode}');
        print(' - error response data: ${e.response!.data}');
      }
      return {
        'error': e.response?.data ?? {'message': 'Failed to fetch credentials'},
      };
    }
  }

  /// Deletes a single credential by its ID.
  static Future<Map<String, dynamic>> deleteCredential(
    String credentialId,
    BuildContext context,
  ) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final walletId = prefs.getString('walletId');

    if (token == null ||
        token.isEmpty ||
        walletId == null ||
        walletId.isEmpty) {
      restrictRunLoader(false, context);
      return {
        'error': {
          'message':
              'Missing auth token or walletId. Please login & fetch wallets first.',
        },
      };
    }

    try {
      final payload = {'permanent': 'true'};

      final response = await _dio.delete(
        '${Api.baseUrl}/wallet-api/wallet/$walletId/credentials/$credentialId',
        data: json.encode(payload),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      restrictRunLoader(false, context);
      return {
        'message': 'Credential deleted successfully',
        'deleted': response.data,
      };
    } on DioException catch (e) {
      restrictRunLoader(false, context);
      debugPrint('DeleteCredential error: ${e.response?.data ?? e.message}');
      print('DeleteCredential error: ${e.response?.data ?? e.message}');
      return {
        'error': e.response?.data ?? {'message': 'Failed to delete credential'},
      };
    }
  }

  /// 01 - Step Finds all credentials in the current wallet matching the given presentation definition.
  static Future<Map<String, dynamic>> matchCredentialsForPresentationDefinition(
    Map<String, dynamic> presentationDefinition,
    BuildContext context,
  ) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final walletId = prefs.getString('walletId');

    if (token == null ||
        token.isEmpty ||
        walletId == null ||
        walletId.isEmpty) {
      restrictRunLoader(false, context);
      return {
        'error': {
          'message':
              'Missing auth token or walletId. Please login & fetch wallets first.',
        },
      };
    }

    try {
      final response = await _dio.post(
        '${Api.baseUrl}/wallet-api/wallet/$walletId/exchange/matchCredentialsForPresentationDefinition',
        data: presentationDefinition,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      restrictRunLoader(false, context);
      return {
        'message': 'Matching credentials retrieved successfully',
        'credentials':
            response.data, // this will be a List of credential objects
      };
    } on DioException catch (e) {
      restrictRunLoader(false, context);
      debugPrint('MatchCredentials error: ${e.response?.data ?? e.message}');
      return {
        'error': e.response?.data ?? {'message': 'Failed to match credentials'},
      };
    }
  }

  /// Resolves (parses) an incoming OIDC-4-VP presentation request URI.
  static Future<Map<String, dynamic>> resolvePresentationRequest(
    String presentationRequestUri,
    BuildContext context,
  ) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final walletId = prefs.getString('walletId');

    if (token == null ||
        token.isEmpty ||
        walletId == null ||
        walletId.isEmpty) {
      restrictRunLoader(false, context);
      return {
        'error': {
          'message':
              'Missing auth token or walletId. Please login & fetch wallets first.',
        },
      };
    }

    try {
      final response = await _dio.post(
        '${Api.baseUrl}/wallet-api/wallet/$walletId/exchange/resolvePresentationRequest',
        // send the raw URI string
        data: presentationRequestUri,
        options: Options(
          headers: {
            'Content-Type': 'text/plain',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      restrictRunLoader(false, context);
      return {
        'message': 'Presentation request resolved successfully',
        'presentationRequest': response.data,
      };
    } on DioException catch (e) {
      restrictRunLoader(false, context);
      debugPrint(
        'ResolvePresentationRequest error: ${e.response?.data ?? e.message}',
      );
      return {
        'error':
            e.response?.data ??
            {'message': 'Failed to resolve presentation request'},
      };
    }
  }

  /// Submits a resolved presentation request along with the selected credential IDs.
  static Future<Map<String, dynamic>> usePresentationRequest({
    required String presentationRequest,
    required List<String> selectedCredentials,
    Map<String, List<String>>? disclosures,
    String? note,
    required BuildContext context,
  }) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final walletId = prefs.getString('walletId');

    if (token == null ||
        token.isEmpty ||
        walletId == null ||
        walletId.isEmpty) {
      restrictRunLoader(false, context);
      return {
        'error': {
          'message':
              'Missing auth token or walletId. Please login & fetch wallets first.',
        },
      };
    }

    // Build the request body exactly to your spec
    final body = <String, dynamic>{
      'presentationRequest': presentationRequest,
      'selectedCredentials': selectedCredentials,
      if (disclosures != null) 'disclosures': disclosures,
      if (note != null) 'note': note,
    };

    try {
      final response = await _dio.post(
        '${Api.baseUrl}/wallet-api/wallet/$walletId/exchange/usePresentationRequest',
        data: body, // Dio will JSON-encode this map
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      restrictRunLoader(false, context);
      return {
        'message': 'Presentation submitted successfully',
        'response': response.data, // often contains redirectUri etc.
      };
    } on DioError catch (e) {
      restrictRunLoader(false, context);
      debugPrint(
        'UsePresentationRequest error: ${e.response?.data ?? e.message}',
      );
      return {
        'error':
            e.response?.data ?? {'message': 'Failed to submit presentation'},
      };
    }
  }

  /// Starts a new OpenID4VCI verification flow:
  /// 1. POST /openid4vc/verify
  /// 2. Extracts `state` and `presentation_definition_uri`
  /// 3. GETs the presentation definition JSON
  /// Returns a map with:
  ///   - authorizationRequestUrl
  ///   - state
  ///   - presentationDefinitionUri
  ///   - presentationDefinition (the decoded JSON)
  static Future<Map<String, dynamic>> initiateVerification({
    required String credentialType,
    required BuildContext context,
  }) async {
    runLoader(true, context);
    try {
      // 1) ask the verifier for an OIDC4VP flow URL
      final verifyRes = await _dio.post(
        '${Api.baseUrl}/openid4vc/verify',
        data: {
          'request_credentials': [
            {'format': 'jwt_vc_json', 'type': credentialType},
          ],
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // the verifier returns a URL like "openid4vp://authorize?...&state=XYZ&presentation_definition_uri=..."
      final authorizationRequestUrl = verifyRes.data as String;

      // 2) parse out state & presentation_definition_uri
      final uri = Uri.parse(authorizationRequestUrl);
      final state = uri.queryParameters['state'] ?? '';
      final pdEncoded =
          uri.queryParameters['presentation_definition_uri'] ?? '';
      final presentationDefinitionUri = Uri.decodeComponent(pdEncoded);

      // 3) fetch the actual JSON of that presentation definition
      final pdRes = await _dio.get(presentationDefinitionUri);
      final presentationDefinition = pdRes.data;

      runLoader(false, context);
      return {
        'authorizationRequestUrl': authorizationRequestUrl,
        'state': state,
        'presentationDefinitionUri': presentationDefinitionUri,
        'presentationDefinition': presentationDefinition,
      };
    } on DioException catch (e) {
      runLoader(false, context);
      debugPrint(
        'initiateVerification error: ${e.response?.data ?? e.message}',
      );
      return {
        'error':
            e.response?.data ?? {'message': 'Failed to initiate verification'},
      };
    }
  }

  /// Fetches the verification session details for a given state ID.
  /// Returns a map containing `sessionDetails` on success, or `error`.
  /*  static Future<Map<String, dynamic>> getVerificationSession({
    required String stateId,
    required BuildContext context,
  }) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      runLoader(false, context);
      return {
        'error': {
          'message': 'No authentication token found. Please login first.',
        },
      };
    }

    try {
      final response = await _dio.get(
        '${Api.baseUrl}/openid4vc/session/$stateId',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      runLoader(false, context);
      return {
        'message': 'Session retrieved successfully',
        'sessionDetails': response.data,
      };
    } on DioError catch (e) {
      runLoader(false, context);
      debugPrint(
        'getVerificationSession error: ${e.response?.data ?? e.message}',
      );
      return {
        'error': e.response?.data ?? {'message': 'Failed to retrieve session'},
      };
    }
  }*/

  /// Returns a map containing `sessionDetails` on success, or `error`.
  static Future<Map<String, dynamic>> getVerificationSession({
    required String stateId,

    required BuildContext context,
  }) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      runLoader(false, context);
      return {
        'error': {
          'message': 'No authentication token found. Please login first.',
        },
      };
    }

    try {
      final response = await _dio.get(
        'https://verifier.demo.walt.id/openid4vc/session/$stateId',
        options: Options(
          headers: {
            'Accept': 'application/json',
            // 'Authorization': 'Bearer $token',
          },
          // Force response to be treated as plain text first
          responseType: ResponseType.plain,
        ),
      );

      // First try to parse as JSON
      try {
        final jsonData = jsonDecode(response.data);
        runLoader(false, context);
        return {
          'message': 'Session retrieved successfully',
          'sessionDetails': jsonData,
        };
      } catch (e) {
        // If JSON parsing fails, check if it's HTML
        if (response.data is String &&
            (response.data as String).contains('<html')) {
          runLoader(false, context);
          return {
            'error': {
              'message':
                  'Server returned HTML content. Please check the endpoint URL.',
            },
          };
        }
        // If not HTML, try to return the raw data
        runLoader(false, context);
        return {
          'message': 'Received non-JSON response',
          'sessionDetails': response.data,
        };
      }
    } on DioException catch (e) {
      runLoader(false, context);
      debugPrint(
        'getVerificationSession error: ${e.response?.data ?? e.message}',
      );

      // Handle HTML error responses
      if (e.response != null &&
          e.response!.data is String &&
          (e.response!.data as String).contains('<html')) {
        return {
          'error': {'message': 'Server error: Received HTML response'},
        };
      }

      return {
        'error': e.response?.data ?? {'message': 'Failed to retrieve session'},
      };
    }
  }

  /// Fetches the status of a credential by its ID in a specific wallet.
  static Future<Map<String, dynamic>> getCredentialStatus({
    required String walletId,
    required String credentialId,
    required BuildContext context,
  }) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      restrictRunLoader(false, context);
      return {
        'error': {
          'message': 'No authentication token found. Please login first.',
        },
      };
    }

    try {
      final response = await _dio.get(
        '${Api.baseUrl}/wallet-api/wallet/$walletId/credentials/$credentialId/status',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      restrictRunLoader(false, context);
      return {
        'message': 'Credential status retrieved successfully',
        'status': response.data,
      };
    } on DioException catch (e) {
      restrictRunLoader(false, context);
      debugPrint('getCredentialStatus error: ${e.response?.data ?? e.message}');
      return {
        'error':
            e.response?.data ??
            {'message': 'Failed to fetch credential status'},
      };
    }
  }

  /// Fetches all DIDs for a given wallet.
  static Future<Map<String, dynamic>> getWalletDIDs({
    required String walletId,
    required BuildContext context,
  }) async {
    runLoader(true, context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      restrictRunLoader(false, context);
      return {
        'error': {
          'message': 'No authentication token found. Please login first.',
        },
      };
    }

    try {
      final response = await _dio.get(
        '${Api.baseUrl}/wallet-api/wallet/$walletId/dids',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      restrictRunLoader(false, context);
      return {'message': 'DIDs retrieved successfully', 'dids': response.data};
    } on DioException catch (e) {
      restrictRunLoader(false, context);
      debugPrint('getWalletDIDs error: ${e.response?.data ?? e.message}');
      return {
        'error': e.response?.data ?? {'message': 'Failed to fetch wallet DIDs'},
      };
    }
  }
}
