import Foundation
import NIO
import NIOHTTP1
import HTTPTypes
import OpenAPIRuntime
import LayoutKitAPI
import Dispatch

// Simple path template matcher supporting segments like "/file/{name}.zip".
private struct PathTemplate: Sendable {
    struct SegmentToken: Sendable { enum Kind { case literal(String); case param(String) }; let kind: Kind }
    let raw: String
    let segments: [[SegmentToken]]

    init(_ template: String) {
        self.raw = template
        self.segments = template.split(separator: "/").map { seg in
            var tokens: [SegmentToken] = []
            var i = seg.startIndex
            while i < seg.endIndex {
                if seg[i] == "{" {
                    // parse param name
                    let start = seg.index(after: i)
                    guard let end = seg[start...].firstIndex(of: "}") else {
                        // treat as literal if malformed
                        tokens.append(.init(kind: .literal(String(seg[i...]))))
                        i = seg.endIndex
                        break
                    }
                    let name = String(seg[start..<end])
                    tokens.append(.init(kind: .param(name)))
                    i = seg.index(after: end)
                } else {
                    // accumulate literal until next '{' or end
                    let next = seg[i...].firstIndex(of: "{") ?? seg.endIndex
                    let lit = String(seg[i..<next])
                    tokens.append(.init(kind: .literal(lit)))
                    i = next
                }
            }
            return tokens
        }
    }

    func match(path: String) -> [String: Substring]? {
        let comps = path.split(separator: "/")
        guard comps.count == segments.count else { return nil }
        var params: [String: Substring] = [:]
        for (segTokens, segVal) in zip(segments, comps) {
            var pos = segVal.startIndex
            for (idx, tok) in segTokens.enumerated() {
                switch tok.kind {
                case .literal(let lit):
                    guard segVal[pos...].hasPrefix(lit) else { return nil }
                    pos = segVal.index(pos, offsetBy: lit.count)
                case .param(let name):
                    // capture until next literal or end of segment
                    let nextLiteral: String? = {
                        if idx + 1 < segTokens.count, case let .literal(l) = segTokens[idx+1].kind { return l } else { return nil }
                    }()
                    if let lit = nextLiteral, !lit.isEmpty {
                        guard let range = segVal[pos...].range(of: lit) else { return nil }
                        params[name] = segVal[pos..<range.lowerBound]
                        pos = range.lowerBound
                    } else {
                        params[name] = segVal[pos...]
                        pos = segVal.endIndex
                    }
                }
            }
            if pos != segVal.endIndex { return nil }
        }
        return params
    }
}

// MARK: - NIO HTTP/1.1 ServerTransport

