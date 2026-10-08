import Foundation

/// 실패를 화면에 띄울 한 줄로.
///
/// 우리가 만든 실패(저장 보호, 서버 거절, 연결 실패)는 이미 읽을 문장이라 그대로 쓴다.
/// 시스템이 만든 문장(「데이터가 올바른 형식이 아니므로…」)이나 타입 이름이 그대로 찍히는
/// 실패(`PokePackBar.Foo error 1`)는 무엇을 하라는 말이 없어 짧은 안내로 바꾸고, 원문은
/// 로그에 남긴다. 파일 실패는 공간, 권한, 없음, 손상으로 나눠 알린다.
enum ProblemText {
    static func message(for error: any Error) -> String {
        let l = L.current
        if let cocoa = error as? CocoaError, let text = fileProblem(cocoa.code, l) {
            AppLog.write("[problem] \(String(describing: error).prefix(300))")
            return text
        }
        let domain = (error as NSError).domain
        if error is DecodingError || error is EncodingError || domain == NSCocoaErrorDomain
            || (!(error is any LocalizedError) && domain.hasPrefix("PokePackBar.")) {
            AppLog.write("[problem] \(String(describing: error).prefix(300))")
            return l.unexpectedProblem
        }
        return error.localizedDescription
    }

    private static func fileProblem(_ code: CocoaError.Code, _ l: L) -> String? {
        switch code {
        case .fileWriteOutOfSpace: l.problemDiskFull
        case .fileWriteNoPermission, .fileReadNoPermission, .fileWriteVolumeReadOnly: l.problemNoPermission
        case .fileNoSuchFile, .fileReadNoSuchFile: l.problemFileMissing
        case .fileReadCorruptFile, .fileReadUnknownStringEncoding, .propertyListReadCorrupt: l.problemFileUnreadable
        default: nil
        }
    }
}
