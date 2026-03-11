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
    // ── Bersihkan history sebelum kirim ke AI ─────────────────
    // Pastikan tidak ada 2 role sama berurutan (error di Groq/OpenAI)
    $cleaned = array();
    foreach ($messages as $m) {
        if (empty(trim($m['content'] ?? ''))) continue;
        if (!empty($cleaned) && end($cleaned)['role'] === $m['role']) {
            // Gabung konten yang role-nya sama
            $last = array_pop($cleaned);
            $last['content'] .= "\n" . $m['content'];
            $cleaned[] = $last;
        } else {
            $cleaned[] = array('role' => $m['role'], 'content' => $m['content']);
        }
    }
    // Harus dimulai dari role 'user'
    while (!empty($cleaned) && $cleaned[0]['role'] !== 'user') {
        array_shift($cleaned);
    }
    if (empty($cleaned)) {
        $cleaned = array(array('role' => 'user', 'content' => 'Halo'));
    }

    $body = json_encode(array(
        'model'       => $model,
        'messages'    => array_merge(
            array(array('role' => 'system', 'content' => $system)),
            $cleaned
        ),
        'max_tokens'  => 400,
        'temperature' => 0.7
    ));

    $ch = curl_init($endpoint);
    curl_setopt_array($ch, array(
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER     => array(
            'Content-Type: application/json',
            'Authorization: Bearer '.$apiKey
        ),
        CURLOPT_POSTFIELDS     => $body,
        CURLOPT_TIMEOUT        => 30
    ));
    $raw  = curl_exec($ch);
    $err  = curl_error($ch);
    $http = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    logIt("AI HTTP=$http cerr=$err raw=".substr($raw, 0, 300));
    $data = json_decode($raw, true);
    return isset($data['choices'][0]['message']['content'])
        ? trim($data['choices'][0]['message']['content'])
        : '';
}

// ── HISTORY: Ambil dari DB ────────────────────────────────────
function getHistory($pdo, $phone, $limit) {
    $limit = (int)$limit;
    $stmt  = $pdo->prepare(
        "SELECT role, content FROM bot_wa_history
         WHERE phone = ?
         ORDER BY id DESC
         LIMIT $limit"
    );
    $stmt->execute(array($phone));
    $rows = array_reverse($stmt->fetchAll(PDO::FETCH_ASSOC));
    $out  = array();
    foreach ($rows as $r) {
        $out[] = array('role' => $r['role'], 'content' => $r['content']);
    }
    logIt("HISTORY loaded: ".count($out)." messages untuk $phone");
    return $out;
}

// ── HISTORY: Simpan ke DB (fix SQL injection pakai prepared stmt) ─
function saveHistory($pdo, $phone, $role, $content) {
    $pdo->prepare(
        "INSERT INTO bot_wa_history (phone, role, content) VALUES (?, ?, ?)"
    )->execute(array($phone, $role, $content));

    // Hapus history lama, simpan 20 terakhir
    $pdo->prepare(
        "DELETE FROM bot_wa_history
         WHERE phone = ?
         AND id NOT IN (
             SELECT id FROM (
                 SELECT id FROM bot_wa_history
                 WHERE phone = ?
                 ORDER BY id DESC
                 LIMIT 20
             ) t
         )"
    )->execute(array($phone, $phone));
}

function getCustomer($pdo, $phone) {
    $stmt = $pdo->prepare(
        "SELECT * FROM data_penyewa_perusahaan WHERE no_telpon LIKE ? LIMIT 1"
    );
    $stmt->execute(array('%'.substr($phone, -9).'%'));
    return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
}

function buildGreeting($c, $name) {
    if ($c) return "Pelanggan: {$c['nama_penanggung_jawab']}, laptop: {$c['kode_laptop']}, status: {$c['status_pembayaran']}.";
    return "Pelanggan baru (belum ada data sewa).";
}

