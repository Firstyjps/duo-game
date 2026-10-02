// Level 1: Kintsugi moonlit field — teaches every move once, in order.
// Coordinates are tiles: [col, row] puts feet on top of row `row`; shards are centred in their tile.
export default {
  name: 'ทุ่งจันทร์คินสึงิ (Kintsugi Field)',
  cols: 140,
  rows: 17,
  start: [3, 14],
  goal: [131, 14],

  checkpoints: [[3, 14], [49, 14], [71, 14], [91, 12], [106, 14], [121, 14]],
  shards: [[7, 12], [10, 11], [17, 13], [25, 10], [36, 9], [43, 9], [55, 6], [63, 9], [77, 7],
    [84, 7], [93, 8], [111, 4], [113, 4], [125, 2]],
  enemies: [[6, 11, 14], [23, 28, 12], [37, 40, 13], [95, 97, 12], [110, 111, 14], [116, 120, 14]],
  movers: [
    { x0: 58, x1: 66, y: 11, w: 3, speed: 42 },
    { x0: 79, x1: 86, y: 10, w: 3, speed: 50 },
  ],
  signs: [
    { col: 4, text: 'X ฟัน · X X X คอมโบ 3 จังหวะ · X X แล้ว ↑+X X X คอมโบ 5 จังหวะ' },
    { col: 13, text: '↓ หมอบลอดใต้เพดาน · กด Shift วิ่งแล้ว ↓ = สไลด์' },
    { col: 30, text: 'กลางอากาศกด Space อีกครั้ง = กระโดดตีลังกา' },
    { col: 45, text: 'C พุ่ง (ใช้กลางอากาศได้) · V+ทิศ กลิ้งหลบ แล้ว X = ฟันสวน · กด V ค้าง = ชาร์จพลัง' },
    { col: 72, text: 'กลางอากาศ ↓ + X = ปักดาบลงพื้น' },
    { col: 107, text: '↑ ปีนบันไดขึ้นไปเก็บเศษทอง' },
    { col: 122, text: 'กระโดดเข้ากำแพง แล้วกด Space อีกครั้ง = กระโดดถีบกำแพง' },
  ],

  build(api) {
    api.fill(0, 0, 0, 16, 1); api.fill(this.cols - 1, this.cols - 1, 0, 16, 1);
    api.ground(1, 20, 14); api.fill(15, 18, 9, 11, 1);       // low tunnel: crouch or slide under it
    api.ground(21, 28, 12);
    api.ground(32, 40, 13); api.spikes(35, 36, 12);
    api.plat(43, 44, 11);
    api.ground(47, 56, 14); api.plat(51, 53, 11); api.plat(54, 56, 8);
    api.ground(57, 70, 14); api.spikes(58, 68, 13);
    api.ground(71, 75, 14); api.plat(73, 74, 11); api.ground(76, 78, 9);
    api.ground(89, 100, 12); api.spikes(93, 94, 11); api.spikes(98, 98, 11);
    api.plat(102, 103, 11);
    api.ground(105, 138, 14); api.plat(112, 114, 11);
    api.ladder(108, 6, 13); api.plat(109, 114, 6);            // ladder up to a bonus ledge
    api.fill(123, 123, 3, 10, 1); api.fill(127, 127, 5, 13, 1); // wall-jump shaft in front of the gate
  },
};
