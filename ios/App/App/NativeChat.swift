import Foundation
import SwiftUI

struct NativeChatMessage: Codable, Identifiable {
    let roomGroup: String
    let isAdmin: Bool
    let id: String
    let displayName: String
    let body: String
    let createdAt: String
    enum CodingKeys: String, CodingKey {
        case roomGroup = "room_group"
        case isAdmin = "is_admin"
        case id
        case displayName = "display_name"
        case body
        case createdAt = "created_at"
    }
}

struct NativeChatService {
    let client: NativeSupabaseClient
    let accessToken: String
    let decoder = JSONDecoder()

    func access(room: String) async throws -> Bool {
        guard room == "boys" || room == "girls" else { throw NativeError.server("مجموعة الدردشة غير صالحة.") }
        let data = try await raw(path: "/rest/v1/rpc/chat_room_access", method: "POST", body: ["p_room": room])
        return try decoder.decode(Bool.self, from: data)
    }

    func list(room: String) async throws -> [NativeChatMessage] {
        let path = "/rest/v1/student_chat_messages?room_group=eq.\(room)&select=room_group,is_admin,id,display_name,body,created_at&order=created_at.desc&limit=100"
        let data = try await raw(path: path)
        return try decoder.decode([NativeChatMessage].self, from: data).reversed()
    }

    func send(room: String, body: String) async throws -> NativeChatMessage {
        let value = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw NativeError.server("لا يمكن إرسال رسالة فارغة.") }
        guard value.count <= 500 else { throw NativeError.server("الحد الأقصى للرسالة 500 محرف.") }
        let data = try await raw(path: "/rest/v1/rpc/send_chat_room_message", method: "POST", body: ["p_room": room, "p_body": value])
        if let rows = try? decoder.decode([NativeChatMessage].self, from: data), let row = rows.first { return row }
        return try decoder.decode(NativeChatMessage.self, from: data)
    }

    func report(room: String, messageId: String, reason: String) async throws {
        guard ["spam", "abuse", "other"].contains(reason) else { throw NativeError.server("سبب البلاغ غير صالح.") }
        _ = try await raw(path: "/rest/v1/rpc/report_student_chat_room_message", method: "POST", body: ["p_room": room, "p_message_id": messageId, "p_reason": reason])
    }

    private func raw(path: String, method: String = "GET", body: Any? = nil) async throws -> Data {
        let encoded = body.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        let (data, response) = try await client.request(path: path, method: method, body: encoded, accessToken: accessToken)
        guard (200..<300).contains(response.statusCode) else { throw NativeError.server("تعذر الاتصال بالدردشة (\(response.statusCode)).") }
        return data
    }
}

@MainActor
final class NativeChatViewModel: ObservableObject {
    @Published var messages: [NativeChatMessage] = []
    @Published var draft = ""
    @Published var loading = true
    @Published var busy = false
    @Published var allowed = false
    @Published var status = "جارٍ التحقق من صلاحية الدردشة…"
    @Published var error: String?
    let service: NativeChatService
    let room: String
    private var timer: Task<Void, Never>?

    init(service: NativeChatService, room: String) { self.service = service; self.room = room }
    deinit { timer?.cancel() }

    func start() async {
        guard room == "boys" || room == "girls" else { allowed = false; loading = false; status = "مجموعة الدردشة غير صالحة."; return }
        do { allowed = try await service.access(room: room); if allowed { await reload() } else { loading = false; status = "ليس لديك صلاحية لعرض غرفة الدردشة هذه." } }
        catch { loading = false; self.error = error.localizedDescription; status = "تعذر التحقق من صلاحية الدردشة." }
        timer = Task { [weak self] in
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 30_000_000_000); if Task.isCancelled { return }; await self?.reload() }
        }
    }

    func reload() async {
        guard allowed else { return }
        do { messages = try await service.list(room: room); loading = false; status = "" }
        catch { loading = false; self.error = error.localizedDescription }
    }

    func send() async {
        guard allowed else { return }
        busy = true; defer { busy = false }
        do { let message = try await service.send(room: room, body: draft); messages.append(message); messages = Array(messages.suffix(100)); draft = ""; status = "تم إرسال الرسالة." }
        catch { self.error = error.localizedDescription }
    }

    func report(_ message: NativeChatMessage, reason: String) async {
        do { try await service.report(room: room, messageId: message.id, reason: reason); status = "تم إرسال البلاغ للمراجعة." }
        catch { self.error = error.localizedDescription }
    }
}

struct NativeChatView: View {
    @StateObject private var model: NativeChatViewModel
    @State private var reason = "spam"
    init(service: NativeChatService, room: String) { _model = StateObject(wrappedValue: NativeChatViewModel(service: service, room: room)) }
    var body: some View {
        VStack(spacing: 0) {
            if !model.status.isEmpty { Text(model.status).font(.caption).foregroundStyle(.secondary).padding(.horizontal) }
            if model.loading { ProgressView("جاري تحميل الرسائل…").padding() }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 10) {
                        ForEach(model.messages) { message in
                            VStack(alignment: .trailing, spacing: 5) {
                                HStack { Text(message.isAdmin ? "\(message.displayName) (مشرف)" : message.displayName).font(.headline); Spacer(); Text(message.createdAt.replacingOccurrences(of: "T", with: " ").prefix(16)).font(.caption).foregroundStyle(.secondary) }
                                Text(message.body).frame(maxWidth: .infinity, alignment: .trailing)
                                Menu { Picker("سبب الإبلاغ", selection: $reason) { Text("مزعج").tag("spam"); Text("إساءة").tag("abuse"); Text("آخر").tag("other") }; Button("إبلاغ") { Task { await model.report(message, reason: reason) } } } label: { Text("إبلاغ").font(.caption) }
                            }.padding(10).background(Color.secondary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10)).id(message.id)
                        }
                    }.padding()
                }.onChange(of: model.messages.count) { _ in if let last = model.messages.last { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            HStack(alignment: .bottom) { TextEditor(text: $model.draft).frame(minHeight: 42, maxHeight: 90).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3))); Button { Task { await model.send() } } label: { Image(systemName: "paperplane.fill").padding(10) }.disabled(model.busy || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding()
        }.navigationTitle("دردشة \(model.room == "boys" ? "الشباب" : "البنات")").task { await model.start() }.alert("الدردشة", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("حسناً", role: .cancel) {} } message: { Text(model.error ?? "") }
    }
}
