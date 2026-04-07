<?php
define('LOG_FILE', __DIR__.'/wa_debug.log');
define('WEBHOOK_SECRET', 'hris2024bot');
define('CONFIG_FILE', __DIR__.'/bot_config.json');
define('DB_HOST', 'localhost');
define('DB_USER', 'u128823797_HRIS');
define('DB_PASS', '#Hris404#');
define('DB_NAME', 'u128823797_HRIS');

$ADMIN_PHONES = array('6281210846420');

function loadConfig() {
    if (!file_exists(CONFIG_FILE)) return array('bot_active' => false);
    $cfg = json_decode(file_get_contents(CONFIG_FILE), true);
    return $cfg ? $cfg : array('bot_active' => false);
}

function logIt($msg) {
    file_put_contents(LOG_FILE, date('Y-m-d H:i:s')." | $msg\n", FILE_APPEND);
}

function normalizePhone($p) {
    $p = preg_replace('/\D/', '', $p);
    if (substr($p, 0, 1) === '0') $p = '62'.substr($p, 1);
    return $p;
}

function sendWA($phone, $msg, $token, $url) {
    $ch = curl_init($url.'/api/send-message');
    curl_setopt_array($ch, array(
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => array('Authorization: '.$token),
        CURLOPT_POSTFIELDS => http_build_query(array('phone' => $phone, 'message' => $msg))
    ));
    $raw = curl_exec($ch);
    $http = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    logIt("SEND to $phone HTTP=$http raw=".substr($raw, 0, 120));
}

function callAI($endpoint, $apiKey, $model, $system, $messages) {
    $body = json_encode(array(
        'model'    => $model,
        'messages' => array_merge(array(array('role'=>'system','content'=>$system)), $messages),
        'max_tokens' => 400,
        'temperature' => 0.7
    ));
    $ch = curl_init($endpoint);
    curl_setopt_array($ch, array(
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => array('Content-Type: application/json','Authorization: Bearer '.$apiKey),
        CURLOPT_POSTFIELDS => $body,
        CURLOPT_TIMEOUT => 30
    ));
    $raw = curl_exec($ch);
    $err = curl_error($ch);
    $http = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    logIt("AI HTTP=$http cerr=$err raw=".substr($raw, 0, 200));
    $data = json_decode($raw, true);
    return isset($data['choices'][0]['message']['content']) ? trim($data['choices'][0]['message']['content']) : '';
}

function getHistory($pdo, $phone, $limit) {
    $limit = (int)$limit;
    $stmt = $pdo->prepare("SELECT role, content FROM bot_wa_history WHERE phone=? ORDER BY id DESC LIMIT $limit");
    $stmt->execute(array($phone));
    $rows = array_reverse($stmt->fetchAll(PDO::FETCH_ASSOC));
    $out = array();
    foreach ($rows as $r) { $out[] = array('role'=>$r['role'],'content'=>$r['content']); }
    return $out;
}

function saveHistory($pdo, $phone, $role, $content) {
    $stmt = $pdo->prepare("INSERT INTO bot_wa_history (phone, role, content) VALUES (?,?,?)");
    $stmt->execute(array($phone, $role, $content));
    $pdo->exec("DELETE FROM bot_wa_history WHERE phone='$phone' AND id NOT IN (SELECT id FROM (SELECT id FROM bot_wa_history WHERE phone='$phone' ORDER BY id DESC LIMIT 20) t)");
}

function getCustomer($pdo, $phone) {
    $stmt = $pdo->prepare("SELECT * FROM data_penyewa_perusahaan WHERE no_telpon LIKE ? LIMIT 1");
    $stmt->execute(array('%'.substr($phone,-9).'%'));
    return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
}

function buildGreeting($c, $name) {
    if ($c) return "Pelanggan: {$c['nama_penanggung_jawab']}, laptop: {$c['kode_laptop']}, status: {$c['status_pembayaran']}.";
    return "Pelanggan baru (belum ada data sewa).";
}

function buildFullKnowledge($pdo) {
    $out = array();
    try {
        $rows = $pdo->query("SELECT kategori, judul, isi FROM ai_knowledge WHERE aktif=1 ORDER BY kategori, id")->fetchAll(PDO::FETCH_ASSOC);
        foreach ($rows as $r) { $out[] = "[{$r['kategori']}] {$r['judul']}:\n{$r['isi']}"; }
    } catch (Exception $e) {}
    try {
        $rows = $pdo->query("SELECT kode_laptop, merek, tipe, ram, storage, harga_per_hari, status FROM data_laptop WHERE status='tersedia' LIMIT 20")->fetchAll(PDO::FETCH_ASSOC);
        foreach ($rows as $r) { $out[] = "[LAPTOP] {$r['kode_laptop']} {$r['merek']} {$r['tipe']} RAM:{$r['ram']} SSD:{$r['storage']} Rp{$r['harga_per_hari']}/hari"; }
    } catch (Exception $e) {}
    return $out;
}

