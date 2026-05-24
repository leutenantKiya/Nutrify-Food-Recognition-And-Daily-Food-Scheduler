import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../providers/chat_provider.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProv, _) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Chat AI', style: AppTextStyles.heading2),
                    FloatingActionButton.small(
                      onPressed: () async {
                        final id = await chatProv.createNewSession();
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(sessionId: id),
                          ),
                        );
                      },
                      child: const Icon(Icons.add, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: chatProv.sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.smart_toy_outlined,
                                size: 64, color: AppColors.textLight),
                            const SizedBox(height: 12),
                            Text('Belum ada sesi chat',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textLight)),
                            const SizedBox(height: 4),
                            Text('Mulai konsultasi nutrisi dengan AI',
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: chatProv.sessions.length,
                        itemBuilder: (ctx, i) {
                          final session = chatProv.sessions[i];
                          return Dismissible(
                            key: Key(session.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) =>
                                chatProv.deleteSession(session.id),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.delete_outline,
                                  color: AppColors.error),
                            ),
                            child: Card(
                              child: ListTile(
                                onTap: () {
                                  chatProv.selectSession(session.id);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailScreen(
                                          sessionId: session.id),
                                    ),
                                  );
                                },
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.chat_bubble_outline,
                                      color: AppColors.primary, size: 20),
                                ),
                                title: Text(session.title,
                                    style: AppTextStyles.labelLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  DateFormat('dd MMM yyyy, HH:mm')
                                      .format(session.createdAt),
                                  style: AppTextStyles.bodySmall,
                                ),
                                trailing: const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textLight),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
