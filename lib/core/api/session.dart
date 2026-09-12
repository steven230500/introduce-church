import 'package:equatable/equatable.dart';

/// The signed-in operator.
class AuthUser extends Equatable {
  const AuthUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['display_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
  };

  @override
  List<Object?> get props => [id, email, displayName];
}

/// A session as the API hands it back.
///
/// The access token is short lived and the refresh token is single use: the
/// server revokes it the moment it is redeemed, so a stolen one works once and
/// the theft surfaces as a failed refresh for the real operator.
class Session extends Equatable {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.expiresAt,
    this.orgId,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final DateTime expiresAt;
  final String? orgId;

  bool get hasOrg => orgId != null && orgId!.isNotEmpty;

  /// True shortly before the real expiry, so a request in flight does not
  /// arrive with a token that died on the way.
  bool get isExpiring =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  factory Session.fromResponse(Map<String, dynamic> json) {
    final expiresIn = json['expires_in'] as int? ?? 900;
    return Session(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      orgId: (json['org_id'] as String?)?.isEmpty ?? true
          ? null
          : json['org_id'] as String,
    );
  }

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    expiresAt: DateTime.parse(json['expires_at'] as String),
    orgId: json['org_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'user': user.toJson(),
    'expires_at': expiresAt.toIso8601String(),
    'org_id': orgId,
  };

  Session copyWith({String? orgId}) => Session(
    accessToken: accessToken,
    refreshToken: refreshToken,
    user: user,
    expiresAt: expiresAt,
    orgId: orgId ?? this.orgId,
  );

  @override
  List<Object?> get props => [accessToken, refreshToken, user, expiresAt, orgId];
}

/// Raised when the API answers with an error body.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  /// True when the session is gone for good and the operator must sign in.
  bool get isAuthFailure =>
      statusCode == 401 || code == 'invalid_refresh' || code == 'invalid_token';

  @override
  String toString() => message;
}
