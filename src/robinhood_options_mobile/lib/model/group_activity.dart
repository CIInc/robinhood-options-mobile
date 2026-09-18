import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

enum GroupActivityType {
  trade,
  order,
  memberJoined,
  memberLeft,
  watchlistUpdated,
  milestone,
}

class GroupActivityPrivacySettings {
  final bool shareTrades;
  final bool showTradeAmounts;
  final bool anonymous;

  const GroupActivityPrivacySettings({
    this.shareTrades = true,
    this.showTradeAmounts = true,
    this.anonymous = false,
  });

  factory GroupActivityPrivacySettings.fromJson(Map<String, dynamic> json) {
    return GroupActivityPrivacySettings(
      shareTrades: json['shareTrades'] as bool? ?? true,
      showTradeAmounts: json['showTradeAmounts'] as bool? ?? true,
      anonymous: json['anonymous'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shareTrades': shareTrades,
      'showTradeAmounts': showTradeAmounts,
      'anonymous': anonymous,
    };
  }

  GroupActivityPrivacySettings copyWith({
    bool? shareTrades,
    bool? showTradeAmounts,
    bool? anonymous,
  }) {
    return GroupActivityPrivacySettings(
      shareTrades: shareTrades ?? this.shareTrades,
      showTradeAmounts: showTradeAmounts ?? this.showTradeAmounts,
      anonymous: anonymous ?? this.anonymous,
    );
  }
}

class GroupActivity {
  final String id;
  final String groupId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final GroupActivityType type;
  final String title;
  final String? description;
  final DateTime timestamp;
  final String? symbol;
  final String? side; // 'buy', 'sell'
  final double? quantity;
  final double? price;
  final String? orderType; // 'market', 'limit', etc.
  final String? assetType; // 'equity', 'option', 'crypto', etc.
  final Map<String, dynamic>? details;
  final bool isAnonymous;
  final bool hideAmounts;

  const GroupActivity({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.type,
    required this.title,
    this.description,
    required this.timestamp,
    this.symbol,
    this.side,
    this.quantity,
    this.price,
    this.orderType,
    this.assetType,
    this.details,
    this.isAnonymous = false,
    this.hideAmounts = false,
  });

  bool get isTrade =>
      type == GroupActivityType.trade || type == GroupActivityType.order;

  bool get isBuy => side?.toLowerCase() == 'buy';
  bool get isSell => side?.toLowerCase() == 'sell';

  bool get isPending {
    final s = details?['state']?.toString().toLowerCase();
    if (s != null && s.isNotEmpty) {
      return s != 'filled';
    }
    return type == GroupActivityType.order;
  }

  String get displayUserName => isAnonymous ? 'Anonymous Member' : userName;

  double? get totalAmount {
    if (price != null && quantity != null) {
      // If options contract, each contract is typically 100 shares
      final multiplier = (assetType?.toLowerCase() == 'option') ? 100.0 : 1.0;
      return price! * quantity! * multiplier;
    }
    return null;
  }

  String get formattedTotal {
    if (hideAmounts) {
      return r'$***';
    }
    final total = totalAmount;
    if (total == null) return '';
    final formatCurrency = NumberFormat.simpleCurrency();
    return formatCurrency.format(total);
  }

  String get formattedQuantity {
    if (hideAmounts) {
      return '***';
    }
    if (quantity == null) return '';
    return quantity! % 1 == 0
        ? quantity!.toInt().toString()
        : quantity!.toStringAsFixed(2);
  }

  factory GroupActivity.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GroupActivity.fromJson(data, doc.id);
  }

  factory GroupActivity.fromJson(Map<String, dynamic> json, [String? id]) {
    DateTime parsedTimestamp;
    if (json['timestamp'] is Timestamp) {
      parsedTimestamp = (json['timestamp'] as Timestamp).toDate();
    } else if (json['timestamp'] is String) {
      parsedTimestamp =
          DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now();
    } else {
      parsedTimestamp = DateTime.now();
    }

    final typeStr = json['type'] as String? ?? 'trade';
    final parsedType = GroupActivityType.values.firstWhere(
      (e) => e.name == typeStr || e.toString() == 'GroupActivityType.$typeStr',
      orElse: () => GroupActivityType.trade,
    );

    return GroupActivity(
      id: id ?? json['id'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Unknown Member',
      userPhotoUrl: json['userPhotoUrl'] as String?,
      type: parsedType,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      timestamp: parsedTimestamp,
      symbol: json['symbol'] as String?,
      side: json['side'] as String?,
      quantity: parseDouble(json['quantity']),
      price: parseDouble(json['price']),
      orderType: json['orderType'] as String?,
      assetType: json['assetType'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      hideAmounts: json['hideAmounts'] as bool? ?? false,
    );
  }

  GroupActivity copyWith({
    String? id,
    String? groupId,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    GroupActivityType? type,
    String? title,
    String? description,
    DateTime? timestamp,
    String? symbol,
    String? side,
    double? quantity,
    double? price,
    String? orderType,
    String? assetType,
    Map<String, dynamic>? details,
    bool? isAnonymous,
    bool? hideAmounts,
  }) {
    return GroupActivity(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      symbol: symbol ?? this.symbol,
      side: side ?? this.side,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      orderType: orderType ?? this.orderType,
      assetType: assetType ?? this.assetType,
      details: details ?? this.details,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      hideAmounts: hideAmounts ?? this.hideAmounts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'type': type.name,
      'title': title,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'symbol': symbol,
      'side': side,
      'quantity': quantity,
      'price': price,
      'orderType': orderType,
      'assetType': assetType,
      'details': details,
      'isAnonymous': isAnonymous,
      'hideAmounts': hideAmounts,
    };
  }
}
