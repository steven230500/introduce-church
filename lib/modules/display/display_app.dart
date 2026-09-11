import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presenter/display_cubit.dart';
import 'presenter/display_page.dart';

class DisplayApp extends StatelessWidget {
  const DisplayApp({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DisplayCubit(Supabase.instance.client, userId)..init(),
      child: const MaterialApp(debugShowCheckedModeBanner: false, home: DisplayPage()),
    );
  }
}
