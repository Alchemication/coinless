// Faint ghosts of arcade heroes, villains, ships and treats beside the top of
// the page: real sprites from 36 classic arcade games (images/ghosts/), shown as
// a tribute (credited in the footer). A game is dealt first, so every game gets
// its turn however many sprites it has, then one of its sprites. One fades in
// at a time, alternating sides, at a random spot, tilt and size in the empty
// space beside the title, lingers, and fades away. Only on wide screens, never
// for visitors who prefer less motion, and paused while the tab is hidden.
// ?ghosts=all shows every sprite; ?ghosts=still holds four at their peak.
;(() => {
  // [game, kind, sprites]. Kinds: 'figure' (a character), 'icon' (a little 80s sprite,
  // drawn smaller), 'portrait' (a 3D-era select-screen face, shown as a round, feathered disc).
  const GAMES = [
    ["Street Fighter II", 'figure', ['sf2-balrog', 'sf2-blanka', 'sf2-chun-li', 'sf2-dhalsim', 'sf2-e-honda', 'sf2-guile', 'sf2-ken', 'sf2-m-bison', 'sf2-ryu', 'sf2-sagat', 'sf2-vega', 'sf2-zangief']],
    ["Golden Axe", 'figure', ['goldenaxe-amazon', 'goldenaxe-ax-battler', 'goldenaxe-chicken-leg', 'goldenaxe-death-adder', 'goldenaxe-gilius-thunderhead', 'goldenaxe-thief']],
    ["Cadillacs and Dinosaurs", 'figure', ['cadillacs-hannah', 'cadillacs-jack', 'cadillacs-mess', 'cadillacs-mustapha']],
    ["Galaga", 'icon', ['galaga-boss', 'galaga-fighter']],
    ["Space Invaders", 'icon', ['space-invaders-crab', 'space-invaders-ufo']],
    ["Ms. Pac-Man", 'icon', ['ms-pac-man', 'ms-pac-man-blinky', 'ms-pac-man-inky']],
    ["Dig Dug", 'icon', ['dig-dug', 'dig-dug-fygar', 'dig-dug-pooka']],
    ["Q*bert", 'icon', ['qbert', 'qbert-coily']],
    ["Frogger", 'icon', ['frogger']],
    ["Joust", 'icon', ['joust-buzzard', 'joust-knight']],
    ["Donkey Kong Jr.", 'icon', ['donkey-kong-jr', 'donkey-kong-jr-mario']],
    ["Galaxian", 'icon', ['galaxian-flagship', 'galaxian-galaxip']],
    ["Centipede", 'icon', ['centipede-mushroom', 'centipede-spider']],
    ["Defender", 'icon', ['defender-lander', 'defender-ship']],
    ["BurgerTime", 'icon', ['burgertime-mr-egg', 'burgertime-mr-hot-dog', 'burgertime-peter-pepper']],
    ["1942", 'icon', ['1942-p38', '1942-zero']],
    ["Xevious", 'icon', ['xevious-andor-genesis', 'xevious-solvalou']],
    ["Robotron: 2084", 'icon', ['robotron-grunt', 'robotron-mommy']],
    ["Kung-Fu Master", 'figure', ['kung-fu-master-thomas']],
    ["Elevator Action", 'figure', ['elevator-action-agent', 'elevator-action-otto']],
    ["Bomb Jack", 'icon', ['bomb-jack']],
    ["Commando", 'figure', ['commando-super-joe']],
    ["Contra", 'figure', ['contra-bill']],
    ["Double Dragon", 'figure', ['double-dragon-abobo', 'double-dragon-billy', 'double-dragon-marian']],
    ["Altered Beast", 'figure', ['altered-beast-centurion', 'altered-beast-werewolf']],
    ["Snow Bros.", 'icon', ['snow-bros-potion']],
    ["Mortal Kombat", 'figure', ['mortal-kombat-scorpion']],
    ["Darkstalkers", 'figure', ['darkstalkers-morrigan', 'darkstalkers-rikuo', 'darkstalkers-victor']],
    ["Bubble Bobble", 'icon', ['bubble-bobble-bob', 'bubble-bobble-bub', 'bubble-bobble-cherries', 'bubble-bobble-watermelon', 'bubble-bobble-zen-chan']],
    ["Rampage", 'figure', ['rampage-george', 'rampage-lizzie', 'rampage-ralph']],
    ["Samurai Shodown", 'figure', ['samurai-shodown-haohmaru', 'samurai-shodown-nakoruru']],
    ["R-Type", 'icon', ['r-type-r9']],
    ["Ghosts 'n Goblins", 'figure', ['ghosts-n-goblins-arthur', 'ghosts-n-goblins-princess', 'ghosts-n-goblins-red-arremer']],
    ["Gradius", 'icon', ['gradius-moai', 'gradius-vic-viper']],
    ["Rygar", 'figure', ['rygar', 'rygar-power-up']],
    ["Virtua Fighter 2", 'portrait', ['vf2-shun-di', 'vf2-akira-yuki', 'vf2-pai-chan', 'vf2-kage-maru', 'vf2-wolf-hawkfield', 'vf2-dural']],
  ]

  const stage = document.querySelector('.ghosts')
  if (!stage) return
  const image = (name) => {
    const img = new Image()
    img.src = `images/ghosts/${name}.png`
    img.alt = ''
    return img
  }

  const mode = new URLSearchParams(location.search).get('ghosts')
  if (mode === 'all') {
    stage.classList.add('sheet')
    GAMES.forEach(([, , sprites]) => sprites.forEach((name) => stage.append(image(name))))
    return
  }
  const still = mode === 'still'
  if (!still && matchMedia('(prefers-reduced-motion: reduce)').matches) return

  const wide = matchMedia('(min-width: 1080px)')
  const random = (low, high) => low + Math.random() * (high - low)
  const shuffle = (list) => list.map((item) => [Math.random(), item]).sort((a, b) => a[0] - b[0]).map(([, item]) => item)
  let deck = []
  let side = Math.random() < 0.5 ? 'left' : 'right'

  // Every game once, in a fresh order, before any comes round again.
  const next = () => {
    if (!deck.length) deck = shuffle(GAMES)
    const [, kind, sprites] = deck.pop()
    return { kind, name: sprites[Math.floor(Math.random() * sprites.length)] }
  }

  const spawn = () => {
    if (document.hidden || !wide.matches) return
    const { kind, name } = next()
    side = side === 'left' ? 'right' : 'left'
    const ghost = document.createElement('div')
    ghost.className = `ghost ${kind}`
    ghost.append(image(name))
    const height = { icon: random(48, 92), figure: random(120, 200), portrait: random(96, 140) }[kind]
    // The empty gutter beside the centred title, kept clear of the words.
    const gutter = Math.max(0, (innerWidth - 760) / 2)
    const x = random(gutter * 0.06, Math.max(gutter * 0.06, gutter - height * 0.9 - 30))
    // Keep clear of any ghost still fading on the same side.
    const taken = [...stage.querySelectorAll(`.ghost[data-side="${side}"]`)].map((other) => parseFloat(other.style.top))
    let top = random(4, 62)
    for (let tries = 0; tries < 12 && taken.some((other) => Math.abs(other - top) < 30); tries++) top = random(4, 62)
    ghost.dataset.side = side
    ghost.style.cssText = `height:${height}px; top:${top}%; ${side}:${x}px;` +
      `--turn:${random(-12, 12)}deg; --flip:${Math.random() < 0.5 ? 1 : -1}; --peak:${random(0.09, 0.17)};`
    if (still) ghost.classList.add('still')
    stage.append(ghost)
    ghost.addEventListener('animationend', () => ghost.remove())
  }

  if (still) { for (let i = 0; i < 4; i++) spawn(); return }
  setTimeout(spawn, 900)
  setInterval(spawn, 3600)
})()
