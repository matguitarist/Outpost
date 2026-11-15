mod metrics;

use axum::{
    extract::State,
    response::{
        sse::{Event, KeepAlive, Sse},
        IntoResponse, Json,
    },
    routing::get,
    Router,
};
use metrics::{MetricsCollector, SharedCollector};
use serde_json::json;
use std::{convert::Infallible, net::SocketAddr, sync::{Arc, Mutex}, time::Duration};
use tokio_stream::StreamExt;
use tower_http::cors::CorsLayer;
use tracing::info;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "outpost_agent=info".into()),
        )
        .init();

    let collector = Arc::new(Mutex::new(MetricsCollector::new()));

    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/stats", get(stats_handler))
        .route("/stats/stream", get(stats_stream_handler))
        .layer(CorsLayer::permissive())
        .with_state(collector);

    let addr = SocketAddr::from(([127, 0, 0, 1], 7654));
    info!("Outpost agent listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_handler() -> impl IntoResponse {
    Json(json!({ "status": "ok", "agent": "outpost-agent", "version": "0.1.0" }))
}

async fn stats_handler(State(collector): State<SharedCollector>) -> impl IntoResponse {
    let mut col = collector.lock().unwrap();
    let stats = col.collect();
    Json(stats)
}

async fn stats_stream_handler(
    State(collector): State<SharedCollector>,
) -> Sse<impl tokio_stream::Stream<Item = Result<Event, Infallible>>> {
    let stream = tokio_stream::wrappers::IntervalStream::new(tokio::time::interval(Duration::from_secs(1)))
        .map(move |_| {
            let stats = {
                let mut col = collector.lock().unwrap();
                col.collect()
            };
            let json_str = serde_json::to_string(&stats).unwrap_or_default();
            Ok(Event::default().event("system").data(json_str))
        });

    Sse::new(stream).keep_alive(KeepAlive::default())
}
