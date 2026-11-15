"""Drives the terminal UI against a fake adapter with Textual's pilot. Needs Textual, so it runs through uv:
uv run --project settings python settings/tests/test_tui.py"""
import asyncio, atexit, shutil, sys, tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from textual.widgets import Input, Label, ListView, Select, Static, Switch

from dotfiles_settings.model import Setting, SettingsError, Source, Value
from dotfiles_settings.tui import SettingsApp

tmp = Path(tempfile.mkdtemp())
atexit.register(shutil.rmtree, tmp, True)


class FakeAdapter:
    write_note = "noted"

    def __init__(self, seeds: dict[str, str]):
        self.overrides: dict[str, str] = {}
        self.seeds = seeds
        self.fail: str | Exception | None = None
        self.refuse: str | Exception | None = None
        self.writes: list[tuple[str, str]] = []
        self.reads = 0
        self.path = tmp / "watched"
        self.ticks = 0
        self.touch()

    @staticmethod
    def error(e: str | Exception) -> Exception:
        return e if isinstance(e, Exception) else SettingsError(e)

    def touch(self):
        self.ticks += 1
        self.path.write_text(str(self.ticks))

    def watch_paths(self) -> list[Path]:
        return [self.path]

    def read(self, s: Setting) -> Value:
        self.reads += 1
        if self.fail:
            raise self.error(self.fail)
        seed = self.seeds.get(s.key)
        if s.key in self.overrides:
            return Value(s.id, self.overrides[s.key], Source.OVERRIDE, seed, False)
        if seed is not None:
            return Value(s.id, seed, Source.SEED, seed, False)
        return Value(s.id, None, Source.UNSET, None, False)

    def write(self, s: Setting, value: str) -> None:
        if self.refuse:
            raise self.error(self.refuse)
        self.writes.append((s.key, value))
        self.overrides[s.key] = value
        self.touch()

    def reset(self, s: Setting) -> None:
        if self.refuse:
            raise self.error(self.refuse)
        self.overrides.pop(s.key, None)


def S(id, key, type, section="One", access="rw", **kw):
    return Setting(id=id, section=section, label=id, help=f"help for {id}", kind="env", key=key, type=type,
                   access=access, **kw)


SETTINGS = [
    S("t.flag", "T_FLAG", "bool", true_value="1"),
    S("t.name", "T_NAME", "string"),
    S("t.pick", "T_PICK", "enum", choices=("a", "b")),
    S("t.locked", "T_LOCKED", "string", access="ro"),
    S("u.other", "U_OTHER", "string", section="Two"),
]


