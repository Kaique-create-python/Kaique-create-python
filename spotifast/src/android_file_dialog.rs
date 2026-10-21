//! Android compatibility placeholder for SpotiFast's desktop file picker.
//! The original desktop-only rfd picker cannot compile on Android.
//! This module intentionally returns None; Android Storage Access Framework
//! integration is a separate TODO, never claim local cover selection works.
use std::path::{Path, PathBuf};

#[derive(Clone, Debug)]
pub struct FileHandle(PathBuf);
impl FileHandle {
    pub fn path(&self) -> &Path { &self.0 }
}
#[derive(Clone, Debug, Default)]
pub struct AsyncFileDialog;
impl AsyncFileDialog {
    pub fn new() -> Self { Self }
    pub fn set_title(self, _title: &str) -> Self { self }
    pub fn add_filter(self, _name: &str, _extensions: &[&str]) -> Self { self }
    pub async fn pick_file(self) -> Option<FileHandle> { None }
    pub async fn pick_folder(self) -> Option<FileHandle> { None }
}
