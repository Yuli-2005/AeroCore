import api from './api';

function extractData<T>(res: any): T[] {
  if (res?.data?.data) return res.data.data;
  if (Array.isArray(res?.data)) return res.data;
  if (Array.isArray(res)) return res;
  return res?.data ?? [];
}

const get = async <T>(path: string): Promise<T[]> => {
  const res = await api.get(path);
  return extractData<T>(res.data);
};

const post = async <T>(path: string, body: unknown): Promise<T> => {
  const res = await api.post(path, body);
  return res.data?.data ?? res.data;
};

const patch = async <T>(path: string, body: unknown): Promise<T> => {
  const res = await api.patch(path, body);
  return res.data?.data ?? res.data;
};

const put = async <T>(path: string, body: unknown): Promise<T> => {
  const res = await api.put(path, body);
  return res.data?.data ?? res.data;
};

const del = async <T>(path: string): Promise<T> => {
  const res = await api.delete(path);
  return res.data?.data ?? res.data;
};

export const adminService = {
  // Countries
  getCountries: () => get<any>('/admin/countries'),
  createCountry: (b: unknown) => post<any>('/admin/countries', b),
  updateCountry: (id: string, b: unknown) => patch<any>(`/admin/countries/${id}`, b),
  deleteCountry: (id: string) => del<any>(`/admin/countries/${id}`),

  // Cities
  getCities: () => get<any>('/admin/cities'),
  createCity: (b: unknown) => post<any>('/admin/cities', b),
  updateCity: (id: string, b: unknown) => patch<any>(`/admin/cities/${id}`, b),
  deleteCity: (id: string) => del<any>(`/admin/cities/${id}`),

  // Airports
  getAirports: () => get<any>('/admin/airports'),
  createAirport: (b: unknown) => post<any>('/admin/airports', b),
  updateAirport: (id: string, b: unknown) => patch<any>(`/admin/airports/${id}`, b),
  deleteAirport: (id: string) => del<any>(`/admin/airports/${id}`),

  // Airlines
  getAirlines: () => get<any>('/admin/airlines'),
  createAirline: (b: unknown) => post<any>('/admin/airlines', b),
  updateAirline: (id: string, b: unknown) => patch<any>(`/admin/airlines/${id}`, b),
  deleteAirline: (id: string) => del<any>(`/admin/airlines/${id}`),

  // Aircraft
  getAircraft: () => get<any>('/admin/aircraft'),
  createAircraft: (b: unknown) => post<any>('/admin/aircraft', b),
  updateAircraft: (id: string, b: unknown) => patch<any>(`/admin/aircraft/${id}`, b),
  deleteAircraft: (id: string) => del<any>(`/admin/aircraft/${id}`),

  // Flights
  getFlights: () => get<any>('/flights'),
  createFlight: (b: unknown) => post<any>('/flights', b),
  updateFlight: (id: string, b: unknown) => put<any>(`/flights/${id}`, b),
  deleteFlight: (id: string) => del<any>(`/flights/${id}`),

  // Segments
  getSegments: () => get<any>('/admin/segments'),
  createSegment: (b: unknown) => post<any>('/admin/segments', b),
  updateSegment: (id: string, b: unknown) => patch<any>(`/admin/segments/${id}`, b),
  deleteSegment: (id: string) => del<any>(`/admin/segments/${id}`),

  // Flight Classes
  getFlightClasses: () => get<any>('/admin/flightclasses'),
  createFlightClass: (b: unknown) => post<any>('/admin/flightclasses', b),
  updateFlightClass: (id: string, b: unknown) => patch<any>(`/admin/flightclasses/${id}`, b),
  deleteFlightClass: (id: string) => del<any>(`/admin/flightclasses/${id}`),

  // Users
  getUsers: () => get<any>('/admin/users'),
  createUser: (b: unknown) => post<any>('/admin/users', b),
  updateUser: (id: string, b: unknown) => patch<any>(`/admin/users/${id}`, b),
  deleteUser: (id: string) => del<any>(`/admin/users/${id}`),

  // Reservations
  getReservations: () => get<any>('/admin/reservations'),
  createReservation: (b: unknown) => post<any>('/admin/reservations', b),
  updateReservation: (id: string, b: unknown) => patch<any>(`/admin/reservations/${id}`, b),
  deleteReservation: (id: string) => del<any>(`/admin/reservations/${id}`),

  // Payments
  getPayments: () => get<any>('/admin/payments'),
  createPayment: (b: unknown) => post<any>('/admin/payments', b),
  updatePayment: (id: string, b: unknown) => patch<any>(`/admin/payments/${id}`, b),
  deletePayment: (id: string) => del<any>(`/admin/payments/${id}`),

  // Invoices
  getInvoices: () => get<any>('/admin/invoices'),
  createInvoice: (b: unknown) => post<any>('/admin/invoices', b),
  updateInvoice: (id: string, b: unknown) => patch<any>(`/admin/invoices/${id}`, b),
  deleteInvoice: (id: string) => del<any>(`/admin/invoices/${id}`),

  // Boarding Passes
  getBoardingPasses: () => get<any>('/admin/boarding-passes'),
  createBoardingPass: (b: unknown) => post<any>('/admin/boarding-passes', b),
  updateBoardingPass: (id: string, b: unknown) => patch<any>(`/admin/boarding-passes/${id}`, b),
  deleteBoardingPass: (id: string) => del<any>(`/admin/boarding-passes/${id}`),

  // Audit Logs
  getAuditLogs: () => get<any>('/admin/auditlogs'),

  // Service Catalog
  getServices: () => get<any>('/admin/servicecatalog'),
  createService: (b: unknown) => post<any>('/admin/servicecatalog', b),
  updateService: (id: string, b: unknown) => patch<any>(`/admin/servicecatalog/${id}`, b),
  deleteService: (id: string) => del<any>(`/admin/servicecatalog/${id}`),

  // Promotions
  getPromotions: () => get<any>('/admin/promotions'),
  createPromotion: (b: unknown) => post<any>('/admin/promotions', b),
  updatePromotion: (id: string, b: unknown) => patch<any>(`/admin/promotions/${id}`, b),
  deletePromotion: (id: string) => del<any>(`/admin/promotions/${id}`),

  // Airline Service Configs
  getAirlineServiceConfigs: () => get<any>('/admin/airline-service-config'),
  createAirlineServiceConfig: (b: unknown) => post<any>('/admin/airline-service-config', b),
  updateAirlineServiceConfig: (id: string, b: unknown) => patch<any>(`/admin/airline-service-config/${id}`, b),
  deleteAirlineServiceConfig: (id: string) => del<any>(`/admin/airline-service-config/${id}`),

  // Airline Airports
  getAirlineAirports: () => get<any>('/admin/airline-airports'),
  createAirlineAirport: (b: unknown) => post<any>('/admin/airline-airports', b),
  deleteAirlineAirport: (airlineId: string, airportId: string) => del<any>(`/admin/airline-airports/${airlineId}/${airportId}`),

  // Billing Profiles
  getBillingProfiles: () => get<any>('/admin/billing-profiles'),
  createBillingProfile: (b: unknown) => post<any>('/admin/billing-profiles', b),
  updateBillingProfile: (id: string, b: unknown) => patch<any>(`/admin/billing-profiles/${id}`, b),
  deleteBillingProfile: (id: string) => del<any>(`/admin/billing-profiles/${id}`),

  // Invoice Items
  getInvoiceItems: () => get<any>('/admin/invoice-items'),
  createInvoiceItem: (b: unknown) => post<any>('/admin/invoice-items', b),
  updateInvoiceItem: (id: string, b: unknown) => patch<any>(`/admin/invoice-items/${id}`, b),
  deleteInvoiceItem: (id: string) => del<any>(`/admin/invoice-items/${id}`),

  // Passenger Services
  getPassengerServices: () => get<any>('/admin/passenger-services'),
  createPassengerService: (b: unknown) => post<any>('/admin/passenger-services', b),
  updatePassengerService: (id: string, b: unknown) => patch<any>(`/admin/passenger-services/${id}`, b),
  deletePassengerService: (id: string) => del<any>(`/admin/passenger-services/${id}`),

  // Reservation Passengers
  getReservationPassengers: () => get<any>('/admin/reservation-passengers'),
  createReservationPassenger: (b: unknown) => post<any>('/admin/reservation-passengers', b),
  updateReservationPassenger: (id: string, b: unknown) => patch<any>(`/admin/reservation-passengers/${id}`, b),
  deleteReservationPassenger: (id: string) => del<any>(`/admin/reservation-passengers/${id}`),
};
