//! Android launcher for the ORIGINAL SpotiFast UI and backend.
//! This is the first integration step, not a separate Java lookalike.
//! It deliberately reuses app::App::new, background_frame and frame_ui.
//!
//! TODO before calling this a working port:
//! Android Keystore credentials, app-private dirs, native audio stream,
//! platform links/permissions, lifecycle and layout fitting.

use crate::{app, backend, paths, settings};

/// NativeActivity entrypoint. Must be exported from libspotifast.so.
#[unsafe(no_mangle)]
pub fn android_main(android_app: android_activity::AndroidApp) {
    let options = eframe::NativeOptions {
        android_app: Some(android_app),
        renderer: eframe::Renderer::Glow,
        viewport: egui::ViewportBuilder::default().with_title("SpotiFast"),
        ..eframe::NativeOptions::default()
    };

    if let Err(error) = eframe::run_native(
        "SpotiFast",
        options,
        Box::new(|cc| {
            let waker = backend::Waker::default();
            let dirs = paths::AppDirs::discover().dirs;
            let _ = dirs.ensure();
            let settings = settings::Settings::load(&dirs.settings_file());

            // The desktop tray, autostart and media integrations don't exist on Android.
            // Keep the original session, Spotify API, player, queue and egui views.
            let mut original = app::App::new(
                &waker,
                dirs,
                settings,
                app::AppOptions {
                    restore_sign_in: true,
                    media_controls: false,
                    tray: false,
                    autostart: false,
                },
            );
            original.attach(&cc.egui_ctx);
            Ok(Box::new(SpotiFastAndroid { original }))
        }),
    ) {
        log::error!("SpotiFast Android native surface failed: {error}");
    }
}

struct SpotiFastAndroid {
    original: app::App,
}

impl eframe::App for SpotiFastAndroid {
    fn logic(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // Same UI logic as the original desktop entrypoint.
        self.original.background_frame(ctx);
        // Also poll for backend events until the Android wake integration is done.
        ctx.request_repaint_after(std::time::Duration::from_millis(100));
    }

    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        // Original SpotiFast UI, not a new approximation.
        self.original.frame_ui(ui);
    }

    fn on_exit(&mut self, _gl: Option<&eframe::glow::Context>) {
        self.original.save_state();
        self.original.flush_files();
    }
}
