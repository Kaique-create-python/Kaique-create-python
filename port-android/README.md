# SpotiFast 0.14.1 for Android — real native-Rust port (work in progress)

This is NOT the previous simplified Java mock. The complete original Spotifast source lives in ../spotifast/. It is based on release v0.14.1 at commit 3ce8b3f274717e973c2914a93f7255e45ced06dd.

The newly added src/android.rs calls the ORIGINAL Rust app::App, background_frame and frame_ui, retaining the user interface and playback architecture.

Android build path:
- Build the Rust cdylib for aarch64-linux-android without desktop-only MilkDrop.
- Package libspotifast.so via the Gradle module in port-android/android.
- Test OAuth, playback, persistent keyring, phone controls, notification and lifecycle.

The current branch is early development, not a functioning Android APK. Actual platform blockers remain:
1. secure credentials through Android Keystore;
2. fastframe-audio -> Android audio sink (AAudio or Oboe) while preserving librespot;
3. removal/replacement of desktop-only tray, titlebar, autostart, update installers and windows;
4. Android-app sandbox paths, login URI intents and lifecycle;
5. responsive touch breakpoints for original egui views, physical phone tests.

Never replace the original player with a decorative mock-up. Original source is MIT licensed; keep license attribution.
