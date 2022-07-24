import Foundation
import MuJoCo
import MuJoCoJupyterExtensions
import Numerics

let simulate = Simulate(width: 1920, height: 1080)

let host = "0.0.0.0"
let port = 12345
let httpRenderServer = HTTPRenderServer(simulate, maxWidth: 1920, maxHeight: 1080, maxFrameRate: 30)
let channel = try httpRenderServer.bind(host: host, port: port).wait()

if CommandLine.arguments.count > 1 {
  simulate.filename = CommandLine.arguments[1]
  simulate.loadrequest = 2
}
simulate.makeContext(hidden: true)
simulate.run()
