import Foundation
import SwiftUI

struct NativeAdminAttendance: Codable, Identifiable {
    let userId: String
    let outbound: Bool
    let returnTrip: Bool
    let fullName: String?
    let phone: String?
    let groupType: String?
    var id: String { userId }
    enum CodingKeys: String, CodingKey { case userId = "user_id", outbound, returnTrip = "return_trip", profile = "profiles" }
    enum ProfileKeys: String, CodingKey { case fullName = "full_name", phone, groupType = "group_type" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId); outbound = try c.decode(Bool.self, forKey: .outbound); returnTrip = try c.decode(Bool.self, forKey: .returnTrip)
        let p = try? c.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profile); fullName = try? p?.decode(String.self, forKey: .fullName); phone = try? p?.decode(String.self, forKey: .phone); groupType = try? p?.decode(String.self, forKey: .groupType)
    }
}

struct NativeAdminSubscription: Codable, Identifiable {
    let id: Int
    let status: String
    let userId: String
    let endDate: String?
    let fullName: String?
    let phone: String?
    let groupType: String?
    enum CodingKeys: String, CodingKey { case id, status, userId = "user_id", endDate = "end_date", profile = "profiles" }
    enum ProfileKeys: String, CodingKey { case fullName = "full_name", phone, groupType = "group_type" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self); id = try c.decode(Int.self, forKey: .id); status = try c.decode(String.self, forKey: .status); userId = try c.decode(String.self, forKey: .userId); endDate = try? c.decode(String.self, forKey: .endDate)
        let p = try? c.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profile); fullName = try? p?.decode(String.self, forKey: .fullName); phone = try? p?.decode(String.self, forKey: .phone); groupType = try? p?.decode(String.self, forKey: .groupType)
    }
}

struct NativeChatReport: Codable, Identifiable {
    let messageId: String
    let displayName: String
    let body: String
    let createdAt: String
    let reportCount: Int
    var id: String { messageId }
    enum CodingKeys: String, CodingKey { case messageId = "message_id", displayName = "display_name", body, createdAt = "created_at", reportCount = "report_count" }
}

struct NativeAdminService {
    let client: NativeSupabaseClient
    let accessToken: String
    let decoder = JSONDecoder()
    func attendance(date: String) async throws -> [NativeAdminAttendance] { try await list("/rest/v1/daily_attendance?attendance_date=eq.\(date)&select=user_id,outbound,return_trip,profiles(full_name,phone,group_type)") }
    func subscriptions() async throws -> [NativeAdminSubscription] { try await list("/rest/v1/subscriptions?select=id,status,user_id,end_date,profiles(full_name,phone,group_type)&order=created_at.desc&limit=100") }
    func updateSubscription(id: Int, status: String) async throws { _ = try await raw("/rest/v1/subscriptions?id=eq.\(id)", method: "PATCH", body: ["status": status]) }
    func updateEndDate(id: Int, date: String) async throws { _ = try await raw("/rest/v1/subscriptions?id=eq.\(id)", method: "PATCH", body: ["end_date": date]) }
    func resetPassword(userId: String, password: String) async throws { _ = try await rpc("admin_reset_password", body: ["p_user_id": userId, "p_new_password": password]) }
    func createCodes(group: String, count: Int) async throws -> [String] { let data = try await rpc("admin_create_codes", body: ["p_group": group, "p_count": count]); if let rows = try? decoder.decode([[String: String]].self, from: data) { return rows.compactMap { $0["new_code"] } }; return [] }
    func reports(room: String) async throws -> [NativeChatReport] { try await rpcDecode("admin_list_student_chat_reports", body: ["p_room": room, "p_limit": 100]) }
    func deleteMessage(room: String, messageId: String) async throws { _ = try await rpc("admin_delete_student_chat_message", body: ["p_room": room, "p_message_id": messageId]) }
    func createAnnouncement(title: String, message: String, target: String?) async throws { _ = try await raw("/rest/v1/announcements", method: "POST", body: ["title": title, "message": message, "target_group": target as Any]) }
    func hideAnnouncement(id: Int) async throws { _ = try await raw("/rest/v1/announcements?id=eq.\(id)", method: "PATCH", body: ["is_active": false]) }
    private func list<T: Decodable>(_ path: String) async throws -> [T] { try decoder.decode([T].self, from: try await raw(path)) }
    private func rpcDecode<T: Decodable>(_ name: String, body: Any) async throws -> [T] { try decoder.decode([T].self, from: try await rpc(name, body: body)) }
    private func rpc(_ name: String, body: Any) async throws -> Data { try await raw("/rest/v1/rpc/\(name)", method: "POST", body: body) }
    private func raw(_ path: String, method: String = "GET", body: Any? = nil) async throws -> Data { let encoded = body.flatMap { try? JSONSerialization.data(withJSONObject: $0) }; let (data, response) = try await client.request(path: path, method: method, body: encoded, accessToken: accessToken); guard (200..<300).contains(response.statusCode) else { throw NativeError.server("تعذر تنفيذ عملية المشرف (\(response.statusCode)).") }; return data }
}

