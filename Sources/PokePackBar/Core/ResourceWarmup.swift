import Foundation

/// 큰 번들 리소스를 기동 직후 백그라운드에서 미리 읽는다.
///
/// 홀로 좌표(12MB), 카드별 참고 홀로(10MB), 실물 표식(3MB) 같은 파일은 처음 쓰는 순간
/// 읽는데, 그 순간이 대개 첫 카드 공개 애니메이션이다. 메인 스레드에서 합쳐 0.7초 넘게 걸려
/// 앱을 켜고 처음 여는 홀로 카드가 멈췄다. 정적 상수는 한 번만 초기화되므로 여기서 먼저 만지면
/// 화면은 다 읽힌 것을 쓴다. 화면이 먼저 닿으면 그쪽은 이 작업이 끝나기를 기다린다.
enum ResourceWarmup {
    static func start() {
        Task.detached(priority: .utility) {
            _ = CardIndex.shared
            _ = PriceSnapshotStore.shared.cards
            _ = DexCardSearch.normalizedNames.count
            _ = DexCardSearch.normalizedNumbers.count
            _ = CardArtLibrary.entries.count
            _ = FoilGeometry.entries.count
            _ = ReviewedFoilProfiles.entries.count
            PhysicalFoilMarks.warm()
            _ = FoilSubjectMasks.entries.count
            _ = ExpansionFoil.entries.count
            _ = RegisteredCrackedIce.entries.count
        }
    }
}
