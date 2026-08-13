// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarEmojiMeta =
      const VerificationMeta('avatarEmoji');
  @override
  late final GeneratedColumn<String> avatarEmoji = GeneratedColumn<String>(
      'avatar_emoji', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('🍺'));
  static const VerificationMeta _bioMeta = const VerificationMeta('bio');
  @override
  late final GeneratedColumn<String> bio = GeneratedColumn<String>(
      'bio', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _favoriteStylesMeta =
      const VerificationMeta('favoriteStyles');
  @override
  late final GeneratedColumn<String> favoriteStyles = GeneratedColumn<String>(
      'favorite_styles', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _isMeMeta = const VerificationMeta('isMe');
  @override
  late final GeneratedColumn<bool> isMe = GeneratedColumn<bool>(
      'is_me', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_me" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, username, displayName, avatarEmoji, bio, favoriteStyles, isMe];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(Insertable<Profile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('avatar_emoji')) {
      context.handle(
          _avatarEmojiMeta,
          avatarEmoji.isAcceptableOrUnknown(
              data['avatar_emoji']!, _avatarEmojiMeta));
    }
    if (data.containsKey('bio')) {
      context.handle(
          _bioMeta, bio.isAcceptableOrUnknown(data['bio']!, _bioMeta));
    }
    if (data.containsKey('favorite_styles')) {
      context.handle(
          _favoriteStylesMeta,
          favoriteStyles.isAcceptableOrUnknown(
              data['favorite_styles']!, _favoriteStylesMeta));
    }
    if (data.containsKey('is_me')) {
      context.handle(
          _isMeMeta, isMe.isAcceptableOrUnknown(data['is_me']!, _isMeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      avatarEmoji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_emoji'])!,
      bio: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bio']),
      favoriteStyles: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}favorite_styles'])!,
      isMe: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_me'])!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final String id;
  final String username;
  final String displayName;
  final String avatarEmoji;
  final String? bio;
  final String favoriteStyles;
  final bool isMe;
  const Profile(
      {required this.id,
      required this.username,
      required this.displayName,
      required this.avatarEmoji,
      this.bio,
      required this.favoriteStyles,
      required this.isMe});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['username'] = Variable<String>(username);
    map['display_name'] = Variable<String>(displayName);
    map['avatar_emoji'] = Variable<String>(avatarEmoji);
    if (!nullToAbsent || bio != null) {
      map['bio'] = Variable<String>(bio);
    }
    map['favorite_styles'] = Variable<String>(favoriteStyles);
    map['is_me'] = Variable<bool>(isMe);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      username: Value(username),
      displayName: Value(displayName),
      avatarEmoji: Value(avatarEmoji),
      bio: bio == null && nullToAbsent ? const Value.absent() : Value(bio),
      favoriteStyles: Value(favoriteStyles),
      isMe: Value(isMe),
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      username: serializer.fromJson<String>(json['username']),
      displayName: serializer.fromJson<String>(json['displayName']),
      avatarEmoji: serializer.fromJson<String>(json['avatarEmoji']),
      bio: serializer.fromJson<String?>(json['bio']),
      favoriteStyles: serializer.fromJson<String>(json['favoriteStyles']),
      isMe: serializer.fromJson<bool>(json['isMe']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'username': serializer.toJson<String>(username),
      'displayName': serializer.toJson<String>(displayName),
      'avatarEmoji': serializer.toJson<String>(avatarEmoji),
      'bio': serializer.toJson<String?>(bio),
      'favoriteStyles': serializer.toJson<String>(favoriteStyles),
      'isMe': serializer.toJson<bool>(isMe),
    };
  }

  Profile copyWith(
          {String? id,
          String? username,
          String? displayName,
          String? avatarEmoji,
          Value<String?> bio = const Value.absent(),
          String? favoriteStyles,
          bool? isMe}) =>
      Profile(
        id: id ?? this.id,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        bio: bio.present ? bio.value : this.bio,
        favoriteStyles: favoriteStyles ?? this.favoriteStyles,
        isMe: isMe ?? this.isMe,
      );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      avatarEmoji:
          data.avatarEmoji.present ? data.avatarEmoji.value : this.avatarEmoji,
      bio: data.bio.present ? data.bio.value : this.bio,
      favoriteStyles: data.favoriteStyles.present
          ? data.favoriteStyles.value
          : this.favoriteStyles,
      isMe: data.isMe.present ? data.isMe.value : this.isMe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('bio: $bio, ')
          ..write('favoriteStyles: $favoriteStyles, ')
          ..write('isMe: $isMe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, username, displayName, avatarEmoji, bio, favoriteStyles, isMe);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.username == this.username &&
          other.displayName == this.displayName &&
          other.avatarEmoji == this.avatarEmoji &&
          other.bio == this.bio &&
          other.favoriteStyles == this.favoriteStyles &&
          other.isMe == this.isMe);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String> username;
  final Value<String> displayName;
  final Value<String> avatarEmoji;
  final Value<String?> bio;
  final Value<String> favoriteStyles;
  final Value<bool> isMe;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarEmoji = const Value.absent(),
    this.bio = const Value.absent(),
    this.favoriteStyles = const Value.absent(),
    this.isMe = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String username,
    required String displayName,
    this.avatarEmoji = const Value.absent(),
    this.bio = const Value.absent(),
    this.favoriteStyles = const Value.absent(),
    this.isMe = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        username = Value(username),
        displayName = Value(displayName);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? username,
    Expression<String>? displayName,
    Expression<String>? avatarEmoji,
    Expression<String>? bio,
    Expression<String>? favoriteStyles,
    Expression<bool>? isMe,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (displayName != null) 'display_name': displayName,
      if (avatarEmoji != null) 'avatar_emoji': avatarEmoji,
      if (bio != null) 'bio': bio,
      if (favoriteStyles != null) 'favorite_styles': favoriteStyles,
      if (isMe != null) 'is_me': isMe,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? username,
      Value<String>? displayName,
      Value<String>? avatarEmoji,
      Value<String?>? bio,
      Value<String>? favoriteStyles,
      Value<bool>? isMe,
      Value<int>? rowid}) {
    return ProfilesCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      bio: bio ?? this.bio,
      favoriteStyles: favoriteStyles ?? this.favoriteStyles,
      isMe: isMe ?? this.isMe,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarEmoji.present) {
      map['avatar_emoji'] = Variable<String>(avatarEmoji.value);
    }
    if (bio.present) {
      map['bio'] = Variable<String>(bio.value);
    }
    if (favoriteStyles.present) {
      map['favorite_styles'] = Variable<String>(favoriteStyles.value);
    }
    if (isMe.present) {
      map['is_me'] = Variable<bool>(isMe.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('bio: $bio, ')
          ..write('favoriteStyles: $favoriteStyles, ')
          ..write('isMe: $isMe, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BreweriesTable extends Breweries
    with TableInfo<$BreweriesTable, Brewery> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BreweriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _countryMeta =
      const VerificationMeta('country');
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
      'country', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _foundedMeta =
      const VerificationMeta('founded');
  @override
  late final GeneratedColumn<int> founded = GeneratedColumn<int>(
      'founded', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _websiteMeta =
      const VerificationMeta('website');
  @override
  late final GeneratedColumn<String> website = GeneratedColumn<String>(
      'website', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ownershipMeta =
      const VerificationMeta('ownership');
  @override
  late final GeneratedColumn<String> ownership = GeneratedColumn<String>(
      'ownership', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _employeesMeta =
      const VerificationMeta('employees');
  @override
  late final GeneratedColumn<int> employees = GeneratedColumn<int>(
      'employees', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _annualOutputHlMeta =
      const VerificationMeta('annualOutputHl');
  @override
  late final GeneratedColumn<int> annualOutputHl = GeneratedColumn<int>(
      'annual_output_hl', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _revenueEurMeta =
      const VerificationMeta('revenueEur');
  @override
  late final GeneratedColumn<int> revenueEur = GeneratedColumn<int>(
      'revenue_eur', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dataStatusMeta =
      const VerificationMeta('dataStatus');
  @override
  late final GeneratedColumn<String> dataStatus = GeneratedColumn<String>(
      'data_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        country,
        city,
        address,
        latitude,
        longitude,
        founded,
        website,
        ownership,
        employees,
        annualOutputHl,
        revenueEur,
        notes,
        dataStatus
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'breweries';
  @override
  VerificationContext validateIntegrity(Insertable<Brewery> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('country')) {
      context.handle(_countryMeta,
          country.isAcceptableOrUnknown(data['country']!, _countryMeta));
    } else if (isInserting) {
      context.missing(_countryMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('founded')) {
      context.handle(_foundedMeta,
          founded.isAcceptableOrUnknown(data['founded']!, _foundedMeta));
    }
    if (data.containsKey('website')) {
      context.handle(_websiteMeta,
          website.isAcceptableOrUnknown(data['website']!, _websiteMeta));
    }
    if (data.containsKey('ownership')) {
      context.handle(_ownershipMeta,
          ownership.isAcceptableOrUnknown(data['ownership']!, _ownershipMeta));
    }
    if (data.containsKey('employees')) {
      context.handle(_employeesMeta,
          employees.isAcceptableOrUnknown(data['employees']!, _employeesMeta));
    }
    if (data.containsKey('annual_output_hl')) {
      context.handle(
          _annualOutputHlMeta,
          annualOutputHl.isAcceptableOrUnknown(
              data['annual_output_hl']!, _annualOutputHlMeta));
    }
    if (data.containsKey('revenue_eur')) {
      context.handle(
          _revenueEurMeta,
          revenueEur.isAcceptableOrUnknown(
              data['revenue_eur']!, _revenueEurMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('data_status')) {
      context.handle(
          _dataStatusMeta,
          dataStatus.isAcceptableOrUnknown(
              data['data_status']!, _dataStatusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Brewery map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Brewery(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      country: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}country'])!,
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      founded: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}founded']),
      website: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}website']),
      ownership: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ownership']),
      employees: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}employees']),
      annualOutputHl: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}annual_output_hl']),
      revenueEur: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revenue_eur']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      dataStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_status']),
    );
  }

  @override
  $BreweriesTable createAlias(String alias) {
    return $BreweriesTable(attachedDatabase, alias);
  }
}

class Brewery extends DataClass implements Insertable<Brewery> {
  final String id;
  final String name;
  final String country;
  final String city;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? founded;
  final String? website;
  final String? ownership;
  final int? employees;
  final int? annualOutputHl;
  final int? revenueEur;
  final String? notes;
  final String? dataStatus;
  const Brewery(
      {required this.id,
      required this.name,
      required this.country,
      required this.city,
      this.address,
      this.latitude,
      this.longitude,
      this.founded,
      this.website,
      this.ownership,
      this.employees,
      this.annualOutputHl,
      this.revenueEur,
      this.notes,
      this.dataStatus});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['country'] = Variable<String>(country);
    map['city'] = Variable<String>(city);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || founded != null) {
      map['founded'] = Variable<int>(founded);
    }
    if (!nullToAbsent || website != null) {
      map['website'] = Variable<String>(website);
    }
    if (!nullToAbsent || ownership != null) {
      map['ownership'] = Variable<String>(ownership);
    }
    if (!nullToAbsent || employees != null) {
      map['employees'] = Variable<int>(employees);
    }
    if (!nullToAbsent || annualOutputHl != null) {
      map['annual_output_hl'] = Variable<int>(annualOutputHl);
    }
    if (!nullToAbsent || revenueEur != null) {
      map['revenue_eur'] = Variable<int>(revenueEur);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || dataStatus != null) {
      map['data_status'] = Variable<String>(dataStatus);
    }
    return map;
  }

  BreweriesCompanion toCompanion(bool nullToAbsent) {
    return BreweriesCompanion(
      id: Value(id),
      name: Value(name),
      country: Value(country),
      city: Value(city),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      founded: founded == null && nullToAbsent
          ? const Value.absent()
          : Value(founded),
      website: website == null && nullToAbsent
          ? const Value.absent()
          : Value(website),
      ownership: ownership == null && nullToAbsent
          ? const Value.absent()
          : Value(ownership),
      employees: employees == null && nullToAbsent
          ? const Value.absent()
          : Value(employees),
      annualOutputHl: annualOutputHl == null && nullToAbsent
          ? const Value.absent()
          : Value(annualOutputHl),
      revenueEur: revenueEur == null && nullToAbsent
          ? const Value.absent()
          : Value(revenueEur),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      dataStatus: dataStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(dataStatus),
    );
  }

  factory Brewery.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Brewery(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      country: serializer.fromJson<String>(json['country']),
      city: serializer.fromJson<String>(json['city']),
      address: serializer.fromJson<String?>(json['address']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      founded: serializer.fromJson<int?>(json['founded']),
      website: serializer.fromJson<String?>(json['website']),
      ownership: serializer.fromJson<String?>(json['ownership']),
      employees: serializer.fromJson<int?>(json['employees']),
      annualOutputHl: serializer.fromJson<int?>(json['annualOutputHl']),
      revenueEur: serializer.fromJson<int?>(json['revenueEur']),
      notes: serializer.fromJson<String?>(json['notes']),
      dataStatus: serializer.fromJson<String?>(json['dataStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'country': serializer.toJson<String>(country),
      'city': serializer.toJson<String>(city),
      'address': serializer.toJson<String?>(address),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'founded': serializer.toJson<int?>(founded),
      'website': serializer.toJson<String?>(website),
      'ownership': serializer.toJson<String?>(ownership),
      'employees': serializer.toJson<int?>(employees),
      'annualOutputHl': serializer.toJson<int?>(annualOutputHl),
      'revenueEur': serializer.toJson<int?>(revenueEur),
      'notes': serializer.toJson<String?>(notes),
      'dataStatus': serializer.toJson<String?>(dataStatus),
    };
  }

  Brewery copyWith(
          {String? id,
          String? name,
          String? country,
          String? city,
          Value<String?> address = const Value.absent(),
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          Value<int?> founded = const Value.absent(),
          Value<String?> website = const Value.absent(),
          Value<String?> ownership = const Value.absent(),
          Value<int?> employees = const Value.absent(),
          Value<int?> annualOutputHl = const Value.absent(),
          Value<int?> revenueEur = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<String?> dataStatus = const Value.absent()}) =>
      Brewery(
        id: id ?? this.id,
        name: name ?? this.name,
        country: country ?? this.country,
        city: city ?? this.city,
        address: address.present ? address.value : this.address,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        founded: founded.present ? founded.value : this.founded,
        website: website.present ? website.value : this.website,
        ownership: ownership.present ? ownership.value : this.ownership,
        employees: employees.present ? employees.value : this.employees,
        annualOutputHl:
            annualOutputHl.present ? annualOutputHl.value : this.annualOutputHl,
        revenueEur: revenueEur.present ? revenueEur.value : this.revenueEur,
        notes: notes.present ? notes.value : this.notes,
        dataStatus: dataStatus.present ? dataStatus.value : this.dataStatus,
      );
  Brewery copyWithCompanion(BreweriesCompanion data) {
    return Brewery(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      country: data.country.present ? data.country.value : this.country,
      city: data.city.present ? data.city.value : this.city,
      address: data.address.present ? data.address.value : this.address,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      founded: data.founded.present ? data.founded.value : this.founded,
      website: data.website.present ? data.website.value : this.website,
      ownership: data.ownership.present ? data.ownership.value : this.ownership,
      employees: data.employees.present ? data.employees.value : this.employees,
      annualOutputHl: data.annualOutputHl.present
          ? data.annualOutputHl.value
          : this.annualOutputHl,
      revenueEur:
          data.revenueEur.present ? data.revenueEur.value : this.revenueEur,
      notes: data.notes.present ? data.notes.value : this.notes,
      dataStatus:
          data.dataStatus.present ? data.dataStatus.value : this.dataStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Brewery(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('city: $city, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('founded: $founded, ')
          ..write('website: $website, ')
          ..write('ownership: $ownership, ')
          ..write('employees: $employees, ')
          ..write('annualOutputHl: $annualOutputHl, ')
          ..write('revenueEur: $revenueEur, ')
          ..write('notes: $notes, ')
          ..write('dataStatus: $dataStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      country,
      city,
      address,
      latitude,
      longitude,
      founded,
      website,
      ownership,
      employees,
      annualOutputHl,
      revenueEur,
      notes,
      dataStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Brewery &&
          other.id == this.id &&
          other.name == this.name &&
          other.country == this.country &&
          other.city == this.city &&
          other.address == this.address &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.founded == this.founded &&
          other.website == this.website &&
          other.ownership == this.ownership &&
          other.employees == this.employees &&
          other.annualOutputHl == this.annualOutputHl &&
          other.revenueEur == this.revenueEur &&
          other.notes == this.notes &&
          other.dataStatus == this.dataStatus);
}

class BreweriesCompanion extends UpdateCompanion<Brewery> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> country;
  final Value<String> city;
  final Value<String?> address;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int?> founded;
  final Value<String?> website;
  final Value<String?> ownership;
  final Value<int?> employees;
  final Value<int?> annualOutputHl;
  final Value<int?> revenueEur;
  final Value<String?> notes;
  final Value<String?> dataStatus;
  final Value<int> rowid;
  const BreweriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.country = const Value.absent(),
    this.city = const Value.absent(),
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.founded = const Value.absent(),
    this.website = const Value.absent(),
    this.ownership = const Value.absent(),
    this.employees = const Value.absent(),
    this.annualOutputHl = const Value.absent(),
    this.revenueEur = const Value.absent(),
    this.notes = const Value.absent(),
    this.dataStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BreweriesCompanion.insert({
    required String id,
    required String name,
    required String country,
    required String city,
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.founded = const Value.absent(),
    this.website = const Value.absent(),
    this.ownership = const Value.absent(),
    this.employees = const Value.absent(),
    this.annualOutputHl = const Value.absent(),
    this.revenueEur = const Value.absent(),
    this.notes = const Value.absent(),
    this.dataStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        country = Value(country),
        city = Value(city);
  static Insertable<Brewery> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? country,
    Expression<String>? city,
    Expression<String>? address,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? founded,
    Expression<String>? website,
    Expression<String>? ownership,
    Expression<int>? employees,
    Expression<int>? annualOutputHl,
    Expression<int>? revenueEur,
    Expression<String>? notes,
    Expression<String>? dataStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (country != null) 'country': country,
      if (city != null) 'city': city,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (founded != null) 'founded': founded,
      if (website != null) 'website': website,
      if (ownership != null) 'ownership': ownership,
      if (employees != null) 'employees': employees,
      if (annualOutputHl != null) 'annual_output_hl': annualOutputHl,
      if (revenueEur != null) 'revenue_eur': revenueEur,
      if (notes != null) 'notes': notes,
      if (dataStatus != null) 'data_status': dataStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BreweriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? country,
      Value<String>? city,
      Value<String?>? address,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<int?>? founded,
      Value<String?>? website,
      Value<String?>? ownership,
      Value<int?>? employees,
      Value<int?>? annualOutputHl,
      Value<int?>? revenueEur,
      Value<String?>? notes,
      Value<String?>? dataStatus,
      Value<int>? rowid}) {
    return BreweriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      city: city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      founded: founded ?? this.founded,
      website: website ?? this.website,
      ownership: ownership ?? this.ownership,
      employees: employees ?? this.employees,
      annualOutputHl: annualOutputHl ?? this.annualOutputHl,
      revenueEur: revenueEur ?? this.revenueEur,
      notes: notes ?? this.notes,
      dataStatus: dataStatus ?? this.dataStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (founded.present) {
      map['founded'] = Variable<int>(founded.value);
    }
    if (website.present) {
      map['website'] = Variable<String>(website.value);
    }
    if (ownership.present) {
      map['ownership'] = Variable<String>(ownership.value);
    }
    if (employees.present) {
      map['employees'] = Variable<int>(employees.value);
    }
    if (annualOutputHl.present) {
      map['annual_output_hl'] = Variable<int>(annualOutputHl.value);
    }
    if (revenueEur.present) {
      map['revenue_eur'] = Variable<int>(revenueEur.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (dataStatus.present) {
      map['data_status'] = Variable<String>(dataStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BreweriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('city: $city, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('founded: $founded, ')
          ..write('website: $website, ')
          ..write('ownership: $ownership, ')
          ..write('employees: $employees, ')
          ..write('annualOutputHl: $annualOutputHl, ')
          ..write('revenueEur: $revenueEur, ')
          ..write('notes: $notes, ')
          ..write('dataStatus: $dataStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BeersTable extends Beers with TableInfo<$BeersTable, Beer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BeersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _breweryIdMeta =
      const VerificationMeta('breweryId');
  @override
  late final GeneratedColumn<String> breweryId = GeneratedColumn<String>(
      'brewery_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES breweries (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
      'style', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _abvMeta = const VerificationMeta('abv');
  @override
  late final GeneratedColumn<double> abv = GeneratedColumn<double>(
      'abv', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _ibuMeta = const VerificationMeta('ibu');
  @override
  late final GeneratedColumn<int> ibu = GeneratedColumn<int>(
      'ibu', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isAlcoholFreeMeta =
      const VerificationMeta('isAlcoholFree');
  @override
  late final GeneratedColumn<bool> isAlcoholFree = GeneratedColumn<bool>(
      'is_alcohol_free', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_alcohol_free" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isUserSubmittedMeta =
      const VerificationMeta('isUserSubmitted');
  @override
  late final GeneratedColumn<bool> isUserSubmitted = GeneratedColumn<bool>(
      'is_user_submitted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_user_submitted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _descriptionCommunityMeta =
      const VerificationMeta('descriptionCommunity');
  @override
  late final GeneratedColumn<String> descriptionCommunity =
      GeneratedColumn<String>('description_community', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _communityRatingMeta =
      const VerificationMeta('communityRating');
  @override
  late final GeneratedColumn<double> communityRating = GeneratedColumn<double>(
      'community_rating', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _barcodesMeta =
      const VerificationMeta('barcodes');
  @override
  late final GeneratedColumn<String> barcodes = GeneratedColumn<String>(
      'barcodes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        breweryId,
        name,
        style,
        abv,
        ibu,
        description,
        isAlcoholFree,
        isUserSubmitted,
        descriptionCommunity,
        communityRating,
        barcodes,
        imageUrl
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'beers';
  @override
  VerificationContext validateIntegrity(Insertable<Beer> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('brewery_id')) {
      context.handle(_breweryIdMeta,
          breweryId.isAcceptableOrUnknown(data['brewery_id']!, _breweryIdMeta));
    } else if (isInserting) {
      context.missing(_breweryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('style')) {
      context.handle(
          _styleMeta, style.isAcceptableOrUnknown(data['style']!, _styleMeta));
    } else if (isInserting) {
      context.missing(_styleMeta);
    }
    if (data.containsKey('abv')) {
      context.handle(
          _abvMeta, abv.isAcceptableOrUnknown(data['abv']!, _abvMeta));
    }
    if (data.containsKey('ibu')) {
      context.handle(
          _ibuMeta, ibu.isAcceptableOrUnknown(data['ibu']!, _ibuMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('is_alcohol_free')) {
      context.handle(
          _isAlcoholFreeMeta,
          isAlcoholFree.isAcceptableOrUnknown(
              data['is_alcohol_free']!, _isAlcoholFreeMeta));
    }
    if (data.containsKey('is_user_submitted')) {
      context.handle(
          _isUserSubmittedMeta,
          isUserSubmitted.isAcceptableOrUnknown(
              data['is_user_submitted']!, _isUserSubmittedMeta));
    }
    if (data.containsKey('description_community')) {
      context.handle(
          _descriptionCommunityMeta,
          descriptionCommunity.isAcceptableOrUnknown(
              data['description_community']!, _descriptionCommunityMeta));
    }
    if (data.containsKey('community_rating')) {
      context.handle(
          _communityRatingMeta,
          communityRating.isAcceptableOrUnknown(
              data['community_rating']!, _communityRatingMeta));
    }
    if (data.containsKey('barcodes')) {
      context.handle(_barcodesMeta,
          barcodes.isAcceptableOrUnknown(data['barcodes']!, _barcodesMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Beer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Beer(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      breweryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brewery_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      style: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}style'])!,
      abv: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}abv']),
      ibu: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ibu']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      isAlcoholFree: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_alcohol_free'])!,
      isUserSubmitted: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_user_submitted'])!,
      descriptionCommunity: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}description_community']),
      communityRating: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}community_rating']),
      barcodes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcodes'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
    );
  }

  @override
  $BeersTable createAlias(String alias) {
    return $BeersTable(attachedDatabase, alias);
  }
}

class Beer extends DataClass implements Insertable<Beer> {
  final String id;
  final String breweryId;
  final String name;
  final String style;
  final double? abv;
  final int? ibu;
  final String? description;
  final bool isAlcoholFree;
  final bool isUserSubmitted;

  /// Kundenerfahrungen/Verkostungsnotizen aus der Community-Datenbank.
  final String? descriptionCommunity;

  /// Redaktionelle Community-Bewertung (0–5) aus der Datenbank, kein Messwert.
  final double? communityRating;

  /// Kommagetrennte EAN-Barcodes (8 oder 13 Ziffern), z. B. "90034107".
  final String barcodes;

  /// Etikett-/Produktfoto als URL (Open Food Facts, CC-BY-SA – nur verlinkt).
  final String? imageUrl;
  const Beer(
      {required this.id,
      required this.breweryId,
      required this.name,
      required this.style,
      this.abv,
      this.ibu,
      this.description,
      required this.isAlcoholFree,
      required this.isUserSubmitted,
      this.descriptionCommunity,
      this.communityRating,
      required this.barcodes,
      this.imageUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['brewery_id'] = Variable<String>(breweryId);
    map['name'] = Variable<String>(name);
    map['style'] = Variable<String>(style);
    if (!nullToAbsent || abv != null) {
      map['abv'] = Variable<double>(abv);
    }
    if (!nullToAbsent || ibu != null) {
      map['ibu'] = Variable<int>(ibu);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_alcohol_free'] = Variable<bool>(isAlcoholFree);
    map['is_user_submitted'] = Variable<bool>(isUserSubmitted);
    if (!nullToAbsent || descriptionCommunity != null) {
      map['description_community'] = Variable<String>(descriptionCommunity);
    }
    if (!nullToAbsent || communityRating != null) {
      map['community_rating'] = Variable<double>(communityRating);
    }
    map['barcodes'] = Variable<String>(barcodes);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    return map;
  }

  BeersCompanion toCompanion(bool nullToAbsent) {
    return BeersCompanion(
      id: Value(id),
      breweryId: Value(breweryId),
      name: Value(name),
      style: Value(style),
      abv: abv == null && nullToAbsent ? const Value.absent() : Value(abv),
      ibu: ibu == null && nullToAbsent ? const Value.absent() : Value(ibu),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isAlcoholFree: Value(isAlcoholFree),
      isUserSubmitted: Value(isUserSubmitted),
      descriptionCommunity: descriptionCommunity == null && nullToAbsent
          ? const Value.absent()
          : Value(descriptionCommunity),
      communityRating: communityRating == null && nullToAbsent
          ? const Value.absent()
          : Value(communityRating),
      barcodes: Value(barcodes),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
    );
  }

  factory Beer.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Beer(
      id: serializer.fromJson<String>(json['id']),
      breweryId: serializer.fromJson<String>(json['breweryId']),
      name: serializer.fromJson<String>(json['name']),
      style: serializer.fromJson<String>(json['style']),
      abv: serializer.fromJson<double?>(json['abv']),
      ibu: serializer.fromJson<int?>(json['ibu']),
      description: serializer.fromJson<String?>(json['description']),
      isAlcoholFree: serializer.fromJson<bool>(json['isAlcoholFree']),
      isUserSubmitted: serializer.fromJson<bool>(json['isUserSubmitted']),
      descriptionCommunity:
          serializer.fromJson<String?>(json['descriptionCommunity']),
      communityRating: serializer.fromJson<double?>(json['communityRating']),
      barcodes: serializer.fromJson<String>(json['barcodes']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'breweryId': serializer.toJson<String>(breweryId),
      'name': serializer.toJson<String>(name),
      'style': serializer.toJson<String>(style),
      'abv': serializer.toJson<double?>(abv),
      'ibu': serializer.toJson<int?>(ibu),
      'description': serializer.toJson<String?>(description),
      'isAlcoholFree': serializer.toJson<bool>(isAlcoholFree),
      'isUserSubmitted': serializer.toJson<bool>(isUserSubmitted),
      'descriptionCommunity': serializer.toJson<String?>(descriptionCommunity),
      'communityRating': serializer.toJson<double?>(communityRating),
      'barcodes': serializer.toJson<String>(barcodes),
      'imageUrl': serializer.toJson<String?>(imageUrl),
    };
  }

  Beer copyWith(
          {String? id,
          String? breweryId,
          String? name,
          String? style,
          Value<double?> abv = const Value.absent(),
          Value<int?> ibu = const Value.absent(),
          Value<String?> description = const Value.absent(),
          bool? isAlcoholFree,
          bool? isUserSubmitted,
          Value<String?> descriptionCommunity = const Value.absent(),
          Value<double?> communityRating = const Value.absent(),
          String? barcodes,
          Value<String?> imageUrl = const Value.absent()}) =>
      Beer(
        id: id ?? this.id,
        breweryId: breweryId ?? this.breweryId,
        name: name ?? this.name,
        style: style ?? this.style,
        abv: abv.present ? abv.value : this.abv,
        ibu: ibu.present ? ibu.value : this.ibu,
        description: description.present ? description.value : this.description,
        isAlcoholFree: isAlcoholFree ?? this.isAlcoholFree,
        isUserSubmitted: isUserSubmitted ?? this.isUserSubmitted,
        descriptionCommunity: descriptionCommunity.present
            ? descriptionCommunity.value
            : this.descriptionCommunity,
        communityRating: communityRating.present
            ? communityRating.value
            : this.communityRating,
        barcodes: barcodes ?? this.barcodes,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
      );
  Beer copyWithCompanion(BeersCompanion data) {
    return Beer(
      id: data.id.present ? data.id.value : this.id,
      breweryId: data.breweryId.present ? data.breweryId.value : this.breweryId,
      name: data.name.present ? data.name.value : this.name,
      style: data.style.present ? data.style.value : this.style,
      abv: data.abv.present ? data.abv.value : this.abv,
      ibu: data.ibu.present ? data.ibu.value : this.ibu,
      description:
          data.description.present ? data.description.value : this.description,
      isAlcoholFree: data.isAlcoholFree.present
          ? data.isAlcoholFree.value
          : this.isAlcoholFree,
      isUserSubmitted: data.isUserSubmitted.present
          ? data.isUserSubmitted.value
          : this.isUserSubmitted,
      descriptionCommunity: data.descriptionCommunity.present
          ? data.descriptionCommunity.value
          : this.descriptionCommunity,
      communityRating: data.communityRating.present
          ? data.communityRating.value
          : this.communityRating,
      barcodes: data.barcodes.present ? data.barcodes.value : this.barcodes,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Beer(')
          ..write('id: $id, ')
          ..write('breweryId: $breweryId, ')
          ..write('name: $name, ')
          ..write('style: $style, ')
          ..write('abv: $abv, ')
          ..write('ibu: $ibu, ')
          ..write('description: $description, ')
          ..write('isAlcoholFree: $isAlcoholFree, ')
          ..write('isUserSubmitted: $isUserSubmitted, ')
          ..write('descriptionCommunity: $descriptionCommunity, ')
          ..write('communityRating: $communityRating, ')
          ..write('barcodes: $barcodes, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      breweryId,
      name,
      style,
      abv,
      ibu,
      description,
      isAlcoholFree,
      isUserSubmitted,
      descriptionCommunity,
      communityRating,
      barcodes,
      imageUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Beer &&
          other.id == this.id &&
          other.breweryId == this.breweryId &&
          other.name == this.name &&
          other.style == this.style &&
          other.abv == this.abv &&
          other.ibu == this.ibu &&
          other.description == this.description &&
          other.isAlcoholFree == this.isAlcoholFree &&
          other.isUserSubmitted == this.isUserSubmitted &&
          other.descriptionCommunity == this.descriptionCommunity &&
          other.communityRating == this.communityRating &&
          other.barcodes == this.barcodes &&
          other.imageUrl == this.imageUrl);
}

class BeersCompanion extends UpdateCompanion<Beer> {
  final Value<String> id;
  final Value<String> breweryId;
  final Value<String> name;
  final Value<String> style;
  final Value<double?> abv;
  final Value<int?> ibu;
  final Value<String?> description;
  final Value<bool> isAlcoholFree;
  final Value<bool> isUserSubmitted;
  final Value<String?> descriptionCommunity;
  final Value<double?> communityRating;
  final Value<String> barcodes;
  final Value<String?> imageUrl;
  final Value<int> rowid;
  const BeersCompanion({
    this.id = const Value.absent(),
    this.breweryId = const Value.absent(),
    this.name = const Value.absent(),
    this.style = const Value.absent(),
    this.abv = const Value.absent(),
    this.ibu = const Value.absent(),
    this.description = const Value.absent(),
    this.isAlcoholFree = const Value.absent(),
    this.isUserSubmitted = const Value.absent(),
    this.descriptionCommunity = const Value.absent(),
    this.communityRating = const Value.absent(),
    this.barcodes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BeersCompanion.insert({
    required String id,
    required String breweryId,
    required String name,
    required String style,
    this.abv = const Value.absent(),
    this.ibu = const Value.absent(),
    this.description = const Value.absent(),
    this.isAlcoholFree = const Value.absent(),
    this.isUserSubmitted = const Value.absent(),
    this.descriptionCommunity = const Value.absent(),
    this.communityRating = const Value.absent(),
    this.barcodes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        breweryId = Value(breweryId),
        name = Value(name),
        style = Value(style);
  static Insertable<Beer> custom({
    Expression<String>? id,
    Expression<String>? breweryId,
    Expression<String>? name,
    Expression<String>? style,
    Expression<double>? abv,
    Expression<int>? ibu,
    Expression<String>? description,
    Expression<bool>? isAlcoholFree,
    Expression<bool>? isUserSubmitted,
    Expression<String>? descriptionCommunity,
    Expression<double>? communityRating,
    Expression<String>? barcodes,
    Expression<String>? imageUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (breweryId != null) 'brewery_id': breweryId,
      if (name != null) 'name': name,
      if (style != null) 'style': style,
      if (abv != null) 'abv': abv,
      if (ibu != null) 'ibu': ibu,
      if (description != null) 'description': description,
      if (isAlcoholFree != null) 'is_alcohol_free': isAlcoholFree,
      if (isUserSubmitted != null) 'is_user_submitted': isUserSubmitted,
      if (descriptionCommunity != null)
        'description_community': descriptionCommunity,
      if (communityRating != null) 'community_rating': communityRating,
      if (barcodes != null) 'barcodes': barcodes,
      if (imageUrl != null) 'image_url': imageUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BeersCompanion copyWith(
      {Value<String>? id,
      Value<String>? breweryId,
      Value<String>? name,
      Value<String>? style,
      Value<double?>? abv,
      Value<int?>? ibu,
      Value<String?>? description,
      Value<bool>? isAlcoholFree,
      Value<bool>? isUserSubmitted,
      Value<String?>? descriptionCommunity,
      Value<double?>? communityRating,
      Value<String>? barcodes,
      Value<String?>? imageUrl,
      Value<int>? rowid}) {
    return BeersCompanion(
      id: id ?? this.id,
      breweryId: breweryId ?? this.breweryId,
      name: name ?? this.name,
      style: style ?? this.style,
      abv: abv ?? this.abv,
      ibu: ibu ?? this.ibu,
      description: description ?? this.description,
      isAlcoholFree: isAlcoholFree ?? this.isAlcoholFree,
      isUserSubmitted: isUserSubmitted ?? this.isUserSubmitted,
      descriptionCommunity: descriptionCommunity ?? this.descriptionCommunity,
      communityRating: communityRating ?? this.communityRating,
      barcodes: barcodes ?? this.barcodes,
      imageUrl: imageUrl ?? this.imageUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (breweryId.present) {
      map['brewery_id'] = Variable<String>(breweryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (abv.present) {
      map['abv'] = Variable<double>(abv.value);
    }
    if (ibu.present) {
      map['ibu'] = Variable<int>(ibu.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isAlcoholFree.present) {
      map['is_alcohol_free'] = Variable<bool>(isAlcoholFree.value);
    }
    if (isUserSubmitted.present) {
      map['is_user_submitted'] = Variable<bool>(isUserSubmitted.value);
    }
    if (descriptionCommunity.present) {
      map['description_community'] =
          Variable<String>(descriptionCommunity.value);
    }
    if (communityRating.present) {
      map['community_rating'] = Variable<double>(communityRating.value);
    }
    if (barcodes.present) {
      map['barcodes'] = Variable<String>(barcodes.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BeersCompanion(')
          ..write('id: $id, ')
          ..write('breweryId: $breweryId, ')
          ..write('name: $name, ')
          ..write('style: $style, ')
          ..write('abv: $abv, ')
          ..write('ibu: $ibu, ')
          ..write('description: $description, ')
          ..write('isAlcoholFree: $isAlcoholFree, ')
          ..write('isUserSubmitted: $isUserSubmitted, ')
          ..write('descriptionCommunity: $descriptionCommunity, ')
          ..write('communityRating: $communityRating, ')
          ..write('barcodes: $barcodes, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VenuesTable extends Venues with TableInfo<$VenuesTable, Venue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VenuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('gasthaus'));
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _openingHoursMeta =
      const VerificationMeta('openingHours');
  @override
  late final GeneratedColumn<String> openingHours = GeneratedColumn<String>(
      'opening_hours', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priceHalfLMeta =
      const VerificationMeta('priceHalfL');
  @override
  late final GeneratedColumn<double> priceHalfL = GeneratedColumn<double>(
      'price_half_l', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _priceThirdLMeta =
      const VerificationMeta('priceThirdL');
  @override
  late final GeneratedColumn<double> priceThirdL = GeneratedColumn<double>(
      'price_third_l', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _verifiedMeta =
      const VerificationMeta('verified');
  @override
  late final GeneratedColumn<bool> verified = GeneratedColumn<bool>(
      'verified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("verified" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        category,
        address,
        city,
        latitude,
        longitude,
        openingHours,
        priceHalfL,
        priceThirdL,
        verified,
        createdBy,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'venues';
  @override
  VerificationContext validateIntegrity(Insertable<Venue> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('opening_hours')) {
      context.handle(
          _openingHoursMeta,
          openingHours.isAcceptableOrUnknown(
              data['opening_hours']!, _openingHoursMeta));
    }
    if (data.containsKey('price_half_l')) {
      context.handle(
          _priceHalfLMeta,
          priceHalfL.isAcceptableOrUnknown(
              data['price_half_l']!, _priceHalfLMeta));
    }
    if (data.containsKey('price_third_l')) {
      context.handle(
          _priceThirdLMeta,
          priceThirdL.isAcceptableOrUnknown(
              data['price_third_l']!, _priceThirdLMeta));
    }
    if (data.containsKey('verified')) {
      context.handle(_verifiedMeta,
          verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Venue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Venue(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city']),
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      openingHours: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}opening_hours']),
      priceHalfL: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price_half_l']),
      priceThirdL: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price_third_l']),
      verified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}verified'])!,
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $VenuesTable createAlias(String alias) {
    return $VenuesTable(attachedDatabase, alias);
  }
}

class Venue extends DataClass implements Insertable<Venue> {
  final String id;
  final String name;
  final String category;
  final String? address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? openingHours;
  final double? priceHalfL;
  final double? priceThirdL;
  final bool verified;
  final String? createdBy;
  final DateTime? updatedAt;
  const Venue(
      {required this.id,
      required this.name,
      required this.category,
      this.address,
      this.city,
      this.latitude,
      this.longitude,
      this.openingHours,
      this.priceHalfL,
      this.priceThirdL,
      required this.verified,
      this.createdBy,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || openingHours != null) {
      map['opening_hours'] = Variable<String>(openingHours);
    }
    if (!nullToAbsent || priceHalfL != null) {
      map['price_half_l'] = Variable<double>(priceHalfL);
    }
    if (!nullToAbsent || priceThirdL != null) {
      map['price_third_l'] = Variable<double>(priceThirdL);
    }
    map['verified'] = Variable<bool>(verified);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  VenuesCompanion toCompanion(bool nullToAbsent) {
    return VenuesCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      openingHours: openingHours == null && nullToAbsent
          ? const Value.absent()
          : Value(openingHours),
      priceHalfL: priceHalfL == null && nullToAbsent
          ? const Value.absent()
          : Value(priceHalfL),
      priceThirdL: priceThirdL == null && nullToAbsent
          ? const Value.absent()
          : Value(priceThirdL),
      verified: Value(verified),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Venue.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Venue(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      address: serializer.fromJson<String?>(json['address']),
      city: serializer.fromJson<String?>(json['city']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      openingHours: serializer.fromJson<String?>(json['openingHours']),
      priceHalfL: serializer.fromJson<double?>(json['priceHalfL']),
      priceThirdL: serializer.fromJson<double?>(json['priceThirdL']),
      verified: serializer.fromJson<bool>(json['verified']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'address': serializer.toJson<String?>(address),
      'city': serializer.toJson<String?>(city),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'openingHours': serializer.toJson<String?>(openingHours),
      'priceHalfL': serializer.toJson<double?>(priceHalfL),
      'priceThirdL': serializer.toJson<double?>(priceThirdL),
      'verified': serializer.toJson<bool>(verified),
      'createdBy': serializer.toJson<String?>(createdBy),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Venue copyWith(
          {String? id,
          String? name,
          String? category,
          Value<String?> address = const Value.absent(),
          Value<String?> city = const Value.absent(),
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          Value<String?> openingHours = const Value.absent(),
          Value<double?> priceHalfL = const Value.absent(),
          Value<double?> priceThirdL = const Value.absent(),
          bool? verified,
          Value<String?> createdBy = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      Venue(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        address: address.present ? address.value : this.address,
        city: city.present ? city.value : this.city,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        openingHours:
            openingHours.present ? openingHours.value : this.openingHours,
        priceHalfL: priceHalfL.present ? priceHalfL.value : this.priceHalfL,
        priceThirdL: priceThirdL.present ? priceThirdL.value : this.priceThirdL,
        verified: verified ?? this.verified,
        createdBy: createdBy.present ? createdBy.value : this.createdBy,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  Venue copyWithCompanion(VenuesCompanion data) {
    return Venue(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      address: data.address.present ? data.address.value : this.address,
      city: data.city.present ? data.city.value : this.city,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      openingHours: data.openingHours.present
          ? data.openingHours.value
          : this.openingHours,
      priceHalfL:
          data.priceHalfL.present ? data.priceHalfL.value : this.priceHalfL,
      priceThirdL:
          data.priceThirdL.present ? data.priceThirdL.value : this.priceThirdL,
      verified: data.verified.present ? data.verified.value : this.verified,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Venue(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('openingHours: $openingHours, ')
          ..write('priceHalfL: $priceHalfL, ')
          ..write('priceThirdL: $priceThirdL, ')
          ..write('verified: $verified, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      category,
      address,
      city,
      latitude,
      longitude,
      openingHours,
      priceHalfL,
      priceThirdL,
      verified,
      createdBy,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Venue &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.address == this.address &&
          other.city == this.city &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.openingHours == this.openingHours &&
          other.priceHalfL == this.priceHalfL &&
          other.priceThirdL == this.priceThirdL &&
          other.verified == this.verified &&
          other.createdBy == this.createdBy &&
          other.updatedAt == this.updatedAt);
}

class VenuesCompanion extends UpdateCompanion<Venue> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String?> address;
  final Value<String?> city;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> openingHours;
  final Value<double?> priceHalfL;
  final Value<double?> priceThirdL;
  final Value<bool> verified;
  final Value<String?> createdBy;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const VenuesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.openingHours = const Value.absent(),
    this.priceHalfL = const Value.absent(),
    this.priceThirdL = const Value.absent(),
    this.verified = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VenuesCompanion.insert({
    required String id,
    required String name,
    this.category = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.openingHours = const Value.absent(),
    this.priceHalfL = const Value.absent(),
    this.priceThirdL = const Value.absent(),
    this.verified = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Venue> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? address,
    Expression<String>? city,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? openingHours,
    Expression<double>? priceHalfL,
    Expression<double>? priceThirdL,
    Expression<bool>? verified,
    Expression<String>? createdBy,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (openingHours != null) 'opening_hours': openingHours,
      if (priceHalfL != null) 'price_half_l': priceHalfL,
      if (priceThirdL != null) 'price_third_l': priceThirdL,
      if (verified != null) 'verified': verified,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VenuesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? category,
      Value<String?>? address,
      Value<String?>? city,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<String?>? openingHours,
      Value<double?>? priceHalfL,
      Value<double?>? priceThirdL,
      Value<bool>? verified,
      Value<String?>? createdBy,
      Value<DateTime?>? updatedAt,
      Value<int>? rowid}) {
    return VenuesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      openingHours: openingHours ?? this.openingHours,
      priceHalfL: priceHalfL ?? this.priceHalfL,
      priceThirdL: priceThirdL ?? this.priceThirdL,
      verified: verified ?? this.verified,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (openingHours.present) {
      map['opening_hours'] = Variable<String>(openingHours.value);
    }
    if (priceHalfL.present) {
      map['price_half_l'] = Variable<double>(priceHalfL.value);
    }
    if (priceThirdL.present) {
      map['price_third_l'] = Variable<double>(priceThirdL.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VenuesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('openingHours: $openingHours, ')
          ..write('priceHalfL: $priceHalfL, ')
          ..write('priceThirdL: $priceThirdL, ')
          ..write('verified: $verified, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
      'host_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _venueIdMeta =
      const VerificationMeta('venueId');
  @override
  late final GeneratedColumn<String> venueId = GeneratedColumn<String>(
      'venue_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _venueNameMeta =
      const VerificationMeta('venueName');
  @override
  late final GeneratedColumn<String> venueName = GeneratedColumn<String>(
      'venue_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _messageMeta =
      const VerificationMeta('message');
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
      'message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _visibilityMeta =
      const VerificationMeta('visibility');
  @override
  late final GeneratedColumnWithTypeConverter<SessionVisibility, String>
      visibility = GeneratedColumn<String>('visibility', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<SessionVisibility>(
              $SessionsTable.$convertervisibility);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumnWithTypeConverter<SessionStatus, String> status =
      GeneratedColumn<String>('status', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<SessionStatus>($SessionsTable.$converterstatus);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        hostId,
        venueId,
        venueName,
        message,
        visibility,
        status,
        startedAt,
        endedAt,
        expiresAt,
        latitude,
        longitude
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('host_id')) {
      context.handle(_hostIdMeta,
          hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta));
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('venue_id')) {
      context.handle(_venueIdMeta,
          venueId.isAcceptableOrUnknown(data['venue_id']!, _venueIdMeta));
    }
    if (data.containsKey('venue_name')) {
      context.handle(_venueNameMeta,
          venueName.isAcceptableOrUnknown(data['venue_name']!, _venueNameMeta));
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta,
          message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    }
    context.handle(_visibilityMeta, const VerificationResult.success());
    context.handle(_statusMeta, const VerificationResult.success());
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hostId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}host_id'])!,
      venueId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}venue_id']),
      venueName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}venue_name']),
      message: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message']),
      visibility: $SessionsTable.$convertervisibility.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}visibility'])!),
      status: $SessionsTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SessionVisibility, String, String>
      $convertervisibility =
      const EnumNameConverter<SessionVisibility>(SessionVisibility.values);
  static JsonTypeConverter2<SessionStatus, String, String> $converterstatus =
      const EnumNameConverter<SessionStatus>(SessionStatus.values);
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String hostId;
  final String? venueId;
  final String? venueName;
  final String? message;
  final SessionVisibility visibility;
  final SessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime expiresAt;
  final double? latitude;
  final double? longitude;
  const Session(
      {required this.id,
      required this.hostId,
      this.venueId,
      this.venueName,
      this.message,
      required this.visibility,
      required this.status,
      required this.startedAt,
      this.endedAt,
      required this.expiresAt,
      this.latitude,
      this.longitude});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['host_id'] = Variable<String>(hostId);
    if (!nullToAbsent || venueId != null) {
      map['venue_id'] = Variable<String>(venueId);
    }
    if (!nullToAbsent || venueName != null) {
      map['venue_name'] = Variable<String>(venueName);
    }
    if (!nullToAbsent || message != null) {
      map['message'] = Variable<String>(message);
    }
    {
      map['visibility'] = Variable<String>(
          $SessionsTable.$convertervisibility.toSql(visibility));
    }
    {
      map['status'] =
          Variable<String>($SessionsTable.$converterstatus.toSql(status));
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['expires_at'] = Variable<DateTime>(expiresAt);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      hostId: Value(hostId),
      venueId: venueId == null && nullToAbsent
          ? const Value.absent()
          : Value(venueId),
      venueName: venueName == null && nullToAbsent
          ? const Value.absent()
          : Value(venueName),
      message: message == null && nullToAbsent
          ? const Value.absent()
          : Value(message),
      visibility: Value(visibility),
      status: Value(status),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      expiresAt: Value(expiresAt),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      hostId: serializer.fromJson<String>(json['hostId']),
      venueId: serializer.fromJson<String?>(json['venueId']),
      venueName: serializer.fromJson<String?>(json['venueName']),
      message: serializer.fromJson<String?>(json['message']),
      visibility: $SessionsTable.$convertervisibility
          .fromJson(serializer.fromJson<String>(json['visibility'])),
      status: $SessionsTable.$converterstatus
          .fromJson(serializer.fromJson<String>(json['status'])),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hostId': serializer.toJson<String>(hostId),
      'venueId': serializer.toJson<String?>(venueId),
      'venueName': serializer.toJson<String?>(venueName),
      'message': serializer.toJson<String?>(message),
      'visibility': serializer.toJson<String>(
          $SessionsTable.$convertervisibility.toJson(visibility)),
      'status': serializer
          .toJson<String>($SessionsTable.$converterstatus.toJson(status)),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
    };
  }

  Session copyWith(
          {String? id,
          String? hostId,
          Value<String?> venueId = const Value.absent(),
          Value<String?> venueName = const Value.absent(),
          Value<String?> message = const Value.absent(),
          SessionVisibility? visibility,
          SessionStatus? status,
          DateTime? startedAt,
          Value<DateTime?> endedAt = const Value.absent(),
          DateTime? expiresAt,
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent()}) =>
      Session(
        id: id ?? this.id,
        hostId: hostId ?? this.hostId,
        venueId: venueId.present ? venueId.value : this.venueId,
        venueName: venueName.present ? venueName.value : this.venueName,
        message: message.present ? message.value : this.message,
        visibility: visibility ?? this.visibility,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
      );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      venueId: data.venueId.present ? data.venueId.value : this.venueId,
      venueName: data.venueName.present ? data.venueName.value : this.venueName,
      message: data.message.present ? data.message.value : this.message,
      visibility:
          data.visibility.present ? data.visibility.value : this.visibility,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('hostId: $hostId, ')
          ..write('venueId: $venueId, ')
          ..write('venueName: $venueName, ')
          ..write('message: $message, ')
          ..write('visibility: $visibility, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hostId, venueId, venueName, message,
      visibility, status, startedAt, endedAt, expiresAt, latitude, longitude);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.hostId == this.hostId &&
          other.venueId == this.venueId &&
          other.venueName == this.venueName &&
          other.message == this.message &&
          other.visibility == this.visibility &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.expiresAt == this.expiresAt &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String> hostId;
  final Value<String?> venueId;
  final Value<String?> venueName;
  final Value<String?> message;
  final Value<SessionVisibility> visibility;
  final Value<SessionStatus> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<DateTime> expiresAt;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.hostId = const Value.absent(),
    this.venueId = const Value.absent(),
    this.venueName = const Value.absent(),
    this.message = const Value.absent(),
    this.visibility = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String hostId,
    this.venueId = const Value.absent(),
    this.venueName = const Value.absent(),
    this.message = const Value.absent(),
    required SessionVisibility visibility,
    required SessionStatus status,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required DateTime expiresAt,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        hostId = Value(hostId),
        visibility = Value(visibility),
        status = Value(status),
        startedAt = Value(startedAt),
        expiresAt = Value(expiresAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? hostId,
    Expression<String>? venueId,
    Expression<String>? venueName,
    Expression<String>? message,
    Expression<String>? visibility,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<DateTime>? expiresAt,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hostId != null) 'host_id': hostId,
      if (venueId != null) 'venue_id': venueId,
      if (venueName != null) 'venue_name': venueName,
      if (message != null) 'message': message,
      if (visibility != null) 'visibility': visibility,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? hostId,
      Value<String?>? venueId,
      Value<String?>? venueName,
      Value<String?>? message,
      Value<SessionVisibility>? visibility,
      Value<SessionStatus>? status,
      Value<DateTime>? startedAt,
      Value<DateTime?>? endedAt,
      Value<DateTime>? expiresAt,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<int>? rowid}) {
    return SessionsCompanion(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
      message: message ?? this.message,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (venueId.present) {
      map['venue_id'] = Variable<String>(venueId.value);
    }
    if (venueName.present) {
      map['venue_name'] = Variable<String>(venueName.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(
          $SessionsTable.$convertervisibility.toSql(visibility.value));
    }
    if (status.present) {
      map['status'] =
          Variable<String>($SessionsTable.$converterstatus.toSql(status.value));
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('hostId: $hostId, ')
          ..write('venueId: $venueId, ')
          ..write('venueName: $venueName, ')
          ..write('message: $message, ')
          ..write('visibility: $visibility, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionParticipantsTable extends SessionParticipants
    with TableInfo<$SessionParticipantsTable, SessionParticipant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionParticipantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumnWithTypeConverter<ParticipantKind, String> kind =
      GeneratedColumn<String>('kind', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<ParticipantKind>(
              $SessionParticipantsTable.$converterkind);
  @override
  List<GeneratedColumn> get $columns => [sessionId, profileId, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_participants';
  @override
  VerificationContext validateIntegrity(Insertable<SessionParticipant> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    context.handle(_kindMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, profileId, kind};
  @override
  SessionParticipant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionParticipant(
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      kind: $SessionParticipantsTable.$converterkind.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!),
    );
  }

  @override
  $SessionParticipantsTable createAlias(String alias) {
    return $SessionParticipantsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ParticipantKind, String, String> $converterkind =
      const EnumNameConverter<ParticipantKind>(ParticipantKind.values);
}

class SessionParticipant extends DataClass
    implements Insertable<SessionParticipant> {
  final String sessionId;
  final String profileId;
  final ParticipantKind kind;
  const SessionParticipant(
      {required this.sessionId, required this.profileId, required this.kind});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['profile_id'] = Variable<String>(profileId);
    {
      map['kind'] = Variable<String>(
          $SessionParticipantsTable.$converterkind.toSql(kind));
    }
    return map;
  }

  SessionParticipantsCompanion toCompanion(bool nullToAbsent) {
    return SessionParticipantsCompanion(
      sessionId: Value(sessionId),
      profileId: Value(profileId),
      kind: Value(kind),
    );
  }

  factory SessionParticipant.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionParticipant(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      kind: $SessionParticipantsTable.$converterkind
          .fromJson(serializer.fromJson<String>(json['kind'])),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'profileId': serializer.toJson<String>(profileId),
      'kind': serializer.toJson<String>(
          $SessionParticipantsTable.$converterkind.toJson(kind)),
    };
  }

  SessionParticipant copyWith(
          {String? sessionId, String? profileId, ParticipantKind? kind}) =>
      SessionParticipant(
        sessionId: sessionId ?? this.sessionId,
        profileId: profileId ?? this.profileId,
        kind: kind ?? this.kind,
      );
  SessionParticipant copyWithCompanion(SessionParticipantsCompanion data) {
    return SessionParticipant(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionParticipant(')
          ..write('sessionId: $sessionId, ')
          ..write('profileId: $profileId, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, profileId, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionParticipant &&
          other.sessionId == this.sessionId &&
          other.profileId == this.profileId &&
          other.kind == this.kind);
}

class SessionParticipantsCompanion extends UpdateCompanion<SessionParticipant> {
  final Value<String> sessionId;
  final Value<String> profileId;
  final Value<ParticipantKind> kind;
  final Value<int> rowid;
  const SessionParticipantsCompanion({
    this.sessionId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionParticipantsCompanion.insert({
    required String sessionId,
    required String profileId,
    required ParticipantKind kind,
    this.rowid = const Value.absent(),
  })  : sessionId = Value(sessionId),
        profileId = Value(profileId),
        kind = Value(kind);
  static Insertable<SessionParticipant> custom({
    Expression<String>? sessionId,
    Expression<String>? profileId,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (profileId != null) 'profile_id': profileId,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionParticipantsCompanion copyWith(
      {Value<String>? sessionId,
      Value<String>? profileId,
      Value<ParticipantKind>? kind,
      Value<int>? rowid}) {
    return SessionParticipantsCompanion(
      sessionId: sessionId ?? this.sessionId,
      profileId: profileId ?? this.profileId,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
          $SessionParticipantsTable.$converterkind.toSql(kind.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionParticipantsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('profileId: $profileId, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CheckinsTable extends Checkins with TableInfo<$CheckinsTable, Checkin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _beerIdMeta = const VerificationMeta('beerId');
  @override
  late final GeneratedColumn<String> beerId = GeneratedColumn<String>(
      'beer_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES beers (id)'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _venueIdMeta =
      const VerificationMeta('venueId');
  @override
  late final GeneratedColumn<String> venueId = GeneratedColumn<String>(
      'venue_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _venueNameMeta =
      const VerificationMeta('venueName');
  @override
  late final GeneratedColumn<String> venueName = GeneratedColumn<String>(
      'venue_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
      'rating', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _flavorTagsMeta =
      const VerificationMeta('flavorTags');
  @override
  late final GeneratedColumn<String> flavorTags = GeneratedColumn<String>(
      'flavor_tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _servingStyleMeta =
      const VerificationMeta('servingStyle');
  @override
  late final GeneratedColumnWithTypeConverter<ServingStyle?, String>
      servingStyle = GeneratedColumn<String>('serving_style', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<ServingStyle?>($CheckinsTable.$converterservingStylen);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        profileId,
        beerId,
        sessionId,
        venueId,
        venueName,
        rating,
        note,
        flavorTags,
        servingStyle,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checkins';
  @override
  VerificationContext validateIntegrity(Insertable<Checkin> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('beer_id')) {
      context.handle(_beerIdMeta,
          beerId.isAcceptableOrUnknown(data['beer_id']!, _beerIdMeta));
    } else if (isInserting) {
      context.missing(_beerIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('venue_id')) {
      context.handle(_venueIdMeta,
          venueId.isAcceptableOrUnknown(data['venue_id']!, _venueIdMeta));
    }
    if (data.containsKey('venue_name')) {
      context.handle(_venueNameMeta,
          venueName.isAcceptableOrUnknown(data['venue_name']!, _venueNameMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('flavor_tags')) {
      context.handle(
          _flavorTagsMeta,
          flavorTags.isAcceptableOrUnknown(
              data['flavor_tags']!, _flavorTagsMeta));
    }
    context.handle(_servingStyleMeta, const VerificationResult.success());
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Checkin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Checkin(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      beerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}beer_id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id']),
      venueId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}venue_id']),
      venueName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}venue_name']),
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rating']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      flavorTags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}flavor_tags'])!,
      servingStyle: $CheckinsTable.$converterservingStylen.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}serving_style'])),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CheckinsTable createAlias(String alias) {
    return $CheckinsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ServingStyle, String, String>
      $converterservingStyle =
      const EnumNameConverter<ServingStyle>(ServingStyle.values);
  static JsonTypeConverter2<ServingStyle?, String?, String?>
      $converterservingStylen =
      JsonTypeConverter2.asNullable($converterservingStyle);
}

class Checkin extends DataClass implements Insertable<Checkin> {
  final String id;
  final String profileId;
  final String beerId;
  final String? sessionId;
  final String? venueId;
  final String? venueName;
  final double? rating;
  final String? note;

  /// Kommagetrennt, z. B. "hopfig,fruchtig".
  final String flavorTags;
  final ServingStyle? servingStyle;
  final DateTime createdAt;
  const Checkin(
      {required this.id,
      required this.profileId,
      required this.beerId,
      this.sessionId,
      this.venueId,
      this.venueName,
      this.rating,
      this.note,
      required this.flavorTags,
      this.servingStyle,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['beer_id'] = Variable<String>(beerId);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || venueId != null) {
      map['venue_id'] = Variable<String>(venueId);
    }
    if (!nullToAbsent || venueName != null) {
      map['venue_name'] = Variable<String>(venueName);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['flavor_tags'] = Variable<String>(flavorTags);
    if (!nullToAbsent || servingStyle != null) {
      map['serving_style'] = Variable<String>(
          $CheckinsTable.$converterservingStylen.toSql(servingStyle));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CheckinsCompanion toCompanion(bool nullToAbsent) {
    return CheckinsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      beerId: Value(beerId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      venueId: venueId == null && nullToAbsent
          ? const Value.absent()
          : Value(venueId),
      venueName: venueName == null && nullToAbsent
          ? const Value.absent()
          : Value(venueName),
      rating:
          rating == null && nullToAbsent ? const Value.absent() : Value(rating),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      flavorTags: Value(flavorTags),
      servingStyle: servingStyle == null && nullToAbsent
          ? const Value.absent()
          : Value(servingStyle),
      createdAt: Value(createdAt),
    );
  }

  factory Checkin.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Checkin(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      beerId: serializer.fromJson<String>(json['beerId']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      venueId: serializer.fromJson<String?>(json['venueId']),
      venueName: serializer.fromJson<String?>(json['venueName']),
      rating: serializer.fromJson<double?>(json['rating']),
      note: serializer.fromJson<String?>(json['note']),
      flavorTags: serializer.fromJson<String>(json['flavorTags']),
      servingStyle: $CheckinsTable.$converterservingStylen
          .fromJson(serializer.fromJson<String?>(json['servingStyle'])),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'beerId': serializer.toJson<String>(beerId),
      'sessionId': serializer.toJson<String?>(sessionId),
      'venueId': serializer.toJson<String?>(venueId),
      'venueName': serializer.toJson<String?>(venueName),
      'rating': serializer.toJson<double?>(rating),
      'note': serializer.toJson<String?>(note),
      'flavorTags': serializer.toJson<String>(flavorTags),
      'servingStyle': serializer.toJson<String?>(
          $CheckinsTable.$converterservingStylen.toJson(servingStyle)),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Checkin copyWith(
          {String? id,
          String? profileId,
          String? beerId,
          Value<String?> sessionId = const Value.absent(),
          Value<String?> venueId = const Value.absent(),
          Value<String?> venueName = const Value.absent(),
          Value<double?> rating = const Value.absent(),
          Value<String?> note = const Value.absent(),
          String? flavorTags,
          Value<ServingStyle?> servingStyle = const Value.absent(),
          DateTime? createdAt}) =>
      Checkin(
        id: id ?? this.id,
        profileId: profileId ?? this.profileId,
        beerId: beerId ?? this.beerId,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
        venueId: venueId.present ? venueId.value : this.venueId,
        venueName: venueName.present ? venueName.value : this.venueName,
        rating: rating.present ? rating.value : this.rating,
        note: note.present ? note.value : this.note,
        flavorTags: flavorTags ?? this.flavorTags,
        servingStyle:
            servingStyle.present ? servingStyle.value : this.servingStyle,
        createdAt: createdAt ?? this.createdAt,
      );
  Checkin copyWithCompanion(CheckinsCompanion data) {
    return Checkin(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      beerId: data.beerId.present ? data.beerId.value : this.beerId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      venueId: data.venueId.present ? data.venueId.value : this.venueId,
      venueName: data.venueName.present ? data.venueName.value : this.venueName,
      rating: data.rating.present ? data.rating.value : this.rating,
      note: data.note.present ? data.note.value : this.note,
      flavorTags:
          data.flavorTags.present ? data.flavorTags.value : this.flavorTags,
      servingStyle: data.servingStyle.present
          ? data.servingStyle.value
          : this.servingStyle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Checkin(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('beerId: $beerId, ')
          ..write('sessionId: $sessionId, ')
          ..write('venueId: $venueId, ')
          ..write('venueName: $venueName, ')
          ..write('rating: $rating, ')
          ..write('note: $note, ')
          ..write('flavorTags: $flavorTags, ')
          ..write('servingStyle: $servingStyle, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileId, beerId, sessionId, venueId,
      venueName, rating, note, flavorTags, servingStyle, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Checkin &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.beerId == this.beerId &&
          other.sessionId == this.sessionId &&
          other.venueId == this.venueId &&
          other.venueName == this.venueName &&
          other.rating == this.rating &&
          other.note == this.note &&
          other.flavorTags == this.flavorTags &&
          other.servingStyle == this.servingStyle &&
          other.createdAt == this.createdAt);
}

class CheckinsCompanion extends UpdateCompanion<Checkin> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> beerId;
  final Value<String?> sessionId;
  final Value<String?> venueId;
  final Value<String?> venueName;
  final Value<double?> rating;
  final Value<String?> note;
  final Value<String> flavorTags;
  final Value<ServingStyle?> servingStyle;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CheckinsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.beerId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.venueId = const Value.absent(),
    this.venueName = const Value.absent(),
    this.rating = const Value.absent(),
    this.note = const Value.absent(),
    this.flavorTags = const Value.absent(),
    this.servingStyle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CheckinsCompanion.insert({
    required String id,
    required String profileId,
    required String beerId,
    this.sessionId = const Value.absent(),
    this.venueId = const Value.absent(),
    this.venueName = const Value.absent(),
    this.rating = const Value.absent(),
    this.note = const Value.absent(),
    this.flavorTags = const Value.absent(),
    this.servingStyle = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        profileId = Value(profileId),
        beerId = Value(beerId),
        createdAt = Value(createdAt);
  static Insertable<Checkin> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? beerId,
    Expression<String>? sessionId,
    Expression<String>? venueId,
    Expression<String>? venueName,
    Expression<double>? rating,
    Expression<String>? note,
    Expression<String>? flavorTags,
    Expression<String>? servingStyle,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (beerId != null) 'beer_id': beerId,
      if (sessionId != null) 'session_id': sessionId,
      if (venueId != null) 'venue_id': venueId,
      if (venueName != null) 'venue_name': venueName,
      if (rating != null) 'rating': rating,
      if (note != null) 'note': note,
      if (flavorTags != null) 'flavor_tags': flavorTags,
      if (servingStyle != null) 'serving_style': servingStyle,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CheckinsCompanion copyWith(
      {Value<String>? id,
      Value<String>? profileId,
      Value<String>? beerId,
      Value<String?>? sessionId,
      Value<String?>? venueId,
      Value<String?>? venueName,
      Value<double?>? rating,
      Value<String?>? note,
      Value<String>? flavorTags,
      Value<ServingStyle?>? servingStyle,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return CheckinsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      beerId: beerId ?? this.beerId,
      sessionId: sessionId ?? this.sessionId,
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
      rating: rating ?? this.rating,
      note: note ?? this.note,
      flavorTags: flavorTags ?? this.flavorTags,
      servingStyle: servingStyle ?? this.servingStyle,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (beerId.present) {
      map['beer_id'] = Variable<String>(beerId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (venueId.present) {
      map['venue_id'] = Variable<String>(venueId.value);
    }
    if (venueName.present) {
      map['venue_name'] = Variable<String>(venueName.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (flavorTags.present) {
      map['flavor_tags'] = Variable<String>(flavorTags.value);
    }
    if (servingStyle.present) {
      map['serving_style'] = Variable<String>(
          $CheckinsTable.$converterservingStylen.toSql(servingStyle.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckinsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('beerId: $beerId, ')
          ..write('sessionId: $sessionId, ')
          ..write('venueId: $venueId, ')
          ..write('venueName: $venueName, ')
          ..write('rating: $rating, ')
          ..write('note: $note, ')
          ..write('flavorTags: $flavorTags, ')
          ..write('servingStyle: $servingStyle, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ToastsTable extends Toasts with TableInfo<$ToastsTable, Toast> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ToastsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _checkinIdMeta =
      const VerificationMeta('checkinId');
  @override
  late final GeneratedColumn<String> checkinId = GeneratedColumn<String>(
      'checkin_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES checkins (id)'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  @override
  List<GeneratedColumn> get $columns => [checkinId, profileId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'toasts';
  @override
  VerificationContext validateIntegrity(Insertable<Toast> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('checkin_id')) {
      context.handle(_checkinIdMeta,
          checkinId.isAcceptableOrUnknown(data['checkin_id']!, _checkinIdMeta));
    } else if (isInserting) {
      context.missing(_checkinIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {checkinId, profileId};
  @override
  Toast map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Toast(
      checkinId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}checkin_id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
    );
  }

  @override
  $ToastsTable createAlias(String alias) {
    return $ToastsTable(attachedDatabase, alias);
  }
}

class Toast extends DataClass implements Insertable<Toast> {
  final String checkinId;
  final String profileId;
  const Toast({required this.checkinId, required this.profileId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['checkin_id'] = Variable<String>(checkinId);
    map['profile_id'] = Variable<String>(profileId);
    return map;
  }

  ToastsCompanion toCompanion(bool nullToAbsent) {
    return ToastsCompanion(
      checkinId: Value(checkinId),
      profileId: Value(profileId),
    );
  }

  factory Toast.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Toast(
      checkinId: serializer.fromJson<String>(json['checkinId']),
      profileId: serializer.fromJson<String>(json['profileId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'checkinId': serializer.toJson<String>(checkinId),
      'profileId': serializer.toJson<String>(profileId),
    };
  }

  Toast copyWith({String? checkinId, String? profileId}) => Toast(
        checkinId: checkinId ?? this.checkinId,
        profileId: profileId ?? this.profileId,
      );
  Toast copyWithCompanion(ToastsCompanion data) {
    return Toast(
      checkinId: data.checkinId.present ? data.checkinId.value : this.checkinId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Toast(')
          ..write('checkinId: $checkinId, ')
          ..write('profileId: $profileId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(checkinId, profileId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Toast &&
          other.checkinId == this.checkinId &&
          other.profileId == this.profileId);
}

class ToastsCompanion extends UpdateCompanion<Toast> {
  final Value<String> checkinId;
  final Value<String> profileId;
  final Value<int> rowid;
  const ToastsCompanion({
    this.checkinId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ToastsCompanion.insert({
    required String checkinId,
    required String profileId,
    this.rowid = const Value.absent(),
  })  : checkinId = Value(checkinId),
        profileId = Value(profileId);
  static Insertable<Toast> custom({
    Expression<String>? checkinId,
    Expression<String>? profileId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (checkinId != null) 'checkin_id': checkinId,
      if (profileId != null) 'profile_id': profileId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ToastsCompanion copyWith(
      {Value<String>? checkinId, Value<String>? profileId, Value<int>? rowid}) {
    return ToastsCompanion(
      checkinId: checkinId ?? this.checkinId,
      profileId: profileId ?? this.profileId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (checkinId.present) {
      map['checkin_id'] = Variable<String>(checkinId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ToastsCompanion(')
          ..write('checkinId: $checkinId, ')
          ..write('profileId: $profileId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CommentsTable extends Comments with TableInfo<$CommentsTable, Comment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _checkinIdMeta =
      const VerificationMeta('checkinId');
  @override
  late final GeneratedColumn<String> checkinId = GeneratedColumn<String>(
      'checkin_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES checkins (id)'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, checkinId, profileId, body, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'comments';
  @override
  VerificationContext validateIntegrity(Insertable<Comment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('checkin_id')) {
      context.handle(_checkinIdMeta,
          checkinId.isAcceptableOrUnknown(data['checkin_id']!, _checkinIdMeta));
    } else if (isInserting) {
      context.missing(_checkinIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Comment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Comment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      checkinId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}checkin_id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CommentsTable createAlias(String alias) {
    return $CommentsTable(attachedDatabase, alias);
  }
}

class Comment extends DataClass implements Insertable<Comment> {
  final String id;
  final String checkinId;
  final String profileId;
  final String body;
  final DateTime createdAt;
  const Comment(
      {required this.id,
      required this.checkinId,
      required this.profileId,
      required this.body,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['checkin_id'] = Variable<String>(checkinId);
    map['profile_id'] = Variable<String>(profileId);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CommentsCompanion toCompanion(bool nullToAbsent) {
    return CommentsCompanion(
      id: Value(id),
      checkinId: Value(checkinId),
      profileId: Value(profileId),
      body: Value(body),
      createdAt: Value(createdAt),
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Comment(
      id: serializer.fromJson<String>(json['id']),
      checkinId: serializer.fromJson<String>(json['checkinId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'checkinId': serializer.toJson<String>(checkinId),
      'profileId': serializer.toJson<String>(profileId),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Comment copyWith(
          {String? id,
          String? checkinId,
          String? profileId,
          String? body,
          DateTime? createdAt}) =>
      Comment(
        id: id ?? this.id,
        checkinId: checkinId ?? this.checkinId,
        profileId: profileId ?? this.profileId,
        body: body ?? this.body,
        createdAt: createdAt ?? this.createdAt,
      );
  Comment copyWithCompanion(CommentsCompanion data) {
    return Comment(
      id: data.id.present ? data.id.value : this.id,
      checkinId: data.checkinId.present ? data.checkinId.value : this.checkinId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Comment(')
          ..write('id: $id, ')
          ..write('checkinId: $checkinId, ')
          ..write('profileId: $profileId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, checkinId, profileId, body, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Comment &&
          other.id == this.id &&
          other.checkinId == this.checkinId &&
          other.profileId == this.profileId &&
          other.body == this.body &&
          other.createdAt == this.createdAt);
}

class CommentsCompanion extends UpdateCompanion<Comment> {
  final Value<String> id;
  final Value<String> checkinId;
  final Value<String> profileId;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CommentsCompanion({
    this.id = const Value.absent(),
    this.checkinId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CommentsCompanion.insert({
    required String id,
    required String checkinId,
    required String profileId,
    required String body,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        checkinId = Value(checkinId),
        profileId = Value(profileId),
        body = Value(body),
        createdAt = Value(createdAt);
  static Insertable<Comment> custom({
    Expression<String>? id,
    Expression<String>? checkinId,
    Expression<String>? profileId,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (checkinId != null) 'checkin_id': checkinId,
      if (profileId != null) 'profile_id': profileId,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CommentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? checkinId,
      Value<String>? profileId,
      Value<String>? body,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return CommentsCompanion(
      id: id ?? this.id,
      checkinId: checkinId ?? this.checkinId,
      profileId: profileId ?? this.profileId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (checkinId.present) {
      map['checkin_id'] = Variable<String>(checkinId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommentsCompanion(')
          ..write('id: $id, ')
          ..write('checkinId: $checkinId, ')
          ..write('profileId: $profileId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserBadgesTable extends UserBadges
    with TableInfo<$UserBadgesTable, UserBadge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserBadgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _badgeSlugMeta =
      const VerificationMeta('badgeSlug');
  @override
  late final GeneratedColumn<String> badgeSlug = GeneratedColumn<String>(
      'badge_slug', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _awardedAtMeta =
      const VerificationMeta('awardedAt');
  @override
  late final GeneratedColumn<DateTime> awardedAt = GeneratedColumn<DateTime>(
      'awarded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [profileId, badgeSlug, awardedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_badges';
  @override
  VerificationContext validateIntegrity(Insertable<UserBadge> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('badge_slug')) {
      context.handle(_badgeSlugMeta,
          badgeSlug.isAcceptableOrUnknown(data['badge_slug']!, _badgeSlugMeta));
    } else if (isInserting) {
      context.missing(_badgeSlugMeta);
    }
    if (data.containsKey('awarded_at')) {
      context.handle(_awardedAtMeta,
          awardedAt.isAcceptableOrUnknown(data['awarded_at']!, _awardedAtMeta));
    } else if (isInserting) {
      context.missing(_awardedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, badgeSlug};
  @override
  UserBadge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserBadge(
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      badgeSlug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}badge_slug'])!,
      awardedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}awarded_at'])!,
    );
  }

  @override
  $UserBadgesTable createAlias(String alias) {
    return $UserBadgesTable(attachedDatabase, alias);
  }
}

class UserBadge extends DataClass implements Insertable<UserBadge> {
  final String profileId;
  final String badgeSlug;
  final DateTime awardedAt;
  const UserBadge(
      {required this.profileId,
      required this.badgeSlug,
      required this.awardedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['badge_slug'] = Variable<String>(badgeSlug);
    map['awarded_at'] = Variable<DateTime>(awardedAt);
    return map;
  }

  UserBadgesCompanion toCompanion(bool nullToAbsent) {
    return UserBadgesCompanion(
      profileId: Value(profileId),
      badgeSlug: Value(badgeSlug),
      awardedAt: Value(awardedAt),
    );
  }

  factory UserBadge.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserBadge(
      profileId: serializer.fromJson<String>(json['profileId']),
      badgeSlug: serializer.fromJson<String>(json['badgeSlug']),
      awardedAt: serializer.fromJson<DateTime>(json['awardedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'badgeSlug': serializer.toJson<String>(badgeSlug),
      'awardedAt': serializer.toJson<DateTime>(awardedAt),
    };
  }

  UserBadge copyWith(
          {String? profileId, String? badgeSlug, DateTime? awardedAt}) =>
      UserBadge(
        profileId: profileId ?? this.profileId,
        badgeSlug: badgeSlug ?? this.badgeSlug,
        awardedAt: awardedAt ?? this.awardedAt,
      );
  UserBadge copyWithCompanion(UserBadgesCompanion data) {
    return UserBadge(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      badgeSlug: data.badgeSlug.present ? data.badgeSlug.value : this.badgeSlug,
      awardedAt: data.awardedAt.present ? data.awardedAt.value : this.awardedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserBadge(')
          ..write('profileId: $profileId, ')
          ..write('badgeSlug: $badgeSlug, ')
          ..write('awardedAt: $awardedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, badgeSlug, awardedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserBadge &&
          other.profileId == this.profileId &&
          other.badgeSlug == this.badgeSlug &&
          other.awardedAt == this.awardedAt);
}

class UserBadgesCompanion extends UpdateCompanion<UserBadge> {
  final Value<String> profileId;
  final Value<String> badgeSlug;
  final Value<DateTime> awardedAt;
  final Value<int> rowid;
  const UserBadgesCompanion({
    this.profileId = const Value.absent(),
    this.badgeSlug = const Value.absent(),
    this.awardedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserBadgesCompanion.insert({
    required String profileId,
    required String badgeSlug,
    required DateTime awardedAt,
    this.rowid = const Value.absent(),
  })  : profileId = Value(profileId),
        badgeSlug = Value(badgeSlug),
        awardedAt = Value(awardedAt);
  static Insertable<UserBadge> custom({
    Expression<String>? profileId,
    Expression<String>? badgeSlug,
    Expression<DateTime>? awardedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (badgeSlug != null) 'badge_slug': badgeSlug,
      if (awardedAt != null) 'awarded_at': awardedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserBadgesCompanion copyWith(
      {Value<String>? profileId,
      Value<String>? badgeSlug,
      Value<DateTime>? awardedAt,
      Value<int>? rowid}) {
    return UserBadgesCompanion(
      profileId: profileId ?? this.profileId,
      badgeSlug: badgeSlug ?? this.badgeSlug,
      awardedAt: awardedAt ?? this.awardedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (badgeSlug.present) {
      map['badge_slug'] = Variable<String>(badgeSlug.value);
    }
    if (awardedAt.present) {
      map['awarded_at'] = Variable<DateTime>(awardedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserBadgesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('badgeSlug: $badgeSlug, ')
          ..write('awardedAt: $awardedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WishlistItemsTable extends WishlistItems
    with TableInfo<$WishlistItemsTable, WishlistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishlistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _beerIdMeta = const VerificationMeta('beerId');
  @override
  late final GeneratedColumn<String> beerId = GeneratedColumn<String>(
      'beer_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES beers (id)'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [profileId, beerId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wishlist_items';
  @override
  VerificationContext validateIntegrity(Insertable<WishlistItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('beer_id')) {
      context.handle(_beerIdMeta,
          beerId.isAcceptableOrUnknown(data['beer_id']!, _beerIdMeta));
    } else if (isInserting) {
      context.missing(_beerIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, beerId};
  @override
  WishlistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WishlistItem(
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      beerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}beer_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $WishlistItemsTable createAlias(String alias) {
    return $WishlistItemsTable(attachedDatabase, alias);
  }
}

class WishlistItem extends DataClass implements Insertable<WishlistItem> {
  final String profileId;
  final String beerId;
  final DateTime createdAt;
  const WishlistItem(
      {required this.profileId, required this.beerId, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['beer_id'] = Variable<String>(beerId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WishlistItemsCompanion toCompanion(bool nullToAbsent) {
    return WishlistItemsCompanion(
      profileId: Value(profileId),
      beerId: Value(beerId),
      createdAt: Value(createdAt),
    );
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WishlistItem(
      profileId: serializer.fromJson<String>(json['profileId']),
      beerId: serializer.fromJson<String>(json['beerId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'beerId': serializer.toJson<String>(beerId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WishlistItem copyWith(
          {String? profileId, String? beerId, DateTime? createdAt}) =>
      WishlistItem(
        profileId: profileId ?? this.profileId,
        beerId: beerId ?? this.beerId,
        createdAt: createdAt ?? this.createdAt,
      );
  WishlistItem copyWithCompanion(WishlistItemsCompanion data) {
    return WishlistItem(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      beerId: data.beerId.present ? data.beerId.value : this.beerId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WishlistItem(')
          ..write('profileId: $profileId, ')
          ..write('beerId: $beerId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, beerId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WishlistItem &&
          other.profileId == this.profileId &&
          other.beerId == this.beerId &&
          other.createdAt == this.createdAt);
}

class WishlistItemsCompanion extends UpdateCompanion<WishlistItem> {
  final Value<String> profileId;
  final Value<String> beerId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WishlistItemsCompanion({
    this.profileId = const Value.absent(),
    this.beerId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WishlistItemsCompanion.insert({
    required String profileId,
    required String beerId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : profileId = Value(profileId),
        beerId = Value(beerId),
        createdAt = Value(createdAt);
  static Insertable<WishlistItem> custom({
    Expression<String>? profileId,
    Expression<String>? beerId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (beerId != null) 'beer_id': beerId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WishlistItemsCompanion copyWith(
      {Value<String>? profileId,
      Value<String>? beerId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return WishlistItemsCompanion(
      profileId: profileId ?? this.profileId,
      beerId: beerId ?? this.beerId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (beerId.present) {
      map['beer_id'] = Variable<String>(beerId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishlistItemsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('beerId: $beerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $BreweriesTable breweries = $BreweriesTable(this);
  late final $BeersTable beers = $BeersTable(this);
  late final $VenuesTable venues = $VenuesTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionParticipantsTable sessionParticipants =
      $SessionParticipantsTable(this);
  late final $CheckinsTable checkins = $CheckinsTable(this);
  late final $ToastsTable toasts = $ToastsTable(this);
  late final $CommentsTable comments = $CommentsTable(this);
  late final $UserBadgesTable userBadges = $UserBadgesTable(this);
  late final $WishlistItemsTable wishlistItems = $WishlistItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        profiles,
        breweries,
        beers,
        venues,
        sessions,
        sessionParticipants,
        checkins,
        toasts,
        comments,
        userBadges,
        wishlistItems
      ];
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String username,
  required String displayName,
  Value<String> avatarEmoji,
  Value<String?> bio,
  Value<String> favoriteStyles,
  Value<bool> isMe,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> username,
  Value<String> displayName,
  Value<String> avatarEmoji,
  Value<String?> bio,
  Value<String> favoriteStyles,
  Value<bool> isMe,
  Value<int> rowid,
});

final class $$ProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $ProfilesTable, Profile> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionsTable, List<Session>> _sessionsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.sessions,
          aliasName: $_aliasNameGenerator(db.profiles.id, db.sessions.hostId));

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager($_db, $_db.sessions)
        .filter((f) => f.hostId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SessionParticipantsTable,
      List<SessionParticipant>> _sessionParticipantsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.sessionParticipants,
          aliasName: $_aliasNameGenerator(
              db.profiles.id, db.sessionParticipants.profileId));

  $$SessionParticipantsTableProcessedTableManager get sessionParticipantsRefs {
    final manager =
        $$SessionParticipantsTableTableManager($_db, $_db.sessionParticipants)
            .filter((f) => f.profileId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_sessionParticipantsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CheckinsTable, List<Checkin>> _checkinsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.checkins,
          aliasName:
              $_aliasNameGenerator(db.profiles.id, db.checkins.profileId));

  $$CheckinsTableProcessedTableManager get checkinsRefs {
    final manager = $$CheckinsTableTableManager($_db, $_db.checkins)
        .filter((f) => f.profileId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_checkinsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ToastsTable, List<Toast>> _toastsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.toasts,
          aliasName: $_aliasNameGenerator(db.profiles.id, db.toasts.profileId));

  $$ToastsTableProcessedTableManager get toastsRefs {
    final manager = $$ToastsTableTableManager($_db, $_db.toasts)
        .filter((f) => f.profileId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_toastsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CommentsTable, List<Comment>> _commentsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.comments,
          aliasName:
              $_aliasNameGenerator(db.profiles.id, db.comments.profileId));

  $$CommentsTableProcessedTableManager get commentsRefs {
    final manager = $$CommentsTableTableManager($_db, $_db.comments)
        .filter((f) => f.profileId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_commentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$UserBadgesTable, List<UserBadge>>
      _userBadgesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.userBadges,
          aliasName:
              $_aliasNameGenerator(db.profiles.id, db.userBadges.profileId));

  $$UserBadgesTableProcessedTableManager get userBadgesRefs {
    final manager = $$UserBadgesTableTableManager($_db, $_db.userBadges)
        .filter((f) => f.profileId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_userBadgesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WishlistItemsTable, List<WishlistItem>>
      _wishlistItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.wishlistItems,
              aliasName: $_aliasNameGenerator(
                  db.profiles.id, db.wishlistItems.profileId));

  $$WishlistItemsTableProcessedTableManager get wishlistItemsRefs {
    final manager = $$WishlistItemsTableTableManager($_db, $_db.wishlistItems)
        .filter((f) => f.profileId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_wishlistItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarEmoji => $composableBuilder(
      column: $table.avatarEmoji, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bio => $composableBuilder(
      column: $table.bio, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get favoriteStyles => $composableBuilder(
      column: $table.favoriteStyles,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMe => $composableBuilder(
      column: $table.isMe, builder: (column) => ColumnFilters(column));

  Expression<bool> sessionsRefs(
      Expression<bool> Function($$SessionsTableFilterComposer f) f) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.hostId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableFilterComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> sessionParticipantsRefs(
      Expression<bool> Function($$SessionParticipantsTableFilterComposer f) f) {
    final $$SessionParticipantsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionParticipants,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionParticipantsTableFilterComposer(
              $db: $db,
              $table: $db.sessionParticipants,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> checkinsRefs(
      Expression<bool> Function($$CheckinsTableFilterComposer f) f) {
    final $$CheckinsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableFilterComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> toastsRefs(
      Expression<bool> Function($$ToastsTableFilterComposer f) f) {
    final $$ToastsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.toasts,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ToastsTableFilterComposer(
              $db: $db,
              $table: $db.toasts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> commentsRefs(
      Expression<bool> Function($$CommentsTableFilterComposer f) f) {
    final $$CommentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.comments,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommentsTableFilterComposer(
              $db: $db,
              $table: $db.comments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> userBadgesRefs(
      Expression<bool> Function($$UserBadgesTableFilterComposer f) f) {
    final $$UserBadgesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.userBadges,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UserBadgesTableFilterComposer(
              $db: $db,
              $table: $db.userBadges,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> wishlistItemsRefs(
      Expression<bool> Function($$WishlistItemsTableFilterComposer f) f) {
    final $$WishlistItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.wishlistItems,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishlistItemsTableFilterComposer(
              $db: $db,
              $table: $db.wishlistItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarEmoji => $composableBuilder(
      column: $table.avatarEmoji, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bio => $composableBuilder(
      column: $table.bio, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get favoriteStyles => $composableBuilder(
      column: $table.favoriteStyles,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMe => $composableBuilder(
      column: $table.isMe, builder: (column) => ColumnOrderings(column));
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get avatarEmoji => $composableBuilder(
      column: $table.avatarEmoji, builder: (column) => column);

  GeneratedColumn<String> get bio =>
      $composableBuilder(column: $table.bio, builder: (column) => column);

  GeneratedColumn<String> get favoriteStyles => $composableBuilder(
      column: $table.favoriteStyles, builder: (column) => column);

  GeneratedColumn<bool> get isMe =>
      $composableBuilder(column: $table.isMe, builder: (column) => column);

  Expression<T> sessionsRefs<T extends Object>(
      Expression<T> Function($$SessionsTableAnnotationComposer a) f) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.hostId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> sessionParticipantsRefs<T extends Object>(
      Expression<T> Function($$SessionParticipantsTableAnnotationComposer a)
          f) {
    final $$SessionParticipantsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.sessionParticipants,
            getReferencedColumn: (t) => t.profileId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$SessionParticipantsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.sessionParticipants,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> checkinsRefs<T extends Object>(
      Expression<T> Function($$CheckinsTableAnnotationComposer a) f) {
    final $$CheckinsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableAnnotationComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> toastsRefs<T extends Object>(
      Expression<T> Function($$ToastsTableAnnotationComposer a) f) {
    final $$ToastsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.toasts,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ToastsTableAnnotationComposer(
              $db: $db,
              $table: $db.toasts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> commentsRefs<T extends Object>(
      Expression<T> Function($$CommentsTableAnnotationComposer a) f) {
    final $$CommentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.comments,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommentsTableAnnotationComposer(
              $db: $db,
              $table: $db.comments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> userBadgesRefs<T extends Object>(
      Expression<T> Function($$UserBadgesTableAnnotationComposer a) f) {
    final $$UserBadgesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.userBadges,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UserBadgesTableAnnotationComposer(
              $db: $db,
              $table: $db.userBadges,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> wishlistItemsRefs<T extends Object>(
      Expression<T> Function($$WishlistItemsTableAnnotationComposer a) f) {
    final $$WishlistItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.wishlistItems,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishlistItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.wishlistItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProfilesTable,
    Profile,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (Profile, $$ProfilesTableReferences),
    Profile,
    PrefetchHooks Function(
        {bool sessionsRefs,
        bool sessionParticipantsRefs,
        bool checkinsRefs,
        bool toastsRefs,
        bool commentsRefs,
        bool userBadgesRefs,
        bool wishlistItemsRefs})> {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String> avatarEmoji = const Value.absent(),
            Value<String?> bio = const Value.absent(),
            Value<String> favoriteStyles = const Value.absent(),
            Value<bool> isMe = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion(
            id: id,
            username: username,
            displayName: displayName,
            avatarEmoji: avatarEmoji,
            bio: bio,
            favoriteStyles: favoriteStyles,
            isMe: isMe,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String username,
            required String displayName,
            Value<String> avatarEmoji = const Value.absent(),
            Value<String?> bio = const Value.absent(),
            Value<String> favoriteStyles = const Value.absent(),
            Value<bool> isMe = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion.insert(
            id: id,
            username: username,
            displayName: displayName,
            avatarEmoji: avatarEmoji,
            bio: bio,
            favoriteStyles: favoriteStyles,
            isMe: isMe,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ProfilesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {sessionsRefs = false,
              sessionParticipantsRefs = false,
              checkinsRefs = false,
              toastsRefs = false,
              commentsRefs = false,
              userBadgesRefs = false,
              wishlistItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionsRefs) db.sessions,
                if (sessionParticipantsRefs) db.sessionParticipants,
                if (checkinsRefs) db.checkins,
                if (toastsRefs) db.toasts,
                if (commentsRefs) db.comments,
                if (userBadgesRefs) db.userBadges,
                if (wishlistItemsRefs) db.wishlistItems
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$ProfilesTableReferences._sessionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .sessionsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.hostId == item.id),
                        typedResults: items),
                  if (sessionParticipantsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$ProfilesTableReferences
                            ._sessionParticipantsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .sessionParticipantsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (checkinsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$ProfilesTableReferences._checkinsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .checkinsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (toastsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$ProfilesTableReferences._toastsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0).toastsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (commentsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$ProfilesTableReferences._commentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .commentsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (userBadgesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$ProfilesTableReferences._userBadgesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .userBadgesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (wishlistItemsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$ProfilesTableReferences
                            ._wishlistItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .wishlistItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProfilesTable,
    Profile,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (Profile, $$ProfilesTableReferences),
    Profile,
    PrefetchHooks Function(
        {bool sessionsRefs,
        bool sessionParticipantsRefs,
        bool checkinsRefs,
        bool toastsRefs,
        bool commentsRefs,
        bool userBadgesRefs,
        bool wishlistItemsRefs})>;
typedef $$BreweriesTableCreateCompanionBuilder = BreweriesCompanion Function({
  required String id,
  required String name,
  required String country,
  required String city,
  Value<String?> address,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<int?> founded,
  Value<String?> website,
  Value<String?> ownership,
  Value<int?> employees,
  Value<int?> annualOutputHl,
  Value<int?> revenueEur,
  Value<String?> notes,
  Value<String?> dataStatus,
  Value<int> rowid,
});
typedef $$BreweriesTableUpdateCompanionBuilder = BreweriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> country,
  Value<String> city,
  Value<String?> address,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<int?> founded,
  Value<String?> website,
  Value<String?> ownership,
  Value<int?> employees,
  Value<int?> annualOutputHl,
  Value<int?> revenueEur,
  Value<String?> notes,
  Value<String?> dataStatus,
  Value<int> rowid,
});

final class $$BreweriesTableReferences
    extends BaseReferences<_$AppDatabase, $BreweriesTable, Brewery> {
  $$BreweriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BeersTable, List<Beer>> _beersRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.beers,
          aliasName: $_aliasNameGenerator(db.breweries.id, db.beers.breweryId));

  $$BeersTableProcessedTableManager get beersRefs {
    final manager = $$BeersTableTableManager($_db, $_db.beers)
        .filter((f) => f.breweryId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_beersRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BreweriesTableFilterComposer
    extends Composer<_$AppDatabase, $BreweriesTable> {
  $$BreweriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get founded => $composableBuilder(
      column: $table.founded, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get website => $composableBuilder(
      column: $table.website, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownership => $composableBuilder(
      column: $table.ownership, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get employees => $composableBuilder(
      column: $table.employees, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get annualOutputHl => $composableBuilder(
      column: $table.annualOutputHl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revenueEur => $composableBuilder(
      column: $table.revenueEur, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataStatus => $composableBuilder(
      column: $table.dataStatus, builder: (column) => ColumnFilters(column));

  Expression<bool> beersRefs(
      Expression<bool> Function($$BeersTableFilterComposer f) f) {
    final $$BeersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.beers,
        getReferencedColumn: (t) => t.breweryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BeersTableFilterComposer(
              $db: $db,
              $table: $db.beers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BreweriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BreweriesTable> {
  $$BreweriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get founded => $composableBuilder(
      column: $table.founded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get website => $composableBuilder(
      column: $table.website, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownership => $composableBuilder(
      column: $table.ownership, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get employees => $composableBuilder(
      column: $table.employees, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get annualOutputHl => $composableBuilder(
      column: $table.annualOutputHl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revenueEur => $composableBuilder(
      column: $table.revenueEur, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataStatus => $composableBuilder(
      column: $table.dataStatus, builder: (column) => ColumnOrderings(column));
}

class $$BreweriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BreweriesTable> {
  $$BreweriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get founded =>
      $composableBuilder(column: $table.founded, builder: (column) => column);

  GeneratedColumn<String> get website =>
      $composableBuilder(column: $table.website, builder: (column) => column);

  GeneratedColumn<String> get ownership =>
      $composableBuilder(column: $table.ownership, builder: (column) => column);

  GeneratedColumn<int> get employees =>
      $composableBuilder(column: $table.employees, builder: (column) => column);

  GeneratedColumn<int> get annualOutputHl => $composableBuilder(
      column: $table.annualOutputHl, builder: (column) => column);

  GeneratedColumn<int> get revenueEur => $composableBuilder(
      column: $table.revenueEur, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get dataStatus => $composableBuilder(
      column: $table.dataStatus, builder: (column) => column);

  Expression<T> beersRefs<T extends Object>(
      Expression<T> Function($$BeersTableAnnotationComposer a) f) {
    final $$BeersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.beers,
        getReferencedColumn: (t) => t.breweryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BeersTableAnnotationComposer(
              $db: $db,
              $table: $db.beers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BreweriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BreweriesTable,
    Brewery,
    $$BreweriesTableFilterComposer,
    $$BreweriesTableOrderingComposer,
    $$BreweriesTableAnnotationComposer,
    $$BreweriesTableCreateCompanionBuilder,
    $$BreweriesTableUpdateCompanionBuilder,
    (Brewery, $$BreweriesTableReferences),
    Brewery,
    PrefetchHooks Function({bool beersRefs})> {
  $$BreweriesTableTableManager(_$AppDatabase db, $BreweriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BreweriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BreweriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BreweriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> country = const Value.absent(),
            Value<String> city = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<int?> founded = const Value.absent(),
            Value<String?> website = const Value.absent(),
            Value<String?> ownership = const Value.absent(),
            Value<int?> employees = const Value.absent(),
            Value<int?> annualOutputHl = const Value.absent(),
            Value<int?> revenueEur = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> dataStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BreweriesCompanion(
            id: id,
            name: name,
            country: country,
            city: city,
            address: address,
            latitude: latitude,
            longitude: longitude,
            founded: founded,
            website: website,
            ownership: ownership,
            employees: employees,
            annualOutputHl: annualOutputHl,
            revenueEur: revenueEur,
            notes: notes,
            dataStatus: dataStatus,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String country,
            required String city,
            Value<String?> address = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<int?> founded = const Value.absent(),
            Value<String?> website = const Value.absent(),
            Value<String?> ownership = const Value.absent(),
            Value<int?> employees = const Value.absent(),
            Value<int?> annualOutputHl = const Value.absent(),
            Value<int?> revenueEur = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> dataStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BreweriesCompanion.insert(
            id: id,
            name: name,
            country: country,
            city: city,
            address: address,
            latitude: latitude,
            longitude: longitude,
            founded: founded,
            website: website,
            ownership: ownership,
            employees: employees,
            annualOutputHl: annualOutputHl,
            revenueEur: revenueEur,
            notes: notes,
            dataStatus: dataStatus,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BreweriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({beersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (beersRefs) db.beers],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (beersRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$BreweriesTableReferences._beersRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BreweriesTableReferences(db, table, p0).beersRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.breweryId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BreweriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BreweriesTable,
    Brewery,
    $$BreweriesTableFilterComposer,
    $$BreweriesTableOrderingComposer,
    $$BreweriesTableAnnotationComposer,
    $$BreweriesTableCreateCompanionBuilder,
    $$BreweriesTableUpdateCompanionBuilder,
    (Brewery, $$BreweriesTableReferences),
    Brewery,
    PrefetchHooks Function({bool beersRefs})>;
typedef $$BeersTableCreateCompanionBuilder = BeersCompanion Function({
  required String id,
  required String breweryId,
  required String name,
  required String style,
  Value<double?> abv,
  Value<int?> ibu,
  Value<String?> description,
  Value<bool> isAlcoholFree,
  Value<bool> isUserSubmitted,
  Value<String?> descriptionCommunity,
  Value<double?> communityRating,
  Value<String> barcodes,
  Value<String?> imageUrl,
  Value<int> rowid,
});
typedef $$BeersTableUpdateCompanionBuilder = BeersCompanion Function({
  Value<String> id,
  Value<String> breweryId,
  Value<String> name,
  Value<String> style,
  Value<double?> abv,
  Value<int?> ibu,
  Value<String?> description,
  Value<bool> isAlcoholFree,
  Value<bool> isUserSubmitted,
  Value<String?> descriptionCommunity,
  Value<double?> communityRating,
  Value<String> barcodes,
  Value<String?> imageUrl,
  Value<int> rowid,
});

final class $$BeersTableReferences
    extends BaseReferences<_$AppDatabase, $BeersTable, Beer> {
  $$BeersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BreweriesTable _breweryIdTable(_$AppDatabase db) => db.breweries
      .createAlias($_aliasNameGenerator(db.beers.breweryId, db.breweries.id));

  $$BreweriesTableProcessedTableManager get breweryId {
    final manager = $$BreweriesTableTableManager($_db, $_db.breweries)
        .filter((f) => f.id($_item.breweryId));
    final item = $_typedResult.readTableOrNull(_breweryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$CheckinsTable, List<Checkin>> _checkinsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.checkins,
          aliasName: $_aliasNameGenerator(db.beers.id, db.checkins.beerId));

  $$CheckinsTableProcessedTableManager get checkinsRefs {
    final manager = $$CheckinsTableTableManager($_db, $_db.checkins)
        .filter((f) => f.beerId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_checkinsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WishlistItemsTable, List<WishlistItem>>
      _wishlistItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.wishlistItems,
              aliasName:
                  $_aliasNameGenerator(db.beers.id, db.wishlistItems.beerId));

  $$WishlistItemsTableProcessedTableManager get wishlistItemsRefs {
    final manager = $$WishlistItemsTableTableManager($_db, $_db.wishlistItems)
        .filter((f) => f.beerId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_wishlistItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BeersTableFilterComposer extends Composer<_$AppDatabase, $BeersTable> {
  $$BeersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get style => $composableBuilder(
      column: $table.style, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get abv => $composableBuilder(
      column: $table.abv, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ibu => $composableBuilder(
      column: $table.ibu, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAlcoholFree => $composableBuilder(
      column: $table.isAlcoholFree, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isUserSubmitted => $composableBuilder(
      column: $table.isUserSubmitted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get descriptionCommunity => $composableBuilder(
      column: $table.descriptionCommunity,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get communityRating => $composableBuilder(
      column: $table.communityRating,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcodes => $composableBuilder(
      column: $table.barcodes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  $$BreweriesTableFilterComposer get breweryId {
    final $$BreweriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.breweryId,
        referencedTable: $db.breweries,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BreweriesTableFilterComposer(
              $db: $db,
              $table: $db.breweries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> checkinsRefs(
      Expression<bool> Function($$CheckinsTableFilterComposer f) f) {
    final $$CheckinsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.beerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableFilterComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> wishlistItemsRefs(
      Expression<bool> Function($$WishlistItemsTableFilterComposer f) f) {
    final $$WishlistItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.wishlistItems,
        getReferencedColumn: (t) => t.beerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishlistItemsTableFilterComposer(
              $db: $db,
              $table: $db.wishlistItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BeersTableOrderingComposer
    extends Composer<_$AppDatabase, $BeersTable> {
  $$BeersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get style => $composableBuilder(
      column: $table.style, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get abv => $composableBuilder(
      column: $table.abv, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ibu => $composableBuilder(
      column: $table.ibu, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAlcoholFree => $composableBuilder(
      column: $table.isAlcoholFree,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isUserSubmitted => $composableBuilder(
      column: $table.isUserSubmitted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get descriptionCommunity => $composableBuilder(
      column: $table.descriptionCommunity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get communityRating => $composableBuilder(
      column: $table.communityRating,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcodes => $composableBuilder(
      column: $table.barcodes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  $$BreweriesTableOrderingComposer get breweryId {
    final $$BreweriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.breweryId,
        referencedTable: $db.breweries,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BreweriesTableOrderingComposer(
              $db: $db,
              $table: $db.breweries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BeersTableAnnotationComposer
    extends Composer<_$AppDatabase, $BeersTable> {
  $$BeersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<double> get abv =>
      $composableBuilder(column: $table.abv, builder: (column) => column);

  GeneratedColumn<int> get ibu =>
      $composableBuilder(column: $table.ibu, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<bool> get isAlcoholFree => $composableBuilder(
      column: $table.isAlcoholFree, builder: (column) => column);

  GeneratedColumn<bool> get isUserSubmitted => $composableBuilder(
      column: $table.isUserSubmitted, builder: (column) => column);

  GeneratedColumn<String> get descriptionCommunity => $composableBuilder(
      column: $table.descriptionCommunity, builder: (column) => column);

  GeneratedColumn<double> get communityRating => $composableBuilder(
      column: $table.communityRating, builder: (column) => column);

  GeneratedColumn<String> get barcodes =>
      $composableBuilder(column: $table.barcodes, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  $$BreweriesTableAnnotationComposer get breweryId {
    final $$BreweriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.breweryId,
        referencedTable: $db.breweries,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BreweriesTableAnnotationComposer(
              $db: $db,
              $table: $db.breweries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> checkinsRefs<T extends Object>(
      Expression<T> Function($$CheckinsTableAnnotationComposer a) f) {
    final $$CheckinsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.beerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableAnnotationComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> wishlistItemsRefs<T extends Object>(
      Expression<T> Function($$WishlistItemsTableAnnotationComposer a) f) {
    final $$WishlistItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.wishlistItems,
        getReferencedColumn: (t) => t.beerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishlistItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.wishlistItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BeersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BeersTable,
    Beer,
    $$BeersTableFilterComposer,
    $$BeersTableOrderingComposer,
    $$BeersTableAnnotationComposer,
    $$BeersTableCreateCompanionBuilder,
    $$BeersTableUpdateCompanionBuilder,
    (Beer, $$BeersTableReferences),
    Beer,
    PrefetchHooks Function(
        {bool breweryId, bool checkinsRefs, bool wishlistItemsRefs})> {
  $$BeersTableTableManager(_$AppDatabase db, $BeersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BeersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BeersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BeersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> breweryId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> style = const Value.absent(),
            Value<double?> abv = const Value.absent(),
            Value<int?> ibu = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<bool> isAlcoholFree = const Value.absent(),
            Value<bool> isUserSubmitted = const Value.absent(),
            Value<String?> descriptionCommunity = const Value.absent(),
            Value<double?> communityRating = const Value.absent(),
            Value<String> barcodes = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BeersCompanion(
            id: id,
            breweryId: breweryId,
            name: name,
            style: style,
            abv: abv,
            ibu: ibu,
            description: description,
            isAlcoholFree: isAlcoholFree,
            isUserSubmitted: isUserSubmitted,
            descriptionCommunity: descriptionCommunity,
            communityRating: communityRating,
            barcodes: barcodes,
            imageUrl: imageUrl,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String breweryId,
            required String name,
            required String style,
            Value<double?> abv = const Value.absent(),
            Value<int?> ibu = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<bool> isAlcoholFree = const Value.absent(),
            Value<bool> isUserSubmitted = const Value.absent(),
            Value<String?> descriptionCommunity = const Value.absent(),
            Value<double?> communityRating = const Value.absent(),
            Value<String> barcodes = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BeersCompanion.insert(
            id: id,
            breweryId: breweryId,
            name: name,
            style: style,
            abv: abv,
            ibu: ibu,
            description: description,
            isAlcoholFree: isAlcoholFree,
            isUserSubmitted: isUserSubmitted,
            descriptionCommunity: descriptionCommunity,
            communityRating: communityRating,
            barcodes: barcodes,
            imageUrl: imageUrl,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$BeersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {breweryId = false,
              checkinsRefs = false,
              wishlistItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (checkinsRefs) db.checkins,
                if (wishlistItemsRefs) db.wishlistItems
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (breweryId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.breweryId,
                    referencedTable: $$BeersTableReferences._breweryIdTable(db),
                    referencedColumn:
                        $$BeersTableReferences._breweryIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (checkinsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$BeersTableReferences._checkinsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BeersTableReferences(db, table, p0).checkinsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.beerId == item.id),
                        typedResults: items),
                  if (wishlistItemsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$BeersTableReferences._wishlistItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BeersTableReferences(db, table, p0)
                                .wishlistItemsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.beerId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BeersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BeersTable,
    Beer,
    $$BeersTableFilterComposer,
    $$BeersTableOrderingComposer,
    $$BeersTableAnnotationComposer,
    $$BeersTableCreateCompanionBuilder,
    $$BeersTableUpdateCompanionBuilder,
    (Beer, $$BeersTableReferences),
    Beer,
    PrefetchHooks Function(
        {bool breweryId, bool checkinsRefs, bool wishlistItemsRefs})>;
typedef $$VenuesTableCreateCompanionBuilder = VenuesCompanion Function({
  required String id,
  required String name,
  Value<String> category,
  Value<String?> address,
  Value<String?> city,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> openingHours,
  Value<double?> priceHalfL,
  Value<double?> priceThirdL,
  Value<bool> verified,
  Value<String?> createdBy,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});
typedef $$VenuesTableUpdateCompanionBuilder = VenuesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> category,
  Value<String?> address,
  Value<String?> city,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> openingHours,
  Value<double?> priceHalfL,
  Value<double?> priceThirdL,
  Value<bool> verified,
  Value<String?> createdBy,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});

class $$VenuesTableFilterComposer
    extends Composer<_$AppDatabase, $VenuesTable> {
  $$VenuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get openingHours => $composableBuilder(
      column: $table.openingHours, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get priceHalfL => $composableBuilder(
      column: $table.priceHalfL, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get priceThirdL => $composableBuilder(
      column: $table.priceThirdL, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get verified => $composableBuilder(
      column: $table.verified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$VenuesTableOrderingComposer
    extends Composer<_$AppDatabase, $VenuesTable> {
  $$VenuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get openingHours => $composableBuilder(
      column: $table.openingHours,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get priceHalfL => $composableBuilder(
      column: $table.priceHalfL, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get priceThirdL => $composableBuilder(
      column: $table.priceThirdL, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get verified => $composableBuilder(
      column: $table.verified, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$VenuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VenuesTable> {
  $$VenuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get openingHours => $composableBuilder(
      column: $table.openingHours, builder: (column) => column);

  GeneratedColumn<double> get priceHalfL => $composableBuilder(
      column: $table.priceHalfL, builder: (column) => column);

  GeneratedColumn<double> get priceThirdL => $composableBuilder(
      column: $table.priceThirdL, builder: (column) => column);

  GeneratedColumn<bool> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$VenuesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VenuesTable,
    Venue,
    $$VenuesTableFilterComposer,
    $$VenuesTableOrderingComposer,
    $$VenuesTableAnnotationComposer,
    $$VenuesTableCreateCompanionBuilder,
    $$VenuesTableUpdateCompanionBuilder,
    (Venue, BaseReferences<_$AppDatabase, $VenuesTable, Venue>),
    Venue,
    PrefetchHooks Function()> {
  $$VenuesTableTableManager(_$AppDatabase db, $VenuesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VenuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VenuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VenuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String?> openingHours = const Value.absent(),
            Value<double?> priceHalfL = const Value.absent(),
            Value<double?> priceThirdL = const Value.absent(),
            Value<bool> verified = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VenuesCompanion(
            id: id,
            name: name,
            category: category,
            address: address,
            city: city,
            latitude: latitude,
            longitude: longitude,
            openingHours: openingHours,
            priceHalfL: priceHalfL,
            priceThirdL: priceThirdL,
            verified: verified,
            createdBy: createdBy,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> category = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String?> openingHours = const Value.absent(),
            Value<double?> priceHalfL = const Value.absent(),
            Value<double?> priceThirdL = const Value.absent(),
            Value<bool> verified = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VenuesCompanion.insert(
            id: id,
            name: name,
            category: category,
            address: address,
            city: city,
            latitude: latitude,
            longitude: longitude,
            openingHours: openingHours,
            priceHalfL: priceHalfL,
            priceThirdL: priceThirdL,
            verified: verified,
            createdBy: createdBy,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$VenuesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $VenuesTable,
    Venue,
    $$VenuesTableFilterComposer,
    $$VenuesTableOrderingComposer,
    $$VenuesTableAnnotationComposer,
    $$VenuesTableCreateCompanionBuilder,
    $$VenuesTableUpdateCompanionBuilder,
    (Venue, BaseReferences<_$AppDatabase, $VenuesTable, Venue>),
    Venue,
    PrefetchHooks Function()>;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required String hostId,
  Value<String?> venueId,
  Value<String?> venueName,
  Value<String?> message,
  required SessionVisibility visibility,
  required SessionStatus status,
  required DateTime startedAt,
  Value<DateTime?> endedAt,
  required DateTime expiresAt,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String> hostId,
  Value<String?> venueId,
  Value<String?> venueName,
  Value<String?> message,
  Value<SessionVisibility> visibility,
  Value<SessionStatus> status,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<DateTime> expiresAt,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<int> rowid,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _hostIdTable(_$AppDatabase db) => db.profiles
      .createAlias($_aliasNameGenerator(db.sessions.hostId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get hostId {
    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id($_item.hostId));
    final item = $_typedResult.readTableOrNull(_hostIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$SessionParticipantsTable,
      List<SessionParticipant>> _sessionParticipantsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.sessionParticipants,
          aliasName: $_aliasNameGenerator(
              db.sessions.id, db.sessionParticipants.sessionId));

  $$SessionParticipantsTableProcessedTableManager get sessionParticipantsRefs {
    final manager =
        $$SessionParticipantsTableTableManager($_db, $_db.sessionParticipants)
            .filter((f) => f.sessionId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_sessionParticipantsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get venueId => $composableBuilder(
      column: $table.venueId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get venueName => $composableBuilder(
      column: $table.venueName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SessionVisibility, SessionVisibility, String>
      get visibility => $composableBuilder(
          column: $table.visibility,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<SessionStatus, SessionStatus, String>
      get status => $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get hostId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.hostId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> sessionParticipantsRefs(
      Expression<bool> Function($$SessionParticipantsTableFilterComposer f) f) {
    final $$SessionParticipantsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionParticipants,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionParticipantsTableFilterComposer(
              $db: $db,
              $table: $db.sessionParticipants,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get venueId => $composableBuilder(
      column: $table.venueId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get venueName => $composableBuilder(
      column: $table.venueName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get hostId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.hostId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get venueId =>
      $composableBuilder(column: $table.venueId, builder: (column) => column);

  GeneratedColumn<String> get venueName =>
      $composableBuilder(column: $table.venueName, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SessionVisibility, String> get visibility =>
      $composableBuilder(
          column: $table.visibility, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SessionStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get hostId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.hostId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> sessionParticipantsRefs<T extends Object>(
      Expression<T> Function($$SessionParticipantsTableAnnotationComposer a)
          f) {
    final $$SessionParticipantsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.sessionParticipants,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$SessionParticipantsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.sessionParticipants,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$SessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function({bool hostId, bool sessionParticipantsRefs})> {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> hostId = const Value.absent(),
            Value<String?> venueId = const Value.absent(),
            Value<String?> venueName = const Value.absent(),
            Value<String?> message = const Value.absent(),
            Value<SessionVisibility> visibility = const Value.absent(),
            Value<SessionStatus> status = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> endedAt = const Value.absent(),
            Value<DateTime> expiresAt = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion(
            id: id,
            hostId: hostId,
            venueId: venueId,
            venueName: venueName,
            message: message,
            visibility: visibility,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            expiresAt: expiresAt,
            latitude: latitude,
            longitude: longitude,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String hostId,
            Value<String?> venueId = const Value.absent(),
            Value<String?> venueName = const Value.absent(),
            Value<String?> message = const Value.absent(),
            required SessionVisibility visibility,
            required SessionStatus status,
            required DateTime startedAt,
            Value<DateTime?> endedAt = const Value.absent(),
            required DateTime expiresAt,
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion.insert(
            id: id,
            hostId: hostId,
            venueId: venueId,
            venueName: venueName,
            message: message,
            visibility: visibility,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            expiresAt: expiresAt,
            latitude: latitude,
            longitude: longitude,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SessionsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {hostId = false, sessionParticipantsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionParticipantsRefs) db.sessionParticipants
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (hostId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.hostId,
                    referencedTable: $$SessionsTableReferences._hostIdTable(db),
                    referencedColumn:
                        $$SessionsTableReferences._hostIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionParticipantsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$SessionsTableReferences
                            ._sessionParticipantsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableReferences(db, table, p0)
                                .sessionParticipantsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function({bool hostId, bool sessionParticipantsRefs})>;
typedef $$SessionParticipantsTableCreateCompanionBuilder
    = SessionParticipantsCompanion Function({
  required String sessionId,
  required String profileId,
  required ParticipantKind kind,
  Value<int> rowid,
});
typedef $$SessionParticipantsTableUpdateCompanionBuilder
    = SessionParticipantsCompanion Function({
  Value<String> sessionId,
  Value<String> profileId,
  Value<ParticipantKind> kind,
  Value<int> rowid,
});

final class $$SessionParticipantsTableReferences extends BaseReferences<
    _$AppDatabase, $SessionParticipantsTable, SessionParticipant> {
  $$SessionParticipantsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias($_aliasNameGenerator(
          db.sessionParticipants.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final manager = $$SessionsTableTableManager($_db, $_db.sessions)
        .filter((f) => f.id($_item.sessionId));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias($_aliasNameGenerator(
          db.sessionParticipants.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id($_item.profileId));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SessionParticipantsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionParticipantsTable> {
  $$SessionParticipantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<ParticipantKind, ParticipantKind, String>
      get kind => $composableBuilder(
          column: $table.kind,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableFilterComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionParticipantsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionParticipantsTable> {
  $$SessionParticipantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableOrderingComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionParticipantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionParticipantsTable> {
  $$SessionParticipantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<ParticipantKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionParticipantsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionParticipantsTable,
    SessionParticipant,
    $$SessionParticipantsTableFilterComposer,
    $$SessionParticipantsTableOrderingComposer,
    $$SessionParticipantsTableAnnotationComposer,
    $$SessionParticipantsTableCreateCompanionBuilder,
    $$SessionParticipantsTableUpdateCompanionBuilder,
    (SessionParticipant, $$SessionParticipantsTableReferences),
    SessionParticipant,
    PrefetchHooks Function({bool sessionId, bool profileId})> {
  $$SessionParticipantsTableTableManager(
      _$AppDatabase db, $SessionParticipantsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionParticipantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionParticipantsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionParticipantsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> sessionId = const Value.absent(),
            Value<String> profileId = const Value.absent(),
            Value<ParticipantKind> kind = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionParticipantsCompanion(
            sessionId: sessionId,
            profileId: profileId,
            kind: kind,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String sessionId,
            required String profileId,
            required ParticipantKind kind,
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionParticipantsCompanion.insert(
            sessionId: sessionId,
            profileId: profileId,
            kind: kind,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SessionParticipantsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false, profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable: $$SessionParticipantsTableReferences
                        ._sessionIdTable(db),
                    referencedColumn: $$SessionParticipantsTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable: $$SessionParticipantsTableReferences
                        ._profileIdTable(db),
                    referencedColumn: $$SessionParticipantsTableReferences
                        ._profileIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SessionParticipantsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionParticipantsTable,
    SessionParticipant,
    $$SessionParticipantsTableFilterComposer,
    $$SessionParticipantsTableOrderingComposer,
    $$SessionParticipantsTableAnnotationComposer,
    $$SessionParticipantsTableCreateCompanionBuilder,
    $$SessionParticipantsTableUpdateCompanionBuilder,
    (SessionParticipant, $$SessionParticipantsTableReferences),
    SessionParticipant,
    PrefetchHooks Function({bool sessionId, bool profileId})>;
typedef $$CheckinsTableCreateCompanionBuilder = CheckinsCompanion Function({
  required String id,
  required String profileId,
  required String beerId,
  Value<String?> sessionId,
  Value<String?> venueId,
  Value<String?> venueName,
  Value<double?> rating,
  Value<String?> note,
  Value<String> flavorTags,
  Value<ServingStyle?> servingStyle,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$CheckinsTableUpdateCompanionBuilder = CheckinsCompanion Function({
  Value<String> id,
  Value<String> profileId,
  Value<String> beerId,
  Value<String?> sessionId,
  Value<String?> venueId,
  Value<String?> venueName,
  Value<double?> rating,
  Value<String?> note,
  Value<String> flavorTags,
  Value<ServingStyle?> servingStyle,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$CheckinsTableReferences
    extends BaseReferences<_$AppDatabase, $CheckinsTable, Checkin> {
  $$CheckinsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) => db.profiles
      .createAlias($_aliasNameGenerator(db.checkins.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id($_item.profileId));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $BeersTable _beerIdTable(_$AppDatabase db) => db.beers
      .createAlias($_aliasNameGenerator(db.checkins.beerId, db.beers.id));

  $$BeersTableProcessedTableManager get beerId {
    final manager = $$BeersTableTableManager($_db, $_db.beers)
        .filter((f) => f.id($_item.beerId));
    final item = $_typedResult.readTableOrNull(_beerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$ToastsTable, List<Toast>> _toastsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.toasts,
          aliasName: $_aliasNameGenerator(db.checkins.id, db.toasts.checkinId));

  $$ToastsTableProcessedTableManager get toastsRefs {
    final manager = $$ToastsTableTableManager($_db, $_db.toasts)
        .filter((f) => f.checkinId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_toastsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CommentsTable, List<Comment>> _commentsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.comments,
          aliasName:
              $_aliasNameGenerator(db.checkins.id, db.comments.checkinId));

  $$CommentsTableProcessedTableManager get commentsRefs {
    final manager = $$CommentsTableTableManager($_db, $_db.comments)
        .filter((f) => f.checkinId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_commentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CheckinsTableFilterComposer
    extends Composer<_$AppDatabase, $CheckinsTable> {
  $$CheckinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get venueId => $composableBuilder(
      column: $table.venueId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get venueName => $composableBuilder(
      column: $table.venueName, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get flavorTags => $composableBuilder(
      column: $table.flavorTags, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ServingStyle?, ServingStyle, String>
      get servingStyle => $composableBuilder(
          column: $table.servingStyle,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BeersTableFilterComposer get beerId {
    final $$BeersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.beerId,
        referencedTable: $db.beers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BeersTableFilterComposer(
              $db: $db,
              $table: $db.beers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> toastsRefs(
      Expression<bool> Function($$ToastsTableFilterComposer f) f) {
    final $$ToastsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.toasts,
        getReferencedColumn: (t) => t.checkinId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ToastsTableFilterComposer(
              $db: $db,
              $table: $db.toasts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> commentsRefs(
      Expression<bool> Function($$CommentsTableFilterComposer f) f) {
    final $$CommentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.comments,
        getReferencedColumn: (t) => t.checkinId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommentsTableFilterComposer(
              $db: $db,
              $table: $db.comments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CheckinsTableOrderingComposer
    extends Composer<_$AppDatabase, $CheckinsTable> {
  $$CheckinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get venueId => $composableBuilder(
      column: $table.venueId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get venueName => $composableBuilder(
      column: $table.venueName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get flavorTags => $composableBuilder(
      column: $table.flavorTags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get servingStyle => $composableBuilder(
      column: $table.servingStyle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BeersTableOrderingComposer get beerId {
    final $$BeersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.beerId,
        referencedTable: $db.beers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BeersTableOrderingComposer(
              $db: $db,
              $table: $db.beers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CheckinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheckinsTable> {
  $$CheckinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get venueId =>
      $composableBuilder(column: $table.venueId, builder: (column) => column);

  GeneratedColumn<String> get venueName =>
      $composableBuilder(column: $table.venueName, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get flavorTags => $composableBuilder(
      column: $table.flavorTags, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ServingStyle?, String> get servingStyle =>
      $composableBuilder(
          column: $table.servingStyle, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BeersTableAnnotationComposer get beerId {
    final $$BeersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.beerId,
        referencedTable: $db.beers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BeersTableAnnotationComposer(
              $db: $db,
              $table: $db.beers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> toastsRefs<T extends Object>(
      Expression<T> Function($$ToastsTableAnnotationComposer a) f) {
    final $$ToastsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.toasts,
        getReferencedColumn: (t) => t.checkinId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ToastsTableAnnotationComposer(
              $db: $db,
              $table: $db.toasts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> commentsRefs<T extends Object>(
      Expression<T> Function($$CommentsTableAnnotationComposer a) f) {
    final $$CommentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.comments,
        getReferencedColumn: (t) => t.checkinId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommentsTableAnnotationComposer(
              $db: $db,
              $table: $db.comments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CheckinsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CheckinsTable,
    Checkin,
    $$CheckinsTableFilterComposer,
    $$CheckinsTableOrderingComposer,
    $$CheckinsTableAnnotationComposer,
    $$CheckinsTableCreateCompanionBuilder,
    $$CheckinsTableUpdateCompanionBuilder,
    (Checkin, $$CheckinsTableReferences),
    Checkin,
    PrefetchHooks Function(
        {bool profileId, bool beerId, bool toastsRefs, bool commentsRefs})> {
  $$CheckinsTableTableManager(_$AppDatabase db, $CheckinsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> profileId = const Value.absent(),
            Value<String> beerId = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<String?> venueId = const Value.absent(),
            Value<String?> venueName = const Value.absent(),
            Value<double?> rating = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> flavorTags = const Value.absent(),
            Value<ServingStyle?> servingStyle = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CheckinsCompanion(
            id: id,
            profileId: profileId,
            beerId: beerId,
            sessionId: sessionId,
            venueId: venueId,
            venueName: venueName,
            rating: rating,
            note: note,
            flavorTags: flavorTags,
            servingStyle: servingStyle,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String profileId,
            required String beerId,
            Value<String?> sessionId = const Value.absent(),
            Value<String?> venueId = const Value.absent(),
            Value<String?> venueName = const Value.absent(),
            Value<double?> rating = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> flavorTags = const Value.absent(),
            Value<ServingStyle?> servingStyle = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CheckinsCompanion.insert(
            id: id,
            profileId: profileId,
            beerId: beerId,
            sessionId: sessionId,
            venueId: venueId,
            venueName: venueName,
            rating: rating,
            note: note,
            flavorTags: flavorTags,
            servingStyle: servingStyle,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$CheckinsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {profileId = false,
              beerId = false,
              toastsRefs = false,
              commentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (toastsRefs) db.toasts,
                if (commentsRefs) db.comments
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$CheckinsTableReferences._profileIdTable(db),
                    referencedColumn:
                        $$CheckinsTableReferences._profileIdTable(db).id,
                  ) as T;
                }
                if (beerId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.beerId,
                    referencedTable: $$CheckinsTableReferences._beerIdTable(db),
                    referencedColumn:
                        $$CheckinsTableReferences._beerIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (toastsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$CheckinsTableReferences._toastsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CheckinsTableReferences(db, table, p0).toastsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.checkinId == item.id),
                        typedResults: items),
                  if (commentsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$CheckinsTableReferences._commentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CheckinsTableReferences(db, table, p0)
                                .commentsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.checkinId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CheckinsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CheckinsTable,
    Checkin,
    $$CheckinsTableFilterComposer,
    $$CheckinsTableOrderingComposer,
    $$CheckinsTableAnnotationComposer,
    $$CheckinsTableCreateCompanionBuilder,
    $$CheckinsTableUpdateCompanionBuilder,
    (Checkin, $$CheckinsTableReferences),
    Checkin,
    PrefetchHooks Function(
        {bool profileId, bool beerId, bool toastsRefs, bool commentsRefs})>;
typedef $$ToastsTableCreateCompanionBuilder = ToastsCompanion Function({
  required String checkinId,
  required String profileId,
  Value<int> rowid,
});
typedef $$ToastsTableUpdateCompanionBuilder = ToastsCompanion Function({
  Value<String> checkinId,
  Value<String> profileId,
  Value<int> rowid,
});

final class $$ToastsTableReferences
    extends BaseReferences<_$AppDatabase, $ToastsTable, Toast> {
  $$ToastsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CheckinsTable _checkinIdTable(_$AppDatabase db) => db.checkins
      .createAlias($_aliasNameGenerator(db.toasts.checkinId, db.checkins.id));

  $$CheckinsTableProcessedTableManager get checkinId {
    final manager = $$CheckinsTableTableManager($_db, $_db.checkins)
        .filter((f) => f.id($_item.checkinId));
    final item = $_typedResult.readTableOrNull(_checkinIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProfilesTable _profileIdTable(_$AppDatabase db) => db.profiles
      .createAlias($_aliasNameGenerator(db.toasts.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id($_item.profileId));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ToastsTableFilterComposer
    extends Composer<_$AppDatabase, $ToastsTable> {
  $$ToastsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CheckinsTableFilterComposer get checkinId {
    final $$CheckinsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.checkinId,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableFilterComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ToastsTableOrderingComposer
    extends Composer<_$AppDatabase, $ToastsTable> {
  $$ToastsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CheckinsTableOrderingComposer get checkinId {
    final $$CheckinsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.checkinId,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableOrderingComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ToastsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ToastsTable> {
  $$ToastsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CheckinsTableAnnotationComposer get checkinId {
    final $$CheckinsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.checkinId,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableAnnotationComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ToastsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ToastsTable,
    Toast,
    $$ToastsTableFilterComposer,
    $$ToastsTableOrderingComposer,
    $$ToastsTableAnnotationComposer,
    $$ToastsTableCreateCompanionBuilder,
    $$ToastsTableUpdateCompanionBuilder,
    (Toast, $$ToastsTableReferences),
    Toast,
    PrefetchHooks Function({bool checkinId, bool profileId})> {
  $$ToastsTableTableManager(_$AppDatabase db, $ToastsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ToastsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ToastsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ToastsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> checkinId = const Value.absent(),
            Value<String> profileId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ToastsCompanion(
            checkinId: checkinId,
            profileId: profileId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String checkinId,
            required String profileId,
            Value<int> rowid = const Value.absent(),
          }) =>
              ToastsCompanion.insert(
            checkinId: checkinId,
            profileId: profileId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ToastsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({checkinId = false, profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (checkinId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.checkinId,
                    referencedTable:
                        $$ToastsTableReferences._checkinIdTable(db),
                    referencedColumn:
                        $$ToastsTableReferences._checkinIdTable(db).id,
                  ) as T;
                }
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$ToastsTableReferences._profileIdTable(db),
                    referencedColumn:
                        $$ToastsTableReferences._profileIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ToastsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ToastsTable,
    Toast,
    $$ToastsTableFilterComposer,
    $$ToastsTableOrderingComposer,
    $$ToastsTableAnnotationComposer,
    $$ToastsTableCreateCompanionBuilder,
    $$ToastsTableUpdateCompanionBuilder,
    (Toast, $$ToastsTableReferences),
    Toast,
    PrefetchHooks Function({bool checkinId, bool profileId})>;
typedef $$CommentsTableCreateCompanionBuilder = CommentsCompanion Function({
  required String id,
  required String checkinId,
  required String profileId,
  required String body,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$CommentsTableUpdateCompanionBuilder = CommentsCompanion Function({
  Value<String> id,
  Value<String> checkinId,
  Value<String> profileId,
  Value<String> body,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$CommentsTableReferences
    extends BaseReferences<_$AppDatabase, $CommentsTable, Comment> {
  $$CommentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CheckinsTable _checkinIdTable(_$AppDatabase db) => db.checkins
      .createAlias($_aliasNameGenerator(db.comments.checkinId, db.checkins.id));

  $$CheckinsTableProcessedTableManager get checkinId {
    final manager = $$CheckinsTableTableManager($_db, $_db.checkins)
        .filter((f) => f.id($_item.checkinId));
    final item = $_typedResult.readTableOrNull(_checkinIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProfilesTable _profileIdTable(_$AppDatabase db) => db.profiles
      .createAlias($_aliasNameGenerator(db.comments.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id($_item.profileId));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CommentsTableFilterComposer
    extends Composer<_$AppDatabase, $CommentsTable> {
  $$CommentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$CheckinsTableFilterComposer get checkinId {
    final $$CheckinsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.checkinId,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableFilterComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CommentsTable> {
  $$CommentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$CheckinsTableOrderingComposer get checkinId {
    final $$CheckinsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.checkinId,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableOrderingComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CommentsTable> {
  $$CommentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CheckinsTableAnnotationComposer get checkinId {
    final $$CheckinsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.checkinId,
        referencedTable: $db.checkins,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CheckinsTableAnnotationComposer(
              $db: $db,
              $table: $db.checkins,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CommentsTable,
    Comment,
    $$CommentsTableFilterComposer,
    $$CommentsTableOrderingComposer,
    $$CommentsTableAnnotationComposer,
    $$CommentsTableCreateCompanionBuilder,
    $$CommentsTableUpdateCompanionBuilder,
    (Comment, $$CommentsTableReferences),
    Comment,
    PrefetchHooks Function({bool checkinId, bool profileId})> {
  $$CommentsTableTableManager(_$AppDatabase db, $CommentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> checkinId = const Value.absent(),
            Value<String> profileId = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CommentsCompanion(
            id: id,
            checkinId: checkinId,
            profileId: profileId,
            body: body,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String checkinId,
            required String profileId,
            required String body,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CommentsCompanion.insert(
            id: id,
            checkinId: checkinId,
            profileId: profileId,
            body: body,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$CommentsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({checkinId = false, profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (checkinId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.checkinId,
                    referencedTable:
                        $$CommentsTableReferences._checkinIdTable(db),
                    referencedColumn:
                        $$CommentsTableReferences._checkinIdTable(db).id,
                  ) as T;
                }
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$CommentsTableReferences._profileIdTable(db),
                    referencedColumn:
                        $$CommentsTableReferences._profileIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CommentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CommentsTable,
    Comment,
    $$CommentsTableFilterComposer,
    $$CommentsTableOrderingComposer,
    $$CommentsTableAnnotationComposer,
    $$CommentsTableCreateCompanionBuilder,
    $$CommentsTableUpdateCompanionBuilder,
    (Comment, $$CommentsTableReferences),
    Comment,
    PrefetchHooks Function({bool checkinId, bool profileId})>;
typedef $$UserBadgesTableCreateCompanionBuilder = UserBadgesCompanion Function({
  required String profileId,
  required String badgeSlug,
  required DateTime awardedAt,
  Value<int> rowid,
});
typedef $$UserBadgesTableUpdateCompanionBuilder = UserBadgesCompanion Function({
  Value<String> profileId,
  Value<String> badgeSlug,
  Value<DateTime> awardedAt,
  Value<int> rowid,
});

final class $$UserBadgesTableReferences
    extends BaseReferences<_$AppDatabase, $UserBadgesTable, UserBadge> {
  $$UserBadgesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
          $_aliasNameGenerator(db.userBadges.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id($_item.profileId));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$UserBadgesTableFilterComposer
    extends Composer<_$AppDatabase, $UserBadgesTable> {
  $$UserBadgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get badgeSlug => $composableBuilder(
      column: $table.badgeSlug, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get awardedAt => $composableBuilder(
      column: $table.awardedAt, builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$UserBadgesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserBadgesTable> {
  $$UserBadgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get badgeSlug => $composableBuilder(
      column: $table.badgeSlug, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get awardedAt => $composableBuilder(
      column: $table.awardedAt, builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$UserBadgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserBadgesTable> {
  $$UserBadgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get badgeSlug =>
      $composableBuilder(column: $table.badgeSlug, builder: (column) => column);

  GeneratedColumn<DateTime> get awardedAt =>
      $composableBuilder(column: $table.awardedAt, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$UserBadgesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserBadgesTable,
    UserBadge,
    $$UserBadgesTableFilterComposer,
    $$UserBadgesTableOrderingComposer,
    $$UserBadgesTableAnnotationComposer,
    $$UserBadgesTableCreateCompanionBuilder,
    $$UserBadgesTableUpdateCompanionBuilder,
    (UserBadge, $$UserBadgesTableReferences),
    UserBadge,
    PrefetchHooks Function({bool profileId})> {
  $$UserBadgesTableTableManager(_$AppDatabase db, $UserBadgesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserBadgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserBadgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserBadgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> profileId = const Value.absent(),
            Value<String> badgeSlug = const Value.absent(),
            Value<DateTime> awardedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserBadgesCompanion(
            profileId: profileId,
            badgeSlug: badgeSlug,
            awardedAt: awardedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String profileId,
            required String badgeSlug,
            required DateTime awardedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              UserBadgesCompanion.insert(
            profileId: profileId,
            badgeSlug: badgeSlug,
            awardedAt: awardedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$UserBadgesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$UserBadgesTableReferences._profileIdTable(db),
                    referencedColumn:
                        $$UserBadgesTableReferences._profileIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$UserBadgesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserBadgesTable,
    UserBadge,
    $$UserBadgesTableFilterComposer,
    $$UserBadgesTableOrderingComposer,
    $$UserBadgesTableAnnotationComposer,
    $$UserBadgesTableCreateCompanionBuilder,
    $$UserBadgesTableUpdateCompanionBuilder,
    (UserBadge, $$UserBadgesTableReferences),
    UserBadge,
    PrefetchHooks Function({bool profileId})>;
typedef $$WishlistItemsTableCreateCompanionBuilder = WishlistItemsCompanion
    Function({
  required String profileId,
  required String beerId,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$WishlistItemsTableUpdateCompanionBuilder = WishlistItemsCompanion
    Function({
  Value<String> profileId,
  Value<String> beerId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$WishlistItemsTableReferences
    extends BaseReferences<_$AppDatabase, $WishlistItemsTable, WishlistItem> {
  $$WishlistItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
          $_aliasNameGenerator(db.wishlistItems.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id($_item.profileId));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $BeersTable _beerIdTable(_$AppDatabase db) => db.beers
      .createAlias($_aliasNameGenerator(db.wishlistItems.beerId, db.beers.id));

  $$BeersTableProcessedTableManager get beerId {
    final manager = $$BeersTableTableManager($_db, $_db.beers)
        .filter((f) => f.id($_item.beerId));
    final item = $_typedResult.readTableOrNull(_beerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WishlistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $WishlistItemsTable> {
  $$WishlistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BeersTableFilterComposer get beerId {
    final $$BeersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.beerId,
        referencedTable: $db.beers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BeersTableFilterComposer(
              $db: $db,
              $table: $db.beers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WishlistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $WishlistItemsTable> {
  $$WishlistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BeersTableOrderingComposer get beerId {
    final $$BeersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.beerId,
        referencedTable: $db.beers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BeersTableOrderingComposer(
              $db: $db,
              $table: $db.beers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WishlistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WishlistItemsTable> {
  $$WishlistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BeersTableAnnotationComposer get beerId {
    final $$BeersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.beerId,
        referencedTable: $db.beers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BeersTableAnnotationComposer(
              $db: $db,
              $table: $db.beers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WishlistItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WishlistItemsTable,
    WishlistItem,
    $$WishlistItemsTableFilterComposer,
    $$WishlistItemsTableOrderingComposer,
    $$WishlistItemsTableAnnotationComposer,
    $$WishlistItemsTableCreateCompanionBuilder,
    $$WishlistItemsTableUpdateCompanionBuilder,
    (WishlistItem, $$WishlistItemsTableReferences),
    WishlistItem,
    PrefetchHooks Function({bool profileId, bool beerId})> {
  $$WishlistItemsTableTableManager(_$AppDatabase db, $WishlistItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishlistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishlistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishlistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> profileId = const Value.absent(),
            Value<String> beerId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WishlistItemsCompanion(
            profileId: profileId,
            beerId: beerId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String profileId,
            required String beerId,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WishlistItemsCompanion.insert(
            profileId: profileId,
            beerId: beerId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WishlistItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({profileId = false, beerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$WishlistItemsTableReferences._profileIdTable(db),
                    referencedColumn:
                        $$WishlistItemsTableReferences._profileIdTable(db).id,
                  ) as T;
                }
                if (beerId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.beerId,
                    referencedTable:
                        $$WishlistItemsTableReferences._beerIdTable(db),
                    referencedColumn:
                        $$WishlistItemsTableReferences._beerIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WishlistItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WishlistItemsTable,
    WishlistItem,
    $$WishlistItemsTableFilterComposer,
    $$WishlistItemsTableOrderingComposer,
    $$WishlistItemsTableAnnotationComposer,
    $$WishlistItemsTableCreateCompanionBuilder,
    $$WishlistItemsTableUpdateCompanionBuilder,
    (WishlistItem, $$WishlistItemsTableReferences),
    WishlistItem,
    PrefetchHooks Function({bool profileId, bool beerId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$BreweriesTableTableManager get breweries =>
      $$BreweriesTableTableManager(_db, _db.breweries);
  $$BeersTableTableManager get beers =>
      $$BeersTableTableManager(_db, _db.beers);
  $$VenuesTableTableManager get venues =>
      $$VenuesTableTableManager(_db, _db.venues);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionParticipantsTableTableManager get sessionParticipants =>
      $$SessionParticipantsTableTableManager(_db, _db.sessionParticipants);
  $$CheckinsTableTableManager get checkins =>
      $$CheckinsTableTableManager(_db, _db.checkins);
  $$ToastsTableTableManager get toasts =>
      $$ToastsTableTableManager(_db, _db.toasts);
  $$CommentsTableTableManager get comments =>
      $$CommentsTableTableManager(_db, _db.comments);
  $$UserBadgesTableTableManager get userBadges =>
      $$UserBadgesTableTableManager(_db, _db.userBadges);
  $$WishlistItemsTableTableManager get wishlistItems =>
      $$WishlistItemsTableTableManager(_db, _db.wishlistItems);
}
