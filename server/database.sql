CREATE TABLE sensor_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50),
    trash_weight FLOAT,
    trash_percent FLOAT,
    trash_full BOOLEAN,
    tissue_height FLOAT,
    tissue_empty BOOLEAN,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);