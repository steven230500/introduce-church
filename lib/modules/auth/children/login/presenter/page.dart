import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../../../../core/api/error_text.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/api/api_client.dart';
import 'cubit/cubit.dart';
import 'widgets/reset_password_dialog.dart';

part 'widgets/body.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.resetPassword});

  /// Sets a new password with an administrator's code. Defaults to the API.
  final ResetPassword? resetPassword;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _Body(resetPassword: resetPassword),
          ),
        ),
      ),
    );
  }
}
