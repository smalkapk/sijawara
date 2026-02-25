<?php
// /server/api/get_berita_detail.php
// Proxy API: mengambil konten detail berita dari website sekolah.

// ── CORS Headers ──
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

// ── Parameter ──
$detailUrl = $_GET['url'] ?? '';

if (empty($detailUrl)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Parameter url wajib diisi']);
    exit;
}

// Validasi URL harus dari domain sekolah
if (strpos($detailUrl, 'smamalkautsarpk.sch.id') === false) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'URL tidak valid']);
    exit;
}

$context = stream_context_create([
    'http' => [
        'method'        => 'GET',
        'timeout'       => 15,
        'header'        => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36\r\n"
                         . "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n",
        'ignore_errors' => true,
    ],
    'ssl' => [
        'verify_peer'      => false,
        'verify_peer_name' => false,
    ],
]);

try {
    $html = @file_get_contents($detailUrl, false, $context);

    if ($html === false || empty($html)) {
        throw new Exception('Gagal mengambil halaman berita');
    }

    // ── Parse HTML ──
    libxml_use_internal_errors(true);
    $dom = new DOMDocument();
    $dom->loadHTML('<?xml encoding="utf-8" ?>' . $html, LIBXML_NOWARNING | LIBXML_NOERROR);
    libxml_clear_errors();

    $xpath = new DOMXPath($dom);
    $baseUrl = 'https://smamalkautsarpk.sch.id';

    // ── Judul: ambil dari <h2> pertama yang cukup panjang ──
    $title = '';
    $subtitle = '';
    $titleNode = null;

    // ── Tanggal: ambil dari <time> ──
    $date = '';
    $timeNodes = $xpath->query('//time');
    foreach ($timeNodes as $tNode) {
        $text = trim($tNode->textContent);
        if (strlen($text) > 5) {
            $date = $text;
            break;
        }
    }

    // Cari h2 sebagai judul utama
    // Ambil teks dari <a> di dalam <h2> agar tidak ikut teks <h5> yang nested
    $h2Links = $xpath->query('//h2[contains(@class, "entry-title")]//a | //h2//a');
    foreach ($h2Links as $aNode) {
        $text = trim($aNode->textContent);
        $text = preg_replace('/\s+/', ' ', $text);
        if (strlen($text) > 10) {
            $title = $text;
            $titleNode = $aNode->parentNode;
            break;
        }
    }

    // Fallback: coba h2 textContent langsung (tanpa nested h5)
    if (empty($title)) {
        $h2Nodes = $xpath->query('//h2');
        foreach ($h2Nodes as $node) {
            $text = trim($node->textContent);
            $text = preg_replace('/\s+/', ' ', $text);
            if (strlen($text) > 10) {
                $title = $text;
                $titleNode = $node;
                break;
            }
        }
    }

    // Cari h5 sebagai sub-judul
    $h5Nodes = $xpath->query('//h5');
    foreach ($h5Nodes as $node) {
        $text = trim($node->textContent);
        $text = preg_replace('/\s+/', ' ', $text);
        if (strlen($text) > 5 && $text !== $title) {
            $subtitle = $text;
            break;
        }
    }

    // Hapus subtitle dari title jika ikut terbawa
    if (!empty($subtitle) && !empty($title) && mb_strpos($title, $subtitle) !== false) {
        $title = trim(str_replace($subtitle, '', $title));
        $title = preg_replace('/\s+/', ' ', $title);
    }

    // Fallback: dari <title> tag
    if (empty($title)) {
        $titleNodes = $xpath->query('//title');
        if ($titleNodes->length > 0) {
            $title = trim($titleNodes->item(0)->textContent);
            $title = preg_replace('/\s*\|.*$/', '', $title);
        }
    }

    // ── Gambar utama ──
    $imageUrl = '';
    // OG image
    $ogImage = $xpath->query('//meta[@property="og:image"]');
    if ($ogImage->length > 0) {
        $imageUrl = $ogImage->item(0)->getAttribute('content');
    }

    // Fallback: gambar pertama di konten
    if (empty($imageUrl)) {
        $imgs = $xpath->query('//img[not(contains(@src, "logo")) and not(contains(@src, "icon"))]');
        foreach ($imgs as $img) {
            $src = $img->getAttribute('src');
            if (!empty($src) && strlen($src) > 10) {
                $imageUrl = $src;
                break;
            }
        }
    }

    if (!empty($imageUrl) && strpos($imageUrl, 'http') !== 0) {
        $imageUrl = $baseUrl . '/' . ltrim($imageUrl, '/');
    }

    // ── Konten artikel ──
    // Cari container artikel utama
    $content = '';
    $contentSelectors = [
        '//article',
        '//div[contains(@class, "blog")]',
        '//div[contains(@class, "content")]',
        '//div[contains(@class, "post")]',
        '//div[contains(@class, "entry")]',
        '//div[contains(@class, "detail")]',
        '//div[contains(@class, "berita")]',
    ];

    // Teks yang harus di-skip dari body (sudah tampil sebagai header)
    $skipTexts = array_filter([$title, $subtitle, $date]);

    foreach ($contentSelectors as $selector) {
        $nodes = $xpath->query($selector);
        if ($nodes->length > 0) {
            $node = $nodes->item(0);
            $content = _extractText($node, $xpath, $baseUrl, $skipTexts, $imageUrl);
            if (strlen($content) > 50) {
                break;
            }
        }
    }

    // Fallback: ambil semua <p> di body
    if (strlen($content) < 50) {
        $paragraphs = $xpath->query('//body//p');
        $texts = [];
        foreach ($paragraphs as $p) {
            $text = trim($p->textContent);
            if (strlen($text) > 20 && !_isSkipText($text, $skipTexts)) {
                $texts[] = $text;
            }
        }
        $content = implode("\n\n", $texts);
    }

    // ── OG Description sebagai excerpt ──
    $excerpt = '';
    $ogDesc = $xpath->query('//meta[@property="og:description"]');
    if ($ogDesc->length > 0) {
        $excerpt = trim($ogDesc->item(0)->getAttribute('content'));
    }

    // ── Gambar dalam artikel ──
    $images = [];
    $contentImgs = $xpath->query('//img[not(contains(@src, "logo")) and not(contains(@src, "icon")) and not(contains(@src, "whatsapp"))]');
    foreach ($contentImgs as $img) {
        $src = $img->getAttribute('src');
        if (!empty($src) && strlen($src) > 10) {
            if (strpos($src, 'http') !== 0) {
                $src = $baseUrl . '/' . ltrim($src, '/');
            }
            if (!in_array($src, $images)) {
                $images[] = $src;
            }
        }
    }

    echo json_encode([
        'success'   => true,
        'data'      => [
            'title'     => $title,
            'subtitle'  => $subtitle,
            'date'      => $date,
            'image_url' => $imageUrl,
            'content'   => $content,
            'excerpt'   => $excerpt,
            'images'    => $images,
        ],
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE);
}

// ═══════════════════════════════════════
// Helper
// ═══════════════════════════════════════

/**
 * Cek apakah teks sama dengan salah satu skipTexts (fuzzy match).
 */
function _isSkipText(string $text, array $skipTexts): bool {
    $text = trim(preg_replace('/\s+/', ' ', $text));
    foreach ($skipTexts as $skip) {
        $skip = trim(preg_replace('/\s+/', ' ', $skip));
        if (empty($skip)) continue;
        // Exact match atau contains
        if ($text === $skip || mb_stripos($text, $skip) !== false || mb_stripos($skip, $text) !== false) {
            return true;
        }
    }
    return false;
}

/**
 * Ekstrak teks bersih dari DOM node, preserve paragraf.
 * $skipTexts: array teks yang harus di-skip (judul, sub-judul).
 */
function _extractText(DOMNode $node, DOMXPath $xpath, string $baseUrl, array $skipTexts = [], string $skipImageUrl = ''): string {
    $parts = [];

    foreach ($node->childNodes as $child) {
        if ($child->nodeType === XML_TEXT_NODE) {
            $text = trim($child->textContent);
            if (!empty($text) && !_isSkipText($text, $skipTexts)) {
                $parts[] = $text;
            }
        } elseif ($child->nodeType === XML_ELEMENT_NODE) {
            $tag = strtolower($child->nodeName);

            // Skip navigation, footer, form elements
            if (in_array($tag, ['nav', 'footer', 'form', 'script', 'style', 'iframe', 'button'])) {
                continue;
            }

            // Skip elements with navigation/menu classes
            if ($child instanceof DOMElement) {
                $class = $child->getAttribute('class');
                if (preg_match('/(nav|menu|sidebar|footer|header|widget|comment)/i', $class)) {
                    continue;
                }
            }

            if (in_array($tag, ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'])) {
                $text = trim($child->textContent);
                // Skip jika ini adalah judul atau sub-judul
                if (!empty($text) && !_isSkipText($text, $skipTexts)) {
                    $level = substr($tag, 1);
                    $parts[] = "\n" . str_repeat('#', (int)$level) . ' ' . $text . "\n";
                }
            } elseif ($tag === 'p') {
                $text = trim($child->textContent);
                if (!empty($text) && !_isSkipText($text, $skipTexts)) {
                    $parts[] = $text . "\n";
                }
            } elseif ($tag === 'br') {
                $parts[] = "\n";
            } elseif ($tag === 'li') {
                $text = trim($child->textContent);
                if (!empty($text) && !_isSkipText($text, $skipTexts)) {
                    $parts[] = "• " . $text;
                }
            } elseif ($tag === 'img') {
                $src = $child->getAttribute('src');
                if (!empty($src)) {
                    if (strpos($src, 'http') !== 0) {
                        $src = $baseUrl . '/' . ltrim($src, '/');
                    }
                    // Skip gambar utama (sudah ditampilkan sebagai hero image)
                    // Bandingkan berdasarkan basename karena domain bisa beda
                    // (og:image di smamalkautsarpk.sch.id vs img di sekolah.novadu.id)
                    if (!empty($skipImageUrl) && _isSameImage($src, $skipImageUrl)) {
                        continue;
                    }
                    $alt = $child->getAttribute('alt') ?: 'Gambar';
                    $parts[] = "\n![$alt]($src)\n";
                }
            } elseif (in_array($tag, ['strong', 'b'])) {
                $text = trim($child->textContent);
                if (!empty($text)) {
                    $parts[] = "**" . $text . "**";
                }
            } elseif (in_array($tag, ['em', 'i'])) {
                $text = trim($child->textContent);
                if (!empty($text)) {
                    $parts[] = "*" . $text . "*";
                }
            } else {
                // Recurse ke child elements
                $inner = _extractText($child, $xpath, $baseUrl, $skipTexts, $skipImageUrl);
                if (!empty(trim($inner))) {
                    $parts[] = $inner;
                }
            }
        }
    }

    return implode("\n", $parts);
}

/**
 * Bandingkan dua URL gambar berdasarkan basename (nama file).
 * Diperlukan karena OG image dan entry image bisa beda domain:
 * - og:image:  smamalkautsarpk.sch.id/image?i=upload/.../file.jpg
 * - entry img: sekolah.novadu.id/upload/.../file.jpg
 */
function _isSameImage(string $url1, string $url2): bool {
    if ($url1 === $url2) return true;

    $name1 = _extractImageName($url1);
    $name2 = _extractImageName($url2);

    return !empty($name1) && !empty($name2) && $name1 === $name2;
}

function _extractImageName(string $url): string {
    // Cek apakah ada query param ?i=upload/...
    $parsed = parse_url($url);
    if (isset($parsed['query'])) {
        parse_str($parsed['query'], $params);
        if (isset($params['i'])) {
            return basename($params['i']);
        }
    }
    // Ambil basename dari path
    $path = $parsed['path'] ?? $url;
    return basename($path);
}

