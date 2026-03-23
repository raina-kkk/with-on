import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isSignUpMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _modeSwitchLinkPressed = false;

  late final AnimationController _lampController;
  late final Animation<double> _lampAnimation;

  @override
  void initState() {
    super.initState();
    _lampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _lampAnimation = CurvedAnimation(
      parent: _lampController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _lampController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      if (_isSignUpMode) {
        await _signUp();
      } else {
        await _signIn();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(e.code))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('잠시 연결에 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final user = credential.user;
    if (user == null) return;

    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? '',
      'nickname': _nicknameController.text.trim(),
      'photo_url': null,
      'fcm_token': null,
      'group_ids': <String>[],
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _signIn() async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다. 다시 한 번 확인해 주세요.';
      case 'user-not-found':
        return '등록된 계정을 찾지 못했습니다. 이메일을 다시 확인해 주시거나 회원가입을 해 주세요.';
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 맞지 않습니다. 다시 한 번 확인해 주시겠어요?';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다. 로그인 화면에서 로그인해 주시면 됩니다.';
      case 'weak-password':
        return '비밀번호는 최소 6자리 이상으로 설정해 주시면 감사하겠습니다.';
      case 'too-many-requests':
        return '잠시 너무 많은 시도가 있었습니다. 조금 후에 다시 시도해 주세요.';
      default:
        return '인증 중에 문제가 발생했습니다. 잠시 후 다시 시도해 주시면 감사하겠습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 120, left: 36, right: 36, bottom: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 로고 / 메인카피 / 서브카피 (왼쪽 정렬) ──
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 로고: with;on
                        Text.rich(
                          TextSpan(
                            text: 'With',
                            style: const TextStyle(
                              fontSize: 35,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textLight,
                              letterSpacing: -1.2,
                              fontFamily: 'LeferiPoint',
                            ),
                            children: const [
                              TextSpan(
                                text: ';',
                                style: TextStyle(
                                  color: AppTheme.textLight,
                                  fontSize: 35,
                                  fontFamily: 'LeferiPoint',
                                ),
                              ),
                              TextSpan(
                                text: 'On',
                                style: TextStyle(
                                  color: Color(0xFFFFD966),
                                  fontSize: 38,
                                  fontFamily: 'LeferiPoint',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // 메인카피: 당신의 기도로 온기를 켜주세요
                        Text(
                          '당신의 기도로\n온기를 켜주세요.',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.5,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkPrimary
                                : AppTheme.primary,
                            fontFamily: 'NotoSerifKR',
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 서브카피: 위드온에서 함께 나누는 중보기도
                        Text(
                          '위드온에서 함께 나누는 중보기도',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textLight,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 80),

                    // ── 입력 카드 (로그인 박스) ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.cardDecorationFor(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                    // 닉네임 (회원가입 모드에서만 표시)
                    if (_isSignUpMode) ...[
                      TextFormField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          labelText: '닉네임',
                          hintText: '소그룹에서 불릴 이름을 정해 주세요.',
                          border: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(16)),
                          ),
                          prefixIcon: Icon(
                            Icons.badge_rounded,
                            size: 20,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkSecondary
                                : AppTheme.primary,
                          ),
                        ),
                        validator: (v) {
                          if (_isSignUpMode &&
                              (v == null || v.trim().isEmpty)) {
                            return '닉네임을 입력해 주시면 감사하겠습니다.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 이메일
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: '이메일',
                        labelStyle: TextStyle(
                          color: AppTheme.textLight.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        hintText: 'example@email.com',
                        filled: true,
                        fillColor: const Color(0xFFFDFBF9),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          size: 20,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkSecondary
                              : AppTheme.primary,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return '이메일을 입력해 주시면 감사하겠습니다.';
                        }
                        if (!v.contains('@')) {
                          return '올바른 이메일 형식이 아닌 것 같습니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // 비밀번호
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        labelStyle: TextStyle(
                          color: AppTheme.textLight.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        hintText: _isSignUpMode ? '6자리 이상 입력해 주세요.' : '',
                        filled: true,
                        fillColor: const Color(0xFFFDFBF9),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkSecondary
                              : AppTheme.primary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return '비밀번호를 입력해 주시면 감사하겠습니다.';
                        }
                        if (_isSignUpMode && v.length < 6) {
                          return '비밀번호는 최소 6자리 이상으로 설정해 주세요.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // 메인 버튼 (로그인 or 회원가입)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                _isSignUpMode ? '회원가입하고 시작하기' : '기도 시작하기',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                        ],
                      ),
                    ),
                    // ── 카드 끝 ──
                  ],
                ),
              ),
            ),
            ), // Expanded
            // ── 하단 고정: 아직 계정이 없으신가요? ──
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 16, 36, 24),
              child: Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final buttonColor = isDark ? AppTheme.darkSecondary : AppTheme.primary;
                  final labelColor = AppTheme.textLight.withValues(alpha: 0.7);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isSignUpMode
                            ? '이미 계정이 있으신가요?  '
                            : '아직 계정이 없으신가요?  ',
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTapDown: _isLoading ? null : (_) => setState(() => _modeSwitchLinkPressed = true),
                        onTapUp: _isLoading ? null : (_) => setState(() => _modeSwitchLinkPressed = false),
                        onTapCancel: _isLoading ? null : () => setState(() => _modeSwitchLinkPressed = false),
                        onTap: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _isSignUpMode = !_isSignUpMode;
                                  _formKey.currentState?.reset();
                                  _modeSwitchLinkPressed = false;
                                });
                              },
                        child: Text(
                          _isSignUpMode ? '로그인하기' : '회원가입하기',
                          style: TextStyle(
                            color: buttonColor,
                            fontWeight: _modeSwitchLinkPressed ? FontWeight.w800 : FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: buttonColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
          ), // SafeArea
          Positioned(
            top: 2,
            right: 16,
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                children: [
                  FadeTransition(
                    opacity: _lampAnimation,
                    child: Image.asset('assets/images/Light.png'),
                  ),
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/Lamp_dark.png'
                        : 'assets/images/Lamp.png',
                  ),
                ],
              ),
            ),
          ),
        ], // Stack children
      ), // Stack
    );
  }
}
