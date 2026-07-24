import Foundation

@Observable
final class ProfileStore {
    var profile: Profile {
        didSet { persist() }
    }

    private let defaultsKey = "shorty.profile"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(Profile.self, from: data) {
            profile = decoded
        } else {
            profile = .empty
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    func completeOnboarding(myName: String, roommateName: String) {
        profile.myName = myName
        profile.roommateName = roommateName
        profile.hasSharedRoom = true
    }

    func reset() {
        profile = .empty
    }
}
