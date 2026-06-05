<?php
/**
 * Admin Panel – Publication Stats
 */
session_start();
require_once __DIR__ . '/../config/database.php';
if (!isset($_SESSION['admin_id'])) { header('Location: index.php'); exit; }

$db = getDB();

// ── Most Downloaded PDF ────────────────────────────────────────────────
$mostDownloaded = [];
try {
    $mostDownloaded = $db->query(
        'SELECT p.id, p.title, c.name AS cat, COUNT(d.id) AS cnt
         FROM publications p
         JOIN categories c ON c.id = p.category_id
         LEFT JOIN downloads d ON d.pub_id = p.id
         GROUP BY p.id ORDER BY cnt DESC LIMIT 10'
    )->fetchAll();
} catch (PDOException $e) {}

// ── Most Read Category (from reading history) ──────────────────────────
$mostReadCat = $db->query(
    'SELECT c.name, COALESCE(c.color,"#6366f1") AS color, COUNT(rh.id) AS cnt
     FROM categories c
     LEFT JOIN publications p ON p.category_id = c.id
     LEFT JOIN reading_history rh ON rh.pub_id = p.id
     GROUP BY c.id ORDER BY cnt DESC'
)->fetchAll();

// ── Most Shared PDFs ───────────────────────────────────────────────────
$mostShared = [];
try {
    $mostShared = $db->query(
        'SELECT p.id, p.title, c.name AS cat, COUNT(s.id) AS cnt
         FROM publications p
         JOIN categories c ON c.id = p.category_id
         LEFT JOIN pdf_shares s ON s.pub_id = p.id
         GROUP BY p.id ORDER BY cnt DESC LIMIT 10'
    )->fetchAll();
} catch (PDOException $e) {}

// ── Highest Views ──────────────────────────────────────────────────────
$highestViews = [];
try {
    $highestViews = $db->query(
        'SELECT p.id, p.title, c.name AS cat,
                COALESCE(p.view_count,0) + COALESCE((SELECT COUNT(*) FROM pdf_views v WHERE v.pub_id = p.id),0) AS cnt
         FROM publications p
         JOIN categories c ON c.id = p.category_id
         ORDER BY cnt DESC LIMIT 10'
    )->fetchAll();
} catch (PDOException $e) {}

// ── Download trend (last 30 days) ─────────────────────────────────────
$dlTrend = [];
try {
    $dlTrend = $db->query(
        'SELECT DATE(downloaded_at) AS day, COUNT(*) AS cnt
         FROM downloads
         WHERE downloaded_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
         GROUP BY DATE(downloaded_at)
         ORDER BY day ASC'
    )->fetchAll();
} catch (PDOException $e) {}

// ── Category read distribution ─────────────────────────────────────────
$catReadDist = $db->query(
    'SELECT c.name, COALESCE(c.color,"#6366f1") AS color,
            COUNT(rh.id) AS read_count,
            0 AS download_count
     FROM categories c
     LEFT JOIN publications p ON p.category_id = c.id
     LEFT JOIN reading_history rh ON rh.pub_id = p.id
     GROUP BY c.id'
)->fetchAll();

$pageTitle  = 'Publication Stats';
$activePage = 'pub_stats';
?>
<?php include __DIR__ . '/includes/header.php'; ?>

<!-- ── Top 4 KPI Cards ───────────────────────────────────────────────── -->
<div class="stats-grid animate-in" style="margin-bottom:24px;">
    <div class="stat-card">
        <div class="stat-top">
            <div class="stat-label">Top Downloaded</div>
            <div class="stat-icon" style="background:#fef3c7;color:#b45309;"><i class="fa-solid fa-download"></i></div>
        </div>
        <?php if (!empty($mostDownloaded[0])): ?>
        <div style="font-size:14px;font-weight:700;color:var(--text);line-height:1.3;">
            <?= htmlspecialchars($mostDownloaded[0]['title']) ?>
        </div>
        <div class="stat-change up">
            <i class="fa-solid fa-trophy"></i>
            <?= number_format($mostDownloaded[0]['cnt']) ?> downloads
        </div>
        <?php else: ?><div class="text-muted text-sm">No data yet</div><?php endif; ?>
    </div>

    <div class="stat-card">
        <div class="stat-top">
            <div class="stat-label">Top Read Category</div>
            <div class="stat-icon" style="background:#dcfce7;color:#15803d;"><i class="fa-solid fa-book-open"></i></div>
        </div>
        <?php if (!empty($mostReadCat[0])): ?>
        <div style="font-size:18px;font-weight:800;color:var(--text);"><?= htmlspecialchars($mostReadCat[0]['name']) ?></div>
        <div class="stat-change up">
            <i class="fa-solid fa-fire"></i>
            <?= number_format($mostReadCat[0]['cnt']) ?> reads
        </div>
        <?php else: ?><div class="text-muted text-sm">No data yet</div><?php endif; ?>
    </div>

    <div class="stat-card">
        <div class="stat-top">
            <div class="stat-label">Most Shared</div>
            <div class="stat-icon" style="background:#ede9fe;color:#6d28d9;"><i class="fa-solid fa-share-nodes"></i></div>
        </div>
        <?php if (!empty($mostShared[0])): ?>
        <div style="font-size:14px;font-weight:700;color:var(--text);line-height:1.3;">
            <?= htmlspecialchars($mostShared[0]['title']) ?>
        </div>
        <div class="stat-change up">
            <i class="fa-solid fa-share"></i>
            <?= number_format($mostShared[0]['cnt']) ?> shares
        </div>
        <?php else: ?><div class="text-muted text-sm">No data yet</div><?php endif; ?>
    </div>

    <div class="stat-card">
        <div class="stat-top">
            <div class="stat-label">Highest Views</div>
            <div class="stat-icon" style="background:#dbeafe;color:#1d4ed8;"><i class="fa-solid fa-eye"></i></div>
        </div>
        <?php if (!empty($highestViews[0])): ?>
        <div style="font-size:14px;font-weight:700;color:var(--text);line-height:1.3;">
            <?= htmlspecialchars($highestViews[0]['title']) ?>
        </div>
        <div class="stat-change up">
            <i class="fa-solid fa-eye"></i>
            <?= number_format($highestViews[0]['cnt']) ?> views
        </div>
        <?php else: ?><div class="text-muted text-sm">No data yet</div><?php endif; ?>
    </div>
