<?php
/**
 * Admin Panel – Main Dashboard
 */
session_start();
require_once __DIR__ . '/../config/database.php';
if (!isset($_SESSION['admin_id'])) { header('Location: index.php'); exit; }

$db = getDB();

// ── Core stats ─────────────────────────────────────────────────────────
$totalUsers   = (int)$db->query('SELECT COUNT(*) FROM users WHERE role="user"')->fetchColumn();
$totalPubs    = (int)$db->query('SELECT COUNT(*) FROM publications')->fetchColumn();
$totalCats    = (int)$db->query('SELECT COUNT(*) FROM categories')->fetchColumn();
try { $totalDls = (int)$db->query('SELECT COUNT(*) FROM downloads')->fetchColumn(); } catch(PDOException $e) { $totalDls = 0; }

// Average session time and churn (fault-tolerant – tables may not exist yet)
$avgTime     = '00:00';
$activeUsers = 0;
$churnRate   = 0;
try {
    // Average total time per user
    $avgSec = $db->query(
        'SELECT AVG(total) FROM (
            SELECT SUM(duration_sec) as total FROM app_sessions WHERE duration_sec IS NOT NULL GROUP BY user_id
        ) as user_times'
    )->fetchColumn();
    $avgSec = $avgSec ? (int)$avgSec : 0;
    $avgTime = sprintf('%02d:%02d', intdiv($avgSec, 60), $avgSec % 60);

    // Churn rate: number of users who are inactive (proxy for deleted/deactivated)
    $activeUsers = (int)$db->query(
        'SELECT COUNT(DISTINCT user_id) FROM app_sessions WHERE session_start >= DATE_SUB(NOW(), INTERVAL 30 DAY)'
    )->fetchColumn();
    $churnCount = $totalUsers - $activeUsers;
} catch (PDOException $e) { /* app_sessions not yet created – ignore */ 
    $churnCount = 0;
}

// New users this month
$newUsersMonth = (int)$db->query(
    'SELECT COUNT(*) FROM users WHERE role="user" AND created_at >= DATE_FORMAT(NOW(),"%Y-%m-01")'
)->fetchColumn();

// ── Downloads by category (for bar chart) ──────────────────────────────
$catDownloads = $db->query(
    'SELECT c.name, COALESCE(c.color,"#6366f1") AS color, COUNT(d.id) AS cnt
     FROM categories c
     LEFT JOIN publications p ON p.category_id = c.id
     LEFT JOIN downloads d    ON d.pub_id = p.id
     GROUP BY c.id, c.name, c.color
     ORDER BY cnt DESC'
)->fetchAll();

// ── Recent publications ─────────────────────────────────────────────────
$recentPubs = $db->query(
    'SELECT p.id, p.title, p.created_at, c.name AS category_name,
            COALESCE(p.download_count,0) AS download_count,
            COALESCE(p.view_count,0) AS view_count
     FROM publications p JOIN categories c ON c.id = p.category_id
     ORDER BY p.created_at DESC LIMIT 6'
)->fetchAll();

// ── Top downloaded ──────────────────────────────────────────────────────
$topDownloaded = $db->query(
    'SELECT p.title, c.name AS cat, COUNT(d.id) AS cnt
     FROM publications p
     JOIN categories c ON c.id = p.category_id
     LEFT JOIN downloads d ON d.pub_id = p.id
     GROUP BY p.id ORDER BY cnt DESC LIMIT 5'
)->fetchAll();

$pageTitle  = 'Dashboard';
$activePage = 'dashboard';
?>
<?php include __DIR__ . '/includes/header.php'; ?>

<!-- ── Greeting ──────────────────────────────────────────────────────── -->
<div class="flex-center mb-24 animate-in" style="margin-bottom:24px;">
    <div>
        <h1 style="font-size:22px; font-weight:800; color:var(--text);">
            <span id="dynamic-greeting">Hello</span>, <?= htmlspecialchars($_SESSION['admin_name']) ?>! 👋
        </h1>
        <p class="text-muted text-sm">Here's what's happening with DigiPress today.</p>
    </div>
</div>

<script>
document.addEventListener("DOMContentLoaded", function() {
    const hour = new Date().getHours();
    let greeting = 'Good Evening';
    if (hour >= 5 && hour < 12) greeting = 'Good Morning';
    else if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    else if (hour >= 17 && hour < 21) greeting = 'Good Evening';
    else greeting = 'Good Night';
    document.getElementById('dynamic-greeting').textContent = greeting;
});
</script>

