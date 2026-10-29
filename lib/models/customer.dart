class Customer {
  final int? id;
  final String name;
  final String phone;
  final String? email;

  Customer({this.id, required this.name, required this.phone, this.email});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String?,
    );
  }

  Customer copyWith({int? id, String? name, String? phone, String? email}) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }

  @override
  String toString() => 'Customer(id: $id, name: $name, phone: $phone)';
}
