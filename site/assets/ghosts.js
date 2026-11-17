// Faint ghosts of arcade heroes beside the top of the page: the real stance
// sprites from Street Fighter II and Golden Axe (images/ghosts/), shown as a
// tribute (credited in the footer). One fades in at a time, alternating sides,
// at a random spot, tilt and size in the empty space beside the title, lingers,
// and fades away. Only on wide screens, never for visitors who prefer less
// motion, and paused while the tab is hidden. ?ghosts=all shows them all;
// ?ghosts=still holds four at their peak, for checking the composition.
;(() => {
  // Street Fighter II sprites face right; Golden Axe ones vary, so they turn at random.
  const SPRITES = [
    'sf2-ryu', 'sf2-ken', 'sf2-chun-li', 'sf2-guile', 'sf2-blanka', 'sf2-zangief',
    'sf2-dhalsim', 'sf2-e-honda', 'sf2-balrog', 'sf2-vega', 'sf2-sagat', 'sf2-m-bison',
    'goldenaxe-ax-battler', 'goldenaxe-amazon', 'goldenaxe-gilius-thunderhead', 'goldenaxe-death-adder',
  ]
  const facesRight = (name) => name.startsWith('sf2-')

  const stage = document.querySelector('.ghosts')
  if (!stage) return
  const image = (name) => {
    const img = new Image()
    img.src = `images/ghosts/${name}.png`
    img.alt = ''
    return img
  }

  if (new URLSearchParams(location.search).get('ghosts') === 'all') {
    stage.classList.add('sheet')
    SPRITES.forEach((name) => stage.append(image(name)))
    return
  }
  const still = new URLSearchParams(location.search).get('ghosts') === 'still'
  if (!still && matchMedia('(prefers-reduced-motion: reduce)').matches) return

  const wide = matchMedia('(min-width: 1080px)')
  const random = (low, high) => low + Math.random() * (high - low)
  let deck = []
  let side = Math.random() < 0.5 ? 'left' : 'right'

  // Deal every hero once before any repeats.
  const next = () => {
    if (!deck.length) deck = [...SPRITES].sort(() => Math.random() - 0.5)
    return deck.pop()
  }

  const spawn = () => {
    if (document.hidden || !wide.matches) return
    const name = next()
    side = side === 'left' ? 'right' : 'left'
    const ghost = document.createElement('div')
    ghost.className = 'ghost'
    ghost.append(image(name))
    const height = random(120, 210)
    // The empty gutter beside the centred title, kept clear of the words.
    const gutter = Math.max(0, (innerWidth - 760) / 2)
    const x = random(gutter * 0.06, Math.max(gutter * 0.06, gutter - height * 0.8 - 30))
    // Face the middle of the page.
    const toward = side === 'left' ? 1 : -1
    const flip = facesRight(name) ? toward : (Math.random() < 0.5 ? 1 : -1)
    // Keep clear of any ghost still fading on the same side.
    const taken = [...stage.querySelectorAll(`.ghost[data-side="${side}"]`)].map((other) => parseFloat(other.style.top))
    let top = random(4, 58)
    for (let tries = 0; tries < 12 && taken.some((other) => Math.abs(other - top) < 30); tries++) top = random(4, 58)
    ghost.dataset.side = side
    ghost.style.cssText = `height:${height}px; top:${top}%; ${side}:${x}px;` +
      `--turn:${random(-12, 12)}deg; --flip:${flip}; --peak:${random(0.09, 0.17)};`
    if (still) ghost.classList.add('still')
    stage.append(ghost)
    ghost.addEventListener('animationend', () => ghost.remove())
  }

  if (still) { for (let i = 0; i < 4; i++) spawn(); return }
  setTimeout(spawn, 900)
  setInterval(spawn, 3600)
})()
