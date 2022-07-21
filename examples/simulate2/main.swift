import C_ccv
import Foundation
import MuJoCo
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOWebSocket
import Numerics

var data = Data()
var registeredPromisesForData = [EventLoopPromise<Data>]()
let queue = DispatchQueue(label: "data", qos: .default)
let simulate = Simulate(width: 1280, height: 720)

struct JSEvent: Decodable {
  var keyCode: Int32?
  var ctrlKey: Bool?
  var altKey: Bool?
  var shiftKey: Bool?
  var mouseState: String?
  var buttons: Int32?
  var offsetX: Float?
  var offsetY: Float?
  var deltaX: Float?
  var deltaY: Float?
  var width: Int32?
  var height: Int32?
}

private func httpResponseHead(
  request: HTTPRequestHead, status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders()
) -> HTTPResponseHead {
  var head = HTTPResponseHead(version: request.version, status: status, headers: headers)
  head.headers.add(name: "Connection", value: "close")
  return head
}

private final class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
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
  private var state = State.idle
  private var continuousCount: Int = 0

  private var handler: ((ChannelHandlerContext, HTTPServerRequestPart) -> Void)?
  private let defaultResponse = """
    <!DOCTYPE html><html lang="en"><head><meta charset="utf-8"></head><body><img id="mjpeg-container" src="/mjpeg">
    <script>
      var wsconnection = new WebSocket("ws://192.168.86.5:12345/websocket");
      var commonKeyCodes = {
        "Space": 32,
        "Quote": 39, /* ' */
        "Comma": 44, /* , */
        "Minus": 45, /* - */
        "Period": 46, /* . */
        "Slash": 47, /* / */
        "Digit0": 48,
        "Digit1": 49,
        "Digit2": 50,
        "Digit3": 51,
        "Digit4": 52,
        "Digit5": 53,
        "Digit6": 54,
        "Digit7": 55,
        "Digit8": 56,
        "Digit9": 57,
        "Semicolon": 59, /* ; */
        "Equal": 61, /* = */
        "KeyA": 65,
        "KeyB": 66,
        "KeyC": 67,
        "KeyD": 68,
        "KeyE": 69,
        "KeyF": 70,
        "KeyG": 71,
        "KeyH": 72,
        "KeyI": 73,
        "KeyJ": 74,
        "KeyK": 75,
        "KeyL": 76,
        "KeyM": 77,
        "KeyN": 78,
        "KeyO": 79,
        "KeyP": 80,
        "KeyQ": 81,
        "KeyR": 82,
        "KeyS": 83,
        "KeyT": 84,
        "KeyU": 85,
        "KeyV": 86,
        "KeyW": 87,
        "KeyX": 88,
        "KeyY": 89,
        "KeyZ": 90,
        "BracketLeft": 91, /* [ */
        "Backslash": 92, /* \\ */
        "BracketRight": 93, /* ] */
        "Backquote": 96, /* ` */
        "Escape": 256,
        "Enter": 257,
        "Tab": 258,
        "Backspace": 259,
        "Insert": 260,
        "Delete": 261,
        "ArrowRight": 262,
        "ArrowLeft": 263,
        "ArrowDown": 264,
        "ArrowUp": 265,
        "PageUp": 266,
        "PageDown": 267,
        "Home": 268,
        "End": 269,
        "CapsLock": 280,
        "ScrollLock": 281,
        "NumLock": 282,
        "PrintScreen": 283,
        "Pause": 284,
        "F1": 290,
        "F2": 291,
        "F3": 292,
        "F4": 293,
        "F5": 294,
        "F6": 295,
        "F7": 296,
        "F8": 297,
        "F9": 298,
        "F10": 299,
        "F11": 300,
        "F12": 301,
        "F13": 302,
        "F14": 303,
        "F15": 304,
        "F16": 305,
        "F17": 306,
        "F18": 307,
        "F19": 308,
        "F20": 309,
        "F21": 310,
        "F22": 311,
        "F23": 312,
        "F24": 313,
        "F25": 314,
        "Numpad0": 320,
        "Numpad1": 321,
        "Numpad2": 322,
        "Numpad3": 323,
        "Numpad4": 324,
        "Numpad5": 325,
        "Numpad6": 326,
        "Numpad7": 327,
        "Numpad8": 328,
        "Numpad9": 329,
        "NumpadDecimal": 330,
        "NumpadDivide": 331,
        "NumpadMultiply": 332,
        "NumpadSubstract": 333,
        "NumpadAdd": 334,
        "NumpadEnter": 335,
        "NumpadEqual": 336,
        "ShiftLeft": 340,
        "ControlLeft": 341,
        "AltLeft": 342,
        "ShiftRight": 344,
        "ControlRight": 345,
        "AltRight": 346
      };
      var mjpeg = document.getElementById("mjpeg-container");
      mjpeg.addEventListener("mouseenter", function (e) {
        e.preventDefault()
        wsconnection.send(JSON.stringify({"mouseState": "move", "buttons": e.buttons, "offsetX": e.offsetX, "offsetY": e.offsetY, "ctrlKey": e.ctrlKey, "altKey": e.altKey, "shiftKey": e.shiftKey}))
      });
      mjpeg.addEventListener("mousemove", function (e) {
        e.preventDefault()
        wsconnection.send(JSON.stringify({"mouseState": "move", "buttons": e.buttons, "offsetX": e.offsetX, "offsetY": e.offsetY, "ctrlKey": e.ctrlKey, "altKey": e.altKey, "shiftKey": e.shiftKey}))
      });
      mjpeg.addEventListener("mousedown", function (e) {
        e.preventDefault()
        wsconnection.send(JSON.stringify({"mouseState": "press", "buttons": e.buttons, "offsetX": e.offsetX, "offsetY": e.offsetY, "ctrlKey": e.ctrlKey, "altKey": e.altKey, "shiftKey": e.shiftKey}))
      });
      mjpeg.addEventListener("mouseup", function (e) {
        e.preventDefault()
        wsconnection.send(JSON.stringify({"mouseState": "release", "buttons": e.buttons, "offsetX": e.offsetX, "offsetY": e.offsetY, "ctrlKey": e.ctrlKey, "altKey": e.altKey, "shiftKey": e.shiftKey}))
      });
      mjpeg.addEventListener("wheel", function (e) {
        e.preventDefault()
        wsconnection.send(JSON.stringify({"deltaX": e.deltaX / 16, "deltaY": -e.deltaY / 16}))
      });
      mjpeg.addEventListener("contextmenu", function (e) {
        e.preventDefault()
      });
      mjpeg.addEventListener("dragstart", function (e) {
        e.preventDefault()
      });
      mjpeg.addEventListener("drop", function (e) {
        e.preventDefault()
      });
      window.addEventListener("keydown", function (e) {
        e.preventDefault()
        wsconnection.send(JSON.stringify({"keyCode": commonKeyCodes[e.code], "ctrlKey": e.ctrlKey, "altKey": e.altKey, "shiftKey": e.shiftKey}))
      });
    </script>
    """

  public init() {
  }

  func handleMultipleWrites(
    context: ChannelHandlerContext, request: HTTPServerRequestPart
  ) {
    switch request {
    case .head(let request):
      self.continuousCount = 0
      self.state.requestReceived()
      func doNext(_ data: Data) {
        guard self.buffer != nil else { return }
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
    let promise = promise ?? context.eventLoop.makePromise()
    promise.futureResult.whenComplete { (_: Result<Void, Error>) in context.close(promise: nil) }
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

  func handlerRemoved(context: ChannelHandlerContext) {
    self.buffer = nil
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
        break
      }
    default:
      context.fireUserInboundEventTriggered(event)
    }
  }
}

