import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../../../../core/theme/app_colors.dart';
import 'cubit/cubit.dart';

part 'widgets/body.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: _Body()),
        ),
      ),
    );
  }
}
