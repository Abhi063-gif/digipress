<?php
/**
 * Admin Panel – Categories (Dynamic CRUD)
 * Changes here replicate to the Flutter app via /api/categories/list.php
 */
session_start();
require_once __DIR__ . '/../config/database.php';
if (!isset($_SESSION['admin_id'])) { header('Location: index.php'); exit; }

$db  = getDB();
$msg = '';
$err = '';

// ── Handle POST ─────────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    if ($action === 'add_category') {
        $name  = trim($_POST['category_name'] ?? '');
        $icon  = trim($_POST['category_icon']  ?? '📁');
        $color = trim($_POST['category_color'] ?? '#6366f1');

        if (!$name) {
            $err = 'Category name is required.';
        } else {
            $exists = $db->prepare('SELECT id FROM categories WHERE name = ?');
            $exists->execute([$name]);
            if ($exists->fetch()) {
                $err = 'Category already exists.';
            } else {
                $db->prepare('INSERT INTO categories (name, icon, color) VALUES (?, ?, ?)')
                   ->execute([$name, $icon, $color]);
                $msg = "Category \"$name\" added successfully. It's now visible in the Flutter app.";
            }
        }

    } elseif ($action === 'edit_category') {
        $id    = (int)($_POST['cat_id'] ?? 0);
        $name  = trim($_POST['category_name'] ?? '');
        $icon  = trim($_POST['category_icon']  ?? '📁');
        $color = trim($_POST['category_color'] ?? '#6366f1');

        if (!$id || !$name) {
            $err = 'ID and name are required.';
        } else {
            // Check duplicate
            $dup = $db->prepare('SELECT id FROM categories WHERE name = ? AND id != ?');
            $dup->execute([$name, $id]);
            if ($dup->fetch()) {
                $err = 'Another category with that name already exists.';
            } else {
                $db->prepare('UPDATE categories SET name=?, icon=?, color=? WHERE id=?')
                   ->execute([$name, $icon, $color, $id]);
                $msg = "Category updated successfully.";
            }
        }

    } elseif ($action === 'delete_category') {
        $id = (int)($_POST['cat_id'] ?? 0);
        // Check if any publications use it
        $inUse = $db->prepare('SELECT COUNT(*) FROM publications WHERE category_id = ?');
        $inUse->execute([$id]);
        if ((int)$inUse->fetchColumn() > 0) {
            $err = 'Cannot delete: this category has publications attached. Reassign them first.';
        } else {
            $db->prepare('DELETE FROM categories WHERE id = ?')->execute([$id]);
            $msg = 'Category deleted.';
        }
    }
}

// ── Fetch ────────────────────────────────────────────────────────────────
$categories = $db->query(
    'SELECT c.*, COUNT(p.id) AS pub_count
     FROM categories c
     LEFT JOIN publications p ON p.category_id = c.id
     GROUP BY c.id
     ORDER BY c.name'
)->fetchAll();

$pageTitle  = 'Categories';
$activePage = 'categories';

// Preset emoji icons
$iconOptions = ['📚','📖','📰','📝','🗞️','🎓','🔬','💼','📋','🏆','🌟','📢','📣','📌','🖊️'];
$colorOptions = ['#6366f1','#22c55e','#f59e0b','#ef4444','#06b6d4','#8b5cf6','#ec4899','#14b8a6','#f97316','#0ea5e9'];
?>
<?php include __DIR__ . '/includes/header.php'; ?>

<?php if ($msg): ?><div class="alert alert-success"><i class="fa-solid fa-check-circle"></i> <?= htmlspecialchars($msg) ?></div><?php endif; ?>
<?php if ($err): ?><div class="alert alert-error"><i class="fa-solid fa-triangle-exclamation"></i> <?= htmlspecialchars($err) ?></div><?php endif; ?>

