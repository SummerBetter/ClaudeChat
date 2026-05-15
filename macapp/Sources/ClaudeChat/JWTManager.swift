import Foundation
import CryptoKit
import Security

struct JWTPayload: Codable {
    let sub: String
    let iat: Int
    let exp: Int
}

enum JWTManager {
    private static var secret: SymmetricKey = {
        // Try to load from Keychain, or generate+store
        let tag = "com.claudechat.jwt.secret".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data {
            return SymmetricKey(data: data)
        }
        // Generate new
        let key = SymmetricKey(size: .bits256)
        let raw = key.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecValueData as String: raw,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        return key
    }()

    static func sign(payload: JWTPayload) -> String? {
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        guard let payloadData = try? JSONEncoder().encode(payload),
              let payloadStr = String(data: payloadData, encoding: .utf8)
        else { return nil }

        let hB64 = base64url(header)
        let pB64 = base64url(payloadStr)
        let signingInput = "\(hB64).\(pB64)"

        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(signingInput.utf8), using: secret
        )
        let sigB64 = base64url(Data(signature).base64EncodedString())

        return "\(signingInput).\(sigB64)"
    }

    static func verify(_ token: String) -> JWTPayload? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }

        let signingInput = "\(parts[0]).\(parts[1])"
        let expectedSig = HMAC<SHA256>.authenticationCode(
            for: Data(signingInput.utf8), using: secret
        )
        let expectedSigStr = base64url(Data(expectedSig).base64EncodedString())

        guard expectedSigStr == parts[2] else { return nil }

        guard let payloadData = base64urlDecode(parts[1]),
              let payload = try? JSONDecoder().decode(JWTPayload.self, from: payloadData)
        else { return nil }

        let now = Int(Date().timeIntervalSince1970)
        guard payload.exp > now else { return nil }
        return payload
    }

    private static func base64url(_ input: String) -> String {
        var b64 = Data(input.utf8).base64EncodedString()
        b64 = b64.replacingOccurrences(of: "+", with: "-")
        b64 = b64.replacingOccurrences(of: "/", with: "_")
        return b64.trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    private static func base64urlDecode(_ input: String) -> Data? {
        var b64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        return Data(base64Encoded: b64)
    }
}