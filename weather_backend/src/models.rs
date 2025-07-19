use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct WeatherResponse {
    pub location: String,
    pub temp_c: f64,
    pub condition: String,
    pub daily_forecast: Vec<DailyForecast>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DailyForecast {
    pub date: String,
    pub max_temp_c: f64,
    pub min_temp_c: f64,
    pub condition: String,
}