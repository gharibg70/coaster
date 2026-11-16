import Foundation
import SwiftUI
import MapKit

struct NativeSubscription: Codable {
    let routeId: Int
    let status: String
    let endDate: String?
    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case status
        case endDate = "end_date"
    }
}

struct NativeAttendance: Codable {
    let outbound: Bool
    let returnTrip: Bool
    let auto: Bool?
    enum CodingKeys: String, CodingKey {
        case outbound
        case returnTrip = "return_trip"
        case auto
    }
}

struct NativeSeats: Codable {
    let capacity: Int?
    let outboundTaken: Int?
    let returnTaken: Int?
    enum CodingKeys: String, CodingKey {
        case capacity
        case outboundTaken = "outbound_taken"
        case returnTaken = "return_taken"
    }
}

struct NativeAnnouncement: Codable, Identifiable {
    let id: Int?
    let title: String
    let message: String
    let createdAt: String
    enum CodingKeys: String, CodingKey {
        case id, title, message
        case createdAt = "created_at"
    }
    var stableId: String { "\(id ?? 0)-\(createdAt)" }
}

struct NativeHistory: Codable, Identifiable {
    let attendanceDate: String
    let outbound: Bool
    let returnTrip: Bool
    enum CodingKeys: String, CodingKey {
        case attendanceDate = "attendance_date"
        case outbound
        case returnTrip = "return_trip"
    }
    var id: String { attendanceDate }
}

struct NativeBusLocation: Codable {
    let lat: Double?
    let lng: Double?
    let isSharing: Bool?
    let updatedAt: String?
    enum CodingKeys: String, CodingKey {
        case lat, lng
        case isSharing = "is_sharing"
        case updatedAt = "updated_at"
    }
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct NativeStudentData {
    let subscription: NativeSubscription?
    let date: String
    let attendance: NativeAttendance?
    let announcements: [NativeAnnouncement]
    let history: [NativeHistory]
    let seats: NativeSeats?
}

struct NativeStudentService {
    let client: NativeSupabaseClient
    let accessToken: String
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    func load(profileId: String) async throws -> NativeStudentData {
        let date = serviceDate(offset: 1)
        let subscription = try await first(NativeSubscription.self, path: "/rest/v1/subscriptions?user_id=eq.\(profileId)&select=route_id,status,end_date&limit=1")
        guard let subscription else { return NativeStudentData(subscription: nil, date: date, attendance: nil, announcements: [], history: [], seats: nil) }
        _ = try? await rpcEmpty("apply_defaults", body: ["p_date": date])
        async let attendance = first(NativeAttendance.self, path: "/rest/v1/daily_attendance?user_id=eq.\(profileId)&attendance_date=eq.\(date)&select=outbound,return_trip,auto&limit=1")
        async let announcements = list(NativeAnnouncement.self, path: "/rest/v1/announcements?is_active=eq.true&select=id,title,message,created_at&order=created_at.desc&limit=30")
        async let history = list(NativeHistory.self, path: "/rest/v1/daily_attendance?user_id=eq.\(profileId)&select=attendance_date,outbound,return_trip&order=attendance_date.desc&limit=14")
        async let seats = first(NativeSeats.self, path: "/rest/v1/rpc/get_seats", method: "POST", body: ["p_route_id": subscription.routeId, "p_date": date])
        return NativeStudentData(subscription: subscription, date: date, attendance: try await attendance, announcements: try await announcements, history: try await history, seats: try await seats)
    }

    func setAttendance(routeId: Int, date: String, outbound: Bool, returnTrip: Bool) async throws {
        _ = try await rpcEmpty("set_my_attendance", body: ["p_route_id": routeId, "p_date": date, "p_outbound": outbound, "p_return": returnTrip])
    }

    func redeem(code: String) async throws {
        _ = try await rpcEmpty("redeem_subscription_code", body: ["p_code": code])
    }

    func busLocation() async throws -> NativeBusLocation? {
        try await first(NativeBusLocation.self, path: "/rest/v1/bus_location?id=eq.1&select=lat,lng,is_sharing,updated_at&limit=1")
    }

    private func first<T: Decodable>(_ type: T.Type, path: String, method: String = "GET", body: Any? = nil) async throws -> T? {
        let data = try await raw(path: path, method: method, body: body)
        if data.isEmpty { return nil }
        if let array = try? decoder.decode([T].self, from: data) { return array.first }
        return try decoder.decode(T.self, from: data)
    }

    private func list<T: Decodable>(_ type: T.Type, path: String) async throws -> [T] {
        let data = try await raw(path: path)
        return try decoder.decode([T].self, from: data)
    }

    private func rpcEmpty(_ name: String, body: Any) async throws -> Data {
        try await raw(path: "/rest/v1/rpc/\(name)", method: "POST", body: body)
    }

