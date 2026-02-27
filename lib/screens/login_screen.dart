import 'package:flutter/material.dart';
import '../animations/transitions.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'package:url_launcher/url_launcher.dart';

const _primary = Color(0xff539091);
const _surfaceLight = Color(0xffFFFFFF);
const _surfaceDark = Color(0xff1E293B);
const _borderLight = Color(0xffE2E8F0);
const _borderDark = Color(0xff334155);
const _textDark = Color(0xff0F172A);
const _textMutedLight = Color(0xff64748B);
const _textMutedDark = Color(0xff94A3B8);
const _helpLight = Color(0xff3B82F6);
const _helpDark = Color(0xff60A5FA);
const _error = Color(0xffEF4444);
const _logoAsset = 'lib/assets/vecinus iso-01.png';
const _contentMaxWidth = 448.0;
const _inputRadius = 12.0;
const _supportEmail = '';
const _supportPhone = '';
const _supportWhatsApp = '';
const _supportUrl = '';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool loading = false;
  String? error;
  bool obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_handleFocusChange);
    _passwordFocus.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_handleFocusChange);
    _passwordFocus.removeListener(_handleFocusChange);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> login() async {
    if (loading) return;
    if (!_validateFields()) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await ApiService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      final token = data['token'];
      final userJson = data['usuario'];
      final user = User.fromJson(userJson);
      final sessionExpiration = _extractSessionExpiration(data) ??
          user.sessionExpiresAt ??
          DateTime.now().add(const Duration(hours: 2));
      final sessionUser = user.copyWith(sessionExpiresAt: sessionExpiration);

      await AuthService.saveSession(token, sessionUser.toJson());

      if (mounted) {
        Navigator.pushReplacement(
          context,
          fadeSlideRoute(MainShell(user: sessionUser, token: token)),
        );
      }
    } catch (e) {
      String message = e.toString();
      const exceptionPrefix = 'Exception: ';
      if (message.startsWith(exceptionPrefix)) {
        message = message.substring(exceptionPrefix.length);
      }

      if (message.contains('401')) {
        message = 'Credenciales incorrectas.';
      } else if (message.contains('403')) {
        message = 'Usuario inactivo.';
      }

      if (!mounted) return;
      setState(() => error = message);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      } else {
        loading = false;
      }
    }
  }

  TextStyle _interStyle({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  DateTime? _extractSessionExpiration(Map<String, dynamic> data) {
    final raw =
        data['expires_at'] ?? data['token_expires_at'] ?? data['session_expires_at'];
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    if (raw is int) {
      final isMillis = raw > 2000000000;
      return DateTime.fromMillisecondsSinceEpoch(isMillis ? raw : raw * 1000);
    }
    return null;
  }

  bool _validateFields() {
    final email = emailController.text.trim();
    final password = passwordController.text;
    String? emailError;
    String? passwordError;

    if (email.isEmpty) {
      emailError = 'Ingresa tu correo.';
    } else if (!_isValidEmail(email)) {
      emailError = 'Correo inválido.';
    }

    if (password.isEmpty) {
      passwordError = 'Ingresa tu contraseña.';
    }

    if (emailError == null && passwordError == null) {
      if (_emailError != null || _passwordError != null) {
        setState(() {
          _emailError = null;
          _passwordError = null;
        });
      }
      return true;
    }

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      error = null;
    });
    return false;
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(value);
  }

  void _handleEmailChanged(String _) {
    if (_emailError == null && error == null) return;
    setState(() {
      _emailError = null;
      error = null;
    });
  }

  void _handlePasswordChanged(String _) {
    if (_passwordError == null && error == null) return;
    setState(() {
      _passwordError = null;
      error = null;
    });
  }

  String _normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Uri? _supportLink({required String subject, required String message}) {
    if (_supportEmail.isNotEmpty) {
      return Uri(
        scheme: 'mailto',
        path: _supportEmail,
        queryParameters: {'subject': subject, 'body': message},
      );
    }
    return null;
  }

  Uri? _whatsAppLink(String message) {
    final phone = _normalizePhone(_supportWhatsApp);
    if (phone.isEmpty) return null;
    return Uri.https('wa.me', '/$phone', {'text': message});
  }

  Uri? _phoneLink() {
    final phone = _normalizePhone(_supportPhone);
    if (phone.isEmpty) return null;
    return Uri(scheme: 'tel', path: phone);
  }

  Uri? _urlLink() {
    if (_supportUrl.isEmpty) return null;
    final hasScheme = _supportUrl.startsWith('http://') ||
        _supportUrl.startsWith('https://');
    return Uri.parse(hasScheme ? _supportUrl : 'https://$_supportUrl');
  }

  Future<void> _launchSupport(Uri uri) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace de soporte.')),
      );
    }
  }

  void _openSupportSheet({
    required String title,
    required String message,
    required String subject,
  }) {
    final actions = <_SupportAction>[];
    final emailLink = _supportLink(subject: subject, message: message);
    final whatsappLink = _whatsAppLink(message);
    final phoneLink = _phoneLink();
    final urlLink = _urlLink();

    if (emailLink != null) {
      actions.add(
        _SupportAction(
          label: 'Enviar correo',
          icon: Icons.email_outlined,
          uri: emailLink,
        ),
      );
    }
    if (whatsappLink != null) {
      actions.add(
        _SupportAction(
          label: 'WhatsApp',
          icon: Icons.chat_bubble_outline,
          uri: whatsappLink,
        ),
      );
    }
    if (phoneLink != null) {
      actions.add(
        _SupportAction(
          label: 'Llamar',
          icon: Icons.call_outlined,
          uri: phoneLink,
        ),
      );
    }
    if (urlLink != null) {
      actions.add(
        _SupportAction(
          label: 'Centro de ayuda',
          icon: Icons.support_agent,
          uri: urlLink,
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final muted =
            theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? _textMutedLight;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  actions.isEmpty
                      ? 'Contacta a la administración de tu condominio para resolverlo.'
                      : message,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 16),
                if (actions.isNotEmpty)
                  ...actions.map(
                    (action) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(action.icon, color: _primary),
                      title: Text(action.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _launchSupport(action.uri);
                      },
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInfoDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final textColor = theme.colorScheme.onSurface;
        final muted = textColor.withValues(alpha: 0.75);
        return AlertDialog(
          title: Text(
            title,
            style: _interStyle(
              size: 16,
              weight: FontWeight.w700,
              height: 1.3,
              color: textColor,
            ),
          ),
          content: Text(
            message,
            style: _interStyle(
              size: 14,
              weight: FontWeight.w400,
              height: 1.5,
              color: muted,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = theme.scaffoldBackgroundColor;
    final surface = isDark ? _surfaceDark : _surfaceLight;
    final border = isDark ? _borderDark : _borderLight;
    final textColor = isDark ? Colors.white : _textDark;
    final muted = isDark ? _textMutedDark : _textMutedLight;
    final helpColor = isDark ? _helpDark : _helpLight;
    final bottomPadding = media.viewInsets.bottom + 8;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minHeight = constraints.maxHeight;
              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: IntrinsicHeight(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _contentMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                _buildLogo(isDark),
                                const SizedBox(height: 20),
                                _buildHeader(textColor, muted),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 16),
                                _buildForm(
                                  surface: surface,
                                  border: border,
                                  textColor: textColor,
                                  muted: muted,
                                  linkColor: helpColor,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildFooter(helpColor),
                          ),
                          const SizedBox(height: 8),
                          _buildHomeIndicator(isDark),
                          ],
                        ),
                    ),
                  ),
                ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Image.asset(
            _logoAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.home_work_outlined,
                size: 72,
                color: isDark ? Colors.white : _textDark,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'vecinus',
          style: _interStyle(
            size: 32,
            weight: FontWeight.w700,
            height: 1.1,
            color: _primary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Color textColor, Color muted) {
    return Column(
      children: [
        Text(
          'Bienvenido',
          style: _interStyle(
            size: 28,
            weight: FontWeight.w700,
            height: 1.15,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Pagos, avisos y acuerdos comunitarios, con respaldo.',
            style: _interStyle(
              size: 13,
              weight: FontWeight.w400,
              height: 1.5,
              color: muted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildForm({
    required Color surface,
    required Color border,
    required Color textColor,
    required Color muted,
    required Color linkColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInputField(
          label: 'Correo electrónico',
          hint: 'ejemplo@correo.com',
          controller: emailController,
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          focusNode: _emailFocus,
          surface: surface,
          border: border,
          textColor: textColor,
          muted: muted,
          errorText: _emailError,
          onChanged: _handleEmailChanged,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Contraseña',
          hint: '********',
          controller: passwordController,
          icon: Icons.lock_outline,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          focusNode: _passwordFocus,
          obscure: obscurePassword,
          surface: surface,
          border: border,
          textColor: textColor,
          muted: muted,
          errorText: _passwordError,
          onChanged: _handlePasswordChanged,
          autofillHints: const [AutofillHints.password],
          suffix: IconButton(
            onPressed: () =>
                setState(() => obscurePassword = !obscurePassword),
            icon: Icon(
              obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: muted.withValues(alpha: 0.7),
            ),
          ),
          onSubmitted: (_) => login(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _openSupportSheet(
              title: 'Recuperar contraseña',
              message: 'Elige un canal para recuperar tu acceso.',
              subject: 'Recuperar contraseña - Vecinus',
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '¿Olvidaste tu contraseña?',
              style: _interStyle(
                size: 13,
                weight: FontWeight.w600,
                height: 1.4,
                color: linkColor,
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          _buildErrorCard(error!),
        ],
        const SizedBox(height: 16),
        _buildPrimaryButton(isDark),
        const SizedBox(height: 14),
        _buildTrustCard(
          border: border,
          textColor: textColor,
          linkColor: linkColor,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required Color surface,
    required Color border,
    required Color textColor,
    required Color muted,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    FocusNode? focusNode,
    String? errorText,
    Iterable<String>? autofillHints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: _interStyle(
              size: 13,
              weight: FontWeight.w600,
              height: 1.2,
              color: muted,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscure,
          focusNode: focusNode,
          style: _interStyle(
            size: 16,
            weight: FontWeight.w500,
            height: 1.4,
            color: textColor,
          ),
          cursorColor: _primary,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          autofillHints: autofillHints,
          decoration: InputDecoration(
            filled: true,
            fillColor: surface,
            hintText: hint,
            hintStyle: _interStyle(
              size: 16,
              weight: FontWeight.w400,
              height: 1.4,
              color: muted,
            ),
            errorText: errorText,
            prefixIcon: Icon(icon, color: muted.withValues(alpha: 0.7)),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 48),
            suffixIcon: suffix,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 48),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_inputRadius),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_inputRadius),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_inputRadius),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_inputRadius),
              borderSide: BorderSide(color: _error.withValues(alpha: 0.8)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_inputRadius),
              borderSide: BorderSide(color: _error.withValues(alpha: 0.9), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(bool isDark) {
    return Opacity(
      opacity: loading ? 0.7 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(_inputRadius),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: isDark ? 0.28 : 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : login,
            borderRadius: BorderRadius.circular(_inputRadius),
            child: SizedBox(
              height: 56,
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Entrar a Vecinus',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _interStyle(
                          size: 17,
                          weight: FontWeight.w700,
                          height: 1.2,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustCard({
    required Color border,
    required Color textColor,
    required Color linkColor,
    required bool isDark,
  }) {
    final cardColor = isDark
        ? _surfaceDark.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.6);
    final cardBorder = border.withValues(alpha: isDark ? 0.7 : 0.5);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_inputRadius),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, color: _primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tu información se guarda con trazabilidad y control.',
                  style: _interStyle(
                    size: 13,
                    weight: FontWeight.w600,
                    height: 1.4,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => _showInfoDialog(
              title: 'Seguridad y trazabilidad',
              message:
                  'Tus datos se almacenan con trazabilidad y control. Para más información, contacta a la administración.',
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Cómo cuidamos tu comunidad',
              style: _interStyle(
                size: 12,
                weight: FontWeight.w600,
                height: 1.2,
                color: linkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: _interStyle(
                size: 13,
                weight: FontWeight.w500,
                height: 1.4,
                color: _error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color linkColor) {
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => _openSupportSheet(
            title: 'Ayuda rápida',
            message: 'Cuéntanos qué problema tienes y te ayudamos a resolverlo.',
            subject: 'Ayuda de acceso - Vecinus',
          ),
          icon: Icon(Icons.help_outline, size: 18, color: linkColor),
          label: Text(
            '¿Necesitas ayuda?',
            style: _interStyle(
              size: 14,
              weight: FontWeight.w700,
              height: 1.4,
              color: linkColor,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            foregroundColor: linkColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHomeIndicator(bool isDark) {
    return Center(
      child: Container(
        width: 128,
        height: 6,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SupportAction {
  final String label;
  final IconData icon;
  final Uri uri;

  _SupportAction({
    required this.label,
    required this.icon,
    required this.uri,
  });
}

