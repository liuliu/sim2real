// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

#if canImport(Crypto)
  import Crypto
#endif

enum JupyterDisplay {
  struct Header: Encodable {
    let messageID: String
    let username: String
    let session: String
    let date: String
    let messageType: String
    let version: String
    private enum CodingKeys: String, CodingKey {
      case messageID = "msg_id"
      case messageType = "msg_type"
      case username = "username"
      case session = "session"
      case date = "date"
      case version = "version"
    }

    init(
      messageID: String = UUID().uuidString,
      username: String = "kernel",
      session: String,
      messageType: String = "display_data",
      version: String = "5.3"
    ) {
      self.messageID = messageID
      self.username = username
      self.session = session
      self.messageType = messageType
      self.version = version
      let currentDate = Date()
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.locale = Locale(identifier: "en_US_POSIX")
      self.date = formatter.string(from: currentDate)
    }

    var json: String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      guard let jsonData = try? encoder.encode(self) else { return "{}" }
      let jsonString = String(data: jsonData, encoding: .utf8)!
      return jsonString
    }
  }

  struct Message {
    var messageType: String = "display_data"
    var delimiter = "<IDS|MSG>"
    var key: String = ""
    var header: Header
    var metadata: String = "{}"
    var content: String = "{}"
    var hmacSignature: String {
      #if canImport(Crypto)
        guard let data = (header.json + parentHeader + metadata + content).data(using: .utf8),
          let secret = key.data(using: .utf8)
        else { return "" }
        let authenticationCode = HMAC<SHA256>.authenticationCode(
          for: data, using: SymmetricKey(data: secret))
        return authenticationCode.map { String(format: "%02x", $0) }.joined()
      #endif
      return ""
    }
    var messageParts: [KernelCommunicator.BytesReference] {
      return [
        bytes(messageType),
        bytes(delimiter),
        bytes(hmacSignature),
        bytes(header.json),
        bytes(parentHeader),
        bytes(metadata),
        bytes(content),
      ]
    }

    var json: String {
      let encoder = JSONEncoder()
      let array = [
        messageType, delimiter, hmacSignature, header.json, parentHeader, metadata, content,
      ]
      guard let jsonData = try? encoder.encode(array) else { return "[]" }
      let jsonString = String(data: jsonData, encoding: .utf8)!
      return jsonString
    }

    init(content: String = "{}") {
      header = Header(
        username: JupyterKernel.communicator.jupyterSession.username,
        session: JupyterKernel.communicator.jupyterSession.id
      )
      self.content = content
      key = JupyterKernel.communicator.jupyterSession.key
      #if !canImport(Crypto)
        if !key.isEmpty {
          fatalError(
            """
            Unable to import Crypto to perform message signing.
            Add swift-crypto as a dependency, or disable message signing in Jupyter as follows:
            jupyter notebook --Session.key='b\"\"'\n
            """)
        }
      #endif
    }
  }

  struct PNGImageData: Encodable {
    let image: String
    let text = "<IPython.core.display.Image object>"
    init(base64EncodedPNG: String) {
      image = base64EncodedPNG
    }
    private enum CodingKeys: String, CodingKey {
      case image = "image/png"
      case text = "text/plain"
    }
  }

  struct HTMLData: Encodable {
    let html: String
    init(html: String) {
      self.html = html
    }
    private enum CodingKeys: String, CodingKey {
      case html = "text/html"
    }
  }

  struct TextData: Encodable {
    let text: String
    init(text: String) {
      self.text = text
    }
    private enum CodingKeys: String, CodingKey {
      case text = "text/plain"
    }
  }

  struct MarkdownData: Encodable {
    let markdown: String
    init(markdown: String) {
      self.markdown = markdown
    }
    private enum CodingKeys: String, CodingKey {
      case markdown = "text/markdown"
    }
  }

  struct JSONData: Encodable {
    let json: String
    init(json: String) {
      self.json = json
    }
    private enum CodingKeys: String, CodingKey {
      case json = "application/json"
    }
  }

  struct MessageContent<Data>: Encodable where Data: Encodable {
    let metadata: String
    let transient = "{}"
    let data: Data
    init(metadata: String, data: Data) {
      self.metadata = metadata
      self.data = data
    }
    init(data: Data) {
      self.metadata = "{}"
      self.data = data
    }
    var json: String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      guard let jsonData = try? encoder.encode(self) else { return "{}" }
      let jsonString = String(data: jsonData, encoding: .utf8)!
      return jsonString
    }
  }

  static var parentHeader = "{}"
  static var messages = [Message]()
}

extension JupyterDisplay {
  private static func bytes(_ bytes: String) -> KernelCommunicator.BytesReference {
    let bytes = bytes.utf8CString.dropLast()
    return KernelCommunicator.BytesReference(bytes)
  }

  private static func updateParentMessage(to parentMessage: KernelCommunicator.ParentMessage) {
    do {
      let jsonData = (parentMessage.json).data(using: .utf8, allowLossyConversion: false)
      let jsonDict = try JSONSerialization.jsonObject(with: jsonData!) as? NSDictionary
      let headerData = try JSONSerialization.data(withJSONObject: jsonDict!["header"]!)
      parentHeader = String(data: headerData, encoding: .utf8)!
    } catch {
      print("Error in JSON parsing!")
    }
  }

