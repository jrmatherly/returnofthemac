"""Drives the agent widgets and the plugin stack screen with Textual's pilot. Needs Textual, so it runs through uv:
uv run --project settings python settings/tests/test_tui_agents.py"""
import asyncio, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from textual.app import App
from textual.widgets import DataTable, Select, Static

from dotfiles_settings import registry
from dotfiles_settings.adapters import tool
from dotfiles_settings.model import Setting, SettingsError, Source, Value
from dotfiles_settings.tui import SettingsApp
from dotfiles_settings.tui_agents import LinesEditor, SeatsEditor, StackScreen

by_id = {s.id: s for s in registry.load()}
paths_setting, bug_fix_setting = by_id["hindsight.paths"], by_id["jstack.bug_fix"]


class FakeAdapter:
    def __init__(self, values: dict[str, str]):
        self.values = values
        self.writes: list[tuple[str, str]] = []
        self.fail: Exception | None = None
        self.source = Source.SEED
        self.resets: list[str] = []

    def read(self, s: Setting) -> Value:
        if self.fail:
            raise self.fail
        return Value(s.id, self.values[s.id], self.source, self.values[s.id], False)

    def write(self, s: Setting, value: str) -> None:
        self.writes.append((s.id, value))
        self.values[s.id] = value

    def reset(self, s: Setting) -> None:
        self.resets.append(s.id)


def host(widget):
    class Host(App):
        def compose(self):
            yield widget
    return Host()


async def test_seats_editor_single_role():
    async with host(SeatsEditor("bug-fix", "opus medium", id="e")).run_test() as pilot:
        e = pilot.app.query_one("#e", SeatsEditor)
        assert not pilot.app.query("#add-seat")
        e.query_one("#effort-0", Select).value = "high"
        await pilot.pause()
        assert e.value == "opus high"
        e.query_one("#model-0", Select).value = "inherit"
        await pilot.pause()
        assert e.value == "inherit" and e.query_one("#effort-0", Select).disabled


async def test_seats_editor_list_role():
    async with host(SeatsEditor("arena cross-judge pool", "fable medium, claude-opus-5-5 max", id="e")).run_test() as pilot:
        e = pilot.app.query_one("#e", SeatsEditor)
        assert e.value == "fable medium, claude-opus-5-5 max"        # an unknown id survives
        await pilot.click("#add-seat"); await pilot.pause()
        assert e.value == "fable medium, claude-opus-5-5 max, opus medium"
        e.query_one("#model-2", Select).value = "codex"
        await pilot.pause()
        assert e.value.endswith(", codex")
        for _ in range(4):
            await pilot.click("#remove-seat")
        await pilot.pause()
        assert e.value == "fable medium"


async def test_seats_editor_opens_what_it_cannot_parse():
    for role, value, effort in (("bug-fix", "opus fast", "fast"),
                                ("arena runners", "fable medium,opus medium", "medium,opus medium")):
        async with host(SeatsEditor(role, value, id="e")).run_test() as pilot:
            e = pilot.app.query_one("#e", SeatsEditor)
            assert e.value == value and e.query_one("#effort-0", Select).value == effort, "opening changes nothing"


async def test_lines_editor_saves_on_blur():
    fake = FakeAdapter({"hindsight.paths": "~/dev"})
    app = SettingsApp(settings=[paths_setting], adapters={"tool": fake})
    async with app.run_test() as pilot:
        ed = app.query_one("#w-hindsight-paths", LinesEditor)
        ed.focus(); ed.text = "~/dev\n\n /opt/src \n"
        await pilot.press("tab"); await pilot.pause()
        assert fake.writes == [("hindsight.paths", "~/dev\n/opt/src")]
        ed.focus(); await pilot.press("end", "p"); await pilot.pause()
        assert "p\n" in ed.text + "\n" and not isinstance(app.screen, StackScreen), "p types into the box"
        await pilot.press("backspace", "tab"); await pilot.pause()
        fake.values["hindsight.paths"] = "~/work"; app.refresh_values(); await pilot.pause()
        assert ed.text == "~/work" and len(fake.writes) == 1, "a box without focus redraws without a save"
        ed.focus(); await pilot.press("end", "p"); await pilot.pause()
        fake.values["hindsight.paths"] = "~/other"; app.refresh_values(); await pilot.pause()
        assert ed.text.endswith("p") and len(fake.writes) == 1, "a change on disk does not replace a typed edit"
        await pilot.press("tab"); await pilot.pause()
        assert fake.writes[-1] == ("hindsight.paths", "~/workp"), fake.writes


