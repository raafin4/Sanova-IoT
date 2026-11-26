<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validasi data yang diperlukan
    if (!isset($data['device_id']) || !isset($data['tissue_percent']) || !isset($data['trash_percent'])) {
        echo json_encode(['status' => 'error', 'message' => 'Missing required data']);
        exit;
    }
    
    // Koneksi database
    require_once __DIR__ . '/config.php';

    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        echo json_encode(['status' => 'error', 'message' => 'Database connection failed: ' . $conn->connect_error]);
        exit;
    }
    
    // Query SQL - menyimpan data persentase (kompatibel dengan tabel lama)
    $sql = "INSERT INTO sensor_data (device_id, tissue_percent, trash_percent) VALUES (?, ?, ?)";
    
    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        echo json_encode(['status' => 'error', 'message' => 'Prepare statement failed: ' . $conn->error]);
        exit;
    }
    
    // Bind parameter: s = string, d = double/float
    // Mengisi kolom lama dengan nilai default 0, fokus pada persentase
    $stmt->bind_param("sdd", 
        $data['device_id'], 
        $data['tissue_percent'],
        $data['trash_percent']
    );
    
    if ($stmt->execute()) {
        echo json_encode([
            'status' => 'success', 
            'message' => 'Data saved successfully',
            'data' => [
                'device_id' => $data['device_id'],
                'tissue_percent' => $data['tissue_percent'],
                'trash_percent' => $data['trash_percent'],
                'timestamp' => date('Y-m-d H:i:s')
            ]
        ]);
    } else {
        echo json_encode(['status' => 'error', 'message' => 'Failed to save data: ' . $stmt->error]);
    }
    
    $stmt->close();
    $conn->close();
} else {
    // Jika bukan POST request
    echo json_encode(['status' => 'error', 'message' => 'Only POST method allowed']);
}
?>