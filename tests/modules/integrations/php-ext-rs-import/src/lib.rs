use ext_php_rs::prelude::*;

#[php_function]
pub fn hello_php(name: &str) -> String {
    format!("Hello, {name}!")
}

#[php_module]
pub fn get_module(module: ModuleBuilder) -> ModuleBuilder {
    module.function(wrap_function!(hello_php))
}
