# Duo Game

เกมที่ทำกัน 2 คน — ทั้งคู่ใช้ Claude Code + GitHub · engine: **Godot 4.7** (`game/`)

## เริ่มใช้ (ครั้งแรก)
```bash
gh repo clone Firstyjps/duo-game && cd duo-game
git config user.name "<ชื่อที่ใส่ใน docs/OWNERS.md>"
claude
```
แล้วพิมพ์ `/start` — Claude จะ sync, อ่าน handoff ของอีกคน และสรุปว่าวันนี้ทำอะไรต่อ
จบงานพิมพ์ `/wrap` — Claude รันเทสต์, เปิด/อัปเดต PR และเขียน handoff ให้อีกคน

## อ่านต่อ
| ไฟล์ | คืออะไร |
|---|---|
| [docs/WORKFLOW.md](docs/WORKFLOW.md) | **กติกาการทำงานร่วมกัน** (อ่านก่อน) |
| [docs/OWNERS.md](docs/OWNERS.md) | ใครเป็นเจ้าของระบบไหน |
| [docs/DESIGN.md](docs/DESIGN.md) | ตัวเกม (GDD) |
| [docs/contracts/](docs/contracts/) | ข้อตกลงระหว่างระบบ (signal / data) |
| [docs/DECISIONS.md](docs/DECISIONS.md) | บันทึกการตัดสินใจ |
| [CLAUDE.md](CLAUDE.md) | กติกาที่ Claude ทั้งสองฝั่งต้องทำตาม |

## รัน / ทดสอบ
```bash
godot --path game                                              # เปิดเกม/editor
godot --headless --path game --script res://tests/run_tests.gd # เทสต์ (CI รันอันเดียวกัน)
```
