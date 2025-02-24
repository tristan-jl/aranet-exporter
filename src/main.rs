use aranet4::sensor::SensorManager;
use prometheus_exporter::prometheus::{register_gauge, register_int_gauge};
use std::{env, net::SocketAddr};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| format!("{}=debug", env!("CARGO_CRATE_NAME")).into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let port = env::var("PORT").unwrap_or("9186".to_string());
    let addr_raw = format!("0.0.0.0:{port}");
    let addr: SocketAddr = addr_raw.parse().expect("can not parse listen addr");
    let exporter = prometheus_exporter::start(addr).expect("can not start exporter");

    tracing::info!("Starting exporter at: {addr}");

    let mut sensor_addr = env::var("ARANET_ADDR").ok();
    sensor_addr = sensor_addr.and_then(|i| if i.len() > 0 { Some(i) } else { None });

    let sensor = SensorManager::init(sensor_addr)
        .await
        .expect("Unable to find Aranet sensor");

    tracing::info!("Found sensor");

    let co2_ppm = register_int_gauge!("aranet4_co2_ppm", "CO2 level in parts per million.")
        .expect("could not create gauge");
    let temp_c = register_gauge!("aranet4_temperature_c", "Temperature in celcius.")
        .expect("could not create gauge");
    let humidity_pc = register_int_gauge!(
        "aranet4_humidity_percent",
        "Relative humidity as percentage."
    )
    .expect("could not create gauge");
    let pressure_hpa = register_gauge!("aranet4_pressure_hpa", "Atmospheric pressure in hPa.")
        .expect("could not create gauge");
    let battery_pc = register_int_gauge!("aranet4_battery_percent", "Battery level as percentage.")
        .expect("could not create gauge");

    loop {
        {
            // Will block until duration is elapsed.
            let _guard = exporter.wait_request();

            if let Ok(sr) = sensor.read_current_values().await {
                tracing::info!("Updating metrics");
                co2_ppm.set(sr.co2_level.into());
                temp_c.set(sr.temperature.into());
                humidity_pc.set(sr.humidity.into());
                pressure_hpa.set(sr.pressure.into());
                battery_pc.set(sr.battery.into());
            } else {
                tracing::error!("Failed to read Aranet sensor");
            }
        }
    }
}
