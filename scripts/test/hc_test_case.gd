class_name HCTestCase
extends RefCounted
## Base class for the in-repo headless test framework (no external deps).
## Subclasses implement run() and call the check* helpers.

var failures: Array[String] = []
var checks_run := 0

func suite_name() -> String:
    return "unnamed"

func run() -> void:
    push_warning("HCTestCase.run() not overridden for %s" % suite_name())

func check(condition: bool, message: String) -> void:
    checks_run += 1
    if not condition:
        failures.append(message)

func check_eq(got: Variant, expected: Variant, message: String) -> void:
    checks_run += 1
    if got != expected:
        failures.append("%s (got %s, expected %s)" % [message, str(got), str(expected)])

func check_close(got: float, expected: float, tolerance: float, message: String) -> void:
    checks_run += 1
    if absf(got - expected) > tolerance:
        failures.append("%s (got %.6f, expected %.6f +/- %.6f)" % [message, got, expected, tolerance])

func check_le(got: int, bound: int, message: String) -> void:
    checks_run += 1
    if got > bound:
        failures.append("%s (got %d, bound %d)" % [message, got, bound])

func check_true(condition: bool, message: String) -> void:
    check(condition, message)

func check_false(condition: bool, message: String) -> void:
    check(not condition, message)

func report() -> String:
    return "%s: %d checks, %d failures" % [suite_name(), checks_run, failures.size()]
