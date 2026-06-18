// ignore_for_file: uri_does_not_exist, unused_import, undefined_class, undefined_method, undefined_identifier, non_type_as_type_argument

// ============================================================
// VERSÃO RUIM — viola o SRP
// ============================================================

class LoginController {
  Future<void> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email e senha obrigatórios');
    }

    if (!email.contains('@')) {
      throw Exception('Email inválido');
    }

    print('Iniciando login');

    final response = await Dio().post(
      'https://api.example.com/login',
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final user = User.fromJson(response.data);

      SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', response.data['token']);
      await prefs.setString('user_name', user.name);
      await prefs.setString('user_email', user.email);

      FirebaseAnalytics.instance.logLogin();

      FirebaseCrashlytics.instance.setUserIdentifier(user.id.toString());

      await NotificationService().registerDevice();

      await LocalDatabase.instance.saveUser(user);

      await CacheManager.instance.clearOldCache();

      await AuditService().saveLog(action: 'LOGIN', userId: user.id);

      await EmailService().sendWelcomeBackEmail(user.email);

      await PermissionService().refreshPermissions();

      print('Usuário logado');

      if (user.isAdmin) {
        Navigator.pushNamed('/admin');
      } else {
        Navigator.pushNamed('/home');
      }
    } else {
      print('Falha ao realizar login');

      FirebaseCrashlytics.instance.recordError(Exception('Erro login'), null);
    }
  }
}

// ============================================================
// VERSÃO NOVA — respeita o SRP
// ============================================================

class LoginController2 {
  final LoginService _loginService;
  final NavigationService _navigationService;
  final NotificationService _notificationService;
  final PermissionService _permissionService;
  final AnalyticsService _analytics;

  LoginController2({
    required LoginService loginService,
    required NavigationService navigationService,
    required NotificationService notificationService,
    required PermissionService permissionService,
    required AnalyticsService analytics,
  }) : _loginService = loginService,
       _navigationService = navigationService,
       _notificationService = notificationService,
       _permissionService = permissionService,
       _analytics = analytics;

  Future<void> login(String email, String password) async {
    final result = await _loginService.login(email, password);

    await result.fold(showError, (user) async {
      _analytics.trackLogin(user);

      await _notificationService.registerDevice();

      await _permissionService.refresh();

      await _navigationService.navigateAfterLogin(user);
    });
  }
}

class LoginService {
  const LoginService(
    LoginValidator validator,
    AuthRepository authRepository,
    SessionManager sessionManager,
  ) : _validator = validator,
      _authRepository = authRepository,
      _sessionManager = sessionManager;

  final LoginValidator _validator;
  final AuthRepository _authRepository;
  final SessionManager _sessionManager;

  Future<Either<Exception, User>> login(String email, String password) async {
    try {
      _validator.validate(email, password);

      final user = await _authRepository.login(email, password);

      await _sessionManager.start(user);

      return Right(user);
    } on Exception catch (e) {
      return Left(e);
    }
  }
}

class AuthRepository {
  final ApiClientAdapter _apiClient;
  const AuthRepository({required ApiClientAdapter apiClient})
    : _apiClient = apiClient;

  Future<User> login(String email, String password) async {
    final response = await _apiClient.post(
      'https://api.example.com/login',
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    } else {
      throw Exception('Falha ao realizar login');
    }
  }
}
