import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/role_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/font_utils.dart';
import '../../../core/utils/icon_utils.dart';
import '../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../services/role_service.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({
    super.key,
    required this.child,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  late RoleService _roleService;
  List<NavigationItemConfig> _navigationItems = [];

  @override
  void initState() {
    super.initState();
    _roleService = RoleService();
    _updateNavigationItems();
    
    // Listen to role service changes
    _roleService.addListener(_updateNavigationItems);
  }

  @override
  void dispose() {
    _roleService.removeListener(_updateNavigationItems);
    super.dispose();
  }

  void _updateNavigationItems() {
    if (mounted) {
      setState(() {
        _navigationItems = _roleService.getFilteredNavigationItems();
        // Force rebuild to update title and other role-dependent UI elements
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSelectedIndex();
    });
  }

  void _updateSelectedIndex() {
    if (!mounted) return;

    try {
      final currentLocation = GoRouterState.of(context).matchedLocation;
      for (int i = 0; i < _navigationItems.length; i++) {
        if (currentLocation.startsWith(_navigationItems[i].route)) {
          if (_selectedIndex != i) {
            setState(() {
              _selectedIndex = i;
            });
          }
          break;
        }
      }
    } catch (e) {
      // If GoRouterState is not ready yet, ignore the error
      debugPrint('GoRouterState not ready: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: ResponsiveBreakpoints.of(context).largerThan(TABLET) ? _buildDesktopLayout() : widget.child,
      bottomNavigationBar: ResponsiveBreakpoints.of(context).smallerThan(DESKTOP) ? _buildBottomNavigation() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Icon(
            Icons.medical_services_rounded,
            color: AppColors.onPrimary,
            // Apply icon size protection
            size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              _getCurrentPageTitle(),
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.bold,
                color: AppColors.onPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
          ),
          onPressed: () {
            // TODO: Show notifications
          },
        ),
        PopupMenuButton<String>(
          icon: CircleAvatar(
            child: Icon(
              Icons.person,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
          ),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                context.go('/profile');
                break;
              case 'logout':
                _handleLogout();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                  ),
                  const SizedBox(width: 8),
                  const Text('Profile'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: AppColors.error,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                  ),
                  const SizedBox(width: 8),
                  const Text('Logout'),
                ],
              ),
            ),
          ],
        ),
        SizedBox(width: 8.w),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildSideNavigation(),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildSideNavigation() {
    return Container(
      width: 240.w,
      decoration: const BoxDecoration(
        color: AppColors.lightSurface,
        border: Border(
          right: BorderSide(
            color: AppColors.lightDivider,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedIndex == index;

                return Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  child: ListTile(
                    selected: isSelected,
                    leading: Icon(
                      _getIconData(isSelected ? item.selectedIcon : item.icon),
                      color: isSelected ? AppColors.primary : AppColors.lightOnSurfaceVariant,
                      size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                    ),
                    title: Text(
                      item.label,
                      style: FontUtils.body(
                        context: context,
                        color: isSelected ? AppColors.primary : AppColors.lightOnSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                    onTap: () => _onNavItemTapped(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    // Ensure we have at least 2 items for BottomNavigationBar
    if (_navigationItems.length < 2) {
      return const SizedBox.shrink(); // Hide bottom navigation if insufficient items
    }
    
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex.clamp(0, _navigationItems.length - 1), // Clamp index to valid range
      onTap: _onNavItemTapped,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightOnSurfaceVariant,
      selectedLabelStyle: FontUtils.caption(
        context: context,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: FontUtils.caption(
        context: context,
        fontWeight: FontWeight.w500,
      ),
      items: _navigationItems
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(
                _getIconData(item.icon),
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              activeIcon: Icon(
                _getIconData(item.selectedIcon),
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              label: item.label,
            ),
          )
          .toList(),
    );
  }

  void _onNavItemTapped(int index) {
    // Ensure we have valid navigation items and index
    if (_navigationItems.isEmpty || index >= _navigationItems.length || index < 0) {
      return;
    }
    
    setState(() {
      _selectedIndex = index;
    });

    final route = _navigationItems[index].route;
    context.go(route);
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!mounted) return;
              
              Navigator.of(context).pop();
              
              // Get AuthBloc and trigger logout
              final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
              
              // Clear role service first
              _roleService.clear();
              
              // Trigger logout event in AuthBloc
              authBloc.add(LogoutRequested());
              
              // Wait for logout to complete and then navigate
              await Future.delayed(const Duration(milliseconds: 100));
              
              if (mounted && context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  /// Get current page title based on route and role
  String _getCurrentPageTitle() {
    try {
      final currentLocation = GoRouterState.of(context).matchedLocation;
      return _roleService.getPageTitle(currentLocation);
    } catch (e) {
      return _roleService.getHomePageTitle();
    }
  }

  /// Convert string icon name to IconData
  IconData _getIconData(String iconName) {
    switch (iconName) {
      // Dashboard icons
      case 'dashboard_outlined':
        return Icons.dashboard_outlined;
      case 'dashboard':
        return Icons.dashboard;
      
      // People/Patient icons
      case 'people_outlined':
        return Icons.people_outlined;
      case 'people':
        return Icons.people;
      case 'person_outlined':
        return Icons.person_outlined;
      case 'person':
        return Icons.person;
      
      // Analytics icons
      case 'analytics_outlined':
        return Icons.analytics_outlined;
      case 'analytics':
        return Icons.analytics;
      
      // Settings icons
      case 'settings_outlined':
        return Icons.settings_outlined;
      case 'settings':
        return Icons.settings;
      
      // Report/Description icons
      case 'description_outlined':
        return Icons.description_outlined;
      case 'description':
        return Icons.description;
      
      // Health icons
      case 'health_and_safety_outlined':
        return Icons.health_and_safety_outlined;
      case 'health_and_safety':
        return Icons.health_and_safety;
      
      // Medication icons
      case 'medication_outlined':
        return Icons.medication_outlined;
      case 'medication':
        return Icons.medication;
      
      // Message icons
      case 'message_outlined':
        return Icons.message_outlined;
      case 'message':
        return Icons.message;
      
      // Admin icons
      case 'admin_panel_settings_outlined':
        return Icons.admin_panel_settings_outlined;
      case 'admin_panel_settings':
        return Icons.admin_panel_settings;
      
      // Device icons
      case 'devices_outlined':
        return Icons.devices_outlined;
      case 'devices':
        return Icons.devices;
      
      // History icons
      case 'history_outlined':
        return Icons.history_outlined;
      case 'history':
        return Icons.history;
      
      // Default fallback
      default:
        return Icons.help_outline;
    }
  }
}

