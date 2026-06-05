<?php
/**
 * Admin Panel – Total Publications
 */
session_start();
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/cloudinary.php';
if (!isset($_SESSION['admin_id'])) { header('Location: index.php'); exit; }

$db  = getDB();
$msg = '';
$err = '';

// ── Delete ─────────────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'delete_pub') {
    $pubId = (int)($_POST['pub_id'] ?? 0);
    $row   = $db->prepare('SELECT cloudinary_id FROM publications WHERE id = ?');
    $row->execute([$pubId]);
    $row = $row->fetch();
    if ($row) {
        cloudinaryDelete($row['cloudinary_id']);
        $db->prepare('DELETE FROM publications WHERE id = ?')->execute([$pubId]);
        $msg = 'Publication deleted successfully.';
    }
}

// ── Filters ────────────────────────────────────────────────────────────
$search   = trim($_GET['search'] ?? '');
$catFilter= (int)($_GET['cat'] ?? 0);

$where  = 'WHERE 1';
$params = [];
if ($search) {
    $where .= ' AND (p.title LIKE ? OR p.description LIKE ?)';
    $params[] = "%$search%";
    $params[] = "%$search%";
}
if ($catFilter) {
    $where .= ' AND p.category_id = ?';
    $params[] = $catFilter;
}

$cStmt = $db->prepare("SELECT COUNT(*) FROM publications p $where");
$cStmt->execute($params);
$total = (int)$cStmt->fetchColumn();

$perPage = 20;
$page    = max(1, (int)($_GET['page'] ?? 1));
$offset  = ($page - 1) * $perPage;
$pages   = max(1, ceil($total / $perPage));

$stmt = $db->prepare(
    "SELECT p.id, p.title, p.description, p.pdf_url, p.created_at,
            COALESCE(p.download_count,0) AS download_count,
            COALESCE(p.view_count,0) AS view_count,
            COALESCE(p.share_count,0) AS share_count,
            p.pages,
            c.id AS cat_id, c.name AS category_name,
            u.name AS uploaded_by,
            COALESCE(p.download_count,0) AS real_dl
     FROM publications p
     JOIN categories c ON c.id = p.category_id
     JOIN users u ON u.id = p.uploaded_by
     $where
     ORDER BY p.created_at DESC
     LIMIT $perPage OFFSET $offset"
);
$stmt->execute($params);
$pubs = $stmt->fetchAll();

$categories = $db->query('SELECT id, name FROM categories ORDER BY name')->fetchAll();
$totalPubs  = (int)$db->query('SELECT COUNT(*) FROM publications')->fetchColumn();

$pageTitle  = 'Total Publications';
$activePage = 'publications';
?>
<?php include __DIR__ . '/includes/header.php'; ?>

<?php if ($msg): ?><div class="alert alert-success"><i class="fa-solid fa-check-circle"></i> <?= htmlspecialchars($msg) ?></div><?php endif; ?>
<?php if ($err): ?><div class="alert alert-error"><i class="fa-solid fa-triangle-exclamation"></i> <?= htmlspecialchars($err) ?></div><?php endif; ?>

<!-- Quick stat -->
<div class="flex-center" style="margin-bottom:20px; gap:16px; flex-wrap:wrap;">
    <div class="card animate-in" style="padding:16px 24px; flex:1; min-width:140px;">
        <div class="stat-label">Total Publications</div>
        <div style="font-size:26px;font-weight:800;color:var(--accent1);margin-top:4px;"><?= $totalPubs ?></div>
    </div>
    <div class="card animate-in delay-1" style="padding:16px 24px; flex:1; min-width:140px;">
        <div class="stat-label">Showing</div>
        <div style="font-size:26px;font-weight:800;color:var(--primary);margin-top:4px;"><?= $total ?></div>
    </div>
    <a href="new_publication.php" class="btn btn-primary animate-in delay-2" style="height:fit-content;">
        <i class="fa-solid fa-plus"></i> New Publication
    </a>
</div>

