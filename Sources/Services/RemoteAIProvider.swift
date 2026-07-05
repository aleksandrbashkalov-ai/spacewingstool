import Foundation

public actor RemoteAIProvider: AIProvider {
    public static let shared = RemoteAIProvider()

    private var session: URLSession
    private var endpointURL: String
    private var apiKey: String
    private var modelName: String
    private var maxTokens: Int
    private var temperature: Double

    public var isConfigured: Bool {
        !endpointURL.isEmpty && !apiKey.isEmpty
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        self.endpointURL = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiEndpointURL)
            ?? "https://api.openai.com/v1/chat/completions"
        self.apiKey = KeychainService.load(key: Constants.UserDefaultsKeys.aiAPIKey) ?? ""
        self.modelName = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiModelName)
            ?? "gpt-4o-mini"
        self.maxTokens = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.aiMaxTokens) as? Int ?? 1024
        self.temperature = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.aiTemperature) as? Double ?? 0.7
    }

    public func reloadConfiguration() {
        endpointURL = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiEndpointURL)
            ?? "https://api.openai.com/v1/chat/completions"
        apiKey = KeychainService.load(key: Constants.UserDefaultsKeys.aiAPIKey) ?? ""
        modelName = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiModelName)
            ?? "gpt-4o-mini"
        maxTokens = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.aiMaxTokens) as? Int ?? 1024
        temperature = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.aiTemperature) as? Double ?? 0.7
    }

    public func generateSummary(systemPrompt: String, userMessage: String) async throws -> String {
        guard isConfigured else {
            throw AIProviderError.notConfigured("Set API key and endpoint URL in settings")
        }

        guard let url = URL(string: endpointURL) else {
            throw AIProviderError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage],
            ],
            "max_tokens": maxTokens,
            "temperature": temperature,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.requestFailed("No HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIProviderError.requestFailed("HTTP \(httpResponse.statusCode): \(bodyStr)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIProviderError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
