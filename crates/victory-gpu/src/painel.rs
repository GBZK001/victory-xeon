//! P1nkman: the diagnostics panel (`VICTORY_DEBUG_HUD`, on unless `0`) and the window's
//! caption, in Portuguese, as in the DexNom-based builds the owner chose (p19 to p22): frames
//! a second, ms a frame, draws, the wait for the GPU, preparing on the CPU, the copy-back,
//! draws dropped and the process's memory; the caption adds the GPU's share, the CPU's and
//! how long the game has been running.

use std::sync::Mutex;
use std::time::{Duration, Instant};

use windows::Win32::Foundation::HWND;
use windows::Win32::UI::WindowsAndMessaging::SetWindowTextW;
use windows::core::PCWSTR;

/// One second of the frame meter, per frame.
pub(crate) struct Figures {
    pub(crate) fps: f64,
    pub(crate) ms: f64,
    pub(crate) draws: f64,
    /// Preparing submissions on the CPU, ms.
    pub(crate) cpu: f64,
    /// Waiting for the GPU, ms.
    pub(crate) gpu: f64,
    /// Copying back what shaders wrote, ms.
    pub(crate) back_ms: f64,
    pub(crate) dropped: f64,
}

/// Called by the frame meter once a second, for the game's window `hwnd`.
pub(crate) fn frame(hwnd: HWND, f: &Figures) {
    let Figures { fps, ms, draws, cpu, gpu, back_ms, dropped } = *f;
    // The process's share of the whole machine since the last call.
    static CPU: Mutex<Option<(Instant, u64)>> = Mutex::new(None);
    let cpu_pct = {
        let now = (Instant::now(), process_cpu_us().unwrap_or(0));
        let mut last = CPU.lock().unwrap_or_else(|e| e.into_inner());
        let pct = last.map_or(0.0, |(at, us)| {
            now.1.saturating_sub(us) as f64 / 1e6 / now.0.duration_since(at).as_secs_f64().max(1e-3)
                / f64::from(logical_processors())
                * 100.0
        });
        *last = Some(now);
        pct
    };
    let gpu_pct = if ms > 0.0 { gpu / ms * 100.0 } else { 0.0 };
    let ram_mb = process_working_set().unwrap_or(0) as f64 / (1024.0 * 1024.0);
    crate::debug_hud::update(hwnd, || {
        format!("P1nkman - diagnóstico\n{fps:.1} FPS   {ms:.1} ms/quadro   {draws:.0} draws/quadro\nEspera da GPU {gpu:.1} ms   Preparo na CPU {cpu:.1} ms   Cópia de volta {back_ms:.1} ms\nDescartados {dropped:.0}/quadro   RAM {ram_mb:.0} MB")
    });
    let text = format!(
        "P1nkman | {fps:.0} FPS {ms:.1} ms/quadro | GPU {gpu_pct:.0}% ocupada \
         CPU {cpu_pct:.0}% RAM {ram_mb:.0} MB | {draws:.0} draws/quadro"
    );
    // Setting the text waits for the window's thread (a title thread,
    // which may not pump for a while), so a thread of ours does it and
    // presenting never waits; it takes the newest figures when free, and
    // keeps the running time moving while frames are slow or absent.
    static PENDING: Mutex<Option<(usize, String)>> = Mutex::new(None);
    static SETTER: std::sync::Once = std::sync::Once::new();
    *PENDING.lock().unwrap_or_else(|e| e.into_inner()) = Some((hwnd.0 as usize, text));
    SETTER.call_once(|| {
        let _ = std::thread::Builder::new().name("victory-caption".into()).spawn(|| {
            let (mut newest, mut shown) = (None, String::new());
            loop {
                let next = PENDING.lock().unwrap_or_else(|e| e.into_inner()).take();
                newest = next.or(newest);
                if let Some((hwnd, figures)) = &newest {
                    let text = caption(figures, process_uptime());
                    if text != shown {
                        let wide: Vec<u16> = text.encode_utf16().chain([0]).collect();
                        // SAFETY: a window handle and a NUL-terminated text.
                        unsafe {
                            let _ = SetWindowTextW(HWND(*hwnd as *mut _), PCWSTR(wide.as_ptr()));
                        }
                        shown = text;
                    }
                }
                std::thread::sleep(Duration::from_millis(100));
            }
        });
    });
}

