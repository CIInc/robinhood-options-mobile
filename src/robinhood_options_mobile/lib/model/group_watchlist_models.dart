import 'package:cloud_firestore/cloud_firestore.dart';

enum WatchlistPermission { editor, viewer }

class GroupWatchlist {
  final String id;
  final String groupId;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> permissions; // userId -> "editor" or "viewer"
  final List<WatchlistSymbol> symbols;

  GroupWatchlist({
    required this.id,
    required this.groupId,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.permissions,
    this.symbols = const [],
  });

  factory GroupWatchlist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupWatchlist(
      id: doc.id,
      groupId: data['groupId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      permissions: Map<String, String>.from(
        (data['permissions'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'permissions': permissions,
    };
  }

  GroupWatchlist copyWith({
    String? id,
    String? groupId,
    String? name,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? permissions,
    List<WatchlistSymbol>? symbols,
  }) {
    return GroupWatchlist(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      permissions: permissions ?? this.permissions,
      symbols: symbols ?? this.symbols,
    );
  }
}

class WatchlistSymbol {
  final String id;
  final String symbol;
  final String addedBy;
  final DateTime addedAt;
  final List<WatchlistAlert> alerts;

  WatchlistSymbol({
    required this.id,
    required this.symbol,
    required this.addedBy,
    required this.addedAt,
    this.alerts = const [],
  });

  factory WatchlistSymbol.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WatchlistSymbol(
      id: doc.id,
      symbol: data['symbol'] as String? ?? '',
      addedBy: data['addedBy'] as String? ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'symbol': symbol,
      'addedBy': addedBy,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  WatchlistSymbol copyWith({
    String? id,
    String? symbol,
    String? addedBy,
    DateTime? addedAt,
    List<WatchlistAlert>? alerts,
  }) {
    return WatchlistSymbol(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      alerts: alerts ?? this.alerts,
    );
  }
}

class WatchlistAlert {
  final String id;
  final String type; // "price_above", "price_below"
  final double threshold;
  final bool active;
  final DateTime createdAt;

  WatchlistAlert({
    required this.id,
    required this.type,
    required this.threshold,
    required this.active,
    required this.createdAt,
  });

  factory WatchlistAlert.fromFirestore(Map<String, dynamic> data, String id) {
    return WatchlistAlert(
      id: id,
      type: data['type'] as String? ?? 'price_above',
      threshold: (data['threshold'] as num?)?.toDouble() ?? 0.0,
      active: data['active'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'threshold': threshold,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  WatchlistAlert copyWith({
    String? id,
    String? type,
    double? threshold,
    bool? active,
    DateTime? createdAt,
  }) {
    return WatchlistAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      threshold: threshold ?? this.threshold,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
