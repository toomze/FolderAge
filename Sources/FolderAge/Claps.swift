import Foundation
import Combine

/// «Похлопать»: общий счётчик хлопков, как в Medium. С одного компьютера — до 50 хлопков.
/// На сервер уходит только случайный номер установки и число хлопков.
final class ClapStore: ObservableObject {
    static let shared = ClapStore()
    static let maxMine = 50

    @Published private(set) var total: Int
    @Published private(set) var mine: Int

    private let d = UserDefaults.standard
    private var pending = 0
    private var sendWork: DispatchWorkItem?

    private var deviceID: String {
        if let s = d.string(forKey: "clapDeviceID") { return s }
        let s = UUID().uuidString
        d.set(s, forKey: "clapDeviceID")
        return s
    }

    private init() {
        total = d.integer(forKey: "clapTotal")
        mine = d.integer(forKey: "clapMine")
    }

    var canClap: Bool { mine < ClapStore.maxMine }

    /// Общее число обновляем не чаще раза в сутки.
    func refreshIfStale() {
        guard let url = AppConfig.clapsURL else { return }
        let last = d.object(forKey: "clapFetchedAt") as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= 86_400 else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let r = try? JSONDecoder().decode(Reply.self, from: data) else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.total = max(r.total, self.total)
                self.d.set(self.total, forKey: "clapTotal")
                self.d.set(Date(), forKey: "clapFetchedAt")
            }
        }.resume()
    }

    func clap() {
        guard canClap, AppConfig.clapsURL != nil else { return }
        mine += 1; total += 1; pending += 1
        d.set(mine, forKey: "clapMine"); d.set(total, forKey: "clapTotal")
        // Несколько быстрых хлопков уходят одним запросом.
        sendWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.send() }
        sendWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func send() {
        guard let url = AppConfig.clapsURL, pending > 0 else { return }
        let n = pending; pending = 0
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["id": deviceID, "n": n])
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let data, let r = try? JSONDecoder().decode(Reply.self, from: data) else {
                    self.pending += n          // нет сети — отправим со следующим хлопком
                    return
                }
                self.total = max(r.total, self.total)
                if let y = r.yours { self.mine = max(y, self.mine) }
                self.d.set(self.total, forKey: "clapTotal"); self.d.set(self.mine, forKey: "clapMine")
                self.d.set(Date(), forKey: "clapFetchedAt")
            }
        }.resume()
    }

    private struct Reply: Decodable { let total: Int; let yours: Int? }
}
