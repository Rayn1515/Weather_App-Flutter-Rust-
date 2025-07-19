use crate::{models::WeatherResponse, error::WeatherError};
use reqwest;
use serde_json::Value;

const API_URL: &str = "http://api.weatherapi.com/v1/forecast.json";
const API_KEY: &str = "API_KEY"; 

pub async fn fetch_weather(location: &str) -> Result<WeatherResponse, WeatherError> {
    let url = format!("{}?key={}&q={}&days=7", API_URL, API_KEY, location);
    
    let response = reqwest::get(&url)
        .await
        .map_err(|e| WeatherError::FetchError(e.to_string()))?;
        
    let json: Value = response.json()
        .await
        .map_err(|e| WeatherError::FetchError(e.to_string()))?;

    let current = &json["current"];
    let forecast_days = &json["forecast"]["forecastday"];
    
    let daily_forecast = forecast_days.as_array().unwrap().iter().map(|day| {
        crate::models::DailyForecast {
            date: day["date"].as_str().unwrap().to_string(),
            max_temp_c: day["day"]["maxtemp_c"].as_f64().unwrap(),
            min_temp_c: day["day"]["mintemp_c"].as_f64().unwrap(),
            condition: day["day"]["condition"]["text"].as_str().unwrap().to_string(),
        }
    }).collect();

    Ok(WeatherResponse {
        location: json["location"]["name"].as_str().unwrap().to_string(),
        temp_c: current["temp_c"].as_f64().unwrap(),
        condition: current["condition"]["text"].as_str().unwrap().to_string(),
        daily_forecast,
    })
}