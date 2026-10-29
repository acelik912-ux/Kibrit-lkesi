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


def onayla_durumu(page):
    """Onayla düğmesindeki 'seçilen/gereken' sayılarını okur."""
    import re
    btns = page.get_by_role("button")
    for i in range(btns.count()):
        try:
            t = btns.nth(i).inner_text(timeout=300) or ""
        except Exception:  # noqa: BLE001
            continue
        m = re.search(r"Onayla\s*(\d+)/(\d+)", t)
        if m:
            return int(m.group(1)), int(m.group(2))
    return None


BOARD = {}


def sec_kare(page):
    """Senin ülkenin bir üst satırındaki boş karelere dokunur.
    Defterin ekrandaki yerini ilk turda deneyerek bulur."""
    left, right = 23, 403  # genişlik dar: defter yatayda dolu
    cw = (right - left) / 18
    if "top" not in BOARD:
        for top in range(100, 260, 4):
            page.touchscreen.tap(left + 9.5 * cw, top + 15.5 * cw)
            time.sleep(0.25)
            d = onayla_durumu(page)
            if d and d[0] > 0:
                BOARD["top"] = top
                log.append(f"defter üstü bulundu: y={top}")
                break
        else:
            log.append("TEST HATASI: defter bulunamadı")
            return
        start = 1
    else:
        start = 0
    top = BOARD["top"]
    # Satır 15 sağa doğru, sonra satır 14 (ülke büyüdükçe yer değişir).
    hedefler = [(c, 15) for c in range(9, 18)] + [(c, 14) for c in range(9, 18)] \
        + [(c, 13) for c in range(9, 18)] + [(c, 12) for c in range(9, 18)]
    for (cx, cy) in hedefler[start:]:
        d = onayla_durumu(page)
        if not d or d[0] >= d[1]:
            break
        page.touchscreen.tap(left + (cx + 0.5) * cw, top + (cy + 0.5) * cw)
        time.sleep(0.2)


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
            # Kutu ortada bekliyor: dokununca yerine döner.
            page.touchscreen.tap(206, 446)
            time.sleep(0.8)
            # Defterde geçerli bir boş kareye dokun: insan oyuncunun ülkesi
            # alttadır; ülkenin hemen üstündeki kareyi dene.
            sec_kare(page)
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