<div class="grid-2" style="align-items:start;">

    <!-- Add Category Form -->
    <div class="card animate-in">
        <div class="card-header">
            <div>
                <div class="card-title">Add New Category</div>
                <div class="card-subtitle">Categories appear dynamically in the Flutter app</div>
            </div>
        </div>

        <form method="POST" id="addCatForm">
            <input type="hidden" name="action" value="add_category">

            <div class="form-group">
                <label class="form-label">Category Name *</label>
                <input type="text" name="category_name" class="form-control"
                       placeholder="e.g. Annual Magazine" required
                       value="<?= htmlspecialchars($_POST['category_name'] ?? '') ?>">
            </div>

            <div class="form-group">
                <label class="form-label">Icon (emoji)</label>
                <div style="display:flex; gap:8px; flex-wrap:wrap; margin-bottom:10px;" id="iconPicker">
                    <?php foreach ($iconOptions as $ic): ?>
                        <button type="button" class="icon-opt"
                                onclick="selectIcon('<?= $ic ?>')"
                                style="width:38px;height:38px;border-radius:8px;border:2px solid var(--border);
                                       background:var(--bg);font-size:18px;cursor:pointer;transition:all .15s;">
                            <?= $ic ?>
                        </button>
                    <?php endforeach; ?>
                </div>
                <input type="text" name="category_icon" id="iconInput" class="form-control"
                       value="📁" placeholder="Or type an emoji" maxlength="4">
            </div>

            <div class="form-group">
                <label class="form-label">Color</label>
                <div style="display:flex; gap:8px; flex-wrap:wrap; margin-bottom:10px;">
                    <?php foreach ($colorOptions as $col): ?>
                        <button type="button" onclick="selectColor('<?= $col ?>')"
                                style="width:28px;height:28px;border-radius:50%;background:<?= $col ?>;
                                       border:2px solid transparent;cursor:pointer;transition:transform .15s;"
                                class="color-swatch">
                        </button>
                    <?php endforeach; ?>
                </div>
                <input type="color" name="category_color" id="colorInput" class="form-control"
                       value="#6366f1" style="height:42px;padding:4px;">
            </div>

            <button type="submit" class="btn btn-primary" style="width:100%;">
                <i class="fa-solid fa-plus"></i> Add Category
            </button>
        </form>
    </div>

    <!-- Category List -->
    <div style="display:flex;flex-direction:column;gap:16px;">
        <div class="card animate-in delay-1">
            <div class="card-header">
                <div class="card-title">All Categories <span class="badge badge-gray"><?= count($categories) ?></span></div>
                <div class="card-subtitle">Click edit to modify. Changes sync to app immediately.</div>
            </div>

            <?php if (empty($categories)): ?>
                <p class="text-muted text-sm">No categories yet.</p>
            <?php else: ?>
            <div style="display:flex;flex-direction:column;gap:10px;">
            <?php foreach ($categories as $cat): ?>
                <div class="cat-row" style="display:flex;align-items:center;gap:12px;padding:12px;
                     border-radius:10px;border:1px solid var(--border);background:var(--bg);
                     transition:all .2s;" onmouseover="this.style.borderColor='var(--primary)'"
                     onmouseout="this.style.borderColor='var(--border)'">
                    <!-- Icon circle -->
                    <div style="width:44px;height:44px;border-radius:12px;flex-shrink:0;
                                background:<?= htmlspecialchars($cat['color'] ?? '#6366f1') ?>22;
                                display:flex;align-items:center;justify-content:center;
                                font-size:20px;">
                        <?= htmlspecialchars($cat['icon'] ?? '📁') ?>
                    </div>
                    <!-- Info -->
                    <div style="flex:1;min-width:0;">
                        <div style="font-weight:700;font-size:14px;"><?= htmlspecialchars($cat['name']) ?></div>
                        <div class="text-muted text-sm">
                            <?= $cat['pub_count'] ?> publication<?= $cat['pub_count'] != 1 ? 's' : '' ?> ·
                            Added <?= date('M Y', strtotime($cat['created_at'])) ?>
                        </div>
                    </div>
                    <!-- Color dot -->
                    <div style="width:12px;height:12px;border-radius:50%;
                                background:<?= htmlspecialchars($cat['color'] ?? '#6366f1') ?>;flex-shrink:0;">
                    </div>
                    <!-- Actions -->
                    <div style="display:flex;gap:6px;flex-shrink:0;">
                        <button type="button" class="btn btn-outline btn-sm"
                                onclick="openEdit(<?= $cat['id'] ?>, '<?= addslashes(htmlspecialchars($cat['name'])) ?>', '<?= addslashes($cat['icon'] ?? '📁') ?>', '<?= $cat['color'] ?? '#6366f1' ?>')">
                            <i class="fa-solid fa-pen"></i>
                        </button>
                        <?php if ($cat['pub_count'] == 0): ?>
                        <form method="POST" onsubmit="return confirm('Delete category \'<?= addslashes($cat['name']) ?>\'?')">
                            <input type="hidden" name="action" value="delete_category">
                            <input type="hidden" name="cat_id" value="<?= $cat['id'] ?>">
                            <button type="submit" class="btn btn-danger btn-sm">
                                <i class="fa-solid fa-trash"></i>
                            </button>
                        </form>
                        <?php else: ?>
                        <button type="button" class="btn btn-sm"
                                style="background:var(--border);color:var(--text-muted);cursor:not-allowed;"
                                title="Category has publications – cannot delete">
                            <i class="fa-solid fa-lock"></i>
                        </button>
                        <?php endif; ?>
                    </div>
                </div>
            <?php endforeach; ?>
            </div>
            <?php endif; ?>
        </div>
    </div>