public final class NIOHTTPServerTransport: ServerTransport, @unchecked Sendable {
    public typealias Handler = @Sendable (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws -> (HTTPResponse, HTTPBody?)

    private struct Route: Sendable { let method: HTTPRequest.Method; let template: PathTemplate; let handler: Handler }
    private var routes: [Route] = []
    private let group: EventLoopGroup
    private var channel: Channel?
    private let host: String
    private let port: Int
    private let sync = DispatchQueue(label: "com.fountaincoach.layoutkit.nio.transport")

    public init(host: String = "127.0.0.1", port: Int = 8080, group: EventLoopGroup? = nil) {
        self.host = host
        self.port = port
        self.group = group ?? MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }

    deinit {
        // If user didn't close, try best-effort shutdown.
        try? close()
    }

    public func register(_ handler: @escaping Handler, method: HTTPRequest.Method, path: String) throws {
        sync.sync { routes.append(Route(method: method, template: PathTemplate(path), handler: handler)) }
    }

    public func start() async throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(transport: self))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        self.channel = try await bootstrap.bind(host: host, port: port).get()
    }

    public func close() throws {
        try channel?.close().wait()
        try group.syncShutdownGracefully()
    }

    // Internal router lookup
    private func route(method: HTTPRequest.Method, pathOnly: String) -> (Handler, [String: Substring])? {
        return sync.sync { () -> (Handler, [String: Substring])? in
            for r in routes where r.method == method {
                if let params = r.template.match(path: pathOnly) { return (r.handler, params) }
            }
            return nil
        }
    }

    // Channel handler bridging NIO <-> OpenAPIRuntime types.
    private final class HTTPHandler: ChannelInboundHandler, @unchecked Sendable {
        typealias InboundIn = HTTPServerRequestPart
        typealias OutboundOut = HTTPServerResponsePart

        private let transport: NIOHTTPServerTransport
        private var requestHead: HTTPRequestHead?
        private var bodyBuffer: ByteBuffer?

        // Wrapper to silence Swift 6 Sendable checks where safe.
        private struct UnsafeSendableBox<T>: @unchecked Sendable { let value: T }

        init(transport: NIOHTTPServerTransport) { self.transport = transport }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let part = self.unwrapInboundIn(data)
            switch part {
            case .head(let head):
                self.requestHead = head
                self.bodyBuffer = context.channel.allocator.buffer(capacity: 0)
            case .body(var buf):
                if var body = self.bodyBuffer { var b = buf; body.writeBuffer(&b); self.bodyBuffer = body } else { self.bodyBuffer = buf }
            case .end:
                guard let head = requestHead else { return }
                let (httpReq, body, metadata) = Self.toHTTPTypes(head: head, bodyBuffer: bodyBuffer)
                // Route and handle
                let pathOnly: Substring = {
                    let p = httpReq.path ?? ""
                    let end = p.firstIndex(of: "?") ?? p.firstIndex(of: "#") ?? p.endIndex
                    return p[p.startIndex..<end]
                }()
                let method = httpReq.method
                guard let (handler, params) = transport.route(method: method, pathOnly: String(pathOnly)) else {
                    self.writeResponse(context: context, status: .notFound, headers: HTTPHeaders([("content-length","0")]), body: nil)
                    return
                }
                let meta = ServerRequestMetadata(pathParameters: params)
                let ctxBox = UnsafeSendableBox(value: context)
                let selfBox = UnsafeSendableBox(value: self)
                Task.detached {
                    do {
                        let (resp, respBody) = try await handler(httpReq, body, meta)
                        let (status, headers, buf) = try await HTTPHandler.encodeResponse(resp: resp, body: respBody)
                        let ctx = ctxBox.value
                        let strongSelf = selfBox.value
                        ctx.eventLoop.execute {
                            strongSelf.writeResponse(context: ctx, status: status, headers: headers, body: buf)
                        }
                    } catch {
                        let ctx = ctxBox.value
                        let strongSelf = selfBox.value
                        ctx.eventLoop.execute {
                            strongSelf.writeResponse(context: ctx, status: .internalServerError, headers: HTTPHeaders([("content-length","0")]), body: nil)
                        }
                    }
                }
            }
        }

        private static func toHTTPTypes(head: HTTPRequestHead, bodyBuffer: ByteBuffer?) -> (HTTPRequest, HTTPBody?, ServerRequestMetadata) {
            // Convert headers
            var fields = HTTPFields()
            for h in head.headers {
                if let name = HTTPField.Name(h.name) { fields.append(HTTPField(name: name, value: h.value)) }
            }
            // Path includes query already as stored in head.uri; ensure leading '/'
            let path = head.uri
            let method = HTTPRequest.Method(rawValue: head.method.rawValue.uppercased()) ?? .get
            let req = HTTPRequest(method: method, scheme: nil, authority: nil, path: path, headerFields: fields)
            var body: HTTPBody? = nil
            if let bb = bodyBuffer, bb.readableBytes > 0 {
                var tmp = bb
                if let bytes = tmp.readBytes(length: tmp.readableBytes) {
                    body = HTTPBody(ArraySlice(bytes))
                }
            }
            return (req, body, ServerRequestMetadata())
        }

        private func writeResponse(context: ChannelHandlerContext, status: HTTPResponseStatus, headers: HTTPHeaders, body: ByteBuffer?) {
            let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: status, headers: headers)
            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
            if let body = body { context.write(self.wrapOutboundOut(.body(.byteBuffer(body))), promise: nil) }
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        }

        private static func encodeResponse(resp: HTTPTypes.HTTPResponse, body respBody: OpenAPIRuntime.HTTPBody?) async throws -> (HTTPResponseStatus, HTTPHeaders, ByteBuffer?) {
            var headers = HTTPHeaders()
            for field in resp.headerFields { headers.add(name: field.name.canonicalName, value: field.value) }
            var bodyBuf: ByteBuffer? = nil
            if let respBody {
                let data = try await Data(collecting: respBody, upTo: .max)
                var buf = ByteBufferAllocator().buffer(capacity: data.count)
                buf.writeBytes(data)
                bodyBuf = buf
                if headers["content-length"].isEmpty { headers.replaceOrAdd(name: "content-length", value: String(data.count)) }
            } else {
                headers.replaceOrAdd(name: "content-length", value: "0")
            }
            if headers["connection"].isEmpty { headers.replaceOrAdd(name: "connection", value: "keep-alive") }
            let status = HTTPResponseStatus(statusCode: Int(resp.status.code))
            return (status, headers, bodyBuf)
        }
    }
}
