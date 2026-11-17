/// Supabase 연결 정보. publishable 키는 앱에 포함되는 공개용 키다.
/// service_role 키나 DB 비밀번호는 절대 여기에 넣지 않는다.
const supabaseUrl = 'https://tcexjsgaspkozzhwofpc.supabase.co';
const supabasePublishableKey = 'sb_publishable_WVBHA7Jsgan7oiOuJkOUwQ_VRhbWlel';

/// 배포된 웹 주소. 앱(iPhone 등)에서 친구 초대 링크·QR을 만들 때 쓴다.
const webAppUrl = 'https://thingjae85.github.io/jedoit/';

/// iPhone 앱에서 Google 로그인 후 앱으로 돌아오는 주소.
/// Supabase Authentication → URL Configuration → Redirect URLs에도 같은 값을 넣어야 한다.
const appAuthRedirect = 'com.thingjae85.jeoduit://login-callback';
