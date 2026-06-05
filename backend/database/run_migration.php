<?php
/**
 * Migration runner — visit this once in browser:
 * http://localhost/clg_magzine/database/run_migration.php
 * Then DELETE this file for security.
 */
require_once __DIR__ . '/../config/database.php';

$db     = getDB();
$done   = [];
$errors = [];

// ── Step 1: Run the main SQL file ─────────────────────────────────────
$sql = file_get_contents(__DIR__ . '/migration_admin.sql');
$statements = array_filter(array_map('trim', explode(';', $sql)));

foreach ($statements as $stmt) {
    if (!$stmt || preg_match('/^\s*--/', $stmt) || preg_match('/^\s*USE\s/i', $stmt)) continue;
    try {
        $db->exec($stmt);
        $done[] = substr($stmt, 0, 90) . '…';
    } catch (PDOException $e) {
        $errors[] = $e->getMessage() . ' → ' . substr($stmt, 0, 80);
    }
}

// ── Step 2: Add columns to categories if they don't exist ────────────
function addColumnIfMissing(PDO $db, string $table, string $col, string $definition, array &$done, array &$errors): void {
    $check = $db->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?"
    );
    $check->execute([$table, $col]);
    if ((int)$check->fetchColumn() === 0) {
        try {
            $db->exec("ALTER TABLE `$table` ADD COLUMN `$col` $definition");
            $done[] = "Added column $table.$col";
        } catch (PDOException $e) {
            $errors[] = "ALTER $table.$col: " . $e->getMessage();
        }
    } else {
        $done[] = "Column $table.$col already exists – skipped";
    }
}

addColumnIfMissing($db, 'categories',   'icon',           "VARCHAR(10) DEFAULT '📁'",  $done, $errors);
addColumnIfMissing($db, 'categories',   'color',          "VARCHAR(20) DEFAULT '#6366f1'", $done, $errors);
addColumnIfMissing($db, 'publications', 'download_count', 'INT DEFAULT 0',             $done, $errors);
addColumnIfMissing($db, 'publications', 'view_count',     'INT DEFAULT 0',             $done, $errors);
addColumnIfMissing($db, 'publications', 'share_count',    'INT DEFAULT 0',             $done, $errors);

// ── Step 3: Fix admin password (re-hash with current PHP) ─────────────
try {
    $hash = password_hash('Abhi@123', PASSWORD_BCRYPT);
    $upd  = $db->prepare("UPDATE users SET password_hash = ?, role = 'admin', email_verified = 1 WHERE email = ?");
    $upd->execute([$hash, 'a4abhi078@gmail.com']);
    if ($upd->rowCount() > 0) {
        $done[] = "Admin password reset for a4abhi078@gmail.com (Abhi@123)";
    } else {
        // Insert if not exists
        $ins = $db->prepare("INSERT IGNORE INTO users (name, email, password_hash, role, email_verified) VALUES (?,?,?,?,1)");
        $ins->execute(['Admin', 'a4abhi078@gmail.com', $hash, 'admin']);
        $done[] = "Admin user created: a4abhi078@gmail.com";
    }
} catch (PDOException $e) {
    $errors[] = "Admin fix: " . $e->getMessage();
}

?>
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>Migration Runner – DigiPress</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0f172a; color: #e2e8f0; padding: 32px; }
  h2 { color: #22c55e; font-size: 22px; margin-bottom: 4px; }
  .subtitle { color: #64748b; font-size: 13px; margin-bottom: 24px; }
  .card { background: #1e293b; border-radius: 12px; padding: 20px; margin-bottom: 16px; border: 1px solid #334155; }
  .ok  { color: #22c55e; font-size: 13px; font-family: monospace; padding: 3px 0; }
  .err { color: #ef4444; font-size: 13px; font-family: monospace; padding: 3px 0; background: rgba(239,68,68,.1); padding: 6px 10px; border-radius: 6px; margin: 4px 0; }
  .warn { background: rgba(245,158,11,.1); border: 1px solid #f59e0b; padding: 14px 18px; border-radius: 10px; margin-top: 16px; color: #f59e0b; }
  .go { display: inline-block; margin-top: 16px; background: #22c55e; color: #fff; padding: 12px 24px; border-radius: 10px; text-decoration: none; font-weight: 700; font-size: 14px; }
  .count { color: #94a3b8; font-size: 14px; margin-bottom: 12px; }
</style>
</head><body>
<h2>✅ DigiPress Admin Migration</h2>
<p class="subtitle">Database setup for the new admin panel features</p>

<div class="card">
    <p class="count">✓ <?= count($done) ?> statement(s) succeeded &nbsp;|&nbsp; ✗ <?= count($errors) ?> error(s)</p>
    <?php foreach ($done as $d): ?>
        <div class="ok">✓ <?= htmlspecialchars($d) ?></div>
    <?php endforeach; ?>
    <?php foreach ($errors as $e): ?>
        <div class="err">✗ <?= htmlspecialchars($e) ?></div>
    <?php endforeach; ?>
</div>

<?php if (!empty($errors)): ?>
<div class="warn">
    ⚠️ Some statements failed. If they say "Table already exists" or "Duplicate column" that's usually fine.<br>
    Check the actual errors above for real issues.
</div>
<?php else: ?>
<div style="background:rgba(34,197,94,.1);border:1px solid #22c55e;padding:14px 18px;border-radius:10px;color:#22c55e;margin-top:16px;">
    🎉 All migrations completed successfully!
</div>
<?php endif; ?>

<div class="warn" style="margin-top:16px;">
    ⚠️ <strong>Security reminder:</strong> Delete this file after running!<br>
    <code style="font-size:12px;opacity:.8;"><?= __FILE__ ?></code>
</div>

<a href="/clg_magzine/admin/dashboard.php" class="go">→ Go to Admin Dashboard</a>
</body></html>