@MainActor
final class NativeAdminViewModel: ObservableObject {
    @Published var date: String
    @Published var attendance: [NativeAdminAttendance] = []
    @Published var subscriptions: [NativeAdminSubscription] = []
    @Published var reports: [NativeChatReport] = []
    @Published var codes: [String] = []
    @Published var busy = false
    @Published var error: String?
    @Published var message: String?
    let service: NativeAdminService
    init(service: NativeAdminService) { self.service = service; date = NativeAdminViewModel.today(offset: 1) }
    func loadAttendance() async { do { attendance = try await service.attendance(date: date) } catch { error = error.localizedDescription } }
    func loadSubscriptions() async { do { subscriptions = try await service.subscriptions() } catch { error = error.localizedDescription } }
    func loadReports(room: String) async { do { reports = try await service.reports(room: room) } catch { error = error.localizedDescription } }
    func toggle(_ item: NativeAdminSubscription) async { busy = true; defer { busy = false }; do { try await service.updateSubscription(id: item.id, status: item.status == "active" ? "suspended" : "active"); message = "تم تحديث الاشتراك"; await loadSubscriptions() } catch { error = error.localizedDescription } }
    func makeCodes(group: String, count: Int) async { busy = true; defer { busy = false }; do { codes = try await service.createCodes(group: group, count: count); message = "تم إنشاء الرموز" } catch { error = error.localizedDescription } }
    func remove(report: NativeChatReport, room: String) async { do { try await service.deleteMessage(room: room, messageId: report.messageId); reports.removeAll { $0.id == report.id }; message = "تم حذف الرسالة" } catch { error = error.localizedDescription } }
    static func today(offset: Int) -> String { let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone(identifier: "Asia/Baghdad"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Calendar.current.date(byAdding: .day, value: offset, to: Date())!) }
}

