class Customer {
  final int id;
  final String idNumber;
  final String name;
  final String phone;
  final String? address;
  final String? email;
  final int point;
  final String status;

  const Customer({
    required this.id,
    required this.idNumber,
    required this.name,
    required this.phone,
    this.address,
    this.email,
    required this.point,
    required this.status,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawPoint = json['point'];

    return Customer(
      id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      idNumber: json['id_number']?.toString() ?? "",
      name: json['name']?.toString() ?? "",
      phone: json['phone']?.toString() ?? "",
      address: json['address']?.toString(),
      email: json['email']?.toString(),
      point: rawPoint is int ? rawPoint : int.tryParse(rawPoint.toString()) ?? 0,
      status: json['verification']?.toString() ?? "",
    );
  }
}
