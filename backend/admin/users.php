<?php
/**
 * Admin Panel – Total Users
 */
session_start();
require_once __DIR__ . '/../config/database.php';
if (!isset($_SESSION['admin_id'])) { header('Location: index.php'); exit; }

$db = getDB();

// Filters
$search = trim($_GET['search'] ?? '');
$filter = $_GET['filter'] ?? 'all'; // all | verified | unverified

$where  = "WHERE u.role = 'user'";
$params = [];
if ($search) {
    $where .= " AND (u.name LIKE ? OR u.email LIKE ?)";
    $params[] = "%$search%";
    $params[] = "%$search%";
}
if ($filter === 'verified')   $where .= " AND u.email_verified = 1";
if ($filter === 'unverified') $where .= " AND u.email_verified = 0";

$cntStmt = $db->prepare("SELECT COUNT(*) FROM users u $where");
$cntStmt->execute($params);
$total = (int)$cntStmt->fetchColumn();

// Pagination
$perPage = 20;
$page    = max(1, (int)($_GET['page'] ?? 1));
$offset  = ($page - 1) * $perPage;
$pages   = max(1, ceil($total / $perPage));

$stmt = $db->prepare(
    "SELECT u.id, u.name, u.email, u.email_verified, u.user_type, u.department,
            u.created_at,
            (SELECT COUNT(*) FROM downloads d WHERE d.user_id = u.id) AS dl_count,
            (SELECT COUNT(*) FROM reading_history rh WHERE rh.user_id = u.id) AS read_count
     FROM users u $where
     ORDER BY u.created_at DESC
     LIMIT $perPage OFFSET $offset"
);
$stmt->execute($params);
$users = $stmt->fetchAll();

// Summary stats
$totalUsers    = (int)$db->query("SELECT COUNT(*) FROM users WHERE role='user'")->fetchColumn();
$verifiedUsers = (int)$db->query("SELECT COUNT(*) FROM users WHERE role='user' AND email_verified=1")->fetchColumn();
$newThisMonth  = (int)$db->query("SELECT COUNT(*) FROM users WHERE role='user' AND created_at >= DATE_FORMAT(NOW(),'%Y-%m-01')")->fetchColumn();

$pageTitle  = 'Total Users';
$activePage = 'users';
?>
<?php include __DIR__ . '/includes/header.php'; ?>

<!-- Stats -->
<div class="stats-grid" style="grid-template-columns: repeat(auto-fit, minmax(180px,1fr)); margin-bottom:24px;">
    <div class="stat-card animate-in">
        <div class="stat-top">
            <div class="stat-label">Total Users</div>
            <div class="stat-icon" style="background:#dbeafe;color:#1d4ed8;"><i class="fa-solid fa-users"></i></div>
        </div>
        <div class="stat-value"><?= number_format($totalUsers) ?></div>
    </div>
    <div class="stat-card animate-in delay-1">
        <div class="stat-top">
            <div class="stat-label">Verified</div>
            <div class="stat-icon" style="background:#dcfce7;color:#15803d;"><i class="fa-solid fa-circle-check"></i></div>
        </div>
        <div class="stat-value"><?= number_format($verifiedUsers) ?></div>
    </div>
    <div class="stat-card animate-in delay-2">
        <div class="stat-top">
            <div class="stat-label">Unverified</div>
            <div class="stat-icon" style="background:#fee2e2;color:#b91c1c;"><i class="fa-solid fa-circle-xmark"></i></div>
        </div>
        <div class="stat-value"><?= number_format($totalUsers - $verifiedUsers) ?></div>
    </div>
    <div class="stat-card animate-in delay-3">
        <div class="stat-top">
            <div class="stat-label">New This Month</div>
            <div class="stat-icon" style="background:#fef3c7;color:#b45309;"><i class="fa-solid fa-user-plus"></i></div>
        </div>
        <div class="stat-value"><?= number_format($newThisMonth) ?></div>
    </div>
</div>

