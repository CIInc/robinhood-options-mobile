/*
{
    "child_sort_direction": "ascending",
    "child_sort_order": "custom",
    "created_at": "2021-10-19T14:44:28.178002+00:00",
    "display_description": null,
    "display_name": "Energy",
    "id": "4d9aea6a-2574-4d3e-875c-5d2e98362ea9",
    "owner_type": "custom",
    "parent_lists": [],
    "read_permission": "private",
    "updated_at": "2021-10-19T14:45:27.349316+00:00",
    "allowed_object_types": [
        "currency_pair",
        "instrument"
    ],
    "icon_emoji": "ð¡",
    "owner": "8e620d87-d864-4297-828b-c9b7662f2c2b",
    "item_count": 4,
    "child_info": {
        "child_type": "item",
        "children": []
    },
    "followed": true,
    "default_expanded": true,
    "related_lists": [],
    "hero_images": null
}
*/
import 'package:robinhood_options_mobile/model/watchlist_item.dart';

class Watchlist {
  final String id;
  final String displayName;
  final String? ownerType;
  final String? iconEmoji;
  final Map<String, dynamic>? imageUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  List<WatchlistItem> items = [];

  Watchlist(this.id, this.displayName, this.ownerType, this.iconEmoji,
      this.imageUrls, this.createdAt, this.updatedAt);

  Watchlist.fromJson(dynamic json)
      : id = json['id'],
        displayName = json['display_name'],
        ownerType = json['owner_type'],
        iconEmoji = json['icon_emoji'],
        imageUrls = json['image_urls'],
        createdAt = DateTime.tryParse(json['created_at']),
        updatedAt = DateTime.tryParse(json['updated_at']);
}
