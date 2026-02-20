extends Node

func buy_upgrade(upgrade_id: int) -> bool:
    var upgrade = DataManager.upgrades_db.get(upgrade_id)
    if upgrade == null:
        return false

    if upgrade_id in File.data["player"]["upgrades_owned"]:
        return false

    if File.data["player"]["coins"] < upgrade["cost"]:
        return false

    File.data["player"]["coins"] -= upgrade["cost"]
    File.data["player"]["upgrades_owned"].append(upgrade_id)

    apply_upgrades()

    File.save_game()
    FirebaseManager.upload_save()

    return true


func apply_upgrades() -> void:
    var base_stats = File.data["player"]["base_stats"]
    var current_stats = File.data["player"]["current_stats"]

    current_stats.clear()
    for key in base_stats.keys():
        current_stats[key] = base_stats[key]

    for id in File.data["player"]["upgrades_owned"]:
        var upgrade = DataManager.upgrades_db.get(id)
        if upgrade == null:
            continue

        for effect_key in upgrade["effect"].keys():
            if not current_stats.has(effect_key):
                current_stats[effect_key] = 0

            current_stats[effect_key] += upgrade["effect"][effect_key]