// ============================================================
// HELPER: Parse lokasi dari payload Wablas
// Format Wablas location: lat|lng|name atau dalam field terpisah
// ============================================================
function parseLocation($data) {
    // Coba field location (object)
    if (!empty($data['location'])) {
        $loc = $data['location'];
        $lat  = $loc['latitude']  ?? $loc['lat'] ?? null;
        $lng  = $loc['longitude'] ?? $loc['lng'] ?? null;
        $name = $loc['name']      ?? $loc['address'] ?? '';
        if ($lat && $lng) {
            return array('lat' => $lat, 'lng' => $lng, 'name' => $name);
        }
    }
    // Format Wablas: "nama#alamat#lat#lng"
    $msg = $data['message'] ?? '';
    if (strpos($msg, '#') !== false) {
        $parts = explode('#', $msg);
        // Cari lat lng dari bagian yang berbentuk angka desimal negatif/positif
        $lat = null; $lng = null; $name = $parts[0] ?? ''; $alamat = $parts[1] ?? '';
        foreach ($parts as $p) {
            $p = trim($p);
            if (preg_match('/^-?\d+\.\d{4,}$/', $p)) {
                if ($lat === null) $lat = $p;
                elseif ($lng === null) $lng = $p;
            }
        }
        if ($lat && $lng) {
            return array('lat' => $lat, 'lng' => $lng, 'name' => $name, 'alamat' => $alamat);
        }
    }
    // Fallback: format "lat,lng" atau "lat|lng"
    if (preg_match('/(-?\d+\.\d+)[,|](-?\d+\.\d+)/', $msg, $m)) {
        return array('lat' => $m[1], 'lng' => $m[2], 'name' => '');
    }
    return null;
}

function locationToText($loc) {
    $mapsUrl = "https://www.google.com/maps?q={$loc['lat']},{$loc['lng']}";
    $name    = !empty($loc['name'])   ? $loc['name']   : '';
    $alamat  = !empty($loc['alamat']) ? $loc['alamat'] : '';
    $detail  = trim("$name - $alamat", ' -');

    // Hitung jarak dari Istana Komputer
    $jarak = hitungJarak(-6.2664338, 106.8758517, (float)$loc['lat'], (float)$loc['lng']);
    $jarakTeks = number_format($jarak, 1, '.', '') . ' km';
    $bisaAntar = $jarak <= 20 ? "BISA diantar (dalam radius 20km)" : "TIDAK BISA diantar (lebih dari 20km, jarak $jarakTeks)";

    return "[Lokasi: $detail] Koordinat: {$loc['lat']}, {$loc['lng']} | Maps: $mapsUrl | Jarak dari toko: $jarakTeks | Status: $bisaAntar";
}

function hitungJarak($lat1, $lng1, $lat2, $lng2) {
    $R = 6371; // radius bumi km
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $a = sin($dLat/2) * sin($dLat/2) +
         cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
         sin($dLng/2) * sin($dLng/2);
    $c = 2 * atan2(sqrt($a), sqrt(1-$a));
    return $R * $c;
}

// ===== MAIN =====
$cfg = loadConfig();

// Log viewer
if (isset($_GET['log']) && $_GET['log'] === WEBHOOK_SECRET) {
    header('Content-Type: text/plain; charset=utf-8');
    $lines = file_exists(LOG_FILE) ? file(LOG_FILE) : array();
    echo implode('', array_slice($lines, -500));
    exit;
}

// Secret check
if (($_GET['secret'] ?? '') !== WEBHOOK_SECRET) {
    http_response_code(403); exit('Forbidden');
}

// Bot OFF
if (empty($cfg['bot_active'])) {
    logIt("BOT OFF");
    http_response_code(200); exit('OK');
}

// Parse input
$raw = file_get_contents('php://input');
logIt("RAW: ".substr($raw, 0, 300));
$data = json_decode($raw, true);
if (!$data) { http_response_code(200); exit('OK'); }

$phone    = normalizePhone($data['phone'] ?? '');
$type     = $data['messageType'] ?? '';
$text     = trim($data['message'] ?? '');
$isGroup  = !empty($data['isGroup']);
$isFromMe = !empty($data['isFromMe']);

logIt("phone=$phone type=$type isGroup=".($isGroup?'true':'false')." msg=".substr($text,0,80));

// ── Handle tipe lokasi ──────────────────────────────────────
$isLocation = ($type === 'location' || $type === 'Location');
$locData    = null;