<!-- ── Stat Cards ───────────────────────────────────────────────────── -->
<div class="stats-grid">
    <div class="stat-card animate-in delay-1">
        <div class="stat-top">
            <div class="stat-label">Total Users</div>
            <div class="stat-icon" style="background:#dbeafe; color:#1d4ed8;">
                <i class="fa-solid fa-users"></i>
            </div>
        </div>
        <div class="stat-value"><?= number_format($totalUsers) ?></div>
        <div class="stat-change up">
            <i class="fa-solid fa-arrow-trend-up"></i>
            +<?= $newUsersMonth ?> this month
        </div>
    </div>

    <div class="stat-card animate-in delay-2">
        <div class="stat-top">
            <div class="stat-label">Avg. Session Time</div>
            <div class="stat-icon" style="background:#dcfce7; color:#15803d;">
                <i class="fa-solid fa-clock"></i>
            </div>
        </div>
        <div class="stat-value" style="font-size:26px;"><?= $avgTime ?></div>
        <div class="stat-change neutral">
            <i class="fa-solid fa-minus"></i>
            minutes:seconds per user
        </div>
    </div>

    <div class="stat-card animate-in delay-3">
        <div class="stat-top">
            <div class="stat-label">Churn Rate</div>
            <div class="stat-icon" style="background:#fee2e2; color:#b91c1c;">
                <i class="fa-solid fa-user-minus"></i>
            </div>
        </div>
        <div class="stat-value"><?= number_format($churnCount) ?></div>
        <div class="stat-change <?= $churnCount > ($totalUsers * 0.3) ? 'down' : 'up' ?>">
            <i class="fa-solid fa-<?= $churnCount > ($totalUsers * 0.3) ? 'arrow-trend-up' : 'arrow-trend-down' ?>"></i>
            <?= $churnCount > 0 ? 'Users deactivated/deleted' : 'Healthy retention' ?>
        </div>
    </div>

    <div class="stat-card animate-in delay-4">
        <div class="stat-top">
            <div class="stat-label">Total Downloads</div>
            <div class="stat-icon" style="background:#fef3c7; color:#b45309;">
                <i class="fa-solid fa-download"></i>
            </div>
        </div>
        <div class="stat-value"><?= number_format($totalDls) ?></div>
        <div class="stat-change up">
            <i class="fa-solid fa-book-open"></i>
            Across <?= $totalPubs ?> publications
        </div>
    </div>
</div>

<!-- ── Charts Row ───────────────────────────────────────────────────── -->
<div class="grid-2" style="margin-bottom:24px;">

    <!-- Bar Chart: Downloads by Category -->
    <div class="card animate-in">
        <div class="card-header">
            <div>
                <div class="card-title">Downloads by Category</div>
                <div class="card-subtitle">Total downloads per magazine category</div>
            </div>
            <span class="badge badge-green"><i class="fa-solid fa-chart-bar"></i> Live</span>
        </div>
        <canvas id="catBarChart" height="220"></canvas>
    </div>

    <!-- Top Downloaded -->
    <div class="card animate-in">
        <div class="card-header">
            <div>
                <div class="card-title">Top Downloaded Publications</div>
                <div class="card-subtitle">All-time most downloaded PDFs</div>
            </div>
        </div>
        <?php if (empty($topDownloaded)): ?>
            <p class="text-muted text-sm">No downloads recorded yet.</p>
        <?php else: ?>
        <div style="display:flex;flex-direction:column;gap:14px;">
            <?php foreach ($topDownloaded as $i => $row):
                $maxCnt = max(1, $topDownloaded[0]['cnt']);
                $pct    = round(($row['cnt'] / $maxCnt) * 100);
                $colors = ['var(--accent2)','var(--primary)','var(--accent1)','var(--accent4)','var(--accent3)'];
                $color  = $colors[$i % 5];
            ?>
            <div>
                <div class="flex-center" style="margin-bottom:6px;">
                    <span class="rank rank-<?= $i < 3 ? $i+1 : '' ?>"
                          style="background:<?= $color ?>22; color:<?= $color ?>;"><?= $i+1 ?></span>
                    <span style="font-size:13px; font-weight:600; flex:1;"><?= htmlspecialchars($row['title']) ?></span>
                    <span class="badge badge-gray"><?= $row['cnt'] ?> dls</span>
                </div>
                <div class="progress-bar-wrap">
                    <div class="progress-bar" style="width:<?= $pct ?>%; background:<?= $color ?>;"></div>
                </div>
            </div>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>
    </div>

