/// Android flavor version: upstream major.minor.patch plus our revision.
class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.parts);

  final List<int> parts;

  static ReleaseVersion? parse(String value, {bool allowLegacy = false}) {
    final match = RegExp(
      allowLegacy
          ? r'^v?(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?(?:-[0-9a-f]{9,40}(?:-dirty)?)?(?:\+\d+)?$'
          : r'^v?(\d+)\.(\d+)\.(\d+)\.(\d+)$',
    ).firstMatch(value);
    if (match == null) return null;
    return ReleaseVersion([
      for (var i = 1; i <= 3; i++) int.parse(match.group(i)!),
      // The first flavor release supersedes old three-part local builds.
      match.group(4) == null ? -1 : int.parse(match.group(4)!),
    ]);
  }

  @override
  int compareTo(ReleaseVersion other) {
    for (var i = 0; i < 4; i++) {
      final result = parts[i].compareTo(other.parts[i]);
      if (result != 0) return result;
    }
    return 0;
  }
}