async def main():
    fake = FakeAdapter(seeds={"T_NAME": "seeded"})
    app = SettingsApp(SETTINGS, {"env": fake})
    async with app.run_test(size=(120, 40), notifications=True) as pilot:
        await pilot.pause()
        assert [str(i.query_one(Label).content) for i in app.query_one("#sections", ListView).children] == ["One", "Two"]
        assert isinstance(app.query_one("#w-t-flag"), Switch)
        assert isinstance(app.query_one("#w-t-pick"), Select)
        assert isinstance(app.query_one("#w-t-name"), Input) and app.query_one("#w-t-name", Input).value == "seeded"
        assert app.query_one("#w-t-locked").disabled and not app.query("#r-t-locked")
        assert fake.writes == [], "mounting wrote nothing"
        assert "seed" in str(app.query_one("#m-t-name", Static).content)

        app.query_one("#w-t-flag").focus(); await pilot.press("enter"); await pilot.pause()
        assert fake.writes == [("T_FLAG", "1")]
        seen = fake.reads; app.poll()
        assert fake.reads == seen, "the UI's own write is read once"
        assert app.query_one("#m-t-flag").has_class("-override")
        assert "override" in str(app.query_one("#m-t-flag", Static).content)
        assert any("noted" in str(n.message) for n in app._notifications)

        await pilot.press("ctrl+r"); await pilot.pause()
        assert "T_FLAG" not in fake.overrides and not app.query_one("#m-t-flag").has_class("-override"), "ctrl+r reset the focused row"
        assert app.query_one("#w-t-flag", Switch).value is False

        app.query_one("#w-t-name", Input).focus()
        await pilot.press("end", "!", "enter"); await pilot.pause()
        assert fake.overrides["T_NAME"] == "seeded!"
        await pilot.click("#r-t-name"); await pilot.pause()
        assert app.query_one("#w-t-name", Input).value == "seeded"
        app.query_one("#w-t-name", Input).focus()
        await pilot.press("end", "!", "enter"); await pilot.pause()
        app.query_one("#r-t-name").focus(); await pilot.press("enter"); await pilot.pause()
        assert app.focused is app.query_one("#w-t-name"), "focus stays on the row after Reset removes its button"

        fake.refuse = "nope"
        app.query_one("#w-t-name", Input).focus()
        await pilot.press("end", "?", "enter"); await pilot.pause()
        assert app.query_one("#w-t-name", Input).value == "seeded", "a refused value does not stay on screen"
        assert any(n.severity == "error" and "nope" in str(n.message) and n.timeout == 20 for n in app._notifications)
        fake.refuse = None

        fake.refuse = FileNotFoundError(2, "No such file or directory", "bin/hindsight-memory")
        app.query_one("#w-t-name", Input).focus()
        await pilot.press("end", "?", "enter"); await pilot.pause()
        assert app.is_running and any("hindsight-memory" in str(n.message) for n in app._notifications)
        fake.overrides["T_NAME"] = "set"; app.refresh_values(); await pilot.pause()
        app.query_one("#w-t-name", Input).focus(); await pilot.press("ctrl+r"); await pilot.pause()
        assert app.is_running and fake.overrides["T_NAME"] == "set", "a reset that cannot run is a notice"
        fake.refuse = None; fake.overrides.pop("T_NAME")
        fake.fail = PermissionError(13, "Permission denied", "config.override.toml")
        app.refresh_values(); await pilot.pause()
        assert "Permission denied" in str(app.query_one("#error", Static).content)
        fake.fail = None; app.refresh_values(); await pilot.pause()

        app.query_one("#w-t-name", Input).focus()
        await pilot.press("end", "X", "tab"); await pilot.pause()
        assert fake.overrides["T_NAME"] == "seededX", "Tab saves a single-line field, as it saves a lines box"
        app.query_one("#w-t-name", Input).focus()
        await pilot.press("end", "Y"); await pilot.pause()
        fake.overrides["T_NAME"] = "elsewhere"; app.refresh_values(); await pilot.pause()
        assert app.query_one("#w-t-name", Input).value == "seededXY", "a change on disk does not replace a typed edit"
        assert any("changed elsewhere" in str(n.message) for n in app._notifications)
        await pilot.press("enter"); await pilot.pause()
        assert fake.overrides["T_NAME"] == "seededXY"
        fake.overrides.pop("T_NAME"); app.refresh_values(); await pilot.pause()
        assert app.query_one("#w-t-name", Input).value == "seeded", "a box with no edit follows the disk"

        fake.overrides["T_PICK"] = "b"; fake.touch()
        await pilot.pause(2.5)
        assert app.query_one("#w-t-pick", Select).value == "b", "a second UI's write shows up"

        fake.fail = "config.override.toml: bad"; fake.touch()
        await pilot.pause(2.5)
        assert "config.override.toml" in str(app.query_one("#error", Static).content)
        assert app.query_one("#w-t-flag").disabled
        fake.fail = None; fake.touch()
        await pilot.pause(2.5)
        assert not app.query("#error") and not app.query_one("#w-t-flag").disabled, "a fixed file clears the banner"

    empty = SettingsApp([], {})
    async with empty.run_test(size=(120, 40)) as pilot:
        await pilot.pause()
        assert not empty.query("#sections ListItem"), "empty means empty, not the real registry"

    locked = FakeAdapter(seeds={})
    locked.fail = PermissionError(13, "Permission denied", "config.override.toml")
    unreadable = SettingsApp(SETTINGS, {"env": locked})
    async with unreadable.run_test(size=(120, 40)) as pilot:
        await pilot.pause()
        assert "Permission denied" in str(unreadable.query_one("#error", Static).content)

asyncio.run(main())
print("ok")
