import 'package:flutter_test/flutter_test.dart';
import 'package:zyro/services/auth_service.dart';

void main() {
  group('AuthService Input Validators', () {
    final authService = AuthService();

    test('Email validator rejects empty email', () {
      expect(authService.validateEmail(''), 'Email address is required');
      expect(authService.validateEmail(null), 'Email address is required');
    });

    test('Email validator rejects malformed email', () {
      expect(authService.validateEmail('notanemail'),
          'Please enter a valid email address');
      expect(authService.validateEmail('user@'),
          'Please enter a valid email address');
    });

    test('Email validator accepts valid email', () {
      expect(authService.validateEmail('rider@zyro.com'), isNull);
    });

    test('Password validator rejects short passwords', () {
      expect(authService.validatePassword(''), 'Password is required');
      expect(authService.validatePassword('123'),
          'Password must be at least 6 characters');
    });

    test('Password validator accepts valid passwords', () {
      expect(authService.validatePassword('securePass123!'), isNull);
    });

    test('Full name validator rejects empty or single-char names', () {
      expect(authService.validateFullName(''), 'Full name is required');
      expect(authService.validateFullName('A'),
          'Name must be at least 2 characters');
    });

    test('Full name validator accepts valid full name', () {
      expect(authService.validateFullName('Siri Chandana'), isNull);
    });
  });
}
