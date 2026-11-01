#[cfg(feature = "greeting")]
pub const GREETING: &str = "hello from a greeting build";

#[cfg(not(feature = "greeting"))]
pub const GREETING: &str = "hello";

#[no_mangle]
pub extern "C" fn hello_cross_answer() -> u32 {
    42
}
