mod api;
mod models;
mod error;

use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};
use serde::Deserialize;
use crate::api::fetch_weather;

#[derive(Deserialize)]
struct WeatherQuery {
    location: String,
}

#[get("/weather")]
async fn get_weather(query: web::Query<WeatherQuery>) -> HttpResponse {
    match fetch_weather(&query.location).await {
        Ok(data) => HttpResponse::Ok().json(data),
        Err(e) => {
            log::error!("API error: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();
    log::info!("Starting server at http://127.0.0.1:8080");
    
    HttpServer::new(|| {
        App::new()
            .service(get_weather)
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
}