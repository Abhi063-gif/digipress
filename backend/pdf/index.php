<?php
// /pdf/index.php
// This script serves as a fallback for deep links.
// If the app is not installed, Android will open this URL in the browser.
// We display a short message and redirect to the Play Store.

$id = htmlspecialchars($_GET['id'] ?? '');
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Opening DigiPress...</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background-color: #f8fafc;
            color: #0f172a;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
        }
        .loader {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #1d4ed8;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 1.5rem auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        h1 {
            font-size: 1.5rem;
            margin-bottom: 0.5rem;
        }
        p {
            color: #64748b;
        }
        .btn {
            display: inline-block;
            margin-top: 1.5rem;
            padding: 0.75rem 1.5rem;
            background-color: #1d4ed8;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="loader"></div>
        <h1>Opening DigiPress...</h1>
        <p>If the app does not open automatically, please install it.</p>
        <a href="https://play.google.com/store/apps/details?id=com.dav.digipress" class="btn">Get it on Google Play</a>
    </div>

    <script>
        // Attempt to redirect to the Play Store after a short delay
        // (in case the browser didn't natively handle the App Link)
        setTimeout(function() {
            window.location.href = 'https://play.google.com/store/apps/details?id=com.dav.digipress';
        }, 2500);
    </script>
</body>
</html>