</div>

<!-- ── Edit Modal ──────────────────────────────────────────────────── -->
<div id="editModal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,.4);
     z-index:1000;align-items:center;justify-content:center;backdrop-filter:blur(4px);"
     onclick="if(event.target===this) closeModal()">
    <div style="background:var(--card-bg);border-radius:16px;padding:28px;width:440px;max-width:90vw;
                box-shadow:0 20px 60px rgba(0,0,0,.2);animation:fadeInUp .25s ease;">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
            <div style="font-size:17px;font-weight:700;">Edit Category</div>
            <button onclick="closeModal()" style="background:none;border:none;font-size:20px;cursor:pointer;color:var(--text-muted);">✕</button>
        </div>
        <form method="POST">
            <input type="hidden" name="action" value="edit_category">
            <input type="hidden" name="cat_id" id="editCatId">

            <div class="form-group">
                <label class="form-label">Category Name *</label>
                <input type="text" name="category_name" id="editCatName" class="form-control" required>
            </div>
            <div class="form-group">
                <label class="form-label">Icon</label>
                <input type="text" name="category_icon" id="editCatIcon" class="form-control" maxlength="4">
            </div>
            <div class="form-group">
                <label class="form-label">Color</label>
                <input type="color" name="category_color" id="editCatColor" class="form-control" style="height:42px;padding:4px;">
            </div>
            <div style="display:flex;gap:10px;margin-top:4px;">
                <button type="button" onclick="closeModal()" class="btn btn-outline" style="flex:1;">Cancel</button>
                <button type="submit" class="btn btn-primary" style="flex:2;">
                    <i class="fa-solid fa-check"></i> Save Changes
                </button>
            </div>
        </form>
    </div>
</div>

<script>
// Icon picker
function selectIcon(ic) {
    document.getElementById('iconInput').value = ic;
    document.querySelectorAll('.icon-opt').forEach(b => b.style.borderColor = 'var(--border)');
    event.currentTarget.style.borderColor = 'var(--primary)';
}
function selectColor(col) {
    document.getElementById('colorInput').value = col;
    document.querySelectorAll('.color-swatch').forEach(b => b.style.border = '2px solid transparent');
    event.currentTarget.style.border = '2px solid var(--text)';
}

// Modal
const modal = document.getElementById('editModal');
function openEdit(id, name, icon, color) {
    document.getElementById('editCatId').value    = id;
    document.getElementById('editCatName').value  = name;
    document.getElementById('editCatIcon').value  = icon;
    document.getElementById('editCatColor').value = color;
    modal.style.display = 'flex';
}
function closeModal() { modal.style.display = 'none'; }
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModal(); });
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>
