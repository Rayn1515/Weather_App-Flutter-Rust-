use thiserror::Error;

#[derive(Error, Debug)]
pub enum WeatherError {
    #[error("Failed to fetch weather data: {0}")]
    FetchError(String),
}