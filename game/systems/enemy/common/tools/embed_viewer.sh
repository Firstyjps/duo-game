#!/bin/sh
# สร้าง viewer HTML จาก template: แทน __B64__ ด้วยรูป sprite sheet แบบ base64 (viewer เปิดได้ไฟล์เดียว ไม่ต้องมีรูปข้าง ๆ)
# ใช้: sh game/systems/enemy/common/tools/embed_viewer.sh <template.html> <sheet.png> <out.html>
# ตัวอย่าง: sh game/systems/enemy/common/tools/embed_viewer.sh game/systems/enemy/boss_minotaur/tools/minotaur_viewer.template.html \
#           game/systems/enemy/boss_minotaur/minotaur_sheet.png game/systems/enemy/boss_minotaur/tools/minotaur_viewer.html
T="$1"; P="$2"; O="$3"
B=$(mktemp)
base64 -w0 "$P" > "$B"
# อ่านรูปจากไฟล์ทีละบรรทัด (awk -v กับสตริงยาวหลาย MB ช้ามากจนค้าง)
awk -v f="$B" '{i=index($0,"__B64__"); if(i){printf "%s", substr($0,1,i-1); while((getline l < f)>0) printf "%s", l; print substr($0,i+7)} else print}' "$T" > "$O"
rm -f "$B"