private final class WebSocketControlHandler: ChannelInboundHandler {
  typealias InboundIn = WebSocketFrame
  typealias OutboundOut = WebSocketFrame

  private var awaitingClose: Bool = false
  private lazy var decoder = JSONDecoder()

  public func handlerAdded(context: ChannelHandlerContext) {
  }

  public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let frame = self.unwrapInboundIn(data)

    switch frame.opcode {
    case .connectionClose:
      self.receivedClose(context: context, frame: frame)
    case .ping:
      self.pong(context: context, frame: frame)
    case .text:
      var data = frame.unmaskedData
      let text = data.readString(length: data.readableBytes) ?? ""
      if let textData = text.data(using: .utf8),
        let jsEvent = try? decoder.decode(JSEvent.self, from: textData)
      {
        if let keyCode = jsEvent.keyCode {
          simulate.sendEvent(
            .keyboard(
              .init(
                keyCode: keyCode, control: jsEvent.ctrlKey ?? false,
                shift: jsEvent.shiftKey ?? false, alt: jsEvent.altKey ?? false)))
        } else if let mouseState = jsEvent.mouseState, let buttons = jsEvent.buttons,
          let offsetX = jsEvent.offsetX, let offsetY = jsEvent.offsetY
        {
          switch mouseState {
          case "press":
            simulate.sendEvent(
              .mouse(
                .init(
                  state: .press, x: offsetX, y: offsetY, left: (buttons | 1 == 1),
                  right: (buttons | 2 == 2), middle: (buttons | 4 == 4),
                  control: jsEvent.ctrlKey ?? false, shift: jsEvent.shiftKey ?? false,
                  alt: jsEvent.altKey ?? false)))
          case "release":
            simulate.sendEvent(
              .mouse(
                .init(
                  state: .release, x: offsetX, y: offsetY, left: (buttons | 1 == 1),
                  right: (buttons | 2 == 2), middle: (buttons | 4 == 4),
                  control: jsEvent.ctrlKey ?? false, shift: jsEvent.shiftKey ?? false,
                  alt: jsEvent.altKey ?? false)))
          case "move":
            simulate.sendEvent(
              .mouse(
                .init(
                  state: .move, x: offsetX, y: offsetY, left: (buttons | 1 == 1),
                  right: (buttons | 2 == 2), middle: (buttons | 4 == 4),
                  control: jsEvent.ctrlKey ?? false, shift: jsEvent.shiftKey ?? false,
                  alt: jsEvent.altKey ?? false)))
          default:
            break
          }
        } else if let deltaX = jsEvent.deltaX, let deltaY = jsEvent.deltaY {
          simulate.sendEvent(.scroll(.init(sx: deltaX, sy: deltaY)))
        } else if let width = jsEvent.width, let height = jsEvent.height {
          simulate.sendEvent(.resize(.init(width: width, height: height)))
        }
      }
    case .binary, .continuation, .pong:
      // We ignore these frames.
      break
    default:
      // Unknown frames are errors.
      self.closeOnError(context: context)
    }
  }

  public func channelReadComplete(context: ChannelHandlerContext) {
    context.flush()
  }

  private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
    // Handle a received close frame. In websockets, we're just going to send the close
    // frame and then close, unless we already sent our own close frame.
    if awaitingClose {
      // Cool, we started the close and were waiting for the user. We're done.
      context.close(promise: nil)
    } else {
      // This is an unsolicited close. We're going to send a response frame and
      // then, when we've sent it, close up shop. We should send back the close code the remote
      // peer sent us, unless they didn't send one at all.
      var data = frame.unmaskedData
      let closeDataCode = data.readSlice(length: 2) ?? ByteBuffer()
      let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: closeDataCode)
      _ = context.write(self.wrapOutboundOut(closeFrame)).map { () in
        context.close(promise: nil)
      }
    }
  }

  private func pong(context: ChannelHandlerContext, frame: WebSocketFrame) {
    var frameData = frame.data
    let maskingKey = frame.maskKey

    if let maskingKey = maskingKey {
      frameData.webSocketUnmask(maskingKey)
    }

    let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
    context.write(self.wrapOutboundOut(responseFrame), promise: nil)
  }

  private func closeOnError(context: ChannelHandlerContext) {
    // We have hit an error, we want to close. We do that by sending a close frame and then
    // shutting down the write side of the connection.
    var data = context.channel.allocator.buffer(capacity: 2)
    data.write(webSocketErrorCode: .protocolError)
    let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
    context.write(self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
      context.close(mode: .output, promise: nil)
    }
    awaitingClose = true
  }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
