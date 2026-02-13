import XCTest
@testable import GSDMonitor

final class PlanParserTests: XCTestCase {

    func testParseEmptyPlan() {
        let parser = PlanParser()
        let content = ""

        let result = parser.parse(content)

        XCTAssertNil(result, "Empty content should return nil")
    }

    func testParsePlanWithPhaseAndPlanNumbers() {
        let parser = PlanParser()
        let content = """
        ---
        phase: 02-file-discovery-parsing
        plan: 03
        type: tdd
        ---

        <objective>
        Implement parsers for REQUIREMENTS.md and PLAN.md files.
        </objective>

        <tasks>
        <task type="auto">
          <name>Task 1: Implement parsers</name>
        </task>
        </tasks>
        """

        let result = parser.parse(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.phaseNumber, 2)
        XCTAssertEqual(result?.planNumber, 3)
        XCTAssertEqual(result?.objective, "Implement parsers for REQUIREMENTS.md and PLAN.md files.")
        XCTAssertEqual(result?.tasks.count, 1)
    }

    func testParseTaskTypes() {
        let parser = PlanParser()
        let content = """
        ---
        phase: 01-foundation
        plan: 01
        ---

        <objective>
        Test objective
        </objective>

        <tasks>
        <task type="auto">
          <name>Task 1: Auto task</name>
        </task>
        <task type="checkpoint:human-verify">
          <name>Task 2: Checkpoint task</name>
        </task>
        </tasks>
        """

        let result = parser.parse(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.tasks.count, 2)

        let autoTask = result?.tasks[0]
        XCTAssertEqual(autoTask?.name, "Auto task")
        XCTAssertEqual(autoTask?.type, .auto)

        let checkpointTask = result?.tasks[1]
        XCTAssertEqual(checkpointTask?.name, "Checkpoint task")
        XCTAssertEqual(checkpointTask?.type, .checkpoint)
    }

    func testParseNoTasks() {
        let parser = PlanParser()
        let content = """
        ---
        phase: 01-foundation
        plan: 01
        ---

        <objective>
        Test objective
        </objective>

        <tasks>
        </tasks>
        """

        let result = parser.parse(content)

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.tasks.isEmpty ?? false)
    }

    func testParseMalformedFrontmatter() {
        let parser = PlanParser()
        let content = """
        <objective>
        Missing frontmatter
        </objective>
        """

        let result = parser.parse(content)

        XCTAssertNil(result, "Malformed content should return nil")
    }
}
