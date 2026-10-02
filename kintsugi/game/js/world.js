// Mutable game state shared between modules.
export const world = {
  pl: null,
  enemies: [], shards: [], checkpoints: [], movers: [],
  respawn: { x: 0, y: 0 },
  cam: { x: 0, y: 0 },
  time: 0, deaths: 0,
  running: false, won: false,
  hitstop: 0, shake: 0,
};