function buildFullKnowledge($pdo) {
    $out = array();

    // 1. Knowledge base
    try {
        $rows = $pdo->query(
            "SELECT kategori, judul, isi FROM ai_knowledge WHERE aktif=1 ORDER BY kategori, id"
        )->fetchAll(PDO::FETCH_ASSOC);
        foreach ($rows as $r) {
            $out[] = "[{$r['kategori']}] {$r['judul']}:\n{$r['isi']}";
        }
    } catch (Exception $e) {}

    // 2. Daftar laptop tersedia
    try {
        $rows = $pdo->query(
            "SELECT kode_laptop, merek, tipe, ram, storage, harga_per_hari, status
             FROM data_laptop WHERE status='tersedia' LIMIT 20"
        )->fetchAll(PDO::FETCH_ASSOC);
        foreach ($rows as $r) {
            $out[] = "[LAPTOP] {$r['kode_laptop']} {$r['merek']} {$r['tipe']} RAM:{$r['ram']} SSD:{$r['storage']} Rp{$r['harga_per_hari']}/hari";
        }
    } catch (Exception $e) {}

    // 3. Tabel harga bertingkat (tiered pricing)
    // Kolom: price_id, min_qty (hari mulai), max_qty (hari sampai, NULL=open), price_per_unit
    try {
        $tiers = $pdo->query(
            "SELECT min_qty, max_qty, price_per_unit
             FROM ci_laptop_prices
             ORDER BY min_qty ASC"
        )->fetchAll(PDO::FETCH_ASSOC);

        if ($tiers) {
            $tierLines = array();
            foreach ($tiers as $t) {
                $min = (int)$t['min_qty'];
                $max = $t['max_qty'];
                $hrg = number_format((float)$t['price_per_unit'], 0, ',', '.');
                if ($max === null || $max === '') {
                    $tierLines[] = "  - Sewa {$min} hari ke atas: Rp{$hrg}/hari";
                } else {
                    $tierLines[] = "  - Sewa {$min}–{$max} hari: Rp{$hrg}/hari";
                }
            }
            $out[] = "[HARGA_SEWA] Tabel harga per hari berdasarkan durasi sewa:\n"
                   . implode("\n", $tierLines)
                   . "\n\nCara menghitung total biaya: cari range yang cocok dengan jumlah hari, lalu kalikan harga/hari × jumlah hari."
                   . "\nContoh: sewa 5 hari → lihat range yang mencakup angka 5, misal range 4–6 hari Rp50.000/hari → total = 5 × 50.000 = Rp250.000."
                   . "\nSelalu hitung dan sebutkan total biaya lengkap saat pelanggan tanya harga.";
        }
    } catch (Exception $e) {
        logIt("WARN tiered pricing error: ".$e->getMessage());
    }

    return $out;
}

function parseLocation($data) {
    if (!empty($data['location'])) {
        $loc  = $data['location'];
        $lat  = $loc['latitude']  ?? $loc['lat']     ?? null;
        $lng  = $loc['longitude'] ?? $loc['lng']     ?? null;
        $name = $loc['name']      ?? $loc['address'] ?? '';
        if ($lat && $lng) return array('lat' => $lat, 'lng' => $lng, 'name' => $name);
    }
    $msg = $data['message'] ?? '';
    if (strpos($msg, '#') !== false) {
        $parts  = explode('#', $msg);
        $lat    = null; $lng = null;
        $name   = $parts[0] ?? '';
        $alamat = $parts[1] ?? '';
        foreach ($parts as $p) {
            $p = trim($p);
            if (preg_match('/^-?\d+\.\d{4,}$/', $p)) {
                if ($lat === null) $lat = $p;
                elseif ($lng === null) $lng = $p;
            }
        }
        if ($lat && $lng) return array('lat' => $lat, 'lng' => $lng, 'name' => $name, 'alamat' => $alamat);
    }
    if (preg_match('/(-?\d+\.\d+)[,|](-?\d+\.\d+)/', $msg, $m)) {
        return array('lat' => $m[1], 'lng' => $m[2], 'name' => '');
    }
    return null;
}

function locationToText($loc) {
    $mapsUrl   = "https://www.google.com/maps?q={$loc['lat']},{$loc['lng']}";
    $name      = !empty($loc['name'])   ? $loc['name']   : '';
    $alamat    = !empty($loc['alamat']) ? $loc['alamat'] : '';
    $detail    = trim("$name - $alamat", ' -');
    $jarak     = hitungJarak(-6.2664338, 106.8758517, (float)$loc['lat'], (float)$loc['lng']);
    $jarakTeks = number_format($jarak, 1, '.', '') . ' km';
    $bisaAntar = $jarak <= 20
        ? "BISA diantar (dalam radius 20km)"
        : "TIDAK BISA diantar (lebih dari 20km, jarak $jarakTeks)";
    return "[Lokasi: $detail] Koordinat: {$loc['lat']}, {$loc['lng']} | Maps: $mapsUrl | Jarak dari toko: $jarakTeks | Status: $bisaAntar";
}

function hitungJarak($lat1, $lng1, $lat2, $lng2) {
    $R    = 6371;
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $a    = sin($dLat/2)*sin($dLat/2) + cos(deg2rad($lat1))*cos(deg2rad($lat2))*sin($dLng/2)*sin($dLng/2);
    return $R * 2 * atan2(sqrt($a), sqrt(1 - $a));
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
    logIt("BOT OFF"); http_response_code(200); exit('OK');
}

// Parse input
$raw  = file_get_contents('php://input');
logIt("RAW: ".substr($raw, 0, 300));
$data = json_decode($raw, true);
if (!$data) { http_response_code(200); exit('OK'); }