</div>

<!-- ── Charts Row ───────────────────────────────────────────────────── -->
<div class="grid-2" style="margin-bottom:24px;">

    <!-- Download Trend Line Chart -->
    <div class="card animate-in">
        <div class="card-header">
            <div>
                <div class="card-title">Download Trend</div>
                <div class="card-subtitle">Last 30 days daily downloads</div>
            </div>
        </div>
        <canvas id="dlTrendChart" height="220"></canvas>
    </div>

    <!-- Category Distribution Doughnut -->
    <div class="card animate-in delay-1">
        <div class="card-header">
            <div>
                <div class="card-title">Category Distribution</div>
                <div class="card-subtitle">Reads & downloads by category</div>
            </div>
        </div>
        <canvas id="catDistChart" height="220"></canvas>
    </div>
</div>

<!-- ── Stats Tables ──────────────────────────────────────────────────── -->
<div class="grid-2" style="margin-bottom:24px;">

    <!-- Most Downloaded -->
    <div class="card animate-in">
        <div class="card-header">
            <div class="card-title">📥 Most Downloaded PDFs</div>
        </div>
        <div class="table-wrap">
        <table>
            <thead>
                <tr><th>Rank</th><th>Title</th><th>Category</th><th>Downloads</th></tr>
            </thead>
            <tbody>
            <?php foreach ($mostDownloaded as $i => $row): ?>
            <tr>
                <td>
                    <span class="rank" style="background:<?= ['#fef3c7','#f1f5f9','#fce7f3'][$i] ?? '#f1f5f9' ?>;
                                               color:<?= ['#d97706','#64748b','#9d174d'][$i] ?? '#64748b' ?>;">
                        <?= $i+1 ?>
                    </span>
                </td>
                <td style="font-weight:500;font-size:13px;"><?= htmlspecialchars($row['title']) ?></td>
                <td><span class="badge badge-blue"><?= htmlspecialchars($row['cat']) ?></span></td>
                <td><strong><?= number_format($row['cnt']) ?></strong></td>
            </tr>
            <?php endforeach; ?>
            <?php if (empty($mostDownloaded)): ?>
                <tr><td colspan="4" class="text-muted text-sm" style="text-align:center;padding:20px;">No download data yet.</td></tr>
            <?php endif; ?>
            </tbody>
        </table>
        </div>
    </div>

    <!-- Most Shared -->
    <div class="card animate-in delay-1">
        <div class="card-header">
            <div class="card-title">📤 Most Shared PDFs</div>
        </div>
        <div class="table-wrap">
        <table>
            <thead>
                <tr><th>Rank</th><th>Title</th><th>Category</th><th>Shares</th></tr>
            </thead>
            <tbody>
            <?php foreach ($mostShared as $i => $row): ?>
            <tr>
                <td>
                    <span class="rank" style="background:<?= ['#ede9fe','#f1f5f9','#fce7f3'][$i] ?? '#f1f5f9' ?>;
                                               color:<?= ['#6d28d9','#64748b','#9d174d'][$i] ?? '#64748b' ?>;">
                        <?= $i+1 ?>
                    </span>
                </td>
                <td style="font-weight:500;font-size:13px;"><?= htmlspecialchars($row['title']) ?></td>
                <td><span class="badge badge-purple"><?= htmlspecialchars($row['cat']) ?></span></td>
                <td><strong><?= number_format($row['cnt']) ?></strong></td>
            </tr>
            <?php endforeach; ?>
            <?php if (empty($mostShared)): ?>
                <tr><td colspan="4" class="text-muted text-sm" style="text-align:center;padding:20px;">No share data yet.</td></tr>
            <?php endif; ?>
            </tbody>
        </table>
        </div>
    </div>
