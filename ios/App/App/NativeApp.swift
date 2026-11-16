import Foundation
import SwiftUI
import CoreLocation

struct NativeProfile: Codable, Identifiable {
    let id: String
    let fullName: String?
    let phone: String?
    let role: String?
    let groupType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case phone
        case role
        case groupType = "group_type"
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: AuthUser
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthUser: Codable { let id: String }

struct NativeSupabaseClient {
    let baseURL: URL
    let anonKey: String
    let decoder = JSONDecoder()

    func request(path: String, method: String = "GET", body: Data? = nil, accessToken: String? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: baseURL.absoluteString + path) else { throw NativeError.invalidConfiguration }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NativeError.network("استجابة غير صالحة من الخادم") }
        return (data, http)
    }

    func signIn(phone: String, password: String) async throws -> AuthResponse {
        let email = phone.contains("@") ? phone.trimmingCharacters(in: .whitespacesAndNewlines) : phone.filter { $0.isNumber } + "@bus.app"
        let body = try JSONEncoder().encode(["email": email, "password": password])
        let (data, response) = try await request(path: "/auth/v1/token?grant_type=password", method: "POST", body: body)
        guard (200..<300).contains(response.statusCode) else { throw NativeError.server(message(from: data) ?? "رقم الهاتف أو كلمة المرور غير صحيحة.") }
        return try decoder.decode(AuthResponse.self, from: data)
    }

    func signUp(name: String, phone: String, password: String) async throws -> AuthResponse {
        let email = phone.contains("@") ? phone.trimmingCharacters(in: .whitespacesAndNewlines) : phone.filter { $0.isNumber } + "@bus.app"
        let body: [String: Any] = ["email": email, "password": password, "data": ["full_name": name, "phone": phone]]
        let dataBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await request(path: "/auth/v1/signup", method: "POST", body: dataBody)
        guard (200..<300).contains(response.statusCode) else { throw NativeError.server(message(from: data) ?? "تعذر إنشاء الحساب.") }
        return try decoder.decode(AuthResponse.self, from: data)
    }

    func profile(userId: String, accessToken: String) async throws -> NativeProfile {
        let path = "/rest/v1/profiles?id=eq.\(userId)&select=id,full_name,phone,role,group_type&limit=1"
        let (data, response) = try await request(path: path, accessToken: accessToken)
        guard (200..<300).contains(response.statusCode) else { throw NativeError.server(message(from: data) ?? "تعذر تحميل الملف الشخصي") }
        let profiles = try decoder.decode([NativeProfile].self, from: data)
        guard let profile = profiles.first else { throw NativeError.server("لم يتم العثور على الملف الشخصي") }
        return profile
    }

    private func message(from data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
    }
}

enum NativeError: LocalizedError {
    case invalidConfiguration
    case network(String)
    case server(String)
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "إعداد الاتصال بالخدمة غير متاح في هذه النسخة."
        case .network(let message): return message
        case .server(let message): return message
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var profile: NativeProfile?
    @Published var isLoading = true
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var locationSharing = false
    let client: NativeSupabaseClient?
    private let accessTokenKey = "coaster.native.accessToken"
    private var accessToken: String?
    let location = NativeLocationManager()
    var nativeStudentService: NativeStudentService? {
        guard let client, let accessToken else { return nil }
        return NativeStudentService(client: client, accessToken: accessToken)
    }
    var nativeChatService: NativeChatService? {
        guard let client, let accessToken else { return nil }
        return NativeChatService(client: client, accessToken: accessToken)
    }
    var nativeAdminService: NativeAdminService? {
        guard let client, let accessToken else { return nil }
        return NativeAdminService(client: client, accessToken: accessToken)
    }

    init() {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
           !urlString.isEmpty, !key.isEmpty, let url = URL(string: urlString) {
            client = NativeSupabaseClient(baseURL: url, anonKey: key)
        } else { client = nil }
        accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
        Task { await restoreSession() }
    }

    func restoreSession() async {
        defer { isLoading = false }
        guard let client, let accessToken else { return }
        do {
            let userId = UserDefaults.standard.string(forKey: "coaster.native.userId") ?? ""
            profile = try await client.profile(userId: userId, accessToken: accessToken)
        } catch { signOut() }
    }

    func signIn(phone: String, password: String) async {
        errorMessage = nil; isBusy = true
        defer { isBusy = false }
        do {
            guard let client else { throw NativeError.invalidConfiguration }
            let response = try await client.signIn(phone: phone, password: password)
            accessToken = response.accessToken
            UserDefaults.standard.set(response.accessToken, forKey: accessTokenKey)
            UserDefaults.standard.set(response.user.id, forKey: "coaster.native.userId")
            profile = try await client.profile(userId: response.user.id, accessToken: response.accessToken)
        } catch { errorMessage = error.localizedDescription }
    }

