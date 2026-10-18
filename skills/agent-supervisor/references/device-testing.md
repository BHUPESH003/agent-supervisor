# Device and app testing with agents

Agents can drive a real Android phone over adb, a browser through Playwright, or an emulator. They can use it to test flows or to compare the app against a reference design. Every rule here exists because breaking it once broke a run.

## One device, one agent
- A phone is a shared resource. Queue the agents that need it: start the next one when the previous one's PID exits. Two agents tapping the same screen corrupt each other's runs.
- Ask the user not to use the phone while an agent is driving it.
- **Pin the device** with `export ANDROID_SERIAL=<serial>` in the launching shell. The agent's adb calls and `gradlew install*` inherit it. When the user swaps phones, wait until the new serial appears in `adb devices`, then resume the agent with the new serial. Tell it that the screen size differs and old tap coordinates are invalid.
- If adb drops, run `adb kill-server && adb start-server` and retry for up to about 2 minutes. Put this in the brief so the agent doesn't stop and wait for a human.

## Driving the UI
- Get element bounds from `adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml`. Never reuse hard-coded coordinates across devices or app versions.
- Tap with `adb shell input tap X Y`, type with `adb shell input text`, and use `adb shell input keyevent 4` for back.
- Check for crashes: run `adb logcat -c` at the start, then `adb logcat -d '*:E' | grep -i '<package>\|AndroidRuntime\|FATAL'` after each role or flow.
- Lock the orientation to portrait, except when testing rotation on purpose.

## Screenshots
- **Bring the app to the front first**: `adb shell monkey -p <package> 1` or `am start -n <package>/<activity>`. Confirm it's the top activity with `dumpsys activity activities | grep -m1 topResumed`.
- **Check the file size before reading the image.** A phone launcher or another app (wallpaper, music player) produces 4 MB or larger PNGs. Once base64-encoded they exceed the 5 MB model image limit, and the session dies; worse, the image stays in the history, so every later resume fails too. Skip anything over 2 MB, because it's not your app. If it happens anyway, delete the file, compact the session, then resume.
- Never read screenshots of other apps or of the home screen. They may show the user's personal data.
- Save the before, after and reference images per unit in a scratch folder. Never commit them.

## Credentials
- Before typing anything, dump the UI and confirm the app's sign-in screen is showing. If the app died, for example killed by a reinstall, typed text lands in the launcher's search bar. That happened once, with a test password.
- Never UI-dump password fields, and never echo credentials in output or reports.
- Use sandbox or test accounts only, and read their credentials from the files where they live.
- If an agent leaked a credential anyway, tell the user which one and where it went.

## Safety on a live backend
Even on staging, other people's data and real notifications may be involved. Default to **view-only**:
- navigate, scroll and pull-to-refresh freely;
- no sending (messages, announcements, reminders), no payments, bookings, approvals, deletes or settings changes;
- for payment screens, open and check the screen, then back out.
Ask the agent to list everything it skipped for safety, and anything it did beyond the brief.

## Comparing against a reference design
1. Capture the reference (the web page at phone viewport, or the design file) and the app screen.
2. Look at both and write down the concrete differences: layout, hierarchy, imagery, sizes, density.
3. Read the reference source for exact sizes and colours.
4. Implement, recapture and compare again.
5. Commit.
Do this one screen at a time. Allow deliberate improvements over the reference if the user wants them, each recorded with a one-line reason in a parity log.

## Test report
Ask for:
- a table of role × screen with OK or the issue;
- each issue with its steps, screenshot name and logcat line;
- a cause tag per issue: upgrade, redesign, pre-existing or data;
- what wasn't covered.
If the user stops the run early, resume the agent once with "don't touch the device; write the report from what you already saw".
