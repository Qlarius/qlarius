// Liquid glass bottom nav — archisvaze-style SVG backdrop filter (Chromium only).

const SURFACE_FNS = {
  convex_squircle: (x) => Math.pow(1 - Math.pow(1 - x, 4), 0.25),
}

function calculateRefractionProfile(glassThickness, bezelWidth, heightFn, ior, samples = 128) {
  const eta = 1 / ior
  const profile = new Float64Array(samples)

  for (let i = 0; i < samples; i++) {
    const x = i / samples
    const y = heightFn(x)
    const dx = x < 1 ? 0.0001 : -0.0001
    const y2 = heightFn(x + dx)
    const deriv = (y2 - y) / dx
    const mag = Math.sqrt(deriv * deriv + 1)
    const nx = -deriv / mag
    const ny = -1 / mag
    const dot = ny
    const k = 1 - eta * eta * (1 - dot * dot)

    if (k < 0) {
      profile[i] = 0
      continue
    }

    const sq = Math.sqrt(k)
    const rx = -(eta * dot + sq) * nx
    const ry = eta - (eta * dot + sq) * ny
    profile[i] = rx * ((y * bezelWidth + glassThickness) / ry)
  }

  return profile
}

/** Signed distance to pill outline (negative = inside). Matches border-radius: 9999px track. */
function sdfRoundedRect(px, py, w, h, radius) {
  const r = Math.min(radius, w / 2, h / 2)
  const cx = px - w / 2
  const cy = py - h / 2
  const hx = w / 2 - r
  const hy = h / 2 - r
  const qx = Math.abs(cx) - hx
  const qy = Math.abs(cy) - hy
  const ax = Math.max(qx, 0)
  const ay = Math.max(qy, 0)
  const outside = Math.hypot(ax, ay) - r
  const inside = Math.min(Math.max(qx, qy), 0)
  return outside + inside
}

function sdfGradient(px, py, w, h, radius) {
  const r = Math.min(radius, w / 2, h / 2)
  const eps = Math.max(0.35, Math.min(w, h) * 0.025)
  const d0 = sdfRoundedRect(px, py, w, h, r)
  const gx =
    (sdfRoundedRect(px + eps, py, w, h, r) - d0) / eps
  const gy =
    (sdfRoundedRect(px, py + eps, w, h, r) - d0) / eps
  const len = Math.hypot(gx, gy) || 1
  return { nx: gx / len, ny: gy / len }
}

/** Inward normal + depth from pill SDF (smooth around caps and flats — no piecewise seams). */
function pillDepthNormal(px, py, w, h, r, bezelWidth) {
  const sdf = sdfRoundedRect(px, py, w, h, r)
  if (sdf >= 0) return null

  const depth = -sdf
  if (depth > bezelWidth) return null

  const { nx: gx, ny: gy } = sdfGradient(px, py, w, h, r)
  return { depth, inx: -gx, iny: -gy }
}

function generateDisplacementMap(w, h, radius, bezelWidth, profile, maxDisp) {
  const canvas = document.createElement("canvas")
  canvas.width = w
  canvas.height = h
  const ctx = canvas.getContext("2d")
  const img = ctx.createImageData(w, h)
  const d = img.data
  const S = profile.length
  const r = Math.min(radius, w / 2, h / 2)

  for (let i = 0; i < d.length; i += 4) {
    d[i] = 128
    d[i + 1] = 128
    d[i + 2] = 0
    d[i + 3] = 255
  }

  for (let y1 = 0; y1 < h; y1++) {
    for (let x1 = 0; x1 < w; x1++) {
      const px = x1 + 0.5
      const py = y1 + 0.5
      const sdf = sdfRoundedRect(px, py, w, h, r)
      if (sdf >= 0) continue

      const hit = pillDepthNormal(px, py, w, h, r, bezelWidth)

      if (!hit || hit.depth > bezelWidth) continue

      const t = hit.depth / bezelWidth
      const bi = Math.min((t * S) | 0, S - 1)
      const disp = profile[bi] || 0
      if (disp === 0) continue

      const edgeFade = Math.min(1, hit.depth / 1.5)
      const rimFade = 1 - t * 0.15
      const op = edgeFade * rimFade

      const dX = (hit.inx * disp) / maxDisp
      const dY = (hit.iny * disp) / maxDisp
      const idx = (y1 * w + x1) * 4

      d[idx] = (128 + dX * 127 * op + 0.5) | 0
      d[idx + 1] = (128 + dY * 127 * op + 0.5) | 0
    }
  }

  ctx.putImageData(img, 0, 0)
  return canvas.toDataURL()
}

