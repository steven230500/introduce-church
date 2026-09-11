import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presenter/stage_cubit.dart';
import 'presenter/stage_page.dart';

class StageApp extends StatelessWidget {
  const StageApp({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StageCubit(Supabase.instance.client, userId)..init(),
      child: const MaterialApp(debugShowCheckedModeBanner: false, home: StagePage()),
    );
  }
}