</div>

<!-- ── Quick Stats Row ──────────────────────────────────────────────── -->
<div class="grid-3" style="margin-bottom:24px;">
    <div class="card animate-in" style="text-align:center;">
        <div style="font-size:32px; margin-bottom:8px;">📚</div>
        <div style="font-size:26px; font-weight:800; color:var(--accent1);"><?= $totalPubs ?></div>
        <div class="text-muted text-sm">Total Publications</div>
    </div>
    <div class="card animate-in" style="text-align:center;">
        <div style="font-size:32px; margin-bottom:8px;">🏷️</div>
        <div style="font-size:26px; font-weight:800; color:var(--accent2);"><?= $totalCats ?></div>
        <div class="text-muted text-sm">Categories</div>
    </div>
    <div class="card animate-in" style="text-align:center;">
        <div style="font-size:32px; margin-bottom:8px;">👥</div>
        <div style="font-size:26px; font-weight:800; color:var(--primary);"><?= $activeUsers ?></div>
        <div class="text-muted text-sm">Active Users (30d)</div>
    </div>
</div>

<!-- ── Recent Publications ─────────────────────────────────────────── -->
<div class="card animate-in">
    <div class="card-header">
        <div>
            <div class="card-title">Recent Publications</div>
            <div class="card-subtitle">Latest uploaded PDFs</div>
        </div>
        <a href="publications.php" class="btn btn-outline btn-sm">View All</a>
    </div>
    <?php if (empty($recentPubs)): ?>
        <p class="text-muted text-sm">No publications yet. <a href="new_publication.php" style="color:var(--primary);">Upload one!</a></p>
    <?php else: ?>
    <div class="table-wrap">
    <table>
        <thead>
            <tr>
                <th>#</th>
                <th>Title</th>
                <th>Category</th>
                <th>Downloads</th>
                <th>Views</th>
                <th>Date</th>
                <th>Action</th>
            </tr>
        </thead>
        <tbody>
        <?php foreach ($recentPubs as $i => $p): ?>
            <tr>
                <td><span class="text-muted text-sm"><?= $i+1 ?></span></td>
                <td style="font-weight:600; max-width:220px;">
                    <div style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:200px;">
                        <?= htmlspecialchars($p['title']) ?>
                    </div>
                </td>
                <td><span class="badge badge-blue"><?= htmlspecialchars($p['category_name']) ?></span></td>
                <td><?= number_format($p['download_count']) ?></td>
                <td><?= number_format($p['view_count']) ?></td>
                <td class="text-muted text-sm"><?= date('M d, Y', strtotime($p['created_at'])) ?></td>
                <td>
                    <a href="publications.php?highlight=<?= $p['id'] ?>" class="btn btn-outline btn-sm">
                        <i class="fa-solid fa-eye"></i>
                    </a>
                </td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    </div>
    <?php endif; ?>
</div>

<script>
// ── Category Bar Chart ────────────────────────────────────────────────
const catLabels = <?= json_encode(array_column($catDownloads, 'name')) ?>;
const catCounts = <?= json_encode(array_column($catDownloads, 'cnt')) ?>;
const defaultPalette = ['#6366f1', '#22c55e', '#f59e0b', '#ef4444', '#06b6d4', '#8b5cf6', '#ec4899', '#14b8a6', '#f97316', '#0ea5e9'];
const dbColors  = <?= json_encode(array_column($catDownloads, 'color')) ?>;
const catColors = dbColors.map((c, i) => c === '#6366f1' ? defaultPalette[i % defaultPalette.length] : c);

const ctx = document.getElementById('catBarChart').getContext('2d');
new Chart(ctx, {
    type: 'bar',
    data: {
        labels: catLabels,
        datasets: [{
            label: 'Downloads',
            data: catCounts,
            backgroundColor: catColors.map(c => c + 'cc'),
            borderColor: catColors,
            borderWidth: 2,
            borderRadius: 8,
            borderSkipped: false,
        }]
    },
    options: {
        responsive: true,
        plugins: {
            legend: { display: false },
            tooltip: {
                callbacks: {
                    label: ctx => ' ' + ctx.parsed.y + ' downloads'
                }
            }
        },
        scales: {
            x: { grid: { display: false }, ticks: { font: { size: 12 } } },
            y: { grid: { color: '#f0f0f0' }, ticks: { font: { size: 12 }, precision: 0 }, beginAtZero: true }
        }
    }
});
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>
