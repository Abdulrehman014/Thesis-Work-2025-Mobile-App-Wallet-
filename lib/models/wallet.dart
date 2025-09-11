// lib/models/wallet.dart

class Wallet {
  final String id;
  final String name;
  final DateTime createdOn;
  final DateTime addedOn;
  final String permission;

  Wallet({
    required this.id,
    required this.name,
    required this.createdOn,
    required this.addedOn,
    required this.permission,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    id: json['id'] as String,
    name: json['name'] as String,
    createdOn: DateTime.parse(json['createdOn'] as String),
    addedOn: DateTime.parse(json['addedOn'] as String),
    permission: json['permission'] as String,
  );
}
