import 'package:flutter_test/flutter_test.dart';
import 'package:nijagig/core/errors/app_failure.dart';
import 'package:nijagig/data/models/app_user.dart';
import 'package:nijagig/data/repositories/auth_repository.dart';
import 'package:nijagig/data/repositories/demo/demo_auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('demo email password account survives sign-out and sign-in', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = DemoAuthRepository(prefs);

    final created = await repo.signUpWithPassword(
      method: AuthMethod.email,
      identifier: 'Amaka@Example.com',
      password: 'strongpass1',
      displayName: 'Amaka Okafor',
      role: UserRole.customer,
    );
    expect(created.email, 'amaka@example.com');
    expect(created.phone, '');
    expect(created.displayName, 'Amaka Okafor');

    await repo.signOut();
    expect(repo.currentUser, isNull);

    final returning = await repo.signInWithPassword(
      method: AuthMethod.email,
      identifier: 'AMAKA@example.com',
      password: 'strongpass1',
    );
    expect(returning.displayName, 'Amaka Okafor');
    expect(returning.email, 'amaka@example.com');
    expect(returning.role, UserRole.customer);

    await repo.signOut();
    await expectLater(
      repo.signInWithPassword(
        method: AuthMethod.email,
        identifier: 'amaka@example.com',
        password: 'wrongpass1',
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('demo phone password account normalises the number', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = DemoAuthRepository(prefs);

    final created = await repo.signUpWithPassword(
      method: AuthMethod.phone,
      identifier: '0803 123 4567',
      password: 'strongpass1',
      displayName: 'Chidi Eze',
      role: UserRole.business,
    );
    expect(created.phone, '+2348031234567');
    expect(created.email, isNull);

    await repo.signOut();
    final returning = await repo.signInWithPassword(
      method: AuthMethod.phone,
      identifier: '8031234567',
      password: 'strongpass1',
    );
    expect(returning.phone, '+2348031234567');
    expect(returning.displayName, 'Chidi Eze');
    expect(returning.role, UserRole.business);
  });

  test('demo password sign-up rejects a duplicate account', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = DemoAuthRepository(prefs);

    await repo.signUpWithPassword(
      method: AuthMethod.email,
      identifier: 'amaka@example.com',
      password: 'strongpass1',
      displayName: 'Amaka Okafor',
      role: UserRole.customer,
    );

    await expectLater(
      repo.signUpWithPassword(
        method: AuthMethod.email,
        identifier: 'amaka@example.com',
        password: 'anotherpass1',
        displayName: 'Amaka Okafor',
        role: UserRole.customer,
      ),
      throwsA(
        isA<AppFailure>().having(
          (error) => error.code,
          'code',
          'account_exists',
        ),
      ),
    );
  });

  test('demo OTP is six digits and stable per phone number', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = DemoAuthRepository(prefs);

    final first = await repo.requestOtp('0803 123 4567');
    final again = await repo.requestOtp('08031234567');
    final other = await repo.requestOtp('0812 123 4567');

    expect(first.demoCode, matches(RegExp(r'^\d{6}$')));
    expect(again.demoCode, first.demoCode);
    expect(other.demoCode, isNot(first.demoCode));

    final user = await repo.verifyOtp(
      phone: '08031234567',
      code: first.demoCode!,
      role: UserRole.customer,
      challenge: first,
    );
    expect(user.phone, '+2348031234567');

    await repo.updateProfile(
      displayName: 'Amaka Okafor',
      email: 'amaka@example.com',
    );
    expect(repo.currentUser?.displayName, 'Amaka Okafor');
    expect(repo.currentUser?.email, 'amaka@example.com');

    await repo.signOut();
    final returningChallenge = await repo.requestOtp('08031234567');
    expect(returningChallenge.demoCode, first.demoCode);
    final returningUser = await repo.verifyOtp(
      phone: '08031234567',
      code: returningChallenge.demoCode!,
      role: UserRole.customer,
      challenge: returningChallenge,
    );
    expect(returningUser.displayName, 'Amaka Okafor');
    expect(returningUser.email, 'amaka@example.com');
  });

  test('demo OTP rejects a different code', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = DemoAuthRepository(prefs);

    final challenge = await repo.requestOtp('08031234567');
    final wrong = challenge.demoCode == '000000' ? '111111' : '000000';

    await expectLater(
      repo.verifyOtp(
        phone: '08031234567',
        code: wrong,
        role: UserRole.customer,
        challenge: challenge,
      ),
      throwsA(isA<AppFailure>()),
    );
  });
}
