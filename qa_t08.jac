"""Temporary T08 browser interaction QA runner."""

import os;
import from jaclang.cli.browser_engine {
    cmd_click,
    cmd_close,
    cmd_console,
    cmd_fill,
    cmd_navigate,
    cmd_open,
    cmd_screenshot,
    cmd_snapshot,
    cmd_wait,
}


with entry:__main__ {
    os.environ["JACBROWSER_CHROME"] = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";
    viewport: str = os.environ.get("QA_VIEWPORT", "1280x900");
    session: str = "t08-" + viewport + "-" + str(os.getpid());
    image_path: str = "C:\\Users\\sethi\\AppData\\Local\\Temp\\careroute-t08-" + viewport + ".png";
    print(cmd_open(session, "about:blank", viewport));
    print(cmd_navigate(session, "http://localhost:8000"));
    print(cmd_wait(session, "1000"));
    initial: str = cmd_snapshot(session);
    if "We are now syncing your browsing data" in initial {
        print(cmd_click(session, "@e9"));
        print(cmd_wait(session, "400"));
        print(cmd_navigate(session, "http://localhost:8000"));
        print(cmd_wait(session, "1000"));
    }
    print(cmd_click(session, ".primary-nav button:nth-child(2)"));
    print(cmd_wait(session, "300"));
    print(cmd_fill(session, "#hospital-username", "colombo_central_demo"));
    print(cmd_fill(session, "#hospital-password", "care-route-demo"));
    print(cmd_click(session, ".ops-form button[type='submit']"));
    print(cmd_wait(session, "1200"));
    print("--- signed in " + viewport + " ---");
    print(cmd_snapshot(session));
    print(cmd_click(session, "button[aria-label='Decrease ICU free beds']"));
    print(cmd_wait(session, "600"));
    print("--- ICU changed ---");
    print(cmd_snapshot(session));
    print(cmd_screenshot(session, image_path));
    print(cmd_click(session, ".ops-signout"));
    print(cmd_wait(session, "400"));
    print("--- signed out ---");
    print(cmd_snapshot(session));
    print(cmd_console(session));
    print(cmd_close(session));
}
