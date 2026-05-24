import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/meal_schedule.dart';
import '../../data/repositories/schedule_repository.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/ingredient_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/ai_button_group.dart';
import '../widgets/recommendation_card.dart';

class ChatDetailScreen extends StatefulWidget {
  final String sessionId;
  const ChatDetailScreen({super.key, required this.sessionId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().selectSession(widget.sessionId);
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final chatProv = context.read<ChatProvider>();
    if (chatProv.isLoading) return; // ← Guard UI: jangan kirim saat masih loading

    final userProv = context.read<UserProvider>();
    final ingredientProv = context.read<IngredientProvider>();
    final avoidedIngs = ingredientProv.avoidedIngredients;

    String userContext = userProv.profile?.toAiContext() ?? '';
    if (avoidedIngs.isNotEmpty) {
      final names = avoidedIngs.map((i) => i.nama).join(', ');
      userContext += '\nBahan makanan yang dihindari (pantangan tambahan): $names. Tolong jangan rekomendasikan menu yang mengandung bahan-bahan ini.';
    }

    final profile = userProv.profile;
    if (profile != null) {
      final today = DateTime.now();
      final todayMeals = ScheduleRepository.getByDate(today);
      final targetKalori = userProv.targetKalori;
      final targetTdee = userProv.targetTdee;

      final eatenMeals = todayMeals.where((m) => m.status == 'eaten').toList();
      final totalKaloriEaten = eatenMeals.fold(0.0, (sum, m) => sum + m.totalKalori);
      final totalProteinEaten = eatenMeals.fold(0.0, (sum, m) => sum + m.totalProtein);
      final totalKarboEaten = eatenMeals.fold(0.0, (sum, m) => sum + m.totalKarbo);

      userContext += '\n\nINFORMASI NUTRISI DAN JADWAL REALTIME HARI INI:';
      userContext += '\n- Waktu sekarang: ${DateFormat('HH:mm').format(today)}';
      userContext += '\n- Target Kalori Harian: ${targetKalori.toStringAsFixed(0)} kkal';
      userContext += '\n- Target TDEE: ${targetTdee.toStringAsFixed(0)} kkal';
      userContext += '\n- Konsumsi Kalori Hari Ini: ${totalKaloriEaten.toStringAsFixed(0)} kkal';
      userContext += '\n- Konsumsi Protein Hari Ini: ${totalProteinEaten.toStringAsFixed(1)}g';
      userContext += '\n- Konsumsi Karbohidrat Hari Ini: ${totalKarboEaten.toStringAsFixed(1)}g';

      // Rule 3: Makan Malam dekat jam tidur (Bedtime - 2 jam)
      final bedtimeParts = profile.jamTidur.split(':');
      final bedtimeHour = int.tryParse(bedtimeParts[0]) ?? 22;
      final bedtimeMinute = int.tryParse(bedtimeParts[1]) ?? 0;
      final bedtime = DateTime(today.year, today.month, today.day, bedtimeHour, bedtimeMinute);
      final bedLimitTime = bedtime.subtract(const Duration(hours: 2));

      final hasDinnerEaten = todayMeals.any((m) => m.sesi == 'makan_malam' && m.status == 'eaten');
      if (!hasDinnerEaten && today.isAfter(bedLimitTime)) {
        final maxDinnerCal = min(max(0.0, targetKalori - totalKaloriEaten), targetTdee * 0.15);
        userContext += '\n- ATURAN WAKTU TIDUR DEKAT (Rule 3): Waktu sekarang sudah berada dalam rentang 2 jam sebelum waktu tidur (${profile.jamTidur}). Rekomendasi makan malam untuk user HARUS dibatasi maksimal ${maxDinnerCal.toStringAsFixed(0)} kkal dan HANYA rekomendasikan makanan yang sangat mudah dicerna (seperti bubur gandum, sup bening, atau salad ringan).';
      }

      // Rule 6: Sebelum 14:00 tapi kalori harian > 80% target
      if (today.hour < 14 && totalKaloriEaten > (targetKalori * 0.80)) {
        final maxDinnerCal = targetTdee * 0.10;
        userContext += '\n- ATURAN ASUPAN BERLEBIH SIANG (Rule 6): Karena kalori hari ini sudah melebihi 80% target harian sebelum pukul 14:00, porsi makan malam HARUS dibatasi porsi kecil maksimal ${maxDinnerCal.toStringAsFixed(0)} kkal (misalnya salad hijau segar atau sup bening rendah kalori).';
      }

      // Rule 10: Defisit Protein di malam hari (>= 18:00)
      final proteinRequired = 0.8 * profile.beratBadan;
      if (today.hour >= 18 && totalProteinEaten < proteinRequired) {
        userContext += '\n- ATURAN DEFISIT PROTEIN (Rule 10): Waktu sudah menunjukkan pukul 18:00 atau lebih dan asupan protein saat ini (${totalProteinEaten.toStringAsFixed(1)}g) masih kurang dari batas minimum protein harian (${proteinRequired.toStringAsFixed(1)}g). Makan malam yang direkomendasikan HARUS tinggi protein (seperti dada ayam panggang, putih telur rebus, tahu/tempe panggang, atau ikan).';
      }

      // Rule 11: Karbohidrat dikunci pada target cutting
      if (profile.targetDiet == 'cutting' && totalKaloriEaten > 0) {
        final batasKarbo = 0.35 * totalKaloriEaten / 4;
        if (totalKarboEaten >= batasKarbo) {
          userContext += '\n- ATURAN BATAS KARBOHIDRAT CUTTING (Rule 11): Batas karbohidrat diet cutting hari ini (${batasKarbo.toStringAsFixed(1)}g) telah terlampaui. Rekomendasikan menu makan malam yang HAMPIR BEBAS KARBOHIDRAT atau SANGAT RENDAH KARBO (karbohidrat dikunci, fokus pada protein tinggi dan lemak sehat).';
        }
      }
    }

    chatProv.sendMessage(
      text.trim(),
      userContext: userContext,
    );
    _msgController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat NutriFy AI', style: AppTextStyles.heading3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProv, _) {
          _scrollToBottom();
          return Column(
            children: [
              // Messages
              Expanded(
                child: chatProv.messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatProv.messages.length + (chatProv.isLoading ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == chatProv.messages.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: ChatBubble(
                                message: 'AI sedang mengetik...',
                                isUser: false,
                              ),
                            );
                          }
                          final msg = chatProv.messages[i];
                          final isUser = msg.role == 'user';
                          final time = DateFormat('HH:mm').format(msg.timestamp);

                          if (isUser) {
                            return ChatBubble(
                              message: msg.content,
                              isUser: true,
                              time: time,
                            );
                          }

                          // AI message - parse for special content
                          final cleanText = chatProv.getCleanText(msg.content);
                          final buttons = chatProv.getButtons(msg.content);
                          final rekomendasi = chatProv.getRekomendasi(msg.content);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cleanText.isNotEmpty)
                                ChatBubble(
                                  message: cleanText,
                                  isUser: false,
                                  time: time,
                                ),
                              ...rekomendasi.map((r) => Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: RecommendationCard(
                                      recommendation: r,
                                      initialAction: msg.recommendationActions?[r.namaMenu] ?? 'none',
                                      onAddToSchedule: () async {
                                        final success = await context
                                            .read<ScheduleProvider>()
                                            .addMealFromRecommendation(
                                              namaMenu: r.namaMenu,
                                              ingredients: r.ingredients,
                                              sesiMakan: r.sesiMakan,
                                            );
                                        if (!success) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                    '⚠️ Batas kalori atau makro harian terlampaui. Makanan tidak dapat ditambahkan!'),
                                                backgroundColor: AppColors.error,
                                                behavior: SnackBarBehavior.floating,
                                                margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        if (context.mounted) {
                                          await context.read<IngredientProvider>().loadIngredients();
                                        }
                                        if (context.mounted) {
                                          context.read<DashboardProvider>().refresh();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '✅ ${r.namaMenu} ditambahkan ke ${r.sesiMakan}!'),
                                              backgroundColor: AppColors.success,
                                              behavior: SnackBarBehavior.floating,
                                              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                          
                                          await chatProv.updateRecommendationAction(
                                            messageId: msg.id,
                                            menuName: r.namaMenu,
                                            action: 'added',
                                          );
                                        }
                                      },
                                      onReplaceSchedule: () async {
                                        final scheduleProv = context.read<ScheduleProvider>();
                                        final existingMeals = scheduleProv.getTodayMealsForSession(r.sesiMakan);

                                        bool success = false;
                                        if (existingMeals.isEmpty) {
                                          success = await scheduleProv.addMealFromRecommendation(
                                            namaMenu: r.namaMenu,
                                            ingredients: r.ingredients,
                                            sesiMakan: r.sesiMakan,
                                          );
                                        } else if (existingMeals.length == 1) {
                                          success = await scheduleProv.replaceSpecificMealFromRecommendation(
                                            targetMealId: existingMeals.first.id,
                                            newNamaMenu: r.namaMenu,
                                            ingredients: r.ingredients,
                                            sesiMakan: r.sesiMakan,
                                          );
                                        } else {
                                          final selectedMeal = await _showChoiceDialog(context, existingMeals, r.sesiMakan);
                                          if (selectedMeal == null) {
                                            return false;
                                          }
                                          success = await scheduleProv.replaceSpecificMealFromRecommendation(
                                            targetMealId: selectedMeal.id,
                                            newNamaMenu: r.namaMenu,
                                            ingredients: r.ingredients,
                                            sesiMakan: r.sesiMakan,
                                          );
                                        }

                                        if (!success) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                    '⚠️ Batas kalori atau makro harian terlampaui. Makanan tidak dapat ditambahkan!'),
                                                backgroundColor: AppColors.error,
                                                behavior: SnackBarBehavior.floating,
                                                margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            );
                                          }
                                          return false;
                                        }

