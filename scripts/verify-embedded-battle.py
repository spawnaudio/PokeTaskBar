#!/usr/bin/env python3
"""Check packaged embedded Battle chrome using Playwright and a simulated native bridge.

Requires the Python Playwright package and Chromium. Native session, item and
lifecycle behavior is covered by BattleWindowTests on macOS.
"""
import argparse
import functools
import http.server
import pathlib
import re
import shutil
import threading

from playwright.sync_api import expect, sync_playwright


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screenshot", type=pathlib.Path, help="Optional output screenshot")
    args = parser.parse_args()
    repository = pathlib.Path(__file__).resolve().parent.parent
    swift = (repository / "Sources/PokeTaskBar/UI/BattleWindow.swift").read_text()
    match = re.search(r'private static let embeddedChromeScript = """\n(.*?)\n    """', swift, re.S)
    if match is None:
        raise AssertionError("Could not find the embedded chrome script in BattleWindow.swift")
    chrome_script = match.group(1)
    handler = functools.partial(QuietHandler, directory=str(repository / "Sources/PokeTaskBar/Resources/BattleWindow"))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with sync_playwright() as playwright:
            chromium = shutil.which("chromium") or shutil.which("chromium-browser")
            options = {"headless": True, "args": ["--no-sandbox"]}
            if chromium:
                options["executable_path"] = chromium
            browser = playwright.chromium.launch(**options)
            page = browser.new_page(viewport={"width": 450, "height": 225})
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.add_init_script("""
              window.commands = [];
              window.nativeState = {
                phase: 'idle', planned: 1500, remaining: 0, xp: 42, threshold: 100,
                coins: 12345, opponent: 0, opponentName: 'GENGAR', opponentImage: '',
                taskTitle: 'Deep work', playerName: 'BULBASAUR', stage: 'Lv. 1', playerImage: '',
                bag: { potion: 1, 'super-potion': 0, 'hyper-potion': 0, revive: 0, 'full-restore': 0 },
                prices: { potion: 100, 'super-potion': 700, 'hyper-potion': 1200, revive: 1500, 'full-restore': 3000 },
                itemImages: {}, defaultMinutes: 25, scale: 1.25, pinned: false
              };
              window.webkit = { messageHandlers: { battle: { postMessage(message) {
                window.commands.push(message);
                if (message.action === 'start') {
                  nativeState.phase = 'running'; nativeState.planned = message.minutes * 60;
                  nativeState.remaining = nativeState.planned;
                }
                setTimeout(() => window.pokeTasksReply?.({ id: message.id, state: {...window.nativeState} }), 0);
              } } } };
            """)
            page.add_init_script('document.addEventListener("DOMContentLoaded", () => {' + chrome_script + '});')
            page.goto(f"http://127.0.0.1:{server.server_port}/", wait_until="networkidle")
            expect(page.locator("main")).to_be_visible()
            expect(page.get_by_role("button", name="Fold into Game Boy")).not_to_be_visible()
            page.get_by_role("button", name="More", exact=True).click()
            expect(page.get_by_role("button", name="Choose task", exact=True)).to_be_visible()
            for name in ["Pin window", "Unpin window", "Tuck at screen edge"]:
                expect(page.get_by_role("button", name=name, exact=True)).not_to_be_visible()
            page.get_by_role("button", name="Choose task", exact=True).click()
            page.wait_for_function("commands.some(command => command.action === 'choose-task')")
            page.get_by_role("button", name="Start timer", exact=True).click()
            expect(page.get_by_test_id("game")).to_have_attribute("data-phase", "running")
            assert page.evaluate("commands.some(command => command.action === 'start' && command.minutes === 25)")
            for scale in [0.5, 1, 1.25, 2]:
                page.set_viewport_size({"width": round(360 * scale), "height": round(180 * scale)})
                page.evaluate("(scale) => { nativeState.scale = scale; window.pokeTasksReply({id: 0, state: {...nativeState}}); }", scale)
                page.wait_for_function("(scale) => Math.abs(document.querySelector('.game').getBoundingClientRect().width - 360 * scale) < 0.1", arg=scale)
                bounds = page.locator(".game").bounding_box()
                assert abs(bounds["width"] - 360 * scale) < 0.1
                assert abs(bounds["height"] - 180 * scale) < 0.1
            if args.screenshot:
                page.set_viewport_size({"width": 450, "height": 225})
                page.evaluate("nativeState.scale = 1.25; window.pokeTasksReply({id: 0, state: {...nativeState}});")
                page.wait_for_function("Math.abs(document.querySelector('.game').getBoundingClientRect().width - 450) < 0.1")
                args.screenshot.parent.mkdir(parents=True, exist_ok=True)
                page.screenshot(path=str(args.screenshot))
            assert not errors, errors
            print("PASS packaged embedded Battle chrome, Choose task/Start commands, scales 50–200%, no browser exceptions")
            browser.close()
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