if ($isLocation) {
    $locData = parseLocation($data);
    if ($locData) {
        $text = locationToText($locData); // jadikan teks untuk AI
        logIt("LOCATION parsed: lat={$locData['lat']} lng={$locData['lng']}");
    } else {
        logIt("LOCATION: gagal parse koordinat");
        http_response_code(200); exit('OK');
    }
}

// Skip jika bukan teks/lokasi, atau dari grup
if ((!$isLocation && $type !== 'text') || empty($text) || $isGroup) {
    logIt("SKIP: bukan teks/lokasi atau grup");
    http_response_code(200); exit('OK');
}

// Trial Mode
if (!empty($cfg['trial_mode'])) {
    $allowed = $cfg['trial_numbers'] ?? array();
    if (!in_array($phone, $allowed)) {
        logIt("TRIAL MODE: $phone tidak di whitelist - diabaikan");
        http_response_code(200); exit('OK');
    }
    logIt("TRIAL MODE: $phone diizinkan");
}

// Skip pesan dari diri sendiri
if ($isFromMe) { http_response_code(200); exit('OK'); }

$token    = $cfg['wablas_token'] ?? '';
$url      = rtrim($cfg['wablas_url'] ?? 'https://sby.wablas.com', '/');
$prov     = $cfg['provider'] ?? 'groq';
$provCfg  = $cfg['providers'][$prov] ?? array();
$apiKey   = $provCfg['api_key'] ?? '';
$model    = $provCfg['model'] ?? '';
$endpoint = $provCfg['endpoint'] ?? '';

// DB
try {
    $pdo = new PDO('mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4', DB_USER, DB_PASS,
        array(PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION));
    logIt("DB OK");
} catch (Exception $e) {
    logIt("DB ERROR: ".$e->getMessage());
    http_response_code(200); exit('OK');
}

$customer = getCustomer($pdo, $phone);
logIt("Customer: ".($customer ? $customer['nama_penanggung_jawab'] : 'BARU'));

// Cek jam operasional (WIB)
date_default_timezone_set('Asia/Jakarta');
$hour = (int)date('H');
logIt("JAM WIB=$hour");
if ($hour < 8 || $hour >= 20) {
    $greet = "Maaf, kami tutup (08.00-20.00 WIB). Hubungi kami besok ya!";
    sendWA($phone, $greet, $token, $url);
    logIt("TUTUP - keluar");
    http_response_code(200); exit('OK');
}

logIt("STEP: akan load knowledge");
$knowledge = buildFullKnowledge($pdo);
$knowText  = $knowledge ? implode("\n\n", $knowledge) : 'Tidak ada data knowledge.';
logIt("STEP: knowledge ok, items=".count($knowledge));
$greeting  = buildGreeting($customer, $data['pushName'] ?? '');

$systemTemplate = $cfg['system_prompt'] ?? "Kamu adalah asisten WhatsApp untuk bisnis sewa laptop. Jawab singkat, ramah, dalam bahasa Indonesia.\n\nJika tidak tahu, arahkan ke admin 081210846420.";

if (strpos($systemTemplate, '{customer}') !== false) {
    $systemTemplate = str_replace('{customer}', $greeting, $systemTemplate);
} else {
    $systemTemplate .= "\n\nInfo pelanggan: $greeting";
}
if (strpos($systemTemplate, '{knowledge}') !== false) {
    $systemTemplate = str_replace('{knowledge}', $knowText, $systemTemplate);
} else {
    $systemTemplate .= "\n\nKnowledge:\n$knowText";
}

// Tambahkan instruksi khusus untuk lokasi
$systemTemplate .= "\n\nJika ada pesan berisi [Lokasi] dengan koordinat dan link Google Maps, artinya pelanggan sedang share lokasi pengiriman/penjemputan laptop. Konfirmasi lokasi tersebut dan tanyakan apakah ada yang perlu dibantu.";

$system = $systemTemplate;

logIt("STEP: akan getHistory");
try {
    $history = getHistory($pdo, $phone, 10);
} catch (Exception $e) {
    logIt("ERROR getHistory: ".$e->getMessage());
    $history = array();
}
logIt("STEP: history ok count=".count($history));
logIt("STEP: akan callAI endpoint=".$endpoint);
$history[] = array('role'=>'user','content'=>$text);

$reply = callAI($endpoint, $apiKey, $model, $system, $history);
logIt("STEP: callAI selesai reply=".substr($reply,0,50));

if ($reply) {
    logIt("REPLY [provider=$prov model=$model]: ".substr($reply, 0, 100));
    sendWA($phone, $reply, $token, $url);
    saveHistory($pdo, $phone, 'user', $text);
    saveHistory($pdo, $phone, 'assistant', $reply);
}

logIt("DONE");
http_response_code(200);
echo 'OK';
