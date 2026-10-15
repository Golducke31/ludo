extends HCTestCase

func suite_name() -> String:
    return "smoke"

func run() -> void:
    check(true, "sanity check passes")
    check_eq(1 + 1, 2, "integer arithmetic")
    check_close(0.5, 0.5, 0.0001, "float compare")
    check_eq(str("HCT"), "HCT", "string identity")
    check_false(false, "boolean negation")
    # Autoloads are alive in the test run too.
    check(EventBus != null, "EventBus autoload present")
    check(Settings != null, "Settings autoload present")
    check(Save != null, "Save autoload present")
    check(Stats != null, "Stats autoload present")
    check(Audio != null, "Audio autoload present")