<!-- Publications Table -->
<div class="card animate-in">
    <div class="card-header" style="flex-wrap:wrap; gap:12px;">
        <div class="card-title">All Publications</div>
        <form method="GET" style="display:flex; gap:10px; flex-wrap:wrap; align-items:center;">
            <input type="text" name="search" class="form-control" style="width:220px;"
                   placeholder="Search title…" value="<?= htmlspecialchars($search) ?>">
            <select name="cat" class="form-control" style="width:160px;" onchange="this.form.submit()">
                <option value="">All Categories</option>
                <?php foreach ($categories as $c): ?>
                    <option value="<?= $c['id'] ?>" <?= $catFilter == $c['id'] ? 'selected' : '' ?>>
                        <?= htmlspecialchars($c['name']) ?>
                    </option>
                <?php endforeach; ?>
            </select>
            <button type="submit" class="btn btn-primary btn-sm"><i class="fa-solid fa-search"></i></button>
            <?php if ($search || $catFilter): ?>
            <a href="publications.php" class="btn btn-outline btn-sm">Clear</a>
            <?php endif; ?>
        </form>
    </div>

    <div class="table-wrap">
    <table>
        <thead>
            <tr>
                <th>#</th>
                <th>Title</th>
                <th>Category</th>
                <th>Downloads</th>
                <th>Views</th>
                <th>Shares</th>
                <th>Pages</th>
                <th>Uploaded By</th>
                <th>Date</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
        <?php if (empty($pubs)): ?>
            <tr><td colspan="10" class="text-muted text-sm" style="text-align:center;padding:28px;">No publications found.</td></tr>
        <?php else: ?>
        <?php foreach ($pubs as $i => $p): ?>
            <tr>
                <td class="text-muted text-sm"><?= ($page-1)*$perPage + $i + 1 ?></td>
                <td style="max-width:200px;">
                    <div style="font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:180px;"
                         title="<?= htmlspecialchars($p['title']) ?>">
                        <?= htmlspecialchars($p['title']) ?>
                    </div>
                    <?php if ($p['description']): ?>
                    <div class="text-muted text-sm" style="margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:180px;">
                        <?= htmlspecialchars(substr($p['description'], 0, 60)) ?>…
                    </div>
                    <?php endif; ?>
                </td>
                <td><span class="badge badge-blue"><?= htmlspecialchars($p['category_name']) ?></span></td>
                <td><span class="badge badge-amber"><?= number_format($p['real_dl']) ?></span></td>
                <td><?= number_format($p['view_count']) ?></td>
                <td><?= number_format($p['share_count']) ?></td>
                <td class="text-muted text-sm"><?= $p['pages'] ?: '–' ?></td>
                <td class="text-muted text-sm"><?= htmlspecialchars($p['uploaded_by']) ?></td>
                <td class="text-muted text-sm"><?= date('M d, Y', strtotime($p['created_at'])) ?></td>
                <td>
                    <div class="flex-center" style="gap:6px;">
                        <?php 
                            $pdfUrl = trim($p['pdf_url']);
                            $ext = 'pdf'; // default
                            if (preg_match('/\.([a-z0-9]{2,4})(?:[?#]|$)/i', $pdfUrl, $m)) {
                                $ext = strtolower($m[1]);
                            }
                        ?>
                        <a href="<?= htmlspecialchars($pdfUrl) ?>" target="_blank"
                           class="btn btn-outline btn-sm" title="View/Download"
                           download="<?= htmlspecialchars($p['title']) ?>.<?= $ext ?>">
                            <i class="fa-solid fa-eye"></i>
                        </a>
                        <form method="POST" onsubmit="return confirm('Delete this publication permanently?')">
                            <input type="hidden" name="action" value="delete_pub">
                            <input type="hidden" name="pub_id" value="<?= $p['id'] ?>">
                            <button type="submit" class="btn btn-danger btn-sm" title="Delete">
                                <i class="fa-solid fa-trash"></i>
                            </button>
                        </form>
                    </div>
                </td>
            </tr>
        <?php endforeach; ?>
        <?php endif; ?>
        </tbody>
    </table>
    </div>

    <!-- Pagination -->
    <?php if ($pages > 1): ?>
    <div style="display:flex; justify-content:center; gap:6px; padding-top:20px; flex-wrap:wrap;">
        <?php for ($pg = 1; $pg <= $pages; $pg++): ?>
            <a href="?page=<?= $pg ?>&search=<?= urlencode($search) ?>&cat=<?= $catFilter ?>"
               class="btn btn-sm <?= $pg === $page ? 'btn-primary' : 'btn-outline' ?>">
                <?= $pg ?>
            </a>
        <?php endfor; ?>
    </div>
    <?php endif; ?>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>
