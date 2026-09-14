part of '../page.dart';

String _hintText(L10n t, LoginHint hint) => switch (hint) {
  LoginHint.email => t.loginHintEmail,
  LoginHint.password => t.loginHintPassword(LoginModel.minPasswordLength),
  LoginHint.mismatch => t.loginHintMismatch,
};

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginCubit, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccessState) {
          if (state.hasOrg) {
            Modular.to.navigate('/presentation/');
          } else {
            Modular.to.navigate('/org-setup/');
          }
        }
        if (state is LoginErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorText(L10n.of(context), state.error)),
              backgroundColor: const Color(0xFFFF453A),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is LoginLoadingState;
        final model = state.model;
        final cubit = context.read<LoginCubit>();

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(child: Image.asset('assets/images/casavida-isologo-white.png', width: 140)),
              const SizedBox(height: 48),

              // Form card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceControl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      model.isRegistering
                          ? L10n.of(context).loginCreateAccount
                          : L10n.of(context).loginTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (model.isRegistering) ...[
                      _Field(
                        // Keyed: the name field appears above these when registering, and
                        // without keys each field would inherit the text of the one above it.
                        key: const ValueKey('name'),
                        label: L10n.of(context).loginNameOptional,
                        icon: Icons.person_outline,
                        enabled: !isLoading,
                        onChanged: cubit.onDisplayNameChanged,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Email
                    _Field(
                      key: const ValueKey('email'),
                      label: L10n.of(context).loginEmail,
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                      onChanged: cubit.onEmailChanged,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    _Field(
                      key: const ValueKey('password'),
                      label: L10n.of(context).loginPassword,
                      icon: Icons.lock_outline,
                      obscureText: _obscure,
                      enabled: !isLoading,
                      onChanged: cubit.onPasswordChanged,
                      onSubmitted: (_) => model.isRegistering ? null : cubit.submit(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        tooltip: _obscure
                            ? L10n.of(context).loginShowPassword
                            : L10n.of(context).loginHidePassword,
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),

                    if (model.isRegistering) ...[
                      const SizedBox(height: 14),
                      _Field(
                        key: const ValueKey('confirm'),
                        label: L10n.of(context).loginRepeatPassword,
                        icon: Icons.lock_outline,
                        obscureText: _obscure,
                        enabled: !isLoading,
                        onChanged: cubit.onConfirmPasswordChanged,
                        onSubmitted: (_) => cubit.submit(),
                      ),
                    ],

                    // Says what is wrong while they type, instead of waiting
                    // for a failed submit to explain it.
                    if (model.hint != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 13, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _hintText(L10n.of(context), model.hint!),
                              style: const TextStyle(color: AppColors.warning, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Button
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: isLoading || !model.isValid ? null : cubit.submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: AppColors.surfaceControl,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textMuted,
                                ),
                              )
                            : Text(
                                model.isRegistering
                                    ? L10n.of(context).loginCreateAccount
                                    : L10n.of(context).loginSubmit,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: TextButton(
                        onPressed: isLoading ? null : cubit.toggleMode,
                        child: Text(
                          model.isRegistering
                              ? L10n.of(context).loginHaveAccount
                              : L10n.of(context).loginFirstTime,
                          style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
    this.onSubmitted,
  });

  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceControl,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        isDense: true,
      ),
    );
  }
}
