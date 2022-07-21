import C_ccv
import Foundation
import MuJoCo
import NIOCore
import NIOHTTP1
import NIOPosix
import Numerics

var data = Data()
var registeredPromisesForData = [EventLoopPromise<Data>]()
let queue = DispatchQueue(label: "data", qos: .default)

private func httpResponseHead(
  request: HTTPRequestHead, status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders()
) -> HTTPResponseHead {
  var head = HTTPResponseHead(version: request.version, status: status, headers: headers)
  let connectionHeaders: [String] = head.headers[canonicalForm: "connection"].map {
    $0.lowercased()
  }

  if !connectionHeaders.contains("keep-alive") && !connectionHeaders.contains("close") {
    // the user hasn't pre-set either 'keep-alive' or 'close', so we might need to add headers

    switch (request.isKeepAlive, request.version.major, request.version.minor) {
    case (true, 1, 0):
      // HTTP/1.0 and the request has 'Connection: keep-alive', we should mirror that
      head.headers.add(name: "Connection", value: "keep-alive")
    case (false, 1, let n) where n >= 1:
      // HTTP/1.1 (or treated as such) and the request has 'Connection: close', we should mirror that
      head.headers.add(name: "Connection", value: "close")
    default:
      // we should match the default or are dealing with some HTTP that we don't support, let's leave as is
      ()
    }
  }
  return head
}

private final class HTTPHandler: ChannelInboundHandler {
  public typealias InboundIn = HTTPServerRequestPart
  public typealias OutboundOut = HTTPServerResponsePart

  private enum State {
    case idle
    case waitingForRequestBody
    case sendingResponse

    mutating func requestReceived() {
      precondition(self == .idle, "Invalid state for request received: \(self)")
      self = .waitingForRequestBody
    }

    mutating func requestComplete() {
      precondition(self == .waitingForRequestBody, "Invalid state for request complete: \(self)")
      self = .sendingResponse
    }

    mutating func responseComplete() {
      precondition(self == .sendingResponse, "Invalid state for response complete: \(self)")
      self = .idle
    }
  }

  private var buffer: ByteBuffer! = nil
  private var keepAlive = false
  private var state = State.idle
  private var continuousCount: Int = 0

  private var handler: ((ChannelHandlerContext, HTTPServerRequestPart) -> Void)?
  private let defaultResponse =
    "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"></head><body><img src=\"mjpeg\">\r\n"

  public init() {
  }

  func handleMultipleWrites(
    context: ChannelHandlerContext, request: HTTPServerRequestPart
  ) {
    switch request {
    case .head(let request):
      self.keepAlive = request.isKeepAlive
      self.continuousCount = 0
      self.state.requestReceived()
      func doNext(_ data: Data) {
        self.buffer.clear()
        let promise = context.eventLoop.makePromise(of: Data.self)
        let future = promise.futureResult
        self.buffer.writeStaticString("--FRAME\r\n")
        self.buffer.writeStaticString("Content-Type: image/jpeg\r\n")
        self.buffer.writeString("Content-Length: \(data.count)\r\n")
        self.buffer.writeStaticString("\r\n")
        self.buffer.writeBytes(data)
        queue.sync {
          registeredPromisesForData.append(promise)
        }
        self.buffer.writeStaticString("\r\n")
        context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(self.buffer)))).whenSuccess {
          future.whenSuccess(doNext)
        }
      }
      var responseHead = httpResponseHead(request: request, status: .ok)
      responseHead.headers.add(
        name: "Content-Type", value: "multipart/x-mixed-replace; boundary=FRAME")
      context.writeAndFlush(self.wrapOutboundOut(.head(responseHead)), promise: nil)
      var nextData: Data? = nil
      queue.sync {
        nextData = data
      }
      doNext(nextData!)
    case .end:
      self.state.requestComplete()
    default:
      break
    }
  }

  func mjpegHandler(request reqHead: HTTPRequestHead) -> (
    (ChannelHandlerContext, HTTPServerRequestPart) -> Void
  )? {
    return {
      self.handleMultipleWrites(context: $0, request: $1)
    }
  }

  private func completeResponse(
    _ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?
  ) {
    self.state.responseComplete()

    let promise = self.keepAlive ? promise : (promise ?? context.eventLoop.makePromise())
    if !self.keepAlive {
      promise!.futureResult.whenComplete { (_: Result<Void, Error>) in context.close(promise: nil) }
    }
    self.handler = nil

    context.writeAndFlush(self.wrapOutboundOut(.end(trailers)), promise: promise)
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let reqPart = self.unwrapInboundIn(data)
    if let handler = self.handler {
      handler(context, reqPart)
      return
    }

    switch reqPart {
    case .head(let request):

      if request.uri == "/mjpeg" {
        self.handler = self.mjpegHandler(request: request)
        self.handler!(context, reqPart)
        return
      }

      self.keepAlive = request.isKeepAlive
      self.state.requestReceived()

      var responseHead = httpResponseHead(request: request, status: .ok)
      self.buffer.clear()
      self.buffer.writeString(self.defaultResponse)
      responseHead.headers.add(name: "Content-Length", value: "\(self.buffer!.readableBytes)")
      responseHead.headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
      let response = HTTPServerResponsePart.head(responseHead)
      context.write(self.wrapOutboundOut(response), promise: nil)
    case .body:
      break
    case .end:
      self.state.requestComplete()
      let content = HTTPServerResponsePart.body(.byteBuffer(buffer!.slice()))
      context.write(self.wrapOutboundOut(content), promise: nil)
      self.completeResponse(context, trailers: nil, promise: nil)
    }
  }

  func channelReadComplete(context: ChannelHandlerContext) {
    context.flush()
  }

  func handlerAdded(context: ChannelHandlerContext) {
    self.buffer = context.channel.allocator.buffer(capacity: 0)
  }

  func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
    switch event {
    case let evt as ChannelEvent where evt == ChannelEvent.inputClosed:
      // The remote peer half-closed the channel. At this time, any
      // outstanding response will now get the channel closed, and
      // if we are idle or waiting for a request body to finish we
      // will close the channel immediately.
      switch self.state {
      case .idle, .waitingForRequestBody:
        context.close(promise: nil)
      case .sendingResponse:
        self.keepAlive = false
      }
    default:
      context.fireUserInboundEventTriggered(event)
    }
  }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
  return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
    channel.pipeline.addHandler(HTTPHandler())
  }
}
let socketBootstrap = ServerBootstrap(group: group)
  // Specify backlog and enable SO_REUSEADDR for the server itself
  .serverChannelOption(ChannelOptions.backlog, value: 256)
  .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

  // Set the handlers that are applied to the accepted Channels
  .childChannelInitializer(childChannelInitializer(channel:))

  // Enable SO_REUSEADDR for the accepted Channels
  .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
  .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
  .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)

