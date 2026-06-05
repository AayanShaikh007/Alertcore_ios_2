import Foundation

actor NetworkClient {
    static let shared = NetworkClient()
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 5.0
        // disable caching for status polls
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    func baseUrl(ip: String, port: Int) -> URL {
        var comps = URLComponents()
        comps.scheme = "http"
        comps.host = ip
        comps.port = port
        return comps.url!
    }

    func fetchStatus(ip: String, port: Int) async throws -> StatusDto {
        let url = baseUrl(ip: ip, port: port).appendingPathComponent("api/status")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(StatusDto.self, from: data)
    }

    func fetchHistory(ip: String, port: Int, minutes: Int) async throws -> [DistanceSampleDto] {
        var comps = URLComponents(url: baseUrl(ip: ip, port: port).appendingPathComponent("api/history"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "minutes", value: String(minutes))]
        let url = comps.url!
        let (data, _) = try await session.data(from: url)
        let dto = try JSONDecoder().decode(HistoryDto.self, from: data)
        return dto.samples
    }

    func updateThreshold(ip: String, port: Int, threshold: Int) async throws -> StatusDto {
        let url = baseUrl(ip: ip, port: port).appendingPathComponent("api/threshold")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ThresholdRequestDto(thresholdCm: threshold)
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(StatusDto.self, from: data)
    }

    func health(ip: String, port: Int) async throws -> HealthDto {
        let url = baseUrl(ip: ip, port: port).appendingPathComponent("api/health")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(HealthDto.self, from: data)
    }
}
