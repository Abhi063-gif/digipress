<?php
/**
 * Admin Panel – New Publication Upload
 */
session_start();
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/cloudinary.php';
if (!isset($_SESSION['admin_id'])) { header('Location: index.php'); exit; }

$db  = getDB();
$msg = '';
$err = '';

// ── Handle Upload ──────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'upload_pdf') {
    $title       = trim($_POST['title'] ?? '');
    $description = trim($_POST['description'] ?? '');
    $categoryId  = (int)($_POST['category_id'] ?? 0);

    if (!$title || !$categoryId) {
        $err = 'Title and category are required.';
    } elseif (empty($_FILES['pdf_file']['tmp_name'])) {
        $err = 'Please select a PDF file.';
    } else {
        $file = $_FILES['pdf_file'];
        $mime = mime_content_type($file['tmp_name']);
        if (!in_array($mime, ['application/pdf', 'application/x-pdf'])) {
            $err = 'Only PDF files are allowed.';
        } elseif ($file['size'] > 25 * 1024 * 1024) {
            $err = 'Max file size is 25 MB.';
        } else {
            try {
                $resp = cloudinaryUpload($file['tmp_name'], 'digipress/publications');
                if (!empty($resp['secure_url'])) {
                    // Extract Pages
                    $pagesCount = 1;
                    $pagesOverride = isset($_POST['pages_override']) ? (int)$_POST['pages_override'] : 0;
                    
                    if ($pagesOverride > 0) {
                        $pagesCount = $pagesOverride;
                    } else {
                        try {
                            $pdfContent = @file_get_contents($file['tmp_name']);
                            if ($pdfContent) {
                                // 1. Try to find /Count in the Pages dictionary
                                if (preg_match("/\/Type\s*\/Pages.*?\/Count\s+(\d+)/s", $pdfContent, $m)) {
                                    $pagesCount = (int)$m[1];
                                } 
                                // 2. Fallback: Count /Type /Page with /MediaBox
                                elseif (preg_match_all("/\/Type\s*\/Page\b[^>]*?\/MediaBox/s", $pdfContent, $matches)) {
                                    $pagesCount = count($matches[0]);
                                }
                                // 3. Basic fallback
                                elseif (preg_match_all("/\/Type\s*\/Page\b/", $pdfContent, $matches)) {
                                    $pagesCount = count($matches[0]);
                                }
                            }
                        } catch (Exception $e) {}
                    }
                    if ($pagesCount <= 0) $pagesCount = 1;

                    $stmt = $db->prepare(
                        'INSERT INTO publications (title, description, category_id, pdf_url, cloudinary_id, uploaded_by, pages)
                         VALUES (?, ?, ?, ?, ?, ?, ?)'
                    );
                    $stmt->execute([
                        $title, $description, $categoryId,
                        $resp['secure_url'], $resp['public_id'],
                        $_SESSION['admin_id'], $pagesCount
                    ]);
                    $pubId = (int)$db->lastInsertId();

                    // Auto notification
                    $catRow = $db->prepare('SELECT name FROM categories WHERE id = ?');
                    $catRow->execute([$categoryId]);
                    $catName = $catRow->fetchColumn();

                    $db->prepare('INSERT INTO notifications (title, body, category, pub_id) VALUES (?, ?, ?, ?)')
                       ->execute(["$catName: $title", "A new $catName has been published.", $catName, $pubId]);

                    $msg = '✅ Publication uploaded successfully! It is now live in the app.';
                } else {
                    $err = 'Cloudinary upload failed. Please try again.';
                }
            } catch (Exception $e) {
                $err = 'Upload error: ' . $e->getMessage();
            }
        }
    }
}

$categories = $db->query('SELECT * FROM categories ORDER BY name')->fetchAll();
$pageTitle  = 'New Publication';
$activePage = 'new_pub';
?>
<?php include __DIR__ . '/includes/header.php'; ?>

