//! JNI bridge for the original Rust SpotiFast on Android.
//! Browser authorization uses a real Android ACTION_VIEW intent.
//! OAuth grants are sealed with AndroidKeyStore AES/GCM by SpotiFastActivity.
//! No tokens are logged or written unencrypted to filesystem preferences.

use std::{io, sync::OnceLock};
use android_activity::AndroidApp;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use jni::{jni_sig, jni_str, JValue, objects::{JObject, JString}};

static APP: OnceLock<AndroidApp> = OnceLock::new();

pub(crate) fn install(app: &AndroidApp) {
    let _ = APP.set(app.clone());
}

fn with_activity<T>(
    operation: impl FnOnce(&mut jni::Env<'_>, &JObject<'_>) -> jni::errors::Result<T>,
) -> Result<T, String> {
    let app = APP.get().ok_or_else(|| "Android Activity is not ready".to_owned())?;
    // SAFETY: android-activity owns this valid JVM reference for APP's lifetime.
    let vm = unsafe { jni::JavaVM::from_raw(app.vm_as_ptr().cast()) };
    // Keep the JNI global-ref pointer storage alive for the entire
    // attachment scope (and any borrow tied to Env's local frame).
    let raw = app.activity_as_ptr() as jni::sys::jobject;
    vm.attach_current_thread(|env| {
        // SAFETY: Borrowed global activity reference. Do not delete it.
        let activity = unsafe { env.as_cast_raw::<JObject>(&raw)? };
        operation(env, activity.as_ref())
    }).map_err(|e| e.to_string())
}

fn java_result_string(
    env: &mut jni::Env<'_>,
    value: jni::objects::JObject<'_>,
) -> jni::errors::Result<Option<String>> {
    if value.is_null() { return Ok(None); }
    let text = env.as_cast::<JString>(&value)?;
    Ok(Some(text.try_to_string(env)?))
}

pub(crate) fn app_files_path() -> io::Result<String> {
    with_activity(|env, activity| {
        let value = env.call_method(
            activity,
            jni_str!("appFilesPath"),
            jni_sig!("()Ljava/lang/String;"),
            &[],
        )?.l()?;
        java_result_string(env, value)?.ok_or(jni::errors::Error::NullPtr("appFilesPath"))
    }).map_err(|_| io::Error::other("Android app data path unavailable"))
}

/// Open the supplementary Audius/Jamendo/YouTube music catalogue.
pub(crate) fn open_free_music() -> io::Result<()> {
    with_activity(|env, activity| {
        env.call_method(
            activity,
            jni_str!("openFreeMusic"),
            jni_sig!("()V"),
            &[],
        )?;
        Ok(())
    }).map_err(|_| io::Error::other("Could not open Android free-music screen"))
}

pub(crate) fn open_url(url: &str) -> io::Result<()> {
    if !url.starts_with("https://") && !url.starts_with("http://") {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "URL scheme not allowed"));
    }
    with_activity(|env, activity| {
        let url = JString::from_str(env, url)?;
        env.call_method(
            activity,
            jni_str!("openExternalUrl"),
            jni_sig!("(Ljava/lang/String;)V"),
            &[JValue::Object(&url)],
        )?;
        Ok(())
    }).map_err(|_| io::Error::other("Cannot open Android system browser"))
}

pub(crate) fn read_secret(key: &str) -> Result<Option<Vec<u8>>, String> {
    let result = with_activity(|env, activity| {
        let key = JString::from_str(env, key)?;
        let value = env.call_method(
            activity,
            jni_str!("readSecretB64"),
            jni_sig!("(Ljava/lang/String;)Ljava/lang/String;"),
            &[JValue::Object(&key)],
        )?.l()?;
        java_result_string(env, value)
    })?;
    result.map(|encoded| STANDARD.decode(encoded).map_err(|_| "Invalid encrypted grant encoding".to_owned())).transpose()
}

pub(crate) fn write_secret(key: &str, secret: &[u8]) -> Result<(), String> {
    let encoded = STANDARD.encode(secret);
    with_activity(|env, activity| {
        let key = JString::from_str(env, key)?;
        let encoded = JString::from_str(env, &encoded)?;
        env.call_method(
            activity,
            jni_str!("writeSecretB64"),
            jni_sig!("(Ljava/lang/String;Ljava/lang/String;)V"),
            &[JValue::Object(&key), JValue::Object(&encoded)],
        )?;
        Ok(())
    })
}

pub(crate) fn delete_secret(key: &str) -> Result<(), String> {
    with_activity(|env, activity| {
        let key = JString::from_str(env, key)?;
        env.call_method(
            activity,
            jni_str!("deleteSecret"),
            jni_sig!("(Ljava/lang/String;)V"),
            &[JValue::Object(&key)],
        )?;
        Ok(())
    })
}
