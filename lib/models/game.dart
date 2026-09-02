/// A game in the catalog, managed via the Setting/*_game endpoints. Stored
/// centrally on gameon (like Tukar Point); the image file itself lives on
/// billing_api. Deletion is a soft delete (ms_game_active = 'N').
class Game {
  final int id;
  final String name;

  /// Branches this game is available at (multi). See [gameBranchNames].
  final List<int> branchIds;

  /// Consoles this game runs on (multi). See [gameConsoleOptions].
  final List<String> consoles;

  /// category_meja ids this game is available in ("Tersedia di ruangan").
  final List<int> roomIds;

  /// Human-readable names for [roomIds], resolved server-side.
  final List<String> roomNames;

  final String description;
  final String imageUrl;

  const Game({
    required this.id,
    required this.name,
    required this.branchIds,
    required this.consoles,
    required this.roomIds,
    required this.roomNames,
    required this.description,
    required this.imageUrl,
  });

  /// Branch labels for display, e.g. "Danau Sentarum, P.Aim".
  List<String> get branchNames => branchIds
      .map((b) => gameBranchNames[b] ?? "Cabang $b")
      .toList();

  factory Game.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? "") ?? 0;

    List<int> asIntList(dynamic v) {
      if (v is List) {
        return v.map((e) => int.tryParse(e.toString())).whereType<int>().toList();
      }
      return const [];
    }

    List<String> asStringList(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    return Game(
      id: asInt(json['id']),
      name: json['name']?.toString() ?? "",
      branchIds: asIntList(json['branch_ids']),
      consoles: asStringList(json['consoles']),
      roomIds: asIntList(json['room_ids']),
      roomNames: asStringList(json['room_names']),
      description: json['desc']?.toString() ?? "",
      imageUrl: json['image_url']?.toString() ?? "",
    );
  }
}

/// Branches games can be assigned to. Keep in sync with the backend's
/// `_branchNames` (Danau Sentarum = 1, P.Aim = 2).
const Map<int, String> gameBranchNames = {1: "Danau Sentarum", 2: "P.Aim"};

/// Console options offered in the game form.
const List<String> gameConsoleOptions = [
  "PS3",
  "PS4",
  "PS5",
  "Nintendo Switch",
  "PC",
];
