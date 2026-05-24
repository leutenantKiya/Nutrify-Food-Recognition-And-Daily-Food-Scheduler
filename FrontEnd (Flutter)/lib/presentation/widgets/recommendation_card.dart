import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/ai_response_parser.dart';
import '../providers/schedule_provider.dart';

/// Status aksi yang dilakukan user pada card ini
enum _CardAction { none, added, replaced }

class RecommendationCard extends StatefulWidget {
  final FoodRecommendation recommendation;
  final Future<void> Function() onAddToSchedule;
  final Future<bool> Function() onReplaceSchedule;
  final String initialAction;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.onAddToSchedule,
    required this.onReplaceSchedule,
    this.initialAction = 'none',
  });

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  _CardAction _action = _CardAction.none;
  bool _willExceedAdd = false;
  bool _willExceedReplace = false;
  bool _isLoadingLimits = true;

  _CardAction _parseAction(String act) {
    if (act == 'added') return _CardAction.added;
    if (act == 'replaced') return _CardAction.replaced;
    return _CardAction.none;
  }

  String get _sesiIcon {
    final sesi = widget.recommendation.sesiMakan.toLowerCase();
    if (sesi.contains('sarapan')) return '🌅';
    if (sesi.contains('siang')) return '☀️';
    if (sesi.contains('malam')) return '🌙';
    return '🍽️';
  }

  @override
  void initState() {
    super.initState();
    _action = _parseAction(widget.initialAction);
    _checkLimits();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Daftarkan dependensi ke ScheduleProvider agar ter-trigger saat ada perubahan schedule/asupan
    Provider.of<ScheduleProvider>(context);
    _checkLimits();
  }

  @override
  void didUpdateWidget(covariant RecommendationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recommendation != widget.recommendation || oldWidget.initialAction != widget.initialAction) {
      _action = _parseAction(widget.initialAction);
      _checkLimits();
    }
  }

  Future<void> _checkLimits() async {
    if (!mounted) return;
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    final rec = widget.recommendation;

    final exceedAdd = await provider.willExceedLimit(
      ingredients: rec.ingredients,
      sesiMakan: rec.sesiMakan,
      isReplace: false,
    );

    final exceedReplace = await provider.willExceedLimit(
      ingredients: rec.ingredients,
      sesiMakan: rec.sesiMakan,
      isReplace: true,
    );

    if (mounted) {
      setState(() {
        _willExceedAdd = exceedAdd;
        _willExceedReplace = exceedReplace;
        _isLoadingLimits = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;
    final entries = rec.ingredients.entries.toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.03),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.namaMenu,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entries.length} bahan makanan',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge sesi makan
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_sesiIcon, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        rec.sesiMakan,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tabel Bahan Makanan ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // Header tabel
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Bahan Makanan',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Porsi',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.1)),
                const SizedBox(height: 4),
                // Baris bahan
                ...entries.asMap().entries.map((e) {
                  final isLast = e.key == entries.length - 1;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                _capitalize(e.value.key),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                e.value.value,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          color: AppColors.primary.withValues(alpha: 0.06),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),

          // ── Tombol Aksi ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _action != _CardAction.none
                  ? _buildDoneState()
                  : _buildActionButtons(),
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan setelah aksi berhasil
  Widget _buildDoneState() {
    final isAdded = _action == _CardAction.added;
    return Container(
      key: const ValueKey('done'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
          const SizedBox(width: 6),
          Text(
            isAdded
                ? '${widget.recommendation.sesiMakan} – Menu ditambahkan!'
                : '${widget.recommendation.sesiMakan} – Menu diganti!',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Dua tombol: Tambah & Ganti
  Widget _buildActionButtons() {
    return Row(
      key: const ValueKey('buttons'),
      children: [
        // Tombol TAMBAH
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (_isLoadingLimits || _willExceedAdd)
                ? null
                : () async {
                    setState(() => _action = _CardAction.added);
                    await widget.onAddToSchedule();
                  },
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: const Text('Tambah'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Tombol GANTI
        Expanded(
          child: FilledButton.icon(
            onPressed: (_isLoadingLimits || _willExceedReplace)
                ? null
                : () async {
                    final didReplace = await widget.onReplaceSchedule();
                    if (didReplace) {
                      setState(() => _action = _CardAction.replaced);
                    }
                  },
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Ganti'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