                                        if (context.mounted) {
                                          await context.read<IngredientProvider>().loadIngredients();
                                        }
                                        if (context.mounted) {
                                          context.read<DashboardProvider>().refresh();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '🔄 Menu ${r.sesiMakan} diganti dengan ${r.namaMenu}!'),
                                              backgroundColor: AppColors.primary,
                                              behavior: SnackBarBehavior.floating,
                                              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );

                                          await chatProv.updateRecommendationAction(
                                            messageId: msg.id,
                                            menuName: r.namaMenu,
                                            action: 'replaced',
                                          );
                                        }
                                        return true;
                                      },
                                    ),
                                  )),
                              if (buttons.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: AiButtonGroup(
                                    buttons: buttons,
                                    onPressed: (btn) => _sendMessage(btn),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),



              // Input bar
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          enabled: !chatProv.isLoading,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _sendMessage,
                          decoration: InputDecoration(
                            hintText: chatProv.isLoading
                                ? 'AI sedang memproses...'
                                : 'Tulis pesan...',
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient: chatProv.isLoading
                              ? null
                              : AppColors.primaryGradient,
                          color: chatProv.isLoading
                              ? AppColors.surfaceVariant
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: chatProv.isLoading
                              ? null
                              : () => _sendMessage(_msgController.text),
                          icon: Icon(
                            Icons.send_rounded,
                            color: chatProv.isLoading
                                ? AppColors.textLight
                                : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('NutriFy AI', style: AppTextStyles.heading3),
          const SizedBox(height: 4),
          Text('Asisten nutrisi pribadimu',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _quickBtn('Buatkan jadwal makan hari ini'),
              _quickBtn('Hitung kebutuhan kalori saya'),
              _quickBtn('Rekomendasi menu sehat'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(String text) {
    return ActionChip(
      label: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
      backgroundColor: AppColors.primarySurface,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      onPressed: () => _sendMessage(text),
    );
  }

  Future<MealSchedule?> _showChoiceDialog(
    BuildContext context,
    List<MealSchedule> meals,
    String sesiMakan,
  ) {
    return showDialog<MealSchedule>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surface,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Menu Untuk Diganti',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Terdapat lebih dari satu menu pada sesi $sesiMakan hari ini.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: meals.length,
              itemBuilder: (BuildContext context, int index) {
                final meal = meals[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).pop(meal);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                meal.namaMenu,
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Batal',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
