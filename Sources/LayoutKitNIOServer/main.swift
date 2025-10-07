import Foundation
import LayoutKitAPI
import LayoutKitNIO

@main
struct Main {
    static func main() async {
        let host = ProcessInfo.processInfo.environment["LAYOUTKIT_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["LAYOUTKIT_PORT"] ?? "8080") ?? 8080
        let transport = NIOHTTPServerTransport(host: host, port: port)
        let handlers = DefaultHandlers()
        do {
            try handlers.registerHandlers(on: transport)
            try await transport.start()
            print("LayoutKitNIOServer listening on http://\(host):\(port)")
            // Sleep the async main task forever; NIO holds the process open.
            // Suspend indefinitely
            try? await withCheckedThrowingContinuation { (_: CheckedContinuation<Void, Error>) in }
        } catch {
            fputs("Server error: \(error)\n", stderr)
            exit(1)
        }
    }
}
