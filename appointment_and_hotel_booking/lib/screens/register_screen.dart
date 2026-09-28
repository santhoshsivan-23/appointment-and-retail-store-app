import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  final List<String> _businessTypes = [
    'Unified Care & Retail Platform',
    'Veterinary & Clinical Suite',
    'Salon & Pet Grooming',
    'Hotel & Pet Boarding',
    'Store & Retail POS',
  ];

  late String _selectedBusinessType;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedBusinessType = _businessTypes[0];
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _fillSampleBusiness() {
    final rand = DateTime.now().millisecondsSinceEpoch % 1000;
    _businessNameController.text = 'Grand Pet Oasis & Clinic';
    _ownerNameController.text = 'Dr. Shaun Ong';
    _emailController.text = 'shaun$rand@omopet.clinic';
    _phoneController.text = '+1-555-01$rand';
    _passwordController.text = 'Omopet2026!';
    _confirmPasswordController.text = 'Omopet2026!';
    _cityController.text = 'San Francisco';
    _countryController.text = 'United States';
    setState(() {});
  }

  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    if (!_agreeTerms) {
      setState(() {
        _errorMessage = 'Please agree to terms & terminal policies.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final payload = {
      'business_name': _businessNameController.text.trim(),
      'business_type': _selectedBusinessType,
      'owner_name': _ownerNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'password': _passwordController.text,
      'city': _cityController.text.trim(),
      'country': _countryController.text.trim(),
    };

    final res = await ApiService.register(payload);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res.success && res.data != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.tertiary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(business: res.data),
        ),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // Background ambient gradient blurs
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryContainer.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryContainer.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Main Column (Header, Body, Footer)
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1140),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 940;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: _buildHeroLeft()),
                                const SizedBox(width: 48),
                                Expanded(flex: 7, child: Center(child: _buildRegisterCard())),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildHeroLeft(isCompact: true),
                                const SizedBox(height: 36),
                                _buildRegisterCard(),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Logo & Back
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface, size: 22),
                tooltip: 'Back to Sign In',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IQ Store',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'BUSINESS REGISTRATION PORTAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          TextButton.icon(
            icon: const Icon(Icons.login, size: 16, color: AppTheme.primary),
            label: Text(
              'Sign In',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                fontSize: 13,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroLeft({bool isCompact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'INSTANT TERMINAL ONBOARDING',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Register Your Business Terminal',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isCompact ? 26 : 34,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface,
            height: 1.15,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Deploy your clinical schedule, salon grooming slots, hotel boarding reservations, and store POS terminal in a unified system.',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            color: AppTheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        _buildFeatureCard(
          icon: Icons.calendar_month,
          iconBg: AppTheme.primary.withValues(alpha: 0.1),
          iconColor: AppTheme.primary,
          title: 'Appointment Booking & Check-In',
          description: 'Customizable time slots, doctor queues, and client notifications.',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          icon: Icons.point_of_sale,
          iconBg: AppTheme.secondaryContainer.withValues(alpha: 0.25),
          iconColor: AppTheme.secondary,
          title: 'Unified Store & Room POS',
          description: 'Manage sales receipts, room bookings, and product stock effortlessly.',
        ),
        const SizedBox(height: 24),

        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _buildTrustBadge(Icons.security, 'Encrypted Gateway', AppTheme.tertiary),
            _buildTrustBadge(Icons.sync, 'Multi-Station Sync', AppTheme.primary),
            _buildTrustBadge(Icons.cloud_done, 'Instant Setup', AppTheme.secondary),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 540),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardIconGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 26),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.auto_fix_high, size: 14, color: AppTheme.primary),
                  label: Text(
                    'Sample Data',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  onPressed: _fillSampleBusiness,
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(
              'Register Business Terminal',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your business specifications and manager credentials.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          color: AppTheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Business Name
            _buildFieldLabel(Icons.storefront, 'Business Name *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _businessNameController,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'e.g. Grand Pet Oasis & Clinic',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter business name' : null,
            ),
            const SizedBox(height: 14),

            // Business Category
            _buildFieldLabel(Icons.category, 'Terminal Category *'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedBusinessType,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
              dropdownColor: AppTheme.surfaceContainerLowest,
              decoration: const InputDecoration(),
              items: _businessTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedBusinessType = val);
              },
            ),
            const SizedBox(height: 14),

            // Owner / Manager Name & Phone
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(Icons.badge, 'Owner / Contact *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ownerNameController,
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Dr. Shaun Ong',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter owner name' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(Icons.phone, 'Contact Phone *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
                        decoration: const InputDecoration(
                          hintText: '+1 555-0199',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter phone number' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Email
            _buildFieldLabel(Icons.email, 'Business Email * (for login)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'admin@omopet.clinic',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter business email';
                if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Passwords Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(Icons.lock, 'Password *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Min 6 chars',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              size: 18,
                              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(Icons.lock_reset, 'Confirm *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Confirm pwd',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              size: 18,
                              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Confirm password' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // City & Country Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(Icons.location_city, 'City'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cityController,
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
                        decoration: const InputDecoration(hintText: 'e.g. Chicago'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(Icons.public, 'Country'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _countryController,
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
                        decoration: const InputDecoration(hintText: 'e.g. USA'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Terms checkbox
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _agreeTerms,
                    activeColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _agreeTerms = val ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'I agree to Terminal Services & 256-Bit Data Protocols',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isLoading ? null : _handleRegister,
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.app_registration, size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Complete Business Registration',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Already registered? Sign in
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already registered your business? ',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: AppTheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1140),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user, size: 16, color: AppTheme.tertiary),
                  const SizedBox(width: 6),
                  Text(
                    '256-Bit Encrypted Clinical Gateway',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
              Text(
                '© 2025 Omopet Veterinary & Grooming Solutions Ltd. All rights reserved.',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
