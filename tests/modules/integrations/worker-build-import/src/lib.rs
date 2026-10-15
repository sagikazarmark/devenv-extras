use worker::*;

#[cfg(not(feature = "greeting"))]
compile_error!("worker-build.import should build with buildFeatures");

#[event(fetch)]
async fn fetch(_req: Request, _env: Env, _ctx: Context) -> Result<Response> {
    Response::ok("Hello from a Nix-built worker!")
}
