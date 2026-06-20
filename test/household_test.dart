import 'package:test/test.dart';
import 'package:keemos_sdk/src/models_household.dart';
import 'package:keemos_sdk/src/generated/household_models.dart';

void main() {
  test('Household.fromJson supports household_id', () {
    final h = Household.fromJson({
      'household_id': 'abc',
      'name': 'Home',
      'address': 'Addr',
      'city': 'Ha Noi',
      'type': 'villa',
    });
    expect(h.householdId, 'abc');
    expect(h.name, 'Home');
    expect(h.address, 'Addr');
    expect(h.city, 'Ha Noi');
    expect(h.type, 'villa');
  });

  test('Household.fromJson supports householdId', () {
    final h = Household.fromJson({'householdId': 'abc', 'name': 'Home'});
    expect(h.householdId, 'abc');
    expect(h.name, 'Home');
  });

  test('Household.fromJson supports id fallback', () {
    final h = Household.fromJson({'id': 'abc', 'name': 'Home'});
    expect(h.householdId, 'abc');
    expect(h.name, 'Home');
  });

  test('Household.toJson includes optional location fields when present', () {
    final h = Household(
      householdId: 'abc',
      name: 'Home',
      address: '456 XYZ',
      city: 'Ha Noi',
      type: 'villa',
    );
    final out = h.toJson();
    expect(out['household_id'], 'abc');
    expect(out['name'], 'Home');
    expect(out['address'], '456 XYZ');
    expect(out['city'], 'Ha Noi');
    expect(out['type'], 'villa');
  });

  test('HouseholdModel.fromJson keeps id fallback behavior', () {
    final h = HouseholdModel.fromJson({'id': 'abc', 'name': 'Home'});
    expect(h.id, 'abc');
    expect(h.name, 'Home');
  });

  test('HouseholdMember.fromJson supports common key variants', () {
    final m = HouseholdMember.fromJson({
      'id': 'u1',
      'email': 'member@example.com',
      'name': 'Member Name',
      'householdRole': 'owner',
    });
    expect(m.userId, 'u1');
    expect(m.email, 'member@example.com');
    expect(m.name, 'Member Name');
    expect(m.role, 'owner');
  });

  test('InvitationCodeResponse supports code variants', () {
    final res = InvitationCodeResponse.fromJson({
      'invitation_code': 'ABC123',
      'expires_at': '2026-04-28T10:00:00Z',
    });
    expect(res.code, 'ABC123');
    expect(res.expiresAt, '2026-04-28T10:00:00Z');
  });
}
