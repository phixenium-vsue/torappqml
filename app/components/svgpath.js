.pragma library

var PI = Math.PI

function tokenize(d) {
    var re = /([MmLlHhVvCcSsQqTtAaZz])|(-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)/g
    var out = [], m
    while ((m = re.exec(d)) !== null)
        out.push(m[1] ? m[1] : parseFloat(m[2]))
    return out
}

function angle(ux, uy, vx, vy) {
    var dot = ux * vx + uy * vy
    var len = Math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
    var a = Math.acos(Math.min(1, Math.max(-1, dot / len)))
    if (ux * vy - uy * vx < 0) a = -a
    return a
}

function arcTo(ctx, x1, y1, rx, ry, rotDeg, largeArc, sweep, x2, y2) {
    if (x1 === x2 && y1 === y2) return
    rx = Math.abs(rx); ry = Math.abs(ry)
    if (rx === 0 || ry === 0) { ctx.lineTo(x2, y2); return }
    var phi = rotDeg * PI / 180
    var cos = Math.cos(phi), sin = Math.sin(phi)
    var dx2 = (x1 - x2) / 2, dy2 = (y1 - y2) / 2
    var x1p = cos * dx2 + sin * dy2
    var y1p = -sin * dx2 + cos * dy2
    var lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if (lam > 1) { var sc = Math.sqrt(lam); rx *= sc; ry *= sc }
    var sign = (largeArc !== sweep) ? 1 : -1
    var num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    var den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    var co = sign * Math.sqrt(Math.max(0, num / den))
    var cxp = co * rx * y1p / ry
    var cyp = -co * ry * x1p / rx
    var cx = cos * cxp - sin * cyp + (x1 + x2) / 2
    var cy = sin * cxp + cos * cyp + (y1 + y2) / 2
    var ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry
    var vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry
    var th1 = angle(1, 0, ux, uy)
    var dth = angle(ux, uy, vx, vy)
    if (!sweep && dth > 0) dth -= 2 * PI
    if (sweep && dth < 0) dth += 2 * PI

    var segs = Math.ceil(Math.abs(dth) / (PI / 2)) || 1
    var delta = dth / segs
    var k = 4 / 3 * Math.tan(delta / 4)
    var px = x1, py = y1

    for (var s = 0; s < segs; s++) {
        var th2 = th1 + delta
        var c1 = Math.cos(th1), s1 = Math.sin(th1)
        var c2 = Math.cos(th2), s2 = Math.sin(th2)
        var p2x = cx + cos * rx * c2 - sin * ry * s2
        var p2y = cy + sin * rx * c2 + cos * ry * s2
        var d1x = -cos * rx * s1 - sin * ry * c1
        var d1y = -sin * rx * s1 + cos * ry * c1
        var d2x = -cos * rx * s2 - sin * ry * c2
        var d2y = -sin * rx * s2 + cos * ry * c2
        ctx.bezierCurveTo(px + k * d1x, py + k * d1y,
                          p2x - k * d2x, p2y - k * d2y, p2x, p2y)
        px = p2x; py = p2y; th1 = th2
    }
}

function drawPath(ctx, d) {
    if (!d) return
    var t = tokenize(d)
    var i = 0, cmd = null
    var x = 0, y = 0, sx = 0, sy = 0
    var pcx = 0, pcy = 0, pc = ''
    function n() { return t[i++] }

    while (i < t.length) {
        if (typeof t[i] === 'string') { cmd = t[i]; i++ }
        var up = cmd.toUpperCase()
        var rel = (cmd !== up)

        if (up === 'M') {
            x = n() + (rel ? x : 0); y = n() + (rel ? y : 0)
            sx = x; sy = y; ctx.moveTo(x, y); pc = 'M'
            cmd = rel ? 'l' : 'L'
        } else if (up === 'L') {
            x = n() + (rel ? x : 0); y = n() + (rel ? y : 0)
            ctx.lineTo(x, y); pc = 'L'
        } else if (up === 'H') {
            x = n() + (rel ? x : 0); ctx.lineTo(x, y); pc = 'H'
        } else if (up === 'V') {
            y = n() + (rel ? y : 0); ctx.lineTo(x, y); pc = 'V'
        } else if (up === 'C') {
            var c1x = n() + (rel ? x : 0), c1y = n() + (rel ? y : 0)
            var c2x = n() + (rel ? x : 0), c2y = n() + (rel ? y : 0)
            x = n() + (rel ? x : 0); y = n() + (rel ? y : 0)
            ctx.bezierCurveTo(c1x, c1y, c2x, c2y, x, y)
            pcx = c2x; pcy = c2y; pc = 'C'
        } else if (up === 'S') {
            var s2x = n() + (rel ? x : 0), s2y = n() + (rel ? y : 0)
            var ex = n() + (rel ? x : 0), ey = n() + (rel ? y : 0)
            var sc1x = (pc === 'C' || pc === 'S') ? 2 * x - pcx : x
            var sc1y = (pc === 'C' || pc === 'S') ? 2 * y - pcy : y
            ctx.bezierCurveTo(sc1x, sc1y, s2x, s2y, ex, ey)
            pcx = s2x; pcy = s2y; x = ex; y = ey; pc = 'S'
        } else if (up === 'Q') {
            var qx = n() + (rel ? x : 0), qy = n() + (rel ? y : 0)
            x = n() + (rel ? x : 0); y = n() + (rel ? y : 0)
            ctx.quadraticCurveTo(qx, qy, x, y)
            pcx = qx; pcy = qy; pc = 'Q'
        } else if (up === 'T') {
            var tex = n() + (rel ? x : 0), tey = n() + (rel ? y : 0)
            var tqx = (pc === 'Q' || pc === 'T') ? 2 * x - pcx : x
            var tqy = (pc === 'Q' || pc === 'T') ? 2 * y - pcy : y
            ctx.quadraticCurveTo(tqx, tqy, tex, tey)
            pcx = tqx; pcy = tqy; x = tex; y = tey; pc = 'T'
        } else if (up === 'A') {
            var arx = n(), ary = n(), arot = n()
            var laf = n(), swf = n()
            var aex = n() + (rel ? x : 0)
            var aey = n() + (rel ? y : 0)
            arcTo(ctx, x, y, arx, ary, arot, laf, swf, aex, aey)
            x = aex; y = aey; pc = 'A'
        } else if (up === 'Z') {
            ctx.closePath(); x = sx; y = sy; pc = 'Z'
        } else {
            i++
        }
    }
}
