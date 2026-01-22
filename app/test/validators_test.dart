import 'package:flutter_test/flutter_test.dart';
import 'package:app/Services/validators.dart';

void main() {
  group('Email Validation', () {
    test('should accept valid email addresses', () {
      expect(Validators.validateEmail('test@example.com'), isNull);
      expect(Validators.validateEmail('user.name@domain.org'), isNull);
      expect(Validators.validateEmail('user+tag@example.com'), isNull);
      expect(Validators.validateEmail('test123@test.co.uk'), isNull);
    });

    test('should reject empty email', () {
      expect(Validators.validateEmail(null), isNotNull);
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('   '), isNotNull);
    });

    test('should reject invalid email formats', () {
      expect(Validators.validateEmail('notanemail'), isNotNull);
      expect(Validators.validateEmail('missing@domain'), isNotNull);
      expect(Validators.validateEmail('@nodomain.com'), isNotNull);
      expect(Validators.validateEmail('spaces in@email.com'), isNotNull);
    });

    test('should detect common typos', () {
      final result = Validators.validateEmail('test@gmail.con');
      expect(result, contains('mean'));
    });

    test('should reject overly long emails', () {
      final longEmail = '${'a' * 250}@test.com';
      expect(Validators.validateEmail(longEmail), isNotNull);
    });
  });

  group('Password Validation', () {
    test('should accept strong passwords', () {
      expect(Validators.validatePassword('MyStr0ng!Pass'), isNull);
      expect(Validators.validatePassword('Test1234'), isNull);
      expect(Validators.validatePassword('Abcd1234'), isNull);
    });

    test('should reject empty password', () {
      expect(Validators.validatePassword(null), isNotNull);
      expect(Validators.validatePassword(''), isNotNull);
    });

    test('should reject short passwords', () {
      expect(Validators.validatePassword('Ab1'), isNotNull);
      expect(Validators.validatePassword('Short1'), isNotNull);
    });

    test('should require uppercase letters', () {
      final result = Validators.validatePassword('lowercase1');
      expect(result, contains('uppercase'));
    });

    test('should require lowercase letters', () {
      final result = Validators.validatePassword('UPPERCASE1');
      expect(result, contains('lowercase'));
    });

    test('should require numbers', () {
      final result = Validators.validatePassword('NoNumbers');
      expect(result, contains('number'));
    });

    test('should reject common weak passwords', () {
      expect(Validators.validatePassword('Password1'), isNotNull);
      expect(Validators.validatePassword('Qwerty123'), isNotNull);
    });

    test('should reject overly long passwords', () {
      final longPassword = 'Aa1${'a' * 200}';
      expect(Validators.validatePassword(longPassword), isNotNull);
    });
  });

  group('Password Strength', () {
    test('should calculate strength correctly', () {
      // Empty = 0
      expect(Validators.calculatePasswordStrength(''), equals(0));

      // Short = low
      expect(Validators.calculatePasswordStrength('abc'), lessThan(2));

      // Medium length with variety = higher
      expect(Validators.calculatePasswordStrength('Abc12345'), greaterThan(1));

      // Long with all character types = highest
      expect(
        Validators.calculatePasswordStrength('MyStr0ng!Password123'),
        greaterThanOrEqualTo(3),
      );
    });

    test('should return correct strength labels', () {
      expect(Validators.getPasswordStrengthLabel(''), equals('Very Weak'));
      expect(
        Validators.getPasswordStrengthLabel('MyStr0ng!Pass123'),
        equals('Very Strong'),
      );
    });
  });

  group('Username Validation', () {
    test('should accept valid usernames', () {
      expect(Validators.validateUsername('john_doe'), isNull);
      expect(Validators.validateUsername('User123'), isNull);
      expect(Validators.validateUsername('test_user_123'), isNull);
    });

    test('should reject empty username', () {
      expect(Validators.validateUsername(null), isNotNull);
      expect(Validators.validateUsername(''), isNotNull);
    });

    test('should reject short usernames', () {
      expect(Validators.validateUsername('ab'), isNotNull);
    });

    test('should reject long usernames', () {
      expect(Validators.validateUsername('a' * 25), isNotNull);
    });

    test('should reject invalid characters', () {
      expect(Validators.validateUsername('user@name'), isNotNull);
      expect(Validators.validateUsername('user name'), isNotNull);
      expect(Validators.validateUsername('user.name'), isNotNull);
      expect(Validators.validateUsername('user-name'), isNotNull);
    });

    test('should reject usernames starting with numbers', () {
      expect(Validators.validateUsername('123user'), isNotNull);
    });

    test('should reject reserved usernames', () {
      expect(Validators.validateUsername('admin'), isNotNull);
      expect(Validators.validateUsername('moderator'), isNotNull);
      expect(Validators.validateUsername('support'), isNotNull);
    });
  });

  group('Name Validation', () {
    test('should accept valid names', () {
      expect(Validators.validateName('John'), isNull);
      expect(Validators.validateName("O'Brien"), isNull);
      expect(Validators.validateName('Mary-Jane'), isNull);
      expect(Validators.validateName('José'), isNull);
    });

    test('should reject empty names', () {
      expect(Validators.validateName(null), isNotNull);
      expect(Validators.validateName(''), isNotNull);
      expect(Validators.validateName('   '), isNotNull);
    });

    test('should reject overly long names', () {
      expect(Validators.validateName('a' * 60), isNotNull);
    });

    test('should reject names with invalid characters', () {
      expect(Validators.validateName('John123'), isNotNull);
      expect(Validators.validateName('John@Doe'), isNotNull);
    });

    test('should use custom field name in error message', () {
      final result = Validators.validateName('', field: 'first name');
      expect(result, contains('first name'));
    });
  });

  group('Message Validation', () {
    test('should accept valid messages', () {
      expect(Validators.validateMessage('Hello, world!'), isNull);
      expect(Validators.validateMessage('This is a test message.'), isNull);
    });

    test('should reject empty messages', () {
      expect(Validators.validateMessage(null), isNotNull);
      expect(Validators.validateMessage(''), isNotNull);
      expect(Validators.validateMessage('   '), isNotNull);
    });

    test('should reject overly long messages', () {
      expect(Validators.validateMessage('a' * 1500), isNotNull);
    });
  });

  group('Message Sanitization', () {
    test('should trim whitespace', () {
      expect(Validators.sanitizeMessage('  hello  '), equals('hello'));
    });

    test('should remove null bytes', () {
      expect(Validators.sanitizeMessage('hello\x00world'), equals('helloworld'));
    });

    test('should remove control characters', () {
      expect(Validators.sanitizeMessage('hello\x01\x02world'), equals('helloworld'));
    });

    test('should preserve newlines and tabs', () {
      expect(Validators.sanitizeMessage('hello\nworld'), contains('\n'));
    });

    test('should limit consecutive newlines', () {
      final result = Validators.sanitizeMessage('hello\n\n\n\n\nworld');
      expect(result, equals('hello\n\nworld'));
    });

    test('should limit consecutive spaces', () {
      final result = Validators.sanitizeMessage('hello     world');
      expect(result, equals('hello  world'));
    });
  });

  group('URL Validation', () {
    test('should accept valid URLs', () {
      expect(Validators.validateUrl('https://example.com'), isNull);
      expect(Validators.validateUrl('http://test.org/path'), isNull);
      expect(Validators.validateUrl('https://sub.domain.com/page?q=1'), isNull);
    });

    test('should accept null/empty URLs (optional)', () {
      expect(Validators.validateUrl(null), isNull);
      expect(Validators.validateUrl(''), isNull);
    });

    test('should reject invalid URLs', () {
      expect(Validators.validateUrl('not-a-url'), isNotNull);
      expect(Validators.validateUrl('ftp://invalid.com'), isNotNull);
    });

    test('should reject overly long URLs', () {
      expect(Validators.validateUrl('https://example.com/${'a' * 2100}'), isNotNull);
    });
  });

  group('String Extensions', () {
    test('isValidEmail should work correctly', () {
      expect('test@example.com'.isValidEmail, isTrue);
      expect('invalid'.isValidEmail, isFalse);
    });

    test('isValidUsername should work correctly', () {
      expect('valid_user'.isValidUsername, isTrue);
      expect('inv@lid'.isValidUsername, isFalse);
    });

    test('sanitized should work correctly', () {
      expect('hello\x00world'.sanitized, equals('helloworld'));
    });
  });
}