    func signUp(name: String, phone: String, password: String, code: String) async {
        errorMessage = nil; isBusy = true
        defer { isBusy = false }
        do {
            guard let client else { throw NativeError.invalidConfiguration }
            let response = try await client.signUp(name: name, phone: phone, password: password)
            guard !response.accessToken.isEmpty else { throw NativeError.server("فعّل التسجيل التلقائي للبريد في إعدادات Supabase.") }
            accessToken = response.accessToken
            UserDefaults.standard.set(response.accessToken, forKey: accessTokenKey)
            UserDefaults.standard.set(response.user.id, forKey: "coaster.native.userId")
            try await NativeStudentService(client: client, accessToken: response.accessToken).redeem(code: code)
            profile = try await client.profile(userId: response.user.id, accessToken: response.accessToken)
        } catch { errorMessage = error.localizedDescription }
    }

    func signOut() {
        accessToken = nil; profile = nil; location.stop()
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: "coaster.native.userId")
    }

    func toggleLocation() {
        if locationSharing { location.stop(); locationSharing = false }
        else { location.start(); locationSharing = true }
    }
}

final class NativeLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyBest }
    func start() { manager.requestWhenInUseAuthorization(); manager.startUpdatingLocation() }
    func stop() { manager.stopUpdatingLocation() }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        Group {
            if state.isLoading { ProgressView("جاري التحميل…") }
            else if let profile = state.profile {
                if profile.role == "admin", let service = state.nativeAdminService { NativeAdminDashboard(service: service) }
                else if let service = state.nativeStudentService { StudentHomeView(service: service, profileId: profile.id) }
                else { LoginView() }
            }
            else { LoginView() }
        }
        .tint(Color(red: 0.04, green: 0.72, blue: 0.47))
        .alert("تنبيه", isPresented: Binding(get: { state.errorMessage != nil }, set: { if !$0 { state.errorMessage = nil } })) {
            Button("حسناً", role: .cancel) { state.errorMessage = nil }
        } message: { Text(state.errorMessage ?? "") }
    }
}

struct LoginView: View {
    @EnvironmentObject private var state: AppState
    @State private var register = false
    @State private var name = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var code = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("كوستر الجامعة").font(.system(size: 36, weight: .bold, design: .rounded))
                Text("دهوك ⟷ الموصل · احجز مقعدك بسهولة").foregroundStyle(.secondary)
                VStack(alignment: .trailing, spacing: 14) {
                    Text(register ? "حساب جديد" : "تسجيل الدخول").font(.title2.bold())
                    if register {
                        Text("الاسم الكامل")
                        TextField("مثال: أحمد محمد", text: $name).textContentType(.name).textFieldStyle(.roundedBorder)
                    }
                    Text("رقم الهاتف")
                    TextField("07XXXXXXXXX", text: $phone).textContentType(.telephoneNumber).keyboardType(.phonePad).textFieldStyle(.roundedBorder).multilineTextAlignment(.leading)
                    Text("كلمة المرور")
                    SecureField("••••••", text: $password).textContentType(register ? .newPassword : .password).textFieldStyle(.roundedBorder)
                    if register {
                        Text("رمز الاشتراك")
                        TextField("BUS-XXXX", text: $code).textFieldStyle(.roundedBorder).multilineTextAlignment(.leading)
                    }
                    Button { Task { if register { await state.signUp(name: name, phone: phone, password: password, code: code) } else { await state.signIn(phone: phone, password: password) } } } label: {
                        Text(state.isBusy ? "جارٍ التنفيذ…" : register ? "إنشاء الحساب" : "دخول").frame(maxWidth: .infinity).padding().background(Color.green).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }.disabled(state.isBusy || phone.isEmpty || password.count < 6 || (register && (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)))
                    Button(register ? "عندي حساب" : "ليس لدي حساب") { register.toggle() }.buttonStyle(.borderless)
                }.padding(22).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 20))
            }.padding(24).frame(maxWidth: 520)
        }.background(Color(uiColor: .systemBackground)).environment(\.layoutDirection, .rightToLeft)
    }
}

struct HomeView: View {
    @EnvironmentObject private var state: AppState
    let profile: NativeProfile
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .trailing, spacing: 18) {
                    Text("مرحباً، \(profile.fullName ?? "مستخدم")").font(.title.bold())
                    NativeCard(title: "الحساب") {
                        Label(profile.phone ?? "", systemImage: "phone.fill")
                        if let role = profile.role { Label(role == "admin" ? "مشرف" : "طالب", systemImage: "person.fill") }
                    }
                    NativeCard(title: "النسخة الأصلية") {
                        Text("هذه شاشة SwiftUI أصلية بدون واجهة ويب.").foregroundStyle(.secondary)
                        if profile.role == "admin" {
                            Button { state.toggleLocation() } label: {
                                Label(state.locationSharing ? "إيقاف مشاركة موقع الحافلة" : "بدء مشاركة موقع الحافلة", systemImage: state.locationSharing ? "location.slash.fill" : "location.fill")
                            }
                        }
                    }
                    Button("تسجيل الخروج", role: .destructive) { state.signOut() }
                }.padding()
        }.navigationTitle("كوستر الجامعة").toolbar { ToolbarItem(placement: .navigationBarLeading) { Text("أصلي").font(.caption).foregroundStyle(.secondary) } }
        }.navigationViewStyle(.stack).environment(\.layoutDirection, .rightToLeft)
    }
}

struct NativeCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .trailing, spacing: 10) { Text(title).font(.headline); content.frame(maxWidth: .infinity, alignment: .trailing) }
            .padding().background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
