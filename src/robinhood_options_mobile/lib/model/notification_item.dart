import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _dateFormat = DateFormat.yMMMd();

/// Interactive response prompt attached to a notification message.
class NotificationResponse {
  final String displayText;
  final String? answer;

  const NotificationResponse({required this.displayText, this.answer});

  factory NotificationResponse.fromJson(dynamic json) {
    if (json is! Map) {
      return const NotificationResponse(displayText: '');
    }
    return NotificationResponse(
      displayText: (json['display_text'] ?? json['text'] ?? '').toString(),
      answer: json['answer']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'display_text': displayText,
    if (answer != null) 'answer': answer,
  };
}

/// Represents a first-party notification card or announcement from the
/// Midlands Notification Stack (`/midlands/notifications/stack/`) or Inbox Threads (`/inbox/threads/`).
class NotificationItem {
  final String cardId;
  final String? loadId;
  final String
  category; // 'market', 'feature', 'account', 'security', 'orders', 'options', 'crypto', 'futures', 'dividends', 'ipo', 'announcements'
  final String type;
  final String title;
  final String message;
  final String? callToAction;
  final String? action;
  final String? iconName;
  final bool isFixed;
  final DateTime? time;
  final String? url;
  final bool isRead;
  final String? shortDisplayName;
  final String? avatarColorHex;
  final bool isCritical;
  final bool isMuted;
  final String? entityUrl;
  final String? avatarUrl;
  final String? actionDisplayText;
  final String? actionUrl;
  final List<NotificationResponse> responses;

  const NotificationItem({
    required this.cardId,
    this.loadId,
    this.category = 'general',
    this.type = 'announcement',
    required this.title,
    required this.message,
    this.callToAction,
    this.action,
    this.iconName,
    this.isFixed = false,
    this.time,
    this.url,
    this.isRead = false,
    this.shortDisplayName,
    this.avatarColorHex,
    this.isCritical = false,
    this.isMuted = false,
    this.entityUrl,
    this.avatarUrl,
    this.actionDisplayText,
    this.actionUrl,
    this.responses = const [],
  });

