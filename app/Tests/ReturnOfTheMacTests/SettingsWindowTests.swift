import AppKit
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
}
