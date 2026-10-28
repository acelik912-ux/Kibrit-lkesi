"""Web sürümünü telefon boyutunda açıp oyunu oynar ve ekran görüntüleri alır.

Kullanım: python scripts/ekran_testi.py http://localhost:8000/ ekranlar/
"""
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

url = sys.argv[1]
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
log = []


def shot(page, name):
    page.screenshot(path=str(out / f"{name}.png"))
    log.append(f"ekran: {name}")


def click_text(page, text):
    """Flutter web'de erişilebilirlik katmanı üzerinden düğmeye bas."""
    loc = page.get_by_role("button", name=text)
    if loc.count() == 0:
        loc = page.get_by_text(text)
    loc.first.click(timeout=5000)
    log.append(f"tıklandı: {text}")


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 412, "height": 892},
                            device_scale_factor=2, is_mobile=True, has_touch=True)
    page.on("console", lambda m: log.append(f"console[{m.type}]: {m.text}"))
    page.on("pageerror", lambda e: log.append(f"HATA: {e}"))
    page.goto(url)
    page.wait_for_selector("flt-glass-pane, flutter-view", timeout=60000)
    time.sleep(6)
    # Erişilebilirlik katmanını aç ki düğmeleri adıyla bulabilelim.
    page.evaluate(
        "() => { const e = document.querySelector('flt-semantics-placeholder');"
        " if (e) e.click(); }")
    time.sleep(1.5)
    shot(page, "1_menu")

    try:
        click_text(page, "Oyuna başla")
        time.sleep(2)
        shot(page, "2_oyun")
        for tur in range(4):
            click_text(page, "Kibriti at")
            time.sleep(2.2)
            shot(page, f"3_atis_{tur}")
            # Defterde geçerli bir boş kareye dokun: insan oyuncunun ülkesi
            # alttadır; ülkenin hemen üstündeki kareyi dene.
            board = page.evaluate(
                "() => { const v = document.querySelector('flutter-view, flt-glass-pane');"
                " const r = v.getBoundingClientRect(); return [r.width, r.height]; }")
            w, h = board
            # Defter yaklaşık x: 22..w-8, y: 90..h-170 arası; 18x24 kare.
            left, right, top, bottom = 22, w - 8, 92, h - 175
            cw = (right - left) / 18
            chh = (bottom - top) / 24
            ccw = min(cw, chh * 18 / 24 * 24 / 18)
            # Ülke merkezi (9, 18); üstündeki boş satır y=15.
            for k in range(6):
                x = left + (7 + k % 5 + 0.5) * cw
                y = top + (15 - k // 5 + 0.5) * chh
                page.mouse.click(x, y)
                time.sleep(0.25)
            shot(page, f"4_secim_{tur}")
            try:
                page.get_by_role("button", name="Onayla").first.click(timeout=2000)
            except Exception:
                btns = page.get_by_role("button")
                for i in range(btns.count()):
                    t = btns.nth(i).inner_text(timeout=500) or ""
                    if "Onayla" in t:
                        btns.nth(i).click()
                        break
            log.append("onaylandı")
            time.sleep(8)  # botların oynamasını bekle
            shot(page, f"5_bot_sonrasi_{tur}")
    except Exception as e:  # noqa: BLE001
        log.append(f"TEST HATASI: {e}")
        shot(page, "hata")

    browser.close()

(out / "log.txt").write_text("\n".join(log), encoding="utf-8")
print("\n".join(log))
