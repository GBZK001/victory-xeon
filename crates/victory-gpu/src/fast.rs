//! A hash for small keys of ours (addresses, indices, offsets) in maps that
//! every draw looks into: the standard one (SipHash, built to resist keys a
//! stranger chooses) cost 3% of the title's recording threads in `bind`
//! (profile of 27 Nov, the boat on the Xeon). The same mixing as
//! `profile.rs`'s and rustc's FxHash; never for keys from outside.

use std::hash::{BuildHasherDefault, Hasher};

#[derive(Default, Clone, Copy)]
pub(crate) struct Fast(u64);

impl Hasher for Fast {
    fn write(&mut self, bytes: &[u8]) {
        for &b in bytes {
            self.write_u64(u64::from(b));
        }
    }
    fn write_u8(&mut self, v: u8) {
        self.write_u64(u64::from(v));
    }
    fn write_u32(&mut self, v: u32) {
        self.write_u64(u64::from(v));
    }
    fn write_u64(&mut self, v: u64) {
        self.0 = (self.0.rotate_left(5) ^ v).wrapping_mul(0x517c_c1b7_2722_0a95);
    }
    fn write_usize(&mut self, v: usize) {
        self.write_u64(v as u64);
    }
    fn finish(&self) -> u64 {
        self.0
    }
}

pub(crate) type FastMap<K, V> = std::collections::HashMap<K, V, BuildHasherDefault<Fast>>;
pub(crate) type FastSet<K> = std::collections::HashSet<K, BuildHasherDefault<Fast>>;
