import '../database/app_database.dart';
import 'posting_repository.dart';

final appDatabase = AppDatabase();
final postingRepository = PostingRepository(appDatabase);
