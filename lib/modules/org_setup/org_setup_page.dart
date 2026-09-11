import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../core/models/organization.dart';
import 'org_setup_cubit.dart';
import '../../core/theme/app_colors.dart';

class OrgSetupPage extends StatelessWidget {
  const OrgSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = Modular.get<OrgSetupCubit>();
    cubit.init().then((alreadyActive) {
      if (alreadyActive) Modular.to.navigate('/presentation/');
    });
    return BlocProvider.value(
      value: cubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SizedBox(width: 480, child: _Body(cubit: cubit)),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.cubit});
  final OrgSetupCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrgSetupCubit, OrgSetupState>(
      builder: (context, state) {
        if (state.loading && state.mode == OrgSetupMode.initial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.isPending) return _PendingView(cubit: cubit);
        return switch (state.mode) {
          OrgSetupMode.initial => _InitialView(cubit: cubit),
          OrgSetupMode.create => _CreateView(cubit: cubit),
          OrgSetupMode.join => _JoinView(cubit: cubit),
        };
      },
    );
  }
}

// ── Initial ───────────────────────────────────────────────────────────────────

class _InitialView extends StatelessWidget {
  const _InitialView({required this.cubit});
  final OrgSetupCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.church, color: AppColors.accent, size: 30),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bienvenido',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Para empezar, crea una organización para tu iglesia\no únete a una existente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary, height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Crear organización'),
              onPressed: cubit.showCreate,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Unirme a una organización'),
              onPressed: cubit.showJoin,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15),
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create org ────────────────────────────────────────────────────────────────

class _CreateView extends StatefulWidget {
  const _CreateView({required this.cubit});
  final OrgSetupCubit cubit;
  @override
  State<_CreateView> createState() => _CreateViewState();
}

class _CreateViewState extends State<_CreateView> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrgSetupCubit, OrgSetupState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textTertiary),
                onPressed: widget.cubit.goBack,
              ),
              const SizedBox(height: 16),
              const Text(
                'Nueva organización',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dale un nombre a tu iglesia u organización.',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre de la organización',
                  hintText: 'Ej. Iglesia Cristiana Central',
                  hintStyle: const TextStyle(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                  errorText: state.error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.loading ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: state.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final ok = await widget.cubit.createOrg(_ctrl.text);
    if (ok && mounted) {
      Modular.to.navigate('/presentation/');
    }
  }
}

// ── Join org ──────────────────────────────────────────────────────────────────

class _JoinView extends StatefulWidget {
  const _JoinView({required this.cubit});
  final OrgSetupCubit cubit;
  @override
  State<_JoinView> createState() => _JoinViewState();
}

class _JoinViewState extends State<_JoinView> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrgSetupCubit, OrgSetupState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textTertiary),
                onPressed: widget.cubit.goBack,
              ),
              const SizedBox(height: 16),
              const Text(
                'Buscar organización',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Busca tu iglesia y envía una solicitud.\nUn administrador deberá aprobarla.',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary, height: 1.5),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre de la organización',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
                onChanged: widget.cubit.search,
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              if (state.searchResults.isEmpty && _ctrl.text.isNotEmpty && !state.loading)
                const Center(
                  child: Text(
                    'Sin resultados',
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
                  ),
                )
              else
                ...state.searchResults.map(
                  (org) => _OrgResultTile(
                    org: org,
                    loading: state.loading,
                    onJoin: () => widget.cubit.requestJoin(org),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OrgResultTile extends StatelessWidget {
  const _OrgResultTile({required this.org, required this.loading, required this.onJoin});
  final Organization org;
  final bool loading;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.church_outlined, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(org.name, style: const TextStyle(fontSize: 14, color: Colors.white)),
          ),
          FilledButton.tonal(
            onPressed: loading ? null : onJoin,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );
  }
}

// ── Pending approval ──────────────────────────────────────────────────────────

class _PendingView extends StatelessWidget {
  const _PendingView({required this.cubit});
  final OrgSetupCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrgSetupCubit, OrgSetupState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF9500), size: 30),
              ),
              const SizedBox(height: 24),
              const Text(
                'Solicitud enviada',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu solicitud para unirte a "${state.pendingOrgName}" está pendiente de aprobación.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textTertiary, height: 1.5),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: state.loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verificar aprobación'),
                  onPressed: state.loading ? null : () => _check(context),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _check(BuildContext context) async {
    final approved = await cubit.checkApproval();
    if (!context.mounted) return;
    if (approved) {
      Modular.to.navigate('/presentation/');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aún pendiente. Contacta al administrador.')));
    }
  }
}
