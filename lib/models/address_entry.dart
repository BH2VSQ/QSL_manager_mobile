class AddressEntry {
  const AddressEntry({
    required this.callsign,
    this.name = '',
    this.phone = '',
    this.address = '',
    this.postalCode = '',
    this.country = '',
  });

  final String callsign;
  final String name;
  final String phone;
  final String address;
  final String postalCode;
  final String country;

  factory AddressEntry.fromJson(Map<String, dynamic> json) => AddressEntry(
        callsign: _asString(json['callsign']),
        name: _asString(json['name']),
        phone: _asString(json['phone']),
        address: _asString(json['address']),
        postalCode: _asString(json['postal_code'] ?? json['zip']),
        country: _asString(json['country']),
      );

  static String _asString(dynamic value) => value == null ? '' : value.toString();
}
