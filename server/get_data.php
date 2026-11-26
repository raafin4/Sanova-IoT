<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
    require_once __DIR__ . '/config.php';

    $conn = new mysqli($servername, $username, $password, $dbname);

    if ($conn->connect_error) {
        echo json_encode(['status' => 'error', 'message' => 'Database connection failed: ' . $conn->connect_error]);
        exit;
    }

    // Ambil data terbaru (misalnya 1 terakhir)
    $sql = "SELECT * FROM sensor_data ORDER BY id DESC LIMIT 1";
    $result = $conn->query($sql);

    if ($result && $row = $result->fetch_assoc()) {
        echo json_encode([
            'status' => 'success',
            'data' => [
                'device_id' => $row['device_id'],
                'tissue_percent' => floatval($row['tissue_percent']),
                'trash_percent' => floatval($row['trash_percent']),
                'timestamp' => $row['timestamp']
            ]
        ]);
    } else {
        echo json_encode(['status' => 'error', 'message' => 'No data found']);
    }

    $conn->close();
} else {
    echo json_encode(['status' => 'error', 'message' => 'Only GET method allowed']);
}
