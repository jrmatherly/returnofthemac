import AppKit
import RotmCore
import Testing

@testable import ReturnOfTheMac

private func editableFields(in view: NSView) -> [NSTextField] {
  let mine = (view as? NSTextField).map { $0.isEditable ? [$0] : [] } ?? []
  return mine + view.subviews.flatMap(editableFields)
}

@Suite(.serialized) @MainActor struct SettingsWindowTests {
  init() {
    _ = NSApplication.shared
  }

  @Test func noFieldTakesFocusOnOpen() async throws {
    let controller = await settingsWindow()
    try await Task.sleep(nanoseconds: 500_000_000)
    let frame = try #require(controller.window.contentView?.superview)
    #expect(!editableFields(in: frame).isEmpty, "the window has no text field, so the check proves nothing")
    #expect(!(controller.window.firstResponder is NSText), "a text field took focus on open")
    controller.window.close()
  }

  @Test func applyListsTheSettingsOnce() async throws {
    let (state, runner) = await fixtureState()
    let controller = SettingsWindowController(state: state, runner: runner)
    await controller.model.load()
    controller.show()
    try await Task.sleep(nanoseconds: 500_000_000)
    let set = ["settings", "set", "updates.slow_step_seconds", "--", "20"]
    runner.stub(set, .success(CommandOutput(stdout: "", stderr: "")))
    controller.model.stage("updates.slow_step_seconds", value: "20", shared: false)
    let before = runner.calls.count
    await state.exclusive("Applying settings…") { await controller.model.applyStaged() }
    try await Task.sleep(nanoseconds: 500_000_000)
    #expect(Array(runner.calls.dropFirst(before)) == [set, ["settings", "status", "--json"], ["settings", "list", "--json"]])
    controller.window.close()
  }
}
