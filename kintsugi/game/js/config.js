// Screen, tile and physics constants shared by every module.
export const W = 480, H = 270, T = 16;
export const STEP = 1 / 120;          // fixed physics step

// Palette taken from the character (see docs/character-design-guide.md §4),
// plus the mint/teal slash colours seen in the pack's reference GIFs.
export const P = {
  navy: '#1C154D', navyD: '#151037', navyDD: '#0F121B', royal: '#0321BC',
  lilac: '#B2B2FF', lilacD: '#9EA0FA', plum: '#40225F', plumD: '#2F1850',
  gold: '#FFA303', goldHi: '#FFFFCC', goldD: '#E05E2B', rust: '#A64B0A',
  red: '#FF0E00', crimson: '#882323', crimsonD: '#580303', wood: '#4D2F1E',
  white: '#FFFFFF', ice: '#97C0FF', mint: '#7FF5C8', teal: '#2AA58A', jade: '#6CF2C2', orange: '#FFB347',
};

// Player physics. Speeds in px/s, times in seconds.
export const K = {
  WALK: 120, RUN: 195, CRAWL: 55,
  ACC: 1100, AIR_ACC: 760, FRICTION: 1400,
  GRAV: 1500, JUMP_V: 455, DJUMP_V: 410, MAX_FALL: 520,
  WALL_SLIDE: 70, WJ_VX: 175, WJ_VY: 440,
  CLIMB: 85,
  DASH_V: 340, DASH_T: .18,
  ROLL_V: 235, ROLL_T: .34,
  SLIDE_V: 280, SLIDE_T: .42,
  PW: 14, PH: 40, PH_LOW: 22,          // hitbox: width, standing height, crouched height
  HP: 3, INV: 1.1,
};
