// Sends a debug command to a running ClipStack (needs `defaults write local.tools.ClipStack DebugHooks -bool YES`
// and a relaunch). Usage: swift scripts/debug-hook.swift <toggle|query|snapshot|settings> [argument]
import Foundation

let args = CommandLine.arguments.dropFirst()
guard let command = args.first else {
    print("usage: debug-hook.swift <toggle|query|snapshot|settings> [argument]")
    exit(1)
}
let argument = args.dropFirst().first
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("local.tools.ClipStack.debug." + command), object: argument, userInfo: nil, deliverImmediately: true)
RunLoop.current.run(until: Date().addingTimeInterval(0.2))
print("sent \(command)\(argument.map { " \($0)" } ?? "")")