  private static func consumeDisplayMessages() -> [KernelCommunicator.JupyterDisplayMessage] {
    flushFigures()
    var displayMessages = [KernelCommunicator.JupyterDisplayMessage]()
    for message in messages {
      displayMessages.append(KernelCommunicator.JupyterDisplayMessage(parts: message.messageParts))
    }
    messages = []
    return displayMessages
  }

  static func enable() {
    JupyterKernel.communicator.handleParentMessage(updateParentMessage)
    JupyterKernel.communicator.afterSuccessfulExecution(run: consumeDisplayMessages)
  }

  private static func flushFigures() {
    #if canImport(PythonKit)
      guard matplotlibEnabled else { return }
      backend_inline.flush_figures()
    #endif
  }

  #if canImport(PythonKit)
    private static var matplotlibEnabled = false
    private static let backend_inline = Python.import("matplotlib_swift.backend_inline")
    static func enable_matplotlib() {
      guard let matplotlib = try? Python.attemptImport("matplotlib"),
        let plt = try? Python.attemptImport("matplotlib.pyplot")
      else { return }
      matplotlib.interactive(true)
      let backend = "module://matplotlib_swift.backend_inline"
      matplotlib.rcParams["backend"] = backend.pythonObject
      plt.switch_backend(backend)
      plt.show._needmain = false
      let FigureCanvasBase = Python.import("matplotlib.backend_bases").FigureCanvasBase
      let BytesIO = Python.import("io").BytesIO
      let b2a_base64 = Python.import("binascii").b2a_base64
      let json = Python.import("json")
      backend_inline.show._display =
        PythonFunction({ (x: [PythonObject]) -> PythonConvertible in
          let fig = x[0]
          let metadata = x[1]
          if fig.canvas == Python.None {
            FigureCanvasBase(fig)
          }
          let bytesIo = BytesIO()
          fig.canvas.print_figure(
            bytesIo, format: "png", facecolor: fig.get_facecolor(), edgecolor: fig.get_edgecolor(),
            dpi: fig.dpi, bbox_inches: "tight")
          let base64EncodedPNG = String(b2a_base64(bytesIo.getvalue()).decode("ascii"))!
          JupyterDisplay.display(
            base64EncodedPNG: base64EncodedPNG,
            metadata: metadata == Python.None ? nil : String(json.dumps(metadata))!)
          return Python.None
        }).pythonObject
      matplotlibEnabled = true
    }
  #endif

  static func display(base64EncodedPNG: String, metadata: String? = nil) {
    let pngData = JupyterDisplay.PNGImageData(base64EncodedPNG: base64EncodedPNG)
    let data = JupyterDisplay.MessageContent(metadata: metadata ?? "{}", data: pngData).json
    JupyterDisplay.messages.append(JupyterDisplay.Message(content: data))
  }

  static func display(html: String, metadata: String? = nil) {
    let htmlData = JupyterDisplay.HTMLData(html: html)
    let data = JupyterDisplay.MessageContent(metadata: metadata ?? "{}", data: htmlData).json
    JupyterDisplay.messages.append(JupyterDisplay.Message(content: data))
  }

  static func display(text: String, metadata: String? = nil) {
    let textData = JupyterDisplay.TextData(text: text)
    let data = JupyterDisplay.MessageContent(metadata: metadata ?? "{}", data: textData).json
    JupyterDisplay.messages.append(JupyterDisplay.Message(content: data))
  }

  static func flush() {
    // Encode the messages into JSON array and push out into stdout. The StdoutHandler was enhanced
    // to parse special boundary chars and send display message to Jupyter accordingly.
    let boundary = "\(String(JupyterKernel.communicator.jupyterSession.id.reversed()))flush"
    let payload =
      "--\(boundary)[\(JupyterDisplay.messages.map({ $0.json }).joined(separator: ","))]--\(boundary)--"
    guard let data = payload.data(using: .utf8) else { return }
    try? FileHandle.standardOutput.write(contentsOf: data)
    JupyterDisplay.messages = []
  }
}

#if canImport(SwiftPlot)
  import SwiftPlot
  import AGGRenderer
  var __agg_renderer = AGGRenderer()
  extension Plot {
    func display(size: Size = Size(width: 1000, height: 660)) {
      drawGraph(size: size, renderer: __agg_renderer)
      JupyterDisplay.display(base64EncodedPNG: __agg_renderer.base64Png())
    }
  }
#endif

#if canImport(PythonKit)
  import PythonKit
  extension PythonObject {
    func display() {
      if Bool(Python.hasattr(self, "_repr_html_")) == true {
        JupyterDisplay.display(html: String(self[dynamicMember: "_repr_html_"]())!)
        return
      }
      JupyterDisplay.display(text: description)
    }
  }
#endif

JupyterDisplay.enable()
#if canImport(PythonKit)
  JupyterDisplay.enable_matplotlib()
#endif
