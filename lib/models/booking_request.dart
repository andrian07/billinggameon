/// One booking room made by a member from the gameon app. Saldo has already
/// been deducted on the gameon side when the row was created - billinggameon
/// only displays these (see BookingRepository / Master::bookings()).
class BookingRequest {
  final int bookingRequestId;
  final int customerId;
  final String customerName;
  final String customerPhone;
  final int categoryMejaId;
  final String categoryName;
  final int? unitNo;
  final String? area;
  final String bookingDate;
  final String bookingTime;
  final int durationHours;
  final int price;
  final String status;
  final DateTime? createdAt;

  const BookingRequest({
    required this.bookingRequestId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.categoryMejaId,
    required this.categoryName,
    required this.bookingDate,
    required this.bookingTime,
    required this.durationHours,
    required this.price,
    required this.status,
    this.unitNo,
    this.area,
    this.createdAt,
  });

  /// "Reguler · No.3 (Smoking)" - for the cashier list.
  String get roomLabel {
    if (unitNo == null) return categoryName;
    final areaLabel = area == 'Smoking' ? 'Smoking' : 'Non-smoking';
    return "$categoryName · No.$unitNo ($areaLabel)";
  }

  /// Scheduled start, parsed from [bookingDate] + [bookingTime] ("2026-09-01"
  /// + "15:00:00") - used to sort by soonest-to-play and to open the table
  /// with the exact slot the member booked (see BookingPage's "Buka Meja").
  DateTime? get startAt => DateTime.tryParse("$bookingDate $bookingTime");

  /// Seluruh slot yang dipesan (jam mulai + durasi) sudah lewat dari sekarang -
  /// member tidak datang, meja tidak lagi bisa dibukakan untuk slot itu. Baris
  /// seperti ini ditampilkan redup di halaman Booking dan tidak ikut dihitung
  /// di badge notifikasi (belum di-acc TAPI sudah tidak bisa ditindaklanjuti).
  bool get isExpired {
    final start = startAt;
    if (start == null) return false;
    return start.add(Duration(hours: durationHours)).isBefore(DateTime.now());
  }

  factory BookingRequest.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;

    return BookingRequest(
      bookingRequestId: asInt(json['booking_request_id']),
      customerId: asInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? "",
      customerPhone: json['customer_phone']?.toString() ?? "",
      categoryMejaId: asInt(json['category_meja_id']),
      categoryName: json['category_name']?.toString() ?? "-",
      unitNo: json['unit_no'] == null ? null : asInt(json['unit_no']),
      area: json['area']?.toString(),
      bookingDate: json['booking_date']?.toString() ?? "",
      bookingTime: json['booking_time']?.toString() ?? "",
      durationHours: asInt(json['duration_hours']),
      price: asInt(json['price']),
      status: json['status']?.toString() ?? "",
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ""),
    );
  }
}

/// Locally-logged booking notification (billing_flutter.booking_notification),
/// independent of the live list - stays even after the booking is served.
class BookingNotificationItem {
  final int id;
  final int bookingRequestId;
  final int customerId;
  final String customerName;
  final String categoryName;
  final String bookingDate;
  final String bookingTime;
  final int durationHours;
  final int price;
  final bool isRead;
  final DateTime? createdAt;

  const BookingNotificationItem({
    required this.id,
    required this.bookingRequestId,
    required this.customerId,
    required this.customerName,
    required this.categoryName,
    required this.bookingDate,
    required this.bookingTime,
    required this.durationHours,
    required this.price,
    required this.isRead,
    this.createdAt,
  });

  factory BookingNotificationItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;

    return BookingNotificationItem(
      id: asInt(json['id']),
      bookingRequestId: asInt(json['booking_request_id']),
      customerId: asInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? "",
      categoryName: json['category_name']?.toString() ?? "-",
      bookingDate: json['booking_date']?.toString() ?? "",
      bookingTime: json['booking_time']?.toString() ?? "",
      durationHours: asInt(json['duration_hours']),
      price: asInt(json['price']),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ""),
    );
  }
}
