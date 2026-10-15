use dioxus::prelude::*;

#[cfg(not(feature = "greeting"))]
compile_error!("dioxus.import should build with buildFeatures");

// dx generates this with Tailwind CSS before building, from tailwind.css.
const TAILWIND: Asset = asset!("/assets/tailwind.css");

fn main() {
    dioxus::launch(App);
}

#[component]
fn App() -> Element {
    rsx! {
        document::Stylesheet { href: TAILWIND }
        h1 { class: "text-red-500", "Hello from a Nix-built Dioxus app!" }
    }
}