struct NativeAdminDashboard: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var model: NativeAdminViewModel
    @State private var tab = 0
    @State private var group = "boys"
    @State private var count = 1
    @State private var announcementTitle = ""
    @State private var announcementMessage = ""
    init(service: NativeAdminService) { _model = StateObject(wrappedValue: NativeAdminViewModel(service: service)) }
    var body: some View {
        TabView(selection: $tab) { attendance.tabItem { Label("الحضور", systemImage: "person.3.fill") }.tag(0); subscriptions.tabItem { Label("المشتركون", systemImage: "person.crop.circle") }.tag(1); tools.tabItem { Label("الأدوات", systemImage: "wrench.and.screwdriver.fill") }.tag(2) }.environment(\.layoutDirection, .rightToLeft).task { await model.loadAttendance(); await model.loadSubscriptions() }.alert("لوحة المشرف", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("حسناً", role: .cancel) {} } message: { Text(model.error ?? "") }.alert("تم", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("حسناً", role: .cancel) {} } message: { Text(model.message ?? "") }
    }
    private var attendance: some View { NavigationView { List { DatePicker("تاريخ الرحلة", selection: Binding(get: { dateValue(model.date) }, set: { model.date = stringDate($0); Task { await model.loadAttendance() } }), displayedComponents: .date); Section("إحصاءات") { Text("ذهاب: \(model.attendance.filter { $0.outbound }.count) · عودة: \(model.attendance.filter { $0.returnTrip }.count)") }; Section("الركاب") { ForEach(model.attendance) { row in HStack { VStack(alignment: .trailing) { Text(row.fullName ?? "بدون اسم"); Text(row.phone ?? "").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(row.outbound && row.returnTrip ? "ذهاب وعودة" : row.outbound ? "ذهاب" : row.returnTrip ? "عودة" : "لا يداوم").font(.caption) } } } }.navigationTitle("الحضور") }.navigationViewStyle(.stack) }
    private var subscriptions: some View { NavigationView { List(model.subscriptions) { item in VStack(alignment: .trailing) { HStack { Text(item.fullName ?? "بدون اسم"); Spacer(); Text(item.status == "active" ? "فعال" : "موقوف").foregroundStyle(item.status == "active" ? .green : .red) }; Text(item.phone ?? "").font(.caption); if let endDate = item.endDate { Text("ينتهي: \(endDate)").font(.caption).foregroundStyle(.secondary) }; HStack { Button(item.status == "active" ? "إيقاف" : "تفعيل") { Task { await model.toggle(item) } }; Button("سجل") { } } } }.navigationTitle("المشتركون") }.navigationViewStyle(.stack) }
    private var tools: some View { NavigationView { ScrollView { VStack(alignment: .trailing, spacing: 16) { NativeCard(title: "مشاركة الموقع") { Button { state.toggleLocation() } label: { Label(state.locationSharing ? "إيقاف المشاركة" : "بدء مشاركة الموقع", systemImage: "location.fill") } }; NativeCard(title: "رموز الاشتراك") { Picker("المجموعة", selection: $group) { Text("الشباب").tag("boys"); Text("البنات").tag("girls") }.pickerStyle(.segmented); Stepper("العدد: \(count)", value: $count, in: 1...100); Button("إنشاء الرموز") { Task { await model.makeCodes(group: group, count: count) } }; if !model.codes.isEmpty { Text(model.codes.joined(separator: "\n")).font(.system(.body, design: .monospaced)).textSelection(.enabled) } }; NativeCard(title: "إرسال تنبيه") { TextField("العنوان", text: $announcementTitle).textFieldStyle(.roundedBorder); TextEditor(text: $announcementMessage).frame(height: 90).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3))); Button("نشر التنبيه") { Task { do { try await model.service.createAnnouncement(title: announcementTitle, message: announcementMessage, target: nil); model.message = "تم نشر التنبيه"; announcementTitle = ""; announcementMessage = "" } catch { model.error = error.localizedDescription } } }.disabled(announcementTitle.isEmpty || announcementMessage.isEmpty) }; NativeCard(title: "بلاغات الدردشة") { Picker("الغرفة", selection: $group) { Text("الشباب").tag("boys"); Text("البنات").tag("girls") }.pickerStyle(.segmented); Button("تحميل البلاغات") { Task { await model.loadReports(room: group) } }; ForEach(model.reports) { report in VStack(alignment: .trailing) { Text("\(report.displayName) · \(report.reportCount) بلاغ").font(.headline); Text(report.body); Button("حذف الرسالة") { Task { await model.remove(report: report, room: group) } }.foregroundStyle(.red) }.padding(.vertical, 6) } } }.padding() }.navigationTitle("أدوات المشرف") }.navigationViewStyle(.stack) }
    private func dateValue(_ value: String) -> Date { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "Asia/Baghdad"); return f.date(from: value) ?? Date() }
    private func stringDate(_ value: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "Asia/Baghdad"); return f.string(from: value) }
}
