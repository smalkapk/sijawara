import 'package:flutter/material.dart';
import '../theme.dart';

class GuruProfileCard extends StatelessWidget {
  final String guruName;
  final String roleLabel;
  final String className;
  final String? avatarUrl;

  const GuruProfileCard({
    super.key,
    required this.guruName,
    required this.roleLabel,
    this.className = 'Kelas -',
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initials = guruName.isNotEmpty ? guruName[0].toUpperCase() : '?';
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.grey100,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar — fully rounded
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
                child: hasAvatar
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl!.startsWith('http')
                              ? avatarUrl!
                              : 'https://portal-smalka.com/${avatarUrl!}',
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.white.withOpacity(0.5),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Center(
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
                      )
                    : Center(
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

              // Name & role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guruName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$roleLabel • $className',
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
            ],
          ),
        ),
      ),
    );
  }
}