    private func raw(path: String, method: String = "GET", body: Any? = nil) async throws -> Data {
        let bodyData = body.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        let (data, response) = try await client.request(path: path, method: method, body: bodyData, accessToken: accessToken)
        guard (200..<300).contains(response.statusCode) else { throw NativeError.server("تعذر تحميل بيانات الطالب (\(response.statusCode))") }
        return data
    }

    private func serviceDate(offset: Int) -> String {
        let calendar = Calendar(identifier: .gregorian)
        var zone = TimeZone(identifier: "Asia/Baghdad")!
        var calendar = calendar
        calendar.timeZone = zone
        let date = calendar.date(byAdding: .day, value: offset, to: Date())!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

@MainActor
final class NativeStudentViewModel: ObservableObject {
    @Published var data: NativeStudentData?
    @Published var busLocation: NativeBusLocation?
    @Published var isLoading = false
    @Published var isBusy = false
    @Published var message: String?
    @Published var error: String?
    let service: NativeStudentService
    let profileId: String

    init(service: NativeStudentService, profileId: String) { self.service = service; self.profileId = profileId }

    func load() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do { data = try await service.load(profileId: profileId) }
        catch { error = errorMessage(error) }
    }

    func refreshBus() async {
        do { busLocation = try await service.busLocation() }
        catch { /* map stays usable when the bus table is temporarily unavailable */ }
    }

    func choose(outbound: Bool, returnTrip: Bool) async {
        guard let subscription = data?.subscription else { return }
        isBusy = true; defer { isBusy = false }
        do {
            try await service.setAttendance(routeId: subscription.routeId, date: data?.date ?? "", outbound: outbound, returnTrip: returnTrip)
            message = "تم حفظ اختيارك بنجاح"
            await load()
        } catch { error = errorMessage(error) }
    }

    func redeem(_ code: String) async {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isBusy = true; defer { isBusy = false }
        do { try await service.redeem(code: code.trimmingCharacters(in: .whitespacesAndNewlines)); message = "تم تفعيل الاشتراك"; await load() }
        catch { error = errorMessage(error) }
    }

    private func errorMessage(_ error: Error) -> String { (error as? LocalizedError)?.errorDescription ?? "تعذر الاتصال بالخدمة." }
}

struct StudentHomeView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var model: NativeStudentViewModel
    @State private var tab = 0
    @State private var code = ""

    init(service: NativeStudentService, profileId: String) { _model = StateObject(wrappedValue: NativeStudentViewModel(service: service, profileId: profileId)) }