<!-- Filters & Search -->
<div class="card animate-in" style="margin-bottom:0;">
    <div class="card-header" style="flex-wrap:wrap; gap:12px;">
        <div class="card-title">All Users <span class="badge badge-gray" style="margin-left:6px;"><?= number_format($total) ?></span></div>
        <form method="GET" style="display:flex; gap:10px; flex-wrap:wrap; align-items:center;">
            <input type="text" name="search" class="form-control" style="width:220px;"
                   placeholder="Search name or email…" value="<?= htmlspecialchars($search) ?>">
            <select name="filter" class="form-control" style="width:160px;" onchange="this.form.submit()">
                <option value="all"        <?= $filter==='all'        ? 'selected':'' ?>>All Users</option>
                <option value="verified"   <?= $filter==='verified'   ? 'selected':'' ?>>Verified</option>
                <option value="unverified" <?= $filter==='unverified' ? 'selected':'' ?>>Unverified</option>
            </select>
            <button type="submit" class="btn btn-primary btn-sm"><i class="fa-solid fa-search"></i> Search</button>
            <?php if ($search || $filter !== 'all'): ?>
            <a href="users.php" class="btn btn-outline btn-sm">Clear</a>
            <?php endif; ?>
        </form>
    </div>

    <div class="table-wrap">
    <table>
        <thead>
            <tr>
                <th>#</th>
                <th>Name</th>
                <th>Email</th>
                <th>Type</th>
                <th>Department</th>
                <th>Downloads</th>
                <th>Reads</th>
                <th>Verified</th>
                <th>Joined</th>
            </tr>
        </thead>
        <tbody>
        <?php if (empty($users)): ?>
            <tr><td colspan="9" class="text-muted text-sm" style="text-align:center;padding:24px;">No users found.</td></tr>
        <?php else: ?>
        <?php foreach ($users as $i => $u): ?>
            <tr>
                <td class="text-muted text-sm"><?= ($page-1)*$perPage + $i + 1 ?></td>
                <td>
                    <div class="flex-center">
                        <div style="width:32px;height:32px;border-radius:50%;background:linear-gradient(135deg,#6366f1,#22c55e);
                                    display:flex;align-items:center;justify-content:center;color:#fff;font-size:13px;font-weight:700;flex-shrink:0;">
                            <?= strtoupper(substr($u['name'], 0, 1)) ?>
                        </div>
                        <span style="font-weight:600;"><?= htmlspecialchars($u['name']) ?></span>
                    </div>
                </td>
                <td class="text-muted text-sm"><?= htmlspecialchars($u['email']) ?></td>
                <td>
                    <?php if ($u['user_type']): ?>
                    <span class="badge <?= $u['user_type']==='student' ? 'badge-blue' : 'badge-purple' ?>">
                        <?= ucfirst($u['user_type']) ?>
                    </span>
                    <?php else: ?>
                    <span class="badge badge-gray">–</span>
                    <?php endif; ?>
                </td>
                <td class="text-muted text-sm"><?= htmlspecialchars($u['department'] ?? '–') ?></td>
                <td><span class="badge badge-amber"><?= $u['dl_count'] ?></span></td>
                <td><span class="badge badge-green"><?= $u['read_count'] ?></span></td>
                <td>
                    <?php if ($u['email_verified']): ?>
                        <span class="badge badge-green"><i class="fa-solid fa-check"></i> Yes</span>
                    <?php else: ?>
                        <span class="badge badge-red"><i class="fa-solid fa-xmark"></i> No</span>
                    <?php endif; ?>
                </td>
                <td class="text-muted text-sm"><?= date('M d, Y', strtotime($u['created_at'])) ?></td>
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
            <a href="?page=<?= $pg ?>&search=<?= urlencode($search) ?>&filter=<?= $filter ?>"
               class="btn btn-sm <?= $pg === $page ? 'btn-primary' : 'btn-outline' ?>">
                <?= $pg ?>
            </a>
        <?php endfor; ?>
    </div>
    <?php endif; ?>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>