let upgrader = NIOWebSocketServerUpgrader(
  shouldUpgrade: { (channel: Channel, head: HTTPRequestHead) in
    channel.eventLoop.makeSucceededFuture(HTTPHeaders())
  },
  upgradePipelineHandler: { (channel: Channel, _: HTTPRequestHead) in
    channel.pipeline.addHandler(WebSocketControlHandler())
  })
let socketBootstrap = ServerBootstrap(group: group)
  // Specify backlog and enable SO_REUSEADDR for the server itself
  .serverChannelOption(ChannelOptions.backlog, value: 256)
  .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

  // Set the handlers that are applied to the accepted Channels
  .childChannelInitializer { channel in
    let httpHandler = HTTPHandler()
    let config: NIOHTTPServerUpgradeConfiguration = (
      upgraders: [upgrader],
      completionHandler: { _ in
        channel.pipeline.removeHandler(httpHandler, promise: nil)
      }
    )
    return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
      channel.pipeline.addHandler(httpHandler)
    }
  }

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
var image = ccv_dense_matrix_new(720, 1280, Int32(CCV_8U | CCV_C3), nil, 0)
simulate.renderContextCallback = { context, width, height in
  if image?.pointee.rows != height || image?.pointee.cols != width {
    ccv_matrix_free(image)
    image = ccv_dense_matrix_new(height, width, Int32(CCV_8U | CCV_C3), nil, 0)
  }
  context.readPixels(
    rgb: &image!.pointee.data.u8,
    viewport: MjrRect(left: 0, bottom: 0, width: width, height: height))
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
