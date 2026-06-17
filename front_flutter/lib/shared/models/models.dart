double _d(dynamic v) => double.tryParse((v ?? 0).toString()) ?? 0.0;

class Airport {
  final String id, iataCode, name;
  final String? cityName;
  Airport({required this.id, required this.iataCode, required this.name, this.cityName});
  factory Airport.fromJson(Map j) => Airport(
    id: j['id'] ?? '', iataCode: j['iataCode'] ?? '',
    name: j['name'] ?? '', cityName: j['city']?['name']);
}

class FlightClass {
  final String id, cabinClass;
  final double price;
  final int availableSeats;
  FlightClass({required this.id, required this.cabinClass,
    required this.price, required this.availableSeats});
  factory FlightClass.fromJson(Map j) => FlightClass(
    id: j['id'] ?? '', cabinClass: j['cabinClass'] ?? 'ECONOMY',
    price: _d(j['basePrice'] ?? j['price']),
    availableSeats: j['availableSeats'] ?? 0);
}

class Flight {
  final String id, flightNumber, status;
  final String departureTime, arrivalTime;
  final Airport origin, destination;
  final String airlineName;
  final List<FlightClass> classes;
  Flight({required this.id, required this.flightNumber, required this.status,
    required this.departureTime, required this.arrivalTime,
    required this.origin, required this.destination,
    required this.airlineName, required this.classes});
  factory Flight.fromJson(Map j) => Flight(
    id: j['id'] ?? '', flightNumber: j['flightNumber'] ?? '',
    status: j['status'] ?? '',
    departureTime: j['departureDateTime'] ?? j['departureTime'] ?? '',
    arrivalTime:   j['arrivalDateTime']   ?? j['arrivalTime']   ?? '',
    origin:      Airport.fromJson(j['originAirport'] ?? {}),
    destination: Airport.fromJson(j['destinationAirport'] ?? {}),
    airlineName: j['airline']?['name'] ?? '',
    classes: (j['flightClasses'] as List<dynamic>? ?? [])
        .map((c) => FlightClass.fromJson(c)).toList());

  // Used when flight comes from reservation response (segments-based structure)
  factory Flight.fromReservationJson(Map j) {
    final segs = j['segments'] as List<dynamic>?;
    final seg  = (segs != null && segs.isNotEmpty) ? segs[0] as Map : null;
    return Flight(
      id:            j['id']           ?? '',
      flightNumber:  j['flightNumber'] ?? '',
      status:        j['status']       ?? '',
      departureTime: seg?['departureDateTime'] ?? '',
      arrivalTime:   seg?['arrivalDateTime']   ?? '',
      origin:      Airport.fromJson(seg?['originAirport']      ?? {}),
      destination: Airport.fromJson(seg?['destinationAirport'] ?? {}),
      airlineName: seg?['airline']?['name'] ?? '',
      classes:     [],
    );
  }

  String get depTime => departureTime.length > 15 ? departureTime.substring(11, 16) : departureTime;
  String get arrTime => arrivalTime.length > 15 ? arrivalTime.substring(11, 16) : arrivalTime;
}

class Passenger {
  final String id, firstName, lastName, documentNumber;
  final String? seatNumber, cabinClass, flightClassId;
  Passenger({required this.id, required this.firstName, required this.lastName,
    required this.documentNumber, this.seatNumber, this.cabinClass, this.flightClassId});
  factory Passenger.fromJson(Map j) => Passenger(
    id: j['id'] ?? '', firstName: j['firstName'] ?? '',
    lastName: j['lastName'] ?? '', documentNumber: j['documentNumber'] ?? '',
    seatNumber: j['seatNumber'], cabinClass: j['cabinClass'],
    flightClassId: j['flightClassId']);
  String get fullName => '$firstName $lastName';
}

class Invoice {
  final String id, invoiceNumber;
  final double subtotal, taxAmount, total;
  final String createdAt;
  Invoice({required this.id, required this.invoiceNumber,
    required this.subtotal, required this.taxAmount,
    required this.total, required this.createdAt});
  factory Invoice.fromJson(Map j) => Invoice(
    id:            j['id']            ?? '',
    invoiceNumber: j['invoiceNumber'] ?? '',
    subtotal:      _d(j['subtotal']),
    taxAmount:     _d(j['taxAmount']),
    total:         _d(j['total']),
    createdAt:     j['createdAt']     ?? '');
}

class Reservation {
  final String id, reservationCode, status;
  final double totalAmount;
  final String? createdAt;
  final List<Passenger> passengers;
  final Flight? flight;
  Reservation({required this.id, required this.reservationCode,
    required this.status, required this.totalAmount,
    this.createdAt, required this.passengers, this.flight});
  factory Reservation.fromJson(Map j) => Reservation(
    id: j['id'] ?? '', reservationCode: j['reservationCode'] ?? '',
    status: j['status'] ?? '', totalAmount: _d(j['totalAmount']),
    createdAt: j['createdAt'],
    passengers: (j['passengers'] as List<dynamic>? ?? [])
        .map((p) => Passenger.fromJson(p)).toList(),
    flight: j['flight'] != null
        ? Flight.fromReservationJson(j['flight']) : null);
}