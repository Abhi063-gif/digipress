<?php
/**
 * Admin Panel – Shared Header & Sidebar
 * Include at the top of every admin page
 * Requires: $pageTitle, $activePage
 */
if (!isset($_SESSION)) session_start();
require_once __DIR__ . '/../../config/database.php';

if (!isset($_SESSION['admin_id'])) {
    header('Location: ' . dirname($_SERVER['SCRIPT_NAME'], 1) . '/../index.php');
    exit;
}

$adminName  = $_SESSION['admin_name']  ?? 'Admin';
$adminEmail = $_SESSION['admin_email'] ?? '';
$pageTitle  = $pageTitle  ?? 'Dashboard';
$activePage = $activePage ?? 'dashboard';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($pageTitle) ?> – DigiPress Admin</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
    <style>
        /* ── CSS Reset & Variables ─────────────────────────────────────── */
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        :root {
            --primary:      #22c55e;
            --primary-dark: #16a34a;
            --primary-soft: rgba(34,197,94,.12);
            --bg:           #f4f6fb;
            --sidebar-bg:   #ffffff;
            --card-bg:      #ffffff;
            --border:       #e8ecf0;
            --text:         #0f172a;
            --text-muted:   #64748b;
            --text-light:   #94a3b8;
            --accent1:      #6366f1;
            --accent2:      #f59e0b;
            --accent3:      #ef4444;
            --accent4:      #06b6d4;
            --sidebar-w:    248px;
            --topbar-h:     64px;
            --radius:       12px;
            --shadow:       0 1px 3px rgba(0,0,0,.06), 0 4px 16px rgba(0,0,0,.04);
            --shadow-md:    0 4px 20px rgba(0,0,0,.10);
            --transition:   .2s ease;
        }

        body {
            font-family: 'Inter', system-ui, sans-serif;
            background: var(--bg);
            color: var(--text);
            display: flex;
            min-height: 100vh;
            overflow-x: hidden;
        }

        /* ── Sidebar ───────────────────────────────────────────────────── */
        .sidebar {
            width: var(--sidebar-w);
            background: var(--sidebar-bg);
            border-right: 1px solid var(--border);
            display: flex;
            flex-direction: column;
            position: fixed;
            top: 0; left: 0; bottom: 0;
            z-index: 100;
            transition: transform var(--transition);
            overflow-y: auto;
        }

        .sidebar-logo {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 20px 20px 16px;
            border-bottom: 1px solid var(--border);
        }
        .sidebar-logo .logo-icon {
            width: 40px; height: 40px;
            display: flex; align-items: center; justify-content: center;
            flex-shrink: 0;
            overflow: hidden;
            border-radius: 8px;
        }
        .sidebar-logo .logo-icon img {
            width: 100%;
            height: 100%;
            object-fit: contain;
        }
        .sidebar-logo .logo-text {
            font-size: 17px;
            font-weight: 800;
            color: var(--text);
            letter-spacing: -.3px;
        }
        .sidebar-logo .logo-text span {
            color: var(--primary);
        }

        .sidebar-section-label {
            padding: 18px 20px 6px;
            font-size: 10px;
            font-weight: 700;
            color: var(--text-light);
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .nav-item {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 10px 20px;
            margin: 1px 10px;
            border-radius: 10px;
            text-decoration: none;
            color: var(--text-muted);
            font-size: 13.5px;
            font-weight: 500;
            transition: all var(--transition);
            cursor: pointer;
        }
        .nav-item .nav-icon {
            width: 32px; height: 32px;
            border-radius: 8px;
            display: flex; align-items: center; justify-content: center;
            font-size: 14px;
            background: transparent;
            transition: all var(--transition);
            flex-shrink: 0;
        }
        .nav-item:hover {
            background: var(--primary-soft);
            color: var(--primary-dark);
        }
        .nav-item:hover .nav-icon {
            background: var(--primary-soft);
            color: var(--primary);
        }
        .nav-item.active {
            background: var(--primary-soft);
            color: var(--primary-dark);
            font-weight: 600;
        }
        .nav-item.active .nav-icon {
            background: var(--primary);
            color: #fff;
        }
        .nav-item .nav-badge {
            margin-left: auto;
            background: var(--primary);
            color: #fff;
            font-size: 10px;
            font-weight: 700;
            padding: 2px 7px;
            border-radius: 20px;
        }

        .sidebar-footer {
            margin-top: auto;
            padding: 16px;
            border-top: 1px solid var(--border);
        }
        .admin-profile {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 10px;
            border-radius: 10px;
            background: var(--bg);
        }
        .admin-avatar {
            width: 36px; height: 36px;
            border-radius: 50%;
            background: linear-gradient(135deg, var(--accent1), var(--primary));
            display: flex; align-items: center; justify-content: center;
            color: #fff; font-size: 14px; font-weight: 700;
            flex-shrink: 0;
        }
        .admin-info .name { font-size: 12px; font-weight: 700; color: var(--text); }
        .admin-info .role { font-size: 10px; color: var(--text-light); }

        /* ── Main Content ───────────────────────────────────────────────── */
        .main-content {
            margin-left: var(--sidebar-w);
            flex: 1;
            display: flex;
            flex-direction: column;
            min-height: 100vh;
        }

        /* ── Topbar ─────────────────────────────────────────────────────── */
        .topbar {
            height: var(--topbar-h);
            background: var(--card-bg);
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            padding: 0 28px;
            gap: 16px;
            position: sticky;
            top: 0;
            z-index: 50;
        }
        .topbar-title {
            font-size: 18px;
            font-weight: 700;
            color: var(--text);
            flex: 1;
        }
        .topbar-title span {
            font-weight: 400;
            color: var(--text-muted);
            font-size: 14px;
        }
        .topbar-actions {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .topbar-btn {
            width: 38px; height: 38px;
            border-radius: 10px;
            background: var(--bg);
            border: 1px solid var(--border);
            display: flex; align-items: center; justify-content: center;
            color: var(--text-muted);
            font-size: 15px;
            cursor: pointer;
            transition: all var(--transition);
            text-decoration: none;
        }
        .topbar-btn:hover {
            background: var(--primary-soft);
            color: var(--primary);
            border-color: var(--primary);
        }
        .topbar-user {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 6px 10px;
            border-radius: 10px;
            background: var(--bg);
            border: 1px solid var(--border);
            cursor: pointer;
            font-size: 13px;
            font-weight: 600;
            color: var(--text);
        }
        .topbar-user .avatar {
            width: 28px; height: 28px;
            border-radius: 50%;
            background: linear-gradient(135deg, var(--accent1), var(--primary));
            display: flex; align-items: center; justify-content: center;
            color: #fff; font-size: 11px; font-weight: 700;
        }

        /* ── Page Body ──────────────────────────────────────────────────── */
        .page-body {
            padding: 28px;
            flex: 1;
        }

        /* ── Cards ──────────────────────────────────────────────────────── */
        .card {
            background: var(--card-bg);
            border-radius: var(--radius);
            border: 1px solid var(--border);
            box-shadow: var(--shadow);
            padding: 24px;
        }
        .card-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 20px;
        }
        .card-title {
            font-size: 15px;
            font-weight: 700;
            color: var(--text);
        }
        .card-subtitle {
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 2px;
        }

        /* ── Stat Cards ─────────────────────────────────────────────────── */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 20px;
            margin-bottom: 24px;
        }
        .stat-card {
            background: var(--card-bg);
            border-radius: var(--radius);
            border: 1px solid var(--border);
            box-shadow: var(--shadow);
            padding: 22px;
            display: flex;
            flex-direction: column;
            gap: 12px;
            transition: transform var(--transition), box-shadow var(--transition);
        }
        .stat-card:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }
        .stat-top {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
        }
        .stat-label {
            font-size: 12px;
            font-weight: 600;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: .5px;
        }
        .stat-icon {
            width: 42px; height: 42px;
            border-radius: 12px;
            display: flex; align-items: center; justify-content: center;
            font-size: 18px;
        }
        .stat-value {
            font-size: 30px;
            font-weight: 800;
            color: var(--text);
            letter-spacing: -1px;
            line-height: 1;
        }
        .stat-change {
            font-size: 12px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 4px;
        }
        .stat-change.up   { color: var(--primary); }
        .stat-change.down { color: var(--accent3); }
        .stat-change.neutral { color: var(--text-muted); }

        /* ── Buttons ────────────────────────────────────────────────────── */
        .btn {
            display: inline-flex;
            align-items: center;
            gap: 7px;
            padding: 9px 18px;
            border-radius: 9px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            transition: all var(--transition);
            border: none;
            text-decoration: none;
        }
        .btn-primary {
            background: var(--primary);
            color: #fff;
        }
        .btn-primary:hover { background: var(--primary-dark); transform: translateY(-1px); }
        .btn-outline {
            background: transparent;
            border: 1.5px solid var(--border);
            color: var(--text-muted);
        }
        .btn-outline:hover { border-color: var(--primary); color: var(--primary); }
        .btn-danger {
            background: var(--accent3);
            color: #fff;
        }
        .btn-danger:hover { background: #dc2626; }
        .btn-sm {
            padding: 6px 12px;
            font-size: 12px;
            border-radius: 7px;
        }

        /* ── Forms ──────────────────────────────────────────────────────── */
        .form-group { margin-bottom: 16px; }
        .form-label {
            display: block;
            font-size: 12px;
            font-weight: 600;
            color: var(--text);
            margin-bottom: 6px;
            text-transform: uppercase;
            letter-spacing: .4px;
        }
        .form-control {
            width: 100%;
            padding: 10px 14px;
            border: 1.5px solid var(--border);
            border-radius: 9px;
            font-size: 13.5px;
            font-family: inherit;
            background: var(--bg);
            color: var(--text);
            outline: none;
            transition: border-color var(--transition), box-shadow var(--transition);
        }
        .form-control:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px var(--primary-soft);
        }
        select.form-control { cursor: pointer; }
        textarea.form-control { resize: vertical; min-height: 90px; }

        /* ── Alerts ─────────────────────────────────────────────────────── */
        .alert {
            padding: 12px 16px;
            border-radius: 10px;
            font-size: 13px;
            font-weight: 500;
            margin-bottom: 18px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .alert-success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #166534; }
        .alert-error   { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; }
        .alert-info    { background: #eff6ff; border: 1px solid #bfdbfe; color: #1e40af; }

        /* ── Tables ─────────────────────────────────────────────────────── */
        .table-wrap { overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        thead th {
            text-align: left;
            padding: 10px 14px;
            font-size: 11px;
            font-weight: 700;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: .5px;
            background: var(--bg);
            border-bottom: 1px solid var(--border);
        }
        tbody td {
            padding: 12px 14px;
            border-bottom: 1px solid var(--border);
            vertical-align: middle;
        }
        tbody tr:last-child td { border-bottom: none; }
        tbody tr:hover td { background: var(--bg); }

        /* ── Badges ─────────────────────────────────────────────────────── */
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 600;
        }
        .badge-green  { background: #dcfce7; color: #166534; }
        .badge-blue   { background: #dbeafe; color: #1e40af; }
        .badge-purple { background: #ede9fe; color: #6d28d9; }
        .badge-amber  { background: #fef3c7; color: #92400e; }
        .badge-red    { background: #fee2e2; color: #991b1b; }
        .badge-gray   { background: #f1f5f9; color: #475569; }

        /* ── Grid Utilities ─────────────────────────────────────────────── */
        .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px; }
        @media (max-width: 900px) { .grid-2, .grid-3 { grid-template-columns: 1fr; } }

        /* ── Upload drag zone ───────────────────────────────────────────── */
        .drop-zone {
            border: 2px dashed var(--border);
            border-radius: 12px;
            padding: 28px;
            text-align: center;
            cursor: pointer;
            transition: all var(--transition);
            background: var(--bg);
        }
        .drop-zone:hover, .drop-zone.dragover {
            border-color: var(--primary);
            background: var(--primary-soft);
        }
        .drop-zone .icon { font-size: 32px; margin-bottom: 8px; }
        .drop-zone p { font-size: 13px; color: var(--text-muted); }
        .drop-zone strong { color: var(--primary); }

        /* ── Progress ───────────────────────────────────────────────────── */
        .progress-bar-wrap { background: var(--border); border-radius: 9999px; height: 8px; overflow: hidden; }
        .progress-bar { height: 100%; border-radius: 9999px; background: linear-gradient(90deg, var(--primary), var(--primary-dark)); transition: width .4s ease; }

        /* ── Rank badge ─────────────────────────────────────────────────── */
        .rank { width: 24px; height: 24px; border-radius: 50%; display: inline-flex; align-items:center; justify-content:center; font-size: 11px; font-weight: 700; }
        .rank-1 { background: #fef3c7; color: #d97706; }
        .rank-2 { background: #f1f5f9; color: #64748b; }
        .rank-3 { background: #fce7f3; color: #9d174d; }

        /* ── Mobile toggle ──────────────────────────────────────────────── */
        .sidebar-toggle {
            display: none;
            background: none;
            border: none;
            font-size: 22px;
            cursor: pointer;
            color: var(--text-muted);
            margin-right: 8px;
        }
        @media (max-width: 768px) {
            .sidebar { transform: translateX(-100%); }
            .sidebar.open { transform: translateX(0); }
            .main-content { margin-left: 0; }
            .sidebar-toggle { display: block; }
            .page-body { padding: 16px; }
        }

        /* ── Animations ─────────────────────────────────────────────────── */
        @keyframes fadeInUp {
            from { opacity: 0; transform: translateY(16px); }
            to   { opacity: 1; transform: translateY(0); }
        }
        .animate-in { animation: fadeInUp .35s ease both; }
        .delay-1 { animation-delay: .05s; }
        .delay-2 { animation-delay: .10s; }
        .delay-3 { animation-delay: .15s; }
        .delay-4 { animation-delay: .20s; }

        /* ── Inline icon text ───────────────────────────────────────────── */
        .flex-center { display: flex; align-items: center; gap: 8px; }
        .text-muted  { color: var(--text-muted); }
        .text-sm     { font-size: 12px; }
        .fw-700      { font-weight: 700; }
        .mb-0 { margin-bottom: 0 !important; }
    </style>
</head>
<body>

<!-- ── Sidebar ─────────────────────────────────────────────── -->
<aside class="sidebar" id="sidebar">
    <div class="sidebar-logo">
        <div class="logo-icon">
            <img src="../assets/logo.png" alt="Logo">
        </div>
        <div class="logo-text">Digi<span>Press</span></div>
    </div>

    <div class="sidebar-section-label">Main Menu</div>

    <a href="dashboard.php"
       class="nav-item <?= $activePage === 'dashboard' ? 'active' : '' ?>">
        <div class="nav-icon"><i class="fa-solid fa-gauge"></i></div>
        Dashboard
    </a>

    <a href="users.php"
       class="nav-item <?= $activePage === 'users' ? 'active' : '' ?>">
        <div class="nav-icon"><i class="fa-solid fa-users"></i></div>
        Total Users
    </a>

    <a href="publications.php"
       class="nav-item <?= $activePage === 'publications' ? 'active' : '' ?>">
        <div class="nav-icon"><i class="fa-solid fa-book-open"></i></div>
        Total Publications
    </a>

    <a href="new_publication.php"
       class="nav-item <?= $activePage === 'new_pub' ? 'active' : '' ?>">
        <div class="nav-icon"><i class="fa-solid fa-upload"></i></div>
        New Publication
        <span class="nav-badge">+</span>
    </a>

    <a href="pub_stats.php"
       class="nav-item <?= $activePage === 'pub_stats' ? 'active' : '' ?>">
        <div class="nav-icon"><i class="fa-solid fa-chart-bar"></i></div>
        Publication Stats
    </a>

    <a href="categories.php"
       class="nav-item <?= $activePage === 'categories' ? 'active' : '' ?>">
        <div class="nav-icon"><i class="fa-solid fa-tags"></i></div>
        Categories
    </a>

    <div class="sidebar-footer">
        <div class="admin-profile">
            <div class="admin-avatar"><?= strtoupper(substr($adminName, 0, 1)) ?></div>
            <div class="admin-info">
                <div class="name"><?= htmlspecialchars($adminName) ?></div>
                <div class="role">Administrator</div>
            </div>
            <a href="#" onclick="confirmLogout(event)" title="Logout"
               style="margin-left:auto; color:var(--accent3); font-size:14px; text-decoration:none;">
                <i class="fa-solid fa-right-from-bracket"></i>
            </a>
        </div>
    </div>
</aside>

<!-- ── Main ────────────────────────────────────────────────── -->
<div class="main-content">

    <!-- Topbar -->
    <header class="topbar">
        <button class="sidebar-toggle" onclick="document.getElementById('sidebar').classList.toggle('open')">
            <i class="fa-solid fa-bars"></i>
        </button>
        <div class="topbar-title">
            <?= htmlspecialchars($pageTitle) ?>
        </div>
        <div class="topbar-actions">
            <a href="new_publication.php" class="topbar-btn" title="New Publication">
                <i class="fa-solid fa-plus"></i>
            </a>
            <a href="#" onclick="confirmLogout(event)" class="topbar-btn" title="Logout">
                <i class="fa-solid fa-right-from-bracket"></i>
            </a>
            <div class="topbar-user">
                <div class="avatar"><?= strtoupper(substr($adminName, 0, 1)) ?></div>
                <?= htmlspecialchars($adminName) ?>
            </div>
        </div>
    </header>

    <!-- Page body starts here -->
    <div class="page-body">

<!-- ── Custom Logout Modal ────────────────────────────────────────────── -->
<div id="logoutModal" style="display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 9999; align-items: center; justify-content: center;">
    <div style="background: #fff; padding: 24px; border-radius: 12px; width: 100%; max-width: 320px; text-align: center; box-shadow: 0 4px 20px rgba(0,0,0,0.15);">
        <div style="font-size: 36px; color: #dc2626; margin-bottom: 12px;"><i class="fa-solid fa-right-from-bracket"></i></div>
        <h3 style="margin-bottom: 8px; font-size: 18px; font-weight: 700; color: #111;">Are you sure?</h3>
        <p style="margin-bottom: 24px; color: #64748b; font-size: 14px; line-height: 1.5;">Do you really want to log out of the admin panel?</p>
        <div style="display: flex; gap: 12px; justify-content: center;">
            <button onclick="document.getElementById('logoutModal').style.display='none'" style="flex:1; padding: 10px; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #fff; cursor: pointer; font-weight: 600; color: #475569; transition: all 0.2s;" onmouseover="this.style.background='#f8fafc'" onmouseout="this.style.background='#fff'">No</button>
            <button onclick="window.location.href='logout.php'" style="flex:1; padding: 10px; border-radius: 8px; border: none; background: #dc2626; cursor: pointer; font-weight: 600; color: #fff; transition: all 0.2s;" onmouseover="this.style.background='#b91c1c'" onmouseout="this.style.background='#dc2626'">Yes</button>
        </div>
    </div>
</div>

<script>
function confirmLogout(e) {
    e.preventDefault();
    document.getElementById('logoutModal').style.display = 'flex';
}
</script>
