extends HCTestCase

func suite_name() -> String:
    return "geometry"

func run() -> void:
    var r := MatchRules.create_default()
    var geo := BoardGeometry.new(r)
    for p in 4:
        check_eq(geo.start_index(p), p * 13, "start index p%d" % p)
        for prog in [0, 1, 7, 13, 30, 49]:
            check_eq(geo.step_along(p, prog), (13 * p + prog) % 52, "step_along p%d %d" % [p, prog])
    check(geo.is_safe(0) and geo.is_safe(7), "arm0 safe squares")
    check(geo.is_safe(13) and geo.is_safe(20), "arm1 safe squares")
    check(geo.is_safe(26) and geo.is_safe(33), "arm2 safe squares")
    check(geo.is_safe(39) and geo.is_safe(46), "arm3 safe squares")
    check(not geo.is_safe(1), "1 not safe")
    check(not geo.is_safe(4), "4 not safe (portal)")
    check(not geo.is_safe(30), "30 not safe (lantern)")
    check(not geo.is_safe(47), "47 not safe (candy)")
    check_eq(String(geo.special_at(4)), "portal", "portal at 4")
    check_eq(String(geo.special_at(30)), "lantern", "lantern at 30")
    check_eq(String(geo.special_at(47)), "", "candy off by default")
    check_eq(String(geo.special_at(0)), "", "start not special")
    var classic := MatchRules.create_classic()
    var g2 := BoardGeometry.new(classic)
    check_eq(String(g2.special_at(4)), "", "classic: no portal")
    check_eq(String(g2.special_at(30)), "", "classic: no lantern")

    # ---- layout invariants -------------------------------------------------
    var lay := BoardLayout.new(r)
    var pts := lay.all_ring()
    check_eq(pts.size(), 52, "52 ring points")
    var step := lay.ring_step_distance()
    for i in 52:
        var d := pts[i].distance_to(pts[(i + 1) % 52])
        # corner crossings are chords (~0.707*step); straight edges are exact
        check(d > step * 0.7 and d <= step + 0.02, "spacing bound at %d (%.3f)" % [i, d])
    var straight := 0
    for i in 52:
        var d2 := pts[i].distance_to(pts[(i + 1) % 52])
        if absf(d2 - step) <= 0.02:
            straight += 1
    check_eq(straight, 48, "48 straight spacings (4 corners are chords)")
    var min_d := 1e9
    for i in 52:
        for j in range(i + 1, 52):
            var d := pts[i].distance_to(pts[j])
            if d < min_d:
                min_d = d
    check(min_d > 30.0, "ring points never overlap (min %.1f)" % min_d)
    check(pts[0].y > BoardLayout.BOARD_CENTER.y, "arm 0 starts on the bottom edge")
    check(pts[13].x < BoardLayout.BOARD_CENTER.x, "arm 1 on the left edge")
    check(pts[26].y < BoardLayout.BOARD_CENTER.y, "arm 2 on the top edge")
    check(pts[39].x > BoardLayout.BOARD_CENTER.x, "arm 3 on the right edge")
    for p in 4:
        var e := r.home_entry_index(p)
        var s := r.start_index(p)
        check_eq((e + 2) % 52, s, "entry is 2 ring steps before start p%d" % p)
        var de := lay.ring_position(e).distance_to(lay.ring_position(s))
        check(de <= 2.0 * step + 0.05, "entry-start euclidean bound p%d (%.1f)" % [p, de])
    for p in 4:
        var entry_pt := lay.ring_position(r.home_entry_index(p))
        var d0 := entry_pt.distance_to(BoardLayout.BOARD_CENTER)
        for i in r.column_length:
            var c := lay.column_position(p, i)
            check(c.distance_to(BoardLayout.BOARD_CENTER) < d0 - 1.0, "column approaches center p%d i%d" % [p, i])
    for p in 4:
        var g := lay.goal_position(p)
        check(g.distance_to(BoardLayout.BOARD_CENTER) < 420.0, "goal near center p%d (%.0f)" % [p, g.distance_to(BoardLayout.BOARD_CENTER)])
        check(lay.in_design_bounds(g, 8.0), "goal in bounds p%d" % p)
        for s in r.pieces_per_player:
            check(lay.in_design_bounds(lay.pen_position(p, s), 8.0), "pen slot in bounds p%d %d" % [p, s])
            check(lay.pen_position(p, s).distance_to(BoardLayout.BOARD_CENTER) > BoardLayout.RING_HALF, "pen outside ring p%d %d" % [p, s])
    for p in 4:
        for q in range(p + 1, 4):
            check(lay.goal_position(p).distance_to(lay.goal_position(q)) > 40.0, "goals distinct p%d p%d" % [p, q])
    var seen := {}
    for p in 4:
        for s in r.pieces_per_player:
            var pp := lay.pen_position(p, s)
            var key := "%d,%d" % [int(pp.x), int(pp.y)]
            check(not seen.has(key), "pen slot unique %s" % key)
            seen[key] = true

    # ---- position_for mapping ---------------------------------------------
    var m := MatchFactory.make(r, 2)
    MatchFactory.place(m, 0, 0, -1)
    MatchFactory.place(m, 0, 1, 0)
    MatchFactory.place(m, 0, 2, 50)   # home column index 0
    MatchFactory.place(m, 0, 3, 56)
    check_eq(m.state.players[0].pieces[0].loc(), Move.LOC_PEN, "pen loc")
    check_eq(m.state.players[0].pieces[1].loc(), Move.LOC_RING, "ring loc")
    check_eq(m.state.players[0].pieces[2].loc(), Move.LOC_COLUMN, "column loc")
    check_eq(m.state.players[0].pieces[3].loc(), Move.LOC_GOAL, "goal loc")
    check_eq(m.state.players[0].pieces[1].ring_index(), 0, "ring index at start")
    check_eq(m.state.players[0].pieces[2].column_index(), 0, "column index")
    check_close(lay.position_for(m.state.players[0].pieces[1]).distance_to(lay.ring_position(0)), 0.0, 0.001, "position_for ring matches")
    check_close(lay.position_for(m.state.players[0].pieces[2]).distance_to(lay.column_position(0, 0)), 0.0, 0.001, "position_for column matches")
    check_close(lay.position_for(m.state.players[0].pieces[3]).distance_to(lay.goal_position(0)), 0.0, 0.001, "position_for goal matches")
