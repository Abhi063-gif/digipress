<?php
/**
 * Admin Panel – Login page
 * Only admin email (a4abhi078@gmail.com) can log in.
 */
session_start();
require_once __DIR__ . '/../config/database.php';

// Already logged in?
if (isset($_SESSION['admin_id'])) {
    header('Location: dashboard.php');
    exit;
}

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email    = strtolower(trim($_POST['email'] ?? ''));
    $password = $_POST['password'] ?? '';

    if (!$email || !$password) {
        $error = 'Email and password are required.';
    } else {
        $db   = getDB();
        $stmt = $db->prepare('SELECT id, name, email, password_hash, role FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password_hash'])) {
            $error = 'Invalid email or password.';
        } else {
            // ── Re-enforce role from DB (check against ADMIN_EMAILS) ──────────────
            $isAdminEmail = in_array(strtolower($email), array_map('strtolower', ADMIN_EMAILS));
            $correctRole  = $isAdminEmail ? 'admin' : 'user';

            if ($user['role'] !== $correctRole) {
                $db->prepare('UPDATE users SET role = ? WHERE id = ?')
                   ->execute([$correctRole, $user['id']]);
                $user['role'] = $correctRole;
            }

            if ($user['role'] !== 'admin') {
                $error = 'Access denied. Admin privileges required.';
            } else {
                $_SESSION['admin_id']    = $user['id'];
                $_SESSION['admin_name']  = $user['name'];
                $_SESSION['admin_email'] = $user['email'];
                header('Location: dashboard.php');
                exit;
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DigiPress Admin – Login</title>
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; background: #f0f4ff; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .card { background: #fff; border-radius: 16px; padding: 40px 36px; width: 100%; max-width: 420px; box-shadow: 0 8px 32px rgba(0,0,0,.08); }
        .logo { width: 48px; height: 48px; background: #111; border-radius: 12px; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; color: #fff; font-size: 20px; }
        h1 { text-align: center; font-size: 22px; font-weight: 800; color: #111827; margin-bottom: 4px; }
        .subtitle { text-align: center; font-size: 13px; color: #6b7280; margin-bottom: 28px; }
        label { display: block; font-size: 12px; font-weight: 700; color: #6b7280; text-transform: uppercase; letter-spacing: .5px; margin-bottom: 6px; }
        input[type="email"], input[type="password"] { width: 100%; padding: 12px 14px; border: 1.5px solid #e5e7eb; border-radius: 10px; font-size: 14px; background: #f9fafb; outline: none; transition: border-color .15s; margin-bottom: 16px; }
        input:focus { border-color: #1d7fec; }
        .btn { width: 100%; padding: 13px; background: #1d7fec; color: #fff; border: none; border-radius: 12px; font-size: 15px; font-weight: 600; cursor: pointer; transition: background .2s; }
        .btn:hover { background: #1565c0; }
        .error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 10px 14px; border-radius: 8px; font-size: 13px; margin-bottom: 16px; }
    </style>
</head>
<body>
<div class="card">
    <div class="logo">📖</div>
    <h1>Admin Panel</h1>
    <p class="subtitle">DigiPress – College Publications Management</p>

    <?php if ($error): ?>
        <div class="error"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>

    <form method="POST" autocomplete="off">
        <label>Admin Email</label>
        <input type="email" name="email" placeholder="admin@gmail.com" required autocomplete="off" value="<?= htmlspecialchars($_POST['email'] ?? '') ?>">
        <label>Password</label>
        <div style="position: relative; margin-bottom: 16px;">
            <input type="password" id="password" name="password" placeholder="••••••••" required autocomplete="new-password" style="width: 100%; padding: 12px 14px; padding-right: 40px; border: 1.5px solid #e5e7eb; border-radius: 10px; font-size: 14px; background: #f9fafb; outline: none; transition: border-color .15s;">
            <button type="button" onclick="togglePassword()" style="position: absolute; right: 12px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; color: #6b7280; display: flex; align-items: center; justify-content: center;">
                <svg id="eye-icon" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                    <circle cx="12" cy="12" r="3"></circle>
                </svg>
            </button>
        </div>
        <button type="submit" class="btn">Sign In →</button>
    </form>
</div>

<script>
function togglePassword() {
    const pwd = document.getElementById('password');
    const eye = document.getElementById('eye-icon');
    if (pwd.type === 'password') {
        pwd.type = 'text';
        eye.innerHTML = '<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path><line x1="1" y1="1" x2="23" y2="23"></line>';
    } else {
        pwd.type = 'password';
        eye.innerHTML = '<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle>';
    }
}
</script>
</body>
</html>
