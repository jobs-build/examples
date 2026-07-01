// A tiny tiny_http "hello world" server built by JOBS via the cargo-build plugin.
// Flags come from clap (derive proc-macros — which the musl-host toolchain builds
// thanks to the vendored loader); request logging via log + env_logger. The Rust
// analogue of go-build/main.go.
use clap::Parser;
use std::time::Instant;
use tiny_http::{Response, Server};

#[derive(Parser)]
#[command(name = "hello", about = "a tiny tiny_http server that logs with env_logger")]
struct Args {
    /// address to listen on (host:port)
    #[arg(short, long, default_value = "0.0.0.0:8080")]
    addr: String,
    /// log level: error, warn, info, debug, trace
    #[arg(long, default_value = "info")]
    log_level: String,
}

fn main() {
    let args = Args::parse();
    env_logger::Builder::new().parse_filters(&args.log_level).init();

    log::info!("starting server addr={}", args.addr);
    let server = Server::http(&args.addr).expect("bind address");
    for request in server.incoming_requests() {
        let start = Instant::now();
        let method = request.method().to_string();
        let path = request.url().to_string();
        let _ = request.respond(Response::from_string("hello world\n"));
        log::info!("request method={} path={} duration={:?}", method, path, start.elapsed());
    }
}