export function canUseSvgBackdropFilter() {
  if (!window.CSS?.supports) return false
  if (!CSS.supports("backdrop-filter", "blur(4px)")) return false
  if (!CSS.supports("backdrop-filter", "url(#qlarius-svg-backdrop-supports-test)")) {
    return false
  }

  const ua = navigator.userAgent
  if (/iPhone|iPod/i.test(ua)) return false
  if (/iPad/i.test(ua) && /Safari/i.test(ua) && !/CriOS|Chrome|Edg/i.test(ua)) return false
  if (/Safari/i.test(ua) && !/Chrome|Chromium|Edg|OPR|CriOS/i.test(ua)) return false
  if (/Firefox|FxiOS/i.test(ua)) return false

  return /Chrome|Chromium|Edg|OPR|Brave|CriOS/i.test(ua)
}

export function buildMobileBottomNavGlassFilter(defsRoot, width, height) {
  if (!defsRoot || width < 8 || height < 8) return

  const radius = height / 2
  const bezelWidth = Math.min(26, radius - 2, Math.min(width, height) / 2 - 2)
  const glassThickness = 72
  const ior = 2.4
  const blurAmount = 2.65
  const scaleRatio = 0.88
  const heightFn = SURFACE_FNS.convex_squircle

  const profile = calculateRefractionProfile(
    glassThickness,
    bezelWidth,
    heightFn,
    ior,
    128
  )
  const maxDisp = Math.max(...Array.from(profile).map(Math.abs), 1) || 1
  const dispUrl = generateDisplacementMap(
    width,
    height,
    radius,
    bezelWidth,
    profile,
    maxDisp
  )
  const scale = Math.max(12, maxDisp * scaleRatio)
  const svgNS = "http://www.w3.org/2000/svg"
  const xlinkNS = "http://www.w3.org/1999/xlink"

  defsRoot.replaceChildren()

  const filter = document.createElementNS(svgNS, "filter")
  filter.setAttribute("id", "qlarius-mobile-bottom-nav-glass")
  filter.setAttribute("x", "0%")
  filter.setAttribute("y", "0%")
  filter.setAttribute("width", "100%")
  filter.setAttribute("height", "100%")
  filter.setAttribute("color-interpolation-filters", "sRGB")

  const blur = document.createElementNS(svgNS, "feGaussianBlur")
  blur.setAttribute("in", "SourceGraphic")
  blur.setAttribute("stdDeviation", String(blurAmount))
  blur.setAttribute("result", "blurred_source")

  const image = document.createElementNS(svgNS, "feImage")
  image.setAttribute("href", dispUrl)
  image.setAttributeNS(xlinkNS, "href", dispUrl)
  image.setAttribute("x", "0")
  image.setAttribute("y", "0")
  image.setAttribute("width", String(width))
  image.setAttribute("height", String(height))
  image.setAttribute("preserveAspectRatio", "none")
  image.setAttribute("result", "disp_map")

  const displace = document.createElementNS(svgNS, "feDisplacementMap")
  displace.setAttribute("in", "blurred_source")
  displace.setAttribute("in2", "disp_map")
  displace.setAttribute("scale", String(scale))
  displace.setAttribute("xChannelSelector", "R")
  displace.setAttribute("yChannelSelector", "G")
  displace.setAttribute("result", "displaced")

  const saturate = document.createElementNS(svgNS, "feColorMatrix")
  saturate.setAttribute("in", "displaced")
  saturate.setAttribute("type", "saturate")
  saturate.setAttribute("values", "1.62")

  filter.append(blur, image, displace, saturate)
  defsRoot.append(filter)
}

export function MobileBottomNavGlassHook() {
  return {
    mounted() {
      this._timer = null
      this.defsRoot = document.getElementById("qlarius-mobile-bottom-nav-filter-defs")
      this.glassEl = this.el.querySelector(".mobile-bottom-nav__glass-backdrop")
      this.enabled = canUseSvgBackdropFilter()

      if (this.enabled) {
        document.documentElement.dataset.liquidGlassBackdrop = "true"
      }

      this._rebuild = () => {
        const w = Math.round(this.el.offsetWidth)
        const h = Math.round(this.el.offsetHeight)
        buildMobileBottomNavGlassFilter(this.defsRoot, w, h)
      }

      this._scheduleRebuild = () => {
        clearTimeout(this._timer)
        this._timer = setTimeout(this._rebuild, 40)
      }

      this._resizeObserver = new ResizeObserver(() => this._scheduleRebuild())
      this._resizeObserver.observe(this.el)
      if (this.glassEl && this.glassEl !== this.el) {
        this._resizeObserver.observe(this.glassEl)
      }

      requestAnimationFrame(() => requestAnimationFrame(this._rebuild))
    },

    updated() {
      this.glassEl = this.el.querySelector(".mobile-bottom-nav__glass-backdrop")
      this._scheduleRebuild?.()
    },

    destroyed() {
      clearTimeout(this._timer)
      this._resizeObserver?.disconnect()

      if (document.documentElement.dataset.liquidGlassBackdrop === "true") {
        delete document.documentElement.dataset.liquidGlassBackdrop
      }
    },
  }
}
