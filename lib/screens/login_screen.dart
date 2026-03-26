import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../data/auth_storage.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController tokenController = TextEditingController();

  bool loading = false;
  String? errorText;
  bool obscureToken = true;

  Future<void> login() async {
    final token = tokenController.text.trim();

    if (token.isEmpty) {
      setState(() {
        errorText = 'Please enter your API token.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      await AuthStorage.saveToken(token);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorText = 'Token could not be saved.';
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    tokenController.dispose();
    super.dispose();
  }

  Widget loginCard() {
    return Container(
      width: 460,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.08),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trading Systems Dashboard',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Controlled by claus.digital',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sign in with your private app token to access the monitoring dashboard.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: tokenController,
            obscureText: obscureToken,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: 'API Token',
              hintText: 'Enter X-APP-TOKEN value',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    obscureToken = !obscureToken;
                  });
                },
                icon: Icon(
                  obscureToken ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                errorText!,
                style: const TextStyle(
                  color: AppColors.red,
                  fontSize: 12,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: loading ? null : login,
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Open Dashboard'),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Read-only monitoring access. No trade execution or account control.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: loginCard(),
        ),
      ),
    );
  }
}