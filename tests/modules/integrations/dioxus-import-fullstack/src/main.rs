use dioxus::prelude::*;

fn main() {
    dioxus::launch(App);
}

#[component]
fn App() -> Element {
    rsx! { h1 { "Hello from a Nix-built fullstack app!" } }
}
