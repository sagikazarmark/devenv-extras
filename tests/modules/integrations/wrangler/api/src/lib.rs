use std::cell::Cell;
use worker::*;

#[durable_object]
pub struct Counter {
    count: Cell<u32>,
}

impl DurableObject for Counter {
    fn new(_state: State, _env: Env) -> Self {
        Self { count: Cell::new(0) }
    }

    async fn fetch(&self, _req: Request) -> Result<Response> {
        self.count.set(self.count.get() + 1);
        Response::ok(format!("count {}", self.count.get()))
    }
}

#[event(fetch)]
async fn fetch(_req: Request, env: Env, _ctx: Context) -> Result<Response> {
    let stub = env.durable_object("COUNTER")?.id_from_name("shared")?.get_stub()?;
    let body = stub.fetch_with_str("http://counter/").await?.text().await?;
    Response::ok(format!("api: {body}"))
}