defer {
  try! group.syncShutdownGracefully()
}

let host = "0.0.0.0"
let port = 12345
let channel = try socketBootstrap.bind(host: host, port: port).wait()

let simulate = Simulate(width: 800, height: 600)
let syncmisalign: Double = 0.1  // maximum time mis-alignment before re-sync
let refreshfactor: Double = 0.7  // fraction of refresh available for simulation
var ctrlnoise: [Double]? = nil
if CommandLine.arguments.count > 1 {
  simulate.filename = CommandLine.arguments[1]
  simulate.loadrequest = 2
}
simulate.makeContext(hidden: false)
let vmode = GLContext.videoMode
final class Timer {
  var simsync: Double = 0
  var cpusync: Double = 0
}
let timer = Timer()
var image = ccv_dense_matrix_new(600, 800, Int32(CCV_8U | CCV_C3), nil, 0)
simulate.renderContextCallback = { context in
  context.readPixels(
    rgb: &image!.pointee.data.u8, viewport: MjrRect(left: 0, bottom: 0, width: 800, height: 600))
  ccv_flip(image, &image, 0, Int32(CCV_FLIP_Y))
  let _ = "/tmp/output.jpg".withCString {
    ccv_write(image, UnsafeMutablePointer(mutating: $0), nil, Int32(CCV_IO_JPEG_FILE), nil)
  }
  queue.sync {
    data = try! Data(contentsOf: URL(fileURLWithPath: "/tmp/output.jpg"))
    let promises = registeredPromisesForData
    registeredPromisesForData.removeAll()
    for promise in promises {
      promise.succeed(data)
    }
  }
}
while !simulate.exitrequest {
  simulate.yield()
  guard let m = simulate.model, var d = simulate.data else { continue }
  if simulate.run {
    let tmstart = GLContext.time
    if simulate.ctrlnoisestd > 0 {
      let rate = exp(-m.opt.timestep / simulate.ctrlnoiserate)
      let scale = simulate.ctrlnoisestd * (1 - rate * rate).squareRoot()
      let prevctrlnoise = ctrlnoise
      if ctrlnoise == nil {
        // allocate ctrlnoise
        ctrlnoise = Array(repeating: 0, count: Int(m.nu))
      }
      for i in 0..<Int(m.nu) {
        ctrlnoise?[i] = rate * (prevctrlnoise?[i] ?? 0) + scale * Simulate.normal(1)
        d.ctrl[i] = ctrlnoise?[i] ?? 0
      }
    }
    let offset = abs(
      (d.time * Double(simulate.slowdown) - timer.simsync) - (tmstart - timer.cpusync))
    // Out of sync.
    if d.time * Double(simulate.slowdown) < timer.simsync || tmstart < timer.cpusync
      || timer.cpusync == 0 || offset > syncmisalign * Double(simulate.slowdown)
      || simulate.speedchanged
    {
      timer.cpusync = tmstart
      timer.simsync = d.time * Double(simulate.slowdown)
      simulate.speedchanged = false
      d.xfrcApplied.zero()
      simulate.perturb.applyPerturbPose(model: m, data: &d, flgPaused: 0)
      simulate.perturb.applyPerturbForce(model: m, data: &d)
      m.step(data: &d)
    } else {
      // In sync.
      // step while simtime lags behind cputime, and within safefactor
      while d.time * Double(simulate.slowdown) - timer.simsync < GLContext.time - timer.cpusync
        && GLContext.time - tmstart < refreshfactor / Double(vmode.refreshRate)
      {
        // clear old perturbations, apply new
        d.xfrcApplied.zero()
        simulate.perturb.applyPerturbPose(model: m, data: &d, flgPaused: 0)
        simulate.perturb.applyPerturbForce(model: m, data: &d)
        let prevtm = d.time * Double(simulate.slowdown)
        m.step(data: &d)

        // break on reset
        if d.time * Double(simulate.slowdown) < prevtm {
          break
        }
      }
    }
  } else {
    simulate.perturb.applyPerturbPose(model: m, data: &d, flgPaused: 1)
    m.forward(data: &d)
  }
}
ccv_matrix_free(image)
