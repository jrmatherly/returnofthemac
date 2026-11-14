# Menu bar app: your setup without a terminal

Return of the Mac is a menu bar app over the `rotm` command. It shows the state of your setup and changes it, and every action is one command that also works in a terminal. The app holds no settings logic of its own. Before it changes anything it shows the command it is about to run, and afterwards it shows what the command printed.

It needs macOS 14 or newer on Apple Silicon. It is the [`menubar` module](modules.md), which is on by default.

## What the menu shows

The app has no Dock icon and no window until you ask for one. Its icon in the menu bar gains a dot when something waits for you: a sync conflict, changes that are not synced yet, a saved profile whose file is missing on this Mac, an update for your setup, or a newer version of the app.

The menu, top to bottom. A line that ends in `…` asks before it runs anything, and the question names the command.

| Line | What it shows or runs |
| --- | --- |
| **Update Return of the Mac to 0.2.0…** | Only when a newer app exists. Runs `mise bootstrap packages upgrade --yes brew-cask:jrmatherly/tap/returnofthemac-app`. See [how the app updates](#how-the-app-updates) |
| The last command's output | What the last menu action printed, or its error, until you choose **Dismiss**. A note such as "Run `rotm install`" appears here |
| **Profile: work** | The [profile](settings-sync.md#profiles) in use. Its submenu lists `default` and every profile, with a tick on the one in use. Choosing another runs `rotm settings profile use <name>` |
| **New Profile…** (in the Profile submenu) | Asks for a name, then runs `rotm settings profile new <name>` |
| **Sync: on, 2 changes waiting** | The state of [settings sync](settings-sync.md). It also says when a conflict waits to be settled |
| **Sync Now** | Runs `rotm settings sync now`. Shown when sync is on |
| **Turn On Sync…** | Runs `rotm settings sync on` in the [console](#the-console), where you finish the GitHub sign-in. Shown when sync is off |
| **Setup: 2 updates waiting** | Whether an update for your setup is waiting. It reads `Setup: up to date` when none is, `Setup: not checked yet` before the first check, and `Setup: development clone` on a clone, which you pull yourself |
| **Update…** | Runs `rotm update -y` in the console |
| **More ▸ Run Setup Again…** | Runs `rotm install -y` in the console |
| **More ▸ Apply macOS Preferences…** | Runs `~/dotfiles/bin/set-defaults` in the console |
| **More ▸ Launch at Login** | Starts the app when you log in. Off until you turn it on |
| **Settings…** | Opens the [settings window](#the-settings-window) |
| **Quit** | Quits the app. It asks first while a command runs or while the settings window holds changes you have not applied |

One command runs at a time. While it runs, the other actions are disabled.

The state comes from two commands that change nothing. The app runs `rotm settings status --json` when the menu opens, every five minutes, and after each action. It runs `rotm update --check --json` at most once an hour, and again after a console command ends.

When the app cannot find `~/dotfiles/bin/rotm`, or `rotm` fails, the menu shows that message, a disabled **Settings…** and **Quit**.

## The console

Update, setup, the macOS preferences and turning sync on take minutes and can ask a question. The app runs each of them in a console window in place of Terminal. The command gets a terminal of its own, so a password prompt works as it does in Terminal.

- The window shows the command's output as it arrives, with its colours.
- Type an answer in the line below the output and press Return. At a password prompt the line hides what you type. A typed password is not shown and is not written to the log.
- **Stop** interrupts the command, as Ctrl-C does, and ends it two seconds later if it is still running. Closing the window while a command runs asks first, and then stops it.
- **Show Log in Finder** opens the folder that holds [the log of this run](#where-the-logs-are).
- When the command ends, the window says whether it finished, was stopped or ended with an exit code, and the menu reads the state again.

Quitting the app stops a command that is running in the console, so **Quit** asks first.

**Turn On Sync…** signs in to GitHub when `gh` is not signed in. The console prints a one-time code and waits for Return before it opens GitHub in your browser. [Settings sync](settings-sync.md#the-commands) describes what the command does after the sign-in.

## The settings window

**Settings…** opens a window with every setting that `rotm settings` manages. The sections are in a sidebar, and the search field matches a setting's name, its id and its help text. The first load takes a few seconds, because the app reads the settings with `rotm settings list --json`.

Each row has the setting's name, its help text and a control: a switch, a menu of choices, or a text field. A jstack role has a model and an effort menu for each seat, and a list of paths has **Add Entry** and a remove button per entry. A row whose value you changed from the default has an **Override** badge and a **Reset** button. A read-only row has a lock.

Changes are staged, not applied one by one:

1. Change as many settings as you want. Each changed row gets a **Changed** badge and an **Undo** button, and the bar at the bottom counts the changes.
1. Choose **Review…**. The sheet lists the commands that will run, one `rotm settings set` or `rotm settings reset` line per change.
1. Choose **Apply**. The app runs the commands in order. A command that fails does not stop the ones after it, and its change stays staged.

After Apply the bar shows what the commands printed, such as the line that tells you to run `set-defaults`, and any failure, until you choose **Dismiss**. A macOS preference takes effect as its change is applied, and the Dock or Finder restarts when the preference needs it. Nothing is installed by a change alone: run **Run Setup Again…** or **Apply macOS Preferences…** from the menu when a note asks for it.

While a [profile](settings-sync.md#profiles) is in use, changes go to that profile. Tick **Write to shared settings** in the bar to change your shared settings instead, which adds `--shared` to every staged command.

The window reads the settings again each time you bring it to the front and after every command the app runs. A staged change that a terminal command or a sync has already made is dropped from the list, and the others stay.

The app has no screen for the per-project plugin stack. That screen is in the terminal UI (`rotm settings tui`, then `p`).

## How the app starts

- **After an install.** The cask puts `Return of the Mac.app` in `/Applications`. Setup opens it in the background at the end of the first run that finds it there. Later setup runs and updates do not open it again, so an app you quit stays quit.
- **After a restart.** Turn on **More ▸ Launch at Login**. Without it, open the app from Applications, Launchpad or Spotlight.
- **Opening it while it runs** shows the settings window, or the menu when the app cannot find `rotm`. The app has no Dock icon, so this is also the way to reach it when the menu bar is too full to show its icon.

## How the app updates

The app updates through mise, which installed it. It has no updater of its own, and nothing installs by itself.

Once a day the app reads its cask file in the tap (`Casks/returnofthemac-app.rb` in `jrmatherly/homebrew-tap`, fetched from `raw.githubusercontent.com`) and compares the version there with its own. When the tap has a newer one, the icon gains its dot and the menu's first line reads **Update Return of the Mac to 0.2.0…**. A check that fails, as with no network, says nothing and is tried again later.

Choosing that line asks first, then runs this command from your home folder:

```shell
mise bootstrap packages upgrade --yes brew-cask:jrmatherly/tap/returnofthemac-app
```

The command does not run in the console, because a console command stops when the app quits and this one replaces the app. **Quit** is refused until it ends. The app then reads the version of the copy on disk. When that is the new version, the app quits and opens again. When it is not, the app stays open, shows what mise printed, and gives the command to run in Terminal (the same one without `--yes`, so mise asks before it upgrades).

`sysup` upgrades the app with the other casks. `rotm update` updates your setup and leaves the app's version alone.

## Where the logs are

Each console run writes `~/Library/Logs/returnofthemac/<date>-<time>-<title>.log`, such as `20261114-093012-Update.log`. Only your account can read the file, and the app keeps the newest 20. The same folder holds `opened-by-setup`, the empty file that tells setup it has opened the app once. Delete that file to have the next setup run open the app again.

Actions that run outside the console (a profile switch, **Sync Now**, an Apply in the settings window, the app's own update) write no log. Their output is in the menu or in the settings window's bar.

## Switch the app off

```shell
rotm settings set modules.menubar off
```

In the app, that is the **Menu bar app** switch in the settings window. To leave the app out from the start, add `--without menubar` to the [install line](installation.md#install-without-cloning).

With the module off, mise stops reading the app's cask and setup stops opening the app. The app stays installed and keeps running until you quit it, and **Launch at Login** stays as you set it. It is no longer updated, by `sysup` or by its own menu line, because mise upgrades only a cask that a config declares. [Modules](modules.md#switching-a-module-off-or-on) says how to remove what a module installed.