    var body: some View {
        TabView(selection: $tab) {
            bookingView.tabItem { Label("الرئيسية", systemImage: "house.fill") }.tag(0)
            mapView.tabItem { Label("الكوستر", systemImage: "location.fill") }.tag(1)
            announcementsView.tabItem { Label("التنبيهات", systemImage: "bell.fill") }.tag(2)
            historyView.tabItem { Label("السجل", systemImage: "clock.fill") }.tag(3)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task { await model.load() }
        .alert("تنبيه", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("حسناً", role: .cancel) {} } message: { Text(model.error ?? "") }
        .alert("تم", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("حسناً", role: .cancel) {} } message: { Text(model.message ?? "") }
    }

    private var bookingView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .trailing, spacing: 16) {
                    HStack { Spacer(); VStack(alignment: .trailing) { Text("دوام الغد").font(.largeTitle.bold()); Text(model.data?.date ?? "").foregroundStyle(.secondary) } }
                    if model.isLoading && model.data == nil { ProgressView("جاري تحميل بيانات الحجز…") }
                    else if model.data?.subscription == nil {
                        NativeCard(title: "تفعيل الحساب") { Text("لم يُفعّل اشتراكك بعد.").foregroundStyle(.secondary); TextField("BUS-XXXX", text: $code).textFieldStyle(.roundedBorder); Button("تفعيل الاشتراك") { Task { await model.redeem(code) } }.disabled(model.isBusy) }
                    } else if let data = model.data, let subscription = data.subscription {
                        if subscription.status != "active" { Text("اشتراكك موقوف. راجع صاحب الكوستر.").foregroundColor(.red).frame(maxWidth: .infinity, alignment: .trailing) }
                        if let seats = data.seats { seatsCard(seats) }
                        NativeCard(title: "اختيار الرحلة") {
                            bookingButton("أذهب وأرجع", subtitle: "دهوك إلى الموصل ثم العودة", outbound: true, returnTrip: true, data: data)
                            bookingButton("أذهب فقط", subtitle: "دهوك إلى الموصل", outbound: true, returnTrip: false, data: data)
                            bookingButton("أرجع فقط", subtitle: "الموصل إلى دهوك", outbound: false, returnTrip: true, data: data)
                            bookingButton("لا أداوم", subtitle: "لا حجز لأي رحلة", outbound: false, returnTrip: false, data: data)
                        }
                        Text("رقم المسار: \(subscription.routeId)").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("تسجيل الخروج", role: .destructive) { state.signOut() }
                }.padding()
            }.navigationTitle("كوستر الجامعة").toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") } } }
        }.navigationViewStyle(.stack)
    }

    private func seatsCard(_ seats: NativeSeats) -> some View {
        NativeCard(title: "المقاعد المتبقية") {
            seatRow("ذهاب", free: (seats.capacity ?? 0) - (seats.outboundTaken ?? 0), capacity: seats.capacity ?? 0)
            seatRow("عودة", free: (seats.capacity ?? 0) - (seats.returnTaken ?? 0), capacity: seats.capacity ?? 0)
        }
    }

    private func seatRow(_ title: String, free: Int, capacity: Int) -> some View {
        VStack(alignment: .trailing) { HStack { Text("\(max(0, free)) مقعد").foregroundStyle(free > capacity / 2 ? .green : .orange); Spacer(); Text(title) }; ProgressView(value: Double(max(0, free)), total: Double(max(1, capacity))) }
    }

    private func bookingButton(_ title: String, subtitle: String, outbound: Bool, returnTrip: Bool, data: NativeStudentData) -> some View {
        let selected = data.attendance?.outbound == outbound && data.attendance?.returnTrip == returnTrip
        let capacity = data.seats?.capacity ?? 0
        let full = (outbound && (data.seats?.outboundTaken ?? 0) >= capacity && data.attendance?.outbound != true) || (returnTrip && (data.seats?.returnTaken ?? 0) >= capacity && data.attendance?.returnTrip != true)
        return Button { Task { await model.choose(outbound: outbound, returnTrip: returnTrip) } } label: { HStack { Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? .green : .secondary); VStack(alignment: .trailing) { Text(title).font(.headline); Text(full ? "ممتلئ" : subtitle).font(.caption).foregroundStyle(full ? .red : .secondary) }; Spacer() } .padding(12).background(selected ? Color.green.opacity(0.14) : Color.secondary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10)) }.disabled(model.isBusy || full || data.subscription?.status != "active")
    }

    private var mapView: some View {
        NavigationView { NativeBusMapView(model: model).navigationTitle("أين الكوستر؟") }.navigationViewStyle(.stack)
    }

    private var announcementsView: some View {
        NavigationView { ScrollView { VStack(alignment: .trailing, spacing: 12) { if model.data?.announcements.isEmpty != false { Text("لا توجد تنبيهات حالياً.").foregroundStyle(.secondary).padding() } else { ForEach(model.data?.announcements ?? [], id: \.stableId) { item in NativeCard(title: item.title) { Text(item.message); Text(item.createdAt).font(.caption).foregroundStyle(.secondary) } } } }.padding() }.navigationTitle("التنبيهات") }.navigationViewStyle(.stack)
    }

    private var historyView: some View {
        NavigationView { List(model.data?.history ?? []) { item in HStack { Text(tripLabel(item.outbound, item.returnTrip)); Spacer(); Text(item.attendanceDate).font(.caption).monospacedDigit() } }.navigationTitle("سجل دوامك") }.navigationViewStyle(.stack)
    }

    private func tripLabel(_ outbound: Bool, _ returnTrip: Bool) -> String { outbound && returnTrip ? "ذهاب وعودة" : outbound ? "ذهاب فقط" : returnTrip ? "عودة فقط" : "لا يداوم" }
}

struct NativeBusMapView: View {
    @ObservedObject var model: NativeStudentViewModel
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 36.62, longitude: 43.05), span: MKCoordinateSpan(latitudeDelta: 1.4, longitudeDelta: 1.4))
    var body: some View {
        VStack(spacing: 0) {
            Map(coordinateRegion: $region, annotationItems: model.busLocation?.coordinate.map { [NativeMapPin(coordinate: $0)] } ?? []) { pin in MapAnnotation(coordinate: pin.coordinate) { Image(systemName: "bus.fill").font(.title).foregroundColor(.green).padding(10).background(.regularMaterial).clipShape(Circle()) } }.frame(minHeight: 380)
            if let location = model.busLocation, let updated = location.updatedAt {
                Text(location.isSharing == true ? "الموقع مباشر · آخر تحديث \(relativeTime(updated))" : "صاحب الكوستر لا يشارك موقعه حالياً.").frame(maxWidth: .infinity, alignment: .trailing).padding().foregroundStyle(location.isSharing == true ? .green : .secondary)
            } else { Text("جاري تحميل موقع الحافلة…").frame(maxWidth: .infinity, alignment: .trailing).padding() }
            Button("تحديث موقع الحافلة") { Task { await model.refreshBus() } }.padding(.bottom)
        }.task { await model.refreshBus() }
        .onChange(of: model.busLocation?.lat) { _ in if let coordinate = model.busLocation?.coordinate { region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)) } }
    }
    private func relativeTime(_ value: String) -> String { value.replacingOccurrences(of: "T", with: " ").prefix(16).description }
}

struct NativeMapPin: Identifiable { let id = UUID(); let coordinate: CLLocationCoordinate2D }