$phone    = normalizePhone($data['phone'] ?? '');
$type     = $data['messageType'] ?? '';
$text     = trim($data['message'] ?? '');
$isGroup  = !empty($data['isGroup']);
$isFromMe = !empty($data['isFromMe']);

logIt("phone=$phone type=$type isGroup=".($isGroup?'true':'false')." msg=".substr($text, 0, 80));

// Handle tipe lokasi
$isLocation = ($type === 'location' || $type === 'Location');
if ($isLocation) {
    $locData = parseLocation($data);
    if ($locData) {
        $text = locationToText($locData);
        logIt("LOCATION parsed: lat={$locData['lat']} lng={$locData['lng']}");
    } else {
        logIt("LOCATION: gagal parse koordinat");
        http_response_code(200); exit('OK');
    }
}

if ((!$isLocation && $type !== 'text') || empty($text) || $isGroup) {
    logIt("SKIP: bukan teks/lokasi atau grup");
    http_response_code(200); exit('OK');
}

// Trial Mode
if (!empty($cfg['trial_mode'])) {
    $allowed = $cfg['trial_numbers'] ?? array();
    if (!in_array($phone, $allowed)) {
        logIt("TRIAL MODE: $phone tidak di whitelist");
        http_response_code(200); exit('OK');
    }
}

if ($isFromMe) { http_response_code(200); exit('OK'); }

$token    = $cfg['wablas_token']     ?? '';
$url      = rtrim($cfg['wablas_url'] ?? 'https://sby.wablas.com', '/');
$prov     = $cfg['provider']         ?? 'groq';
$provCfg  = $cfg['providers'][$prov] ?? array();
$apiKey   = $provCfg['api_key']      ?? '';
$model    = $provCfg['model']        ?? '';
$endpoint = $provCfg['endpoint']     ?? '';

// DB
try {
    $pdo = new PDO(
        'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS,
        array(PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION)
    );
    logIt("DB OK");
} catch (Exception $e) {
    logIt("DB ERROR: ".$e->getMessage());
    http_response_code(200); exit('OK');
}

$customer = getCustomer($pdo, $phone);
logIt("Customer: ".($customer ? $customer['nama_penanggung_jawab'] : 'BARU'));

// Jam operasional
date_default_timezone_set('Asia/Jakarta');
$hour = (int)date('H');
if ($hour < 8 || $hour >= 20) {
    sendWA($phone, "Maaf, kami tutup (08.00-20.00 WIB). Hubungi kami besok ya!", $token, $url);
    logIt("TUTUP jam=$hour");
    http_response_code(200); exit('OK');
}

$knowledge = buildFullKnowledge($pdo);
$knowText  = $knowledge ? implode("\n\n", $knowledge) : 'Tidak ada data knowledge.';
logIt("Knowledge items=".count($knowledge));

$greeting = buildGreeting($customer, $data['pushName'] ?? '');

$system = $cfg['system_prompt'] ?? "Kamu adalah asisten WhatsApp untuk bisnis sewa laptop. Jawab singkat, ramah, dalam bahasa Indonesia.\n\nJika tidak tahu, arahkan ke admin 081210846420.";
$system = str_replace('{customer}',  $greeting, $system);
$system = str_replace('{knowledge}', $knowText, $system);
if (strpos($system, $greeting)  === false) $system .= "\n\nInfo pelanggan: $greeting";
if (strpos($system, $knowText)  === false) $system .= "\n\nKnowledge:\n$knowText";
$system .= "\n\nJika ada pesan berisi [Lokasi] dengan koordinat dan link Google Maps, artinya pelanggan sedang share lokasi pengiriman/penjemputan laptop. Konfirmasi lokasi tersebut dan tanyakan apakah ada yang perlu dibantu.";

// ── Load history percakapan sebelumnya dari DB ────────────────
try {
    $history = getHistory($pdo, $phone, 10);
} catch (Exception $e) {
    logIt("ERROR getHistory: ".$e->getMessage());
    $history = array();
}

// ── Tambah pesan user saat ini ke history ─────────────────────
$history[] = array('role' => 'user', 'content' => $text);
logIt("History dikirim ke AI: ".count($history)." pesan");

// ── Panggil AI ────────────────────────────────────────────────
$reply = callAI($endpoint, $apiKey, $model, $system, $history);
logIt("Reply: ".substr($reply, 0, 100));

if ($reply) {
    sendWA($phone, $reply, $token, $url);
    saveHistory($pdo, $phone, 'user',      $text);
    saveHistory($pdo, $phone, 'assistant', $reply);
}

logIt("DONE");
http_response_code(200);
echo 'OK';
