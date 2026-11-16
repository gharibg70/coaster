import Foundation
import Security
import UserNotifications
import UIKit

final class NativeKeychain {
    static let shared = NativeKeychain()
    private let service = "com.gharibg70.coaster"
    private init() {}
    func set(_ value: String, key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
    }
    func get(_ key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    func remove(_ key: String) { let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]; SecItemDelete(query as CFDictionary) }
}

final class NativeAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static weak var shared: NativeAppDelegate?
    private let tokenKey = "coaster.native.apnsToken"
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool { Self.shared = self; UNUserNotificationCenter.current().delegate = self; return true }
    func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do { let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge]); if granted { await MainActor.run { UIApplication.shared.registerForRemoteNotifications() } }; return granted } catch { return false }
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) { let token = deviceToken.map { String(format: "%02x", $0) }.joined(); NativeKeychain.shared.set(token, key: tokenKey); NotificationCenter.default.post(name: .nativeAPNSTokenReceived, object: token) }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) { NotificationCenter.default.post(name: .nativeAPNSRegistrationFailed, object: error) }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .badge] }
}

extension Notification.Name {
    static let nativeAPNSTokenReceived = Notification.Name("coaster.native.apnsTokenReceived")
    static let nativeAPNSRegistrationFailed = Notification.Name("coaster.native.apnsRegistrationFailed")
}
