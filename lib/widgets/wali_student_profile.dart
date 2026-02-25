import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/wali_service.dart';

class WaliStudentProfile extends StatelessWidget {
  final WaliChildInfo? child;
  final List<WaliChildInfo> allChildren;
  final ValueChanged<int>? onChildSwitch;

  const WaliStudentProfile({
    super.key,
    this.child,
    this.allChildren = const [],
    this.onChildSwitch,
  });

  bool get _hasMultipleChildren => allChildren.length > 1;

  @override
  Widget build(BuildContext context) {
    final studentName = child?.studentName ?? '-';
    final className = child != null ? 'Kelas ${child!.className}' : '-';
    final initials = child?.initials ?? '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _hasMultipleChildren
            ? () => _showChildSwitcherSheet(context)
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.greenGlow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.white.withOpacity(0.15),
                    border: Border.all(
                      color: AppTheme.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Name & class
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        className,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mint,
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),

                // Dropdown indicator (jika punya >1 anak)
                if (_hasMultipleChildren)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: AppTheme.white.withOpacity(0.8),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChildSwitcherSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChildSwitcherSheet(
        allChildren: allChildren,
        selectedChildId: child?.studentId,
        onChildSelected: (studentId) {
          Navigator.pop(ctx);
          onChildSwitch?.call(studentId);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ───── Bottom Sheet: Pilih Anak ──────────────────────
// ═══════════════════════════════════════════════════════

class _ChildSwitcherSheet extends StatelessWidget {
  final List<WaliChildInfo> allChildren;
  final int? selectedChildId;
  final ValueChanged<int> onChildSelected;

  const _ChildSwitcherSheet({
    required this.allChildren,
    this.selectedChildId,
    required this.onChildSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Anak',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${allChildren.length} anak terdaftar',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.grey100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppTheme.grey600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Child list
          ...allChildren.map((child) {
            final isSelected = child.studentId == selectedChildId;

            return GestureDetector(
              onTap: () {
                if (!isSelected) {
                  onChildSelected(child.studentId);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryGreen.withOpacity(0.08)
                      : AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.grey100,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.primaryGreen.withOpacity(0.12),
                      ),
                      child: Center(
                        child: Text(
                          child.initials,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? AppTheme.white
                                : AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.studentName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kelas ${child.className} • NIS: ${child.nis}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Check indicator
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppTheme.white,
                          size: 16,
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.grey400,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
