// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[cfg(target_os = "linux")]
mod linux_gtk;

fn main() {
    #[cfg(target_os = "linux")]
    {
        for variable in ["GTK_MODULES", "GTK3_MODULES"] {
            if let Some(filtered) = std::env::var_os(variable)
                .as_deref()
                .and_then(linux_gtk::without_appmenu_module)
            {
                unsafe { std::env::set_var(variable, filtered) };
            }
        }

        // WebKitGTK 2.42+ DMA-BUF renderer fails on proprietary NVIDIA drivers
        // and certain GPU setups ("Failed to create GBM buffer"), causing a blank window.
        if linux_gtk::should_disable_dmabuf_renderer(
            std::env::var_os(linux_gtk::WEBKIT_DISABLE_DMABUF_RENDERER).as_deref(),
        ) {
            unsafe {
                std::env::set_var(linux_gtk::WEBKIT_DISABLE_DMABUF_RENDERER, "1");
            }
        }
    }

    codex_switcher_lib::run()
}
