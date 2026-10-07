import AppKit

/// 앱을 다시 시작한다. 온라인 모드 전환이나 다른 계정 연결처럼 기동할 때 정해지는 설정에 쓴다.
///
/// 정상 종료는 launchd 가 다시 띄우지 않으므로(`KeepAlive.SuccessfulExit=false`) 직접 띄운다.
/// 새 인스턴스는 이 프로세스가 끝난 뒤에 연다 — 먼저 뜨면 실행 중인 인스턴스에 양보하고 바로 꺼진다.
@MainActor
enum AppRelauncher {
    static func relaunch() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
                          Bundle.main.bundleURL.path]
        do {
            try task.run()
        } catch {
            AppLog.write("relaunch helper failed: \(error.localizedDescription)")
            return
        }
        NSApp.terminate(nil)
    }
}
