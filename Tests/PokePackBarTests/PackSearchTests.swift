import XCTest
@testable import PokePackBar

/// 팩 이름 검색. 세트 이름은 영어 원문이고, 시대, 세트 ID, 연도로도 찾는다.
final class PackSearchTests: XCTestCase {

    private func set(_ id: String, _ name: String, _ series: String, _ released: String) -> CardSet {
        CardSet(id: id, name: name, series: series, released: released, cardCount: 1)
    }

    private var sample: [CardSet] {
        [set("base1", "Base", "Base", "1999/01/09"),
         set("base4", "Base Set 2", "Base", "2000/02/24"),
         set("sm1", "Sun & Moon", "Sun & Moon", "2017/02/03"),
         set("sm12", "Cosmic Eclipse", "Sun & Moon", "2019/11/01"),
         set("sv3", "Obsidian Flames", "Scarlet & Violet", "2023/08/11"),
         set("sv3pt5", "151", "Scarlet & Violet", "2023/09/22"),
         set("xy12", "Evolutions", "XY", "2016/11/02")]
    }

    private func ids(_ query: String) -> [String] {
        PackSearch.results(query, in: sample).map(\.id)
    }

    func testFindsByNameIDAndYear() {
        XCTAssertEqual(ids("151"), ["sv3pt5"])
        XCTAssertEqual(ids("OBSIDIAN fl"), ["sv3"])
        XCTAssertEqual(ids("2023"), ["sv3pt5", "sv3"], "같은 정도로 맞으면 최신 세트가 앞이다")
        XCTAssertEqual(ids("évolutions"), ["xy12"])
    }

    /// 이름이나 ID 를 그대로 치면 그 세트가 맨 앞이다.
    func testExactNameOrIDComesFirst() {
        XCTAssertEqual(ids("base"), ["base1", "base4"])
        XCTAssertEqual(ids("sv3").first, "sv3")
    }

    /// 띄어 쓴 낱말은 모두 맞아야 하고, 띄어쓰기와 기호는 따지지 않는다.
    func testEveryWordMustMatchAndSpacingIsIgnored() {
        XCTAssertEqual(ids("scarlet 151"), ["sv3pt5"])
        for query in ["sun moon", "sunmoon", "Sun & Moon"] {
            XCTAssertEqual(ids(query).first, "sm1", query)
        }
        XCTAssertEqual(ids("sun moon"), ["sm1", "sm12"], "같은 시대의 다른 세트는 뒤에 온다")
    }

    /// 한글로 치면 아무것도 안 나온다. 그때 화면이 이름이 영어라고 알려 줄 수 있어야 한다.
    func testNonLatinQueriesAreRecognised() {
        XCTAssertTrue(ids("스칼렛").isEmpty)
        XCTAssertTrue(PackSearch.hasNonLatinLetters("스칼렛"))
        XCTAssertFalse(PackSearch.hasNonLatinLetters("sun & moon 151"))
        XCTAssertTrue(ids("   ").isEmpty)
        XCTAssertTrue(PackSearch.matches(sample[0], query: ""))
    }

    /// 상점이 진열하는 실제 세트로도 대표 검색어가 맞는 팩을 찾는다.
    func testBundledCatalogue() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let sets = index.eras.flatMap(\.sets)
        XCTAssertEqual(PackSearch.results("151", in: sets).first?.id, "sv3pt5")
        XCTAssertEqual(PackSearch.results("base", in: sets).first?.id, "base1")
        XCTAssertEqual(PackSearch.results("obsidian", in: sets).map(\.id), ["sv3"])
    }
}
