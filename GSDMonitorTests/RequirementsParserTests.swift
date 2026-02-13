import XCTest
@testable import GSDMonitor

final class RequirementsParserTests: XCTestCase {

    func testParseEmptyRequirements() {
        let parser = RequirementsParser()
        let content = ""

        let result = parser.parse(content)

        XCTAssertTrue(result.isEmpty, "Empty content should return empty array")
    }

    func testParseRequirementsWithCategories() {
        let parser = RequirementsParser()
        let content = """
        ### Navigation

        - [ ] **NAV-01**: User can see all GSD-projekter i en sidebar
        - [x] **NAV-02**: User can tilføje projektmapper manuelt

        ### Parsing

        - [ ] **PARSE-01**: App parser ROADMAP.md korrekt
        """

        let result = parser.parse(content)

        XCTAssertEqual(result.count, 3)

        let nav01 = result.first { $0.id == "NAV-01" }
        XCTAssertNotNil(nav01)
        XCTAssertEqual(nav01?.category, "Navigation")
        XCTAssertEqual(nav01?.description, "User can see all GSD-projekter i en sidebar")
        XCTAssertEqual(nav01?.status, .active)

        let nav02 = result.first { $0.id == "NAV-02" }
        XCTAssertNotNil(nav02)
        XCTAssertEqual(nav02?.status, .validated)

        let parse01 = result.first { $0.id == "PARSE-01" }
        XCTAssertNotNil(parse01)
        XCTAssertEqual(parse01?.category, "Parsing")
    }

    func testParseTraceabilityTable() {
        let parser = RequirementsParser()
        let content = """
        ### UI/UX

        - [x] **UI-01**: App følger macOS system theme

        ## Traceability

        | Requirement | Phase | Status |
        |-------------|-------|--------|
        | UI-01 | Phase 1 | Done |
        | NAV-01 | Phase 2 | Pending |
        """

        let result = parser.parse(content)

        let ui01 = result.first { $0.id == "UI-01" }
        XCTAssertNotNil(ui01)
        XCTAssertEqual(ui01?.mappedToPhases, [1])
    }

    func testParseNoTraceabilityTable() {
        let parser = RequirementsParser()
        let content = """
        ### Navigation

        - [ ] **NAV-01**: User can see all GSD-projekter
        """

        let result = parser.parse(content)

        let nav01 = result.first { $0.id == "NAV-01" }
        XCTAssertNotNil(nav01)
        XCTAssertTrue(nav01?.mappedToPhases.isEmpty ?? false)
    }
}
