use worker::*;

#[event(fetch)]
async fn fetch(_req: Request, env: Env, _ctx: Context) -> Result<Response> {
    // The Counter Durable Object runs in the api worker.
    let stub = env.durable_object("COUNTER")?.id_from_name("shared")?.get_stub()?;
    let body = stub.fetch_with_str("http://counter/").await?.text().await?;
    Response::ok(format!("app: {body}"))
}