<?php if ($msg): ?><div class="alert alert-success"><i class="fa-solid fa-check-circle"></i> <?= htmlspecialchars($msg) ?></div><?php endif; ?>
<?php if ($err): ?><div class="alert alert-error"><i class="fa-solid fa-triangle-exclamation"></i> <?= htmlspecialchars($err) ?></div><?php endif; ?>

<div class="grid-2" style="align-items:start;">

    <!-- Upload Form -->
    <div class="card animate-in">
        <div class="card-header">
            <div>
                <div class="card-title">Upload New Publication</div>
                <div class="card-subtitle">PDF will be uploaded to Cloudinary and appear in the Flutter app instantly</div>
            </div>
        </div>

        <form method="POST" enctype="multipart/form-data" id="uploadForm">
            <input type="hidden" name="action" value="upload_pdf">

            <div class="form-group">
                <label class="form-label">Publication Title *</label>
                <input type="text" name="title" class="form-control"
                       placeholder="e.g. Annual Magazine 2024" required
                       value="<?= htmlspecialchars($_POST['title'] ?? '') ?>">
            </div>

            <div class="form-group">
                <label class="form-label">Category *</label>
                <select name="category_id" class="form-control" required>
                    <option value="">Select a category…</option>
                    <?php foreach ($categories as $c): ?>
                        <option value="<?= $c['id'] ?>"
                            <?= (($_POST['category_id'] ?? '') == $c['id']) ? 'selected' : '' ?>>
                            <?= htmlspecialchars($c['name']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div class="form-group">
                <label class="form-label">Description (optional)</label>
                <textarea name="description" class="form-control" rows="2"
                          placeholder="Brief description of this publication…"><?= htmlspecialchars($_POST['description'] ?? '') ?></textarea>
            </div>

            <div class="form-group">
                <label class="form-label">Page Count (Optional Override) <span class="badge badge-blue" style="font-size:10px;">New</span></label>
                <input type="number" name="pages_override" class="form-control"
                       placeholder="Leave empty for auto-detection" min="1"
                       value="<?= htmlspecialchars($_POST['pages_override'] ?? '') ?>">
                <small style="color:var(--text-muted); font-size:11px;">If auto-detection is wrong (e.g. for newspapers), enter the correct count manually.</small>
            </div>

            <div class="form-group">
                <label class="form-label">PDF File * (max 25 MB)</label>
                <div class="drop-zone" id="dropZone" onclick="document.getElementById('pdfInput').click()">
                    <div class="icon">📄</div>
                    <p><strong>Click to browse</strong> or drag & drop a PDF here</p>
                    <p id="fileNameDisplay" style="margin-top:8px; color:var(--primary); font-weight:600; display:none;"></p>
                </div>
                <input type="file" name="pdf_file" id="pdfInput" accept=".pdf"
                       style="display:none;" required onchange="handleFileSelect(this)">
            </div>

            <!-- Progress bar (shown during upload) -->
            <div id="progressWrap" style="display:none; margin-bottom:16px;">
                <div style="font-size:12px; color:var(--text-muted); margin-bottom:6px;">Uploading…</div>
                <div class="progress-bar-wrap">
                    <div class="progress-bar" id="progressBar" style="width:0%;"></div>
                </div>
            </div>

            <button type="submit" class="btn btn-primary" style="width:100%;" id="submitBtn">
                <i class="fa-solid fa-cloud-arrow-up"></i> Upload Publication
            </button>
        </form>
    </div>

    <!-- Info Panel -->
    <div style="display:flex; flex-direction:column; gap:20px;">
        <div class="card animate-in delay-1">
            <div class="card-title" style="margin-bottom:14px;">📋 Upload Guidelines</div>
            <ul style="list-style:none; display:flex; flex-direction:column; gap:10px;">
                <li class="flex-center text-sm">
                    <span style="color:var(--primary);">✓</span>
                    File format: PDF only
                </li>
                <li class="flex-center text-sm">
                    <span style="color:var(--primary);">✓</span>
                    Max file size: 25 MB (10 MB for Cloudinary free plan)
                </li>
                <li class="flex-center text-sm">
                    <span style="color:var(--primary);">✓</span>
                    Publication appears in the Flutter app immediately
                </li>
                <li class="flex-center text-sm">
                    <span style="color:var(--primary);">✓</span>
                    Push notification sent automatically to all users
                </li>
                <li class="flex-center text-sm">
                    <span style="color:var(--primary);">✓</span>
                    Select correct category for better discoverability
                </li>
            </ul>
        </div>

        <div class="card animate-in delay-2">
            <div class="card-title" style="margin-bottom:14px;">🏷️ Available Categories</div>
            <div style="display:flex; flex-wrap:wrap; gap:8px;">
                <?php foreach ($categories as $c): ?>
                    <span class="badge badge-blue" style="font-size:12px; padding:5px 12px;">
                        <?= htmlspecialchars($c['icon'] ?? '📁') ?> <?= htmlspecialchars($c['name']) ?>
                    </span>
                <?php endforeach; ?>
            </div>
            <a href="categories.php" style="display:inline-flex;align-items:center;gap:6px;margin-top:14px;
               font-size:12px;color:var(--primary);font-weight:600;text-decoration:none;">
                <i class="fa-solid fa-plus"></i> Manage Categories
            </a>
        </div>

        <!-- Recent uploads -->
        <div class="card animate-in delay-3">
            <div class="card-title" style="margin-bottom:14px;">🕐 Recent Uploads</div>
            <?php
            $recent = $db->query('SELECT p.title, c.name AS cat, p.created_at
                                  FROM publications p JOIN categories c ON c.id=p.category_id
                                  ORDER BY p.created_at DESC LIMIT 5')->fetchAll();
            ?>
            <?php if (empty($recent)): ?>
                <p class="text-muted text-sm">No uploads yet.</p>
            <?php else: ?>
            <div style="display:flex; flex-direction:column; gap:10px;">
                <?php foreach ($recent as $r): ?>
                <div class="flex-center" style="gap:10px;">
                    <div style="width:34px;height:34px;border-radius:8px;background:var(--primary-soft);
                                display:flex;align-items:center;justify-content:center;font-size:16px;flex-shrink:0;">📄</div>
                    <div style="flex:1;min-width:0;">
                        <div style="font-size:12px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">
                            <?= htmlspecialchars($r['title']) ?>
                        </div>
                        <div class="text-muted text-sm"><?= htmlspecialchars($r['cat']) ?> · <?= date('M d', strtotime($r['created_at'])) ?></div>
                    </div>
                </div>
                <?php endforeach; ?>
            </div>
            <?php endif; ?>
        </div>
    </div>
</div>

<script>
function handleFileSelect(input) {
    const file = input.files[0];
    if (!file) return;
    const display = document.getElementById('fileNameDisplay');
    display.textContent = '📄 ' + file.name + ' (' + (file.size / 1048576).toFixed(1) + ' MB)';
    display.style.display = 'block';
    document.getElementById('dropZone').style.borderColor = 'var(--primary)';
}

// Drag and drop
const dz = document.getElementById('dropZone');
dz.addEventListener('dragover', e => { e.preventDefault(); dz.classList.add('dragover'); });
dz.addEventListener('dragleave', () => dz.classList.remove('dragover'));
dz.addEventListener('drop', e => {
    e.preventDefault();
    dz.classList.remove('dragover');
    const file = e.dataTransfer.files[0];
    if (file && file.type === 'application/pdf') {
        const dt = new DataTransfer();
        dt.items.add(file);
        document.getElementById('pdfInput').files = dt.files;
        handleFileSelect(document.getElementById('pdfInput'));
    }
});

// Show progress on submit
document.getElementById('uploadForm').addEventListener('submit', function() {
    const btn = document.getElementById('submitBtn');
    const pw  = document.getElementById('progressWrap');
    const pb  = document.getElementById('progressBar');
    btn.disabled = true;
    btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Uploading…';
    pw.style.display = 'block';
    let w = 0;
    const iv = setInterval(() => {
        w = Math.min(w + Math.random() * 8, 90);
        pb.style.width = w + '%';
    }, 400);
});
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>
