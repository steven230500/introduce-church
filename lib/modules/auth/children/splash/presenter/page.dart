import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import 'cubit/cubit.dart';
import 'cubit/state.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashCubit, SplashState>(
      listener: (context, state) {
        if (state is SplashNavigateLogin) Modular.to.navigate('/auth/login');
        if (state is SplashNavigatePresentation) Modular.to.navigate('/presentation/');
        if (state is SplashNavigateOrgSetup) Modular.to.navigate('/org-setup/');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeIn,
            builder: (_, value, child) => Opacity(opacity: value, child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/casavida-isologo-white.png', width: 180),
                const SizedBox(height: 48),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