fn process_cpu_us() -> Option<u64> {
    use windows_sys::Win32::Foundation::FILETIME;
    use windows_sys::Win32::System::Threading::{GetCurrentProcess, GetProcessTimes};
    // SAFETY: plain C structs, zero is a valid value for each.
    let (mut creation, mut exit, mut kernel, mut user) = unsafe {
        (
            std::mem::zeroed::<FILETIME>(),
            std::mem::zeroed::<FILETIME>(),
            std::mem::zeroed::<FILETIME>(),
            std::mem::zeroed::<FILETIME>(),
        )
    };
    // SAFETY: the current-process pseudo handle and four writable FILETIMEs.
    let ok = unsafe {
        GetProcessTimes(
            GetCurrentProcess(),
            &mut creation,
            &mut exit,
            &mut kernel,
            &mut user,
        )
    };
    if ok == 0 {
        return None;
    }
    let ticks = |f: FILETIME| (u64::from(f.dwHighDateTime) << 32) | u64::from(f.dwLowDateTime);
    Some((ticks(kernel) + ticks(user)) / 10)
}

/// The process's working set in bytes.
#[cfg(windows)]
fn process_working_set() -> Option<u64> {
    use windows_sys::Win32::System::ProcessStatus::{
        GetProcessMemoryInfo, PROCESS_MEMORY_COUNTERS,
    };
    use windows_sys::Win32::System::Threading::GetCurrentProcess;
    // SAFETY: a plain C struct, zero is a valid value.
    let mut counters = unsafe { std::mem::zeroed::<PROCESS_MEMORY_COUNTERS>() };
    // SAFETY: the current-process pseudo handle and a counter of the size passed.
    let ok = unsafe {
        GetProcessMemoryInfo(
            GetCurrentProcess(),
            &mut counters,
            std::mem::size_of::<PROCESS_MEMORY_COUNTERS>() as u32,
        )
    };
    (ok != 0).then_some(counters.WorkingSetSize as u64)
}

/// The machine's logical processors.
#[cfg(windows)]
fn logical_processors() -> u32 {
    use windows_sys::Win32::System::SystemInformation::{GetSystemInfo, SYSTEM_INFO};
    // SAFETY: the call fills the plain struct.
    let mut info = unsafe { std::mem::zeroed::<SYSTEM_INFO>() };
    // SAFETY: as above.
    unsafe { GetSystemInfo(&mut info) };
    info.dwNumberOfProcessors.max(1)
}

/// How long ago the kernel created this process.
#[cfg(windows)]
fn process_age() -> Option<Duration> {
    use windows_sys::Win32::Foundation::FILETIME;
    use windows_sys::Win32::System::Threading::{GetCurrentProcess, GetProcessTimes};
    // A FILETIME counts 100 ns from 1601; the Unix epoch is this many later.
    const UNIX_EPOCH_TICKS: u64 = 116_444_736_000_000_000;
    // SAFETY: plain C structs, zero is a valid value for each.
    let mut times = unsafe { std::mem::zeroed::<[FILETIME; 4]>() };
    let [creation, exit, kernel, user] = &mut times;
    // SAFETY: the current-process pseudo handle and four writable FILETIMEs.
    if unsafe { GetProcessTimes(GetCurrentProcess(), creation, exit, kernel, user) } == 0 {
        return None;
    }
    let ticks = (u64::from(creation.dwHighDateTime) << 32) | u64::from(creation.dwLowDateTime);
    let created = Duration::from_nanos(ticks.checked_sub(UNIX_EPOCH_TICKS)?.checked_mul(100)?);
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .ok()?
        .checked_sub(created)
}

/// How long the process has been running: its age when first asked, plus the
/// time since, so the wall clock being set does not move it.
fn process_uptime() -> Duration {
    static FIRST: std::sync::OnceLock<(Instant, Duration)> = std::sync::OnceLock::new();
    let (at, age) = *FIRST.get_or_init(|| (Instant::now(), process_age().unwrap_or_default()));
    age + at.elapsed()
}

/// The window's caption: the meter's figures, then how long the process has
/// run, as minutes and seconds, with hours once there are any.
fn caption(figures: &str, up: Duration) -> String {
    let s = up.as_secs();
    let (h, m, s) = (s / 3600, s / 60 % 60, s % 60);
    if h == 0 {
        format!("{figures} | ligado há {m}:{s:02}")
    } else {
        format!("{figures} | ligado há {h}:{m:02}:{s:02}")
    }
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_caption_ends_with_how_long_the_process_has_run() {
        let figures = "P1nkman | 1 FPS 953.5 ms/quadro | 1526 draws/quadro";
        let up = |secs| caption(figures, Duration::from_secs(secs));
        assert_eq!(up(0), format!("{figures} | ligado há 0:00"));
        assert_eq!(up(59), format!("{figures} | ligado há 0:59"));
        assert_eq!(up(754), format!("{figures} | ligado há 12:34"));
        assert_eq!(up(3723), format!("{figures} | ligado há 1:02:03"));
    }
}