async def test_a_read_failure_saves_nothing_from_a_focused_box():
    fake = FakeAdapter({"hindsight.paths": "~/dev"})
    app = SettingsApp(settings=[paths_setting], adapters={"tool": fake})
    async with app.run_test() as pilot:
        ed = app.query_one("#w-hindsight-paths", LinesEditor)
        ed.focus(); await pilot.press("end", "enter", "~", "/", "h", "a"); await pilot.pause()
        fake.fail = SettingsError("file broke"); app.refresh_values(); await pilot.pause()
        assert app.query("#error") and ed.disabled and fake.writes == [], fake.writes
        fake.fail = None; app.refresh_values(); await pilot.pause()
        assert ed.text == "~/dev\n~/ha" and not ed.disabled, "the typed lines are still there"
        ed.focus(); await pilot.press("tab"); await pilot.pause()
        assert fake.writes == [("hindsight.paths", "~/dev\n~/ha")]


async def test_seats_editor_saves_through_the_app():
    fake = FakeAdapter({"jstack.bug_fix": "opus medium"})
    app = SettingsApp(settings=[bug_fix_setting], adapters={"tool": fake})
    async with app.run_test() as pilot:
        app.query_one("#w-jstack-bug_fix #effort-0", Select).value = "max"
        await pilot.pause()
        assert fake.writes == [("jstack.bug_fix", "opus max")]
        fake.values["jstack.bug_fix"] = "opus"; app.refresh_values(); await pilot.pause()
        e = app.query_one("#w-jstack-bug_fix", SeatsEditor)
        assert e.value == "opus" and e.query_one("#effort-0", Select).value == "medium"
        assert len(fake.writes) == 1, "a re-synced or model-only seat writes nothing"


async def test_ctrl_r_resets_from_inside_a_seat_picker():
    fake = FakeAdapter({"jstack.bug_fix": "opus high"}); fake.source = Source.OVERRIDE
    app = SettingsApp(settings=[bug_fix_setting], adapters={"tool": fake})
    async with app.run_test() as pilot:
        app.query_one("#w-jstack-bug_fix #model-0").focus(); await pilot.pause()
        await pilot.press("ctrl+r"); await pilot.pause()
        assert fake.resets == ["jstack.bug_fix"]


async def test_stack_screen_keep_and_off():
    tool.stack_scan = lambda cwd: [tool.StackRow("off", "b@m", "no signal")]
    applied = []
    tool.stack_apply = lambda cwd, keep, off: applied.append((keep, off)) or "applied"
    ran = []
    tool.run = lambda argv, cwd=None: ran.append(argv)      # any real tool reader would land here
    app = SettingsApp(settings=[], adapters={})             # empty means empty, not the real registry
    async with app.run_test() as pilot:
        assert ran == [] and not app.query("#w-stack-status")   # no real adapter ran, no real row drawn
        await pilot.press("p"); await pilot.pause(0.2)
        table = app.screen.query_one("#stack", DataTable)
        assert table.row_count == 1
        await pilot.press("k"); await pilot.pause(0.2)
        assert applied == [(["b@m"], [])]
        await pilot.press("p"); await pilot.pause()
        assert len(app.screen_stack) == 2, "p on the stack screen opens no second one"
        await pilot.press("escape"); await pilot.pause()
        assert not isinstance(app.screen, StackScreen)

        def missing(cwd):
            raise FileNotFoundError(2, "No such file", "bin/claude-stack")
        tool.stack_scan = missing
        await pilot.press("p"); await pilot.pause(0.2)
        assert app.is_running and str(app.screen.query_one("#stack-state", Static).content) == "Scan failed"


async def main():
    for test in (test_seats_editor_single_role, test_seats_editor_list_role,
                 test_seats_editor_opens_what_it_cannot_parse, test_lines_editor_saves_on_blur,
                 test_a_read_failure_saves_nothing_from_a_focused_box, test_seats_editor_saves_through_the_app,
                 test_ctrl_r_resets_from_inside_a_seat_picker, test_stack_screen_keep_and_off):
        await test()

asyncio.run(main())
print("ok")
