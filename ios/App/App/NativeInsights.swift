import Foundation
import SwiftUI
import CoreLocation

struct NativeRoadPulseSample: Codable, Identifiable {
    let direction: String
    let weekday: Int
    let sampleCount: Int?
    let medianDurationSeconds: Double?
    let allWeekSampleCount: Int?
    let allWeekMedianDurationSeconds: Double?
    var id: String { "\(direction)-\(weekday)" }
    enum CodingKeys: String, CodingKey {
        case direction, weekday
        case sampleCount = "sample_count"
        case medianDurationSeconds = "median_duration_seconds"
        case allWeekSampleCount = "all_week_sample_count"
        case allWeekMedianDurationSeconds = "all_week_median_duration_seconds"
    }
}

struct NativeDestination {
    let lat: Double
    let lng: Double
    let radiusMeters: Double
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
}

extension NativeStudentService {
    func roadPulse() async throws -> [NativeRoadPulseSample] {
        let data = try await raw(path: "/rest/v1/rpc/get_road_pulse", method: "POST", body: [:])
        return try decoder.decode([NativeRoadPulseSample].self, from: data)
    }

    func destination(direction: String) async throws -> NativeDestination? {
        let key = direction == "return" ? "arrival_destination_return" : "arrival_destination_outbound"
        let data = try await raw(path: "/rest/v1/system_settings?key=eq.\(key)&select=value&limit=1")
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let rawValue = rows.first?["value"] else { return nil }
        let value: Any
        if let string = rawValue as? String, let decoded = try? JSONSerialization.jsonObject(with: Data(string.utf8)) { value = decoded } else { value = rawValue }
        guard let object = value as? [String: Any], let lat = Double(String(describing: object["lat"] ?? "")), let lng = Double(String(describing: object["lng"] ?? "")), let radius = Double(String(describing: object["radiusMeters"] ?? "")), radius > 0 else { return nil }
        return NativeDestination(lat: lat, lng: lng, radiusMeters: radius)
    }
}

struct NativeInsightsView: View {
    @ObservedObject var model: NativeStudentViewModel
    @State private var samples: [NativeRoadPulseSample] = []
    @State private var loading = true
    var body: some View {
        NavigationView {
            ScrollView { VStack(alignment: .trailing, spacing: 16) {
                NativeCard(title: "نبض الطريق · مدة الرحلة") {
                    if loading { ProgressView("جاري تحميل سجل الرحلات…") }
                    else { pulse(direction: "outbound", title: "الذهاب"); pulse(direction: "return", title: "العودة") }
                    Text("هذه أوساط تاريخية للرحلات المكتملة وليست حالة المرور الحالية أو ضماناً لوقت الوصول.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding() }.navigationTitle("التحليلات")
        }.navigationViewStyle(.stack).task { await reload() }
    }
    private func reload() async { loading = true; defer { loading = false }; samples = (try? await model.service.roadPulse()) ?? [] }
    private func pulse(direction: String, title: String) -> some View {
        let weekday = weekday(model.data?.date)
        let row = samples.first { $0.direction == direction && $0.weekday == weekday }
        let count = row?.sampleCount ?? 0
        let comparable = row?.medianDurationSeconds
        let weekly = row?.allWeekMedianDurationSeconds
        return VStack(alignment: .trailing, spacing: 6) {
            Text(title).font(.headline)
            if count >= 4, let comparable, let weekly {
                Text("الوسيط التاريخي: \(duration(comparable))")
                Text("وسيط الأسبوع: \(duration(weekly)) · \(comparable >= weekly ? "أطول بـ \(duration(comparable - weekly))" : "أقصر بـ \(duration(weekly - comparable))")").font(.caption).foregroundStyle(.secondary)
                Text("من \(count) رحلات مماثلة").font(.caption).foregroundStyle(.secondary)
            } else { Text("نجمع بيانات الرحلات · \(count)/4 رحلات مماثلة").foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .trailing).padding(12).background(Color.secondary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private func weekday(_ value: String?) -> Int { guard let value, let date = ISO8601DateFormatter().date(from: value + "T12:00:00Z") else { return 0 }; return Calendar(identifier: .gregorian).component(.weekday, from: date) - 1 }
    private func duration(_ seconds: Double) -> String { let minutes = Int((seconds / 60).rounded()); return minutes < 60 ? "\(minutes) دقيقة" : "\(minutes / 60) ساعة و\(minutes % 60) دقيقة" }
}

struct NativeArrivalReminderView: View {
    @ObservedObject var model: NativeStudentViewModel
    @AppStorage("coaster.native.arrival.enabled") private var enabled = false
    @AppStorage("coaster.native.arrival.direction") private var direction = "outbound"
    @AppStorage("coaster.native.arrival.message") private var reminderMessage = "اقترب الكوستر من وجهته."
    @State private var destination: NativeDestination?
    @State private var lastBus: NativeBusLocation?
    @State private var status = "جارٍ التحقق من الوجهة…"
    @State private var notified = false
    var body: some View {
        NativeCard(title: "تذكير الوصول") {
            Text("ينبهك التطبيق عند اقتراب موقع الكوستر من الوجهة. لا نجمع موقع هاتفك، ويعمل التذكير أثناء بقاء التطبيق مفتوحاً ونشطاً.").font(.caption).foregroundStyle(.secondary)
            Picker("اتجاه الرحلة", selection: $direction) { Text("الذهاب").tag("outbound"); Text("الإياب").tag("return") }.pickerStyle(.segmented)
            TextField("نص التذكير", text: $reminderMessage).textFieldStyle(.roundedBorder)
            Text(status).font(.caption).foregroundStyle(.secondary)
            Button(enabled ? "إيقاف تذكير الوصول" : "تفعيل تذكير الوصول") { enabled.toggle(); notified = false; if enabled { Task { await refresh() } } }.buttonStyle(.borderedProminent).disabled(destination == nil && !enabled)
        }.task { await monitor() }.onChange(of: direction) { _ in Task { await refresh() } }
    }
    private func monitor() async { while !Task.isCancelled { await refresh(); try? await Task.sleep(nanoseconds: 15_000_000_000) } }
    private func refresh() async {
        destination = try? await model.service.destination(direction: direction)
        lastBus = try? await model.service.busLocation()
        guard let destination else { status = "وجهة هذا الاتجاه غير متاحة حالياً."; return }
        guard lastBus?.isSharing == true, let coordinate = lastBus?.coordinate else { status = "مشاركة موقع الكوستر متوقفة."; return }
        if distance(from: coordinate, to: destination.coordinate) <= destination.radiusMeters {
            status = "اقترب الكوستر من الوجهة."
            if enabled && !notified { notified = true; model.message = reminderMessage }
        } else { notified = false; status = "بانتظار اقتراب الكوستر من الوجهة." }
    }
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double { let earth = 6_371_000.0; let p1 = from.latitude * .pi / 180; let p2 = to.latitude * .pi / 180; let dp = (to.latitude - from.latitude) * .pi / 180; let dl = (to.longitude - from.longitude) * .pi / 180; let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2); return earth * 2 * atan2(sqrt(a), sqrt(1 - a)) }
}
