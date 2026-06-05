    </div><!-- /page-body -->
</div><!-- /main-content -->

<script>
// Sidebar overlay on mobile
document.addEventListener('click', function(e) {
    var sidebar = document.getElementById('sidebar');
    if (window.innerWidth <= 768 && sidebar.classList.contains('open')) {
        if (!sidebar.contains(e.target) && !e.target.closest('.sidebar-toggle')) {
            sidebar.classList.remove('open');
        }
    }
});

// Auto-dismiss alerts
document.querySelectorAll('.alert').forEach(function(el) {
    setTimeout(function() {
        el.style.transition = 'opacity .5s';
        el.style.opacity = '0';
        setTimeout(function() { el.remove(); }, 500);
    }, 4000);
});
</script>
</body>
</html>
