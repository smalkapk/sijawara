<?php
// /server/index.php
// Halaman login utama portal Sijawara
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Masuk - Portal Sijawara</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,400;0,14..32,500;0,14..32,600;0,14..32,700;0,14..32,800&display=swap" rel="stylesheet">
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        'green-forest': '#0D6E3B',
                        'green-primary': '#1B8A4A',
                        'green-light': '#E8F5EE',
                        'green-muted': '#4C8B65',
                    },
                    fontFamily: {
                        sans: ['Inter', 'system-ui', 'sans-serif'],
                    },
                }
            }
        }
    </script>
    <style>
        /* ─── Role tabs ──────────────────────────────────── */
        .role-tab { transition: color 0.3s ease; position: relative; z-index: 10; cursor: pointer; }
        .role-tab.active { color: #fff; }
        .role-tab:not(.active) { color: rgba(255,255,255,0.65); }
        .role-tab:not(.active):hover { color: #fff; }

        /* ─── Inputs ─────────────────────────────────────── */
        .field-input {
            background-color: rgba(255,255,255,0.12);
            border: 1px solid rgba(255,255,255,0.22);
            color: #fff;
            transition: border-color 0.2s, background-color 0.2s;
        }
        .field-input::placeholder { color: rgba(255,255,255,0.5); }
        .field-input:focus { outline: none; border-color: rgba(255,255,255,0.75); background-color: rgba(255,255,255,0.18); }
        .field-input.error { border-color: #fca5a5; }
        .error-text { color: #fca5a5; font-size: 0.75rem; margin-top: 4px; display: none; }
        .error-text.visible { display: block; }

        /* ─── Toast ──────────────────────────────────────── */
        #toast { transition: opacity 0.3s ease; }

        /* ══════════════════════════════════════════════════
           MOBILE layout: sticky hero image + slide-up form
           ══════════════════════════════════════════════════ */
        @media (max-width: 767px) {
            html, body { overflow-x: clip; }

            /* hero image sticks to top while form scrolls over it */
            .hero-panel {
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                height: 100vh;
                height: 100dvh; /* modern fallback */
                z-index: 0;
                overflow: hidden;
            }

            /* form sheet slides up over the hero */
            .form-panel {
                position: relative;
                z-index: 10;
                margin-top: calc(100vh - 2.5rem);
                margin-top: calc(100dvh - 2.5rem);          /* peek up over image */
                border-radius: 28px 28px 0 0;
                min-height: calc(100vh + 2.5rem);
                min-height: calc(100dvh + 2.5rem);
                background-color: #0D6E3B;
            }
        }

        /* ══════════════════════════════════════════════════
           DESKTOP layout: fixed split screen
           ══════════════════════════════════════════════════ */
        @media (min-width: 768px) {
            html, body { height: 100%; overflow: hidden; }

            .layout-root {
                display: flex;
                height: 100dvh;
                overflow: hidden;
            }

            .hero-panel {
                position: relative;
                flex: 1;
                height: 100%;
            }

            .form-panel {
                width: 480px;
                flex-shrink: 0;
                height: 100%;
                overflow-y: auto;
                background-color: #0D6E3B;
                display: flex;
                flex-direction: column;
                justify-content: center;
            }
        }
    </style>
</head>
<body class="bg-green-forest font-sans">

    <!-- Toast -->
    <div id="toast" class="fixed top-5 left-1/2 -translate-x-1/2 z-[9999] hidden opacity-0 pointer-events-none">
        <div id="toastContent" class="flex items-center gap-3 px-5 py-3 rounded-xl shadow-lg text-sm font-medium text-white"></div>
    </div>

    <!-- ══════════════════════════════════════════════════════════
         LAYOUT ROOT  (flex on desktop / block on mobile)
         ══════════════════════════════════════════════════════════ -->
    <div class="layout-root">

        <!-- ── LEFT / TOP: Hero image ─────────────────────────── -->
        <div class="hero-panel">
            
            <!-- Mobile Header Overlay (Text only if any, otherwise empty) -->
            <div class="absolute top-12 left-0 right-0 z-10 flex flex-col items-center justify-center md:hidden px-4 text-center pointer-events-none">
                <!-- Logo moved to form-panel -->
            </div>

            <img
                id="heroImage"
                src="assets/login.webp"
                alt="Sijawara"
                class="w-full h-full object-cover origin-center"
                style="object-position: center 25%; transform: scale(1.1); transition: transform 0.1s ease-out;"
                loading="eager">

            <!-- Mobile swipe hint arrow -->
            <div id="swipeHint" class="absolute bottom-28 left-0 right-0 flex flex-col items-center justify-center md:hidden pointer-events-none transition-opacity duration-200">
                <p class="text-white/90 text-sm font-medium mb-2 drop-shadow-md animate-pulse">Geser ke atas untuk masuk</p>
                <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-white/80 animate-bounce drop-shadow-md" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7"/>
                </svg>
            </div>
        </div>

        <!-- ── RIGHT / BOTTOM: Form panel ─────────────────────── -->
        <div class="form-panel relative">
            
            <!-- Mobile Overlapping Logo -->
            <div class="absolute left-1/2 -translate-x-1/2 -top-16 z-20 md:hidden pointer-events-none">
                <div class="w-32 h-32 bg-white rounded-full border-4 border-green-forest flex items-center justify-center overflow-hidden shadow-2xl p-1">
                    <img src="assets/logosmalka.png" alt="Logo SMALKA" class="w-full h-full object-cover rounded-full">
                </div>
            </div>

            <!-- Mobile drag handle -->
            <div class="flex justify-center pt-5 pb-1 md:hidden mt-12">
                <div class="w-10 h-1.5 rounded-full bg-white/30"></div>
            </div>

            <!-- Form content -->
            <div class="px-7 py-4 md:py-0 md:px-12 w-full max-w-sm mx-auto">

                <!-- Header (desktop only — mobile uses hero overlay) -->
                <div class="mb-7 hidden md:block">
                    <div class="w-20 h-20 bg-white rounded-full border-2 border-white/20 mb-4 flex items-center justify-center p-1 overflow-hidden shadow-sm">
                        <img src="assets/logosmalka.png" alt="Logo SMALKA" class="w-full h-full object-cover rounded-full">
                    </div>
                    <h1 class="text-3xl font-extrabold text-white tracking-tight">Assalamualaikum</h1>
                    <p class="text-xl font-bold text-white mt-0.5">Selamat Datang</p>
                    <p class="text-sm text-white/60 mt-2">Masuk ke akun Anda untuk melanjutkan</p>
                </div>

                <!-- Header (mobile) -->
                <div class="mt-8 mb-6 md:hidden text-center">
                    <h1 class="text-2xl font-extrabold text-white tracking-tight">Assalamualaikum</h1>
                    <p class="text-white/60 text-sm mt-1">Masuk ke akun Anda untuk melanjutkan</p>
                </div>

                <!-- Role Tabs with sliding background -->
                <div class="relative flex bg-white/10 rounded-xl p-1 mb-5 overflow-hidden text-[11px] sm:text-xs">
                    <!-- The sliding active pill background -->
                    <div id="tabIndicator" class="absolute top-1 bottom-1 left-1 bg-green-forest rounded-lg transition-transform duration-300 ease-out shadow-sm" style="width: calc(25% - 0.5rem); transform: translateX(0);"></div>
                    
                    <button type="button"
                        class="role-tab active flex-1 flex flex-col items-center justify-center gap-1.5 py-2 px-1 sm:py-3 rounded-lg font-semibold"
                        data-role="siswa" onclick="selectTab(this, 0)">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 sm:w-5 sm:h-5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 14l9-5-9-5-9 5 9 5z"/>
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/>
                        </svg>
                        <span class="whitespace-nowrap">Siswa</span>
                    </button>
                    <button type="button"
                        class="role-tab flex-1 flex flex-col items-center justify-center gap-1.5 py-2 px-1 sm:py-3 rounded-lg font-semibold"
                        data-role="orang_tua" onclick="selectTab(this, 1)">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 sm:w-5 sm:h-5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"/>
                        </svg>
                        <span class="text-center leading-tight sm:whitespace-nowrap">Wali</span>
                    </button>
                    <button type="button"
                        class="role-tab flex-1 flex flex-col items-center justify-center gap-1.5 py-2 px-1 sm:py-3 rounded-lg font-semibold"
                        data-role="guru" onclick="selectTab(this, 2)">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 sm:w-5 sm:h-5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                        </svg>
                        <span class="whitespace-nowrap">Guru</span>
                    </button>
                    <button type="button"
                        class="role-tab flex-1 flex flex-col items-center justify-center gap-1.5 py-2 px-1 sm:py-3 rounded-lg font-semibold"
                        data-role="admin" onclick="selectTab(this, 3)">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 sm:w-5 sm:h-5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                        </svg>
                        <span class="whitespace-nowrap">Admin</span>
                    </button>
                </div>

                <!-- Form -->
                <form id="loginForm" onsubmit="handleLogin(event)" novalidate>

                    <!-- Email -->
                    <div class="mb-3">
                        <div class="relative">
                            <span class="absolute inset-y-0 left-3.5 flex items-center pointer-events-none">
                                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-white/55" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                                </svg>
                            </span>
                            <input id="emailInput" type="text" autocomplete="username"
                                class="field-input w-full pl-11 pr-4 py-3.5 rounded-xl text-sm"
                                placeholder="Email atau NIS">
                        </div>
                        <p id="emailError" class="error-text">Email tidak boleh kosong</p>
                    </div>

                    <!-- Password -->
                    <div class="mb-6">
                        <div class="relative">
                            <span class="absolute inset-y-0 left-3.5 flex items-center pointer-events-none">
                                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-white/55" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                                </svg>
                            </span>
                            <input id="passwordInput" type="password" autocomplete="current-password"
                                class="field-input w-full pl-11 pr-12 py-3.5 rounded-xl text-sm"
                                placeholder="Kata Sandi">
                            <button type="button" onclick="togglePassword()"
                                class="absolute inset-y-0 right-3.5 flex items-center text-white/55 hover:text-white transition-colors">
                                <svg id="eyeIcon" xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                                </svg>
                                <svg id="eyeOffIcon" xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 hidden" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>
                                </svg>
                            </button>
                        </div>
                        <p id="passwordError" class="error-text">Kata sandi tidak boleh kosong</p>
                    </div>

                    <!-- Submit -->
                    <button id="submitBtn" type="submit"
                        class="w-full bg-white text-green-forest font-semibold py-3.5 rounded-xl text-sm hover:bg-green-light active:scale-[0.98] transition-all shadow-md disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2">
                        <span id="btnText">Masuk sebagai Siswa</span>
                        <svg id="btnSpinner" xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 animate-spin hidden" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                        </svg>
                    </button>

                </form>

                <!-- Footer note -->
                <p class="text-center text-xs text-white/50 mt-5 leading-relaxed">
                    <span class="text-white/80 font-semibold">Belum mempunyai akun?</span><br>
                    Silahkan menghubungi admin untuk membantu Anda
                </p>

                <!-- Mobile copyright -->
                <p class="text-center text-white/20 text-xs mt-8 md:hidden">© <?= date('Y') ?> Sijawara · SMA Muhammadiyah Al Kautsar Program Khusus</p>

            </div><!-- /form content -->
        </div><!-- /form-panel -->

    </div><!-- /layout-root -->

    <script>
        // ─── Role Tab Logic ───────────────────────────────────────────────
        const rolePlaceholders = {
            siswa:     'Email atau NIS',
            orang_tua: 'Email atau No. HP',
            guru:      'Email Guru',
            admin:     'Username atau Email',
        };
        const roleLabels = {
            siswa:     'Siswa',
            orang_tua: 'Orang Tua/Wali',
            guru:      'Guru',
            admin:     'Admin',
        };
        let currentRole = 'siswa';

        function selectTab(el, index) {
            // Update active text colors
            document.querySelectorAll('.role-tab').forEach(t => t.classList.remove('active'));
            el.classList.add('active');
            
            // Move the background pill
            const indicator = document.getElementById('tabIndicator');
            // Since there are 4 tabs now, and no gap in the flex container, width is 25% of pure container width minus padding.
            // Padding of container is 4px (p-1) on each side -> 8px total. Wait, flex items will just take 25% width each.
            // If width of indicator is `calc(25% - 0.5rem)` (which is 8px smaller than the 25%),
            // then we translate it by `calc(index * 100%)` relative to its own size? No, `translateX` uses the element's own width.
            // A safer, more robust way: Use offsetLeft!
            indicator.style.transform = `translateX(${el.offsetLeft - 4}px)`; // 4px is to account for left-1 in absolute positioning

            currentRole = el.dataset.role;
            document.getElementById('emailInput').placeholder = rolePlaceholders[currentRole];
            document.getElementById('btnText').textContent = 'Masuk sebagai ' + roleLabels[currentRole];
            // Clear errors on tab change
            clearErrors();
        }

        // ─── Password Toggle ─────────────────────────────────────────────
        function togglePassword() {
            const input = document.getElementById('passwordInput');
            const eye   = document.getElementById('eyeIcon');
            const eyeOff= document.getElementById('eyeOffIcon');
            if (input.type === 'password') {
                input.type = 'text';
                eye.classList.add('hidden');
                eyeOff.classList.remove('hidden');
            } else {
                input.type = 'password';
                eye.classList.remove('hidden');
                eyeOff.classList.add('hidden');
            }
        }

        // ─── Validation helpers ───────────────────────────────────────────
        function clearErrors() {
            ['emailInput','passwordInput'].forEach(id => {
                document.getElementById(id).classList.remove('error');
            });
            document.getElementById('emailError').classList.remove('visible');
            document.getElementById('passwordError').classList.remove('visible');
        }

        function showError(inputId, errorId, msg) {
            const inp = document.getElementById(inputId);
            const err = document.getElementById(errorId);
            inp.classList.add('error');
            err.textContent = msg;
            err.classList.add('visible');
        }

        // ─── Toast ────────────────────────────────────────────────────────
        function showToast(message, isError = true) {
            const toast   = document.getElementById('toast');
            const content = document.getElementById('toastContent');
            content.className = `flex items-center gap-3 px-5 py-3 rounded-xl shadow-lg text-sm font-medium text-white ${isError ? 'bg-red-500' : 'bg-green-primary'}`;
            content.textContent = message;
            toast.classList.remove('hidden', 'opacity-0', 'pointer-events-none');
            setTimeout(() => {
                toast.classList.add('opacity-0');
                setTimeout(() => toast.classList.add('hidden', 'pointer-events-none'), 300);
            }, 4000);
        }

        // ─── Login Handler ────────────────────────────────────────────────
        async function handleLogin(e) {
            e.preventDefault();
            clearErrors();

            const email    = document.getElementById('emailInput').value.trim();
            const password = document.getElementById('passwordInput').value;
            let valid = true;

            if (!email) {
                showError('emailInput', 'emailError', 'Email tidak boleh kosong');
                valid = false;
            }
            if (!password) {
                showError('passwordInput', 'passwordError', 'Kata sandi tidak boleh kosong');
                valid = false;
            } else if (password.length < 6) {
                showError('passwordInput', 'passwordError', 'Kata sandi minimal 6 karakter');
                valid = false;
            }
            if (!valid) return;

            // Loading state
            const btn     = document.getElementById('submitBtn');
            const btnText = document.getElementById('btnText');
            const spinner = document.getElementById('btnSpinner');
            btn.disabled = true;
            spinner.classList.remove('hidden');

            try {
                const res  = await fetch('api/login.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password, role_tab: currentRole }),
                });
                const data = await res.json();

                if (!res.ok || !data.success) {
                    throw new Error(data.message || 'Login gagal. Periksa kembali data Anda.');
                }

                // Redirect based on role returned from server
                const role = data.data?.role ?? '';
                showToast('Login berhasil! Mengalihkan...', false);

                // Store web session for portal access
                try {
                    await fetch('config/web/siswa_auth.php', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            action: 'login',
                            user_id: data.data.user_id,
                            token: data.data.token,
                            name: data.data.name,
                            role: data.data.role,
                            avatar_url: data.data.avatar_url || '',
                            email: data.data.email || '',
                        }),
                    });
                } catch (e) { /* ignore session error */ }

                let redirect = 'web/siswa/';
                if      (role === 'siswa')        redirect = 'web/siswa/';
                else if (role === 'orang_tua')    redirect = 'web/wali/';
                else if (role === 'guru_kelas')   redirect = 'web/guru/';
                else if (role === 'guru_tahfidz') redirect = 'web/tahfidz/';
                else if (role === 'admin')        redirect = 'web/admin/';

                setTimeout(() => { window.location.href = redirect; }, 800);

            } catch (err) {
                showToast(err.message || 'Terjadi kesalahan. Periksa koneksi internet Anda.');
            } finally {
                btn.disabled = false;
                spinner.classList.add('hidden');
            }
        }

        // ─── Parallax on Mobile ───────────────────────────────────────────
        window.addEventListener('scroll', () => {
            if (window.innerWidth < 768) {
                const scrollY = window.scrollY;
                const heroImg = document.getElementById('heroImage');
                const swipeHint = document.getElementById('swipeHint');
                
                if (heroImg) {
                    // Start zoomed in at 1.1, slowly return to 1.0 (zoom out) when user scrolls
                    let scale = 1.1 - (scrollY * 0.0003);
                    if (scale < 1) scale = 1;
                    heroImg.style.transform = `scale(${scale})`;
                }
                
                if (swipeHint) {
                    // Fade out the upward swipe hint
                    let opacity = 1 - (scrollY * 0.005);
                    if (opacity < 0) opacity = 0;
                    swipeHint.style.opacity = opacity;
                }
            }
        });

    </script>
</body>
</html>