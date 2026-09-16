import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_button.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../data/models/college_model.dart';
import '../../../data/repositories/college_repository.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final selectedCollege = ref.watch(selectedCandidateCollegeProvider);
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      next.maybeWhen(
        error: (e, s) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        ),
        orElse: () {},
      );
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: AppRadius.mdRadius,
                    boxShadow: AppShadows.card(context),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    size: 44,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.appTagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 40),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search institutes',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<CollegeModel>>(
                  stream: ref
                      .watch(collegeRepositoryProvider)
                      .streamActiveColleges(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Could not load institutes: ${snapshot.error}');
                    }

                    final colleges = snapshot.data!
                        .where((college) => _query.isEmpty || college.name.toLowerCase().contains(_query))
                        .toList();

                    if (colleges.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Text(
                          'No institutes found.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: colleges.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final college = colleges[index];
                          final selected = selectedCollege?.id == college.id;
                          return UnexaCard(
                            borderRadius: AppRadius.sm,
                            color: selected
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                                : null,
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                            ),
                            onTap: () => ref
                                .read(selectedCandidateCollegeProvider.notifier)
                                .select(college),
                            child: Row(
                              children: [
                                Icon(
                                  selected ? Icons.radio_button_checked_rounded : Icons.school_outlined,
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    college.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selectedCollege == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            selectedCollege.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        ),
                ),
                UnexaButton(
                  text: 'Continue with Google',
                  isLoading: authState.isLoading,
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  onPressed: selectedCollege == null
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(selectedCollege),
                ),
                const SizedBox(height: 16),
                Text(
                  'Use your institute Google account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
