import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../state/providers.dart';
import '../../widgets/state_views.dart';

/// Bottom-navigation shell: Home · Explore · My Tickets · Profile.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(reservationsProvider).value?.where((r) => r.isUpcoming()).length ?? 0;
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StatusBanners(),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.outlineSoft)),
            ),
            child: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) {
                HapticFeedback.selectionClick();
                shell.goBranch(index, initialLocation: index == shell.currentIndex);
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore_rounded),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: upcoming > 0,
                    backgroundColor: AppColors.accent,
                    textColor: AppColors.onAccent,
                    label: Text('$upcoming'),
                    child: const Icon(Icons.confirmation_number_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: upcoming > 0,
                    backgroundColor: AppColors.accent,
                    textColor: AppColors.onAccent,
                    label: Text('$upcoming'),
                    child: const Icon(Icons.confirmation_number_rounded),
                  ),
                  label: 'My Tickets',
                  tooltip: upcoming > 0 ? 'My Tickets, $upcoming upcoming' : 'My Tickets',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// IndexedStack (keeps each tab's state) with a quick fade between tabs.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.medium, value: 1);

  @override
  void didUpdateWidget(covariant FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Motion.curve),
      child: IndexedStack(
        index: widget.index,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            TickerMode(enabled: i == widget.index, child: widget.children[i]),
        ],
      ),
    );
  }
}
