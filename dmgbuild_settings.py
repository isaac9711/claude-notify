import os

app_path = os.environ.get("APP_PATH", "/Applications/ClaudeNotify.app")

format = "UDZO"
size = None
files = [app_path]
symlinks = {"Applications": "/Applications"}
icon_size = 80
window_rect = ((200, 120), (540, 380))
icon_locations = {
    "ClaudeNotify.app": (130, 170),
    "Applications": (410, 170),
}
