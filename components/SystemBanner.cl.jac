"""Global notice shown when the AI model is paused and agents use built-in backup logic."""

import from react { useEffect }
sv import from reliability { SystemStatus, get_system_status }


def:pub SystemBanner -> JsxElement {
    has backup: bool = False,
        message: str = "";

    async def check_status() {
        try {
            status = await get_system_status();
            backup = status.backup_logic;
            message = status.message;
        } except Exception {
            # Status is a courtesy; never block the page when it cannot be read.
            backup = False;
        }
    }

    useEffect(lambda {
        check_status();
        interval = setInterval(lambda { check_status(); }, 10000);
        return lambda { clearInterval(interval); };
    }, []);

    if not backup {
        return <div></div>;
    }
    return <div className="system-banner" role="status">
        <span aria-hidden="true">⚠</span>
        <p>{message}</p>
    </div>;
}
