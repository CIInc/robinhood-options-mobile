import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/device.dart';

class User {
  String? name;
  String? nameLower;
  String? email;
  String? phoneNumber;
  String? photoUrl;
  String? providerId;
  String? location;
  UserRole role;
  List<Device> devices;
  DateTime dateCreated;
  DateTime? dateUpdated;
  List<BrokerageUser> brokerageUsers = [];

  User(
      {this.name,
      this.nameLower,
      this.email,
      this.phoneNumber,
      this.photoUrl,
      this.providerId,
      this.location,
      this.role = UserRole.user,
      required this.devices,
      required this.dateCreated,
      this.dateUpdated,
      required this.brokerageUsers});

  User.fromJson(Map<String, Object?> json)
      : this(
            name: json['name'] as String?,
            nameLower: json['nameLower'] as String?,
            email: json['email'] as String?,
            phoneNumber: json['phoneNumber'] as String?,
            photoUrl: json['photoUrl'] as String?,
            providerId: json['providerId'] as String?,
            location: json['location'] as String?,
            role: (json['role'] != null ? json['role'] as String : '')
                .parseEnum(UserRole.values, UserRole.user) as UserRole,
            devices: json.keys.contains('devices')
                ? Device.fromJsonArray(json['devices'])
                : [],
            dateCreated: (json['dateCreated'] as Timestamp).toDate(),
            dateUpdated: json['dateUpdated'] != null
                ? (json['dateUpdated'] as Timestamp).toDate()
                : null,
            brokerageUsers: json['brokerageUsers'] != null
                ? BrokerageUser.fromJsonArray(json['brokerageUsers'])
                : []);

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'nameLower': nameLower,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'providerId': providerId,
      'location': location,
      'role': role.enumValue(),
      'devices': devices.map((e) => e.toJson()).toList(),
      'dateCreated': dateCreated,
      'dateUpdated': dateUpdated,
      'brokerageUsers': brokerageUsers.map((e) => e.toJson()).toList()
    };
  }

  static List<User> fromJsonArray(dynamic json) {
    List<User> list = [];
    for (int i = 0; i < json.length; i++) {
      list.add(User.fromJson(json[i]));
    }
    return list;
  }
}