</div>

<!-- Most Read Category & Highest Views -->
<div class="grid-2" style="margin-bottom:24px;">

    <!-- Category Reads -->
    <div class="card animate-in">
        <div class="card-header">
            <div class="card-title">📚 Most Read Categories</div>
        </div>
        <div style="display:flex;flex-direction:column;gap:12px;">
        <?php foreach ($mostReadCat as $i => $row):
            $maxR = max(1, $mostReadCat[0]['cnt']);
            $pct  = round(($row['cnt'] / $maxR) * 100);
        ?>
        <div>
            <div class="flex-center" style="margin-bottom:5px;">
                <span style="font-size:13px;font-weight:600;flex:1;"><?= htmlspecialchars($row['name']) ?></span>
                <span class="text-muted text-sm"><?= number_format($row['cnt']) ?> reads</span>
            </div>
            <div class="progress-bar-wrap">
                <div class="progress-bar" style="width:<?= $pct ?>%; background:<?= htmlspecialchars($row['color']) ?>;"></div>
            </div>
        </div>
        <?php endforeach; ?>
        <?php if (empty($mostReadCat)): ?><p class="text-muted text-sm">No data.</p><?php endif; ?>
        </div>
    </div>

    <!-- Highest Views -->
    <div class="card animate-in delay-1">
        <div class="card-header">
            <div class="card-title">👁️ Highest Views</div>
        </div>
        <div class="table-wrap">
        <table>
            <thead>
                <tr><th>Rank</th><th>Title</th><th>Category</th><th>Views</th></tr>
            </thead>
            <tbody>
            <?php foreach ($highestViews as $i => $row): ?>
            <tr>
                <td><span class="rank" style="background:#dbeafe;color:#1d4ed8;"><?= $i+1 ?></span></td>
                <td style="font-weight:500;font-size:13px;"><?= htmlspecialchars($row['title']) ?></td>
                <td><span class="badge badge-green"><?= htmlspecialchars($row['cat']) ?></span></td>
                <td><strong><?= number_format($row['cnt']) ?></strong></td>
            </tr>
            <?php endforeach; ?>
            <?php if (empty($highestViews)): ?>
                <tr><td colspan="4" class="text-muted text-sm" style="text-align:center;padding:20px;">No view data yet.</td></tr>
            <?php endif; ?>
            </tbody>
        </table>
        </div>
    </div>
</div>

<script>
// ── Download Trend Line Chart ─────────────────────────────────────────
const dlDays = <?= json_encode(array_column($dlTrend, 'day')) ?>;
const dlCnts = <?= json_encode(array_column($dlTrend, 'cnt')) ?>;

const ctx1 = document.getElementById('dlTrendChart').getContext('2d');
new Chart(ctx1, {
    type: 'line',
    data: {
        labels: dlDays,
        datasets: [{
            label: 'Downloads',
            data: dlCnts,
            borderColor: '#22c55e',
            backgroundColor: 'rgba(34,197,94,.1)',
            borderWidth: 2.5,
            pointRadius: 4,
            pointBackgroundColor: '#22c55e',
            tension: .4,
            fill: true,
        }]
    },
    options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: {
            x: { grid: { display: false }, ticks: { font: { size: 11 }, maxRotation: 45 } },
            y: { grid: { color: '#f0f0f0' }, beginAtZero: true, ticks: { precision: 0 } }
        }
    }
});

// ── Category Distribution Doughnut ────────────────────────────────────
const catNames   = <?= json_encode(array_column($catReadDist, 'name')) ?>;
const catReads   = <?= json_encode(array_column($catReadDist, 'read_count')) ?>;
const defaultPalette = ['#6366f1', '#22c55e', '#f59e0b', '#ef4444', '#06b6d4', '#8b5cf6', '#ec4899', '#14b8a6', '#f97316', '#0ea5e9'];
const dbColors2  = <?= json_encode(array_column($catReadDist, 'color')) ?>;
const catColors2 = dbColors2.map((c, i) => c === '#6366f1' ? defaultPalette[i % defaultPalette.length] : c);

const ctx2 = document.getElementById('catDistChart').getContext('2d');
new Chart(ctx2, {
    type: 'doughnut',
    data: {
        labels: catNames,
        datasets: [{
            data: catReads,
            backgroundColor: catColors2.map(c => c + 'cc'),
            borderColor: catColors2,
            borderWidth: 2,
        }]
    },
    options: {
        responsive: true,
        plugins: {
            legend: { position: 'bottom', labels: { font: { size: 11 }, padding: 12 } }
        },
        cutout: '65%'
    }
});
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>
