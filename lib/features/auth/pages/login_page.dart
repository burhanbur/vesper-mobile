import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/security/local_data_failure.dart';
import '../../../core/utils/string_formatter.dart';
import '../data/auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _authRepository = AuthRepository();

  // Login Controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  // Register Controllers
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _regObscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() => _authenticate();

  Future<void> _handleRegister() => _authenticate(register: true);

  Future<void> _authenticate({bool register = false}) async {
    if (_isLoading) return;
    final email = (register ? _regEmailController : _loginEmailController).text
        .trim();
    final password =
        (register ? _regPasswordController : _loginPasswordController).text;
    final rawName = register ? _regNameController.text.trim() : null;
    final name = rawName != null
        ? StringFormatter.capitalizeWords(rawName)
        : null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        password.isEmpty ||
        password.length > 128 ||
        (register &&
            (password.length < 8 || name!.length < 2 || name.length > 120))) {
      _showError(
        'Masukkan email dan kata sandi yang valid. Untuk mendaftar, nama harus 2–120 karakter dan kata sandi minimal 8 karakter.',
      );
      return;
    }
    final state = AppStateScope.of(context);
    setState(() => _isLoading = true);
    try {
      final user = await _authRepository.authenticate(
        email: email,
        password: password,
        name: name,
        rememberMe: register || _rememberMe,
      );
      if (!mounted) return;
      _loginPasswordController.clear();
      _regPasswordController.clear();
      // Open the authenticated user's local cache before loading server data.
      await state.login(userId: user.id, name: user.name, email: user.email);
    } on ApiFailure catch (error) {
      if (mounted) _showError(error.message);
    } on LocalDataFailure catch (error) {
      if (mounted) _showError(error.toString());
    } catch (_) {
      if (mounted) _showError('Sesi tidak dapat disimpan. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storageError = context
        .dependOnInheritedWidgetOfExactType<AppStateScope>()
        ?.notifier
        ?.localStorageError;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Brand & Logo Header
              _buildBrandHeader(),
              const SizedBox(height: 24),

              if (storageError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(liveRegion: true, child: Text(storageError)),
                ),

              // Segmented Tab Bar (Masuk / Daftar)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: EdgeInsets.zero,
                  splashBorderRadius: BorderRadius.circular(12),
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Masuk'),
                    Tab(text: 'Daftar'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab View Content
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return _tabController.index == 0
                      ? _buildLoginSection()
                      : _buildRegisterSection();
                },
              ),

              const SizedBox(height: 16),

              // Explore Onboarding / Intro link
              Center(
                child: TextButton.icon(
                  onPressed: () => AppStateScope.of(context).showOnboarding(),
                  icon: const Icon(
                    Icons.auto_stories_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    '✦ Lihat Panduan & Pengenalan Fitur Vesper',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              AppAssets.logoBg,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.account_balance_wallet_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Vesper Finance',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Personal & Household Wealth Management',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email Field
        _buildInputField(
          controller: _loginEmailController,
          label: 'Alamat Email',
          hint: 'nama@domain.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        // Password Field
        _buildInputField(
          controller: _loginPasswordController,
          label: 'Kata Sandi',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _loginObscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _loginObscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onPressed: () {
              setState(() => _loginObscurePassword = !_loginObscurePassword);
            },
          ),
        ),
        const SizedBox(height: 12),

        // Remember Me & Forgot Password
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      setState(() => _rememberMe = val ?? true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ingat Saya',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Login Button
        ElevatedButton(
          onPressed: _isLoading ? null : () => _handleLogin(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Masuk ke Akun',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRegisterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInputField(
          controller: _regNameController,
          label: 'Nama Lengkap',
          hint: 'Contoh: Ahmad Rizki',
          icon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          inputFormatters: const [CapitalizeWordsInputFormatter()],
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _regEmailController,
          label: 'Email',
          hint: 'ahmad@example.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _regPasswordController,
          label: 'Kata Sandi',
          hint: 'Minimal 8 karakter',
          icon: Icons.lock_outline_rounded,
          obscureText: _regObscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _regObscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onPressed: () {
              setState(() => _regObscurePassword = !_regObscurePassword);
            },
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Daftar & Mulai Kelola Keuangan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            obscureText: obscureText,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
              prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
