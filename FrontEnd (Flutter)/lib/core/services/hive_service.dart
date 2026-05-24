import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

class HiveService {
  HiveService._();

  static late String localDocumentsDirPath;
  static late Box userBox;
  static late Box ingredientBox;
  static late Box scheduleBox;
  static late Box chatSessionBox;
  static late Box chatMessageBox;
  static late Box secretBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    final directory = await getApplicationDocumentsDirectory();
    localDocumentsDirPath = directory.path;

    userBox = await Hive.openBox(AppConstants.userBox);
    ingredientBox = await Hive.openBox(AppConstants.ingredientBox);
    scheduleBox = await Hive.openBox(AppConstants.scheduleBox);
    chatSessionBox = await Hive.openBox(AppConstants.chatSessionBox);
    chatMessageBox = await Hive.openBox(AppConstants.chatMessageBox);
    secretBox = await Hive.openBox(AppConstants.secretBox);
  }

  static Future<void> clearAll() async {
    await userBox.clear();
    await ingredientBox.clear();
    await scheduleBox.clear();
    await chatSessionBox.clear();
    await chatMessageBox.clear();
  }
}
