import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kProfileAvatarShapeKey = 'profile_avatar_shape';

/// Shape of the top-bar mesh profile control.
enum ProfileAvatarShape {
  /// Rounded square (reference top-bar design). Default.
  rounded,

  /// Full circle.
  circle,
}

extension ProfileAvatarShapeX on ProfileAvatarShape {
  String get storageValue => name;

  String get label => switch (this) {
    ProfileAvatarShape.rounded => 'Rounded',
    ProfileAvatarShape.circle => 'Circle',
  };

  static ProfileAvatarShape fromStorage(String? value) {
    return ProfileAvatarShape.values.firstWhere(
      (ProfileAvatarShape s) => s.name == value,
      orElse: () => ProfileAvatarShape.rounded,
    );
  }
}

final profileAvatarShapeProvider =
    StateNotifierProvider<ProfileAvatarShapeNotifier, ProfileAvatarShape>(
  (Ref ref) => ProfileAvatarShapeNotifier(),
);

class ProfileAvatarShapeNotifier extends StateNotifier<ProfileAvatarShape> {
  ProfileAvatarShapeNotifier() : super(ProfileAvatarShape.rounded) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = ProfileAvatarShapeX.fromStorage(
      prefs.getString(_kProfileAvatarShapeKey),
    );
  }

  Future<void> setShape(ProfileAvatarShape shape) async {
    if (state == shape) return;
    state = shape;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileAvatarShapeKey, shape.storageValue);
  }

  Future<void> toggle() async {
    await setShape(
      state == ProfileAvatarShape.rounded
          ? ProfileAvatarShape.circle
          : ProfileAvatarShape.rounded,
    );
  }
}