  factory NotificationItem.fromJson(dynamic json) {
    if (json is! Map) {
      return const NotificationItem(cardId: '', title: '', message: '');
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    final id =
        (json['id'] ??
                json['card_id'] ??
                json['thread_id'] ??
                json['uuid'] ??
                '')
            .toString();
    final load = json['load_id']?.toString();

    // Map numeric categories to friendly strings
    String catStr = 'general';
    final rawCat = json['category'];
    if (rawCat is int) {
      switch (rawCat) {
        case 8:
          catStr = 'market';
          break;
        case 5:
          catStr = 'feature';
          break;
        case 1:
        case 2:
          catStr = 'account';
          break;
        case 3:
          catStr = 'security';
          break;
        default:
          catStr = 'general';
      }
    } else if (rawCat is String) {
      catStr = rawCat.toLowerCase();
    }

    final tType = (json['type'] ?? json['thread_type'] ?? 'announcement')
        .toString();
    final tTitle =
        (json['display_name'] ??
                json['title'] ??
                json['subject'] ??
                json['header'] ??
                'Robinhood Notice')
            .toString();

    // Extract message text from preview_text or most_recent_message or legacy message/body
    String tMsg = '';
    if (json['preview_text'] is Map && json['preview_text']['text'] != null) {
      tMsg = json['preview_text']['text'].toString();
    } else if (json['most_recent_message'] is Map &&
        json['most_recent_message']['rich_text'] is Map &&
        json['most_recent_message']['rich_text']['text'] != null) {
      tMsg = json['most_recent_message']['rich_text']['text'].toString();
    } else {
      tMsg =
          (json['message'] ??
                  json['body'] ??
                  json['preview'] ??
                  json['text'] ??
                  '')
              .toString();
    }

    // Actions & responses from most_recent_message
    Map? mrm;
    if (json['most_recent_message'] is Map) {
      mrm = json['most_recent_message'] as Map;
    }

    String? actDisplayText =
        json['call_to_action']?.toString() ??
        json['cta_text']?.toString() ??
        mrm?['action']?['display_text']?.toString();
    String? actUrl =
        json['action']?.toString() ??
        json['deep_link']?.toString() ??
        json['target_url']?.toString() ??
        mrm?['action']?['url']?.toString();

    final respList = <NotificationResponse>[];
    if (mrm != null && mrm['responses'] is List) {
      for (final r in mrm['responses']) {
        respList.add(NotificationResponse.fromJson(r));
      }
    }

    final icon = json['icon']?.toString() ?? json['icon_name']?.toString();
    final fixed = json['fixed'] == true;
    final date = parseDate(
      json['last_message_sent_at'] ??
          mrm?['created_at'] ??
          json['time'] ??
          json['created_at'] ??
          json['timestamp'],
    );
    final read = json['is_read'] == true || json['read'] == true;
    final itemUrl = json['url']?.toString();
    final shortName = json['short_display_name']?.toString();
    final colorHex = json['avatar_color']?.toString();
    final critical = json['is_critical'] == true;
    final muted = json['is_muted'] == true;
    final entUrl = json['entity_url']?.toString();
    final avUrl = json['avatar_url']?.toString();

    // Categorization intelligence
    final shortUpper = (shortName ?? '').toUpperCase();
    final titleLower = tTitle.toLowerCase();
    final msgLower = tMsg.toLowerCase();
    final actUrlLower = (actUrl ?? '').toLowerCase();
    final entUrlLower = (entUrl ?? '').toLowerCase();

    if (rawCat == null || catStr == 'general' || catStr == 'account') {
      if (shortUpper.startsWith('/') ||
          titleLower.contains('futures') ||
          msgLower.contains('/m2k') ||
          msgLower.contains('/mgc') ||
          msgLower.contains('/m6e') ||
          msgLower.contains('/sil')) {
        catStr = 'futures';
      } else if (shortUpper == 'IPOA' ||
          titleLower.contains('ipo access') ||
          msgLower.contains('ipo access') ||
          msgLower.contains('plans to go public') ||
          msgLower.contains('prospectus')) {
        catStr = 'ipo';
      } else if (entUrlLower.contains('currency_pair') ||
          actUrlLower.contains('type=currency') ||
          const [
            'DOGE',
            'BTC',
            'ETH',
            'SHIB',
            'BCH',
            'LTC',
            'AVAX',
            'SOL',
            'TRUMP',
            'XRP',
            'ADA',
          ].contains(shortUpper) ||
          msgLower.contains('doge') ||
          msgLower.contains('shib') ||
          msgLower.contains('bitcoin') ||
          msgLower.contains('ethereum')) {
        catStr = 'crypto';
      } else if (actUrlLower.contains('type=option') ||
          msgLower.contains(' call ') ||
          msgLower.contains(' put ') ||
          msgLower.contains('call spread') ||
          msgLower.contains('put spread') ||
          msgLower.contains('contracts of') ||
          titleLower.contains('option')) {
        catStr = 'options';
      } else if (actUrlLower.contains('dividends') ||
          msgLower.contains('dividend reinvestment') ||
          msgLower.contains('dividend payment') ||
          msgLower.contains('received a dividend') ||
          msgLower.contains('adr fee')) {
        catStr = 'dividends';
      } else if (tTitle == 'Announcements' ||
          shortUpper == '!' ||
          msgLower.contains('expire 3 days a week')) {
        catStr = 'announcements';
      } else if (shortUpper == 'RS' ||
          titleLower.contains('security') ||
          msgLower.contains('cash card number') ||
          msgLower.contains('trusted_devices') ||
          msgLower.contains('secure your account')) {
        catStr = 'security';
      } else if (msgLower.contains('order to buy') ||
          msgLower.contains('order to sell') ||
          msgLower.contains('order was filled') ||
          msgLower.contains('order was canceled') ||
          msgLower.contains('order was rejected') ||
          msgLower.contains('trade confirmation')) {
        catStr = 'orders';
      }
    }

    return NotificationItem(
      cardId: id,
      loadId: load,
      category: catStr,
      type: tType,
      title: tTitle,
      message: tMsg,
      callToAction: actDisplayText,
      action: actUrl,
      iconName: icon,
      isFixed: fixed,
      time: date,
      url: itemUrl,
      isRead: read,
      shortDisplayName: shortName,
      avatarColorHex: colorHex,
      isCritical: critical,
      isMuted: muted,
      entityUrl: entUrl,
      avatarUrl: avUrl,
      actionDisplayText: actDisplayText,
      actionUrl: actUrl,
      responses: respList,
    );
  }

  Color? get avatarColor {
    if (avatarColorHex == null || avatarColorHex!.isEmpty) return null;
    try {
      final hex = avatarColorHex!.replaceAll('#', '').trim();
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  IconData get iconData {
    if (iconName != null) {
      switch (iconName!.toLowerCase()) {
        case 'alert':
        case 'warning':
          return Icons.warning_amber_rounded;
        case 'lightbulb':
        case 'tip':
          return Icons.lightbulb_outline;
        case 'star':
        case 'new':
          return Icons.star_outline;
        case 'shield':
        case 'security':
          return Icons.security;
        case 'account':
        case 'user':
          return Icons.person_outline;
        case 'check':
        case 'success':
          return Icons.check_circle_outline;
        case 'trending':
        case 'chart':
          return Icons.trending_up;
      }
    }

    switch (category) {
      case 'orders':
        return Icons.receipt_long_outlined;
      case 'options':
        return Icons.layers_outlined;
      case 'crypto':
        return Icons.currency_bitcoin;
      case 'futures':
        return Icons.candlestick_chart;
      case 'dividends':
        return Icons.payments_outlined;
      case 'ipo':
        return Icons.rocket_launch_outlined;
      case 'announcements':
        return Icons.campaign_outlined;
      case 'security':
        return Icons.shield_outlined;
      case 'market':
        return Icons.trending_up;
      case 'feature':
        return Icons.star_outline;
      case 'account':
        return Icons.person_outline;
      default:
        return Icons.notifications_none;
    }
  }

  Color get iconColor {
    if (avatarColor != null) {
      return avatarColor!;
    }
    switch (category) {
      case 'orders':
        return Colors.blue;
      case 'options':
        return Colors.deepPurple;
      case 'crypto':
        return Colors.amber.shade800;
      case 'futures':
        return Colors.deepOrange;
      case 'dividends':
        return Colors.teal;
      case 'ipo':
        return Colors.green;
      case 'announcements':
        return Colors.indigo;
      case 'market':
        return Colors.orange;
      case 'feature':
        return Colors.blue;
      case 'security':
        return Colors.red;
      case 'account':
        return Colors.teal;
      default:
        return Colors.amber;
    }
  }

  String get formattedTime => time != null ? _dateFormat.format(time!) : '';

  String get relativeTime {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time!);
    if (difference.isNegative) {
      return _dateFormat.format(time!);
    }
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '${mins}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return _dateFormat.format(time!);
    }
  }

  String get formattedCategory {
    switch (category) {
      case 'ipo':
        return 'IPO Access';
      case 'orders':
        return 'Orders';
      case 'options':
        return 'Options';
      case 'crypto':
        return 'Crypto';
      case 'futures':
        return 'Futures';
      case 'dividends':
        return 'Dividends';
      case 'announcements':
        return 'Announcements';
      case 'security':
        return 'Security';
      case 'market':
        return 'Market';
      case 'feature':
        return 'Feature';
      case 'account':
        return 'Account';
      default:
        return category.isNotEmpty
            ? category[0].toUpperCase() + category.substring(1)
            : 'Notice';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'card_id': cardId,
      if (loadId != null) 'load_id': loadId,
      'category': category,
      'type': type,
      'title': title,
      'message': message,
      if (callToAction != null) 'call_to_action': callToAction,
      if (action != null) 'action': action,
      if (iconName != null) 'icon': iconName,
      'fixed': isFixed,
      if (time != null) 'time': time!.toIso8601String(),
      if (url != null) 'url': url,
      'is_read': isRead,
      if (shortDisplayName != null) 'short_display_name': shortDisplayName,
      if (avatarColorHex != null) 'avatar_color': avatarColorHex,
      'is_critical': isCritical,
      'is_muted': isMuted,
      if (entityUrl != null) 'entity_url': entityUrl,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (actionDisplayText != null) 'action_display_text': actionDisplayText,
      if (actionUrl != null) 'action_url': actionUrl,
      if (responses.isNotEmpty)
        'responses': responses.map((r) => r.toJson()).toList(),
    };
  }
}
