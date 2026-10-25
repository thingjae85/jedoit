import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'services/account_service.dart';
import 'services/draft_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final drafts = DraftStore()..captureInviteFromUrl();

  AccountService? account;
  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
    account = SupabaseAccountService(drafts: drafts);
  } catch (_) {
    // 서버에 연결하지 못해도 개인 체험은 이 기기에 기록할 수 있게 한다.
  }
  runApp(JeoduitApp(account: account));
}
