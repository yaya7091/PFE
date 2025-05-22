<?php
// Configuration
$DEEPSEEK_API_KEY = 'sk-6c2d1abb11624d65a5297aef975317b2';
$DEEPSEEK_API_URL = "https://api.deepseek.com/v1/analyse"; // Hypothetical API endpoint
$OUTPUT_FORMAT = "json"; // Choose "json" or "txt"
$MAX_FILE_SIZE_MB = 10; // Skip files larger than this (in MB)

// Check for API key
if (!$DEEPSEEK_API_KEY) {
    die("DeepSeek API key not set. Please set the DEEPSEEK_API_KEY environment variable.\n");
}


// Helper function to recursively scan a folder
function analyzeFolder($folderPath, $maxFileSizeMB) {
    $folderData = [
        "folder_name" => basename($folderPath),
        "total_files" => 0,
        "files" => []
    ];

    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($folderPath, RecursiveDirectoryIterator::SKIP_DOTS),
        RecursiveIteratorIterator::SELF_FIRST
    );

    foreach ($iterator as $file) {
        if ($file->isFile()) {
            $filePath = $file->getRealPath();
            $fileSize = $file->getSize();
            $fileSizeMB = $fileSize / (1024 * 1024);

            // Skip large files
            if ($fileSizeMB > $maxFileSizeMB) {
                echo "Skipping large file: $filePath (" . round($fileSizeMB, 2) . " MB)\n";
                continue;
            }

            $fileInfo = [
                "name" => $file->getFilename(),
                "path" => $filePath,
                "size_bytes" => $fileSize,
                "size_mb" => $fileSizeMB,
                "extension" => $file->getExtension(),
                "content" => null
            ];

            // Read text-based files (skip binaries)
            if (in_array(strtolower($fileInfo["extension"]), ["txt", "csv", "json", "php", "html", "log"])) {
                try {
                    $fileContent = file_get_contents($filePath);
                    $fileInfo["content"] = substr($fileContent, 0, 5000); // Read first 5KB
                } catch (Exception $e) {
                    $fileInfo["content"] = "Error reading file";
                }
            } else {
                $fileInfo["content"] = "Binary file (content not readable)";
            }

            $folderData["files"][] = $fileInfo;
            $folderData["total_files"]++;
        }
    }

    return $folderData;
}

// Simulate sending data to DeepSeek API (replace with actual API call)
function sendToDeepSeek($data, $apiKey, $apiUrl) {
    $ch = curl_init($apiUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $apiKey
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));

    $response = curl_exec($ch);
    if (curl_errno($ch)) {
        echo 'Curl error: ' . curl_error($ch);
    }
    curl_close($ch);

    return json_decode($response, true);
}
function outputResult($data, $format) {
    if ($format === 'json') {
        echo json_encode($data, JSON_PRETTY_PRINT);
    } elseif ($format === 'txt') {
        foreach ($data['files'] as $file) {
            echo "File: {$file['path']} - Size: {$file['size_mb']} MB\n";
        }
    }
}

// 👇 This is your main execution block — put it here, at the bottom:
$folderToAnalyze = "/tmp/service_logs"; // Replace with actual path
$analyzedData = analyzeFolder($folderToAnalyze, $MAX_FILE_SIZE_MB);
$apiResponse = sendToDeepSeek($analyzedData, $DEEPSEEK_API_KEY, $DEEPSEEK_API_URL);
outputResult($apiResponse, $OUTPUT_FORMAT);