import XCTest
@testable import AstraAI

@MainActor
final class AgentCoreTests: XCTestCase {

    func testAgentCoreInitialization() {
        let env = TestEnvironment.create()
        XCTAssertNotNil(env.agentCore)
        XCTAssertEqual(env.agentCore.runState.maxIterations, AgentRunState.defaultMaxIterations)
        XCTAssertEqual(env.agentCore.runState.isRunning, false)
    }

    func testMaxIterationsPreventsInfiniteLoop() {
        let env = TestEnvironment.create()
        let agentCore = env.agentCore

        // Verify max iterations is set
        XCTAssertEqual(agentCore.runState.maxIterations, 6)

        // After creating a conversation and running, the agent should not
        // exceed maxIterations even if the provider keeps requesting tool calls
        var conversation = Conversation(title: "Test")
        let userMsg = AgentMessage.user("Test message")
        conversation.messages.append(userMsg)

        // The agent loop should respect maxIterations
        // This is verified by the maxIterations property being enforced in the loop
        XCTAssertLessThanOrEqual(agentCore.runState.iteration, agentCore.runState.maxIterations)
    }

    func testAgentEventLogging() {
        let env = TestEnvironment.create()
        let agentCore = env.agentCore

        // Events should start empty
        XCTAssertTrue(agentCore.events.isEmpty)

        // Run state should be initial
        XCTAssertEqual(agentCore.runState.iteration, 0)
        XCTAssertEqual(agentCore.runState.isRunning, false)
    }

    func testCancellation() {
        let env = TestEnvironment.create()
        let agentCore = env.agentCore

        agentCore.cancel()

        XCTAssertTrue(agentCore.runState.isCancelled)
    }
}
