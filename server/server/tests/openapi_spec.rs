#[tokio::test]
async fn print_schema_refs() {
    let router = together_server::main().await;
    let openapi = router.openapi();

    let mut found_ref = false;
    for op in openapi.operations() {
        for schema in op
            .parameters
            .iter()
            .chain(op.response.iter().flatten())
        {
            if let utoipa::openapi::RefOr::Ref(r) = schema {
                found_ref = true;
                println!("ref in {} {} -> {}", op.method, op.path, r.ref_location);
            }
        }
    }

    if !found_ref {
        println!("no $ref schemas found");
    }
}
