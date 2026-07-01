use pyo3::prelude::*;

/// Build the greeting string in Rust — called from Python to prove the native
/// module compiled and loaded.
#[pyfunction]
fn greeting(name: &str) -> String {
    format!("hello {name}")
}

/// The native module `myapp._native`.
#[pymodule]
fn _native(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(greeting, m)?)?;
    Ok(())
}
